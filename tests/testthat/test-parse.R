context("parse")

test_that("get_main_parser_lst returns correct parsers", {
  # Use ::: to access non-exported function
  artists_xtr <- musicbrainz:::get_main_parser_lst("artists")
  expect_true(is.list(artists_xtr))
  expect_true("mbid" %in% names(artists_xtr))
  expect_true("name" %in% names(artists_xtr))
  
  releases_xtr <- musicbrainz:::get_main_parser_lst("releases")
  expect_true(is.list(releases_xtr))
  expect_true("mbid" %in% names(releases_xtr))
})

test_that("get_main_parser_lst_ld returns correct parsers", {
  artists_ld_xtr <- musicbrainz:::get_main_parser_lst_ld("artist")
  expect_true(is.list(artists_ld_xtr))
  
  release_ld_xtr <- musicbrainz:::get_main_parser_lst_ld("release")
  expect_true(is.list(release_ld_xtr))
})

test_that("parse_list handles data.frame input", {
  # Create a mock data.frame like API returns
  mock_df <- data.frame(
    id = c("123", "456"),
    name = c("Test Artist 1", "Test Artist 2"),
    type = c("Person", "Group"),
    score = c(100, 90),
    stringsAsFactors = FALSE
  )
  
  # Convert to list of rows like parse_list expects
  mock_list <- split(mock_df, seq_len(nrow(mock_df)))
  
  result <- musicbrainz:::parse_list("artists", mock_list, 0, 2)
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 2)
})

test_that("validate_includes works correctly", {
  # Valid includes
  result <- musicbrainz:::validate_includes(c("tags"), c("tags", "releases"))
  expect_equal(result, "tags")
  
  # Invalid includes - should message and filter
  result2 <- musicbrainz:::validate_includes(c("tags", "invalid"), c("tags"))
  expect_equal(result2, "tags")
})