# Send an E-Mail via SMTP

Sends a plain text e-mail (UTF-8) with
[`curl::send_mail()`](https://jeroen.r-universe.dev/curl/reference/send_mail.html).
The SMTP settings are read from environment variables by default:

## Usage

``` r
send_email(
  subject,
  body,
  to = Sys.getenv("EMAIL_TO"),
  from = Sys.getenv("EMAIL_FROM"),
  server = Sys.getenv("SMTP_SERVER"),
  port = Sys.getenv("SMTP_PORT", "465"),
  user = Sys.getenv("SMTP_USER"),
  password = Sys.getenv("SMTP_PASSWORD")
)
```

## Arguments

- subject:

  subject of the e-mail

- body:

  text of the e-mail

- to:

  recipient(s), character vector or comma separated string

- from:

  sender, optionally with a display name ("Name

  "). If empty, `user` is used.

- server, port, user, password:

  SMTP settings

## Value

`TRUE` (invisibly) if the e-mail was sent

## Details

- `SMTP_SERVER`: host name of the SMTP server, e.g. "smtp.ionos.de" (or
  a URL like "smtps://smtp.ionos.de:465")

- `SMTP_PORT`: port (default: 465, SSL/TLS). With 587 or 25 the
  connection is upgraded with STARTTLS, which is required.

- `SMTP_USER`, `SMTP_PASSWORD`: login (e.g. the full e-mail address and
  the password of the mailbox)

- `EMAIL_FROM`: sender (default: `SMTP_USER`), e.g. "API Potsdam
  <me@example.com>"

- `EMAIL_TO`: recipient(s), several separated by commas

## Examples

``` r
if (FALSE) { # \dontrun{
Sys.setenv(
  SMTP_SERVER = "smtp.ionos.de",
  SMTP_USER = "me@example.com",
  SMTP_PASSWORD = "<password>",
  EMAIL_TO = "me@example.com"
)
send_email("Test", "Hallo!")
} # }
```
