# Changelog

## api.potsdam 0.0.0.9000

- Check the samedi booking calendar of the API Potsdam for free
  appointments
  ([`get_free_appointments()`](https://mrustl.github.io/api-potsdam/reference/get_free_appointments.md),
  [`get_event_types()`](https://mrustl.github.io/api-potsdam/reference/get_event_types.md),
  [`get_times()`](https://mrustl.github.io/api-potsdam/reference/get_times.md)).
- Send Pushover notifications about new free appointments
  ([`check_appointments()`](https://mrustl.github.io/api-potsdam/reference/check_appointments.md),
  [`send_test_notification()`](https://mrustl.github.io/api-potsdam/reference/send_test_notification.md)).
- GitHub Actions workflow `check-appointments` checking every 6 minutes.
  Default: appointment type “D” (statutory health insurance),
  configurable with repository secrets. Public logs only show the number
  of free appointments.
- Pushover priority configurable with the repository variable
  `API_POTSDAM_PRIORITY` (2 = emergency, repeated until acknowledged).
- E-mail notifications via SMTP
  ([`send_email()`](https://mrustl.github.io/api-potsdam/reference/send_email.md),
  [`send_test_email()`](https://mrustl.github.io/api-potsdam/reference/send_test_email.md),
  `check_appointments(send_email_notification = TRUE)`), e.g. with
  IONOS. If one of several channels fails, the others still notify
  (once).
