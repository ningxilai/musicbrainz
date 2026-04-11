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

#' @describeIn async Lookup artist by MBID asynchronously
#' @param mbid MusicBrainz ID
#' @param includes Optional includes
#' @param format Format ("json" or "ld-json")
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
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_artists_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_artists(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search releases asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_releases_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_releases(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search release-groups asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_release_groups_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_release_groups(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search recordings asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_recordings_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_recordings(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search labels asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_labels_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_labels(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search works asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_works_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_works(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search areas asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_areas_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_areas(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search places asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_places_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_places(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search events asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_events_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_events(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search instruments asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_instruments_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_instruments(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search series asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_series_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_series(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search annotations asynchronously
#' @param query Search query
#' @param limit Number of results
#' @param offset Result offset
#' @param strict Exact match only
#' @export
search_annotations_async <- function(query, limit = NULL, offset = NULL, strict = FALSE) {
  future::future({
    search_annotations(query, limit, offset, strict)
  }, seed = TRUE)
}

#' @describeIn async Search genres asynchronously
#' @param limit Number of results
#' @param offset Result offset
#' @param all Fetch all genres
#' @export
search_genres_async <- function(limit = NULL, offset = NULL, all = FALSE) {
  future::future({
    search_genres(limit, offset, all)
  }, seed = TRUE)
}

#' @describeIn async Batch lookup multiple artists
#' @param mbids Vector of MBIDs
#' @param includes Optional includes
#' @param format Format ("json" or "ld-json")
#' @export
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

#' @describeIn async Browse artists by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_artists_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  if (!requireNamespace("future", quietly = TRUE)) {
    stop("Package 'future' required. Install with: install.packages('future')")
  }
  future::future({
    browse_artists_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse events by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_events_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  future::future({
    browse_events_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse labels by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_labels_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  future::future({
    browse_labels_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse places by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_places_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  future::future({
    browse_places_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse recordings by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_recordings_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  future::future({
    browse_recordings_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse releases by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_releases_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  future::future({
    browse_releases_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse release groups by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_release_groups_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  future::future({
    browse_release_groups_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse works by related id asynchronously
#' @param entity Related entity type
#' @param mbid MBID of the entity
#' @param includes Optional includes
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_works_by_async <- function(entity, mbid, includes = NULL, limit = NULL, offset = NULL) {
  future::future({
    browse_works_by(entity, mbid, includes, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Lookup URL by resource asynchronously
#' @export
lookup_url_by_resource_async <- function(resource, includes = NULL, format = "json") {
  future::future({
    lookup_url_by_resource(resource, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup release group genres asynchronously
#' @export
lookup_release_group_genres_async <- function(mbid, format = "json") {
  future::future({
    lookup_release_group_genres(mbid, format)
  }, seed = TRUE)
}

#' @describeIn async Lookup artist relationships asynchronously
#' @export
lookup_artist_relations_async <- function(mbid, includes = NULL, format = "json") {
  future::future({
    lookup_artist_relations(mbid, includes, format)
  }, seed = TRUE)
}

#' @describeIn async Browse collection releases asynchronously
#' @export
browse_collection_releases_async <- function(collection, limit = NULL, offset = NULL) {
  future::future({
    browse_collection_releases(collection, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse collection artists asynchronously
#' @export
browse_collection_artists_async <- function(collection, limit = NULL, offset = NULL) {
  future::future({
    browse_collection_artists(collection, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse collection recordings asynchronously
#' @export
browse_collection_recordings_async <- function(collection, limit = NULL, offset = NULL) {
  future::future({
    browse_collection_recordings(collection, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse collection works asynchronously
#' @export
browse_collection_works_async <- function(collection, limit = NULL, offset = NULL) {
  future::future({
    browse_collection_works(collection, limit, offset)
  }, seed = TRUE)
}

#' @describeIn async Browse collection release groups asynchronously
#' @export
browse_collection_release_groups_async <- function(collection, limit = NULL, offset = NULL) {
  future::future({
    browse_collection_release_groups(collection, limit, offset)
  }, seed = TRUE)
}
