# Default Settings for the API Potsdam Booking Page

The settings are taken from the public online booking page of the
outpatient clinic of the "Akademie fuer Psychotherapie und
Interventionsforschung" (API) in Potsdam, which is provided by samedi:
<https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api>

## Usage

``` r
api_potsdam_config()
```

## Value

named list with elements

- `practice_slug`: practice identifier in the booking page URL

- `widget`: booking widget number in the booking page URL

- `category_slug`: "Behandler/Kategorie" identifier in the booking page
  URL ("API, Potsdam")

- `booking_base_url`: base URL of the booking page

- `api_url`: base URL of the samedi booking API used by the booking page

## Examples

``` r
api_potsdam_config()
#> $practice_slug
#> [1] "akademie-fur-psychotherapie-und-interventionsforschung-gmbh"
#> 
#> $widget
#> [1] "1"
#> 
#> $category_slug
#> [1] "api"
#> 
#> $booking_base_url
#> [1] "https://termin.samedi.de"
#> 
#> $api_url
#> [1] "https://patient.samedi.de/api/booking/v3"
#> 
```
