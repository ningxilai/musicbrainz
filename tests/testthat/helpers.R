# Test helpers for mocking API responses

# Mock response for artist lookup
mock_artist_response <- function() {
  list(
    id = "20ff3303-4fe2-4a47-a1b6-291e26aa3438",
    type = "Person",
    type_id = "b6e035f4-3ce9-331c-97df-83397230b0df",
    score = 100,
    name = "James Brown",
    sort_name = "Brown, James",
    gender = "male",
    gender_id = "36d3d30a-839d-3eda-8cb3-29be4384e4a9",
    country = "US",
    disambiguation = "The Godfather of Soul"
  )
}

# Mock response for search
mock_search_response <- function(entity = "artists") {
  switch(entity,
    artists = list(
      created = "2024-01-01",
      count = 1,
      offset = 0,
      artists = list(
        list(
          id = "20ff3303-4fe2-4a47-a1b6-291e26aa3438",
          type = "Person",
          score = 100,
          name = "James Brown"
        )
      )
    ),
    releases = list(
      created = "2024-01-01",
      count = 1,
      offset = 0,
      releases = list(
        list(
          id = "abc123",
          title = "Test Release"
        )
      )
    )
  )
}

# Mock http response for crul
mock_crul_response <- function(status_code = 200L, content = NULL) {
  res <- crul::HttpResponse$new(
    status_code = status_code,
    content = charToRaw(content %||% ""),
    headers = list()
  )
  res
}

# Helper to suppress messages in tests
suppress_messages <- function(expr) {
  suppressMessages(expr)
}