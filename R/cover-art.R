#' Cover Art Archive Client
#'
#' Functions to get cover artwork URLs from the Cover Art Archive.
#'
#' @description
#' The Cover Art Archive (coverartarchive.org) provides cover images for MusicBrainz releases.
#' Images are available in various sizes: 250, 500, 1200, or original.
#'
#' @examples
#' \dontrun{
#' # Get cover art URL for a release (for Org inline display)
#' cover_art_url("release-mbid")
#' cover_art_url("release-mbid", 500)
#' }
#'
#' @name cover-art
NULL

#' @title Cover Art URL Constructor
#' @description Construct front cover art URL for a release.
#' @param mbid Release MBID
#' @param size Image size: 250, 500, 1200, or NULL for original
#' @return URL string
#' @export
cover_art_url <- function(mbid, size = NULL) {
  base_url <- "https://coverartarchive.org/release"
  if (!is.null(size)) {
    paste0(base_url, "/", mbid, "/front-", size)
  } else {
    paste0(base_url, "/", mbid, "/front")
  }
}