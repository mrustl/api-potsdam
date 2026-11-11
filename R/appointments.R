# Select appointment types by letter, id, slug or (part of the) name ------------
resolve_event_types <- function(types, event_type) {
  if (nrow(types) == 0L) {
    stop("There are no online bookable appointment types.", call. = FALSE)
  }

  if (length(event_type) == 0L || anyNA(event_type)) {
    stop("'event_type' must not be empty or NA.", call. = FALSE)
  }

  available <- paste0(
    "\nAvailable appointment types:\n",
    paste(
      sprintf("* %s (id: %s, slug: '%s')", types$name, types$id, types$slug),
      collapse = "\n"
    )
  )

  indices <- vapply(as.character(event_type), function(x) {
    x <- trimws(x)

    is_letter <- grepl("^[A-Za-z]\\.?$", x)

    hits <- which(as.character(types$id) == x)

    if (length(hits) == 0L && is_letter) {
      hits <- which(types$letter == toupper(substr(x, 1L, 1L)))
    }

    if (length(hits) == 0L) {
      hits <- which(types$slug == x)
    }

    # (Part of the) name, but not for single letters ("F" would match "...f...")
    if (length(hits) == 0L && !is_letter && nzchar(x)) {
      hits <- which(grepl(tolower(x), tolower(types$name), fixed = TRUE))
    }

    if (length(hits) != 1L) {
      stop(
        sprintf(
          "%s appointment type matches '%s'.%s",
          if (length(hits) == 0L) "No" else "More than one",
          x,
          available
        ),
        call. = FALSE
      )
    }

    hits
  }, integer(1L))

  types[unique(indices), , drop = FALSE]
}

# Empty result of get_free_appointments() ---------------------------------------
empty_appointments <- function() {
  data.frame(
    event_type = character(0L),
    event_type_name = character(0L),
    event_type_id = integer(0L),
    insurance = character(0L),
    time = as.POSIXct(character(0L), tz = "Europe/Berlin"),
    booking_url = character(0L),
    stringsAsFactors = FALSE
  )
}

#' Get Free Appointments at the API Potsdam
#'
#' Asks the samedi booking API (the same requests that the public booking page
#' <https://termin.samedi.de> sends, read-only) for free appointments of the
#' given appointment type(s) at the outpatient clinic of the API Potsdam.
#'
#' @param event_type appointment type(s) ("Terminart") to check. Either the
#'   letter shown on the booking page (e.g. "D" for "D. Saeuglings- u.
#'   Kleinkindsprechstunde"),
#'   the samedi id, the slug or a (unique) part of the name, see
#'   [get_event_types()]. Several appointment types can be given as a vector.
#'   Default: "D"
#' @param insurance health insurance ("Krankenversicherung"), see
#'   [insurances()]. Default: "gesetzlich"
#' @param from first day to look for free appointments (default: today)
#' @param to last day to look for free appointments (default: one year after
#'   `from`)
#' @param config settings as returned by [api_potsdam_config()]
#' @return data frame with one row per free appointment and columns
#'   `event_type` (letter), `event_type_name`, `event_type_id`, `insurance`,
#'   `time` (POSIXct, time zone "Europe/Berlin") and `booking_url`. The data
#'   frame has zero rows if there is no free appointment.
#' @export
#' @examples
#' \dontrun{
#' # D. Saeuglings- u. Kleinkindsprechstunde, gesetzlich versichert
#' get_free_appointments()
#'
#' # Several appointment types at once
#' get_free_appointments(event_type = c("A", "D"))
#' }
get_free_appointments <- function(
  event_type = "D",
  insurance = "gesetzlich",
  from = Sys.Date(),
  to = as.Date(from) + 365,
  config = api_potsdam_config()
)
{
  insurance_id <- resolve_insurance(insurance)

  ids <- get_practice_ids(config)
  types <- get_event_types(insurance_id, config = config, ids = ids)
  selected <- resolve_event_types(types, event_type)

  results <- lapply(seq_len(nrow(selected)), function(i) {
    times <- get_times(
      event_type_id = selected$id[i],
      event_category_id = ids$event_category_id,
      insurance = insurance_id,
      from = from,
      to = to,
      config = config
    )

    n <- length(times)

    data.frame(
      event_type = rep(selected$letter[i], n),
      event_type_name = rep(selected$name[i], n),
      event_type_id = rep(selected$id[i], n),
      insurance = rep(insurance_label(insurance_id), n),
      time = times,
      booking_url = rep(booking_url(selected$slug[i], insurance_id, config), n),
      stringsAsFactors = FALSE
    )
  })

  appointments <- do.call(rbind, c(list(empty_appointments()), results))
  attr(appointments$time, "tzone") <- "Europe/Berlin"
  rownames(appointments) <- NULL
  appointments
}
