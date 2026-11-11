# NULL (or empty) to NA, everything else to a single string ---------------------
to_string <- function(x) {
  if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x[[1L]])
}

# Letter of an appointment type as shown on the booking page --------------------
# ("D. Saeuglings- u. ..." -> "D"), NA if the name does not start with one
extract_letter <- function(name) {
  letter <- sub("^\\s*([A-Za-z])\\.\\s.*$", "\\1", name)
  letter[letter == name | is.na(name)] <- NA_character_
  toupper(letter)
}

# Remove HTML tags and collapse whitespace -------------------------------------
strip_html <- function(x) {
  x <- gsub("<[^>]*>", " ", x)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

# Parse ISO 8601 times as returned by samedi ("2026-12-03T08:55:00+01:00") ------
parse_samedi_time <- function(x, tz = "Europe/Berlin") {
  if (length(x) == 0L) {
    return(as.POSIXct(character(0L), tz = tz))
  }

  normalised <- sub("Z$", "+0000", x)
  normalised <- sub("([+-][0-9]{2}):?([0-9]{2})$", "\\1\\2", normalised)

  time <- as.POSIXct(normalised, format = "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC")

  failed <- is.na(time) & !is.na(x)

  if (any(failed)) {
    stop(
      "Could not parse time(s) returned by samedi: ",
      paste(x[failed], collapse = ", "),
      call. = FALSE
    )
  }

  attr(time, "tzone") <- tz
  time
}

# Format a time in German, e.g. "Do, 03.12.2026, 08:55 Uhr" ---------------------
format_time_de <- function(time, tz = "Europe/Berlin") {
  if (length(time) == 0L) {
    return(character(0L))
  }

  lt <- as.POSIXlt(time, tz = tz)
  weekday <- c("So", "Mo", "Di", "Mi", "Do", "Fr", "Sa")[lt$wday + 1L]
  sprintf("%s, %s Uhr", weekday, format(lt, "%d.%m.%Y, %H:%M"))
}

# Escape text for Pushover messages with HTML formatting ------------------------
escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}
