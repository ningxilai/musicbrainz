get_data_with_errors <- function(url, verbose, format = "json") {
  cli <- crul::HttpClient$new(
    url = url,
    headers = list(
      Accept = if (format == "ld-json") "application/ld+json" else "application/json",
      "user-agent" = "musicbrainz/0.1.0 (https://github.com/dmi3kno/musicbrainz)"
    ),
    opts = list(timeout = 10)
  )

  res <- cli$get()

  status <- res$status_code
  content <- res$parse("UTF-8")

  if (status > 200) {
    if (verbose) {
      message(paste("http error code:", status))
    }
    return(NULL)
  }

  if (status == 200) {
    if (format == "ld-json") {
      jsonlite::fromJSON(content, simplifyVector = FALSE)
    } else {
      jsonlite::fromJSON(content, simplifyVector = TRUE)
    }
  }
}

.GET_data <- function(url, verbose = TRUE, format = "json") {
  output <- get_data_with_errors(url, verbose, format)
  max_attempts <- 3

  try_number <- 1
  while (is.null(output) && try_number < max_attempts) {
    try_number <- try_number + 1
    if (verbose) {
      message(paste0("Attempt number ", try_number))
      if (try_number == max_attempts) {
        message("This is the last attempt, if it fails will return NULL")
      }
    }
    Sys.sleep(2^try_number)
    output <- get_data_with_errors(url, verbose, format)
  }
  output
}

get_data <- memoise::memoise(function(url, verbose = TRUE, format = "json") {
  .GET_data(url, verbose, format)
})

#' Clear the API cache
#'
#' Clears all cached API responses. Use this if you need fresh data.
#' @export
clear_cache <- function() {
  memoise::forget(get_data)
  invisible(NULL)
}

lookup_by_id <- function(resource, mbid, includes, format = "json") {
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

search_by_query <- function(type, query, limit, offset, format = "json") {
  base_url <- "http://musicbrainz.org/ws/2"

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

browse_by_lnkd_id <- function(resource, lnk_resource, mbid, includes, limit, offset, format = "json") {
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

crul_batch_lookup <- function(resource, mbids, includes = NULL, format = "json") {
  if (length(mbids) == 0) return(tibble::tibble())

  base_url <- if (format == "ld-json") {
    "https://musicbrainz.org"
  } else {
    "http://musicbrainz.org/ws/2"
  }

  results <- purrr::map(mbids, function(mbid) {
    url <- base::paste(c(base_url, resource, mbid), collapse = "/")
    if (!is.null(includes) && length(includes) && format != "ld-json") {
      url <- paste0(url, "?inc=", paste0(includes, collapse = "+"))
    }
    memoise::forget(get_data)
    get_data(url, format = format)
  })

  results <- purrr::keep(results, Negate(is.null))
  if (length(results) == 0) return(tibble::tibble())

  if (format == "ld-json") {
    purrr::map_dfr(results, parse_list_ld)
  } else {
    res_lst_xtr <- get_main_parser_lst(resource)
    purrr::map_dfr(results, function(r) {
      tibble::as_tibble(purrr::map(res_lst_xtr, function(i) {
        val <- purrr::pluck(r, !!!i, .default = NA_character_)
        if (length(val) == 1 && is.na(val)) NA_character_ else as.character(paste(val, collapse = "; "))
      }))
    })
  }
}

crul_async_get <- function(urls, format = "json") {
  if (length(urls) == 0) return(list())

  cli <- crul::Async$new(urls = urls)
  res <- cli$get()

  lapply(res, function(z) {
    if (is.null(z)) return(NULL)
    tryCatch({
      content <- z$parse("UTF-8")
      if (nchar(content) < 10) return(NULL)
      jsonlite::fromJSON(content, simplifyVector = TRUE)
    }, error = function(e) NULL)
  }) -> parsed

  Filter(Negate(is.null), parsed)
}

crul_batch_lookup_concurrent <- function(resource, mbids, includes = NULL, format = "json") {
  if (length(mbids) == 0) return(tibble::tibble())

  base_url <- if (format == "ld-json") "https://musicbrainz.org" else "http://musicbrainz.org/ws/2"

  urls <- paste0(base_url, "/", resource, "/", mbids)

  results <- crul_async_get(urls, format = format)

  if (length(results) == 0) return(tibble::tibble())

  if (format == "ld-json") {
    purrr::map_dfr(results, parse_list_ld)
  } else {
    purrr::map_dfr(results, function(r) {
      names_to_keep <- c("id", "name", "type", "score")
      nm <- intersect(names_to_keep, names(r))
      tibble::as_tibble(r[nm])
    })
  }
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