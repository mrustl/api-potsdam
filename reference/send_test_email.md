# Send a Test E-Mail

Sends a test e-mail to check the SMTP settings (see
[`send_email()`](https://mrustl.github.io/api-potsdam/reference/send_email.md)).

## Usage

``` r
send_test_email()
```

## Value

`TRUE` (invisibly) if the e-mail was sent

## Examples

``` r
if (FALSE) { # \dontrun{
Sys.setenv(
  SMTP_SERVER = "smtp.ionos.de",
  SMTP_USER = "me@example.com",
  SMTP_PASSWORD = "<password>",
  EMAIL_TO = "me@example.com"
)
send_test_email()
} # }
```
