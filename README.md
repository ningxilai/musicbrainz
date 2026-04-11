
<!-- README.md is generated from README.Rmd. Please edit that file -->

[![CRAN_Status_Badge](http://www.r-pkg.org/badges/version/musicbrainz)](http://cran.r-project.org/package=musicbrainz)

# musicbrainz <img src="man/figures/logo.png" align="right" />

The goal of `musicbrainz` is to make it easy to call the MusicBrainz
Database API from R. Currently API does NOT require authentication for
reading the data, however, requests to the database are subject to a
rate limit of 1 request/sec. The package utilizes `crul` for HTTP
requests with automatic rate limiting.

## Installation

You can install musicbrainz from CRAN or GitHub:

``` r
# install.packages("devtools")
devtools::install_github("ningxilai/musicbrainz")
```

## Features

- **Search**: Free text search across all entity types (12 types)
- **Lookup**: Retrieve detailed information by MusicBrainz ID (mbid) (13
  entity types)
- **Browse**: Get related entities (e.g., all releases by an artist) (7
  entity types)
- **Relations**: Get entity relationships (artist, release, recording,
  work, label)
- **Collection**: Browse collections by collection ID or editor
- **Async**: Asynchronous versions using the `future` package
- **Caching**: Built-in memoisation for repeated requests
- **Rate limiting**: Automatic rate limiting (1 req/sec)
- **JSON-LD**: Support for JSON-LD format (`format = "ld-json"`)
- **HTTP Client**: Uses `crul` for HTTP requests

## Example

There are three main families of functions in `musicbrainz`: search,
lookup, and browse.

### Search

Search for artists, releases, works, and more:

``` r
library(musicbrainz)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union

# Search for artists
miles_df <- search_artists("Miles Davis")
#> Returning artists 1 to 18 of 4051
miles_df
#> # A tibble: 25 × 28
#>    mbid             type  type_id score name  sort_name gender gender_id country
#>    <chr>            <chr> <chr>   <int> <chr> <chr>     <chr>  <chr>     <chr>  
#>  1 561d854a-6a28-4… Pers… b6e035…   100 Mile… Davis, M… male   36d3d30a… US     
#>  2 fe7245e7-d734-4… Group e431f5…    72 Mile… Davis, M… <NA>   <NA>      US     
#>  3 f137837b-fa55-4… Group e431f5…    66 Mile… Davis, M… <NA>   <NA>      US     
#>  4 16d2b8e6-8930-4… Group e431f5…    64 The … Davis, M… <NA>   <NA>      <NA>   
#>  5 03606dee-b333-4… Group e431f5…    63 Mile… Davis, M… <NA>   <NA>      US     
#>  6 88130878-7ee9-4… Group e431f5…    61 Mile… Davis, M… <NA>   <NA>      <NA>   
#>  7 fa3baa96-ab14-4… Pers… b6e035…    61 Veng… Vengeance male   36d3d30a… US     
#>  8 616bb8ca-c0d5-4… <NA>  <NA>       61 Mile… Prower, … <NA>   <NA>      <NA>   
#>  9 55920730-831f-4… Group e431f5…    61 Mile… Miles Da… <NA>   <NA>      <NA>   
#> 10 d74d6350-a042-4… Pers… b6e035…    61 Mile… Moody, M… <NA>   <NA>      <NA>   
#> # ℹ 15 more rows
#> # ℹ 19 more variables: disambiguation <chr>, area_id <chr>, area_name <chr>,
#> #   area_sort_name <chr>, area_disambiguation <lgl>, area_iso <lgl>,
#> #   begin_area_id <chr>, begin_area_name <chr>, begin_area_sort_name <chr>,
#> #   begin_area_disambiguation <lgl>, end_area_id <chr>, end_area_name <chr>,
#> #   end_area_sort_name <chr>, end_area_disambiguation <lgl>,
#> #   life_span_begin <chr>, life_span_end <chr>, life_span_ended <lgl>, …
```

### Lookup

Get detailed information by MusicBrainz ID:

``` r
# Lookup artist by mbid
miles_lookup <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a")
miles_lookup
#> # A tibble: 1 × 28
#>   mbid              type  type_id score name  sort_name gender gender_id country
#>   <chr>             <chr> <chr>   <chr> <chr> <chr>     <chr>  <chr>     <chr>  
#> 1 561d854a-6a28-4a… Pers… b6e035… <NA>  Mile… Davis, M… Male   36d3d30a… US     
#> # ℹ 19 more variables: disambiguation <chr>, area_id <chr>, area_name <chr>,
#> #   area_sort_name <chr>, area_disambiguation <chr>, area_iso <chr>,
#> #   begin_area_id <chr>, begin_area_name <chr>, begin_area_sort_name <chr>,
#> #   begin_area_disambiguation <chr>, end_area_id <chr>, end_area_name <chr>,
#> #   end_area_sort_name <chr>, end_area_disambiguation <chr>,
#> #   life_span_begin <chr>, life_span_end <chr>, life_span_ended <chr>,
#> #   ipis <chr>, isnis <chr>

# Lookup with includes (additional data)
miles_with_works <- lookup_artist_by_id(
  "561d854a-6a28-4aa7-8c99-323e6ce46c2a",
  includes = c("works", "release-groups"))

# Lookup URL by actual URL string
lookup_url_by_resource("https://en.wikipedia.org/wiki/James_Brown")
#> http error code: 404
#> Attempt number 2
#> http error code: 404
#> Attempt number 3
#> This is the last attempt, if it fails will return NULL
#> http error code: 404
#> NULL

# Get genres for a release group
lookup_release_group_genres("3bd76d40-7f0e-36b7-9348-91a33afee20e")
#> # A tibble: 15 × 4
#>    name               id                                   count disambiguation
#>    <chr>              <chr>                                <int> <chr>         
#>  1 alternative metal  7983ff25-ddf9-411e-a7f9-6cca238bff79     5 ""            
#>  2 alternative rock   ceeaa283-5d7b-4202-8d1d-e25d116b2a18     1 ""            
#>  3 art rock           b7ef058e-6d83-4ca4-8123-9724bff4648b     1 ""            
#>  4 electro            60f00d05-df4d-496e-8f5a-c45c03a56ad4     1 ""            
#>  5 electro-industrial 6e2e809f-8c54-4e0f-aca0-0642771ab3cf     1 ""            
#>  6 electronic         89255676-1f14-4dd8-bbad-fca839d6aff4     2 ""            
#>  7 glitch             18b010d7-7d85-4445-a4a8-1889a4688308     1 ""            
#>  8 hard rock          51cb9f91-e6a2-41bf-891f-e78e3f1e52ab     1 ""            
#>  9 idm                8eb583f1-4fd7-460c-8246-dcdccc0e3ef9     1 ""            
#> 10 industrial         060beed7-e597-4c42-8e25-5bf8bd5dd3cb     8 ""            
#> 11 industrial metal   d4df54b5-67b4-4fb7-8f73-79e71717a501     4 ""            
#> 12 industrial rock    ffbc9907-c9be-4ace-876b-b7fd5b9d51f9    13 ""            
#> 13 post-industrial    53ceafec-ced4-4bec-ac57-d00cbf3a0c29     1 ""            
#> 14 rock               0e3fc579-2d24-4f20-9dae-736e1ec78798     3 ""            
#> 15 synth-pop          988e91a3-3341-416d-b7f8-7dbef6848dac     1 ""

# Get artist relationships (members, etc.)
lookup_artist_relations("20ff3303-4fe2-4a47-a1b6-291e26aa3438", includes = "artist-rels")
#> # A tibble: 1 × 29
#>   mbid              type  type_id score name  sort_name gender gender_id country
#>   <chr>             <chr> <chr>   <chr> <chr> <chr>     <chr>  <chr>     <chr>  
#> 1 20ff3303-4fe2-4a… Pers… b6e035… <NA>  Jame… Brown, J… Male   36d3d30a… US     
#> # ℹ 20 more variables: disambiguation <chr>, area_id <chr>, area_name <chr>,
#> #   area_sort_name <chr>, area_disambiguation <chr>, area_iso <chr>,
#> #   begin_area_id <chr>, begin_area_name <chr>, begin_area_sort_name <chr>,
#> #   begin_area_disambiguation <chr>, end_area_id <chr>, end_area_name <chr>,
#> #   end_area_sort_name <chr>, end_area_disambiguation <chr>,
#> #   life_span_begin <chr>, life_span_end <chr>, life_span_ended <chr>,
#> #   ipis <chr>, isnis <chr>, `artist-rels` <list>
```

### Browse

We can also browse linked records (such as all releases by Miles Davis).

``` r
# Browse releases by artist
miles_releases <- browse_releases_by("artist", "561d854a-6a28-4aa7-8c99-323e6ce46c2a")
#> Returning releases 1 to 25 of 1927
miles_releases
#> # A tibble: 25 × 17
#>    mbid     score count title status status_id packaging_id packaging_name date 
#>    <chr>    <int> <lgl> <chr> <chr>  <chr>     <lgl>        <lgl>          <chr>
#>  1 16ed7b4…    NA NA    Vol.… Offic… 4e304316… NA           NA             1954 
#>  2 20ff542…    NA NA    I've… Offic… 4e304316… NA           NA             1953 
#>  3 3bdbd27…    NA NA    Yest… Offic… 4e304316… NA           NA             1951 
#>  4 49aa17f…    NA NA    Youn… <NA>   <NA>      NA           NA             1952 
#>  5 4a8c187…    NA NA    Clas… Offic… 4e304316… NA           NA             1954 
#>  6 645ad83…    NA NA    The … Offic… 4e304316… NA           NA             1953 
#>  7 6c101d7…    NA NA    Budo… Offic… 4e304316… NA           NA             1949…
#>  8 6fbb6d1…    NA NA    Mode… Offic… 4e304316… NA           NA             1951 
#>  9 7acd38f…    NA NA    Mile… Offic… 4e304316… NA           NA             1955…
#> 10 8292500…    NA NA    Mile… Offic… 4e304316… NA           NA             1953 
#> # ℹ 15 more rows
#> # ℹ 8 more variables: country <chr>, disambiguation <chr>, barcode <chr>,
#> #   asin <lgl>, track_count <lgl>, quality <chr>, release_group_id <lgl>,
#> #   release_group_primary_type <lgl>

# Browse artists by area (e.g., all artists from USA)
us_artists <- browse_artists_by("area", "489ce91b-6658-3307-9877-795b68554c98", limit = 10)
#> Returning artists 1 to 10 of 362512

# Browse collections
browse_collection_releases("f4784850-3844-11e0-9e42-0800200c9a66")
#> http error code: 404
#> Attempt number 2
#> http error code: 404
#> Attempt number 3
#> This is the last attempt, if it fails will return NULL
#> http error code: 404
#> NULL
get_collections_by_editor("rob")
#> $`collection-count`
#> [1] 4
#> 
#> $`collection-offset`
#> [1] 0
#> 
#> $collections
#>                                type-id                                   id
#> 1 de6aedf5-73c2-3f7c-88f8-e128c189a205 005b5c07-cd88-32a4-805e-1d358ef1cfa3
#> 2 dda5c90e-4b0b-3482-a6a9-090844e0860e 49b40907-e078-4f15-801f-13167971f567
#> 3 dda5c90e-4b0b-3482-a6a9-090844e0860e 927b919d-672e-42b3-96d5-4b968fa1eaa4
#> 4 ca023ecf-a230-39f4-a252-a8d3b4d59c24 edf6a281-6155-312d-8c26-2521a0fe71bb
#>   entity-type editor                 type event-count             name
#> 1       event    rob            Attending           0        Attending
#> 2   recording    rob Recording collection          NA    LB Radio Test
#> 3   recording    rob Recording collection          NA Empty collection
#> 4       event    rob      Maybe attending           0  Maybe attending
#>   recording-count
#> 1              NA
#> 2               3
#> 3               0
#> 4              NA
```

### Asynchronous Operations

For batch operations, use async functions:

``` r
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
#> http error code: 404
#> Attempt number 2
#> http error code: 404
#> Attempt number 3
#> This is the last attempt, if it fails will return NULL
#> http error code: 404

# Async search
search_f <- search_artists_async("Joni Mitchell", limit = 5)
search_results <- future::value(search_f)
#> Returning artists 1 to 17 of 1708
```

## Other Examples

``` r
# Search for genres
all_genres <- search_genres(all = TRUE)

# Search with strict matching (exact matches only)
exact_matches <- search_artists("Beatles", strict = TRUE)
#> Returning artists 1 to 18 of 271

# Search with pagination
page1 <- search_artists("jazz", limit = 25, offset = 0)
#> Returning artists 1 to 18 of 19490
page2 <- search_artists("jazz", limit = 25, offset = 25)
#> Returning artists 26 to 43 of 19490

# Browse different entity types
# - by area: browse_*_by("area", mbid)
# - by artist: browse_*_by("artist", mbid)
# - by release: browse_*_by("release", mbid)
# - by recording: browse_*_by("recording", mbid)
# - by work: browse_*_by("work", mbid)
# - by label: browse_*_by("label", mbid)

# Cover Art URL generation
cover_art_url("70516629-7715-41bf-97e1-b7bf11254cb8")
#> [1] "https://coverartarchive.org/release/70516629-7715-41bf-97e1-b7bf11254cb8/front"
# Returns: "https://coverartarchive.org/release/70516629-7715-41bf-97e1-b7bf11254cb8/front"

# Using different size (e.g., 500px thumbnail)
cover_art_url("70516629-7715-41bf-97e1-b7bf11254cb8", size = 500)
#> [1] "https://coverartarchive.org/release/70516629-7715-41bf-97e1-b7bf11254cb8/front-500"
# Returns: "https://coverartarchive.org/release/70516629-7715-41bf-97e1-b7bf11254cb8/front-500"
```

## Caching

Results are cached using `memoise`. Repeated calls with the same
parameters return cached results instantly:

``` r
# First call - hits API
result1 <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a")

# Second call - uses cache (instant)
result2 <- lookup_artist_by_id("561d854a-6a28-4aa7-8c99-323e6ce46c2a")
```

To clear cache: `clear_cache()`

## References

1.  Details of the MusicBrainz database API:
    <https://musicbrainz.org/doc/Development/XML_Web_Service/Version_2>
2.  Details about rate limits:
    <https://musicbrainz.org/doc/XML_Web_Service/Rate_Limiting>
