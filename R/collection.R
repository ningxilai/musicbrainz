# Collection lookup functions
# Browse entities by collection MBID using ?collection= query parameter

#' Browse releases in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_releases <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/release")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse artists in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_artists <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/artist")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse recordings in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_recordings <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/recording")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse release groups in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_release_groups <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/release-group")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse works in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_works <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/work")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse areas in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_areas <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/area")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse events in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_events <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/event")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse instruments in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_instruments <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/instrument")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse labels in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_labels <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/label")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse places in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_places <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/place")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Browse series in a collection
#'
#' @param collection Collection MBID
#' @param limit Number of results
#' @param offset Result offset
#' @export
browse_collection_series <- function(collection, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/series")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(collection = collection, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

#' Get public collections by editor name
#'
#' @param editor Editor username
#' @param limit Number of results
#' @param offset Result offset
#' @export
get_collections_by_editor <- function(editor, limit = NULL, offset = NULL) {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/collection")
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(editor = editor, limit = limit, offset = offset)
  url <- httr::build_url(parsed_url)
  get_data(url, format = "json")
}

entity_plural_map <- function(entity_type) {
  switch(entity_type,
    release = "releases",
    artist = "artists",
    recording = "recordings",
    `release-group` = "release-groups",
    work = "works",
    area = "areas",
    event = "events",
    instrument = "instruments",
    label = "labels",
    place = "places",
    series = "series",
    stop("Unknown entity type: ", entity_type)
  )
}

#' Add entries to a collection
#'
#' Requires an OAuth Bearer token set via \code{set_auth()}.
#' The server expects MBIDs as a semicolon-separated list in the URL path
#' and requires a \code{client} query parameter identifying your application.
#'
#' @param collection Collection MBID
#' @param entity_type Entity type string, one of: release, artist, recording,
#'   release-group, work, area, event, instrument, label, place, series.
#' @param mbids Character vector of MBIDs to add.
#' @param client Application name for the \code{client} query parameter.
#' @export
add_collection_entries <- function(collection, entity_type, mbids, client) {
  plural <- entity_plural_map(entity_type)
  mbid_str <- paste(mbids, collapse = ";")
  url <- paste0(
    "http://musicbrainz.org/ws/2/collection/", collection,
    "/", plural, "/", mbid_str,
    "?client=", utils::URLencode(client, reserved = TRUE)
  )
  put_data(url, "")
}

#' Delete entries from a collection
#'
#' Requires an OAuth Bearer token set via \code{set_auth()}.
#'
#' @param collection Collection MBID
#' @param entity_type Entity type string, one of: release, artist, recording,
#'   release-group, work, area, event, instrument, label, place, series.
#' @param mbids Character vector of MBIDs to delete.
#' @param client Application name for the \code{client} query parameter.
#' @export
delete_collection_entries <- function(collection, entity_type, mbids, client) {
  plural <- entity_plural_map(entity_type)
  mbid_str <- paste(mbids, collapse = ";")
  url <- paste0(
    "http://musicbrainz.org/ws/2/collection/", collection,
    "/", plural, "/", mbid_str,
    "?client=", utils::URLencode(client, reserved = TRUE)
  )
  delete_data(url, "")
}