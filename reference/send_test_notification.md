# Send a Pushover Test Notification

Sends a test message to check that the Pushover credentials (environment
variables `PUSHOVER_USER` and `PUSHOVER_APP`) work.

## Usage

``` r
send_test_notification(priority = 0L, ...)
```

## Arguments

- priority:

  Pushover message priority from -2 to 2 (default: 0)

- ...:

  further arguments passed to
  [`pushoverr::pushover()`](https://briandconnelly.github.io/pushoverr/reference/pushover.html)

## Value

`TRUE` (invisibly) if the message was sent

## Examples

``` r
if (FALSE) { # \dontrun{
Sys.setenv(PUSHOVER_USER = "<user key>", PUSHOVER_APP = "<api token>")
send_test_notification()
} # }
```
