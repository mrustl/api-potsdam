local_pushover_credentials <- function(env = parent.frame()) {
  withr::local_envvar(
    PUSHOVER_USER = "user-key",
    PUSHOVER_APP = "app-token",
    .local_envir = env
  )
}

test_that("check_appointments() does not notify without free appointments", {
  local_pushover_credentials()
  sent <- list()
  local_mocked_bindings(
    get_free_appointments = function(...) empty_appointments(),
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...)
  )

  expect_message(
    result <- check_appointments(send_pushover_notification = TRUE),
    "NO free appointment"
  )
  expect_identical(nrow(result), 0L)
  expect_true("is_new" %in% names(result))
  expect_length(sent, 0L)
})

test_that("check_appointments() notifies about free appointments", {
  local_pushover_credentials()
  sent <- list()
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...)
  )

  expect_message(
    result <- check_appointments(send_pushover_notification = TRUE, sound = "siren"),
    "2 free appointment"
  )

  expect_identical(nrow(result), 2L)
  expect_true(all(result$is_new))
  expect_length(sent, 1L)
  expect_identical(sent[[1L]]$title, "API Potsdam: 2 freie Termine")
  expect_identical(sent[[1L]]$priority, 1L)
  expect_identical(sent[[1L]]$sound, "siren")
  expect_identical(sent[[1L]]$url, booking_url("sauglings-u-kleinkindsprechstunde-unter-3-jahre"))
  expect_match(sent[[1L]]$message, "<b>D. S\u00e4uglings", fixed = TRUE)
  expect_match(sent[[1L]]$message, "- Do, 03.12.2026, 08:55 Uhr", fixed = TRUE)
  expect_match(sent[[1L]]$message, "- Do, 10.12.2026, 08:55 Uhr", fixed = TRUE)
})

test_that("check_appointments() does not notify if not requested", {
  sent <- list()
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...)
  )
  state_file <- withr::local_tempfile()

  result <- check_appointments(state_file = state_file, dbg = FALSE)

  expect_identical(nrow(result), 2L)
  expect_length(sent, 0L)
  expect_false(file.exists(state_file))
})

test_that("check_appointments() notifies only about new appointments", {
  local_pushover_credentials()
  sent <- list()
  free <- fake_appointments(times = "2026-12-03T08:55:00+01:00")
  local_mocked_bindings(
    get_free_appointments = function(...) free,
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...)
  )
  state_file <- file.path(withr::local_tempdir(), "state", "notified.txt")

  check <- function() {
    check_appointments(
      send_pushover_notification = TRUE,
      state_file = state_file,
      dbg = FALSE
    )
  }

  # first appointment: notification
  expect_true(all(check()$is_new))
  expect_length(sent, 1L)
  expect_identical(sent[[1L]]$title, "API Potsdam: 1 freier Termin")
  expect_true(file.exists(state_file))

  # same appointment again: no notification
  expect_false(any(check()$is_new))
  expect_length(sent, 1L)

  # an additional appointment: notification about the new one only
  free <- fake_appointments()
  result <- check()
  expect_identical(result$is_new, c(FALSE, TRUE))
  expect_length(sent, 2L)
  expect_false(grepl("03.12.2026", sent[[2L]]$message, fixed = TRUE))
  expect_match(sent[[2L]]$message, "10.12.2026", fixed = TRUE)

  # appointment booked by someone else, then free again: notification
  free <- fake_appointments(times = "2026-12-10T08:55:00+01:00")
  check()
  expect_length(sent, 2L)
  free <- fake_appointments()
  check()
  expect_length(sent, 3L)
  expect_match(sent[[3L]]$message, "03.12.2026", fixed = TRUE)
})

test_that("check_appointments() keeps the state if sending fails", {
  local_pushover_credentials()
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_pushover = function(...) stop("Pushover is down")
  )
  state_file <- withr::local_tempfile()

  expect_error(
    check_appointments(
      send_pushover_notification = TRUE,
      state_file = state_file,
      dbg = FALSE
    ),
    "Pushover is down"
  )
  expect_false(file.exists(state_file))
})

test_that("check_appointments() fails early without Pushover credentials", {
  withr::local_envvar(PUSHOVER_USER = "", PUSHOVER_APP = "app-token")
  called <- FALSE
  local_mocked_bindings(get_free_appointments = function(...) {
    called <<- TRUE
    empty_appointments()
  })

  expect_error(
    check_appointments(send_pushover_notification = TRUE),
    "PUSHOVER_USER"
  )
  expect_false(called)
})

test_that("format_notification() groups by appointment type and truncates", {
  times <- format(
    as.POSIXct("2026-12-01 09:00", tz = "Europe/Berlin") + (0:13) * 86400,
    "%Y-%m-%dT%H:%M:%S%z"
  )
  d <- fake_appointments(times = times)
  a <- fake_appointments(times = "2026-12-02T10:00:00+01:00")
  a$event_type <- "A"
  a$event_type_name <- "A. Erstgespr\u00e4ch / psychotherapeutische Sprechstunde"
  a$event_type_id <- 489167L
  a$booking_url <- booking_url("erstgesprach")

  notification <- format_notification(rbind(d, a))

  expect_identical(notification$title, "API Potsdam: 15 freie Termine")
  expect_match(notification$message, "... und 4 weitere", fixed = TRUE)
  expect_match(notification$message, "<b>A. Erstgespr\u00e4ch", fixed = TRUE)
  expect_identical(notification$url, booking_url())
  expect_lte(nchar(notification$message), 1024L)

  # long messages are truncated to the Pushover limit
  many <- fake_appointments(times = times)
  many$event_type_name <- strrep("x", 2000L)
  long <- format_notification(many)
  expect_lte(nchar(long$message), 1024L)
  expect_false(grepl("<b>", long$message, fixed = TRUE))
})

test_that("send_test_notification() sends a message", {
  local_pushover_credentials()
  sent <- list()
  local_mocked_bindings(
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...)
  )

  expect_true(send_test_notification())
  expect_length(sent, 1L)
  expect_identical(sent[[1L]]$title, "API Potsdam: Testnachricht")
  expect_identical(sent[[1L]]$priority, 0L)
  expect_identical(sent[[1L]]$url, booking_url())
})

test_that("send_test_notification() needs credentials", {
  withr::local_envvar(PUSHOVER_USER = "user-key", PUSHOVER_APP = "")
  expect_error(send_test_notification(), "PUSHOVER_APP")
})

test_that("check_priority() accepts -2 to 2, also as string", {
  expect_identical(check_priority(2), 2L)
  expect_identical(check_priority("2"), 2L)
  expect_identical(check_priority(-2L), -2L)
  expect_error(check_priority(3), "must be one of")
  expect_error(check_priority(1.5), "must be one of")
  expect_error(check_priority("high"), "must be one of")
  expect_error(check_priority(""), "must be one of")
  expect_error(check_priority(NA), "must be one of")
  expect_error(check_priority(NULL), "must be one of")
  expect_error(check_priority(c(1, 2)), "must be one of")
})

test_that("check_appointments() passes priority 2 and retry/expire on", {
  local_pushover_credentials()
  sent <- list()
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...)
  )

  check_appointments(
    send_pushover_notification = TRUE,
    priority = "2",
    retry = 120,
    dbg = FALSE
  )

  expect_identical(sent[[1L]]$priority, 2L)
  expect_identical(sent[[1L]]$retry, 120)

  expect_error(
    check_appointments(send_pushover_notification = TRUE, priority = 5, dbg = FALSE),
    "must be one of"
  )
  expect_length(sent, 1L)
})

test_that("check_appointments() passes its settings to get_free_appointments()", {
  args <- NULL
  local_mocked_bindings(get_free_appointments = function(...) {
    args <<- list(...)
    empty_appointments()
  })

  check_appointments(
    event_type = c("A", "D"),
    insurance = "privat",
    from = as.Date("2026-11-11"),
    to = as.Date("2026-12-31"),
    dbg = FALSE
  )

  expect_identical(args$event_type, c("A", "D"))
  expect_identical(args$insurance, "privat")
  expect_identical(args$from, as.Date("2026-11-11"))
  expect_identical(args$to, as.Date("2026-12-31"))
})

test_that("send_pushover() protects braces from glue in pushoverr", {
  sent <- NULL
  local_mocked_bindings(
    pushover = function(message, title = NULL, ...) {
      sent <<- list(message = message, title = title, ...)
    },
    .package = "pushoverr"
  )

  send_pushover(message = "D. Test {Sys.getenv('PUSHOVER_APP')}", title = "{1 + 1}", priority = 1L)

  expect_identical(sent$message, "D. Test {{Sys.getenv('PUSHOVER_APP')}}")
  expect_identical(sent$title, "{{1 + 1}}")
  expect_identical(sent$priority, 1L)
  # glue (used inside pushoverr::pushover()) restores the original text
  expect_identical(
    as.character(glue::glue(sent$message)),
    "D. Test {Sys.getenv('PUSHOVER_APP')}"
  )

  send_pushover(message = "no title")
  expect_null(sent$title)
})

test_that("format_notification() mentions every type even if many are free", {
  times <- format(
    as.POSIXct("2026-12-01 09:00", tz = "Europe/Berlin") + (0:11) * 86400,
    "%Y-%m-%dT%H:%M:%S%z"
  )
  many <- do.call(rbind, lapply(LETTERS[1:5], function(letter) {
    x <- fake_appointments(times = times)
    x$event_type <- letter
    x$event_type_name <- paste0(letter, ". ", strrep("Lange Bezeichnung der Terminart ", 3L))
    x$booking_url <- booking_url(tolower(letter))
    x
  }))

  notification <- format_notification(many)

  expect_identical(notification$title, "API Potsdam: 60 freie Termine")
  expect_lte(nchar(notification$message), 1024L)
  for (letter in LETTERS[1:5]) {
    expect_match(notification$message, paste0("<b>", letter, ". "), fixed = TRUE)
  }
  expect_match(notification$message, "12 Termine|weitere")
})

test_that("check_appointments() sends e-mails", {
  withr::local_envvar(
    SMTP_SERVER = "smtp.example.com", SMTP_USER = "me@example.com",
    SMTP_PASSWORD = "secret", EMAIL_TO = "me@example.com", EMAIL_FROM = ""
  )
  emails <- list()
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_email = function(subject, body, ...) {
      emails[[length(emails) + 1L]] <<- list(subject = subject, body = body)
    }
  )
  state_file <- withr::local_tempfile()

  result <- check_appointments(
    send_email_notification = TRUE,
    state_file = state_file,
    dbg = FALSE
  )

  expect_length(emails, 1L)
  expect_identical(emails[[1L]]$subject, "API Potsdam: 2 freie Termine")
  expect_identical(attr(result, "failed_channels"), character(0L))
  expect_true(file.exists(state_file))

  # no second e-mail about the same appointments
  check_appointments(send_email_notification = TRUE, state_file = state_file, dbg = FALSE)
  expect_length(emails, 1L)
})

test_that("check_appointments() keeps going if one of two channels fails", {
  local_pushover_credentials()
  withr::local_envvar(SMTP_SERVER = "smtp.example.com", SMTP_USER = "me@example.com", EMAIL_TO = "me@example.com")
  sent <- list()
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...),
    send_email = function(...) stop("535 Authentication failed")
  )
  state_file <- withr::local_tempfile()

  expect_warning(
    result <- check_appointments(
      send_pushover_notification = TRUE,
      send_email_notification = TRUE,
      state_file = state_file,
      dbg = FALSE
    ),
    "E-Mail: 535 Authentication failed"
  )

  expect_length(sent, 1L)
  expect_identical(attr(result, "failed_channels"), "E-Mail")
  # the appointments count as notified: no Pushover message again next time
  expect_true(file.exists(state_file))
  expect_length(read_state(state_file), 2L)
})

test_that("check_appointments() keeps the state if all channels fail", {
  local_pushover_credentials()
  withr::local_envvar(SMTP_SERVER = "smtp.example.com", SMTP_USER = "me@example.com", EMAIL_TO = "me@example.com")
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_pushover = function(...) stop("Pushover is down"),
    send_email = function(...) stop("SMTP is down")
  )
  state_file <- withr::local_tempfile()

  expect_error(
    check_appointments(
      send_pushover_notification = TRUE,
      send_email_notification = TRUE,
      state_file = state_file,
      dbg = FALSE
    ),
    "Pushover: Pushover is down; E-Mail: SMTP is down"
  )
  expect_false(file.exists(state_file))
})

test_that("check_appointments() fails early without e-mail settings", {
  withr::local_envvar(SMTP_SERVER = "", EMAIL_TO = "me@example.com")
  called <- FALSE
  local_mocked_bindings(get_free_appointments = function(...) {
    called <<- TRUE
    empty_appointments()
  })

  expect_error(check_appointments(send_email_notification = TRUE), "SMTP_SERVER")
  expect_false(called)
})

test_that("a channel that is not set up completely does not block the other one", {
  local_pushover_credentials()
  withr::local_envvar(SMTP_SERVER = "smtp.example.com", SMTP_USER = "me@example.com", EMAIL_TO = "")
  sent <- list()
  local_mocked_bindings(
    get_free_appointments = function(...) fake_appointments(),
    send_pushover = function(...) sent[[length(sent) + 1L]] <<- list(...),
    send_email = function(...) stop("must not be called")
  )
  state_file <- withr::local_tempfile()

  expect_warning(
    result <- check_appointments(
      send_pushover_notification = TRUE,
      send_email_notification = TRUE,
      state_file = state_file,
      dbg = FALSE
    ),
    "E-Mail: E-mail settings missing.*EMAIL_TO"
  )

  expect_length(sent, 1L)
  expect_identical(attr(result, "failed_channels"), "E-Mail")
  expect_length(read_state(state_file), 2L)
})

test_that("an incomplete channel is reported even without new appointments", {
  local_pushover_credentials()
  withr::local_envvar(SMTP_SERVER = "smtp.example.com", SMTP_USER = "me@example.com", EMAIL_TO = "")
  local_mocked_bindings(
    get_free_appointments = function(...) empty_appointments(),
    send_pushover = function(...) stop("must not be called")
  )

  expect_warning(
    result <- check_appointments(
      send_pushover_notification = TRUE,
      send_email_notification = TRUE,
      dbg = FALSE
    ),
    "not set up completely: E-Mail"
  )
  expect_identical(attr(result, "failed_channels"), "E-Mail")
})

test_that("check_appointments() stops early if no enabled channel is set up", {
  withr::local_envvar(PUSHOVER_USER = "", PUSHOVER_APP = "", SMTP_SERVER = "", EMAIL_TO = "")
  called <- FALSE
  local_mocked_bindings(get_free_appointments = function(...) {
    called <<- TRUE
    empty_appointments()
  })

  expect_error(
    check_appointments(send_pushover_notification = TRUE, send_email_notification = TRUE),
    "Pushover credentials missing.*E-mail settings missing"
  )
  expect_false(called)
})

test_that("check_appointments() without notification has no failed channels", {
  local_mocked_bindings(get_free_appointments = function(...) fake_appointments())
  result <- check_appointments(dbg = FALSE)
  expect_identical(attr(result, "failed_channels"), character(0L))
})
