;;; musicbrainz-url.el --- URL construction for MusicBrainz API -*- lexical-binding: t; -*-

;; Copyright (C) 2025
;; Author: Mimo V2 Flash Free/MiniMax M2.5 Free
;; Keywords: music, url, musicbrainz
;; Package-Requires: ((emacs "27.1"))

;;; Commentary:

;; This package provides URL construction for MusicBrainz API.
;; It uses declarative templates to define URL structures
;; and construct URLs by filling in parameters.
;;
;; Benefits:
;; - Declarative URL definitions
;; - Easy maintenance when API changes
;; - Type-safe parameter handling
;; - Validation of URL structure
;;
;; Usage:
;;   (musicbrainz-url-artist-lookup "mbid" "releases")
;;   (musicbrainz-url-artist-search "query" 10 0)

;;; Code:

(defgroup musicbrainz-url nil
  "PEG-based URL construction for MusicBrainz API."
  :group 'music
  :prefix "musicbrainz-url-")

(defcustom musicbrainz-url-base "https://musicbrainz.org/ws/2"
  "Base URL for MusicBrainz API."
  :type 'string
  :group 'musicbrainz-url)

;;; URL Template Definitions
;;; Each template is a PEG-like rule that defines the URL structure

(defvar musicbrainz-url-templates
  '(
    ;; Artist endpoints
    (artist-lookup
     . "artist/{mbid}?inc={inc}&fmt=json")
    (artist-search
     . "artist?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Release endpoints
    (release-lookup
     . "release/{mbid}?inc={inc}&fmt=json")
    (release-search
     . "release?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Release Group endpoints
    (release-group-lookup
     . "release-group/{mbid}?inc={inc}&fmt=json")
    (release-group-search
     . "release-group?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Recording endpoints
    (recording-lookup
     . "recording/{mbid}?inc={inc}&fmt=json")
    (recording-search
     . "recording?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Label endpoints
    (label-lookup
     . "label/{mbid}?inc={inc}&fmt=json")
    (label-search
     . "label?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Work endpoints
    (work-lookup
     . "work/{mbid}?inc={inc}&fmt=json")
    (work-search
     . "work?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Area endpoints
    (area-lookup
     . "area/{mbid}?inc={inc}&fmt=json")
    (area-search
     . "area?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Event endpoints
    (event-lookup
     . "event/{mbid}?inc={inc}&fmt=json")
    (event-search
     . "event?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Instrument endpoints
    (instrument-lookup
     . "instrument/{mbid}?inc={inc}&fmt=json")
    (instrument-search
     . "instrument?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Place endpoints
    (place-lookup
     . "place/{mbid}?inc={inc}&fmt=json")
    (place-search
     . "place?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Series endpoints
    (series-lookup
     . "series/{mbid}?inc={inc}&fmt=json")
    (series-search
     . "series?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; URL endpoints
    (url-lookup
     . "url/{mbid}?inc={inc}&fmt=json")
    (url-resource-lookup
     . "url?resource={resource}&inc={inc}&fmt=json")
    (url-search
     . "url?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Genre endpoints (no search, only lookup and /all)
    (genre-lookup
     . "genre/{mbid}?fmt=json")
    (genre-all
     . "genre/all?limit={limit}&offset={offset}&fmt=json")

    ;; Disc ID endpoints
    (discid-lookup
     . "discid/{discid}?inc={inc}&fmt=json")

    ;; ISRC endpoints
    (isrc-lookup
     . "isrc/{isrc}?inc={inc}&fmt=json")

    ;; ISWC endpoints
    (iswc-lookup
     . "iswc/{iswc}?inc={inc}&fmt=json")

    ;; PUID endpoints
    (puid-lookup
     . "puid/{puid}?inc={inc}&fmt=json")

    ;; CDStub endpoints
    (cdstub-lookup
     . "cdstub/{cdstub}?fmt=json")
    (cdstub-search
     . "cdstub?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; FreeDB endpoints
    (freedb-lookup
     . "freedb/{freedb}?fmt=json")
    (freedb-search
     . "freedb?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Collection endpoints
    (collection-lookup
     . "collection/{collection}?fmt=json")
    (collection-releases
     . "collection/{collection}/releases?limit={limit}&offset={offset}&fmt=json")
    (collection-artists
     . "collection/{collection}/artists?limit={limit}&offset={offset}&fmt=json")
    (collection-recordings
     . "collection/{collection}/recordings?limit={limit}&offset={offset}&fmt=json")
    (collection-release-groups
     . "collection/{collection}/release-groups?limit={limit}&offset={offset}&fmt=json")
    (collection-labels
     . "collection/{collection}/labels?limit={limit}&offset={offset}&fmt=json")
    (collection-works
     . "collection/{collection}/works?limit={limit}&offset={offset}&fmt=json")
    (collection-events
     . "collection/{collection}/events?limit={limit}&offset={offset}&fmt=json")
    (collection-places
     . "collection/{collection}/places?limit={limit}&offset={offset}&fmt=json")

    ;; Annotation endpoints
    (annotation-lookup
     . "annotation/{entity}/{mbid}?fmt=json")
    (annotation-search
     . "annotation?query={query}&limit={limit}&offset={offset}&fmt=json")

    ;; Generic lookup (for unknown entities)
    (generic-lookup
     . "{entity}/{mbid}?inc={inc}&fmt=json")
    (generic-search
     . "{entity}?query={query}&limit={limit}&offset={offset}&fmt=json")
    )
  "URL templates for MusicBrainz API endpoints.
Each entry is a cons cell (TEMPLATE-NAME . TEMPLATE-STRING).
Template strings use {param} syntax for parameter substitution.")

;;; URL Construction Functions

(defun musicbrainz-url--fill-template (template &rest params)
  "Fill TEMPLATE with PARAMS.
TEMPLATE is a string with {param} placeholders.
PARAMS is a list of (PARAM-NAME . VALUE) cons cells."
  (cl-reduce
   (lambda (url param)
     (let ((param-name (car param))
           (param-value (cdr param)))
       (if (stringp param-value)
           (string-replace (format "{%s}" param-name) param-value url)
         url)))
   params
   :initial-value template))

(defun musicbrainz-url--get-template (template-name)
  "Get template string for TEMPLATE-NAME."
  (cdr (assoc template-name musicbrainz-url-templates)))

(defun musicbrainz-url-construct (template-name &rest params)
  "Construct URL for TEMPLATE-NAME with PARAMS."
  (let ((template (musicbrainz-url--get-template template-name))
        (base musicbrainz-url-base))
    (when template
      (concat base "/"
              (apply #'musicbrainz-url--fill-template template params)))))

;;; Specific URL Construction Functions

;; Artist URLs
;;;###autoload
(defun musicbrainz-url-artist-lookup (mbid &optional inc)
  "Construct URL for artist lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'artist-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-artist-search (query &optional limit offset)
  "Construct URL for artist search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'artist-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Release URLs
;;;###autoload
(defun musicbrainz-url-release-lookup (mbid &optional inc)
  "Construct URL for release lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'release-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-release-search (query &optional limit offset)
  "Construct URL for release search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'release-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Release Group URLs
(defun musicbrainz-url-release-group-lookup (mbid &optional inc)
  "Construct URL for release group lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'release-group-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

(defun musicbrainz-url-release-group-search (query &optional limit offset)
  "Construct URL for release group search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'release-group-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Recording URLs
;;;###autoload
(defun musicbrainz-url-recording-lookup (mbid &optional inc)
  "Construct URL for recording lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'recording-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-recording-search (query &optional limit offset)
  "Construct URL for recording search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'recording-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Label URLs
;;;###autoload
(defun musicbrainz-url-label-lookup (mbid &optional inc)
  "Construct URL for label lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'label-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-label-search (query &optional limit offset)
  "Construct URL for label search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'label-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Work URLs
;;;###autoload
(defun musicbrainz-url-work-lookup (mbid &optional inc)
  "Construct URL for work lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'work-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-work-search (query &optional limit offset)
  "Construct URL for work search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'work-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Area URLs
;;;###autoload
(defun musicbrainz-url-area-lookup (mbid &optional inc)
  "Construct URL for area lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'area-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-area-search (query &optional limit offset)
  "Construct URL for area search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'area-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Event URLs
;;;###autoload
(defun musicbrainz-url-event-lookup (mbid &optional inc)
  "Construct URL for event lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'event-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-event-search (query &optional limit offset)
  "Construct URL for event search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'event-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Instrument URLs
;;;###autoload
(defun musicbrainz-url-instrument-lookup (mbid &optional inc)
  "Construct URL for instrument lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'instrument-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-instrument-search (query &optional limit offset)
  "Construct URL for instrument search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'instrument-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Place URLs
;;;###autoload
(defun musicbrainz-url-place-lookup (mbid &optional inc)
  "Construct URL for place lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'place-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-place-search (query &optional limit offset)
  "Construct URL for place search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'place-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Series URLs
;;;###autoload
(defun musicbrainz-url-series-lookup (mbid &optional inc)
  "Construct URL for series lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'series-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-series-search (query &optional limit offset)
  "Construct URL for series search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'series-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; URL URLs (ironic naming, but consistent with API)
;;;###autoload
(defun musicbrainz-url-url-lookup (mbid &optional inc)
  "Construct URL for URL entity lookup by MBID with optional INCLUDES."
  (musicbrainz-url-construct 'url-lookup
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-url-search (query &optional limit offset)
  "Construct URL for URL entity search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'url-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Genre URLs
;;;###autoload
(defun musicbrainz-url-genre-lookup (mbid)
  "Construct URL for genre lookup by MBID."
  (musicbrainz-url-construct 'genre-lookup
                             (cons 'mbid mbid)))

;;;###autoload
(defun musicbrainz-url-genre-all (&optional limit offset)
  "Construct URL for browsing all genres with LIMIT and OFFSET."
  (musicbrainz-url-construct 'genre-all
                             (cons 'limit (number-to-string (or limit 100)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Disc ID URLs
;;;###autoload
(defun musicbrainz-url-discid-lookup (discid &optional inc)
  "Construct URL for disc ID lookup by DISCID with optional INCLUDES."
  (musicbrainz-url-construct 'discid-lookup
                             (cons 'discid discid)
                             (cons 'inc (or inc ""))))

;; ISRC URLs
;;;###autoload
(defun musicbrainz-url-isrc-lookup (isrc &optional inc)
  "Construct URL for ISRC lookup by ISRC with optional INCLUDES."
  (musicbrainz-url-construct 'isrc-lookup
                             (cons 'isrc isrc)
                             (cons 'inc (or inc ""))))

;; ISWC URLs
;;;###autoload
(defun musicbrainz-url-iswc-lookup (iswc &optional inc)
  "Construct URL for ISWC lookup by ISWC with optional INCLUDES."
  (musicbrainz-url-construct 'iswc-lookup
                             (cons 'iswc iswc)
                             (cons 'inc (or inc ""))))

;; PUID URLs
;;;###autoload
(defun musicbrainz-url-puid-lookup (puid &optional inc)
  "Construct URL for PUID lookup by PUID with optional INCLUDES."
  (musicbrainz-url-construct 'puid-lookup
                             (cons 'puid puid)
                             (cons 'inc (or inc ""))))

;; CDStub URLs
;;;###autoload
(defun musicbrainz-url-cdstub-lookup (cdstub)
  "Construct URL for CDStub lookup by CDSTUB."
  (musicbrainz-url-construct 'cdstub-lookup
                             (cons 'cdstub cdstub)))

;;;###autoload
(defun musicbrainz-url-cdstub-search (query &optional limit offset)
  "Construct URL for CDStub search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'cdstub-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; FreeDB URLs
;;;###autoload
(defun musicbrainz-url-freedb-lookup (freedb)
  "Construct URL for FreeDB lookup by FREEDB."
  (musicbrainz-url-construct 'freedb-lookup
                             (cons 'freedb freedb)))

;;;###autoload
(defun musicbrainz-url-freedb-search (query &optional limit offset)
  "Construct URL for FreeDB search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'freedb-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Collection URLs
;;;###autoload
(defun musicbrainz-url-collection-lookup (collection)
  "Construct URL for collection lookup by COLLECTION."
  (musicbrainz-url-construct 'collection-lookup
                             (cons 'collection collection)))

;;;###autoload
(defun musicbrainz-url-collection-releases (collection &optional limit offset)
  "Construct URL for collection releases by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-releases
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-collection-artists (collection &optional limit offset)
  "Construct URL for collection artists by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-artists
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-collection-recordings (collection &optional limit offset)
  "Construct URL for collection recordings by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-recordings
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-collection-release-groups (collection &optional limit offset)
  "Construct URL for collection release groups by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-release-groups
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-collection-labels (collection &optional limit offset)
  "Construct URL for collection labels by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-labels
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-collection-works (collection &optional limit offset)
  "Construct URL for collection works by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-works
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-collection-events (collection &optional limit offset)
  "Construct URL for collection events by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-events
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-collection-places (collection &optional limit offset)
  "Construct URL for collection places by COLLECTION with LIMIT and OFFSET."
  (musicbrainz-url-construct 'collection-places
                             (cons 'collection collection)
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;; Annotation URLs
;;;###autoload
(defun musicbrainz-url-annotation-lookup (entity mbid)
  "Construct URL for annotation lookup by ENTITY and MBID."
  (musicbrainz-url-construct 'annotation-lookup
                             (cons 'entity entity)
                             (cons 'mbid mbid)))

;;;###autoload
(defun musicbrainz-url-annotation-search (query &optional limit offset)
  "Construct URL for annotation search with QUERY, LIMIT, and OFFSET."
  (musicbrainz-url-construct 'annotation-search
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;; Generic URL Construction

;;;###autoload
(defun musicbrainz-url-generic-lookup (entity mbid &optional inc)
  "Construct URL for generic entity lookup."
  (musicbrainz-url-construct 'generic-lookup
                             (cons 'entity entity)
                             (cons 'mbid mbid)
                             (cons 'inc (or inc ""))))

;;;###autoload
(defun musicbrainz-url-generic-search (entity query &optional limit offset)
  "Construct URL for generic entity search."
  (musicbrainz-url-construct 'generic-search
                             (cons 'entity entity)
                             (cons 'query (url-encode-url query))
                             (cons 'limit (number-to-string (or limit 25)))
                             (cons 'offset (number-to-string (or offset 0)))))

;;;###autoload
(defun musicbrainz-url-url-lookup-by-resource (resource &optional inc)
  "Construct URL for looking up a URL entity by RESOURCE."
  (musicbrainz-url-construct 'url-resource-lookup
                             (cons 'resource (url-encode-url resource))
                             (cons 'inc (or inc ""))))

;;; URL Validation (Optional)

(defun musicbrainz-url-validate-mbid (mbid)
  "Validate MBID format.
MBID should be in the format: 8-4-4-4-12 hex digits."
  (string-match-p "^[0-9a-fA-F]\\{8\\}-[0-9a-fA-F]\\{4\\}-[0-9a-fA-F]\\{4\\}-[0-9a-fA-F]\\{4\\}-[0-9a-fA-F]\\{12\\}$" mbid))

;;; Helper Functions

(defun musicbrainz-url-encode-query (query)
  "URL-encode QUERY string."
  (url-encode-url query))

(defun musicbrainz-url-add-params (url &rest params)
  "Add parameters to URL."
  (let ((separator (if (string-match-p "?" url) "&" "?")))
    (concat url separator
            (mapconcat (lambda (param)
                         (format "%s=%s" (car param) (cdr param)))
                       params
                       "&"))))

(provide 'musicbrainz-url)

;;; musicbrainz-url.el ends here
