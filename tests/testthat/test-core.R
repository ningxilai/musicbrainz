context("core")

test_that("cover_art_url generates correct URL", {
  expect_equal(
    cover_art_url("abc123"),
    "https://coverartarchive.org/release/abc123/front"
  )
  expect_equal(
    cover_art_url("abc123", 250),
    "https://coverartarchive.org/release/abc123/front-250"
  )
  expect_equal(
    cover_art_url("abc123", NULL),
    "https://coverartarchive.org/release/abc123/front"
  )
  expect_equal(
    cover_art_url("abc123", 500),
    "https://coverartarchive.org/release/abc123/front-500"
  )
})