;;; musicbrainz-org.el --- MusicBrainz org-mode interface -*- lexical-binding: t; -*-

;; Copyright (C) 2025
;; Author: Mimo V2 Flash Free/MiniMax M2.5 Free
;; Keywords: music, org-mode, musicbrainz
;; Package-Requires: ((emacs "27.1") (org "9.0") (musicbrainz "1.0"))

;;; Commentary:

;; This package provides an org-mode interface for MusicBrainz queries.
;; It allows inserting MusicBrainz data as structured Org headings.
;;
;; Features:
;; - Interactive selection interface for search results
;; - Direct insertion into Org files with structured metadata
;; - Support for all MusicBrainz entity types
;; - No database dependency - pure file storage using Org properties
;;
;; Inspired by:
;; - denote: Simple file-naming scheme for notes
;; - org-supertag: Database-backed Org workflow with structured tags
;;
;; Design principles:
;; - No database: Store data directly in Org files
;; - Structured headings: Use Org properties for metadata
;; - Link support: Use Org ID links for references
;; - Minimal dependencies: Only requires org-mode and musicbrainz

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'musicbrainz)

;;; Customization

(defgroup musicbrainz-org nil
  "MusicBrainz org-mode interface."
  :group 'music
  :prefix "musicbrainz-org-")

(defcustom musicbrainz-org-default-level 2
  "Default heading level for inserted MusicBrainz data."
  :type 'integer
  :group 'musicbrainz-org)

(defcustom musicbrainz-org-insert-properties t
  "Whether to insert Org properties drawer with metadata."
  :type 'boolean
  :group 'musicbrainz-org)

(defcustom musicbrainz-org-link-to-source t
  "Whether to create links to MusicBrainz source."
  :type 'boolean
  :group 'musicbrainz-org)

(defcustom musicbrainz-org-date-format "%Y-%m-%d"
  "Date format for timestamps."
  :type 'string
  :group 'musicbrainz-org)

(defcustom musicbrainz-org-show-selection t
  "Whether to show selection interface when multiple results are found."
  :type 'boolean
  :group 'musicbrainz-org)

;;; Helper functions

(defun musicbrainz-org--format-timestamp (&optional date)
  "Format DATE as Org timestamp."
  (when date
    (format "[%s]" (format-time-string musicbrainz-org-date-format
                                       (date-to-time date)))))

(defun musicbrainz-org--create-link (type id)
  "Create MusicBrainz link for TYPE and ID."
  (when musicbrainz-org-link-to-source
    (format "https://musicbrainz.org/%s/%s" type id)))

(defun musicbrainz-org--insert-properties (entity)
  "Insert Org properties drawer for ENTITY."
  (when musicbrainz-org-insert-properties
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (oref entity id)))
    ;; Check if slot is bound before accessing
    (when (and (slot-exists-p entity 'type)
               (slot-boundp entity 'type)
               (oref entity type))
      (insert (format ":TYPE: %s\n" (oref entity type))))
    (when (and (slot-exists-p entity 'country)
               (slot-boundp entity 'country)
               (oref entity country))
      (insert (format ":COUNTRY: %s\n" (oref entity country))))
    (when (and (slot-exists-p entity 'disambiguation)
               (slot-boundp entity 'disambiguation)
               (oref entity disambiguation))
      (insert (format ":DISAMBIGUATION: %s\n" (oref entity disambiguation))))
    (when (and (slot-exists-p entity 'begin-date)
               (slot-boundp entity 'begin-date)
               (oref entity begin-date))
      (insert (format ":BEGIN-DATE: %s\n" (oref entity begin-date))))
    (when (and (slot-exists-p entity 'end-date)
               (slot-boundp entity 'end-date)
               (oref entity end-date))
      (insert (format ":END-DATE: %s\n" (oref entity end-date))))
    (when (and (slot-exists-p entity 'country-code)
               (slot-boundp entity 'country-code)
               (oref entity country-code))
      (insert (format ":COUNTRY-CODE: %s\n" (oref entity country-code))))
    (when (and (slot-exists-p entity 'language)
               (slot-boundp entity 'language)
               (oref entity language))
      (insert (format ":LANGUAGE: %s\n" (oref entity language))))
    (when (and (slot-exists-p entity 'address)
               (slot-boundp entity 'address)
               (oref entity address))
      (insert (format ":ADDRESS: %s\n" (oref entity address))))
    (when (and (slot-exists-p entity 'coordinates)
               (slot-boundp entity 'coordinates)
               (oref entity coordinates))
      (insert (format ":COORDINATES: %s\n" (oref entity coordinates))))
    (when (and (slot-exists-p entity 'time)
               (slot-boundp entity 'time)
               (oref entity time))
      (insert (format ":TIME: %s\n" (oref entity time))))
    (when (and (slot-exists-p entity 'setlist)
               (slot-boundp entity 'setlist)
               (oref entity setlist))
      (insert (format ":SETLIST: %s\n" (oref entity setlist))))
    (when (and (slot-exists-p entity 'resource)
               (slot-boundp entity 'resource)
               (oref entity resource))
      (insert (format ":RESOURCE: %s\n" (oref entity resource))))
    ;; Release-specific properties
    (when (and (slot-exists-p entity 'status)
               (slot-boundp entity 'status)
               (oref entity status))
      (insert (format ":STATUS: %s\n" (oref entity status))))
    (when (and (slot-exists-p entity 'format)
               (slot-boundp entity 'format)
               (oref entity format))
      (insert (format ":FORMAT: %s\n" (oref entity format))))
    (when (and (slot-exists-p entity 'date)
               (slot-boundp entity 'date)
               (oref entity date))
      (insert (format ":DATE: %s\n" (oref entity date))))
    (when (and (slot-exists-p entity 'artist)
               (slot-boundp entity 'artist)
               (oref entity artist))
      (insert (format ":ARTIST: %s\n" (oref entity artist))))
    (when (and (slot-exists-p entity 'first-release-date)
               (slot-boundp entity 'first-release-date)
               (oref entity first-release-date))
      (insert (format ":FIRST-RELEASE-DATE: %s\n" (oref entity first-release-date))))
    (insert ":END:\n")))

(defun musicbrainz-org--insert-link (type id)
  "Insert MusicBrainz link."
  (when (and musicbrainz-org-link-to-source type id)
    (insert (format "[[%s][MusicBrainz %s]]\n"
                    (musicbrainz-org--create-link type id)
                    (capitalize type)))))

;;; Selection interface

(defun musicbrainz-org--select-item (items format-func)
  "Select an item from ITEMS using FORMAT-FUNC for display.
Returns the selected item or nil if cancelled."
  (if (null items)
      (progn
        (message "No items found")
        nil)
    (if (and musicbrainz-org-show-selection (> (length items) 1))
        ;; Simple completing-read with fuzzy search (no pagination or navigation)
        (let* ((formatted-items (cl-loop for item in items
                                         collect (funcall format-func item)))
               (choice (completing-read "Select item: "
                                        formatted-items
                                        nil t)))  ; Require match, fuzzy search enabled
          (when choice
            ;; Find the selected item by matching the formatted string
            (let ((pos (cl-position choice formatted-items :test 'equal)))
              (when pos
                (nth pos items)))))
      ;; Return first item if no selection needed
      (car items))))

(defun musicbrainz-org--select-item-progressive (query search-func format-func &optional offset all-items)
  "Select an item using completing-read, loading up to 100 items.
QUERY is the search query. SEARCH-FUNC takes (query limit offset).
FORMAT-FUNC formats items for display."
  (let* ((page-size 100)
         (offset (or offset 0))
         (current-page (condition-case err
                           (funcall search-func query page-size offset)
                         (error (message "Search failed: %s" (error-message-string err))
                                nil)))
         (accumulated (append (or all-items '()) current-page)))
    (cond
     ((null accumulated)
      (message "No items found for query: %s" query)
      nil)
     ((= (length accumulated) 1)
      (car accumulated))
     (t
      (let* ((formatted (mapcar format-func accumulated))
             (has-more (= (length current-page) page-size))
             (prompt (format "Select%s: "
                             (if has-more
                                 (format " [%d+]" (length accumulated))
                               (format " [%d]" (length accumulated)))))
             (choice (completing-read prompt formatted nil t)))
        (when choice
          (let ((pos (cl-position choice formatted :test 'equal)))
            (when pos (nth pos accumulated)))))))))

(defun musicbrainz-org--search-async (query endpoint response-key fmt-lambda parse-func insert-func level)
  "Two-phase async search: pdd for HTTP, async-start for JSON formatting.
QUERY is the search string. ENDPOINT is the API endpoint. RESPONSE-KEY
is the JSON list key. FMT-LAMBDA is a quoted lambda that formats one
raw JSON item (alist). PARSE-FUNC converts one raw JSON item to an
EIEIO object. INSERT-FUNC inserts the selected item at LEVEL."
  (message "Searching %s for \"%s\"..." endpoint query)
  (let ((target-buf (current-buffer)))
    (musicbrainz--request endpoint query 100 0
      (lambda (json)
        (if-let* ((raw (when json (alist-get response-key json)))
                  (items (if (vectorp raw) (append raw nil) raw)))
            (if (= (length items) 1)
                (progn
                  (with-current-buffer target-buf
                    (funcall insert-func (funcall parse-func (car items)) level))
                  (message "Done."))
              (async-start
               `(lambda () (mapcar ,fmt-lambda ',items))
               (lambda (formatted)
                 (let ((choice (completing-read
                                (format "Select [%d]: " (length formatted))
                                formatted nil t)))
                   (when choice
                     (let ((pos (cl-position choice formatted :test 'equal)))
                       (when pos
                         (with-current-buffer target-buf
                           (funcall insert-func
                                    (funcall parse-func (nth pos items))
                                    level))
                         (message "Done."))))))))
          (message "No items found for query: %s" query))))))

(defvar musicbrainz-org--select-items nil)
(defvar musicbrainz-org--select-page 0)
(defvar musicbrainz-org--select-page-size 100)
(defvar musicbrainz-org--select-total nil)
(defvar musicbrainz-org--select-query nil)
(defvar musicbrainz-org--select-search-func nil)
(defvar musicbrainz-org--select-format-func nil)
(defvar musicbrainz-org--select-callback nil)

(defun musicbrainz-org--select-in-buffer (query search-func format-func callback)
  "Select an item in a dedicated buffer with progressive loading.
QUERY is the search query. SEARCH-FUNC takes (query limit offset).
FORMAT-FUNC formats an item for display. CALLBACK receives the selected item."
  (let* ((buf (get-buffer-create "*MusicBrainz Select*"))
         (page-size 100))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (musicbrainz-org-select-mode)
        (setq-local musicbrainz-org--select-items nil)
        (setq-local musicbrainz-org--select-page 0)
        (setq-local musicbrainz-org--select-page-size page-size)
        (setq-local musicbrainz-org--select-total nil)
        (setq-local musicbrainz-org--select-query query)
        (setq-local musicbrainz-org--select-search-func search-func)
        (setq-local musicbrainz-org--select-format-func format-func)
        (setq-local musicbrainz-org--select-callback callback)
        (insert (format " Searching: %s\n\n" query))
        (insert " Loading...\n")
        (setq buffer-read-only t))
      (pop-to-buffer buf '(display-buffer-at-bottom (window-height . 0.4)))
      (musicbrainz-org--select-load-page 0))))

(defun musicbrainz-org--select-load-page (page)
  "Load PAGE of results into the selection buffer."
  (let* ((inhibit-read-only t)
         (offset (* page musicbrainz-org--select-page-size))
         (new-items (funcall musicbrainz-org--select-search-func
                             musicbrainz-org--select-query
                             musicbrainz-org--select-page-size offset))
         (total (if new-items
                    (if (< (length new-items) musicbrainz-org--select-page-size)
                        (+ offset (length new-items))
                      nil)
                  (or musicbrainz-org--select-total (length musicbrainz-org--select-items)))))
    (setq musicbrainz-org--select-page page)
    (setq musicbrainz-org--select-total total)
    (when new-items
      (setq musicbrainz-org--select-items
            (append musicbrainz-org--select-items new-items)))
    (musicbrainz-org--select-redraw)
    (goto-char (point-min))
    (forward-line 3)))

(defun musicbrainz-org--select-redraw ()
  "Redraw the selection buffer contents."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (let* ((items musicbrainz-org--select-items)
           (total (or musicbrainz-org--select-total "?"))
           (page musicbrainz-org--select-page)
           (page-size musicbrainz-org--select-page-size)
           (start (* page page-size))
           (end (min (length items) (+ start page-size)))
           (page-items (cl-subseq items start end))
           (has-more (and (null musicbrainz-org--select-total)
                          (= (length (cl-subseq items start end)) page-size))))
      (insert (format " Search: %s  |  Page %d  |  Showing %d-%d of %s\n"
                      musicbrainz-org--select-query
                      (1+ page) (1+ start) end
                      (if (numberp total) (number-to-string total) total)))
      (insert (format " [RET] select  [n/p] next/prev page  [q] quit%s\n\n"
                      (if has-more "  [l] load more" "")))
      (cl-loop for item in page-items
               for i from start
               do (insert (format " %4d. %s\n" (1+ i)
                                  (funcall musicbrainz-org--select-format-func item)))))))

(defun musicbrainz-org--select-current-item ()
  "Return the item at point in the selection buffer."
  (let* ((line (line-number-at-pos))
         (page musicbrainz-org--select-page)
         (page-size musicbrainz-org--select-page-size)
         (idx (+ (* page page-size) (- line 4))))
    (when (and (>= idx 0) (< idx (length musicbrainz-org--select-items)))
      (nth idx musicbrainz-org--select-items))))

(defun musicbrainz-org--select-choose ()
  "Select the item at point."
  (interactive)
  (let ((item (musicbrainz-org--select-current-item))
        (callback musicbrainz-org--select-callback)
        (buf (current-buffer)))
    (if item
        (progn
          (kill-buffer buf)
          (funcall callback item))
      (message "No item at this line"))))

(defun musicbrainz-org--select-next-page ()
  "Go to the next page."
  (interactive)
  (let ((next-page (1+ musicbrainz-org--select-page))
        (items musicbrainz-org--select-items)
        (page-size musicbrainz-org--select-page-size))
    (if (< (* next-page page-size) (length items))
        (progn
          (setq musicbrainz-org--select-page next-page)
          (musicbrainz-org--select-redraw)
          (goto-char (point-min))
          (forward-line 3))
      (if musicbrainz-org--select-total
          (message "Already on the last page")
        (musicbrainz-org--select-load-page next-page)))))

(defun musicbrainz-org--select-prev-page ()
  "Go to the previous page."
  (interactive)
  (if (> musicbrainz-org--select-page 0)
      (progn
        (setq musicbrainz-org--select-page (1- musicbrainz-org--select-page))
        (musicbrainz-org--select-redraw)
        (goto-char (point-min))
        (forward-line 3))
    (message "Already on the first page")))

(defun musicbrainz-org--select-load-more ()
  "Load the next page of results."
  (interactive)
  (musicbrainz-org--select-load-page (1+ musicbrainz-org--select-page)))

(defun musicbrainz-org--select-quit ()
  "Quit the selection buffer without selecting."
  (interactive)
  (kill-buffer (current-buffer)))

(defvar musicbrainz-org-select-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "RET") #'musicbrainz-org--select-choose)
    (define-key map (kbd "n")   #'musicbrainz-org--select-next-page)
    (define-key map (kbd "p")   #'musicbrainz-org--select-prev-page)
    (define-key map (kbd "l")   #'musicbrainz-org--select-load-more)
    (define-key map (kbd "q")   #'musicbrainz-org--select-quit)
    map)
  "Keymap for MusicBrainz selection buffer.")

(define-derived-mode musicbrainz-org-select-mode special-mode "MB-Select"
  "Major mode for selecting MusicBrainz entities."
  (setq truncate-lines t))

(defun musicbrainz-org--format-artist-for-selection (artist)
  "Format ARTIST for selection display."
  (format "%s (%s%s%s)"
          (oref artist name)
          (if (oref artist type) (oref artist type) "Unknown")
          (if (oref artist country) (format ", %s" (oref artist country)) "")
          (if (oref artist disambiguation) (format ", %s" (oref artist disambiguation)) "")))

(defun musicbrainz-org--format-release-for-selection (release)
  "Format RELEASE for selection display."
  (format "%s - %s (%s%s%s)"
          (if (oref release artist) (oref release artist) "Unknown")
          (oref release title)
          (if (oref release date) (oref release date) "Unknown date")
          (if (oref release country) (format ", %s" (oref release country)) "")
          (if (oref release status) (format ", %s" (oref release status)) "")))

(defun musicbrainz-org--format-label-for-selection (label)
  "Format LABEL for selection display."
  (format "%s (%s%s%s)"
          (oref label name)
          (if (oref label type) (oref label type) "Unknown")
          (if (oref label country) (format ", %s" (oref label country)) "")
          (if (oref label disambiguation) (format ", %s" (oref label disambiguation)) "")))

(defun musicbrainz-org--format-work-for-selection (work)
  "Format WORK for selection display."
  (format "%s (%s%s)"
          (oref work title)
          (if (oref work type) (oref work type) "Unknown")
          (if (oref work language) (format ", %s" (oref work language)) "")))

(defun musicbrainz-org--format-area-for-selection (area)
  "Format AREA for selection display."
  (format "%s (%s%s)"
          (oref area name)
          (if (oref area type) (oref area type) "Unknown")
          (if (oref area country-code) (format ", %s" (oref area country-code)) "")))

(defun musicbrainz-org--format-event-for-selection (event)
  "Format EVENT for selection display."
  (format "%s (%s%s)"
          (oref event name)
          (if (oref event type) (oref event type) "Unknown")
          (if (oref event time) (format ", %s" (oref event time)) "")))

(defun musicbrainz-org--format-instrument-for-selection (instrument)
  "Format INSTRUMENT for selection display."
  (format "%s (%s)"
          (oref instrument name)
          (if (oref instrument type) (oref instrument type) "Unknown")))

(defun musicbrainz-org--format-place-for-selection (place)
  "Format PLACE for selection display."
  (format "%s (%s%s)"
          (oref place name)
          (if (oref place type) (oref place type) "Unknown")
          (if (oref place address) (format ", %s" (oref place address)) "")))

(defun musicbrainz-org--format-series-for-selection (series)
  "Format SERIES for selection display."
  (format "%s (%s)"
          (oref series name)
          (if (oref series type) (oref series type) "Unknown")))

(defun musicbrainz-org--format-url-for-selection (url)
  "Format URL for selection display."
  (format "%s" (oref url resource)))

(defun musicbrainz-org--format-recording-for-selection (recording)
  "Format RECORDING for selection display."
  (format "%s - %s (%s%s)"
          (if-let* ((ac (oref recording artist-credit)))
              (if (consp ac)
                  (alist-get 'name (car (alist-get 'artist (car ac))))
                "Unknown")
            "Unknown")
          (oref recording title)
          (if (oref recording first-release-date)
              (oref recording first-release-date) "Unknown date")
          (if (oref recording length)
              (format ", %d:%02d" (/ (oref recording length) 60000)
                       (/ (mod (oref recording length) 60000) 1000))
            "")))

(defun musicbrainz-org--format-release-group-for-selection (rg)
  "Format RELEASE-GROUP for selection display."
  (format "%s - %s (%s)"
          (if-let* ((ac (oref rg artist-credit)))
              (if (consp ac)
                  (alist-get 'name (car (alist-get 'artist (car ac))))
                "Unknown")
            "Unknown")
          (oref rg title)
          (if (oref rg first-release-date)
              (oref rg first-release-date) "Unknown date")))

(defun musicbrainz-org--format-genre-for-selection (genre)
  "Format GENRE for selection display."
  (format "%s%s"
          (oref genre name)
          (if (oref genre disambiguation)
              (format " (%s)" (oref genre disambiguation)) "")))

;;; Additional format functions for new entities

(defun musicbrainz-org--format-relation-for-selection (relation)
  "Format RELATION for selection display."
  (format "%s -> %s%s"
          (oref relation type)
          (oref relation target-type)
          (if (oref relation ended) " (ended)" "")))

(defun musicbrainz-org--format-annotation-for-selection (annotation)
  "Format ANNOTATION for selection display."
  (format "%s: %s"
          (oref annotation type)
          (if-let* ((text (oref annotation text)))
              (substring text 0 (min 50 (length text)))
            "No text")))

(defun musicbrainz-org--format-collection-for-selection (collection)
  "Format COLLECTION for selection display."
  (format "%s (%d items)"
          (oref collection name)
          (or (oref collection entity-count) 0)))

(defun musicbrainz-org--format-cdstub-for-selection (cdstub)
  "Format CDSTUB for selection display."
  (format "%s - %s"
          (or (oref cdstub artist) "Unknown")
          (or (oref cdstub title) "Unknown")))

(defun musicbrainz-org--format-disc-for-selection (disc)
  "Format DISC for selection display."
  (format "Disc ID: %s (%d releases)"
          (oref disc id)
          (length (or (oref disc release-list) '()))))

(defun musicbrainz-org--format-isrc-for-selection (isrc)
  "Format ISRC for selection display."
  (format "ISRC: %s (%d recordings)"
          (oref isrc id)
          (length (or (oref isrc recording-list) '()))))

(defun musicbrainz-org--format-iswc-for-selection (iswc)
  "Format ISWC for selection display."
  (format "ISWC: %s (%d works)"
          (oref iswc id)
          (length (or (oref iswc work-list) '()))))

(defun musicbrainz-org--format-puid-for-selection (puid)
  "Format PUID for selection display."
  (format "PUID: %s (%d recordings)"
          (oref puid id)
          (length (or (oref puid recording-list) '()))))

(defun musicbrainz-org--format-tag-for-selection (tag)
  "Format TAG for selection display."
  (format "%s%s"
          (oref tag name)
          (if-let* ((count (oref tag count)))
              (format " (%d)" count) "")))

(defun musicbrainz-org--format-medium-for-selection (medium)
  "Format MEDIUM for selection display."
  (format "%s - %s"
          (or (oref medium format) "Unknown format")
          (or (oref medium title) (format "Position %d" (or (oref medium position) 0)))))

(defun musicbrainz-org--format-track-for-selection (track)
  "Format TRACK for selection display."
  (format "%s. %s%s"
          (or (oref track number) "?")
          (oref track title)
          (if-let* ((length (oref track length)))
              (format " (%d:%02d)" (/ length 60000) (/ (mod length 60000) 1000))
            "")))

;;; Insert functions

;;;###autoload
(defun musicbrainz-org-insert-artist (artist &optional level)
  "Insert ARTIST as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if artist
        (progn
          (insert (make-string level ?*) " " (oref artist name) "\n")
          (musicbrainz-org--insert-properties artist)
          (musicbrainz-org--insert-link "artist" (oref artist id))
          (insert "\n"))
      (let ((query (read-string "Search artist: ")))
        (musicbrainz-org--search-async
         query "artist" 'artists
         '(lambda (item)
            (format "%s (%s%s%s)"
                    (or (alist-get 'name item) "?")
                    (or (alist-get 'type item) "Unknown")
                    (if-let* ((c (alist-get 'country item))) (format ", %s" c) "")
                    (if-let* ((d (alist-get 'disambiguation item))) (format ", %s" d) "")))
         #'musicbrainz--parse-artist
         #'musicbrainz-org-insert-artist level)))))

;;;###autoload
(defun musicbrainz-org-insert-release (release &optional level)
  "Insert RELEASE as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if release
        (progn
          (insert (make-string level ?*) " " (oref release title) "\n")
          (musicbrainz-org--insert-properties release)
          (when (and (slot-exists-p release 'artist-credit)
                     (slot-boundp release 'artist-credit)
                     (oref release artist-credit))
            (musicbrainz-org-insert-artist-credit (oref release artist-credit) (1+ level)))
          (when (and (slot-exists-p release 'tracks)
                     (slot-boundp release 'tracks)
                     (oref release tracks))
            (musicbrainz-org-insert-tracklist (oref release tracks) (1+ level)))
          (musicbrainz-org--insert-link "release" (oref release id))
          (insert "\n"))
      (let ((query (read-string "Search release: ")))
        (musicbrainz-org--search-async
         query "release" 'releases
         '(lambda (item)
            (let ((ac (alist-get 'artist-credit item)))
              (format "%s - %s (%s%s%s)"
                      (if (consp ac)
                          (or (alist-get 'name (car (alist-get 'artist (car ac)))) "Unknown")
                        "Unknown")
                      (or (alist-get 'title item) "?")
                      (or (alist-get 'date item) "Unknown date")
                      (if-let* ((c (alist-get 'country item))) (format ", %s" c) "")
                      (if-let* ((s (alist-get 'status item))) (format ", %s" s) ""))))
         #'musicbrainz--parse-release
         #'musicbrainz-org-insert-release level)))))

;;;###autoload
(defun musicbrainz-org-insert-label (label &optional level)
  "Insert LABEL as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if label
        (progn
          (insert (make-string level ?*) " " (oref label name) "\n")
          (musicbrainz-org--insert-properties label)
          (musicbrainz-org--insert-link "label" (oref label id))
          (insert "\n"))
      (let ((query (read-string "Search label: ")))
        (musicbrainz-org--search-async
         query "label" 'labels
         '(lambda (item)
            (format "%s (%s%s%s)"
                    (or (alist-get 'name item) "?")
                    (or (alist-get 'type item) "Unknown")
                    (if-let* ((c (alist-get 'country item))) (format ", %s" c) "")
                    (if-let* ((d (alist-get 'disambiguation item))) (format ", %s" d) "")))
         #'musicbrainz--parse-label
         #'musicbrainz-org-insert-label level)))))

;;;###autoload
(defun musicbrainz-org-insert-work (work &optional level)
  "Insert WORK as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if work
        (progn
          (insert (make-string level ?*) " " (oref work title) "\n")
          (musicbrainz-org--insert-properties work)
          (musicbrainz-org--insert-link "work" (oref work id))
          (insert "\n"))
      (let ((query (read-string "Search work: ")))
        (musicbrainz-org--search-async
         query "work" 'works
         '(lambda (item)
            (format "%s (%s%s)"
                    (or (alist-get 'title item) "?")
                    (or (alist-get 'type item) "Unknown")
                    (if-let* ((l (alist-get 'language item))) (format ", %s" l) "")))
         #'musicbrainz--parse-work
         #'musicbrainz-org-insert-work level)))))

;;;###autoload
(defun musicbrainz-org-insert-area (area &optional level)
  "Insert AREA as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if area
        (progn
          (insert (make-string level ?*) " " (oref area name) "\n")
          (musicbrainz-org--insert-properties area)
          (musicbrainz-org--insert-link "area" (oref area id))
          (insert "\n"))
      (let ((query (read-string "Search area: ")))
        (musicbrainz-org--search-async
         query "area" 'areas
         '(lambda (item)
            (format "%s (%s%s)"
                    (or (alist-get 'name item) "?")
                    (or (alist-get 'type item) "Unknown")
                    (if-let* ((cc (alist-get 'iso-3166-1-codes item)))
                        (format ", %s" (if (listp cc) (mapconcat #'identity cc "/") cc)) "")))
         #'musicbrainz--parse-area
         #'musicbrainz-org-insert-area level)))))

;;;###autoload
(defun musicbrainz-org-insert-event (event &optional level)
  "Insert EVENT as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if event
        (progn
          (insert (make-string level ?*) " " (oref event name) "\n")
          (musicbrainz-org--insert-properties event)
          (musicbrainz-org--insert-link "event" (oref event id))
          (insert "\n"))
      (let ((query (read-string "Search event: ")))
        (musicbrainz-org--search-async
         query "event" 'events
         '(lambda (item)
            (format "%s (%s%s)"
                    (or (alist-get 'name item) "?")
                    (or (alist-get 'type item) "Unknown")
                    (if-let* ((t2 (alist-get 'time item))) (format ", %s" t2) "")))
         #'musicbrainz--parse-event
         #'musicbrainz-org-insert-event level)))))

;;;###autoload
(defun musicbrainz-org-insert-instrument (instrument &optional level)
  "Insert INSTRUMENT as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if instrument
        (progn
          (insert (make-string level ?*) " " (oref instrument name) "\n")
          (musicbrainz-org--insert-properties instrument)
          (musicbrainz-org--insert-link "instrument" (oref instrument id))
          (insert "\n"))
      (let ((query (read-string "Search instrument: ")))
        (musicbrainz-org--search-async
         query "instrument" 'instruments
         '(lambda (item)
            (format "%s (%s)"
                    (or (alist-get 'name item) "?")
                    (or (alist-get 'type item) "Unknown")))
         #'musicbrainz--parse-instrument
         #'musicbrainz-org-insert-instrument level)))))

;;;###autoload
(defun musicbrainz-org-insert-place (place &optional level)
  "Insert PLACE as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if place
        (progn
          (insert (make-string level ?*) " " (oref place name) "\n")
          (musicbrainz-org--insert-properties place)
          (musicbrainz-org--insert-link "place" (oref place id))
          (insert "\n"))
      (let ((query (read-string "Search place: ")))
        (musicbrainz-org--search-async
         query "place" 'places
         '(lambda (item)
            (format "%s (%s%s)"
                    (or (alist-get 'name item) "?")
                    (or (alist-get 'type item) "Unknown")
                    (if-let* ((addr (alist-get 'address item))) (format ", %s" addr) "")))
         #'musicbrainz--parse-place
         #'musicbrainz-org-insert-place level)))))

;;;###autoload
(defun musicbrainz-org-insert-series (series &optional level)
  "Insert SERIES as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if series
        (progn
          (insert (make-string level ?*) " " (oref series name) "\n")
          (musicbrainz-org--insert-properties series)
          (musicbrainz-org--insert-link "series" (oref series id))
          (insert "\n"))
      (let ((query (read-string "Search series: ")))
        (musicbrainz-org--search-async
         query "series" 'series
         '(lambda (item)
            (format "%s (%s)"
                    (or (alist-get 'name item) "?")
                    (or (alist-get 'type item) "Unknown")))
         #'musicbrainz--parse-series
         #'musicbrainz-org-insert-series level)))))

;;;###autoload
(defun musicbrainz-org-insert-url (url &optional level)
  "Insert URL as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if url
        (progn
          (insert (make-string level ?*) " " (oref url resource) "\n")
          (musicbrainz-org--insert-properties url)
          (insert (format "[[%s][%s]]\n" (oref url resource) (oref url resource)))
          (insert "\n"))
      (let ((query (read-string "Search URL: ")))
        (musicbrainz-org--search-async
         query "url" 'urls
         '(lambda (item) (format "%s" (or (alist-get 'resource item) "?")))
         #'musicbrainz--parse-url
         #'musicbrainz-org-insert-url level)))))

;;;###autoload
(defun musicbrainz-org-insert-genre (genre &optional level)
  "Insert GENRE as Org heading at LEVEL.
When called interactively, uses cached genres or loads them asynchronously.
Uses file caching (musicbrainz-genres.eld) for faster subsequent access."
  (interactive
   (list
    (let ((cached (musicbrainz--load-genres-from-file)))
      (if cached
          (let ((formatted (mapcar (lambda (g) (cons (oref g name) g)) cached)))
            (cdr (assoc (completing-read "Select genre: " formatted nil t) formatted)))
        (message "No genre cache found. Loading asynchronously...")
        (musicbrainz-browse-genres-async
         (lambda (genres)
           (let ((formatted (mapcar (lambda (g) (cons (oref g name) g)) genres)))
             (cdr (assoc (completing-read "Select genre: " formatted nil t) formatted)))))
        nil))
    musicbrainz-org-default-level))
  (when genre
    (let ((level (or level musicbrainz-org-default-level)))
      (insert (make-string level ?*) " " (oref genre name) "\n")
      (musicbrainz-org--insert-properties genre)
      (musicbrainz-org--insert-link "genre" (oref genre id))
      (insert "\n"))))

;;;###autoload
(defun musicbrainz-org-refresh-genre-cache ()
  "Refresh genre cache asynchronously from MusicBrainz."
  (interactive)
  (message "Refreshing genre cache from MusicBrainz...")
  (musicbrainz-browse-genres-async
   (lambda (genres)
     (message "Genre cache refreshed: %d genres available" (length genres)))))

;;;###autoload
(defun musicbrainz-org-insert-recording (recording &optional level)
  "Insert RECORDING as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if recording
        (progn
          (insert (make-string level ?*) " " (oref recording title) "\n")
          (musicbrainz-org--insert-properties recording)
          (when (and (slot-exists-p recording 'artist-credit)
                     (slot-boundp recording 'artist-credit)
                     (oref recording artist-credit))
            (musicbrainz-org-insert-artist-credit (oref recording artist-credit) (1+ level)))
          (when (oref recording first-release-date)
            (insert (format "First released: %s\n" (oref recording first-release-date))))
          (musicbrainz-org--insert-link "recording" (oref recording id))
          (insert "\n"))
      (let ((query (read-string "Search recording: ")))
        (musicbrainz-org--search-async
         query "recording" 'recordings
         '(lambda (item)
            (let ((ac (alist-get 'artist-credit item)))
              (format "%s - %s (%s)"
                      (if (consp ac)
                          (or (alist-get 'name (car (alist-get 'artist (car ac)))) "Unknown")
                        "Unknown")
                      (or (alist-get 'title item) "?")
                      (or (alist-get 'first-release-date item) "Unknown date"))))
         #'musicbrainz--parse-recording
         #'musicbrainz-org-insert-recording level)))))

;;;###autoload
(defun musicbrainz-org-insert-release-group (release-group &optional level)
  "Insert RELEASE-GROUP as Org heading at LEVEL.
When called interactively, searches asynchronously and selects one to insert."
  (interactive (list nil (or musicbrainz-org-default-level 2)))
  (let ((level (or level musicbrainz-org-default-level)))
    (if release-group
        (progn
          (insert (make-string level ?*) " " (oref release-group title) "\n")
          (musicbrainz-org--insert-properties release-group)
          (when (and (slot-exists-p release-group 'artist-credit)
                     (slot-boundp release-group 'artist-credit)
                     (oref release-group artist-credit))
            (musicbrainz-org-insert-artist-credit (oref release-group artist-credit) (1+ level)))
          (musicbrainz-org--insert-link "release-group" (oref release-group id))
          (insert "\n"))
      (let ((query (read-string "Search release group: ")))
        (musicbrainz-org--search-async
         query "release-group" 'release-groups
         '(lambda (item)
            (let ((ac (alist-get 'artist-credit item)))
              (format "%s - %s (%s)"
                      (if (consp ac)
                          (or (alist-get 'name (car (alist-get 'artist (car ac)))) "Unknown")
                        "Unknown")
                      (or (alist-get 'title item) "?")
                      (or (alist-get 'first-release-date item) "Unknown date"))))
         #'musicbrainz--parse-release-group
         #'musicbrainz-org-insert-release-group level)))))

;;; Interactive functions with selection

;;;###autoload
(defun musicbrainz-org-search-and-insert-artist (query &optional level)
  "Search for artist and insert result at point with selection."
  (interactive "sSearch artist: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-artist q limit offset))
                   #'musicbrainz-org--format-artist-for-selection)))
    (if selected
        (musicbrainz-org-insert-artist selected level)
      (message "No artist found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-release (query &optional level)
  "Search for release and insert result at point with selection."
  (interactive "sSearch release: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-release q limit offset))
                   #'musicbrainz-org--format-release-for-selection)))
    (if selected
        (musicbrainz-org-insert-release selected level)
      (message "No release found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-label (query &optional level)
  "Search for label and insert result at point with selection."
  (interactive "sSearch label: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-label q limit offset))
                   #'musicbrainz-org--format-label-for-selection)))
    (if selected
        (musicbrainz-org-insert-label selected level)
      (message "No label found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-work (query &optional level)
  "Search for work and insert result at point with selection."
  (interactive "sSearch work: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-work q limit offset))
                   #'musicbrainz-org--format-work-for-selection)))
    (if selected
        (musicbrainz-org-insert-work selected level)
      (message "No work found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-area (query &optional level)
  "Search for area and insert result at point with selection."
  (interactive "sSearch area: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-area q limit offset))
                   #'musicbrainz-org--format-area-for-selection)))
    (if selected
        (musicbrainz-org-insert-area selected level)
      (message "No area found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-event (query &optional level)
  "Search for event and insert result at point with selection."
  (interactive "sSearch event: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-event q limit offset))
                   #'musicbrainz-org--format-event-for-selection)))
    (if selected
        (musicbrainz-org-insert-event selected level)
      (message "No event found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-instrument (query &optional level)
  "Search for instrument and insert result at point with selection."
  (interactive "sSearch instrument: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-instrument q limit offset))
                   #'musicbrainz-org--format-instrument-for-selection)))
    (if selected
        (musicbrainz-org-insert-instrument selected level)
      (message "No instrument found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-place (query &optional level)
  "Search for place and insert result at point with selection."
  (interactive "sSearch place: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-place q limit offset))
                   #'musicbrainz-org--format-place-for-selection)))
    (if selected
        (musicbrainz-org-insert-place selected level)
      (message "No place found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-series (query &optional level)
  "Search for series and insert result at point with selection."
  (interactive "sSearch series: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-series q limit offset))
                   #'musicbrainz-org--format-series-for-selection)))
    (if selected
        (musicbrainz-org-insert-series selected level)
      (message "No series found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-url (query &optional level)
  "Search for URL and insert result at point with selection."
  (interactive "sSearch URL: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-url q limit offset))
                   #'musicbrainz-org--format-url-for-selection)))
    (if selected
        (musicbrainz-org-insert-url selected level)
      (message "No URL found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-recording (query &optional level)
  "Search for recording and insert result at point with selection."
  (interactive "sSearch recording: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-recording q limit offset))
                   #'musicbrainz-org--format-recording-for-selection)))
    (if selected
        (musicbrainz-org-insert-recording selected level)
      (message "No recording found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-search-and-insert-release-group (query &optional level)
  "Search for release group and insert result at point with selection."
  (interactive "sSearch release group: ")
  (let ((selected (musicbrainz-org--select-item-progressive
                   query
                   (lambda (q limit offset) (musicbrainz-search-release-group q limit offset))
                   #'musicbrainz-org--format-release-group-for-selection)))
    (if selected
        (musicbrainz-org-insert-release-group selected level)
      (message "No release group found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-insert-genre-from-release (query &optional level)
  "Search for releases by QUERY, get their genres, and insert them.
This automates getting MBID and inserting genre fields."
  (interactive "sSearch release for genres: ")
  (let* ((releases (musicbrainz-search-release query 10)) ; Get more results
         (found-genres nil)
         (found-release nil))
    ;; Try to find genres from any release with a release-group
    (dolist (release releases)
      (when (and (not found-genres) (oref release release-group-id))
         (let* ((rg-object (musicbrainz-lookup-release-group (oref release release-group-id) "genres"))
               (genres (when rg-object (oref rg-object genres))))
          (when genres
            (setq found-genres genres)
            (setq found-release release)))))

    (if found-genres
        (let ((level (or level musicbrainz-org-default-level)))
          (insert (format "\n%s Genres for %s\n" (make-string level ?*) (oref found-release title)))
          (cl-loop for genre across found-genres
                   for genre-name = (alist-get 'name genre)
                   for genre-id = (alist-get 'id genre)
                   do (insert (format "- %s [genre:%s]\n" genre-name genre-id))))
      (message "No genres found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-insert-genre-from-artist (query &optional level)
  "Search for an artist by QUERY, get genres from their releases, and insert them.
This automates getting MBID and inserting genre fields."
  (interactive "sSearch artist for genres: ")
  (let* ((artists (musicbrainz-search-artist query 1))
         (artist (car artists)))
    (if artist
         (let* ((artist-object (musicbrainz-lookup-artist (oref artist id) "genres"))
               (genres (when artist-object (oref artist-object genres))))
          (if genres
              (let ((level (or level musicbrainz-org-default-level)))
                (insert (format "\n%s Genres for %s\n" (make-string level ?*) (oref artist name)))
                (cl-loop for genre across genres
                         for genre-name = (alist-get 'name genre)
                         for genre-id = (alist-get 'id genre)
                         do (insert (format "- %s [genre:%s]\n" genre-name genre-id))))
            (message "No genres found for artist: %s" (oref artist name))))
      (message "No artist found for query: %s" query))))

;;; Batch insertion functions

;;;###autoload
(defun musicbrainz-org-insert-search-results (entity-type query &optional level)
  "Insert multiple search results for ENTITY-TYPE and QUERY.
Shows selection interface if multiple results are found."
   (interactive
    (list (completing-read "Entity type: "
                           '("artist" "release" "release-group" "recording" "label" "work" "area"
                             "event" "instrument" "place" "series" "url" "genre"))
          (read-string "Search query: ")))
    (let* ((level (or level musicbrainz-org-default-level))
           (results (cond
                     ((equal entity-type "artist") (musicbrainz-search-artist query))
                     ((equal entity-type "release") (musicbrainz-search-release query))
                     ((equal entity-type "release-group") (musicbrainz-search-release-group query))
                     ((equal entity-type "recording") (musicbrainz-search-recording query))
                     ((equal entity-type "label") (musicbrainz-search-label query))
                     ((equal entity-type "work") (musicbrainz-search-work query))
                     ((equal entity-type "area") (musicbrainz-search-area query))
                     ((equal entity-type "event") (musicbrainz-search-event query))
                     ((equal entity-type "instrument") (musicbrainz-search-instrument query))
                     ((equal entity-type "place") (musicbrainz-search-place query))
                     ((equal entity-type "series") (musicbrainz-search-series query))
                     ((equal entity-type "url") (musicbrainz-search-url query))
                     ((equal entity-type "genre") (message "Genre search is not supported by MusicBrainz API") nil))))
      (if results
          (progn
            (insert (format "\n* MusicBrainz %s search results for \"%s\"\n\n"
                            (capitalize entity-type) query))
            (dolist (result results)
              (cond
               ((equal entity-type "artist") (musicbrainz-org-insert-artist result level))
               ((equal entity-type "release") (musicbrainz-org-insert-release result level))
               ((equal entity-type "release-group") (musicbrainz-org-insert-release-group result level))
               ((equal entity-type "recording") (musicbrainz-org-insert-recording result level))
               ((equal entity-type "label") (musicbrainz-org-insert-label result level))
               ((equal entity-type "work") (musicbrainz-org-insert-work result level))
               ((equal entity-type "area") (musicbrainz-org-insert-area result level))
               ((equal entity-type "event") (musicbrainz-org-insert-event result level))
               ((equal entity-type "instrument") (musicbrainz-org-insert-instrument result level))
               ((equal entity-type "place") (musicbrainz-org-insert-place result level))
               ((equal entity-type "series") (musicbrainz-org-insert-series result level))
               ((equal entity-type "url") (musicbrainz-org-insert-url result level))))
            (message "Inserted %d %s results" (length results) entity-type))
       (message "No results found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-insert-lookup (entity-type mbid &optional level)
  "Insert lookup result for ENTITY-TYPE and MBID."
   (interactive
    (list (completing-read "Entity type: "
                           '("artist" "release" "release-group" "recording" "label" "work"
                             "area" "event" "instrument" "place" "series" "url" "genre"))
          (read-string "MBID: ")))
   (let* ((level (or level musicbrainz-org-default-level))
          (result (cond
                   ((equal entity-type "artist") (musicbrainz-lookup-artist mbid))
                   ((equal entity-type "release") (musicbrainz-lookup-release mbid))
                   ((equal entity-type "release-group") (musicbrainz-lookup-release-group mbid))
                   ((equal entity-type "recording") (musicbrainz-lookup-recording mbid))
                   ((equal entity-type "label") (musicbrainz-lookup-label mbid))
                   ((equal entity-type "work") (musicbrainz-lookup-work mbid))
                   ((equal entity-type "area") (musicbrainz-lookup-area mbid))
                   ((equal entity-type "event") (musicbrainz-lookup-event mbid))
                   ((equal entity-type "instrument") (musicbrainz-lookup-instrument mbid))
                   ((equal entity-type "place") (musicbrainz-lookup-place mbid))
                    ((equal entity-type "series") (musicbrainz-lookup-series mbid))
                    ((equal entity-type "url") (musicbrainz-lookup-url mbid))
                    ((equal entity-type "genre") (musicbrainz-lookup-genre mbid)))))
     (if result
         (cond
          ((equal entity-type "artist") (musicbrainz-org-insert-artist result level))
          ((equal entity-type "release") (musicbrainz-org-insert-release result level))
          ((equal entity-type "release-group") (musicbrainz-org-insert-release-group result level))
          ((equal entity-type "recording") (musicbrainz-org-insert-recording result level))
          ((equal entity-type "label") (musicbrainz-org-insert-label result level))
          ((equal entity-type "work") (musicbrainz-org-insert-work result level))
          ((equal entity-type "area") (musicbrainz-org-insert-area result level))
          ((equal entity-type "event") (musicbrainz-org-insert-event result level))
          ((equal entity-type "instrument") (musicbrainz-org-insert-instrument result level))
          ((equal entity-type "place") (musicbrainz-org-insert-place result level))
           ((equal entity-type "series") (musicbrainz-org-insert-series result level))
           ((equal entity-type "url") (musicbrainz-org-insert-url result level))
           ((equal entity-type "genre") (musicbrainz-org-insert-genre result level)))
       (message "No result found for MBID: %s" mbid))))

;;; Org capture integration

;;;###autoload
(defun musicbrainz-org-capture-artist (query)
  "Capture artist search result to Org capture template."
  (interactive "sSearch artist: ")
  (let ((artists (musicbrainz-search-artist query 1)))
    (if artists
        (let ((artist (car artists)))
          (org-capture nil "a")
          (insert (oref artist name) "\n")
          (musicbrainz-org--insert-properties artist)
          (musicbrainz-org--insert-link "artist" (oref artist id)))
      (message "No artist found for query: %s" query))))

;;;###autoload
(defun musicbrainz-org-capture-release (query)
  "Capture release search result to Org capture template."
  (interactive "sSearch release: ")
  (let ((releases (musicbrainz-search-release query 1)))
    (if releases
        (let ((release (car releases)))
          (org-capture nil "a")
          (insert (oref release title) "\n")
          (musicbrainz-org--insert-properties release)
          (musicbrainz-org--insert-link "release" (oref release id)))
      (message "No release found for query: %s" query))))
;;; Utility functions

(defun musicbrainz-org-insert-artist-credit (artist-credit &optional level)
  "Insert artist credit as Org formatted text."
  (when artist-credit
    (let ((level (or level (1+ musicbrainz-org-default-level))))
      (insert (make-string level ?*) " Artist Credit\n")
      (mapc (lambda (credit)
              (let* ((artist (alist-get 'artist credit))
                     (name (alist-get 'name credit))
                     (artist-name (or name (alist-get 'name artist))))
                (insert (format "  - %s\n" artist-name))))
            artist-credit)
      (insert "\n"))))

(defun musicbrainz-org-insert-tracklist (tracks &optional level)
  "Insert tracklist as Org list."
  (when tracks
    (let ((level (or level (1+ musicbrainz-org-default-level))))
      (insert (make-string level ?*) " Tracklist\n")
      (mapc (lambda (track)
              (let ((track-name (alist-get 'title track)))
                (insert (format "  - %s\n" track-name))))
            tracks)
      (insert "\n"))))

;;; Cover Art

;;;###autoload
(defun musicbrainz-org-insert-tracklist-for-release (&optional level)
  "Search for a release, look up its tracklist, and insert at LEVEL."
  (interactive (list musicbrainz-org-default-level))
  (let ((target-buf (current-buffer))
        (level (or level musicbrainz-org-default-level)))
    (musicbrainz--request "release" (read-string "Search release for tracklist: ") 10 0
      (lambda (json)
        (let* ((raw (when json (alist-get 'releases json)))
               (items (if (vectorp raw) (append raw nil) raw)))
          (if items
              (let* ((formatted (mapcar
                                 '(lambda (item)
                                    (let ((ac (alist-get 'artist-credit item)))
                                      (format "%s - %s (%s)"
                                              (if (consp ac)
                                                  (or (alist-get 'name (car (alist-get 'artist (car ac)))) "Unknown")
                                                "Unknown")
                                              (or (alist-get 'title item) "?")
                                              (or (alist-get 'date item) "?"))))
                                 items))
                     (choice (completing-read
                              (format "Select [%d]: " (length formatted))
                              formatted nil t)))
                (when choice
                  (let* ((pos (cl-position choice formatted :test 'equal))
                         (mbid (when pos (alist-get 'id (nth pos items)))))
                    (when mbid
                      (musicbrainz-lookup-release mbid "recordings"
                        (lambda (release)
                          (with-current-buffer target-buf
                            (let ((tracks (when release (oref release tracks))))
                              (if tracks
                                  (musicbrainz-org-insert-tracklist tracks level)
                                (message "No tracks found"))))))))))
            (message "No releases found")))))))

;;;###autoload
(defun musicbrainz-org-insert-cover-art (mbid &optional level)
  "Insert cover art image link for release MBID at LEVEL.
Looks up front cover from coverartarchive.org."
  (interactive
   (let* ((query (read-string "Search release for cover art: "))
          (releases (condition-case nil
                        (musicbrainz-search-release query 10 0)
                      (error nil)))
          (formatted (mapcar (lambda (r)
                               (cons (format "%s - %s"
                                             (or (oref r artist) "?")
                                             (oref r title))
                                     r))
                             releases))
          (choice (when formatted
                    (completing-read "Select release: " formatted nil t)))
          (selected (when choice (cdr (assoc choice formatted)))))
     (list (if selected (oref selected id) "")
           musicbrainz-org-default-level)))
  (when (and mbid (> (length mbid) 0))
    (let ((level (or level musicbrainz-org-default-level))
          (url (musicbrainz-cover-art-url mbid 500)))
      (insert (make-string level ?*) " Cover Art\n")
      (insert (format "[[%s]]\n" url))
      (when (fboundp 'org-display-inline-images)
        (org-display-inline-images nil nil (point-min) (point)))
      (insert "\n"))))

;;; Additional insert functions for new entities

;;;###autoload
(defun musicbrainz-org-insert-relations (entity-type mbid &optional level)
  "Insert relations for ENTITY-TYPE by MBID at LEVEL."
  (interactive
   (list (completing-read "Entity type: "
                          '("artist" "release" "recording" "work" "label"))
         (read-string "MBID: ")
         musicbrainz-org-default-level))
  (let ((level (or level musicbrainz-org-default-level))
        (target-buf (current-buffer)))
    (cond
     ((string= entity-type "artist")
      (musicbrainz-lookup-artist-relations mbid
        (lambda (result)
          (with-current-buffer target-buf
            (let ((artist (plist-get result :artist))
                  (relations (plist-get result :relations)))
              (insert (make-string level ?*) " Relations for " (oref artist name) "\n")
              (dolist (rel relations)
                (insert (format "- %s -> %s%s\n"
                                (oref rel type)
                                (oref rel target-type)
                                (if (oref rel ended) " (ended)" ""))))
              (insert "\n"))))))
     ((string= entity-type "release")
      (musicbrainz-lookup-release-relations mbid
        (lambda (result)
          (with-current-buffer target-buf
            (let ((release (plist-get result :release))
                  (relations (plist-get result :relations)))
              (insert (make-string level ?*) " Relations for " (oref release title) "\n")
              (dolist (rel relations)
                (insert (format "- %s -> %s%s\n"
                                (oref rel type)
                                (oref rel target-type)
                                (if (oref rel ended) " (ended)" ""))))
              (insert "\n"))))))
     ((string= entity-type "recording")
      (musicbrainz-lookup-recording-relations mbid
        (lambda (result)
          (with-current-buffer target-buf
            (let ((recording (plist-get result :recording))
                  (relations (plist-get result :relations)))
              (insert (make-string level ?*) " Relations for " (oref recording title) "\n")
              (dolist (rel relations)
                (insert (format "- %s -> %s%s\n"
                                (oref rel type)
                                (oref rel target-type)
                                (if (oref rel ended) " (ended)" ""))))
              (insert "\n"))))))
     ((string= entity-type "work")
      (musicbrainz-lookup-work-relations mbid
        (lambda (result)
          (with-current-buffer target-buf
            (let ((work (plist-get result :work))
                  (relations (plist-get result :relations)))
              (insert (make-string level ?*) " Relations for " (oref work title) "\n")
              (dolist (rel relations)
                (insert (format "- %s -> %s%s\n"
                                (oref rel type)
                                (oref rel target-type)
                                (if (oref rel ended) " (ended)" ""))))
              (insert "\n"))))))
     ((string= entity-type "label")
      (musicbrainz-lookup-label-relations mbid
        (lambda (result)
          (with-current-buffer target-buf
            (let ((label (plist-get result :label))
                  (relations (plist-get result :relations)))
              (insert (make-string level ?*) " Relations for " (oref label name) "\n")
              (dolist (rel relations)
                (insert (format "- %s -> %s%s\n"
                                (oref rel type)
                                (oref rel target-type)
                                (if (oref rel ended) " (ended)" ""))))
              (insert "\n")))))))))

;;;###autoload
(defun musicbrainz-org-insert-disc-id-releases (disc-id &optional level)
  "Insert releases for DISC-ID at LEVEL."
  (interactive
   (list (read-string "Disc ID: ")
         musicbrainz-org-default-level))
  (let ((level (or level musicbrainz-org-default-level))
        (target-buf (current-buffer)))
    (musicbrainz-lookup-disc-id-releases disc-id
      (lambda (releases)
        (with-current-buffer target-buf
          (if releases
              (progn
                (insert (make-string level ?*) " Releases for Disc ID " disc-id "\n")
                (dolist (release releases)
                  (insert (format "- %s - %s (%s)\n"
                                  (or (oref release artist) "Unknown")
                                  (oref release title)
                                  (or (oref release date) "?"))))
                (insert "\n"))
            (message "No releases found for disc ID: %s" disc-id)))))))

;;;###autoload
(defun musicbrainz-org-insert-isrc-recordings (isrc &optional level)
  "Insert recordings for ISRC at LEVEL."
  (interactive
   (list (read-string "ISRC: ")
         musicbrainz-org-default-level))
  (let ((level (or level musicbrainz-org-default-level))
        (target-buf (current-buffer)))
    (musicbrainz-lookup-isrc-recordings isrc
      (lambda (recordings)
        (with-current-buffer target-buf
          (if recordings
              (progn
                (insert (make-string level ?*) " Recordings for ISRC " isrc "\n")
                (dolist (recording recordings)
                  (insert (format "- %s\n" (oref recording title))))
                (insert "\n"))
            (message "No recordings found for ISRC: %s" isrc)))))))

;;;###autoload
(defun musicbrainz-org-insert-iswc-works (iswc &optional level)
  "Insert works for ISWC at LEVEL."
  (interactive
   (list (read-string "ISWC: ")
         musicbrainz-org-default-level))
  (let ((level (or level musicbrainz-org-default-level))
        (target-buf (current-buffer)))
    (musicbrainz-lookup-iswc-works iswc
      (lambda (works)
        (with-current-buffer target-buf
          (if works
              (progn
                (insert (make-string level ?*) " Works for ISWC " iswc "\n")
                (dolist (work works)
                  (insert (format "- %s\n" (oref work title))))
                (insert "\n"))
            (message "No works found for ISWC: %s" iswc)))))))

;;;###autoload
(defun musicbrainz-org-insert-collection-releases (collection-id &optional level)
  "Insert releases for collection at LEVEL."
  (interactive
   (list (read-string "Collection ID: ")
         musicbrainz-org-default-level))
  (let ((level (or level musicbrainz-org-default-level))
        (target-buf (current-buffer)))
    (musicbrainz-lookup-collection-releases collection-id nil nil
      (lambda (releases)
        (with-current-buffer target-buf
          (if releases
              (progn
                (insert (make-string level ?*) " Releases in Collection " collection-id "\n")
                (dolist (release releases)
                  (insert (format "- %s - %s (%s)\n"
                                  (or (oref release artist) "Unknown")
                                  (oref release title)
                                  (or (oref release date) "?"))))
                (insert "\n"))
            (message "No releases found in collection: %s" collection-id)))))))

(provide 'musicbrainz-org)

;;; musicbrainz-org.el ends here

