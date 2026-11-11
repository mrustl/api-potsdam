#' Check for Free Appointments and Send Notifications
#'
#' Checks the booking calendar of the API Potsdam for free appointments (see
#' [get_free_appointments()]) and sends a notification with the
#' [Pushover](https://pushover.net) app and/or by e-mail if there are any.
#'
#' The Pushover credentials are read from the environment variables
#' `PUSHOVER_USER` (your user key) and `PUSHOVER_APP` (the API token of your
#' Pushover application), see [pushoverr::pushover()]. The e-mail settings
#' are read from the environment variables `SMTP_SERVER`, `SMTP_PORT`,
#' `SMTP_USER`, `SMTP_PASSWORD`, `EMAIL_FROM` and `EMAIL_TO`, see
#' [send_email()].
#'
#' If both channels are used and only one of them fails (or is not set up
#' completely, e.g. `EMAIL_TO` is missing), the appointments are still
#' regarded as notified (no repeated messages on the working channel), a
#' warning is given and the names of the failed channels are returned in the
#' attribute `failed_channels`. If all channels fail, an error is raised and
#' `state_file` is not changed, so that the notification is tried again.
#'
#' @inheritParams get_free_appointments
#' @param send_pushover_notification should a Pushover notification be sent if
#'   there are (new) free appointments? Default: `FALSE`
#' @param send_email_notification should an e-mail be sent if there are (new)
#'   free appointments? Default: `FALSE`
#' @param state_file optional path to a text file in which the appointments
#'   that a notification was already sent for are stored. If given, a
#'   notification is only sent for appointments that are not yet contained in
#'   the file, i.e. you are not notified again and again about the same
#'   appointments. If a notification channel is enabled, the file is
#'   overwritten with the currently free appointments after the notification
#'   was sent (or if there was nothing new to send). An appointment that
#'   disappears and becomes free again is therefore reported again.
#'   Default: `NULL` (notify about all free appointments on each call)
#' @param priority Pushover message priority from -2 (lowest) to 2. Default:
#'   1 (high priority, bypasses the quiet hours of the Pushover app). With 2
#'   (emergency) the notification is repeated every `retry` seconds (default:
#'   60) until it is acknowledged in the Pushover app, for at most `expire`
#'   seconds (default: 3600); `retry` and `expire` can be passed via `...`.
#' @param dbg print debug messages? Default: `TRUE`
#' @param ... further arguments passed to [pushoverr::pushover()], e.g.
#'   `sound` or `device`
#' @return data frame of free appointments as returned by
#'   [get_free_appointments()] with an additional logical column `is_new`
#'   (`TRUE` if the appointment was not yet contained in `state_file`) and
#'   the attribute `failed_channels` (see Details)
#' @export
#' @examples
#' \dontrun{
#' # Only print the free appointments
#' check_appointments()
#'
#' # Send a Pushover notification about new free appointments of type
#' # "D. Saeuglings- u. Kleinkindsprechstunde" for patients with statutory
#' # health insurance
#' Sys.setenv(PUSHOVER_USER = "<user key>", PUSHOVER_APP = "<api token>")
#' check_appointments(
#'   event_type = "D",
#'   insurance = "gesetzlich",
#'   send_pushover_notification = TRUE,
#'   state_file = "notified-appointments.txt"
#' )
#'
#' # Additionally by e-mail (e.g. IONOS)
#' Sys.setenv(
#'   SMTP_SERVER = "smtp.ionos.de",
#'   SMTP_USER = "me@example.com",
#'   SMTP_PASSWORD = "<password>",
#'   EMAIL_TO = "me@example.com"
#' )
#' check_appointments(
#'   send_pushover_notification = TRUE,
#'   send_email_notification = TRUE,
#'   state_file = "notified-appointments.txt"
#' )
#' }
check_appointments <- function(
  event_type = "D",
  insurance = "gesetzlich",
  send_pushover_notification = FALSE,
  send_email_notification = FALSE,
  state_file = NULL,
  priority = 1L,
  from = today_berlin(),
  to = as.Date(from) + 365,
  config = api_potsdam_config(),
  dbg = TRUE,
  ...
)
{
  priority <- check_priority(priority)

  # Settings of each enabled channel. Stop only if no enabled channel is set
  # up, so that a channel that is not (yet) completely set up does not keep
  # the other one from notifying.
  config_errors <- list()

  if (send_pushover_notification) {
    config_errors$Pushover <- error_message(check_pushover_credentials())
  }

  if (send_email_notification) {
    config_errors$`E-Mail` <- error_message(check_email_settings())
  }

  config_errors <- config_errors[!vapply(config_errors, is.null, logical(1L))]
  n_enabled <- sum(send_pushover_notification, send_email_notification)

  if (n_enabled > 0L && length(config_errors) == n_enabled) {
    stop(paste(unlist(config_errors), collapse = " "), call. = FALSE)
  }

  appointments <- get_free_appointments(
    event_type = event_type,
    insurance = insurance,
    from = from,
    to = to,
    config = config
  )

  keys <- appointment_keys(appointments)
  appointments$is_new <- !keys %in% read_state(state_file)

  if (dbg) {
    message(describe_appointments(appointments, event_type))
  }

  new_appointments <- appointments[appointments$is_new, , drop = FALSE]

  failed_channels <- character(0L)

  if (send_pushover_notification || send_email_notification) {
    if (nrow(new_appointments) > 0L) {
      channels <- list()

      if (send_pushover_notification) {
        channels$Pushover <- function() {
          notification <- format_notification(new_appointments)
          send_pushover(
            message = notification$message,
            title = notification$title,
            priority = priority,
            url = notification$url,
            url_title = notification$url_title,
            ...
          )
        }
      }

      if (send_email_notification) {
        channels$`E-Mail` <- function() {
          email <- format_email(new_appointments)
          send_email(subject = email$subject, body = email$body)
        }
      }

      # A channel that is not set up completely fails with its settings error
      for (name in names(config_errors)) {
        channels[[name]] <- local({
          error <- config_errors[[name]]
          function() stop(error, call. = FALSE)
        })
      }

      failed_channels <- send_notifications(channels, dbg = dbg)
    } else if (length(config_errors) > 0L) {
      warning(
        "Notification channel not set up completely: ",
        paste(sprintf("%s: %s", names(config_errors), unlist(config_errors)), collapse = "; "),
        call. = FALSE
      )
      failed_channels <- names(config_errors)
    }

    if (!is.null(state_file)) {
      write_state(state_file, keys)
    }
  }

  attr(appointments, "failed_channels") <- failed_channels
  appointments
}

# Message of the error raised by an expression, NULL if there is none ---------
error_message <- function(expr) {
  tryCatch(
    {
      expr
      NULL
    },
    error = function(e) conditionMessage(e)
  )
}

# Send a notification on every channel, independently of each other -------------
# Returns the names of the channels that failed. Stops if all of them failed.
send_notifications <- function(channels, dbg = TRUE) {
  errors <- list()

  for (name in names(channels)) {
    if (dbg) {
      message("Sending notification: ", name)
    }

    error <- tryCatch(
      {
        channels[[name]]()
        NULL
      },
      error = function(e) conditionMessage(e)
    )

    if (!is.null(error)) {
      errors[[name]] <- error
    }
  }

  details <- paste(sprintf("%s: %s", names(errors), unlist(errors)), collapse = "; ")

  if (length(errors) > 0L && length(errors) == length(channels)) {
    stop("Sending the notification failed (", details, ")", call. = FALSE)
  }

  if (length(errors) > 0L) {
    warning(
      "Sending the notification failed for ", details,
      ". It was sent on the other channel(s).",
      call. = FALSE
    )
  }

  as.character(names(errors))
}

#' Send a Pushover Test Notification
#'
#' Sends a test message to check that the Pushover credentials (environment
#' variables `PUSHOVER_USER` and `PUSHOVER_APP`) work.
#'
#' @param priority Pushover message priority from -2 to 2 (default: 0)
#' @param ... further arguments passed to [pushoverr::pushover()]
#' @return `TRUE` (invisibly) if the message was sent
#' @export
#' @examples
#' \dontrun{
#' Sys.setenv(PUSHOVER_USER = "<user key>", PUSHOVER_APP = "<api token>")
#' send_test_notification()
#' }
send_test_notification <- function(priority = 0L, ...) {
  priority <- check_priority(priority)
  check_pushover_credentials()

  send_pushover(
    message = paste(
      "Test: Pushover-Benachrichtigungen \u00fcber freie Termine bei der",
      "API Potsdam sind eingerichtet."
    ),
    title = "API Potsdam: Testnachricht",
    priority = priority,
    url = booking_url(),
    url_title = "Zur Buchungsseite",
    ...
  )

  invisible(TRUE)
}

#' Send a Test E-Mail
#'
#' Sends a test e-mail to check the SMTP settings (see [send_email()]).
#'
#' @return `TRUE` (invisibly) if the e-mail was sent
#' @export
#' @examples
#' \dontrun{
#' Sys.setenv(
#'   SMTP_SERVER = "smtp.ionos.de",
#'   SMTP_USER = "me@example.com",
#'   SMTP_PASSWORD = "<password>",
#'   EMAIL_TO = "me@example.com"
#' )
#' send_test_email()
#' }
send_test_email <- function() {
  check_email_settings()

  send_email(
    subject = "API Potsdam: Test-E-Mail",
    body = paste0(
      "Test: E-Mail-Benachrichtigungen \u00fcber freie Termine bei der ",
      "API Potsdam sind eingerichtet.\n\nBuchungsseite:\n",
      booking_url()
    )
  )

  invisible(TRUE)
}

# Validate a Pushover priority (also given as string, e.g. from an env var) -----
check_priority <- function(priority) {
  value <- suppressWarnings(as.integer(priority))

  if (
    length(priority) != 1L ||
      is.na(value) ||
      !value %in% -2:2 ||
      value != suppressWarnings(as.numeric(priority))
  ) {
    stop(
      "'priority' must be one of -2, -1, 0, 1, 2 (got '",
      paste(priority, collapse = ", "),
      "').",
      call. = FALSE
    )
  }

  value
}

# Stop if the Pushover credentials are not set ---------------------------------
check_pushover_credentials <- function() {
  missing <- c("PUSHOVER_USER", "PUSHOVER_APP")[
    !nzchar(Sys.getenv(c("PUSHOVER_USER", "PUSHOVER_APP")))
  ]

  if (length(missing) > 0L) {
    stop(
      "Pushover credentials missing. Please set the environment variable(s) ",
      paste(missing, collapse = " and "),
      " (Pushover user key and API token of your Pushover application).",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

# Send a Pushover message ------------------------------------------------------
# pushoverr::pushover() passes message and title through glue::glue(), which
# would evaluate "{...}" (e.g. in appointment type names set by the clinic) as
# R code. Doubled braces are turned back into single braces by glue.
send_pushover <- function(message, title = NULL, ...) {
  escape_glue <- function(x) if (is.null(x)) x else gsub("([{}])", "\\1\\1", x)
  pushoverr::pushover(message = escape_glue(message), title = escape_glue(title), ...)
}

# Unique identifiers of appointments (stored in the state file) ----------------
appointment_keys <- function(appointments) {
  if (nrow(appointments) == 0L) {
    return(character(0L))
  }

  paste(
    appointments$event_type_id,
    format(appointments$time, "%Y-%m-%dT%H:%M:%S%z", tz = "UTC"),
    sep = "|"
  )
}

# Read/write the keys of already notified appointments --------------------------
read_state <- function(state_file) {
  if (is.null(state_file) || !file.exists(state_file)) {
    return(character(0L))
  }

  keys <- readLines(state_file, warn = FALSE, encoding = "UTF-8")
  keys[nzchar(keys)]
}

write_state <- function(state_file, keys) {
  dir.create(dirname(state_file), recursive = TRUE, showWarnings = FALSE)
  writeLines(keys, state_file, useBytes = TRUE)
  invisible(state_file)
}

# Console message about the result of a check -----------------------------------
describe_appointments <- function(appointments, event_type) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "Europe/Berlin")

  if (nrow(appointments) == 0L) {
    return(
      sprintf(
        "API Potsdam (%s): currently there is NO free appointment (%s)",
        paste(event_type, collapse = ", "),
        timestamp
      )
    )
  }

  sprintf(
    "API Potsdam: currently there %s %d free appointment(s), %d of them new (%s):\n%s",
    if (nrow(appointments) == 1L) "is" else "are",
    nrow(appointments),
    sum(appointments$is_new),
    timestamp,
    paste(
      sprintf(
        "* %s: %s%s",
        appointments$event_type_name,
        format_time_de(appointments$time),
        ifelse(appointments$is_new, " (new)", "")
      ),
      collapse = "\n"
    )
  )
}

# Title, text and link of the Pushover notification -----------------------------
format_notification <- function(appointments, max_times = 10L) {
  n <- nrow(appointments)

  title <- sprintf(
    "API Potsdam: %s",
    if (n == 1L) "1 freier Termin" else sprintf("%d freie Termine", n)
  )

  groups <- split(appointments, factor(
    appointments$event_type_name,
    levels = unique(appointments$event_type_name)
  ))

  format_message <- function(max_times) {
    blocks <- vapply(groups, function(group) {
      times <- format_time_de(sort(group$time))
      more <- length(times) - max_times

      if (more > 0L) {
        times <- c(
          times[seq_len(max_times)],
          if (max_times == 0L) {
            sprintf("%d Termin%s", more, if (more == 1L) "" else "e")
          } else {
            sprintf("... und %d weitere", more)
          }
        )
      }

      paste0(
        "<b>", escape_html(group$event_type_name[1L]), "</b> (",
        escape_html(group$insurance[1L]), ")\n",
        paste0("- ", times, collapse = "\n")
      )
    }, character(1L))

    paste(blocks, collapse = "\n\n")
  }

  # Pushover limits messages to 1024 characters: show fewer times per
  # appointment type until the message fits, so that every type is mentioned
  max_times <- max(0L, as.integer(max_times))
  message <- format_message(max_times)

  while (nchar(message) > 1024L && max_times > 0L) {
    max_times <- max_times - 1L
    message <- format_message(max_times)
  }

  # Last resort (very long names): remove the formatting, so that no HTML tag
  # is cut in half, and truncate
  if (nchar(message) > 1024L) {
    message <- gsub("</?b>", "", message)
    message <- paste0(substr(message, 1L, 1000L), "\n...")
  }

  # Link to the appointment type or, for several appointment types, to the
  # category page (booking URL without the appointment type part)
  urls <- unique(appointments$booking_url)
  url <- if (length(urls) == 1L) urls else sub("/[^/?]+(\\?.*)?$", "\\1", urls[1L])

  list(
    title = title,
    message = message,
    url = url,
    url_title = "Jetzt online buchen"
  )
}
