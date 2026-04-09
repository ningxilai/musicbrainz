#' Async MusicBrainz API Client
#'
#' Asynchronous versions of MusicBrainz functions using the future package.
#' These functions return a future that will be resolved asynchronously.
#'
#' @description
#' To use async functions, you need to set a plan (e.g., \code{plan(multisession)}).
#' Then call async functions and use \code{resolved()} to check if results are ready,
#' or \code{value()} to retrieve the results.
#'
#' @note This module requires the \code{future} package. Install with:
#' \code{install.packages("future")}
#'
#' @examples
#' \dontrun{
#' library(future)
#' plan(multisession)
#'
#' # Launch async request
#' f <- lookup_artist_by_id_async("20ff3303-4fe2-4a47-a1b6-291e26aa3438")
#'
#' # Wait and get result
#' result <- value(f)
#' }
#'
#' @name async
NULL

#' @importFrom future future
#' @export
plan <- NULL

#' @describeIn async Lookup artist by MBID asynchronously
#' @param mbid MusicBrainz ID
#' @param includes Optional includes
#' @param format Format ("json" or "jsonld")
#' @note Note: When using multisession/multicore plans, ensure musicbrainz package is 
#'   installed (not just loaded via devtools::load_all). For development, use 
#'   \code{plan(sequential)} or \code{plan(tweak(multisession, workers = 1))}.
#' @export
lookup_artist_by_id_async <- function(mbid, includes = NULL, format = "json") {
  if (!requireNamespace("future", quietly = TRUE)) {
    stop("Package 'future' required. Install with: install.packages('future')")
  }
  future::future({
    lookup_artist_by_id(mbid, includes, format)
  }, seed = TRUE)
}
#' @param mbid MusicBrainz ID
#' @param includes Optional includes
#' @param format Format ("json" or "jsonld")
#' @export
lookup_artist_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_artist_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup area by MBID asynchronously
#' @export
lookup_area_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_area_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup event by MBID asynchronously
#' @export
lookup_event_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_event_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup instrument by MBID asynchronously
#' @export
lookup_instrument_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_instrument_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup label by MBID asynchronously
#' @export
lookup_label_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_label_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup place by MBID asynchronously
#' @export
lookup_place_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_place_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup recording by MBID asynchronously
#' @export
lookup_recording_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_recording_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup release by MBID asynchronously
#' @export
lookup_release_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_release_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup release-group by MBID asynchronously
#' @export
lookup_release_group_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_release_group_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup series by MBID asynchronously
#' @export
lookup_series_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_series_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup URL by MBID asynchronously
#' @export
lookup_url_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_url_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup work by MBID asynchronously
#' @export
lookup_work_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_work_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup genre by MBID asynchronously
#' @export
lookup_genre_by_id_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_genre_by_id(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Search artists asynchronously
#' @export
search_artists_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_artists(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search releases asynchronously
#' @export
search_releases_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_releases(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search release-groups asynchronously
#' @export
search_release_groups_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_release_groups(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search recordings asynchronously
#' @export
search_recordings_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_recordings(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search labels asynchronously
#' @export
search_labels_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_labels(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search works asynchronously
#' @export
search_works_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_works(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search areas asynchronously
#' @export
search_areas_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_areas(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search places asynchronously
#' @export
search_places_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_places(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search events asynchronously
#' @export
search_events_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_events(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search instruments asynchronously
#' @export
search_instruments_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_instruments(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search series asynchronously
#' @export
search_series_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_series(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search annotations asynchronously
#' @export
search_annotations_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_annotations(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search genres asynchronously
#' @export
search_genres_async <- function(limit = NULL, offset = NULL, all = FALSE) {
  future::future({
    search_genres(limit, offset, all)
  }, seed = TRUE)
}

#' @title Batch Async Lookup
#' @description Perform multiple lookups in parallel
#' @param mbids Vector of MBIDs
#' @param type Entity type (artist, release, etc.)
#' @param includes Optional includes
#' @param format Format ("json" or "jsonld")
#' @param .progress Show progress bar
#' @return List of results
#' @export
#' @importFrom furrr future_map_dfr
#' @examples
#' \dontrun{
#' plan(multisession)
#' lookup_artists_by_id_async(c("mbid1", "mbid2", "mbid3"))
#' }
lookup_artists_by_id_async <- function(mbids, includes = NULL, format = "json") {
  future::future({
    purrr::map_dfr(mbids, function(mbid) {
      tryCatch(
        lookup_artist_by_id(mbid, includes, format),
        error = function(e) tibble::tibble(mbid = mbid, error = as.character(e))
      )
    })
  }, seed = TRUE)
}

#' @describeIn async Lookup multiple releases asynchronously
#' @export
lookup_releases_by_id_async <- function(mbids, includes = NULL, format = "json") {
  future::future({
    purrr::map_dfr(mbids, function(mbid) {
      tryCatch(
        lookup_release_by_id(mbid, includes, format),
        error = function(e) tibble::tibble(mbid = mbid, error = as.character(e))
      )
    })
  }, seed = TRUE)
}