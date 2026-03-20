;;; musicbrainz.el --- MusicBrainz API client with structured resources -*- lexical-binding: t; -*-

;; Copyright (C) 2025
;; Author: https://github.com/larsmagne/musicbrainz.el, Mimo V2 Flash Free/MiniMax M2.5 Free
;; Keywords: music, api
;; Package-Requires: ((emacs "27.1") (pdd "0.2.3"))

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
    (let ((oldest (pop musicbrainz--cache-keys)))
      (remhash oldest musicbrainz--cache)))
  (puthash key value musicbrainz--cache)
  (push key musicbrainz--cache-keys))

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
         (artist-name (if (consp artist-credit-list)
                          (alist-get 'name (car (alist-get 'artist (car artist-credit-list))))
                        "Unknown"))
         (formats (alist-get 'formats release-json))
         (format-info (when formats (car formats)))
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

;;; Cover Art Archive

(defun musicbrainz-cover-art-url (mbid &optional size)
  "Construct front cover art URL for release MBID.
SIZE can be 250, 500, or nil for full size."
  (if size
      (format "https://coverartarchive.org/release/%s/front-%d" mbid size)
    (format "https://coverartarchive.org/release/%s/front" mbid)))

(provide 'musicbrainz)

;;; musicbrainz.el ends here
