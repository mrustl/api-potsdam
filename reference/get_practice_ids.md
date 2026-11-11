# Get Practice and Category Ids

Translates the practice and category identifiers of the booking page URL
(see
[`api_potsdam_config()`](https://mrustl.github.io/api-potsdam/reference/api_potsdam_config.md))
into the ids used by the samedi booking API.

## Usage

``` r
get_practice_ids(config = api_potsdam_config())
```

## Arguments

- config:

  settings as returned by
  [`api_potsdam_config()`](https://mrustl.github.io/api-potsdam/reference/api_potsdam_config.md)

## Value

named list with elements `practice_id` (character) and
`event_category_id` (integer)

## Examples

``` r
if (FALSE) { # \dontrun{
get_practice_ids()
} # }
```
