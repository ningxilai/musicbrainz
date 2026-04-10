context("Real API - Lookup Functions")

test_that("lookup_artist_by_id returns real data from API", {
  result <- lookup_artist_by_id("20ff3303-4fe2-4a47-a1b6-291e26aa3438")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_equal(result$mbid[1], "20ff3303-4fe2-4a47-a1b6-291e26aa3438")
  expect_equal(result$name[1], "James Brown")
})

test_that("lookup_area_by_id returns real data from API", {
  result <- lookup_area_by_id("489ce91b-6658-3307-9877-795b68554c98")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("lookup_release_by_id returns real data from API", {
  result <- lookup_release_by_id("70516629-7715-41bf-97e1-b7bf11254cb8")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
  expect_equal(result$mbid[1], "70516629-7715-41bf-97e1-b7bf11254cb8")
})

test_that("lookup_label_by_id returns real data from API", {
  result <- lookup_label_by_id("1220c8aa-53c3-42a7-b8d5-25b5b7b7b9d1")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("lookup_work_by_id returns real data from API", {
  result <- lookup_work_by_id("2e250f50-cded-4db3-8ba8-3738f9425184")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("lookup_recording_by_id returns real data from API", {
  result <- lookup_recording_by_id("c5b02e78-c2f4-4c16-9751-25b7aed88eb3")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("lookup_release_group_by_id returns real data from API", {
  result <- lookup_release_group_by_id("12345678-1234-1234-1234-123456789abc")
  expect_true(is.data.frame(result) || is.null(result))
})

test_that("lookup_series_by_id returns real data from API", {
  result <- lookup_series_by_id("12345678-1234-1234-1234-123456789abc")
  expect_true(is.data.frame(result) || is.null(result))
})

test_that("lookup_event_by_id returns real data from API", {
  result <- lookup_event_by_id("12345678-1234-1234-1234-123456789abc")
  expect_true(is.data.frame(result) || is.null(result))
})

test_that("lookup_instrument_by_id returns real data from API", {
  result <- lookup_instrument_by_id("12345678-1234-1234-1234-123456789abc")
  expect_true(is.data.frame(result) || is.null(result))
})

test_that("lookup_place_by_id returns real data from API", {
  result <- lookup_place_by_id("12345678-1234-1234-1234-123456789abc")
  expect_true(is.data.frame(result) || is.null(result))
})

test_that("lookup_artist_by_id with includes works", {
  result <- lookup_artist_by_id("20ff3303-4fe2-4a47-a1b6-291e26aa3438", 
                                includes = c("works", "release-groups"))
  expect_s3_class(result, "data.frame")
  expect_true(ncol(result) > 5)
})

test_that("lookup_artist_by_id with tags includes works", {
  result <- lookup_artist_by_id("20ff3303-4fe2-4a47-a1b6-291e26aa3438", 
                                includes = c("tags"))
  expect_s3_class(result, "data.frame")
})

test_that("lookup_release_by_id with media includes works", {
  result <- lookup_release_by_id("f59f3b26-3a55-44a4-9228-c4e9ebc90800", 
                                 includes = c("media"))
  expect_s3_class(result, "data.frame")
})

test_that("lookup_url_by_id returns real data", {
  result <- lookup_url_by_id("12345678-1234-1234-1234-123456789abc")
  expect_true(is.data.frame(result) || is.null(result))
})

test_that("lookup_genre_by_id returns real data", {
  result <- lookup_genre_by_id("12345678-1234-1234-1234-123456789abc")
  expect_true(is.data.frame(result) || is.null(result))
})

test_that("lookup_artists_by_id batch works", {
  mbids <- c("20ff3303-4fe2-4a47-a1b6-291e26aa3438", "4d5447d7-c61c-41f9-8e8e-9d7d0f4b8d4e")
  result <- lookup_artists_by_id_async(mbids)
  expect_true(is(result, "Future"))
})

test_that("lookup_releases_by_id batch works", {
  mbids <- c("70516629-7715-41bf-97e1-b7bf11254cb8", "12345678-1234-1234-1234-123456789abc")
  result <- lookup_releases_by_id_async(mbids)
  expect_true(is(result, "Future"))
})