;;; musicbrainz.el --- MusicBrainz API client with structured resources -*- lexical-binding: t; -*-

;; Copyright (C) 2025
;; Author: https://github.com/larsmagne/musicbrainz.el, Mimo V2 Flash Free/MiniMax M2.5 Free
;; Keywords: music api musicbrainz
;; Version: 0.2.0
;; URL: https://github.com/musicbrainz/musicbrainz-el
;; Package-Requires: ((emacs "27.1") (pdd "0.2.3") (async "1.9"))

;;; Commentary:

;; MusicBrainz API client using pdd.el for async HTTP requests.
;; Structured resources (EIEIO), caching, and rate limiting.
;; Designed for query-only use (no write operations).
;;
;; Usage:
;;   (musicbrainz-search-artist "artist name")
;;   (musicbrainz-search-release "album name")
;;   M-x musicbrainz-org-search-and-insert-artist
;;   M-x musicbrainz-org-search-and-insert-release

;;; Code:

(require 'pdd)
(require 'json)
(require 'cl-lib)
(require 'subr-x)
(require 'eieio)
(require 'musicbrainz-url)
(require 'async)

(defgroup musicbrainz nil
  "MusicBrainz API client for Emacs."
  :group 'music
  :prefix "musicbrainz-")

(defcustom musicbrainz-api-base "https://musicbrainz.org/ws/2"
  "Base URL for MusicBrainz API."
  :type 'string
  :group 'musicbrainz)

(defcustom musicbrainz-user-agent
  (format "musicbrainz.el/%s" (or (ignore-errors (require 'musicbrainz)) "0.1.0"))
  "User agent string for MusicBrainz API requests.
Using anonymous format as per MusicBrainz API rate limiting policy."
  :type 'string
  :group 'musicbrainz)

(defcustom musicbrainz-rate-limit-requests 15
  "Number of allowed requests per period."
  :type 'integer
  :group 'musicbrainz)

(defcustom musicbrainz-rate-limit-period 18
  "Period in seconds for rate limiting."
  :type 'integer
  :group 'musicbrainz)

(defcustom musicbrainz-max-retries 3
  "Maximum number of retries for rate-limited requests."
  :type 'integer
  :group 'musicbrainz)

(defcustom musicbrainz-retry-delay 2.0
  "Delay in seconds before retrying a rate-limited request."
  :type 'float
  :group 'musicbrainz)

(defcustom musicbrainz-cache-size 100
  "Maximum number of cached responses."
  :type 'integer
  :group 'musicbrainz)

(defcustom musicbrainz-genre-cache-file
  (expand-file-name "musicbrainz-genres.eld" user-emacs-directory)
  "File to store cached genre data."
  :type 'string
  :group 'musicbrainz)

(defvar musicbrainz--cache (make-hash-table :test 'equal)
  "Cache for API responses.")

(defvar musicbrainz--cache-keys nil
  "List of cache keys for LRU eviction.")

(defvar musicbrainz--request-queue nil
  "Queue of request timestamps for rate limiting.")

;;; HTTP headers

(defun musicbrainz-build-headers ()
  "Build HTTP headers for MusicBrainz API requests."
  `((User-Agent . ,musicbrainz-user-agent)
    (Accept . "application/json")))

;;; Rate limiting using token bucket algorithm (similar to rate-limit-threshold)

(defun musicbrainz--rate-limit ()
  "Apply smart rate limiting using token bucket algorithm.
This implements a sliding window rate limiter similar to rate-limit-threshold."
  (let* ((now (float-time))
         (period (* 1000 musicbrainz-rate-limit-period)) ; period in milliseconds
         (t0 (- now (/ period 1000.0))) ; start of sliding window
         (queue musicbrainz--request-queue))
    ;; Remove old requests from queue
    (while (and queue (< (car queue) t0))
      (setq queue (cdr queue)))
    (setq musicbrainz--request-queue queue)

    ;; Check if we've reached the rate limit
    (when (>= (length queue) musicbrainz-rate-limit-requests)
      ;; Calculate delay needed
      (let* ((oldest-request (car queue))
             (delay (- (+ oldest-request (/ period 1000.0)) now)))
        (when (> delay 0)
          (message "Rate limit reached, waiting %.1f seconds..." delay)
          (sleep-for delay))))

    ;; Add current request to queue
    (setq musicbrainz--request-queue (append musicbrainz--request-queue (list now)))))

;;; Caching

(defun musicbrainz--cache-get (key)
  "Get cached response for KEY."
  (gethash key musicbrainz--cache))

(defun musicbrainz--cache-put (key value)
  "Put VALUE in cache with KEY."
  (when (>= (length musicbrainz--cache-keys) musicbrainz-cache-size)
    (let ((oldest (car musicbrainz--cache-keys)))
      (setq musicbrainz--cache-keys (cdr musicbrainz--cache-keys))
      (remhash oldest musicbrainz--cache)))
  (puthash key value musicbrainz--cache)
  (setq musicbrainz--cache-keys (append musicbrainz--cache-keys (list key))))

(defun musicbrainz--make-cache-key (url parameters)
  "Create cache key from URL and PARAMETERS."
  (concat url "::" (prin1-to-string parameters)))

(defun musicbrainz--extract-response-status (response)
  "Extract HTTP status from RESPONSE."
  (cond
   ((and (listp response) (plist-member response :code))
    (plist-get response :code))
   ((and (consp response) (numberp (car response)))
    (car response))
   ((and (listp response) (= (length response) 2) (numberp (nth 1 response)))
    (nth 1 response))
   (t 200)))

(defun musicbrainz--extract-response-body (response)
  "Extract response body from RESPONSE."
  (cond
   ;; Plist format: (:body ... :code ...)
   ((and (listp response) (plist-member response :body))
    (plist-get response :body))
   ;; Cons cell format: (STATUS . BODY) where STATUS is a number
   ((and (consp response) (numberp (car response)))
    (cdr response))
   ;; List format: (BODY STATUS) where STATUS is a number
   ((and (listp response) (= (length response) 2) (numberp (nth 1 response)))
    (car response))
   ;; Alist format: just return it (parsed JSON from pdd)
   ((and (listp response) (consp (car response)) (not (numberp (car response))))
    response)
   ;; Default: return as-is
   (t response)))

;;; HTTP requests using pdd

(defun musicbrainz--request-with-retry (url params retries)
  "Make request to URL with PARAMS, retrying up to RETRIES times on HTTP 503."
  (condition-case err
      (let ((response (pdd url
                           :headers (musicbrainz-build-headers)
                           :params params
                           :as #'musicbrainz--json-read)))
        (let ((status (musicbrainz--extract-response-status response))
              (body (musicbrainz--extract-response-body response)))
          (cond
           ((= status 503)
            (if (> retries 0)
                (progn
                  (message "Rate limited (HTTP 503), retrying in %s seconds... (retries left: %s)"
                           musicbrainz-retry-delay (1- retries))
                  (sleep-for musicbrainz-retry-delay)
                  (musicbrainz--request-with-retry url params (1- retries)))
              (error "MusicBrainz API rate limit exceeded after %s retries" musicbrainz-max-retries)))
           ((>= status 400)
            (error "MusicBrainz API error %s: %s" status body))
           (t body))))
    (error
     (if (> retries 0)
         (progn
           (message "Request failed (%s), retrying... (retries left: %s)"
                    (error-message-string err) (1- retries))
           (sleep-for musicbrainz-retry-delay)
           (musicbrainz--request-with-retry url params (1- retries)))
       (message "MusicBrainz request failed: %s" (error-message-string err))
       nil))))

(defun musicbrainz--request (endpoint &optional query limit offset callback)
  "Make request to ENDPOINT with QUERY.
If CALLBACK provided, performs async request. Returns parsed JSON response."
  (musicbrainz--rate-limit)
  (let* ((url (if query
                  (musicbrainz-url-generic-search endpoint query limit offset)
                (musicbrainz-url-generic-search endpoint "" limit offset)))
         (params nil)  ; URL now contains all parameters
         (cache-key (musicbrainz--make-cache-key url params)))
    (if callback
        (if-let* ((cached (musicbrainz--cache-get cache-key)))
            (funcall callback cached)
          (pdd url
            :headers (musicbrainz-build-headers)
            :params params
            :as #'musicbrainz--json-read

            :done (lambda (&key body &allow-other-keys)
                    (musicbrainz--cache-put cache-key body)
                    (funcall callback body))))
      (if-let* ((cached (musicbrainz--cache-get cache-key)))
          cached
        (let ((response (musicbrainz--request-with-retry url params musicbrainz-max-retries)))
          (musicbrainz--cache-put cache-key response)
          response)))))

(defun musicbrainz--lookup (endpoint mbid &optional inc callback)
  "Make lookup request to ENDPOINT with MBID.
If CALLBACK provided, performs async request. Returns parsed JSON response."
  (musicbrainz--rate-limit)
  (let* ((url (musicbrainz-url-generic-lookup endpoint mbid inc))
         (params nil)  ; URL now contains all parameters
         (cache-key (musicbrainz--make-cache-key url params)))
    (if callback
        (if-let* ((cached (musicbrainz--cache-get cache-key)))
            (funcall callback cached)
          (pdd url
            :headers (musicbrainz-build-headers)
            :params params
            :as #'musicbrainz--json-read

            :done (lambda (&key body status &allow-other-keys)
                    (if (and status (>= status 400))
                        (message "MusicBrainz API error %s for %s" status url)
                      (progn
                        (musicbrainz--cache-put cache-key body)
                        (funcall callback body)))))))
    (if-let* ((cached (musicbrainz--cache-get cache-key)))
        cached
      (let ((response (pdd url
                        :headers (musicbrainz-build-headers)
                        :params params
                        :as #'musicbrainz--json-read
                        )))
        (let ((status (musicbrainz--extract-response-status response))
              (body (musicbrainz--extract-response-body response)))
          (if (and status (>= status 400))
              (progn
                (message "MusicBrainz API error %s for %s: %s" status url body)
                nil)
            (progn
              (musicbrainz--cache-put cache-key body)
              body)))))))

;;; Structured resources (inspired by cl-musicbrainz, using EIEIO)

(defclass musicbrainz-artist ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Artist name")
   (sort-name :initarg :sort-name :type (or null string) :documentation "Sort name")
   (type :initarg :type :type (or null string) :documentation "Artist type")
   (country :initarg :country :type (or null string) :documentation "Country code")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation")
   (begin-date :initarg :begin-date :type (or null string) :documentation "Begin date")
   (end-date :initarg :end-date :type (or null string) :documentation "End date")
   (genres :initarg :genres :type (or null vector list) :documentation "Genres")
   (tags :initarg :tags :type (or null vector list) :documentation "Tags")
   (rating :initarg :rating :type (or null list) :documentation "Rating")
   (isnis :initarg :isnis :type (or null vector list) :documentation "ISNI codes")
   (ipis :initarg :ipis :type (or null vector list) :documentation "IPI codes")
   (aliases :initarg :aliases :type (or null vector list) :documentation "Aliases"))
  "MusicBrainz artist resource.")

(defclass musicbrainz-release ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (title :initarg :title :type string :documentation "Release title")
   (artist :initarg :artist :type string :documentation "Artist name")
   (artist-credit :initarg :artist-credit :type (or null vector list) :documentation "Artist credit list")
   (tracks :initarg :tracks :type (or null vector list) :documentation "Tracklist")
   (date :initarg :date :type (or null string) :documentation "Release date")
   (country :initarg :country :type (or null string) :documentation "Country code")
   (status :initarg :status :type (or null string) :documentation "Release status")
   (format :initarg :format :type (or null string) :documentation "Release format")
   (barcode :initarg :barcode :type (or null string) :documentation "Barcode")
   (packaging :initarg :packaging :type (or null string) :documentation "Packaging")
   (quality :initarg :quality :type (or null string) :documentation "Release quality")
   (asin :initarg :asin :type (or null string) :documentation "ASIN")
   (language :initarg :language :type (or null string) :documentation "Language")
   (script :initarg :script :type (or null string) :documentation "Script")
   (release-group-id :initarg :release-group-id :type (or null string) :documentation "Release group ID")
   (media :initarg :media :type (or null vector list) :documentation "Media list")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz release resource.")

(defclass musicbrainz-release-group ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (title :initarg :title :type string :documentation "Release group title")
   (type :initarg :type :type (or null string) :documentation "Release group type")
   (primary-type :initarg :primary-type :type (or null string) :documentation "Primary type")
   (secondary-types :initarg :secondary-types :type (or null vector list) :documentation "Secondary types")
   (first-release-date :initarg :first-release-date :type (or null string) :documentation "First release date")
   (artist-credit :initarg :artist-credit :type (or null vector list) :documentation "Artist credit")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation")
   (genres :initarg :genres :type (or null vector list) :documentation "Genres")
   (tags :initarg :tags :type (or null vector list) :documentation "Tags")
   (rating :initarg :rating :type (or null list) :documentation "Rating"))
  "MusicBrainz release group resource.")

(defclass musicbrainz-recording ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (title :initarg :title :type string :documentation "Recording title")
   (artist-credit :initarg :artist-credit :type (or null vector list) :documentation "Artist credit")
   (length :initarg :length :type (or null number) :documentation "Recording length in ms")
   (first-release-date :initarg :first-release-date :type (or null string) :documentation "First release date")
   (video :initarg :video :type (or null boolean) :documentation "Whether this is a video recording")
   (isrcs :initarg :isrcs :type (or null vector list) :documentation "ISRC codes")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation")
   (releases :initarg :releases :type (or null vector list) :documentation "Releases"))
  "MusicBrainz recording resource.")

;;; New entities (libmusicbrainz compatible)

(defclass musicbrainz-label ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Label name")
   (sort-name :initarg :sort-name :type (or null string) :documentation "Sort name")
   (type :initarg :type :type (or null string) :documentation "Label type")
   (country :initarg :country :type (or null string) :documentation "Country code")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation")
   (begin-date :initarg :begin-date :type (or null string) :documentation "Begin date")
   (end-date :initarg :end-date :type (or null string) :documentation "End date")
   (label-code :initarg :label-code :type (or null string) :documentation "Label code")
   (barcode :initarg :barcode :type (or null string) :documentation "Barcode")
   (life-span :initarg :life-span :type (or null list) :documentation "Life span")
   (ipis :initarg :ipis :type (or null vector list) :documentation "IPI codes"))
  "MusicBrainz label resource.")

(defclass musicbrainz-work ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (title :initarg :title :type string :documentation "Work title")
   (type :initarg :type :type (or null string) :documentation "Work type")
   (language :initarg :language :type (or null string) :documentation "Language code")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz work resource.")

(defclass musicbrainz-area ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Area name")
   (type :initarg :type :type (or null string) :documentation "Area type")
   (country-code :initarg :country-code :type (or null string) :documentation "ISO country code")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz area resource.")

(defclass musicbrainz-event ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Event name")
   (type :initarg :type :type (or null string) :documentation "Event type")
   (time :initarg :time :type (or null string) :documentation "Event time")
   (setlist :initarg :setlist :type (or null string) :documentation "Setlist")
   (cancelled :initarg :cancelled :type (or null boolean) :documentation "Whether event was cancelled")
   (life-span :initarg :life-span :type (or null list) :documentation "Life span")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz event resource.")

(defclass musicbrainz-instrument ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Instrument name")
   (type :initarg :type :type (or null string) :documentation "Instrument type")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz instrument resource.")

(defclass musicbrainz-place ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Place name")
   (type :initarg :type :type (or null string) :documentation "Place type")
   (address :initarg :address :type (or null string) :documentation "Address")
   (coordinates :initarg :coordinates :type (or null string) :documentation "Coordinates")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz place resource.")

(defclass musicbrainz-series ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Series name")
   (type :initarg :type :type (or null string) :documentation "Series type")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz series resource.")

(defclass musicbrainz-url ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (resource :initarg :resource :type string :documentation "URL resource"))
  "MusicBrainz URL resource.")

(defclass musicbrainz-genre ()
  ((id :initarg :id :type string :documentation "MusicBrainz ID")
   (name :initarg :name :type string :documentation "Genre name")
   (disambiguation :initarg :disambiguation :type (or null string) :documentation "Disambiguation"))
  "MusicBrainz genre resource.")

;;; Additional entities for full API coverage

(defclass musicbrainz-relation ()
  ((type :initarg :type :type string :documentation "Relation type")
   (target-type :initarg :target-type :type string :documentation "Target entity type")
   (target-id :initarg :target-id :type (or null string) :documentation "Target MBID")
   (direction :initarg :direction :type (or null string) :documentation "Direction (forward/backward)")
   (begin-date :initarg :begin-date :type (or null string) :documentation "Begin date")
   (end-date :initarg :end-date :type (or null string) :documentation "End date")
   (ended :initarg :ended :type (or null boolean) :documentation "Whether relation ended")
   (target :initarg :target :type (or null list) :documentation "Target entity data"))
  "MusicBrainz relation resource.")

(defclass musicbrainz-annotation ()
  ((id :initarg :id :type string :documentation "Annotation ID")
   (entity :initarg :entity :type string :documentation "Entity MBID")
   (name :initarg :name :type (or null string) :documentation "Entity name")
   (text :initarg :text :type (or null string) :documentation "Annotation text")
   (type :initarg :type :type (or null string) :documentation "Entity type"))
  "MusicBrainz annotation resource.")

(defclass musicbrainz-collection ()
  ((id :initarg :id :type string :documentation "Collection ID")
   (name :initarg :name :type string :documentation "Collection name")
   (editor :initarg :editor :type (or null string) :documentation "Editor username")
   (entity-type :initarg :entity-type :type (or null string) :documentation "Entity type")
   (entity-count :initarg :entity-count :type (or null number) :documentation "Entity count"))
  "MusicBrainz collection resource.")

(defclass musicbrainz-cdstub ()
  ((id :initarg :id :type string :documentation "CDStub ID")
   (title :initarg :title :type (or null string) :documentation "CD title")
   (artist :initarg :artist :type (or null string) :documentation "Artist name")
   (barcode :initarg :barcode :type (or null string) :documentation "Barcode")
   (comment :initarg :comment :type (or null string) :documentation "Comment")
   (track-count :initarg :track-count :type (or null number) :documentation "Track count"))
  "MusicBrainz CD stub resource.")

(defclass musicbrainz-disc ()
  ((id :initarg :id :type string :documentation "Disc ID")
   (offsets :initarg :offsets :type (or null vector list) :documentation "Track offsets")
   (sectors :initarg :sectors :type (or null number) :documentation "Number of sectors")
   (release-list :initarg :release-list :type (or null vector list) :documentation "Release list"))
  "MusicBrainz disc resource.")

(defclass musicbrainz-freedb-disc ()
  ((id :initarg :id :type string :documentation "FreeDB Disc ID")
   (title :initarg :title :type (or null string) :documentation "Disc title")
   (artist :initarg :artist :type (or null string) :documentation "Artist name")
   (category :initarg :category :type (or null string) :documentation "Category")
   (year :initarg :year :type (or null number) :documentation "Year"))
  "MusicBrainz FreeDB disc resource.")

(defclass musicbrainz-isrc ()
  ((id :initarg :id :type string :documentation "ISRC code")
   (recording-list :initarg :recording-list :type (or null vector list) :documentation "Recording list"))
  "MusicBrainz ISRC resource.")

(defclass musicbrainz-iswc ()
  ((id :initarg :id :type string :documentation "ISWC code")
   (work-list :initarg :work-list :type (or null vector list) :documentation "Work list"))
  "MusicBrainz ISWC resource.")

(defclass musicbrainz-puid ()
  ((id :initarg :id :type string :documentation "PUID code")
   (recording-list :initarg :recording-list :type (or null vector list) :documentation "Recording list"))
  "MusicBrainz PUID resource.")

(defclass musicbrainz-tag ()
  ((name :initarg :name :type string :documentation "Tag name")
   (count :initarg :count :type (or null number) :documentation "Vote count"))
  "MusicBrainz tag resource.")

(defclass musicbrainz-user-tag ()
  ((name :initarg :name :type string :documentation "Tag name"))
  "MusicBrainz user tag resource.")

(defclass musicbrainz-rating ()
  ((value :initarg :value :type number :documentation "Rating value")
   (votes-count :initarg :votes-count :type (or null number) :documentation "Number of votes"))
  "MusicBrainz rating resource.")

(defclass musicbrainz-user-rating ()
  ((value :initarg :value :type number :documentation "User rating value"))
  "MusicBrainz user rating resource.")

(defclass musicbrainz-medium ()
  ((position :initarg :position :type (or null number) :documentation "Medium position")
   (format :initarg :format :type (or null string) :documentation "Medium format")
   (title :initarg :title :type (or null string) :documentation "Medium title")
   (track-list :initarg :track-list :type (or null vector list) :documentation "Track list")
   (disc-list :initarg :disc-list :type (or null vector list) :documentation "Disc list"))
  "MusicBrainz medium resource.")

(defclass musicbrainz-track ()
  ((id :initarg :id :type (or null string) :documentation "Track ID")
   (position :initarg :position :type (or null number) :documentation "Track position")
   (number :initarg :number :type (or null string) :documentation "Track number")
   (title :initarg :title :type string :documentation "Track title")
   (length :initarg :length :type (or null number) :documentation "Track length in ms")
   (recording :initarg :recording :type (or null list) :documentation "Recording data"))
  "MusicBrainz track resource.")

(defclass musicbrainz-alias ()
  ((locale :initarg :locale :type (or null string) :documentation "Locale")
   (alias :initarg :alias :type string :documentation "Alias text")
   (type :initarg :type :type (or null string) :documentation "Alias type")
   (primary :initarg :primary :type (or null boolean) :documentation "Whether primary"))
  "MusicBrainz alias resource.")

(defclass musicbrainz-attribute ()
  ((attribute :initarg :attribute :type string :documentation "Attribute value")
   (credited-as :initarg :credited-as :type (or null string) :documentation "Credited as"))
  "MusicBrainz attribute resource.")

(defclass musicbrainz-ipi ()
  ((ipi :initarg :ipi :type string :documentation "IPI code"))
  "MusicBrainz IPI resource.")

(defclass musicbrainz-isni ()
  ((isni :initarg :isni :type string :documentation "ISNI code"))
  "MusicBrainz ISNI resource.")

(defclass musicbrainz-life-span ()
  ((begin :initarg :begin :type (or null string) :documentation "Begin date")
   (end :initarg :end :type (or null string) :documentation "End date")
   (ended :initarg :ended :type (or null boolean) :documentation "Whether ended"))
  "MusicBrainz life span resource.")

(defclass musicbrainz-text-representation ()
  ((language :initarg :language :type (or null string) :documentation "Language code")
   (script :initarg :script :type (or null string) :documentation "Script code"))
  "MusicBrainz text representation resource.")

(defclass musicbrainz-artist-credit ()
  ((name-credit-list :initarg :name-credit-list :type (or null vector list) :documentation "Name credit list")
   (name :initarg :name :type (or null string) :documentation "Artist credit name"))
  "MusicBrainz artist credit resource.")

(defclass musicbrainz-name-credit ()
  ((name :initarg :name :type (or null string) :documentation "Credit name")
   (join-phrase :initarg :join-phrase :type (or null string) :documentation "Join phrase")
   (artist :initarg :artist :type (or null list) :documentation "Artist data"))
  "MusicBrainz name credit resource.")

(defclass musicbrainz-secondary-type ()
  ((secondary-type :initarg :secondary-type :type string :documentation "Secondary type"))
  "MusicBrainz secondary type resource.")

;;; Resource parsing

(defun musicbrainz--nullify (obj)
  "Recursively convert :null symbols to nil in OBJ."
  (cond
   ((eq obj :null) nil)
   ((consp obj) (cons (musicbrainz--nullify (car obj))
                      (musicbrainz--nullify (cdr obj))))
   ((vectorp obj) (vconcat (mapcar #'musicbrainz--nullify (append obj nil))))
   (t obj)))

(defun musicbrainz--json-read (string)
  "Parse JSON STRING with native parser, converting null to nil."
  (unless (string-blank-p string)
    (musicbrainz--nullify
     (json-parse-string string :object-type 'alist))))

(defun musicbrainz--parse-artist (artist-json)
  "Parse ARTIST-JSON into musicbrainz-artist object."
  (let ((life-span (alist-get 'life-span artist-json)))
    (make-instance 'musicbrainz-artist
     :id (alist-get 'id artist-json)
     :name (alist-get 'name artist-json)
     :sort-name (alist-get 'sort-name artist-json)
     :type (alist-get 'type artist-json)
     :country (alist-get 'country artist-json)
     :disambiguation (alist-get 'disambiguation artist-json)
     :begin-date (alist-get 'begin life-span)
     :end-date (alist-get 'end life-span)
     :genres (alist-get 'genres artist-json)
     :tags (alist-get 'tags artist-json)
     :rating (alist-get 'rating artist-json)
     :isnis (alist-get 'isnis artist-json)
     :ipis (alist-get 'ipis artist-json)
     :aliases (alist-get 'aliases artist-json))))

(defun musicbrainz--parse-release (release-json)
  "Parse RELEASE-JSON into musicbrainz-release object."
  (let* ((artist-credit-list (alist-get 'artist-credit release-json))
         (artist-name (cond
                       ((consp artist-credit-list)
                        (let* ((first-credit (car artist-credit-list))
                               (artist (alist-get 'artist first-credit)))
                          (or (alist-get 'name artist) "Unknown")))
                       ((vectorp artist-credit-list)
                        (when (> (length artist-credit-list) 0)
                          (let* ((first-credit (aref artist-credit-list 0))
                                 (artist (alist-get 'artist first-credit)))
                            (or (alist-get 'name artist) "Unknown"))))
                       (t "Unknown")))
         (formats (alist-get 'formats release-json))
         (format-info (cond
                       ((vectorp formats) (when (> (length formats) 0) (aref formats 0)))
                       ((consp formats) (car formats))
                       (t nil)))
         (release-group (alist-get 'release-group release-json))
         ;; Parse tracklist - handle both vector and list for media
         (media (alist-get 'media release-json))
         (tracks (when media
                   (cl-loop for medium across media
                            append (append (alist-get 'tracks medium) nil)))))
    (make-instance 'musicbrainz-release
                   :id (alist-get 'id release-json)
                   :title (alist-get 'title release-json)
                   :artist artist-name
                   :artist-credit artist-credit-list
                   :tracks tracks
                   :date (alist-get 'date release-json)
                   :country (alist-get 'country release-json)
                   :status (alist-get 'status release-json)
                   :format (when format-info (alist-get 'name format-info))
                   :barcode (alist-get 'barcode release-json)
                   :packaging (alist-get 'packaging release-json)
                   :quality (alist-get 'quality release-json)
                   :asin (alist-get 'asin release-json)
                   :language (when-let* ((tr (alist-get 'text-representation release-json)))
                               (alist-get 'language tr))
                   :script (when-let* ((tr (alist-get 'text-representation release-json)))
                             (alist-get 'script tr))
                   :release-group-id (when release-group (alist-get 'id release-group))
                   :media media
                   :disambiguation (alist-get 'disambiguation release-json))))

(defun musicbrainz--parse-release-group (release-group-json)
"Parse RELEASE-GROUP-JSON into musicbrainz-release-group object."
(make-instance 'musicbrainz-release-group
               :id (alist-get 'id release-group-json)
               :title (alist-get 'title release-group-json)
               :type (alist-get 'type release-group-json)
               :primary-type (alist-get 'primary-type release-group-json)
               :secondary-types (alist-get 'secondary-types release-group-json)
               :first-release-date (alist-get 'first-release-date release-group-json)
               :artist-credit (alist-get 'artist-credit release-group-json)
               :disambiguation (alist-get 'disambiguation release-group-json)
               :genres (alist-get 'genres release-group-json)
               :tags (alist-get 'tags release-group-json)
               :rating (alist-get 'rating release-group-json)))

(defun musicbrainz--parse-recording (recording-json)
  "Parse RECORDING-JSON into musicbrainz-recording object."
  (make-instance 'musicbrainz-recording
                 :id (alist-get 'id recording-json)
                 :title (alist-get 'title recording-json)
                 :artist-credit (alist-get 'artist-credit recording-json)
                 :length (alist-get 'length recording-json)
                 :first-release-date (alist-get 'first-release-date recording-json)
                 :video (alist-get 'video recording-json)
                 :isrcs (alist-get 'isrcs recording-json)
                 :disambiguation (alist-get 'disambiguation recording-json)
                 :releases (alist-get 'releases recording-json)))

(defun musicbrainz--parse-label (label-json)
  "Parse LABEL-JSON into musicbrainz-label object."
  (let ((life-span (alist-get 'life-span label-json)))
    (make-instance 'musicbrainz-label
     :id (alist-get 'id label-json)
     :name (alist-get 'name label-json)
     :sort-name (alist-get 'sort-name label-json)
     :type (alist-get 'type label-json)
     :country (alist-get 'country label-json)
     :disambiguation (alist-get 'disambiguation label-json)
     :begin-date (alist-get 'begin life-span)
     :end-date (alist-get 'end life-span)
     :label-code (alist-get 'label-code label-json)
     :barcode (alist-get 'barcode label-json)
     :life-span life-span
     :ipis (alist-get 'ipis label-json))))

(defun musicbrainz--parse-work (work-json)
  "Parse WORK-JSON into musicbrainz-work object."
  (make-instance 'musicbrainz-work
   :id (alist-get 'id work-json)
   :title (alist-get 'title work-json)
   :type (alist-get 'type work-json)
   :language (alist-get 'language work-json)
   :disambiguation (alist-get 'disambiguation work-json)))

(defun musicbrainz--parse-area (area-json)
  "Parse AREA-JSON into musicbrainz-area object."
  (make-instance 'musicbrainz-area
   :id (alist-get 'id area-json)
   :name (alist-get 'name area-json)
   :type (alist-get 'type area-json)
   :country-code (alist-get 'country-code area-json)
   :disambiguation (alist-get 'disambiguation area-json)))

(defun musicbrainz--parse-event (event-json)
  "Parse EVENT-JSON into musicbrainz-event object."
  (make-instance 'musicbrainz-event
   :id (alist-get 'id event-json)
   :name (alist-get 'name event-json)
   :type (alist-get 'type event-json)
   :time (alist-get 'time event-json)
   :setlist (alist-get 'setlist event-json)
   :cancelled (alist-get 'cancelled event-json)
   :life-span (alist-get 'life-span event-json)
   :disambiguation (alist-get 'disambiguation event-json)))

(defun musicbrainz--parse-instrument (instrument-json)
  "Parse INSTRUMENT-JSON into musicbrainz-instrument object."
  (make-instance 'musicbrainz-instrument
   :id (alist-get 'id instrument-json)
   :name (alist-get 'name instrument-json)
   :type (alist-get 'type instrument-json)
   :disambiguation (alist-get 'disambiguation instrument-json)))

(defun musicbrainz--parse-place (place-json)
  "Parse PLACE-JSON into musicbrainz-place object."
  (make-instance 'musicbrainz-place
   :id (alist-get 'id place-json)
   :name (alist-get 'name place-json)
   :type (alist-get 'type place-json)
   :address (alist-get 'address place-json)
   :coordinates (alist-get 'coordinates place-json)
   :disambiguation (alist-get 'disambiguation place-json)))

(defun musicbrainz--parse-series (series-json)
  "Parse SERIES-JSON into musicbrainz-series object."
  (make-instance 'musicbrainz-series
   :id (alist-get 'id series-json)
   :name (alist-get 'name series-json)
   :type (alist-get 'type series-json)
   :disambiguation (alist-get 'disambiguation series-json)))

(defun musicbrainz--parse-url (url-json)
  "Parse URL-JSON into musicbrainz-url object."
  (make-instance 'musicbrainz-url
   :id (alist-get 'id url-json)
   :resource (alist-get 'resource url-json)))

(defun musicbrainz--parse-genre (genre-json)
  "Parse GENRE-JSON into musicbrainz-genre object."
  (make-instance 'musicbrainz-genre
   :id (alist-get 'id genre-json)
   :name (alist-get 'name genre-json)
   :disambiguation (alist-get 'disambiguation genre-json)))

(defun musicbrainz--parse-relation (relation-json)
  "Parse RELATION-JSON into musicbrainz-relation object."
  (make-instance 'musicbrainz-relation
   :type (alist-get 'type relation-json)
   :target-type (alist-get 'target-type relation-json)
   :target-id (alist-get 'target-id relation-json)
   :direction (alist-get 'direction relation-json)
   :begin-date (alist-get 'begin-date relation-json)
   :end-date (alist-get 'end-date relation-json)
   :ended (alist-get 'ended relation-json)
   :target (alist-get 'target relation-json)))

(defun musicbrainz--parse-annotation (annotation-json)
  "Parse ANNOTATION-JSON into musicbrainz-annotation object."
  (make-instance 'musicbrainz-annotation
   :id (alist-get 'id annotation-json)
   :entity (alist-get 'entity annotation-json)
   :name (alist-get 'name annotation-json)
   :text (alist-get 'text annotation-json)
   :type (alist-get 'type annotation-json)))

(defun musicbrainz--parse-collection (collection-json)
  "Parse COLLECTION-JSON into musicbrainz-collection object."
  (make-instance 'musicbrainz-collection
   :id (alist-get 'id collection-json)
   :name (alist-get 'name collection-json)
   :editor (alist-get 'editor collection-json)
   :entity-type (alist-get 'entity-type collection-json)
   :entity-count (alist-get 'entity-count collection-json)))

(defun musicbrainz--parse-cdstub (cdstub-json)
  "Parse CDSTUB-JSON into musicbrainz-cdstub object."
  (make-instance 'musicbrainz-cdstub
   :id (alist-get 'id cdstub-json)
   :title (alist-get 'title cdstub-json)
   :artist (alist-get 'artist cdstub-json)
   :barcode (alist-get 'barcode cdstub-json)
   :comment (alist-get 'comment cdstub-json)
   :track-count (alist-get 'track-count cdstub-json)))

(defun musicbrainz--parse-disc (disc-json)
  "Parse DISC-JSON into musicbrainz-disc object."
  (make-instance 'musicbrainz-disc
   :id (alist-get 'id disc-json)
   :offsets (alist-get 'offsets disc-json)
   :sectors (alist-get 'sectors disc-json)
   :release-list (alist-get 'releases disc-json)))

(defun musicbrainz--parse-freedb-disc (freedb-json)
  "Parse FREEDB-JSON into musicbrainz-freedb-disc object."
  (make-instance 'musicbrainz-freedb-disc
   :id (alist-get 'id freedb-json)
   :title (alist-get 'title freedb-json)
   :artist (alist-get 'artist freedb-json)
   :category (alist-get 'category freedb-json)
   :year (alist-get 'year freedb-json)))

(defun musicbrainz--parse-isrc (isrc-json)
  "Parse ISRC-JSON into musicbrainz-isrc object."
  (make-instance 'musicbrainz-isrc
   :id (alist-get 'isrc isrc-json)
   :recording-list (alist-get 'recordings isrc-json)))

(defun musicbrainz--parse-iswc (iswc-json)
  "Parse ISWC-JSON into musicbrainz-iswc object."
  (make-instance 'musicbrainz-iswc
   :id (alist-get 'iswc iswc-json)
   :work-list (alist-get 'works iswc-json)))

(defun musicbrainz--parse-puid (puid-json)
  "Parse PUID-JSON into musicbrainz-puid object."
  (make-instance 'musicbrainz-puid
   :id (alist-get 'id puid-json)
   :recording-list (alist-get 'recordings puid-json)))

(defun musicbrainz--parse-tag (tag-json)
  "Parse TAG-JSON into musicbrainz-tag object."
  (make-instance 'musicbrainz-tag
   :name (alist-get 'name tag-json)
   :count (alist-get 'count tag-json)))

(defun musicbrainz--parse-user-tag (tag-json)
  "Parse TAG-JSON into musicbrainz-user-tag object."
  (make-instance 'musicbrainz-user-tag
   :name (alist-get 'name tag-json)))

(defun musicbrainz--parse-rating (rating-json)
  "Parse RATING-JSON into musicbrainz-rating object."
  (make-instance 'musicbrainz-rating
   :value (alist-get 'value rating-json)
   :votes-count (alist-get 'votes-count rating-json)))

(defun musicbrainz--parse-user-rating (rating-json)
  "Parse RATING-JSON into musicbrainz-user-rating object."
  (make-instance 'musicbrainz-user-rating
   :value (alist-get 'value rating-json)))

(defun musicbrainz--parse-medium (medium-json)
  "Parse MEDIUM-JSON into musicbrainz-medium object."
  (make-instance 'musicbrainz-medium
   :position (alist-get 'position medium-json)
   :format (when-let* ((fmt (alist-get 'format medium-json)))
             (if (stringp fmt) fmt (alist-get 'name fmt)))
   :title (alist-get 'title medium-json)
   :track-list (alist-get 'tracks medium-json)
   :disc-list (alist-get 'discs medium-json)))

(defun musicbrainz--parse-track (track-json)
  "Parse TRACK-JSON into musicbrainz-track object."
  (make-instance 'musicbrainz-track
   :id (alist-get 'id track-json)
   :position (alist-get 'position track-json)
   :number (alist-get 'number track-json)
   :title (alist-get 'title track-json)
   :length (alist-get 'length track-json)
   :recording (alist-get 'recording track-json)))

(defun musicbrainz--parse-alias (alias-json)
  "Parse ALIAS-JSON into musicbrainz-alias object."
  (make-instance 'musicbrainz-alias
   :locale (alist-get 'locale alias-json)
   :alias (alist-get 'alias alias-json)
   :type (alist-get 'type alias-json)
   :primary (alist-get 'primary alias-json)))

(defun musicbrainz--parse-life-span (life-span-json)
  "Parse LIFE-SPAN-JSON into musicbrainz-life-span object."
  (make-instance 'musicbrainz-life-span
   :begin (alist-get 'begin life-span-json)
   :end (alist-get 'end life-span-json)
   :ended (alist-get 'ended life-span-json)))

(defun musicbrainz--parse-text-representation (tr-json)
  "Parse TEXT-REPRESENTATION-JSON into musicbrainz-text-representation object."
  (make-instance 'musicbrainz-text-representation
   :language (alist-get 'language tr-json)
   :script (alist-get 'script tr-json)))

(defun musicbrainz--parse-artist-credit (ac-json)
  "Parse ARTIST-CREDIT-JSON into musicbrainz-artist-credit object."
  (make-instance 'musicbrainz-artist-credit
   :name-credit-list ac-json
   :name (when (consp ac-json)
           (alist-get 'name (car (alist-get 'artist (car ac-json)))))))

(defun musicbrainz--parse-name-credit (nc-json)
  "Parse NAME-CREDIT-JSON into musicbrainz-name-credit object."
  (make-instance 'musicbrainz-name-credit
   :name (alist-get 'name nc-json)
   :join-phrase (alist-get 'joinphrase nc-json)
   :artist (alist-get 'artist nc-json)))

(defun musicbrainz--parse-secondary-type (st-json)
  "Parse SECONDARY-TYPE-JSON into musicbrainz-secondary-type object."
  (make-instance 'musicbrainz-secondary-type
   :secondary-type (if (stringp st-json) st-json (alist-get 'secondary-type st-json))))

;;; Public API - Search functions

(defun musicbrainz-search-artist (query &optional limit offset callback)
  "Search for artists matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "artist" query limit offset
        (lambda (json)
          (when-let* ((artists (alist-get 'artists json)))
            (funcall callback (mapcar #'musicbrainz--parse-artist artists)))))
    (when-let* ((json (musicbrainz--request "artist" query limit offset))
                (artists (alist-get 'artists json)))
      (mapcar #'musicbrainz--parse-artist artists))))

(defun musicbrainz-search-release (query &optional limit offset callback)
  "Search for releases matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "release" query limit offset
        (lambda (json)
          (when-let* ((releases (alist-get 'releases json)))
            (funcall callback (mapcar #'musicbrainz--parse-release releases)))))
    (when-let* ((json (musicbrainz--request "release" query limit offset))
                (releases (alist-get 'releases json)))
      (mapcar #'musicbrainz--parse-release releases))))

;;; Public API - Lookup functions

(defun musicbrainz-lookup-artist (mbid &optional inc callback)
  "Look up artist by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "artist" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-artist json))))
    (when-let* ((json (musicbrainz--lookup "artist" mbid inc)))
      (musicbrainz--parse-artist json))))

(defun musicbrainz-lookup-release (mbid &optional inc callback)
  "Look up release by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "release" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-release json))))
    (when-let* ((json (musicbrainz--lookup "release" mbid inc)))
      (musicbrainz--parse-release json))))

(defun musicbrainz-lookup-release-group (mbid &optional inc callback)
  "Look up release group by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "release-group" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-release-group json))))
    (when-let* ((json (musicbrainz--lookup "release-group" mbid inc)))
      (musicbrainz--parse-release-group json))))

;;; New entity search/lookup functions

;; Label
(defun musicbrainz-search-label (query &optional limit offset callback)
  "Search for labels matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "label" query limit offset
        (lambda (json)
          (when-let* ((labels (alist-get 'labels json)))
            (funcall callback (mapcar #'musicbrainz--parse-label labels)))))
    (when-let* ((json (musicbrainz--request "label" query limit offset))
                (labels (alist-get 'labels json)))
      (mapcar #'musicbrainz--parse-label labels))))

(defun musicbrainz-lookup-label (mbid &optional inc callback)
  "Look up label by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "label" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-label json))))
    (when-let* ((json (musicbrainz--lookup "label" mbid inc)))
      (musicbrainz--parse-label json))))

;; Work
(defun musicbrainz-search-work (query &optional limit offset callback)
  "Search for works matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "work" query limit offset
        (lambda (json)
          (when-let* ((works (alist-get 'works json)))
            (funcall callback (mapcar #'musicbrainz--parse-work works)))))
    (when-let* ((json (musicbrainz--request "work" query limit offset))
                (works (alist-get 'works json)))
      (mapcar #'musicbrainz--parse-work works))))

(defun musicbrainz-lookup-work (mbid &optional inc callback)
  "Look up work by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "work" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-work json))))
    (when-let* ((json (musicbrainz--lookup "work" mbid inc)))
      (musicbrainz--parse-work json))))

;; Area
(defun musicbrainz-search-area (query &optional limit offset callback)
  "Search for areas matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "area" query limit offset
        (lambda (json)
          (when-let* ((areas (alist-get 'areas json)))
            (funcall callback (mapcar #'musicbrainz--parse-area areas)))))
    (when-let* ((json (musicbrainz--request "area" query limit offset))
                (areas (alist-get 'areas json)))
      (mapcar #'musicbrainz--parse-area areas))))

(defun musicbrainz-lookup-area (mbid &optional inc callback)
  "Look up area by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "area" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-area json))))
    (when-let* ((json (musicbrainz--lookup "area" mbid inc)))
      (musicbrainz--parse-area json))))

;; Event
(defun musicbrainz-search-event (query &optional limit offset callback)
  "Search for events matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "event" query limit offset
        (lambda (json)
          (when-let* ((events (alist-get 'events json)))
            (funcall callback (mapcar #'musicbrainz--parse-event events)))))
    (when-let* ((json (musicbrainz--request "event" query limit offset))
                (events (alist-get 'events json)))
      (mapcar #'musicbrainz--parse-event events))))

(defun musicbrainz-lookup-event (mbid &optional inc callback)
  "Look up event by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "event" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-event json))))
    (when-let* ((json (musicbrainz--lookup "event" mbid inc)))
      (musicbrainz--parse-event json))))

;; Instrument
(defun musicbrainz-search-instrument (query &optional limit offset callback)
  "Search for instruments matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "instrument" query limit offset
        (lambda (json)
          (when-let* ((instruments (alist-get 'instruments json)))
            (funcall callback (mapcar #'musicbrainz--parse-instrument instruments)))))
    (when-let* ((json (musicbrainz--request "instrument" query limit offset))
                (instruments (alist-get 'instruments json)))
      (mapcar #'musicbrainz--parse-instrument instruments))))

(defun musicbrainz-lookup-instrument (mbid &optional inc callback)
  "Look up instrument by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "instrument" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-instrument json))))
    (when-let* ((json (musicbrainz--lookup "instrument" mbid inc)))
      (musicbrainz--parse-instrument json))))

;; Place
(defun musicbrainz-search-place (query &optional limit offset callback)
  "Search for places matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "place" query limit offset
        (lambda (json)
          (when-let* ((places (alist-get 'places json)))
            (funcall callback (mapcar #'musicbrainz--parse-place places)))))
    (when-let* ((json (musicbrainz--request "place" query limit offset))
                (places (alist-get 'places json)))
      (mapcar #'musicbrainz--parse-place places))))

(defun musicbrainz-lookup-place (mbid &optional inc callback)
  "Look up place by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "place" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-place json))))
    (when-let* ((json (musicbrainz--lookup "place" mbid inc)))
      (musicbrainz--parse-place json))))

;; Series
(defun musicbrainz-search-series (query &optional limit offset callback)
  "Search for series matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "series" query limit offset
        (lambda (json)
          (when-let* ((series (alist-get 'series json)))
            (funcall callback (mapcar #'musicbrainz--parse-series series)))))
    (when-let* ((json (musicbrainz--request "series" query limit offset))
                (series (alist-get 'series json)))
      (mapcar #'musicbrainz--parse-series series))))

(defun musicbrainz-lookup-series (mbid &optional inc callback)
  "Look up series by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "series" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-series json))))
    (when-let* ((json (musicbrainz--lookup "series" mbid inc)))
      (musicbrainz--parse-series json))))

;; URL
(defun musicbrainz-search-url (query &optional limit offset callback)
  "Search for URLs matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "url" query limit offset
        (lambda (json)
          (when-let* ((urls (alist-get 'urls json)))
            (funcall callback (mapcar #'musicbrainz--parse-url urls)))))
    (when-let* ((json (musicbrainz--request "url" query limit offset))
                (urls (alist-get 'urls json)))
      (mapcar #'musicbrainz--parse-url urls))))

(defun musicbrainz-lookup-url (mbid &optional inc callback)
  "Look up URL by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "url" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-url json))))
    (when-let* ((json (musicbrainz--lookup "url" mbid inc)))
      (musicbrainz--parse-url json))))

;; Recording
(defun musicbrainz-search-recording (query &optional limit offset callback)
  "Search for recordings matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "recording" query limit offset
        (lambda (json)
          (when-let* ((recordings (alist-get 'recordings json)))
            (funcall callback (mapcar #'musicbrainz--parse-recording recordings)))))
    (when-let* ((json (musicbrainz--request "recording" query limit offset))
                (recordings (alist-get 'recordings json)))
      (mapcar #'musicbrainz--parse-recording recordings))))

(defun musicbrainz-lookup-recording (mbid &optional inc callback)
  "Look up recording by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "recording" mbid inc
                           (lambda (json)
                             (funcall callback (musicbrainz--parse-recording json))))
    (when-let* ((json (musicbrainz--lookup "recording" mbid inc)))
      (musicbrainz--parse-recording json))))

;; Release Group
(defun musicbrainz-search-release-group (query &optional limit offset callback)
  "Search for release groups matching QUERY.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request "release-group" query limit offset
                            (lambda (json)
                              (when-let* ((release-groups (alist-get 'release-groups json)))
                                (funcall callback (mapcar #'musicbrainz--parse-release-group release-groups)))))
    (when-let* ((json (musicbrainz--request "release-group" query limit offset))
                (release-groups (alist-get 'release-groups json)))
      (mapcar #'musicbrainz--parse-release-group release-groups))))

;; URL lookup by resource
;;;###autoload
(defun musicbrainz-lookup-url-by-resource (resource &optional inc callback)
  "Look up URL entity by RESOURCE string.
If CALLBACK provided, performs async request."
  (if callback
      (let ((url (musicbrainz-url-url-lookup-by-resource resource inc)))
        (musicbrainz--rate-limit)
        (pdd url
             :headers (musicbrainz-build-headers)
             :as #'musicbrainz--json-read
             :done (lambda (&key body &allow-other-keys)
                     (funcall callback (musicbrainz--parse-url body)))))
    (musicbrainz--rate-limit)
    (let* ((url (musicbrainz-url-url-lookup-by-resource resource inc))
           (response (musicbrainz--request-with-retry url nil musicbrainz-max-retries)))
      (when response
        (musicbrainz--parse-url response)))))

;;; Browse operations

(defun musicbrainz--browse (entity linked-entity mbid parse-func &optional limit offset callback)
  "Browse ENTITY by LINKED-ENTITY MBID, parsing results with PARSE-FUNC.
If CALLBACK provided, performs async request."
  (let ((query (format "%s:\"%s\"" linked-entity mbid))
        (response-key (intern (if (string= entity "release-group") "release-groups"
                                (concat entity "s")))))
    (if callback
        (musicbrainz--request entity query limit offset
          (lambda (json)
            (when-let* ((results (alist-get response-key json)))
              (funcall callback (mapcar parse-func results)))))
      (when-let* ((json (musicbrainz--request entity query limit offset))
                  (results (alist-get response-key json)))
        (mapcar parse-func results)))))

;; Browse releases
;;;###autoload
(defun musicbrainz-browse-releases (linked-entity mbid &optional limit offset callback)
  "Browse releases by LINKED-ENTITY MBID.
LINKED-ENTITY should be one of: \"area\", \"artist\", \"label\",
\"recording\", \"release-group\", \"track\", \"track_artist\", \"work\".
If CALLBACK provided, performs async request."
  (musicbrainz--browse "release" linked-entity mbid
                       #'musicbrainz--parse-release limit offset callback))

;;;###autoload
(defun musicbrainz-browse-artist-releases (artist-mbid &optional limit offset callback)
  "Browse releases by artist MBID."
  (musicbrainz-browse-releases "artist" artist-mbid limit offset callback))

;;;###autoload
(defun musicbrainz-browse-label-releases (label-mbid &optional limit offset callback)
  "Browse releases by label MBID."
  (musicbrainz-browse-releases "label" label-mbid limit offset callback))

;; Browse recordings
;;;###autoload
(defun musicbrainz-browse-recordings (linked-entity mbid &optional limit offset callback)
  "Browse recordings by LINKED-ENTITY MBID.
LINKED-ENTITY should be one of: \"artist\", \"release\", \"work\".
If CALLBACK provided, performs async request."
  (musicbrainz--browse "recording" linked-entity mbid
                       #'musicbrainz--parse-recording limit offset callback))

;;;###autoload
(defun musicbrainz-browse-artist-recordings (artist-mbid &optional limit offset callback)
  "Browse recordings by artist MBID."
  (musicbrainz-browse-recordings "artist" artist-mbid limit offset callback))

;;;###autoload
(defun musicbrainz-browse-release-recordings (release-mbid &optional limit offset callback)
  "Browse recordings by release MBID."
  (musicbrainz-browse-recordings "release" release-mbid limit offset callback))

;; Browse release-groups
;;;###autoload
(defun musicbrainz-browse-release-groups (linked-entity mbid &optional limit offset callback)
  "Browse release groups by LINKED-ENTITY MBID.
LINKED-ENTITY should be one of: \"artist\", \"release\".
If CALLBACK provided, performs async request."
  (musicbrainz--browse "release-group" linked-entity mbid
                       #'musicbrainz--parse-release-group limit offset callback))

;;;###autoload
(defun musicbrainz-browse-artist-release-groups (artist-mbid &optional limit offset callback)
  "Browse release groups by artist MBID."
  (musicbrainz-browse-release-groups "artist" artist-mbid limit offset callback))

;; Browse artists
;;;###autoload
(defun musicbrainz-browse-artists (linked-entity mbid &optional limit offset callback)
  "Browse artists by LINKED-ENTITY MBID.
LINKED-ENTITY should be one of: \"area\", \"recording\", \"release\",
\"release-group\", \"work\".
If CALLBACK provided, performs async request."
  (musicbrainz--browse "artist" linked-entity mbid
                       #'musicbrainz--parse-artist limit offset callback))

;;;###autoload
(defun musicbrainz-browse-area-artists (area-mbid &optional limit offset callback)
  "Browse artists by area MBID."
  (musicbrainz-browse-artists "area" area-mbid limit offset callback))

;; Browse labels
;;;###autoload
(defun musicbrainz-browse-labels (linked-entity mbid &optional limit offset callback)
  "Browse labels by LINKED-ENTITY MBID.
LINKED-ENTITY should be one of: \"area\", \"release\".
If CALLBACK provided, performs async request."
  (musicbrainz--browse "label" linked-entity mbid
                       #'musicbrainz--parse-label limit offset callback))

;;;###autoload
(defun musicbrainz-browse-area-labels (area-mbid &optional limit offset callback)
  "Browse labels by area MBID."
  (musicbrainz-browse-labels "area" area-mbid limit offset callback))

;; Browse works
;;;###autoload
(defun musicbrainz-browse-works (linked-entity mbid &optional limit offset callback)
  "Browse works by LINKED-ENTITY MBID.
LINKED-ENTITY should be one of: \"artist\", \"recording\".
If CALLBACK provided, performs async request."
  (musicbrainz--browse "work" linked-entity mbid
                       #'musicbrainz--parse-work limit offset callback))

;;;###autoload
(defun musicbrainz-browse-artist-works (artist-mbid &optional limit offset callback)
  "Browse works by artist MBID."
  (musicbrainz-browse-works "artist" artist-mbid limit offset callback))

;; Browse events
;;;###autoload
(defun musicbrainz-browse-events (linked-entity mbid &optional limit offset callback)
  "Browse events by LINKED-ENTITY MBID.
LINKED-ENTITY should be one of: \"area\", \"artist\", \"place\".
If CALLBACK provided, performs async request."
  (musicbrainz--browse "event" linked-entity mbid
                       #'musicbrainz--parse-event limit offset callback))

;;;###autoload
(defun musicbrainz-browse-artist-events (artist-mbid &optional limit offset callback)
  "Browse events by artist MBID."
  (musicbrainz-browse-events "artist" artist-mbid limit offset callback))

;; Genre
(defun musicbrainz-lookup-genre (mbid &optional inc callback)
  "Look up genre by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "genre" mbid inc
        (lambda (json)
          (funcall callback (musicbrainz--parse-genre json))))
    (when-let* ((json (musicbrainz--lookup "genre" mbid inc)))
      (musicbrainz--parse-genre json))))

(defun musicbrainz--save-genres-to-file (genres)
  "Save GENRES list to cache file."
  (let ((data (list :version 1
                    :timestamp (current-time)
                    :genres (mapcar (lambda (g)
                                      (list :id (oref g id)
                                            :name (oref g name)
                                            :disambiguation (oref g disambiguation)))
                                    genres))))
    (make-directory (file-name-directory musicbrainz-genre-cache-file) t)
    (with-temp-file musicbrainz-genre-cache-file
      (insert ";; MusicBrainz Genre Cache\n")
      (insert ";; Generated by musicbrainz.el\n\n")
      (prin1 data (current-buffer)))))

(defun musicbrainz--load-genres-from-file ()
  "Load genres from cache file.
Returns list of genre objects or nil if file doesn't exist or is invalid."
  (when (file-exists-p musicbrainz-genre-cache-file)
    (with-temp-buffer
      (insert-file-contents musicbrainz-genre-cache-file)
      (goto-char (point-min))
      (when (re-search-forward "^(:" nil t)
        (goto-char (match-beginning 0))
        (let ((data (read (current-buffer))))
          (when (and (listp data) (plist-get data :genres))
            (mapcar (lambda (g)
                      (make-instance 'musicbrainz-genre
                                     :id (plist-get g :id)
                                     :name (plist-get g :name)
                                     :disambiguation (plist-get g :disambiguation)))
                    (plist-get data :genres))))))))

(defun musicbrainz-browse-genres (&optional callback force-update)
  "Browse all genres from MusicBrainz.
If CALLBACK provided, performs async request.
If FORCE-UPDATE is non-nil, fetch fresh data from MusicBrainz."
  (if callback
      (if force-update
          (musicbrainz-browse-genres-async callback)
        (let ((cached (musicbrainz--load-genres-from-file)))
          (if cached
              (funcall callback cached)
            (musicbrainz-browse-genres-async callback))))
    (let ((cached (musicbrainz--load-genres-from-file)))
      (if (and cached (not force-update))
          cached
        (musicbrainz-browse-genres-sync)))))

(defun musicbrainz-browse-genres-async (callback)
  "Fetch all genres asynchronously with pagination."
  (let ((all-genres '())
        (page-size 100)
        (offset 0))
    (cl-labels ((fetch-page ()
                  (let ((url (musicbrainz-url-genre-all page-size offset)))
                    (musicbrainz--rate-limit)
                    (pdd url
                      :headers (musicbrainz-build-headers)
                      :as #'musicbrainz--json-read
                      :done (lambda (&key body &allow-other-keys)
                              (when-let* ((genres (alist-get 'genres body))
                                          (count (alist-get 'genre-count body)))
                                (setq all-genres (append all-genres (append genres nil)))
                                (message "Fetched %d/%d genres..." (length all-genres) count)
                                (if (< (length all-genres) count)
                                    (progn
                                      (setq offset (+ offset page-size))
                                      (fetch-page))
                                  (let ((genre-objects (mapcar #'musicbrainz--parse-genre all-genres)))
                                    (message "Fetched all %d genres from MusicBrainz" (length genre-objects))
                                    (musicbrainz--save-genres-to-file genre-objects)
                                    (funcall callback genre-objects)))))))))
      (fetch-page))))

(defun musicbrainz-browse-genres-sync ()
  "Fetch all genres synchronously with pagination."
  (let ((all-genres '())
        (page-size 100)
        (offset 0)
        (total-count nil)
        (failed nil))
    (while (and (not failed) (or (null total-count) (< (length all-genres) total-count)))
      (let ((url (musicbrainz-url-genre-all page-size offset)))
        (musicbrainz--rate-limit)
        (if-let* ((response (musicbrainz--request-with-retry url nil musicbrainz-max-retries))
                  (genres (alist-get 'genres response))
                  (count (alist-get 'genre-count response)))
            (progn
              (setq all-genres (append all-genres (append genres nil)))
              (setq total-count count)
              (message "Fetched %d/%d genres..." (length all-genres) count)
              (setq offset (+ offset page-size)))
          (setq failed t)
          (message "Genre fetch interrupted at %d genres" (length all-genres)))))
    (let ((genre-objects (mapcar #'musicbrainz--parse-genre all-genres)))
      (message "Fetched all %d genres from MusicBrainz" (length genre-objects))
      (musicbrainz--save-genres-to-file genre-objects)
      genre-objects)))


;;; Utility functions

(defun musicbrainz-format-artist (artist index)
  "Format ARTIST for display with INDEX."
  (format "[%d] %s%s%s"
          index
          (oref artist name)
          (if-let* ((type (oref artist type)))
              (format " (%s)" type) "")
          (if-let* ((country (oref artist country)))
              (format " [%s]" country) "")))

(defun musicbrainz-format-release (release index)
  "Format RELEASE for display with INDEX."
  (format "[%d] %s - %s (%s%s)"
          index
          (oref release artist)
          (oref release title)
          (oref release date)
          (if-let* ((country (oref release country)))
              (format ", %s" country) "")))

(defun musicbrainz-format-label (label index)
  "Format LABEL for display with INDEX."
  (format "[%d] %s%s%s"
          index
          (oref label name)
          (if-let* ((type (oref label type)))
              (format " (%s)" type) "")
          (if-let* ((country (oref label country)))
              (format " [%s]" country) "")))

(defun musicbrainz-format-work (work index)
  "Format WORK for display with INDEX."
  (format "[%d] %s%s"
          index
          (oref work title)
          (if-let* ((type (oref work type)))
              (format " (%s)" type) "")))

(defun musicbrainz-format-area (area index)
  "Format AREA for display with INDEX."
  (format "[%d] %s%s"
          index
          (oref area name)
          (if-let* ((type (oref area type)))
              (format " (%s)" type) "")))

(defun musicbrainz-format-event (event index)
  "Format EVENT for display with INDEX."
  (format "[%d] %s%s"
          index
          (oref event name)
          (if-let* ((type (oref event type)))
              (format " (%s)" type) "")))

(defun musicbrainz-format-instrument (instrument index)
  "Format INSTRUMENT for display with INDEX."
  (format "[%d] %s%s"
          index
          (oref instrument name)
          (if-let* ((type (oref instrument type)))
              (format " (%s)" type) "")))

(defun musicbrainz-format-place (place index)
  "Format PLACE for display with INDEX."
  (format "[%d] %s%s"
          index
          (oref place name)
          (if-let* ((type (oref place type)))
              (format " (%s)" type) "")))

(defun musicbrainz-format-series (series index)
  "Format SERIES for display with INDEX."
  (format "[%d] %s%s"
          index
          (oref series name)
          (if-let* ((type (oref series type)))
              (format " (%s)" type) "")))

(defun musicbrainz-format-url (url index)
  "Format URL for display with INDEX."
  (format "[%d] %s -> %s"
          index
          (oref url resource)
          (oref url id)))

;;; Additional format functions for new entities

(defun musicbrainz-format-relation (relation index)
  "Format RELATION for display with INDEX."
  (format "[%d] %s -> %s%s"
          index
          (oref relation type)
          (oref relation target-type)
          (if (oref relation ended) " (ended)" "")))

(defun musicbrainz-format-annotation (annotation index)
  "Format ANNOTATION for display with INDEX."
  (format "[%d] %s: %s"
          index
          (oref annotation type)
          (if-let* ((text (oref annotation text)))
              (substring text 0 (min 50 (length text)))
            "No text")))

(defun musicbrainz-format-collection (collection index)
  "Format COLLECTION for display with INDEX."
  (format "[%d] %s (%d items)"
          index
          (oref collection name)
          (or (oref collection entity-count) 0)))

(defun musicbrainz-format-cdstub (cdstub index)
  "Format CDSTUB for display with INDEX."
  (format "[%d] %s - %s"
          index
          (or (oref cdstub artist) "Unknown")
          (or (oref cdstub title) "Unknown")))

(defun musicbrainz-format-disc (disc index)
  "Format DISC for display with INDEX."
  (format "[%d] Disc ID: %s (%d releases)"
          index
          (oref disc id)
          (length (or (oref disc release-list) '()))))

(defun musicbrainz-format-isrc (isrc index)
  "Format ISRC for display with INDEX."
  (format "[%d] ISRC: %s (%d recordings)"
          index
          (oref isrc id)
          (length (or (oref isrc recording-list) '()))))

(defun musicbrainz-format-iswc (iswc index)
  "Format ISWC for display with INDEX."
  (format "[%d] ISWC: %s (%d works)"
          index
          (oref iswc id)
          (length (or (oref iswc work-list) '()))))

(defun musicbrainz-format-puid (puid index)
  "Format PUID for display with INDEX."
  (format "[%d] PUID: %s (%d recordings)"
          index
          (oref puid id)
          (length (or (oref puid recording-list) '()))))

(defun musicbrainz-format-tag (tag index)
  "Format TAG for display with INDEX."
  (format "[%d] %s%s"
          index
          (oref tag name)
          (if-let* ((count (oref tag count)))
              (format " (%d)" count) "")))

(defun musicbrainz-format-medium (medium index)
  "Format MEDIUM for display with INDEX."
  (format "[%d] %s - %s"
          index
          (or (oref medium format) "Unknown format")
          (or (oref medium title) (format "Position %d" (or (oref medium position) 0)))))

(defun musicbrainz-format-track (track index)
  "Format TRACK for display with INDEX."
  (format "[%d] %s. %s%s"
          index
          (or (oref track number) "?")
          (oref track title)
          (if-let* ((length (oref track length)))
              (format " (%d:%02d)" (/ length 60000) (/ (mod length 60000) 1000))
            "")))

;;;###autoload
(defun musicbrainz-lookup-release-group-genres (mbid &optional callback)
  "Look up genres for release group by MBID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "release-group" mbid "genres"
                           (lambda (json)
                             (funcall callback (append (alist-get 'genres json) nil))))
    (when-let* ((json (musicbrainz--lookup "release-group" mbid "genres")))
      (append (alist-get 'genres json) nil))))

;;; Relationship support - Parse relations from entity responses

(defun musicbrainz--extract-relations (entity-json)
  "Extract and parse relations from ENTITY-JSON response."
  (when-let* ((relations (alist-get 'relations entity-json)))
    (mapcar #'musicbrainz--parse-relation
            (if (vectorp relations) (append relations nil) relations))))

(defun musicbrainz--extract-relation-lists (entity-json)
  "Extract relation lists from ENTITY-JSON response."
  (when-let* ((relation-lists (alist-get 'relation-lists entity-json)))
    (mapcar (lambda (rl)
              (let ((target-type (alist-get 'target-type rl))
                    (relations (alist-get 'relations rl)))
                (list :target-type target-type
                      :relations (mapcar #'musicbrainz--parse-relation
                                        (if (vectorp relations) (append relations nil) relations)))))
            (if (vectorp relation-lists) (append relation-lists nil) relation-lists))))

;;;###autoload
(defun musicbrainz-lookup-artist-relations (mbid &optional callback)
  "Look up artist by MBID with relations.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "artist" mbid "url-rels+recording-rels+release-rels+release-group-rels+work-rels+label-rels"
        (lambda (json)
          (let ((artist (musicbrainz--parse-artist json))
                (relations (musicbrainz--extract-relations json))
                (relation-lists (musicbrainz--extract-relation-lists json)))
            (funcall callback (list :artist artist :relations relations :relation-lists relation-lists)))))
    (when-let* ((json (musicbrainz--lookup "artist" mbid "url-rels+recording-rels+release-rels+release-group-rels+work-rels+label-rels")))
      (let ((artist (musicbrainz--parse-artist json))
            (relations (musicbrainz--extract-relations json))
            (relation-lists (musicbrainz--extract-relation-lists json)))
        (list :artist artist :relations relations :relation-lists relation-lists)))))

;;;###autoload
(defun musicbrainz-lookup-release-relations (mbid &optional callback)
  "Look up release by MBID with relations.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "release" mbid "artists+labels+recordings+release-groups+url-rels+discids+artist-credits+media"
        (lambda (json)
          (let ((release (musicbrainz--parse-release json))
                (relations (musicbrainz--extract-relations json))
                (relation-lists (musicbrainz--extract-relation-lists json)))
            (funcall callback (list :release release :relations relations :relation-lists relation-lists)))))
    (when-let* ((json (musicbrainz--lookup "release" mbid "artists+labels+recordings+release-groups+url-rels+discids+artist-credits+media")))
      (let ((release (musicbrainz--parse-release json))
            (relations (musicbrainz--extract-relations json))
            (relation-lists (musicbrainz--extract-relation-lists json)))
        (list :release release :relations relations :relation-lists relation-lists)))))

;;;###autoload
(defun musicbrainz-lookup-recording-relations (mbid &optional callback)
  "Look up recording by MBID with relations.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "recording" mbid "artists+releases+url-rels+work-rels+artist-rels+isrcs+tags+ratings"
        (lambda (json)
          (let ((recording (musicbrainz--parse-recording json))
                (relations (musicbrainz--extract-relations json))
                (relation-lists (musicbrainz--extract-relation-lists json)))
            (funcall callback (list :recording recording :relations relations :relation-lists relation-lists)))))
    (when-let* ((json (musicbrainz--lookup "recording" mbid "artists+releases+url-rels+work-rels+artist-rels+isrcs+tags+ratings")))
      (let ((recording (musicbrainz--parse-recording json))
            (relations (musicbrainz--extract-relations json))
            (relation-lists (musicbrainz--extract-relation-lists json)))
        (list :recording recording :relations relations :relation-lists relation-lists)))))

;;;###autoload
(defun musicbrainz-lookup-work-relations (mbid &optional callback)
  "Look up work by MBID with relations.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "work" mbid "url-rels+artist-rels+recording-rels+iswcs+tags+ratings"
        (lambda (json)
          (let ((work (musicbrainz--parse-work json))
                (relations (musicbrainz--extract-relations json))
                (relation-lists (musicbrainz--extract-relation-lists json)))
            (funcall callback (list :work work :relations relations :relation-lists relation-lists)))))
    (when-let* ((json (musicbrainz--lookup "work" mbid "url-rels+artist-rels+recording-rels+iswcs+tags+ratings")))
      (let ((work (musicbrainz--parse-work json))
            (relations (musicbrainz--extract-relations json))
            (relation-lists (musicbrainz--extract-relation-lists json)))
        (list :work work :relations relations :relation-lists relation-lists)))))

;;;###autoload
(defun musicbrainz-lookup-label-relations (mbid &optional callback)
  "Look up label by MBID with relations.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "label" mbid "url-rels+release-rels+tags+ratings"
        (lambda (json)
          (let ((label (musicbrainz--parse-label json))
                (relations (musicbrainz--extract-relations json))
                (relation-lists (musicbrainz--extract-relation-lists json)))
            (funcall callback (list :label label :relations relations :relation-lists relation-lists)))))
    (when-let* ((json (musicbrainz--lookup "label" mbid "url-rels+release-rels+tags+ratings")))
      (let ((label (musicbrainz--parse-label json))
            (relations (musicbrainz--extract-relations json))
            (relation-lists (musicbrainz--extract-relation-lists json)))
        (list :label label :relations relations :relation-lists relation-lists)))))

;;; Disc ID lookup

;;;###autoload
(defun musicbrainz-lookup-disc-id (disc-id &optional callback)
  "Look up releases by DISC-ID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "discid" disc-id "artists+labels+recordings+release-groups+artist-credits+media"
        (lambda (json)
          (let ((disc (musicbrainz--parse-disc json)))
            (funcall callback disc))))
    (when-let* ((json (musicbrainz--lookup "discid" disc-id "artists+labels+recordings+release-groups+artist-credits+media")))
      (musicbrainz--parse-disc json))))

;;;###autoload
(defun musicbrainz-lookup-disc-id-releases (disc-id &optional callback)
  "Look up releases by DISC-ID, returning release list.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz-lookup-disc-id disc-id
        (lambda (disc)
          (when-let* ((releases (oref disc release-list)))
            (funcall callback (mapcar #'musicbrainz--parse-release
                                      (if (vectorp releases) (append releases nil) releases))))))
    (when-let* ((disc (musicbrainz-lookup-disc-id disc-id))
                (releases (oref disc release-list)))
      (mapcar #'musicbrainz--parse-release
              (if (vectorp releases) (append releases nil) releases)))))

;;; ISRC lookup

;;;###autoload
(defun musicbrainz-lookup-isrc (isrc &optional callback)
  "Look up recordings by ISRC code.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "isrc" isrc "artists+releases+url-rels"
        (lambda (json)
          (let ((isrc-obj (musicbrainz--parse-isrc json)))
            (funcall callback isrc-obj))))
    (when-let* ((json (musicbrainz--lookup "isrc" isrc "artists+releases+url-rels")))
      (musicbrainz--parse-isrc json))))

;;;###autoload
(defun musicbrainz-lookup-isrc-recordings (isrc &optional callback)
  "Look up recordings by ISRC code, returning recording list.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz-lookup-isrc isrc
        (lambda (isrc-obj)
          (when-let* ((recordings (oref isrc-obj recording-list)))
            (funcall callback (mapcar #'musicbrainz--parse-recording
                                      (if (vectorp recordings) (append recordings nil) recordings))))))
    (when-let* ((isrc-obj (musicbrainz-lookup-isrc isrc))
                (recordings (oref isrc-obj recording-list)))
      (mapcar #'musicbrainz--parse-recording
              (if (vectorp recordings) (append recordings nil) recordings)))))

;;; ISWC lookup

;;;###autoload
(defun musicbrainz-lookup-iswc (iswc &optional callback)
  "Look up works by ISWC code.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "iswc" iswc "artists+url-rels"
        (lambda (json)
          (let ((iswc-obj (musicbrainz--parse-iswc json)))
            (funcall callback iswc-obj))))
    (when-let* ((json (musicbrainz--lookup "iswc" iswc "artists+url-rels")))
      (musicbrainz--parse-iswc json))))

;;;###autoload
(defun musicbrainz-lookup-iswc-works (iswc &optional callback)
  "Look up works by ISWC code, returning work list.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz-lookup-iswc iswc
        (lambda (iswc-obj)
          (when-let* ((works (oref iswc-obj work-list)))
            (funcall callback (mapcar #'musicbrainz--parse-work
                                      (if (vectorp works) (append works nil) works))))))
    (when-let* ((iswc-obj (musicbrainz-lookup-iswc iswc))
                (works (oref iswc-obj work-list)))
      (mapcar #'musicbrainz--parse-work
              (if (vectorp works) (append works nil) works)))))

;;; PUID lookup

;;;###autoload
(defun musicbrainz-lookup-puid (puid &optional callback)
  "Look up recordings by PUID code.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "puid" puid "artists+releases"
        (lambda (json)
          (let ((puid-obj (musicbrainz--parse-puid json)))
            (funcall callback puid-obj))))
    (when-let* ((json (musicbrainz--lookup "puid" puid "artists+releases")))
      (musicbrainz--parse-puid json))))

;;; CDStub lookup

;;;###autoload
(defun musicbrainz-lookup-cdstub (cdstub-id &optional callback)
  "Look up CDStub by CDSTUB-ID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "cdstub" cdstub-id nil
        (lambda (json)
          (let ((cdstub (musicbrainz--parse-cdstub json)))
            (funcall callback cdstub))))
    (when-let* ((json (musicbrainz--lookup "cdstub" cdstub-id)))
      (musicbrainz--parse-cdstub json))))

;;; FreeDB lookup

;;;###autoload
(defun musicbrainz-lookup-freedb (freedb-id &optional callback)
  "Look up FreeDB disc by FREEDB-ID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "freedb" freedb-id nil
        (lambda (json)
          (let ((freedb (musicbrainz--parse-freedb-disc json)))
            (funcall callback freedb))))
    (when-let* ((json (musicbrainz--lookup "freedb" freedb-id)))
      (musicbrainz--parse-freedb-disc json))))

;;; Collection lookup (read-only)

;;;###autoload
(defun musicbrainz-lookup-collection (collection-id &optional callback)
  "Look up collection by COLLECTION-ID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--lookup "collection" collection-id nil
        (lambda (json)
          (let ((collection (musicbrainz--parse-collection json)))
            (funcall callback collection))))
    (when-let* ((json (musicbrainz--lookup "collection" collection-id)))
      (musicbrainz--parse-collection json))))

;;;###autoload
(defun musicbrainz-lookup-collection-releases (collection-id &optional limit offset callback)
  "Look up releases in collection by COLLECTION-ID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request (format "collection/%s/releases" collection-id) nil limit offset
        (lambda (json)
          (when-let* ((releases (alist-get 'releases json)))
            (funcall callback (mapcar #'musicbrainz--parse-release releases)))))
    (when-let* ((json (musicbrainz--request (format "collection/%s/releases" collection-id) nil limit offset))
                (releases (alist-get 'releases json)))
      (mapcar #'musicbrainz--parse-release releases))))

;;;###autoload
(defun musicbrainz-lookup-collection-artists (collection-id &optional limit offset callback)
  "Look up artists in collection by COLLECTION-ID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request (format "collection/%s/artists" collection-id) nil limit offset
        (lambda (json)
          (when-let* ((artists (alist-get 'artists json)))
            (funcall callback (mapcar #'musicbrainz--parse-artist artists)))))
    (when-let* ((json (musicbrainz--request (format "collection/%s/artists" collection-id) nil limit offset))
                (artists (alist-get 'artists json)))
      (mapcar #'musicbrainz--parse-artist artists))))

;;;###autoload
(defun musicbrainz-lookup-collection-recordings (collection-id &optional limit offset callback)
  "Look up recordings in collection by COLLECTION-ID.
If CALLBACK provided, performs async request."
  (if callback
      (musicbrainz--request (format "collection/%s/recordings" collection-id) nil limit offset
        (lambda (json)
          (when-let* ((recordings (alist-get 'recordings json)))
            (funcall callback (mapcar #'musicbrainz--parse-recording recordings)))))
    (when-let* ((json (musicbrainz--request (format "collection/%s/recordings" collection-id) nil limit offset))
                (recordings (alist-get 'recordings json)))
      (mapcar #'musicbrainz--parse-recording recordings))))

;;; URL lookup by resource

;;;###autoload
(defun musicbrainz-lookup-url-by-resource (resource &optional inc callback)
  "Look up URL entity by RESOURCE string.
If CALLBACK provided, performs async request."
  (if callback
      (let ((url (musicbrainz-url-url-lookup-by-resource resource inc)))
        (musicbrainz--rate-limit)
        (pdd url
             :headers (musicbrainz-build-headers)
             :as #'musicbrainz--json-read
             :done (lambda (&key body &allow-other-keys)
                     (funcall callback (musicbrainz--parse-url body)))))
    (musicbrainz--rate-limit)
    (let* ((url (musicbrainz-url-url-lookup-by-resource resource inc))
           (response (musicbrainz--request-with-retry url nil musicbrainz-max-retries)))
      (when response
        (musicbrainz--parse-url response)))))

;;; Cover Art Archive

(defun musicbrainz-cover-art-url (mbid &optional size)
  "Construct front cover art URL for release MBID.
SIZE can be 250, 500, or nil for full size."
  (if size
      (format "https://coverartarchive.org/release/%s/front-%d" mbid size)
    (format "https://coverartarchive.org/release/%s/front" mbid)))

(provide 'musicbrainz)

;;; musicbrainz.el ends here
