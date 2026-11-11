#' Default Settings for the API Potsdam Booking Page
#'
#' The settings are taken from the public online booking page of the
#' outpatient clinic of the "Akademie fuer Psychotherapie und
#' Interventionsforschung" (API) in Potsdam, which is provided by samedi:
#' <https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api>
#'
#' @return named list with elements
#'   * `practice_slug`: practice identifier in the booking page URL
#'   * `widget`: booking widget number in the booking page URL
#'   * `category_slug`: "Behandler/Kategorie" identifier in the booking page
#'     URL ("API, Potsdam")
#'   * `booking_base_url`: base URL of the booking page
#'   * `api_url`: base URL of the samedi booking API used by the booking page
#' @export
#' @examples
#' api_potsdam_config()
api_potsdam_config <- function() {
  list(
    practice_slug = "akademie-fur-psychotherapie-und-interventionsforschung-gmbh",
    widget = "1",
    category_slug = "api",
    booking_base_url = "https://termin.samedi.de",
    api_url = "https://patient.samedi.de/api/booking/v3"
  )
}

#' Booking Page URL
#'
#' @param event_type_slug slug of the appointment type (column `slug` of
#'   [get_event_types()]). If `NULL` (default), the URL of the category page
#'   (all appointment types) is returned.
#' @param insurance health insurance, see [insurances()] (default:
#'   "gesetzlich")
#' @param config settings as returned by [api_potsdam_config()]
#' @return URL of the booking page (character)
#' @export
#' @examples
#' booking_url()
#' booking_url("sauglings-u-kleinkindsprechstunde-unter-3-jahre")
booking_url <- function(
  event_type_slug = NULL,
  insurance = "gesetzlich",
  config = api_potsdam_config()
)
{
  path <- paste(
    c(
      config$booking_base_url,
      "b",
      config$practice_slug,
      config$widget,
      config$category_slug,
      event_type_slug
    ),
    collapse = "/"
  )

  paste0(
    path,
    "?insuranceId=",
    utils::URLencode(resolve_insurance(insurance), reserved = TRUE)
  )
}
