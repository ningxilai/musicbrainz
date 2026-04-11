#' Lookup URL by resource (text URL)
#'
#' Look up a URL entity by providing the actual URL string.
#' @param resource The URL to look up
#' @param includes Additional includes
#' @param format Output format
#' @export
lookup_url_by_resource <- function(resource, includes = NULL, format = "json") {
  base_url <- "http://musicbrainz.org/ws/2"
  url_endpoint <- paste0(base_url, "/url")
  
  parsed_url <- httr::parse_url(url_endpoint)
  parsed_url$query <- list(resource = resource)
  
  url <- httr::build_url(parsed_url)
  
  res <- get_data(url, format = format)
  if (is.null(res)) return(NULL)
  
  if (is.data.frame(res)) {
    tibble::as_tibble(res)
  } else {
    tibble::tibble(
      mbid = res$id %||% NA_character_,
      resource = res$resource %||% NA_character_,
      type = res$type %||% NA_character_
    )
  }
}

#' Get release group genres
#'
#' Get genres for a release group.
#' @param mbid Release group MBID
#' @param format Output format
#' @export
lookup_release_group_genres <- function(mbid, format = "json") {
  base_url <- "http://musicbrainz.org/ws/2"
  url <- paste0(base_url, "/release-group/", mbid)
  url <- utils::URLencode(url)
  
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- list(inc = "genres")
  
  url <- httr::build_url(parsed_url)
  
  res <- get_data(url, format = format)
  if (is.null(res)) return(NULL)
  
  tags <- purrr::pluck(res, "genres", .default = NULL)
  if (is.null(tags)) return(tibble::tibble())
  
  if (is.data.frame(tags)) {
    tibble::as_tibble(tags)
  } else if (is.list(tags) && length(tags) > 0) {
    genres_df <- purrr::map_dfr(tags, function(t) {
      tibble::tibble(
        name = t$name %||% NA_character_,
        count = t$count %||% NA_integer_
      )
    })
    genres_df
  } else {
    tibble::tibble()
  }
}