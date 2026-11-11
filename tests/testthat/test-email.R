local_smtp_settings <- function(env = parent.frame()) {
  withr::local_envvar(
    SMTP_SERVER = "smtp.example.com",
    SMTP_PORT = "",
    SMTP_USER = "me@example.com",
    SMTP_PASSWORD = "secret",
    EMAIL_FROM = "",
    EMAIL_TO = "me@example.com",
    .local_envir = env
  )
}

decode_body <- function(message) {
  parts <- strsplit(message, "\r\n\r\n", fixed = TRUE)[[1L]]
  body <- gsub("\r\n", "", parts[2L], fixed = TRUE)
  rawToChar(jsonlite::base64_dec(body))
}

test_that("smtp_url() uses implicit TLS on port 465 and STARTTLS otherwise", {
  expect_identical(
    smtp_url("smtp.ionos.de"),
    list(url = "smtps://smtp.ionos.de:465", use_ssl = "try")
  )
  expect_identical(
    smtp_url("smtp.ionos.de", ""),
    list(url = "smtps://smtp.ionos.de:465", use_ssl = "try")
  )
  expect_identical(
    smtp_url(" smtp.ionos.de ", 587),
    list(url = "smtp://smtp.ionos.de:587", use_ssl = "force")
  )
  expect_identical(
    smtp_url("smtps://mail.example.com:465", "587"),
    list(url = "smtps://mail.example.com:465", use_ssl = "try")
  )
  expect_identical(smtp_url("smtp://mail.example.com:25")$use_ssl, "force")
})

test_that("addresses are split and reduced to the bare address", {
  expect_identical(
    split_addresses("a@x.de, B <b@y.de> ,,"),
    c("a@x.de", "B <b@y.de>")
  )
  expect_identical(split_addresses(c("a@x.de", "b@y.de")), c("a@x.de", "b@y.de"))
  expect_identical(split_addresses(""), character(0L))
  expect_identical(
    email_address(c("a@x.de", "API Potsdam <b@y.de>", " <c@z.de> ")),
    c("a@x.de", "b@y.de", "c@z.de")
  )
})

test_that("headers with umlauts are RFC 2047 encoded", {
  expect_identical(encode_header("API Potsdam: 2 freie Termine"), "API Potsdam: 2 freie Termine")

  encoded <- encode_header("Termine für Kinder")
  expect_match(encoded, "^=\\?UTF-8\\?B\\?.*\\?=$")
  decoded <- rawToChar(jsonlite::base64_dec(sub("^=\\?UTF-8\\?B\\?(.*)\\?=$", "\\1", encoded)))
  Encoding(decoded) <- "UTF-8"
  expect_identical(decoded, "Termine für Kinder")

  expect_identical(encode_address("me@example.com"), "me@example.com")
  expect_identical(encode_address("API Potsdam <me@example.com>"), "API Potsdam <me@example.com>")
  expect_match(encode_address("Jürgen <me@example.com>"), "^=\\?UTF-8\\?B\\?.*\\?= <me@example.com>$")
})

test_that("format_email_date() is RFC 5322 and independent of the locale", {
  time <- as.POSIXct("2026-11-11 06:05:09", tz = "UTC")
  expect_identical(format_email_date(time), "Wed, 11 Nov 2026 06:05:09 +0000")
})

test_that("format_email_message() builds a valid UTF-8 message", {
  body <- paste(rep("D. Säuglings- u. Kleinkindsprechstunde", 5L), collapse = "\n")

  message <- format_email_message(
    from = "API Potsdam <me@example.com>",
    to = c("a@x.de", "b@y.de"),
    subject = "API Potsdam: 2 freie Termine",
    body = body,
    time = as.POSIXct("2026-11-11 06:05:09", tz = "UTC")
  )

  lines <- strsplit(message, "\r\n", fixed = TRUE)[[1L]]
  expect_true("From: API Potsdam <me@example.com>" %in% lines)
  expect_true("To: a@x.de, b@y.de" %in% lines)
  expect_true("Subject: API Potsdam: 2 freie Termine" %in% lines)
  expect_true("Date: Wed, 11 Nov 2026 06:05:09 +0000" %in% lines)
  expect_true("Content-Type: text/plain; charset=UTF-8" %in% lines)
  expect_true("Content-Transfer-Encoding: base64" %in% lines)
  expect_true(all(nchar(lines) <= 76L))

  decoded <- decode_body(message)
  Encoding(decoded) <- "UTF-8"
  expect_identical(decoded, body)

  empty <- format_email_message("me@example.com", "a@x.de", "Leer", "")
  expect_match(empty, "Content-Transfer-Encoding: base64\r\n\r\n$")
})

test_that("send_email() passes the settings to curl without verbose output", {
  local_smtp_settings()
  args <- NULL
  local_mocked_bindings(curl_send_mail = function(...) args <<- list(...))

  expect_true(send_email("Betreff", "Text"))

  expect_identical(args$mail_from, "me@example.com")
  expect_identical(args$mail_rcpt, "me@example.com")
  expect_identical(args$smtp_server, "smtps://smtp.example.com:465")
  expect_identical(args$use_ssl, "try")
  expect_false(args$verbose)
  expect_identical(args$username, "me@example.com")
  expect_identical(args$password, "secret")
  expect_identical(args$timeout, 60L)
  expect_match(args$message, "Subject: Betreff", fixed = TRUE)
})

test_that("send_email() supports several recipients, a sender name and no login", {
  local_smtp_settings()
  withr::local_envvar(
    SMTP_USER = "",
    EMAIL_FROM = "API Potsdam <from@example.com>",
    EMAIL_TO = "a@x.de, B <b@y.de>",
    SMTP_PORT = "587"
  )
  args <- NULL
  local_mocked_bindings(curl_send_mail = function(...) args <<- list(...))

  send_email("Betreff", "Text")

  expect_identical(args$mail_from, "from@example.com")
  expect_identical(args$mail_rcpt, c("a@x.de", "b@y.de"))
  expect_identical(args$smtp_server, "smtp://smtp.example.com:587")
  expect_identical(args$use_ssl, "force")
  expect_null(args$username)
  expect_match(args$message, "From: API Potsdam <from@example.com>", fixed = TRUE)
})

test_that("send_email() and check_email_settings() need server and recipient", {
  local_smtp_settings()
  withr::local_envvar(EMAIL_TO = "")
  expect_error(send_email("a", "b"), "E-mail settings missing")
  expect_error(check_email_settings(), "EMAIL_TO")

  withr::local_envvar(EMAIL_TO = "me@example.com", SMTP_SERVER = "", SMTP_USER = "")
  expect_error(check_email_settings(), "SMTP_SERVER, SMTP_USER or EMAIL_FROM")
})

test_that("format_email() lists all times and the booking links", {
  times <- format(
    as.POSIXct("2026-12-01 09:00", tz = "Europe/Berlin") + (0:14) * 86400,
    "%Y-%m-%dT%H:%M:%S%z"
  )
  email <- format_email(fake_appointments(times = times))

  expect_identical(email$subject, "API Potsdam: 15 freie Termine")
  expect_match(email$body, "D. Säuglings", fixed = TRUE)
  expect_match(email$body, "- Di, 01.12.2026, 09:00 Uhr", fixed = TRUE)
  expect_match(email$body, "- Di, 15.12.2026, 09:00 Uhr", fixed = TRUE)
  expect_match(email$body, booking_url("sauglings-u-kleinkindsprechstunde-unter-3-jahre"), fixed = TRUE)

  one <- format_email(fake_appointments(times = "2026-12-03T08:55:00+01:00"))
  expect_identical(one$subject, "API Potsdam: 1 freier Termin")
})

test_that("send_test_email() sends a test e-mail", {
  local_smtp_settings()
  args <- NULL
  local_mocked_bindings(curl_send_mail = function(...) args <<- list(...))

  expect_true(send_test_email())
  expect_match(args$message, "Subject: API Potsdam: Test-E-Mail", fixed = TRUE)
})

test_that("curl_send_mail() turns errors of the subprocess into normal errors", {
  expect_error(
    curl_send_mail(
      mail_from = "me@example.com",
      mail_rcpt = "me@example.com",
      message = "Subject: x\r\n\r\ny\r\n",
      smtp_server = "ftp://example.com",
      verbose = FALSE
    ),
    "smtp_server invalid"
  )
})

test_that("display names with special characters are quoted", {
  expect_identical(encode_display_name("API Potsdam"), "API Potsdam")
  expect_identical(encode_display_name("Rustler, Michael"), '"Rustler, Michael"')
  expect_identical(encode_display_name("API Potsdam: Termine"), '"API Potsdam: Termine"')
  expect_identical(encode_display_name('Say "hi"'), '"Say \\"hi\\""')
  expect_identical(encode_display_name('"Doe, John"'), '"Doe, John"')
  expect_match(encode_display_name("Jürgen, M."), "^=\\?UTF-8\\?B\\?.*\\?=$")
  expect_identical(
    encode_address("Rustler, Michael <me@example.com>"),
    '"Rustler, Michael" <me@example.com>'
  )
})

test_that("commas within quoted names do not split recipients", {
  expect_identical(
    split_addresses('"Doe, John" <j@x.de>, b@y.de'),
    c('"Doe, John" <j@x.de>', "b@y.de")
  )
  expect_identical(email_address('"Doe, John" <j@x.de>'), "j@x.de")
})

test_that("messages have a unique Message-ID", {
  time <- as.POSIXct("2026-11-11 06:05:09", tz = "UTC")
  message <- format_email_message("API <me@example.com>", "a@x.de", "S", "B", time = time)
  ids <- regmatches(message, regexpr("Message-ID: <[^>]+>", message))
  expect_match(ids, "^Message-ID: <20261111060509[^@<>]*@example\\.com>$")
  expect_false(identical(message_id("me@example.com"), message_id("me@example.com")))
  expect_match(message_id("no-address"), "@api\\.potsdam\\.invalid>$")
})

test_that("as_utf8() keeps valid UTF-8 of unknown encoding", {
  x <- rawToChar(as.raw(c(0x4a, 0xc3, 0xbc, 0x72, 0x67, 0x65, 0x6e)))
  Encoding(x) <- "unknown"
  y <- as_utf8(x)
  expect_identical(charToRaw(y), charToRaw(x))
  expect_identical(Encoding(y), "UTF-8")

  latin1 <- rawToChar(as.raw(c(0x4a, 0xfc, 0x72, 0x67, 0x65, 0x6e)))
  Encoding(latin1) <- "latin1"
  expect_identical(charToRaw(as_utf8(latin1)), charToRaw(x))
  expect_identical(as_utf8("plain"), "plain")
})
