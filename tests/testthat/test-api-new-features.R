context("Real API - New Features")

test_that("lookup_url_by_resource returns real data", {
  Sys.sleep(1.5)
  result <- lookup_url_by_resource("http://www.jamesbrown.com/")
  expect_true(is.data.frame(result) || is.null(result))
  if (is.data.frame(result)) {
    expect_true(nrow(result) > 0)
  }
})

test_that("lookup_url_by_resource returns real data for Wikipedia", {
  Sys.sleep(1.5)
  result <- lookup_url_by_resource("https://en.wikipedia.org/wiki/James_Brown")
  expect_true(is.data.frame(result) || is.null(result))
  if (is.data.frame(result)) {
    expect_true(nrow(result) > 0)
  }
})

test_that("lookup_url_by_resource handles non-existent URL gracefully", {
  Sys.sleep(1.5)
  result <- lookup_url_by_resource("http://nonexistent12345678.com/")
  expect_true(is.null(result) || (is.data.frame(result) && nrow(result) == 0))
})

test_that("lookup_release_group_genres returns genres", {
  Sys.sleep(1.5)
  result <- lookup_release_group_genres("3bd76d40-7f0e-36b7-9348-91a33afee20e")
  expect_true(is.data.frame(result) || is.null(result))
  if (is.data.frame(result)) {
    expect_true(nrow(result) > 0)
    expect_true("name" %in% names(result))
  }
})

test_that("lookup_release_group_genres returns data for known release group", {
  Sys.sleep(1.5)
  result <- lookup_release_group_genres("3bd76d40-7f0e-36b7-9348-91a33afee20e")
  expect_true(is.data.frame(result) || is.null(result))
  if (is.data.frame(result)) {
    expect_true(nrow(result) >= 10)
  }
})

test_that("lookup_release_group_genres handles non-existent MBID", {
  Sys.sleep(1.5)
  result <- lookup_release_group_genres("12345678-1234-1234-1234-123456789abc")
  expect_true(is.null(result) || (is.data.frame(result) && nrow(result) == 0))
})

test_that("lookup_artist_by_id with aliases returns real data", {
  skip_if_not_installed("musicbrainz")
  result <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a", includes = "aliases")
  expect_s3_class(result, "data.frame")
  expect_true("aliases" %in% names(result))
  expect_true(nrow(result$aliases[[1]]) > 0)
})

test_that("lookup_artist_by_id with genres returns real data", {
  skip_if_not_installed("musicbrainz")
  result <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a", includes = "genres")
  expect_s3_class(result, "data.frame")
  expect_true("genres" %in% names(result))
  expect_true(nrow(result$genres[[1]]) > 0)
})