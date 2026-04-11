#' @importFrom tibble tribble
#' @importFrom dplyr filter
#' @keywords internal
get_main_parser_lst <-function(type){
  # prepare extractors
  parsers_df <- tibble::tribble(
    ~nm,    ~lst_xtr,
    "artists",    list(mbid = "id", type = "type", type_id = "type-id", score = "score", name = "name", sort_name = "sort-name",
                       gender = "gender", gender_id = "gender-id", country = "country", disambiguation = "disambiguation",
                       area_id = list("area", "id"), area_name = list("area", "name"),
                       area_sort_name = list("area", "sort-name"), area_disambiguation = list("area", "disambiguation"),
                       area_iso = list("area", "iso-3166-1-codes", 1),
                       begin_area_id = list("begin-area", "id"), begin_area_name = list("begin-area", "name"),
                       begin_area_sort_name = list("begin-area", "sort-name"),
                       begin_area_disambiguation = list("begin-area", "disambiguation"),
                       end_area_id = list("end-area", "id"), end_area_name = list("end-area", "name"),
                       end_area_sort_name = list("end-area", "sort-name"),
                       end_area_disambiguation = list("end-area", "disambiguation"),
                       life_span_begin = list("life-span", "begin"), life_span_end = list("life-span", "end"),
                       life_span_ended = list("life-span", "ended"), ipis = "ipis",
                       isnis = "isnis"),
    "events",    list(mbid = "id", name = "name", type = "type", type_id = "type-id", score = "score",
                       time = "time", cancelled = "cancelled", disambiguation = "disambiguation",
                       begin = list("life-span", "begin"), end = list("life-span", "end"),
                       ended = list("life-span", "ended"), setlist = "setlist"),
    "labels",    list(mbid = "id", type = "type", type_id="type-id", score = "score", name = "name", sort_name = "sort-name",
                       label_code = "label-code", country = "country", disambiguation = "disambiguation",
                       begin = list("life-span", "begin"), end=list("life-span", "end"), ended=list("life-span", "ended"),
                       area_id = list("area", "id"), area_name = list("area", "name"), area_sort_name = list("area", "sort-name"),
                       area_iso = list("area", "iso-3166-1-codes", 1), ipis = "ipis",
                       isnis = "isnis"),
    "places",    list(mbid = "id", type = "type", type_id="type-id", score = "score", name = "name", address = "address",
                       disambiguation = "disambiguation", latitude = list("coordinates","latitude"), longitude = list("coordinates","longitude"),
                       area_id = list("area","id"), area_name = list("area","name"), area_sort_name = list("area","sort-name"),
                       area_disambiguation=list("area","disambiguation"), area_iso=list("area", "iso-3166-1-codes",1),
                       place_begin = list("life-span","begin"), place_end = list("life-span","end"), place_ended = list("life-span","ended")),
    "recordings", list(mbid = "id", score = "score", title = "title", length = "length", video = "video"),
    "releases",   list(mbid = "id", score = "score", count = "count", title = "title",
                       status = "status", status_id = "status-id", packaging_id = list("packaging", "id"), packaging_name = list("packaging", "name"),
                       date = "date", country = "country", disambiguation="disambiguation",
                       barcode = "barcode", asin = "asin", track_count = "track-count", quality="quality",
                       release_group_id = list("release-group", "id"),
                       release_group_primary_type = list("release-group", "primary-type")),
    "release-groups", list(mbid = "id", score = "score", count = "count", title = "title", disambiguation = "disambiguation",
                           primary_type = "primary-type", primary_type_id = "primary-type-id",
                           first_releas_date="first-release-date"),
    "areas",      list(mbid = "id", type = "type", score = "score", name = "name", sort_name = "sort-name",
                       disambiguation = "disambiguation", iso=list("iso-3166-2-codes", 1),
                       begin=list("list-span", "begin"), end=list("list-span", "end"), ended=list("list-span", "ended"),
                       relation_type =  list("relation-list", 1, "relations", 1, "type"),
                       relation_type_id =  list("relation-list", 1, "relations", 1, "type-id"),
                       relation_direction = list("relation-list", 1, "relations", 1, "direction"),
                       relation_area_id = list("relation-list", 1, "relations", 1, "area", "id"),
                       relation_area_type = list("relation-list", 1, "relations", 1, "area", "type"),
                       relation_area_name = list("relation-list", 1, "relations", 1, "area", "name"),
                       relation_area_sort_name = list("relation-list", 1, "relations", 1, "area", "sort-name"),
                       relation_area_begin = list("relation-list", 1, "relations", 1, "area", "list-span", "begin"),
                       relation_area_end = list("relation-list", 1, "relations", 1, "area", "list-span", "end"),
                       relation_area_ended = list("relation-list", 1, "relations", 1, "area", "list-span", "ended")),
    "annotations", list(mbid = "entity", type = "type", score = "score", name = "name", text = "text"),
    "instruments", list(mbid = "id", type = "type", score = "score", name = "name",
                       disambiguation = "disambiguation", description = "description"),
    "series",      list(mbid = "id", type = "type", score = "score", name = "name", disambiguation = "disambiguation"),
    "works",       list(mbid = "id", type = "type", score = "score", title = "title",
                       language = "language", disambiguation = "disambiguation"),
    "urls",        list(mbid = "id", type = "type", resource = "resource", relation_type = "relation-type",
                       relation_type_id = "relation-type-id"),
    "genres",      list(mbid = "id", name = "name", disambiguation = "disambiguation"),
    "relations",   list(relation_type = "type", relation_type_id = "type-id", direction = "direction",
                        target_type = "target-type", target_id = list("target", "id"),
                        target_name = list("target", "name"), begin = "begin", end = "end", ended = "ended")
  )
  dplyr::filter(parsers_df, .data$nm == type)[["lst_xtr"]][[1]] # or pull and flatten
}

#' @importFrom tibble tribble
#' @importFrom dplyr filter
#' @keywords internal
get_main_parser_lst_ld <- function(type) {
  parsers_df <- tibble::tribble(
    ~nm,    ~lst_xtr,
    "artist",     list(mbid = "@id", type = "@type", name = "name", sort_name = "alternateName",
                       gender = list("@type"), birth_date = "birthDate", death_date = "deathDate",
                       birth_place = list("birthPlace", "name"), death_place = list("deathPlace", "name"),
                       country = list("birthPlace", "containedIn", "containedIn", "name"),
                       genre = "genre", same_as = "sameAs",
                       member_of = "memberOf", album = "album"),
    "event",      list(mbid = "@id", name = "name", type = "@type", start_date = "startDate",
                       end_date = "endDate", location = "location", description = "description"),
    "label",      list(mbid = "@id", type = "@type", name = "name", alternate_name = "alternateName",
                       address = "address", same_as = "sameAs", label_code = "identifier"),
    "place",      list(mbid = "@id", type = "@type", name = "name", address = "address",
                       latitude = "latitude", longitude = "longitude", description = "description",
                       contained_in = list("containedInPlace", "name")),
    "recording",  list(mbid = "@id", name = "name", duration = "duration", description = "description",
                       by_artist = "byArtist", recording_of = "recordingOf"),
    "release",    list(mbid = "@id", name = "name", date = "datePublished", country = "country",
                       format = "musicReleaseFormat", barcode = "gtin14", catalog_number = "catalogNumber",
                       credited_to = "creditedTo", description = "description"),
    "release-group", list(mbid = "@id", name = "name", type = "@type", description = "description",
                          date = "datePublished", album = "album", by_artist = "byArtist"),
    "area",       list(mbid = "@id", name = "name", type = "@type", iso = "addressCountry",
                       description = "description", contained_in = "containedIn"),
    "instrument", list(mbid = "@id", type = "@type", name = "name", description = "description",
                       same_as = "sameAs"),
    "series",     list(mbid = "@id", type = "@type", name = "name", description = "description"),
    "work",       list(mbid = "@id", type = "@type", name = "name", language = "inLanguage",
                       description = "description", composer = "composer", lyricist = "lyricist",
                       genre = "genre"),
    "url",        list(mbid = "@id", type = "@type", resource = "url", description = "description"),
    "genre",      list(mbid = "@id", name = "name", description = "description", disambiguation = "disambiguation")
  )
  dplyr::filter(parsers_df, .data$nm == type)[["lst_xtr"]][[1]]
}


#' @importFrom purrr map map_dfr pluck
#' @keywords internal
safe_pluck <- function(x, path, default = NA) {
  if (is.null(x) || length(x) == 0) return(default)
  val <- tryCatch(purrr::pluck(x, !!!path), error = function(e) default)
  if (is.null(val) || (is.list(val) && length(val) == 0)) return(default)
  if (is.vector(val) && length(val) > 1) {
    return(list(val))
  }
  val
}

#' @importFrom purrr map map_dfr pluck
#' @keywords internal
parse_list <- function(type, res_lst, offset, hit_count) {
  if (!is.null(res_lst) && length(res_lst)) {
    message(paste("Returning", type, offset + 1, "to", offset + length(res_lst), "of", hit_count))
  }

  res_lst_xtr <- get_main_parser_lst(type)

  if (is.data.frame(res_lst)) {
    res_lst <- split(res_lst, seq_len(nrow(res_lst)))
  }

  res_df <- purrr::map_dfr(res_lst, function(x) {
    purrr::map(res_lst_xtr, function(i) safe_pluck(x, i))
  })

  res_df$score <- as.integer(res_df$score)

  res_df
}

#' @importFrom purrr map map_dfr pluck
#' @importFrom tibble as_tibble
#' @keywords internal
parse_list_ld <- function(res) {
  if (is.null(res) || is.null(res[["@type"]])) {
    return(NULL)
  }
  
  json_str <- jsonlite::toJSON(res, auto_unbox = FALSE, null = "null")
  
  compacted <- tryCatch(
    jsonld::jsonld_compact(json_str, c("@context" = "https://musicbrainz.org/doc/context.jsonld")), 
    error = function(e) NULL
  )
  
  if (!is.null(compacted)) {
    res <- jsonlite::fromJSON(compacted, simplifyVector = TRUE)
  }

  type_map <- c(
    "MusicArtist" = "artist",
    "MusicEvent" = "event",
    "MusicLabel" = "label",
    "Place" = "place",
    "MusicRecording" = "recording",
    "MusicRelease" = "release",
    "MusicAlbum" = "release-group",
    "AdministrativeArea" = "area",
    "Instrument" = "instrument",
    "Series" = "series",
    "Work" = "work",
    "Person" = "artist",
    "MusicGroup" = "artist"
  )

  type_val <- res[["@type"]]
  if (is.null(type_val)) {
    return(NULL)
  }

  type_str <- if (is.character(type_val)) {
    if (length(type_val) > 1) type_val[[1]] else type_val
  } else if (is.list(type_val) && length(type_val) > 0) {
    type_val[[1]]
  } else {
    ""
  }

  mb_type <- if (!is.null(type_map[[type_str]])) {
    type_map[[type_str]]
  } else {
    tolower(gsub(".*:", "", type_str))
  }

  res_lst_xtr <- get_main_parser_lst_ld(mb_type)

  if (is.null(res_lst_xtr)) {
    return(NULL)
  }

  res_df <- purrr::map(res_lst_xtr, function(i) {
    val <- purrr::pluck(res, !!!i, .default = NA)
    if (is.null(val)) {
      NA
    } else if (is.vector(val) && length(val) > 1) {
      paste0(val, collapse = "; ")
    } else {
      val
    }
  })

  mbid_str <- res_df$mbid
  if (!is.null(mbid_str) && grepl("musicbrainz.org/", mbid_str)) {
    res_df$mbid <- sub(".*musicbrainz\\.org/[^/]+/([^/]+)$", "\\1", mbid_str)
  }

  tibble::as_tibble(res_df)
}

#' @importFrom purrr map map_dfr pluck
#' @importFrom tibble tibble
#' @importFrom dplyr filter mutate select
#' @keywords internal
get_includes_parser_df <- function(res, includes) {
  df <- tibble::tibble(
    nm = c("releases", "recordings", "release-groups", "works", "artists", "labels", "media", "artist-credits", "tags", "genres", "artist-rels", "aliases", "annotation", "discids", "isrcs", "collections", "recording-level-rels", "work-level-rels"),
    node=c("releases", "recordings", "release-groups", "works", "artist-credit", "label-info", "media", "artist-credit", "tags", "genres", "relations", "aliases", "annotation", "media", "isrcs", "collections", "media", "media"),
    lst_xtr = list(
      list(
        release_mbid = "id", barcode = "barcode", packaging_id = "packaging-id",
        packaging_name = "packaging",
        title = "title", date = "date", status = "status", status_id = "status-id",
        quality = "quality", country = "country", disambiguation = "disambiguation"
      ),
      list(
        recording_mbid = "id", disambiguation = "disambiguation", length = "length",
        title = "title", video = "video"
      ),
      list(
        release_group_mbid = "id", title = "title", primary_type = "primary-type",
        primary_type_id = "primary-type-id", disambiguation = "disambiguation",
        first_release_date = "first-release-date"
      ),
      list(
        work_mbid = "id", title = "title", language = "language",
        disambiguation = "disambiguation"
      ),
      list(
        artist_mbid = list("artist", "id"), name = list("artist", "name"),
        sort_name = list("artist", "sort_name"), disambiguation = list("artist", "disambiguation")
      ),
      list(
        label_mbid = list("label", "id"), name = list("label", "name"), sort_name = list("label", "sort-name"),
        label_code = list("label", "label-code"), disambiguation = list("label", "disambiguation"),
        catalog_number = "catalog-number"
      ),
      list(format = "format", disc_count = "disc-count", track_count = "track-count"),
      list(
        artist_mbid = list("artist", "id"), name = list("artist", "name"),
        sort_name = list("artist", "sort_name"), join_phrase = "joinphrase"
      ),
      list(tag_name = "name", tag_count = "count"),
      list(genre_name = "name", genre_count = "count"),
      list(
        relation_type = "type", relation_type_id = "type-id", direction = "direction",
        target_type = "target-type", begin = "begin", end = "end", ended = "ended",
        target_id = list("target", "id"), target_name = list("target", "name")
      ),
      list(alias_name = "name", alias_sort_name = "sort_name", alias_type = "type", begin_date = "begin_date", end_date = "end_date"),
      list(annotation_body = "body"),
      list(discid = "discid", sid = "sid", freedb = "freedb", offset = "offset"),
      list(isrc = "isrc", recording_mbid = "recording_id"),
      list(collection_mbid = "id", collection_name = "name", collection_type = "type"),
      list(
        relation_type = "type", relation_type_id = "type-id", direction = "direction",
        target_type = "target-type", begin = "begin", end = "end", ended = "ended",
        target_id = list("target", "id"), target_name = list("target", "name")
      ),
      list(
        relation_type = "type", relation_type_id = "type-id", direction = "direction",
        target_type = "target-type", begin = "begin", end = "end", ended = "ended",
        target_id = list("target", "id"), target_name = list("target", "name")
      )
    )
  )
  df <- dplyr::filter(df, .data$nm %in% includes)
  df <- dplyr::mutate(df, lst = purrr::map(df$node, function(x) purrr::pluck(res, x, .default = NULL)))
  dplyr::select(df, -"node")
}

#' @importFrom purrr map map_dfr pluck
#' @importFrom tibble tibble
#' @importFrom dplyr filter mutate select
#' @keywords internal
get_includes_parser_df_ld <- function(res, includes) {
  df <- tibble::tibble(
    nm = c("releases", "recordings", "release-groups", "works", "artists", "labels", "media", "tags"),
    node = c("track", "track", "album", "work", "byArtist", "label", "media", "keywords"),
    lst_xtr = list(
      list(release_mbid = "@id", name = "name", date = "datePublished", country = "country",
           format = "musicReleaseFormat", catalog_number = "catalogNumber", barcode = "gtin14"),
      list(recording_mbid = "@id", name = "name", duration = "duration", description = "description"),
      list(release_group_mbid = "@id", name = "name", type = "@type", date = "datePublished"),
      list(work_mbid = "@id", name = "name", language = "inLanguage", description = "description"),
      list(artist_mbid = list("@id"), name = "name", sort_name = "alternateName"),
      list(label_mbid = "@id", name = "name", label_code = "identifier"),
      list(format = "format", disc_count = "num_discs", track_count = "num_tracks"),
      list(tag_name = "name", tag_count = "count")
    )
  )
  df <- dplyr::filter(df, .data$nm %in% includes)
  df <- dplyr::mutate(df, lst = purrr::map(df$node, function(x) purrr::pluck(res, x, .default = NULL)))
  dplyr::select(df, -"node")
}

#' @importFrom purrr map map_dfr pluck
#' @importFrom tibble tibble
parse_includes <- function(nm, lst_xtr, lst) {
  if (is.null(lst) || length(lst) == 0) {
    return(tibble::tibble({{nm}} := list(tibble::tibble())))
  }
  
  if (nm == "media" && is.data.frame(lst)) {
    tracks_by_medium <- purrr::map(seq_len(nrow(lst)), function(i) {
      m <- lst[i, , drop = FALSE]
      tracks_list <- m$tracks[[1]]
      if (is.null(tracks_list) || length(tracks_list) == 0) {
        return(tibble::tibble(
          medium_position = NA_integer_,
          medium_format = NA_character_,
          track_id = NA_character_,
          track_number = NA_integer_,
          track_title = NA_character_,
          track_number_str = NA_character_,
          recording_id = NA_character_,
          recording_title = NA_character_
        ))
      }
      purrr::map_dfr(tracks_list, function(t) {
        rec <- t$recording %||% list()
        tibble::tibble(
          medium_position = m$position,
          medium_format = m$format,
          track_id = t$id %||% NA_character_,
          track_number = t$position %||% NA_integer_,
          track_title = t$title %||% NA_character_,
          track_number_str = t$number %||% NA_character_,
          recording_id = rec$id %||% NA_character_,
          recording_title = rec$title %||% NA_character_
        )
      })
    })
    return(tibble::tibble({{nm}} := list(tracks_by_medium)))
  }
  
if (nm == "artist-credits") {
    return(tibble::tibble({{nm}} := list(tibble::tibble())))
  }
  
  if (nm == "recording-level-rels" || nm == "work-level-rels") {
    return(tibble::tibble({{nm}} := list(tibble::tibble())))
  }
  
  if (is.data.frame(lst)) {
    res_lst <- list(lst)
  } else {
    res_lst <- list(purrr::map_dfr(lst, function(x) purrr::map(lst_xtr, function(i) {
      val <- purrr::pluck(x, !!!i, .default = NA)
      if (is.list(val)) NA else as.character(val)
    })))
  }
tibble::tibble({{nm}} := res_lst)
}

#' @importFrom purrr map_dfr pluck
#' @importFrom tibble tibble
parse_includes_ld <- function(nm, lst_xtr, lst) {
  if (is.null(lst) || length(lst) == 0) {
    return(tibble::tibble({{nm}} := list(NULL)))
  }
  res_lst <- list(purrr::map_dfr(lst, function(x) purrr::map(lst_xtr, function(i) purrr::pluck(x, !!!i, .default = NA))))
  tibble::tibble({{nm}} := res_lst)
}

#' @keywords internal
validate_includes <- function(includes, available_includes){
  unsupported_includes <- base::setdiff(includes, available_includes)
  if(!is.null(unsupported_includes) && length(unsupported_includes)>0){
    if(length(available_includes)>0)
      message(paste("Only", paste0(paste0("'",available_includes,"'"), collapse = ", "),
                    "includes are supported by this function."))
    else
      message("No includes are supported by this function.")

    message(paste("Ignoring", paste0(paste0("'",unsupported_includes,"'"), collapse = ", ")))
  }
  base::intersect(includes, available_includes)
}
