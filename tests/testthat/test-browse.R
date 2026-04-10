context("browse")

test_that("browse functions are exported", {
  funcs <- c(
    "browse_artists_by",
    "browse_releases_by",
    "browse_labels_by",
    "browse_works_by",
    "browse_events_by",
    "browse_places_by",
    "browse_recordings_by",
    "browse_release_groups_by"
  )
  for (f in funcs) {
    expect_true(exists(f) || f %in% ls("package:musicbrainz"),
                 label = f)
  }
})

test_that("browse_artists_by has correct parameters", {
  formals_all <- names(formals(browse_artists_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
  expect_true("includes" %in% formals_all)
  expect_true("limit" %in% formals_all)
  expect_true("offset" %in% formals_all)
})

test_that("browse_artists_by validates entity", {
  expect_error(browse_artists_by("invalid_entity", "abc-123"))
})

test_that("browse_events_by has correct parameters", {
  formals_all <- names(formals(browse_events_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
})

test_that("browse_labels_by has correct parameters", {
  formals_all <- names(formals(browse_labels_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
})

test_that("browse_places_by has correct parameters", {
  formals_all <- names(formals(browse_places_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
})

test_that("browse_recordings_by has correct parameters", {
  formals_all <- names(formals(browse_recordings_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
  expect_true("includes" %in% formals_all)
})

test_that("browse_releases_by has correct parameters", {
  formals_all <- names(formals(browse_releases_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
})

test_that("browse_release_groups_by has correct parameters", {
  formals_all <- names(formals(browse_release_groups_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
})

test_that("browse_works_by has correct parameters", {
  formals_all <- names(formals(browse_works_by))
  expect_true("entity" %in% formals_all)
  expect_true("mbid" %in% formals_all)
})