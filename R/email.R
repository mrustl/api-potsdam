#' Send an E-Mail via SMTP
#'
#' Sends a plain text e-mail (UTF-8) with [curl::send_mail()]. The SMTP
#' settings are read from environment variables by default:
#'
#' * `SMTP_SERVER`: host name of the SMTP server, e.g. "smtp.ionos.de"
#'   (or a URL like "smtps://smtp.ionos.de:465")
#' * `SMTP_PORT`: port (default: 465, SSL/TLS). With 587 or 25 the
#'   connection is upgraded with STARTTLS, which is required.
#' * `SMTP_USER`, `SMTP_PASSWORD`: login (e.g. the full e-mail address and
#'   the password of the mailbox)
#' * `EMAIL_FROM`: sender (default: `SMTP_USER`), e.g.
#'   "API Potsdam <me@example.com>"
#' * `EMAIL_TO`: recipient(s), several separated by commas
#'
#' @param subject subject of the e-mail
#' @param body text of the e-mail
#' @param to recipient(s), character vector or comma separated string
#' @param from sender, optionally with a display name ("Name <address>").
#'   If empty, `user` is used.
#' @param server,port,user,password SMTP settings
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
#' send_email("Test", "Hallo!")
#' }
send_email <- function(
  subject,
  body,
  to = Sys.getenv("EMAIL_TO"),
  from = Sys.getenv("EMAIL_FROM"),
  server = Sys.getenv("SMTP_SERVER"),
  port = Sys.getenv("SMTP_PORT", "465"),
  user = Sys.getenv("SMTP_USER"),
  password = Sys.getenv("SMTP_PASSWORD")
)
{
  recipients <- split_addresses(to)

  # Environment variables of unset GitHub secrets are empty strings
  if (!nzchar(trimws(from))) {
    from <- user
  }

  if (!nzchar(server) || length(recipients) == 0L || !nzchar(from)) {
    stop(
      "E-mail settings missing: SMTP server, sender and recipient are ",
      "required (environment variables SMTP_SERVER, SMTP_USER or ",
      "EMAIL_FROM, and EMAIL_TO).",
      call. = FALSE
    )
  }

  smtp <- smtp_url(server, port)

  message <- format_email_message(
    from = from,
    to = recipients,
    subject = subject,
    body = body
  )

  # A hanging SMTP server must not block the (scheduled) check
  handle_options <- list(timeout = 60L)

  if (nzchar(user)) {
    handle_options$username <- user
    handle_options$password <- password
  }

  # verbose = FALSE: the SMTP dialogue (including the login) must not end up
  # in (public) logs
  do.call(curl_send_mail, c(
    list(
      mail_from = email_address(from),
      mail_rcpt = email_address(recipients),
      message = message,
      smtp_server = smtp$url,
      use_ssl = smtp$use_ssl,
      verbose = FALSE
    ),
    handle_options
  ))

  invisible(TRUE)
}

# curl::send_mail() in a fresh R process ---------------------------------------
# In the same R process, an SMTP connection with TLS after previous HTTPS
# requests (to samedi) sometimes crashed R with memory corruption inside the
# curl package (segfault / "double free or corruption"), which no tryCatch()
# can catch. In a separate process, a crash becomes an ordinary error.
curl_send_mail <- function(...) {
  tryCatch(
    callr::r(
      function(args) {
        do.call(curl::send_mail, args)
        invisible(TRUE)
      },
      args = list(args = list(...)),
      show = FALSE
    ),
    error = function(e) {
      cause <- if (inherits(e$parent, "condition")) e$parent else e
      stop(conditionMessage(cause), call. = FALSE)
    }
  )

  invisible(TRUE)
}

# Stop if the e-mail settings are incomplete ------------------------------------
check_email_settings <- function() {
  missing <- c("SMTP_SERVER", "EMAIL_TO")[
    !nzchar(Sys.getenv(c("SMTP_SERVER", "EMAIL_TO")))
  ]

  if (!nzchar(Sys.getenv("EMAIL_FROM")) && !nzchar(Sys.getenv("SMTP_USER"))) {
    missing <- c(missing, "SMTP_USER or EMAIL_FROM")
  }

  if (length(missing) > 0L) {
    stop(
      "E-mail settings missing. Please set the environment variable(s) ",
      paste(missing, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

# URL of the SMTP server and TLS mode -------------------------------------------
# Port 465: implicit TLS (smtps://), any other port: STARTTLS is required
smtp_url <- function(server, port = "465") {
  server <- trimws(server)

  if (grepl("^smtps?://", server)) {
    url <- server
  } else {
    port <- trimws(as.character(port))
    if (!nzchar(port)) {
      port <- "465"
    }
    scheme <- if (port == "465") "smtps" else "smtp"
    url <- sprintf("%s://%s:%s", scheme, server, port)
  }

  list(
    url = url,
    use_ssl = if (startsWith(url, "smtps://")) "try" else "force"
  )
}

# Split "a@x.de, B <b@y.de>" into single addresses ------------------------------
# (commas within double quotes, e.g. "Doe, John" <j@x.de>, do not split)
split_addresses <- function(x) {
  x <- paste(x, collapse = ",")
  x <- regmatches(x, gregexpr('(?:[^,"]|"[^"]*")+', x, perl = TRUE))[[1L]]
  x <- trimws(x)
  x[nzchar(x)]
}

# Bare address of "Name <address>" ---------------------------------------------
email_address <- function(x) {
  trimws(ifelse(grepl("<[^>]+>", x), sub("^.*<([^>]+)>.*$", "\\1", x), x))
}

# Strings as UTF-8. Strings of unknown encoding that are valid UTF-8 (e.g.
# environment variables in a POSIX locale, as in cron jobs) are taken as UTF-8
# instead of being mangled by enc2utf8()
as_utf8 <- function(x) {
  x <- as.character(x)
  keep <- Encoding(x) != "latin1" & validUTF8(x)
  utf8 <- x[keep]
  Encoding(utf8) <- "UTF-8"
  x[keep] <- utf8
  x[!keep] <- enc2utf8(x[!keep])
  x
}

# RFC 2047 encoded header value (only if it contains non-ASCII characters) ------
encode_header <- function(x) {
  x <- as_utf8(x)
  if (!grepl("[^ -~]", x, useBytes = TRUE)) {
    return(x)
  }
  paste0("=?UTF-8?B?", jsonlite::base64_enc(charToRaw(x)), "?=")
}

# From/To header: encode or quote the display name only -------------------------
encode_address <- function(x) {
  if (!grepl("<[^>]+>", x)) {
    return(trimws(x))
  }
  name <- trimws(sub("<[^>]+>.*$", "", x))
  address <- email_address(x)
  if (!nzchar(name)) {
    return(address)
  }
  sprintf("%s <%s>", encode_display_name(name), address)
}

# Display name: RFC 2047 if non-ASCII, quoted if it contains special characters
encode_display_name <- function(name) {
  if (grepl("[^ -~]", name, useBytes = TRUE)) {
    return(encode_header(sub('^"(.*)"$', "\\1", name)))
  }
  if (grepl('^".*"$', name) || !grepl('[()<>\\[\\]:;@\\\\,."]', name, perl = TRUE)) {
    return(name)
  }
  sprintf('"%s"', gsub('(["\\\\])', "\\\\\\1", name))
}

# Message-ID header value (unique per message) ----------------------------------
message_id <- function(from, time = Sys.time()) {
  domain <- sub("^.*@", "", email_address(from))
  if (!nzchar(domain) || identical(domain, email_address(from))) {
    domain <- "api.potsdam.invalid"
  }
  sprintf(
    "<%s.%d.%s@%s>",
    format(as.POSIXct(time), "%Y%m%d%H%M%OS6", tz = "UTC"),
    Sys.getpid(),
    as.hexmode(sample.int(.Machine$integer.max, 1L)),
    domain
  )
}

# Date header in RFC 5322 format (independent of the locale) --------------------
format_email_date <- function(time = Sys.time()) {
  lt <- as.POSIXlt(time, tz = "UTC")
  sprintf(
    "%s, %02d %s %d %02d:%02d:%02d +0000",
    c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")[lt$wday + 1L],
    lt$mday,
    month.abb[lt$mon + 1L],
    lt$year + 1900L,
    lt$hour,
    lt$min,
    as.integer(lt$sec)
  )
}

# Complete e-mail (headers and base64 encoded UTF-8 body) -----------------------
format_email_message <- function(from, to, subject, body, time = Sys.time()) {
  encoded <- jsonlite::base64_enc(charToRaw(as_utf8(paste(body, collapse = "\n"))))
  encoded <- gsub("\\s", "", encoded)

  # Lines of at most 76 characters
  lines <- if (nchar(encoded) == 0L) {
    character(0L)
  } else {
    starts <- seq(1L, nchar(encoded), by = 76L)
    substring(encoded, starts, pmin(starts + 75L, nchar(encoded)))
  }

  paste(
    c(
      paste0("Date: ", format_email_date(time)),
      paste0("Message-ID: ", message_id(from, time)),
      paste0("From: ", encode_address(from)),
      paste0("To: ", paste(vapply(to, encode_address, ""), collapse = ", ")),
      paste0("Subject: ", encode_header(subject)),
      "MIME-Version: 1.0",
      "Content-Type: text/plain; charset=UTF-8",
      "Content-Transfer-Encoding: base64",
      "",
      lines,
      ""
    ),
    collapse = "\r\n"
  )
}

# Text of the e-mail notification about free appointments -----------------------
format_email <- function(appointments) {
  n <- nrow(appointments)

  subject <- sprintf(
    "API Potsdam: %s",
    if (n == 1L) "1 freier Termin" else sprintf("%d freie Termine", n)
  )

  groups <- split(appointments, factor(
    appointments$event_type_name,
    levels = unique(appointments$event_type_name)
  ))

  blocks <- vapply(groups, function(group) {
    paste0(
      group$event_type_name[1L], " (", group$insurance[1L], ")\n",
      paste0("- ", format_time_de(sort(group$time)), collapse = "\n"),
      "\n\nJetzt online buchen:\n", group$booking_url[1L]
    )
  }, character(1L))

  body <- paste0(
    paste(blocks, collapse = "\n\n\n"),
    "\n\n--\nDiese Nachricht wurde automatisch vom R-Paket api.potsdam ",
    "verschickt."
  )

  list(subject = subject, body = body)
}
