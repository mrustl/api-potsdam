# Booking Page URL

Booking Page URL

## Usage

``` r
booking_url(
  event_type_slug = NULL,
  insurance = "gesetzlich",
  config = api_potsdam_config()
)
```

## Arguments

- event_type_slug:

  slug of the appointment type (column `slug` of
  [`get_event_types()`](https://mrustl.github.io/api-potsdam/reference/get_event_types.md)).
  If `NULL` (default), the URL of the category page (all appointment
  types) is returned.

- insurance:

  health insurance, see
  [`insurances()`](https://mrustl.github.io/api-potsdam/reference/insurances.md)
  (default: "gesetzlich")

- config:

  settings as returned by
  [`api_potsdam_config()`](https://mrustl.github.io/api-potsdam/reference/api_potsdam_config.md)

## Value

URL of the booking page (character)

## Examples

``` r
booking_url()
#> [1] "https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api?insuranceId=public"
booking_url("sauglings-u-kleinkindsprechstunde-unter-3-jahre")
#> [1] "https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api/sauglings-u-kleinkindsprechstunde-unter-3-jahre?insuranceId=public"
```
