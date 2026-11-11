# Get Free Appointment Times for One Appointment Type

Get Free Appointment Times for One Appointment Type

## Usage

``` r
get_times(
  event_type_id,
  event_category_id,
  insurance = "gesetzlich",
  from = today_berlin(),
  to = as.Date(from) + 365,
  config = api_potsdam_config()
)
```

## Arguments

- event_type_id:

  samedi id of the appointment type (column `id` of
  [`get_event_types()`](https://mrustl.github.io/api-potsdam/reference/get_event_types.md))

- event_category_id:

  samedi id of the category (see
  [`get_practice_ids()`](https://mrustl.github.io/api-potsdam/reference/get_practice_ids.md))

- insurance:

  health insurance, see
  [`insurances()`](https://mrustl.github.io/api-potsdam/reference/insurances.md)
  (default: "gesetzlich")

- from:

  first day to look for free appointments (default: today in Potsdam,
  i.e. time zone "Europe/Berlin")

- to:

  last day to look for free appointments (default: one year after
  `from`)

- config:

  settings as returned by
  [`api_potsdam_config()`](https://mrustl.github.io/api-potsdam/reference/api_potsdam_config.md)

## Value

sorted vector of free appointment start times (POSIXct, time zone
"Europe/Berlin"), of length zero if there is no free appointment

## Examples

``` r
if (FALSE) { # \dontrun{
ids <- get_practice_ids()
types <- get_event_types(ids = ids)
get_times(types$id[types$letter == "D"], ids$event_category_id)
} # }
```
