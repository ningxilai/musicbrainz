context("Real API - Async Functions with Value")

test_that("lookup_artist_by_id_async returns real data", {
  skip_if_not_installed("future")
  library(future)
  plan(multisession, workers = 1)
  
  f <- lookup_artist_by_id_async("20ff3303-4fe2-4a47-a1b6-291e26aa3438")
  result <- future::value(f)
  
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_equal(result$mbid[1], "20ff3303-4fe2-4a47-a1b6-291e26aa3438")
  expect_equal(result$name[1], "James Brown")
})

test_that("search_artists_async returns real data", {
  skip_if_not_installed("future")
  library(future)
  plan(multisession, workers = 1)
  
  f <- search_artists_async("James Brown", limit = 5)
  result <- future::value(f)
  
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_true(nrow(result) <= 5)
})

test_that("browse_releases_by_async returns real data", {
  skip_if_not_installed("future")
  library(future)
  plan(multisession, workers = 1)
  
  f <- browse_releases_by_async("artist", "20ff3303-4fe2-4a47-a1b6-291e26aa3438", limit = 5)
  result <- future::value(f)
  
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_true(nrow(result) <= 5)
})

test_that("lookup_artist_relations_async returns relations", {
  skip_if_not_installed("future")
  library(future)
  plan(multisession, workers = 1)
  
  f <- lookup_artist_relations_async("20ff3303-4fe2-4a47-a1b6-291e26aa3438", includes = "artist-rels")
  result <- future::value(f)
  
  expect_s3_class(result, "data.frame")
  expect_true("artist-rels" %in% names(result))
})

test_that("async functions with format parameter work", {
  skip_if_not_installed("future")
  library(future)
  plan(multisession, workers = 1)
  
  f <- lookup_artist_by_id_async("20ff3303-4fe2-4a47-a1b6-291e26aa3438", format = "json")
  result <- future::value(f)
  
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("lookup_url_by_resource_async returns real data", {
  skip_if_not_installed("future")
  library(future)
  plan(multisession, workers = 1)
  Sys.sleep(1)
  
  f <- lookup_url_by_resource_async("http://www.jamesbrown.com/")
  result <- future::value(f)
  
  expect_true(is.data.frame(result) || is.null(result))
  if (is.data.frame(result)) {
    expect_true(nrow(result) > 0)
  }
})

test_that("lookup_release_group_genres_async returns genres", {
  skip_if_not_installed("future")
  library(future)
  plan(multisession, workers = 1)
  Sys.sleep(1)
  
  f <- lookup_release_group_genres_async("3bd76d40-7f0e-36b7-9348-91a33afee20e")
  result <- future::value(f)
  
  expect_true(is.data.frame(result) || is.null(result))
  if (is.data.frame(result)) {
    expect_true(nrow(result) > 0)
    expect_true("name" %in% names(result))
  }
})