# Public configuration of the samedi booking page (https://termin.samedi.de),
# see samedi_widget_config(). Used as long as no other client id is configured.
samedi_defaults <- list(
  client_id = "8f0hsw1v0x676r5pqbf4fecv3fo7s5l",
  api_key = "TESTING",
  source = "bw_v3"
)

# Package-internal cache (client id read from the booking page at runtime)
.cache <- new.env(parent = emptyenv())

# Client id configured by the user (option or environment variable) ------------
samedi_client_id_override <- function() {
  id <- getOption("api.potsdam.samedi_client_id", Sys.getenv("SAMEDI_CLIENT_ID"))
  if (is.character(id) && length(id) == 1L && !is.na(id) && nzchar(id)) {
    id
  } else {
    NULL
  }
}

# Credentials used for requests to the samedi booking API -----------------------
samedi_credentials <- function() {
  credentials <- if (!is.null(.cache$widget)) .cache$widget else samedi_defaults
  override <- samedi_client_id_override()
  if (!is.null(override)) {
    credentials$client_id <- override
  }
  credentials
}

#' Read the Public Configuration of the samedi Booking Page
#'
#' The samedi booking page (<https://termin.samedi.de>) embeds the public
#' client id and API key it uses for its requests to the samedi booking API.
#' [check_appointments()] uses these credentials. They are read from the
#' booking page automatically if a request is rejected with the built-in
#' default credentials (HTTP 401/403), e.g. because samedi changed them.
#'
#' A client id can also be set explicitly with
#' `options(api.potsdam.samedi_client_id = "...")` or the environment
#' variable `SAMEDI_CLIENT_ID`.
#'
#' @param url URL of the booking page (default: "https://termin.samedi.de")
#' @return named list with elements `api_url`, `client_id`, `api_key`
#'   (`NA` if not found)
#' @export
#' @examples
#' \dontrun{
#' samedi_widget_config()
#' }
samedi_widget_config <- function(url = api_potsdam_config()$booking_base_url) {
  response <- http_get(url)

  if (response$status >= 400L) {
    stop(
      sprintf("Could not read the samedi booking page (HTTP %d).", response$status),
      call. = FALSE
    )
  }

  html <- response$text

  get_value <- function(key) {
    match <- regmatches(
      html,
      regexec(sprintf("%s\\s*:\\s*[\"']([^\"']*)[\"']", key), html)
    )[[1L]]
    if (length(match) == 2L) match[2L] else NA_character_
  }

  list(
    api_url = get_value("REACT_APP_BOOKING_WIDGET_API_URL"),
    client_id = get_value("REACT_APP_BOOKING_WIDGET_CLIENT_ID"),
    api_key = get_value("REACT_APP_BOOKING_WIDGET_API_KEY")
  )
}

# Refresh the credentials from the booking page. Returns TRUE if they changed.
refresh_samedi_credentials <- function() {
  config <- tryCatch(samedi_widget_config(), error = function(e) NULL)

  if (is.null(config) || is.na(config$client_id) || !nzchar(config$client_id)) {
    return(FALSE)
  }

  new <- list(
    client_id = config$client_id,
    api_key = if (is.na(config$api_key)) samedi_defaults$api_key else config$api_key,
    source = samedi_defaults$source
  )

  changed <- !identical(new[c("client_id", "api_key")], samedi_credentials()[c("client_id", "api_key")])
  .cache$widget <- new
  changed
}

# HTTP GET request with retries on server/network errors ------------------------
# Returns a list with the status code and the response body as text
http_get <- function(url, query = NULL) {
  response <- httr::RETRY(
    "GET",
    url = url,
    query = query,
    httr::timeout(30),
    times = 3L,
    pause_base = 2,
    quiet = TRUE,
    terminate_on = 400:499
  )

  list(
    status = httr::status_code(response),
    text = httr::content(response, as = "text", encoding = "UTF-8")
  )
}

# GET request to the samedi booking API (read-only) -----------------------------
# Returns the parsed JSON (lists, see jsonlite::fromJSON(simplifyVector = FALSE))
samedi_get <- function(
  endpoint,
  query = list(),
  api_url = api_potsdam_config()$api_url,
  refresh_credentials = TRUE
)
{
  credentials <- samedi_credentials()

  query <- query[!vapply(query, is.null, logical(1L))]

  response <- http_get(
    url = paste0(api_url, "/", endpoint),
    query = c(query, credentials[c("client_id", "api_key", "source")])
  )

  status <- response$status
  text <- response$text

  if (
    status %in% c(401L, 403L) &&
      refresh_credentials &&
      is.null(samedi_client_id_override()) &&
      refresh_samedi_credentials()
  ) {
    return(samedi_get(endpoint, query, api_url, refresh_credentials = FALSE))
  }

  if (status >= 400L) {
    stop(
      sprintf(
        "samedi API request '%s' failed (HTTP %d): %s",
        endpoint,
        status,
        substr(text, 1L, 300L)
      ),
      call. = FALSE
    )
  }

  jsonlite::fromJSON(text, simplifyVector = FALSE)
}

#' Get Practice and Category Ids
#'
#' Translates the practice and category identifiers of the booking page URL
#' (see [api_potsdam_config()]) into the ids used by the samedi booking API.
#'
#' @param config settings as returned by [api_potsdam_config()]
#' @return named list with elements `practice_id` (character) and
#'   `event_category_id` (integer)
#' @export
#' @examples
#' \dontrun{
#' get_practice_ids()
#' }
get_practice_ids <- function(config = api_potsdam_config()) {
  result <- samedi_get(
    "practices/slug_to_id",
    query = list(
      practice_slug = config$practice_slug,
      event_category_slug = config$category_slug
    ),
    api_url = config$api_url
  )

  if (is.null(result$practice_id) || is.null(result$event_category_id)) {
    stop(
      sprintf(
        "Could not find practice '%s' / category '%s' on the samedi booking page.",
        config$practice_slug,
        config$category_slug
      ),
      call. = FALSE
    )
  }

  list(
    practice_id = as.character(result$practice_id),
    event_category_id = as.integer(result$event_category_id)
  )
}

#' Get Online Bookable Appointment Types ("Terminarten")
#'
#' @param insurance health insurance, see [insurances()] (default:
#'   "gesetzlich")
#' @param config settings as returned by [api_potsdam_config()]
#' @param ids practice and category ids as returned by [get_practice_ids()]
#' @return data frame with one row per appointment type and columns `id`
#'   (samedi id), `letter` (letter shown on the booking page, e.g. "D"),
#'   `name`, `slug` and `description`
#' @export
#' @examples
#' \dontrun{
#' get_event_types()
#' }
get_event_types <- function(
  insurance = "gesetzlich",
  config = api_potsdam_config(),
  ids = get_practice_ids(config)
)
{
  result <- samedi_get(
    "event_types",
    query = list(
      practice_id = ids$practice_id,
      insurance_id = resolve_insurance(insurance),
      event_category_id = ids$event_category_id
    ),
    api_url = config$api_url
  )

  types <- result$data

  get_field <- function(field) {
    vapply(types, function(x) to_string(x[[field]]), character(1L))
  }

  name <- trimws(get_field("name"))

  data.frame(
    id = as.integer(get_field("id")),
    letter = extract_letter(name),
    name = name,
    slug = get_field("slug"),
    description = strip_html(get_field("description")),
    stringsAsFactors = FALSE
  )
}

#' Get Free Appointment Times for One Appointment Type
#'
#' @param event_type_id samedi id of the appointment type (column `id` of
#'   [get_event_types()])
#' @param event_category_id samedi id of the category (see
#'   [get_practice_ids()])
#' @param insurance health insurance, see [insurances()] (default:
#'   "gesetzlich")
#' @param from first day to look for free appointments (default: today)
#' @param to last day to look for free appointments (default: one year after
#'   `from`)
#' @param config settings as returned by [api_potsdam_config()]
#' @return sorted vector of free appointment start times (POSIXct, time zone
#'   "Europe/Berlin"), of length zero if there is no free appointment
#' @export
#' @examples
#' \dontrun{
#' ids <- get_practice_ids()
#' types <- get_event_types(ids = ids)
#' get_times(types$id[types$letter == "D"], ids$event_category_id)
#' }
get_times <- function(
  event_type_id,
  event_category_id,
  insurance = "gesetzlich",
  from = Sys.Date(),
  to = as.Date(from) + 365,
  config = api_potsdam_config()
)
{
  from <- as.Date(from)
  to <- as.Date(to)

  if (length(from) != 1L || length(to) != 1L || is.na(from) || is.na(to) || to < from) {
    stop("'from' and 'to' must be single dates with from <= to.", call. = FALSE)
  }

  result <- samedi_get(
    "times",
    query = list(
      event_category_id = event_category_id,
      event_type_id = event_type_id,
      from = format(from, "%Y-%m-%d"),
      to = format(to, "%Y-%m-%d"),
      insurance_id = resolve_insurance(insurance)
    ),
    api_url = config$api_url
  )

  times <- vapply(result$data, function(x) to_string(x$time), character(1L))

  sort(unique(parse_samedi_time(times)))
}
