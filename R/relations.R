# Relations lookup functions
# Uses inc parameters to fetch relationships

#' Lookup artist relationships
#'
#' @param mbid Artist MBID
#' @param includes Relationship types to include (default: artist-rels)
#' @param format Output format
#' @export
lookup_artist_relations <- function(mbid, includes = NULL, format = "json") {
  if (is.null(includes)) {
    includes <- "artist-rels"
  }
  lookup_artist_by_id(mbid, includes, format)
}

#' Lookup release relationships
#'
#' @param mbid Release MBID
#' @param includes Relationship types to include (default: release-group-rels)
#' @param format Output format
#' @export
lookup_release_relations <- function(mbid, includes = NULL, format = "json") {
  if (is.null(includes)) {
    includes <- "release-group-rels"
  }
  lookup_release_by_id(mbid, includes, format)
}

#' Lookup recording relationships
#'
#' @param mbid Recording MBID
#' @param includes Relationship types to include (default: work-rels)
#' @param format Output format
#' @export
lookup_recording_relations <- function(mbid, includes = NULL, format = "json") {
  if (is.null(includes)) {
    includes <- "work-rels"
  }
  lookup_recording_by_id(mbid, includes, format)
}

#' Lookup work relationships
#'
#' @param mbid Work MBID
#' @param includes Relationship types to include (default: recording-rels)
#' @param format Output format
#' @export
lookup_work_relations <- function(mbid, includes = NULL, format = "json") {
  if (is.null(includes)) {
    includes <- "recording-rels"
  }
  lookup_work_by_id(mbid, includes, format)
}

#' Lookup label relationships
#'
#' @param mbid Label MBID
#' @param includes Relationship types to include (default: release-rels)
#' @param format Output format
#' @export
lookup_label_relations <- function(mbid, includes = NULL, format = "json") {
  if (is.null(includes)) {
    includes <- "release-rels"
  }
  lookup_label_by_id(mbid, includes, format)
}