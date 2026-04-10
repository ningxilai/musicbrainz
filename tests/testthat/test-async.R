context("Async Functions")

test_that("async functions require future package", {
  skip_if_not_installed("future")
  
  expect_true(exists("lookup_artist_by_id_async"))
  expect_true(exists("search_artists_async"))
})

test_that("async functions have correct parameters", {
  skip_if_not_installed("future")
  
  formals_artist <- formals(lookup_artist_by_id_async)
  expect_true("mbid" %in% names(formals_artist))
  
  formals_search <- formals(search_artists_async)
  expect_true("query" %in% names(formals_search))
})

test_that("async lookup functions are exported", {
  skip_if_not_installed("future")
  
  funcs <- c(
    "lookup_artist_by_id_async",
    "lookup_area_by_id_async",
    "lookup_release_by_id_async",
    "lookup_label_by_id_async",
    "lookup_recording_by_id_async",
    "lookup_work_by_id_async",
    "lookup_event_by_id_async",
    "lookup_instrument_by_id_async",
    "lookup_series_by_id_async",
    "lookup_url_by_id_async",
    "lookup_genre_by_id_async"
  )
  for (f in funcs) {
    expect_true(exists(f), label = f)
  }
})

test_that("async search functions are exported", {
  skip_if_not_installed("future")
  
  funcs <- c(
    "search_artists_async",
    "search_releases_async",
    "search_labels_async",
    "search_works_async",
    "search_areas_async",
    "search_events_async",
    "search_instruments_async",
    "search_places_async",
    "search_series_async",
    "search_recordings_async",
    "search_release_groups_async",
    "search_annotations_async",
    "search_genres_async"
  )
  for (f in funcs) {
    expect_true(exists(f), label = f)
  }
})

test_that("async browse functions are exported", {
  skip_if_not_installed("future")
  
  funcs <- c(
    "lookup_artists_by_id_async",
    "lookup_releases_by_id_async",
    "browse_artists_by_async",
    "browse_events_by_async",
    "browse_labels_by_async",
    "browse_places_by_async",
    "browse_recordings_by_async",
    "browse_releases_by_async",
    "browse_release_groups_by_async",
    "browse_works_by_async"
  )
  for (f in funcs) {
    expect_true(exists(f), label = f)
  }
})

test_that("async functions have format parameter for lookup", {
  skip_if_not_installed("future")
  
  formals_async <- formals(lookup_artist_by_id_async)
  expect_true("format" %in% names(formals_async))
})