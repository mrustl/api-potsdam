# Read a recorded response of the samedi booking API
read_fixture <- function(name) {
  jsonlite::fromJSON(
    test_path("fixtures", paste0(name, ".json")),
    simplifyVector = FALSE
  )
}

# Fake samedi_get(): returns recorded responses and records the requests
fake_samedi_get <- function(times = "times", requests = NULL) {
  function(endpoint, query = list(), ...) {
    if (!is.null(requests)) {
      if (is.null(requests$calls)) {
        requests$calls <- list()
      }
      requests$calls[[length(requests$calls) + 1L]] <- list(
        endpoint = endpoint,
        query = query
      )
    }

    switch(
      endpoint,
      "practices/slug_to_id" = read_fixture("slug_to_id"),
      "event_types" = read_fixture("event_types"),
      "times" = read_fixture(if (is.function(times)) times(query) else times),
      stop("unexpected endpoint: ", endpoint)
    )
  }
}

# Data frame of free appointments as returned by get_free_appointments()
fake_appointments <- function(
  times = c("2026-12-03T08:55:00+01:00", "2026-12-10T08:55:00+01:00")
)
{
  n <- length(times)

  data.frame(
    event_type = rep("D", n),
    event_type_name = rep(
      "D. S\u00e4uglings- u. Kleinkindsprechstunde (unter 3 Jahre)",
      n
    ),
    event_type_id = rep(490648L, n),
    insurance = rep("gesetzlich", n),
    time = parse_samedi_time(times),
    booking_url = rep(
      booking_url("sauglings-u-kleinkindsprechstunde-unter-3-jahre"),
      n
    ),
    stringsAsFactors = FALSE
  )
}
