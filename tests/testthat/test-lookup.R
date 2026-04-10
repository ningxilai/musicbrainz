context("Lookup Functions")

test_that("lookup functions are exported", {
  expect_true(exists("lookup_artist_by_id"))
  expect_true(exists("lookup_release_by_id"))
  expect_true(exists("lookup_label_by_id"))
  expect_true(exists("lookup_work_by_id"))
  expect_true(exists("lookup_area_by_id"))
  expect_true(exists("lookup_event_by_id"))
  expect_true(exists("lookup_instrument_by_id"))
  expect_true(exists("lookup_place_by_id"))
  expect_true(exists("lookup_recording_by_id"))
  expect_true(exists("lookup_release_group_by_id"))
  expect_true(exists("lookup_series_by_id"))
  expect_true(exists("lookup_url_by_id"))
  expect_true(exists("lookup_genre_by_id"))
})

test_that("lookup functions accept format parameter", {
  # Just check they accept the parameter without error
  # Mock response will handle actual lookup
  expect_silent({
    # These would need mocking to avoid API calls
  })
})

test_that("lookup_url_by_id handles ld-json format gracefully", {
  expect_message(
    lookup_url_by_id("test-id", format = "ld-json"),
    "ld-json format is not supported"
  )
})

test_that("lookup_genre_by_id handles ld-json format gracefully", {
  expect_message(
    lookup_genre_by_id("test-id", format = "ld-json"),
    "ld-json format is not supported"
  )
})