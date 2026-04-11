#' Search musicbrainz database
#'
#' Perform free text search in the musicbrainz database. Scope of each of the `search` functions is limited to specific type of entity. Search string can be composed using Apache Lucene search syntax, including specifying relations between entities explicitly.
#'
#' @param query search string.
#'
#' @param limit limit number of hits returned from database, defaults to NULL
#' @param offset number of hits to skip, defaults to NULL
#' @param strict return only exact matches with score of 100, defaults to FALSE
#'
#' @return a tibble of entities of interest
#' @examples
#' search_annotations("concerto")
#'
#' # return only first entry
#' search_areas("Oslo",limit=1)
#'
#' # skip first 25 entries (can be used as a follow-up query)
#' search_artists("George Michael", offset=25)
#'
#' # return only events precisely matching given name
#' search_events("The Prince\'s Trust", strict=TRUE)
#'
#' @references \url{https://lucene.apache.org/core/4_3_0/queryparser/org/apache/lucene/queryparser/classic/package-summary.html#package_description}
#' @name search
#' @rdname search
NULL

#' @describeIn search Search annotations
#' @importFrom purrr pluck
#' @importFrom dplyr filter
#' @export
search_annotations <- function(query, limit=NULL, offset=NULL, strict=FALSE, format="json") {
  res <- search_by_query("annotation", query, limit, offset, format = format)

  if (format == "ld-json") {
    res_lst <- purrr::pluck(res, "annotations", .default = NA)
    res_df <- parse_list_ld(res_lst)
    if (is.null(res_df)) res_df <- tibble::tibble()
    if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
    return(res_df)
  }

  # prepare lists
  res_lst <- purrr::pluck(res, "annotations", .default = NA)

  # extract and bind together
  res_df <- parse_list("annotations", res_lst, res[["offset"]], res[["count"]])

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search areas
#' @importFrom purrr pluck
#' @importFrom dplyr filter
#' @export
search_areas <- function(query, limit=NULL, offset=NULL, strict=FALSE, format="json") {
  res <- search_by_query("area", query, limit, offset)

  # prepare lists
  res_lst <- purrr::pluck(res, "areas", .default = NA)

  # extract and bind together
  res_df <- parse_list("areas", res_lst, res[["offset"]], res[["count"]])

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search artists
#' @importFrom purrr pluck
#' @importFrom dplyr filter
#' @export
search_artists <- function(query, limit=NULL, offset=NULL, strict=FALSE, format="json") {
  res <- search_by_query("artist", query, limit, offset, format = format)

  if (format == "ld-json") {
    res_lst <- purrr::pluck(res, "artists", .default = NA)
    res_df <- parse_list_ld(res_lst)
    if (is.null(res_df)) res_df <- tibble::tibble()
    if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
    return(res_df)
  }

  # prepare lists
  res_lst <- purrr::pluck(res, "artists", .default = NA)

  res_df <- parse_list("artists", res_lst, res[["offset"]], res[["count"]])

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search events
#' @importFrom purrr pluck map map_chr
#' @importFrom tibble tibble
#' @importFrom tidyr drop_na
#' @importFrom dplyr filter bind_cols
#' @export
search_events <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("event", query, limit, offset)

  res_lst <- purrr::pluck(res, "events", .default = list(NA))
  if (is.data.frame(res_lst)) {
    res_lst <- split(res_lst, seq_len(nrow(res_lst)))
  }
  
  n_items <- length(res_lst)
  relations_lst <- purrr::map(seq_len(n_items), function(i) {
    item <- res_lst[[i]]
    if (is.null(item) || length(item) == 0) return(list(list(NA)))
    purrr::pluck(item, "relations", .default = list(list(NA)))
  })

  res_df <- parse_list("events", res_lst, offset = res[["offset"]], hit_count = res[["count"]])

  artists_df <- purrr::map_dfr(seq_len(n_items), function(i) {
    rel <- relations_lst[[i]]
    if (is.null(rel) || length(rel) == 0 || identical(rel, list(list(NA)))) {
      return(tibble::tibble(artists_json = list(NA_character_)))
    }
    artist_rels <- purrr::keep(rel, ~ {
      art <- purrr::pluck(.x, "artist", .default = NULL)
      !is.null(art)
    })
    if (length(artist_rels) == 0) {
      return(tibble::tibble(artists_json = list(NA_character_)))
    }
    tibble::tibble(artists_json = list(jsonlite::toJSON(artist_rels, auto_unbox = TRUE)))
  })

  places_df <- purrr::map_dfr(seq_len(n_items), function(i) {
    rel <- relations_lst[[i]]
    if (is.null(rel) || length(rel) == 0 || identical(rel, list(list(NA)))) {
      return(tibble::tibble(places_json = list(NA_character_)))
    }
    place_rels <- purrr::keep(rel, ~ {
      pl <- purrr::pluck(.x, "place", .default = NULL)
      !is.null(pl)
    })
    if (length(place_rels) == 0) {
      return(tibble::tibble(places_json = list(NA_character_)))
    }
    tibble::tibble(places_json = list(jsonlite::toJSON(place_rels, auto_unbox = TRUE)))
  })

  res_df <- dplyr::bind_cols(res_df, artists_df, places_df)

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}


#' @describeIn search Search instrument
#' @importFrom purrr pluck
#' @importFrom dplyr filter
#' @export
search_instruments <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("instrument", query, limit, offset)

  # prepare lists
  res_lst <- purrr::pluck(res, "instruments", .default = NA)

  res_df <- parse_list("instruments", res_lst, res[["offset"]], res[["count"]])

 if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
 res_df
}


#' @describeIn search Search labels
#' @importFrom purrr pluck
#' @importFrom dplyr filter
#' @export
search_labels <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("label", query, limit, offset)

  # prepare lists
  res_lst <- purrr::pluck(res, "labels", .default = NA)

  res_df <- parse_list("labels", res_lst, res[["offset"]], res[["count"]])

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search places
#' @importFrom purrr pluck
#' @importFrom dplyr filter
#' @export
search_places <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("place", query, limit, offset)

  # prepare lists
  res_lst <- purrr::pluck(res, "places", .default = NA)

  # extract and bind
  res_df <- parse_list("places", res_lst, offset = res[["offset"]], hit_count = res[["count"]])

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)

  res_df
}

#' @describeIn search Search recordings
#' @importFrom purrr pluck map map_dfr pmap_dfc
#' @importFrom dplyr filter bind_cols
#' @export
search_recordings <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("recording", query, limit, offset)

  res_lst <- purrr::pluck(res, "recordings", .default = NA)
  if (is.data.frame(res_lst)) {
    res_lst <- split(res_lst, seq_len(nrow(res_lst)))
  }

  n_items <- length(res_lst)
  res_df <- parse_list("recordings", res_lst, offset = res[["offset"]], hit_count = res[["count"]])

  includes_df <- purrr::map_dfr(seq_len(n_items), function(i) {
    item <- res_lst[[i]]
    if (is.null(item) || length(item) == 0) {
      return(tibble::tibble(
        releases = list(NA_character_),
        artists = list(NA_character_)
      ))
    }
    
    releases_node <- purrr::pluck(item, "releases", .default = NULL)
    artists_node <- purrr::pluck(item, "artist-credit", .default = NULL)
    
    releases_json <- if (!is.null(releases_node) && length(releases_node) > 0) {
      list(jsonlite::toJSON(releases_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    artists_json <- if (!is.null(artists_node) && length(artists_node) > 0) {
      list(jsonlite::toJSON(artists_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    tibble::tibble(releases = releases_json, artists = artists_json)
  })

  res_df <- dplyr::bind_cols(res_df, includes_df)

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search release groups (e.g. albums)
#' @importFrom purrr pluck map map_dfr pmap_dfc
#' @importFrom tidyr drop_na
#' @importFrom dplyr filter bind_cols
#' @export
search_release_groups <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("release-group", query, limit, offset)

  res_lst <- purrr::pluck(res, "release-groups", .default = NA)
  if (is.data.frame(res_lst)) {
    res_lst <- split(res_lst, seq_len(nrow(res_lst)))
  }

  n_items <- length(res_lst)
  res_df <- parse_list("release-groups", res_lst, offset = res[["offset"]], hit_count = res[["count"]])

  includes_df <- purrr::map_dfr(seq_len(n_items), function(i) {
    item <- res_lst[[i]]
    if (is.null(item) || length(item) == 0) {
      return(tibble::tibble(
        releases = list(NA_character_),
        artists = list(NA_character_)
      ))
    }
    
    releases_node <- purrr::pluck(item, "releases", .default = NULL)
    artists_node <- purrr::pluck(item, "artist-credit", .default = NULL)
    
    releases_json <- if (!is.null(releases_node) && length(releases_node) > 0) {
      list(jsonlite::toJSON(releases_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    artists_json <- if (!is.null(artists_node) && length(artists_node) > 0) {
      list(jsonlite::toJSON(artists_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    tibble::tibble(releases = releases_json, artists = artists_json)
  })

  res_df <- dplyr::bind_cols(res_df, includes_df)

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search releases
#' @importFrom purrr pluck map map_dfr pmap_dfc
#' @importFrom tidyr drop_na
#' @importFrom dplyr filter bind_cols
#' @export
search_releases <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("release", query, limit, offset)

  res_lst <- purrr::pluck(res, "releases", .default = NA)
  if (is.data.frame(res_lst)) {
    res_lst <- split(res_lst, seq_len(nrow(res_lst)))
  }

  n_items <- length(res_lst)
  res_df <- parse_list("releases", res_lst, offset = res[["offset"]], hit_count = res[["count"]])

  includes_df <- purrr::map_dfr(seq_len(n_items), function(i) {
    item <- res_lst[[i]]
    if (is.null(item) || length(item) == 0) {
      return(tibble::tibble(
        releases = list(NA_character_),
        artists = list(NA_character_),
        labels = list(NA_character_),
        media = list(NA_character_)
      ))
    }
    
    releases_node <- purrr::pluck(item, "releases", .default = NULL)
    artists_node <- purrr::pluck(item, "artist-credit", .default = NULL)
    labels_node <- purrr::pluck(item, "label-info", .default = NULL)
    media_node <- purrr::pluck(item, "media", .default = NULL)
    
    releases_json <- if (!is.null(releases_node) && length(releases_node) > 0) {
      list(jsonlite::toJSON(releases_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    artists_json <- if (!is.null(artists_node) && length(artists_node) > 0) {
      list(jsonlite::toJSON(artists_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    labels_json <- if (!is.null(labels_node) && length(labels_node) > 0) {
      list(jsonlite::toJSON(labels_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    media_json <- if (!is.null(media_node) && length(media_node) > 0) {
      list(jsonlite::toJSON(media_node, auto_unbox = TRUE))
    } else {
      list(NA_character_)
    }
    
    tibble::tibble(releases = releases_json, artists = artists_json, labels = labels_json, media = media_json)
  })

  res_df <- dplyr::bind_cols(res_df, includes_df)

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search series
#' @importFrom purrr pluck map map_dfr pmap_dfc
#' @importFrom tidyr drop_na
#' @importFrom dplyr filter bind_cols
#' @export
search_series <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("series", query, limit, offset)

  # prepare lists
  res_lst <- purrr::pluck(res, "series", .default = NA)

  res_df <- parse_list("labels", res_lst, res[["offset"]], res[["count"]])

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search works
#' @importFrom purrr pluck map map_dfr pmap_dfc
#' @importFrom tidyr drop_na
#' @importFrom dplyr filter bind_cols
#' @export
search_works <- function(query, limit=NULL, offset=NULL, strict=FALSE) {
  res <- search_by_query("work", query, limit, offset)

  res_lst <- purrr::pluck(res, "works", .default = NA)
  if (is.data.frame(res_lst)) {
    res_lst <- split(res_lst, seq_len(nrow(res_lst)))
  }
  
  n_items <- length(res_lst)
  relations_lst <- purrr::map(seq_len(n_items), function(i) {
    item <- res_lst[[i]]
    if (is.null(item) || length(item) == 0) return(list(list(NA)))
    purrr::pluck(item, "relations", .default = list(list(NA)))
  })

  res_df <- parse_list("works", res_lst, offset = res[["offset"]], hit_count = res[["count"]])

  artists_df <- purrr::map_dfr(seq_len(n_items), function(i) {
    rel <- relations_lst[[i]]
    if (is.null(rel) || length(rel) == 0 || identical(rel, list(list(NA)))) {
      return(tibble::tibble(artists_json = list(NA_character_)))
    }
    artist_rels <- purrr::keep(rel, ~ {
      art <- purrr::pluck(.x, "artist", .default = NULL)
      !is.null(art)
    })
    if (length(artist_rels) == 0) {
      return(tibble::tibble(artists_json = list(NA_character_)))
    }
    tibble::tibble(artists_json = list(jsonlite::toJSON(artist_rels, auto_unbox = TRUE)))
  })

  recordings_df <- purrr::map_dfr(seq_len(n_items), function(i) {
    rel <- relations_lst[[i]]
    if (is.null(rel) || length(rel) == 0 || identical(rel, list(list(NA)))) {
      return(tibble::tibble(recordings_json = list(NA_character_)))
    }
    rec_rels <- purrr::keep(rel, ~ {
      rec <- purrr::pluck(.x, "recording", .default = NULL)
      !is.null(rec)
    })
    if (length(rec_rels) == 0) {
      return(tibble::tibble(recordings_json = list(NA_character_)))
    }
    tibble::tibble(recordings_json = list(jsonlite::toJSON(rec_rels, auto_unbox = TRUE)))
  })

  res_df <- dplyr::bind_cols(res_df, artists_df, recordings_df)

  if (strict) res_df <- dplyr::filter(res_df, .data$score==100)
  res_df
}

#' @describeIn search Search genres (all genres, not searchable)
#' @param all If TRUE, fetch all genres (requires multiple API calls)
#' @importFrom purrr pluck
#' @importFrom dplyr filter
#' @export
search_genres <- function(limit = NULL, offset = NULL, all = FALSE) {
  if (all) {
    all_genres <- tibble::tibble(mbid = character(), name = character(), disambiguation = character())
    batch_size <- 100
    total_count <- 2132
    
    for (i in seq(0, total_count, batch_size)) {
      res <- search_by_query("genre", "*", batch_size, i)
      res_df_raw <- purrr::pluck(res, "genres", .default = NULL)
      
      if (!is.null(res_df_raw) && nrow(res_df_raw) > 0) {
        batch_df <- tibble::tibble(
          mbid = as.character(res_df_raw$id),
          name = as.character(res_df_raw$name),
          disambiguation = as.character(res_df_raw$disambiguation)
        )
        all_genres <- dplyr::bind_rows(all_genres, batch_df)
      }
    }
    return(all_genres)
  }
  
  res <- search_by_query("genre", "*", limit, offset)

  res_df_raw <- purrr::pluck(res, "genres", .default = NULL)

  if (is.null(res_df_raw) || nrow(res_df_raw) == 0) {
    return(NULL)
  }

  res_df <- tibble::tibble(
    mbid = as.character(res_df_raw$id),
    name = as.character(res_df_raw$name),
    disambiguation = as.character(res_df_raw$disambiguation)
  )

  res_df
}
