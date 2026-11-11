# Get Online Bookable Appointment Types ("Terminarten")

Get Online Bookable Appointment Types ("Terminarten")

## Usage

``` r
get_event_types(
  insurance = "gesetzlich",
  config = api_potsdam_config(),
  ids = get_practice_ids(config)
)
```

## Arguments

- insurance:

  health insurance, see
  [`insurances()`](https://mrustl.github.io/api-potsdam/reference/insurances.md)
  (default: "gesetzlich")

- config:

  settings as returned by
  [`api_potsdam_config()`](https://mrustl.github.io/api-potsdam/reference/api_potsdam_config.md)

- ids:

  practice and category ids as returned by
  [`get_practice_ids()`](https://mrustl.github.io/api-potsdam/reference/get_practice_ids.md)

## Value

data frame with one row per appointment type and columns `id` (samedi
id), `letter` (letter shown on the booking page, e.g. "D"), `name`,
`slug` and `description`

## Examples

``` r
if (FALSE) { # \dontrun{
get_event_types()
} # }
```
