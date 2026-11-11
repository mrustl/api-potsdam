# Get Free Appointments at the API Potsdam

Asks the samedi booking API (the same requests that the public booking
page <https://termin.samedi.de> sends, read-only) for free appointments
of the given appointment type(s) at the outpatient clinic of the API
Potsdam.

## Usage

``` r
get_free_appointments(
  event_type = "D",
  insurance = "gesetzlich",
  from = today_berlin(),
  to = as.Date(from) + 365,
  config = api_potsdam_config()
)
```

## Arguments

- event_type:

  appointment type(s) ("Terminart") to check. Either the letter shown on
  the booking page (e.g. "D" for "D. Saeuglings- u.
  Kleinkindsprechstunde"), the samedi id, the slug or a (unique) part of
  the name, see
  [`get_event_types()`](https://mrustl.github.io/api-potsdam/reference/get_event_types.md).
  Several appointment types can be given as a vector. Default: "D"

- insurance:

  health insurance ("Krankenversicherung"), see
  [`insurances()`](https://mrustl.github.io/api-potsdam/reference/insurances.md).
  Default: "gesetzlich"

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

data frame with one row per free appointment and columns `event_type`
(letter), `event_type_name`, `event_type_id`, `insurance`, `time`
(POSIXct, time zone "Europe/Berlin") and `booking_url`. The data frame
has zero rows if there is no free appointment.

## Examples

``` r
if (FALSE) { # \dontrun{
# D. Saeuglings- u. Kleinkindsprechstunde, gesetzlich versichert
get_free_appointments()

# Several appointment types at once
get_free_appointments(event_type = c("A", "D"))
} # }
```
