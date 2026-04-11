<!-- README.md is generated from README.Rmd. Please edit that file -->

# musicbrainz <img src="man/figures/logo.png" align="right" />

The goal of musicbrainz is to make it easy to call the MusicBrainz Database API from R. Currently API does NOT require authentication for reading the data, however, requests to the database are subject to a rate limit of 1.1 request/sec. The package utilizes `ratelimitr` to make sure you don't need to worry about exceeding that limit.

## Installation

```r
# Install from CRAN
install.packages("musicbrainz")

# Or install from GitHub
# install.packages("devtools")
devtools::install_github("ningxilai/musicbrainz")
```

## Features

- **Search**: Free text search across all entity types
- **Lookup**: Retrieve detailed information by MusicBrainz ID (mbid)
- **Browse**: Get related entities (e.g., all releases by an artist)
- **Async**: Asynchronous versions using the `future` package
- **Caching**: Built-in memoisation for repeated requests
- **Rate limiting**: Automatic rate limiting (1 req/sec)

## Example

There are three main families of functions in `musicbrainz`: search, lookup, and browse.

### Search

Search for artists, releases, works, and more:

```r
library(musicbrainz)
library(dplyr)

# Search for artists
miles_df <- search_artists("Miles Davis")
# Returning artists 1 to 25 of 2443
miles_df
# # A tibble: 25 x 28
#    mbid  type  type_id score name        sort_name     gender country
#    <chr> <chr> <chr>   <int> <chr>        <chr>         <chr>  <chr>  
#  1 561d… Person b6e035…   100 Miles Davis Davis, Miles  male   US     

# Search for releases
abbey_road <- search_releases("Abbey Road", limit = 5)
# # A tibble: 5 x 17
#    mbid                               title           date  country
#    <chr>                              <chr>           <chr> <chr>  
#  1 7051… Abbey Road (Remastered)     2019-09-13      US    
#  2 7051… Abbey Road                   2019-04-19      XW    
```

### Lookup

Get detailed information by MusicBrainz ID:

```r
# Lookup artist by mbid
miles_lookup <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a")
# # A tibble: 1 x 28
#   mbid  type   name        country disambiguation
#   <chr> <chr>  <chr>       <chr>    <chr>         
# 1 561d… Person Miles Davis US       

# Lookup with includes (additional data)
miles_with_works <- lookup_artist_by_id(
  "561d854a-6a28-4aa7-8c99-323e6ce46c2a",
  includes = c("works", "release-groups")
)
```

### Browse

Get related entities:

```r
# Browse releases by artist
miles_releases <- browse_releases_by("artist", "561d854a-6a28-4aa7-8c99-323e6ce46c2a")
# Returning releases 1 to 25 of 1267

# Browse artists by area (e.g., all artists from USA)
us_artists <- browse_artists_by("area", "489ce91b-6658-3307-9877-795b68554c98", limit = 10)

# Browse with includes
miles_with_tags <- browse_releases_by(
  "artist", 
  "561d854a-6a28-4aa7-8c99-323e6ce46c2a",
  includes = c("tags", "artists"),
  limit = 5
)
```

### Asynchronous Operations

For batch operations, use async functions:

```r
library(future)
plan(multisession)  # Enable parallel processing

# Batch lookup multiple artists
mbids <- c(
  "561d854a-6a28-4aa7-8c99-323e6ce46c2a",  # Miles Davis
  "20ff3303-4fe2-4a47-a1b6-291e26aa3438",  # James Brown
  "b10bbbfc-cf9e-42e0-a5e0-4d3aee7aa7d0"   # The Beatles
)

# Launch async requests (returns immediately)
f <- lookup_artists_by_id_async(mbids)

# Get results when ready
results <- future::value(f)
# # A tibble: 3 x 28

# Async search
search_f <- search_artists_async("Joni Mitchell", limit = 5)
search_results <- future::value(search_f)

# Available async functions:
# - lookup_*_async() - lookup by ID
# - search_*_async() - search operations  
# - browse_*_async() - browse operations
# - lookup_*_by_id_async() - batch lookups
```

### Other Examples

```r
# Search for genres
all_genres <- search_genres(all = TRUE)
# Returns all 2132 genres

# Search with strict matching (exact matches only)
exact_matches <- search_artists("Beatles", strict = TRUE)

# Search with pagination
page1 <- search_artists("jazz", limit = 25, offset = 0)
page2 <- search_artists("jazz", limit = 25, offset = 25)

# Browse different entity types
# - by area: browse_*_by("area", mbid)
# - by artist: browse_*_by("artist", mbid)
# - by release: browse_*_by("release", mbid)
# - by recording: browse_*_by("recording", mbid)
# - by work: browse_*_by("work", mbid)
# - by label: browse_*_by("label", mbid)

# Cover Art URL generation
cover_art_url("70516629-7715-41bf-97e1-b7bf11254cb8")
# Returns: "https://coverartarchive.org/release/70516629-7715-41bf-97e1-b7bf11254cb8/front"
```

## Caching

Results are cached using `memoise`. Repeated calls with the same parameters return cached results instantly:

```r
# First call - hits API
result1 <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a")

# Second call - uses cache (instant)
result2 <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a")
```

To clear cache: `memoise::forget(musicbrainz:::get_data)`

## References

1. Details of the MusicBrainz database API: <https://musicbrainz.org/doc/Development/XML_Web_Service/Version_2>
2. Details about rate limits: <https://musicbrainz.org/doc/XML_Web_Service/Rate_Limiting>
