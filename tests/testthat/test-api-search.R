context("Real API - Search Functions")

test_that("search_artists returns real data from API", {
  result <- search_artists("Beatles", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("Beatles", result$name, ignore.case = TRUE)))
})

test_that("search_releases returns real data from API", {
  result <- search_releases("Abbey Road", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search_labels returns real data from API", {
  result <- search_labels("Universal", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search_works returns real data from API", {
  result <- search_works("Symphony", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search_areas returns real data from API", {
  result <- search_areas("London", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search_events returns real data from API", {
  result <- search_events("festival", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("search_instruments returns real data from API", {
  result <- search_instruments("piano", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search_places returns real data from API", {
  result <- search_places("Madison Square Garden", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("search_series returns real data from API", {
  result <- search_series("BBC", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("search_recordings returns real data from API", {
  result <- search_recordings("Imagine", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search_release_groups returns real data from API", {
  result <- search_release_groups("Dark Side of the Moon", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search_annotations returns real data from API", {
  result <- search_annotations("jazz", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("search_genres returns real data from API", {
  result <- search_genres(limit = 10)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("search with strict works", {
  result <- search_artists("Beatles", strict = TRUE, limit = 10)
  expect_s3_class(result, "data.frame")
  if (nrow(result) > 0) {
    expect_true(all(result$score == 100))
  }
})

test_that("search with offset works", {
  result1 <- search_artists("rock", limit = 5, offset = 0)
  result2 <- search_artists("rock", limit = 5, offset = 5)
  expect_s3_class(result1, "data.frame")
  expect_s3_class(result2, "data.frame")
})

test_that("search_artists_async returns future", {
  skip_if_not_installed("future")
  f <- search_artists_async("Beatles", limit = 3)
  expect_true(is(f, "Future"))
})