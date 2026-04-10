#' @importFrom httr GET add_headers
httr_get <- function(url, format = "json") {
  accept_type <- if (format == "ld-json") "application/ld+json" else "application/json"
  httr::GET(
    url,
    httr::add_headers(
      Accept = accept_type,
      "user-agent" = "musicbrainz/0.0.0.9000 (https://github.com/dmi3kno/musicbrainz)"
    )
  )
}

# Rate limiting configuration (matching MusicBrainz API policy: 1 request per second)
#' @importFrom ratelimitr rate limit_rate
#' @keywords internal
mb_rate_limit <- function(n = 1, period = 1.1) {
  ratelimitr::limit_rate(
    function(u) httr_get(u),
    ratelimitr::rate(n = n, period = period)
  )
}

httr_get_rate_ltd <- function(url, format = "json") {
  mb_rate_limit(n = 1, period = 1.1)(url)
}

#' @importFrom httr status_code content
get_data_with_errors <- function(url, verbose, format = "json") {
  # error handling function

  # api call
  mb_data <- httr_get_rate_ltd(url, format)

  # status check
  status <- httr::status_code(mb_data)

  if (status > 200) {
    # this is more problematic and we shall try again
    if (verbose) {
      message(paste("http error code:", status))
    }
    res <- NULL
  }
  if (status == 200) {
    if (format == "ld-json") {
      res <- jsonlite::fromJSON(content(mb_data, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
    } else {
      res <- jsonlite::fromJSON(content(mb_data, as = "text", encoding = "UTF-8"), simplifyVector = TRUE)
    }
  }
  res
}

# main re-attempt function
.GET_data <- function(url, verbose = TRUE, format = "json") { # nolint
  output <- get_data_with_errors(url, verbose, format)
  max_attempts <- 3

  try_number <- 1
  while (is.null(output) && try_number < max_attempts) {
    try_number <- try_number + 1
    if (verbose) {
      message(paste0("Attempt number ", try_number))
      if (try_number == max_attempts) {
        message("This is the last attempt, if it fails will return NULL") # nolint
      }
    }
    Sys.sleep(2^try_number)
    output <- get_data_with_errors(url, verbose, format)
  }
  output
}

#' @importFrom memoise memoise
get_data <- memoise::memoise(function(url, verbose = TRUE, format = "json") {
  .GET_data(url, verbose, format)
})

#' @importFrom httr build_url parse_url
#' @importFrom utils URLencode
lookup_by_id <- function(resource, mbid, includes, format = "json") {
  # lookup:   /<ENTITY>/<MBID>?inc=<INC>
  # API request function for lookup
  if (format == "ld-json") {
    base_url <- "https://musicbrainz.org"
  } else {
    base_url <- "http://musicbrainz.org/ws/2"
  }
  url <- base::paste(c(base_url, resource, mbid), collapse = "/")
  url <- utils::URLencode(url)

  if (!is.null(includes) && length(includes) && format != "ld-json") {
    parsed_url <- httr::parse_url(url)
    parsed_url$query <- base::list(inc = paste0(includes, collapse = "+"))
    url <- httr::build_url(parsed_url)
  }

  get_data(url, format = format)
}

#' @importFrom httr build_url
search_by_query <- function(type, query, limit, offset, format = "json") {
  # API request function for search
  # search:   /<ENTITY>?query=<QUERY>&limit=<LIMIT>&offset=<OFFSET>
  base_url <- "http://musicbrainz.org/ws/2"

  # genre uses special /all endpoint
  if (type == "genre") {
    url <- base::paste(c(base_url, "genre", "all"), collapse = "/")
  } else {
    url <- base::paste(c(base_url, type), collapse = "/")
  }

  parsed_url <- httr::parse_url(url)
  parsed_url$query <- base::list(query = query, limit = limit, offset = offset)

  url <- httr::build_url(parsed_url)

  get_data(url, format = format)
}


#' @importFrom httr build_url
#' @importFrom stats setNames
#' @importFrom utils URLencode
browse_by_lnkd_id <- function(resource, lnk_resource, mbid, includes, limit, offset, format = "json") {
  # API request function for search
  # browse:   /<ENTITY>?<ENTITY>=<MBID>&limit=<LIMIT>&offset=<OFFSET>&inc=<INC>
  base_url <- "http://musicbrainz.org/ws/2"
  url <- base::paste(c(base_url, resource), collapse = "/")
  url <- utils::URLencode(url)
  parsed_url <- httr::parse_url(url)
  parsed_url$query <- stats::setNames(base::list(mbid), nm = lnk_resource)
  parsed_url$query <- base::append(parsed_url$query, list(limit = limit, offset = offset))

  if (!is.null(includes) && length(includes)) {
    parsed_url$query <- base::append(parsed_url$query, list(inc = paste0(includes, collapse = "+")))
  }

  url <- httr::build_url(parsed_url)

  get_data(url, format = format)
}

#' Tidy eval helpers
#'
#' These functions provide tidy eval-compatible ways to capture
#' symbols
#' To learn more about tidy eval and how to use these tools, read
#' <http://rlang.tidyverse.org/articles/tidy-evaluation.html>
#'
#' @name tidyeval
#' @keywords internal
#' @importFrom rlang UQ UQS .data :=
NULL
