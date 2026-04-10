context("Real API - Browse Functions")

test_that("browse_artists_by returns real data from API", {
  result <- browse_artists_by("area", "8a754e96-a6bf-4e18-8c5d-16b41d50bce6", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("browse_releases_by returns real data from API", {
  result <- browse_releases_by("artist", "0103c1cc-4a09-4a5d-a344-56ad99a77193", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("browse_labels_by returns real data from API", {
  result <- browse_labels_by("area", "8a754e96-a6bf-4e18-8c5d-16b41d50bce6", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("browse_works_by returns real data from API", {
  result <- browse_works_by("artist", "0103c1cc-4a09-4a5d-a344-56ad99a77193", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("browse_events_by returns real data from API", {
  result <- browse_events_by("area", "8a754e96-a6bf-4e18-8c5d-16b41d50bce6", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("browse_places_by returns real data from API", {
  result <- browse_places_by("area", "8a754e96-a6bf-4e18-8c5d-16b41d50bce6", limit = 5)
  expect_s3_class(result, "data.frame")
})

test_that("browse_recordings_by returns real data from API", {
  result <- browse_recordings_by("artist", "0103c1cc-4a09-4a5d-a344-56ad99a77193", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("browse_release_groups_by returns real data from API", {
  result <- browse_release_groups_by("artist", "0103c1cc-4a09-4a5d-a344-56ad99a77193", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("browse_with_includes works", {
  result <- browse_artists_by("area", "8a754e96-a6bf-4e18-8c5d-16b41d50bce6", 
                              includes = "tags", limit = 5)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("browse with offset works", {
  result1 <- browse_releases_by("artist", "0103c1cc-4a09-4a5d-a344-56ad99a77193", 
                                limit = 3, offset = 0)
  result2 <- browse_releases_by("artist", "0103c1cc-4a09-4a5d-a344-56ad99a77193", 
                                limit = 3, offset = 3)
  expect_s3_class(result1, "data.frame")
  expect_s3_class(result2, "data.frame")
})

test_that("browse_releases_by with media includes works", {
  result <- browse_releases_by("artist", "0103c1cc-4a09-4a5d-a344-56ad99a77193", 
                              includes = c("artists"), limit = 3)
  expect_s3_class(result, "data.frame")
})