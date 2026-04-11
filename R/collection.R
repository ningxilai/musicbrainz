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