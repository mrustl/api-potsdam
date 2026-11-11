# Read the Public Configuration of the samedi Booking Page

The samedi booking page (<https://termin.samedi.de>) embeds the public
client id and API key it uses for its requests to the samedi booking
API.
[`check_appointments()`](https://mrustl.github.io/api-potsdam/reference/check_appointments.md)
uses these credentials. They are read from the booking page
automatically if a request is rejected with the built-in default
credentials (HTTP 401/403), e.g. because samedi changed them.

## Usage

``` r
samedi_widget_config(url = api_potsdam_config()$booking_base_url)
```

## Arguments

- url:

  URL of the booking page (default: "https://termin.samedi.de")

## Value

named list with elements `api_url`, `client_id`, `api_key` (`NA` if not
found)

## Details

A client id can also be set explicitly with
`options(api.potsdam.samedi_client_id = "...")` or the environment
variable `SAMEDI_CLIENT_ID`.

## Examples

``` r
if (FALSE) { # \dontrun{
samedi_widget_config()
} # }
```
