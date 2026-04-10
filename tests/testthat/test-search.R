context("Search Functions")

test_that("search functions are exported", {
  expect_true(exists("search_artists"))
  expect_true(exists("search_releases"))
  expect_true(exists("search_labels"))
  expect_true(exists("search_works"))
  expect_true(exists("search_areas"))
  expect_true(exists("search_events"))
  expect_true(exists("search_instruments"))
  expect_true(exists("search_places"))
  expect_true(exists("search_series"))
  expect_true(exists("search_recordings"))
  expect_true(exists("search_release_groups"))
  expect_true(exists("search_annotations"))
  expect_true(exists("search_genres"))
})

test_that("search_genres has correct parameters", {
  formals_all <- names(formals(search_genres))
  expect_true("all" %in% formals_all)
})

test_that("search_artists has correct parameters", {
  formals_all <- names(formals(search_artists))
  expect_true("query" %in% formals_all)
  expect_true("limit" %in% formals_all)
  expect_true("offset" %in% formals_all)
  expect_true("strict" %in% formals_all)
})

test_that("search_releases has correct parameters", {
  formals_all <- names(formals(search_releases))
  expect_true("query" %in% formals_all)
  expect_true("limit" %in% formals_all)
  expect_true("offset" %in% formals_all)
  expect_true("strict" %in% formals_all)
})

test_that("search_labels has correct parameters", {
  formals_all <- names(formals(search_labels))
  expect_true("query" %in% formals_all)
})

test_that("search_works has correct parameters", {
  formals_all <- names(formals(search_works))
  expect_true("query" %in% formals_all)
})

test_that("search_areas has correct parameters", {
  formals_all <- names(formals(search_areas))
  expect_true("query" %in% formals_all)
})

test_that("search_events has correct parameters", {
  formals_all <- names(formals(search_events))
  expect_true("query" %in% formals_all)
})

test_that("search_instruments has correct parameters", {
  formals_all <- names(formals(search_instruments))
  expect_true("query" %in% formals_all)
})

test_that("search_places has correct parameters", {
  formals_all <- names(formals(search_places))
  expect_true("query" %in% formals_all)
})

test_that("search_series has correct parameters", {
  formals_all <- names(formals(search_series))
  expect_true("query" %in% formals_all)
})

test_that("search_recordings has correct parameters", {
  formals_all <- names(formals(search_recordings))
  expect_true("query" %in% formals_all)
})

test_that("search_release_groups has correct parameters", {
  formals_all <- names(formals(search_release_groups))
  expect_true("query" %in% formals_all)
})

test_that("search_annotations has correct parameters", {
  formals_all <- names(formals(search_annotations))
  expect_true("query" %in% formals_all)
})