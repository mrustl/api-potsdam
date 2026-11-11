# Check for Free Appointments and Send a Pushover Notification

Checks the booking calendar of the API Potsdam for free appointments
(see
[`get_free_appointments()`](https://mrustl.github.io/api-potsdam/reference/get_free_appointments.md))
and sends a notification with the [Pushover](https://pushover.net) app
if there are any.

## Usage

``` r
check_appointments(
  event_type = "D",
  insurance = "gesetzlich",
  send_pushover_notification = FALSE,
  state_file = NULL,
  priority = 1L,
  from = today_berlin(),
  to = as.Date(from) + 365,
  config = api_potsdam_config(),
  dbg = TRUE,
  ...
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

- send_pushover_notification:

  should a Pushover notification be sent if there are (new) free
  appointments? Default: `FALSE`

- state_file:

  optional path to a text file in which the appointments that a
  notification was already sent for are stored. If given, a notification
  is only sent for appointments that are not yet contained in the file,
  i.e. you are not notified again and again about the same appointments.
  If `send_pushover_notification` is `TRUE`, the file is overwritten
  with the currently free appointments after the notification was sent
  (or if there was nothing new to send). An appointment that disappears
  and becomes free again is therefore reported again. Default: `NULL`
  (notify about all free appointments on each call)

- priority:

  Pushover message priority from -2 (lowest) to 2. Default: 1 (high
  priority, bypasses the quiet hours of the Pushover app). With 2
  (emergency) the notification is repeated every `retry` seconds
  (default: 60) until it is acknowledged in the Pushover app, for at
  most `expire` seconds (default: 3600); `retry` and `expire` can be
  passed via `...`.

- from:

  first day to look for free appointments (default: today in Potsdam,
  i.e. time zone "Europe/Berlin")

- to:

  last day to look for free appointments (default: one year after
  `from`)

- config:

  settings as returned by
  [`api_potsdam_config()`](https://mrustl.github.io/api-potsdam/reference/api_potsdam_config.md)

- dbg:

  print debug messages? Default: `TRUE`

- ...:

  further arguments passed to
  [`pushoverr::pushover()`](https://briandconnelly.github.io/pushoverr/reference/pushover.html),
  e.g. `sound` or `device`

## Value

data frame of free appointments as returned by
[`get_free_appointments()`](https://mrustl.github.io/api-potsdam/reference/get_free_appointments.md)
with an additional logical column `is_new` (`TRUE` if the appointment
was not yet contained in `state_file`)

## Details

The Pushover credentials are read from the environment variables
`PUSHOVER_USER` (your user key) and `PUSHOVER_APP` (the API token of
your Pushover application), see
[`pushoverr::pushover()`](https://briandconnelly.github.io/pushoverr/reference/pushover.html).

## Examples

``` r
if (FALSE) { # \dontrun{
# Only print the free appointments
check_appointments()

# Send a Pushover notification about new free appointments of type
# "D. Saeuglings- u. Kleinkindsprechstunde" for patients with statutory
# health insurance
Sys.setenv(PUSHOVER_USER = "<user key>", PUSHOVER_APP = "<api token>")
check_appointments(
  event_type = "D",
  insurance = "gesetzlich",
  send_pushover_notification = TRUE,
  state_file = "notified-appointments.txt"
)
} # }
```
