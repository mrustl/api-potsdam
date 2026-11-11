# api.potsdam 0.0.0.9000

* Check the samedi booking calendar of the API Potsdam for free appointments
  (`get_free_appointments()`, `get_event_types()`, `get_times()`).
* Send Pushover notifications about new free appointments
  (`check_appointments()`, `send_test_notification()`).
* GitHub Actions workflow `check-appointments` checking every 6 minutes.
  Default: appointment type "D" (statutory health insurance), configurable
  with repository secrets. Public logs only show the number of free
  appointments.
* Pushover priority configurable with the repository variable
  `API_POTSDAM_PRIORITY` (2 = emergency, repeated until acknowledged).
* E-mail notifications via SMTP (`send_email()`, `send_test_email()`,
  `check_appointments(send_email_notification = TRUE)`), e.g. with IONOS.
  If one of several channels fails, the others still notify (once).
