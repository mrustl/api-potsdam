json_response <- function(x, status = 200L) {
  list(status = status, text = jsonlite::toJSON(x, auto_unbox = TRUE))
}

test_that("samedi_get() sends the widget credentials and drops NULL params", {
  requests <- list()
  local_mocked_bindings(http_get = function(url, query = NULL) {
    requests[[length(requests) + 1L]] <<- list(url = url, query = query)
    json_response(list(data = list()))
  })
  withr::local_options(api.potsdam.samedi_client_id = NULL)
  withr::local_envvar(SAMEDI_CLIENT_ID = "")

  result <- samedi_get("times", list(a = 1, b = NULL), api_url = "https://x.y/api")

  expect_identical(result, list(data = list()))
  expect_length(requests, 1L)
  expect_identical(requests[[1L]]$url, "https://x.y/api/times")
  expect_named(requests[[1L]]$query, c("a", "client_id", "api_key", "source"))
  expect_identical(requests[[1L]]$query$client_id, samedi_credentials()$client_id)
  expect_identical(requests[[1L]]$query$source, "bw_v3")
})

test_that("samedi_get() uses a client id given by option or env var", {
  requests <- list()
  local_mocked_bindings(http_get = function(url, query = NULL) {
    requests[[length(requests) + 1L]] <<- query
    json_response(list(data = list()))
  })

  withr::with_envvar(c(SAMEDI_CLIENT_ID = "from-env"), {
    samedi_get("times")
  })
  withr::with_options(list(api.potsdam.samedi_client_id = "from-option"), {
    samedi_get("times")
  })

  expect_identical(requests[[1L]]$client_id, "from-env")
  expect_identical(requests[[2L]]$client_id, "from-option")
})

test_that("samedi_get() reports HTTP errors", {
  local_mocked_bindings(http_get = function(url, query = NULL) {
    json_response(list(error = "Event type or category not found."), 404L)
  })

  expect_error(samedi_get("times"), "HTTP 404.*not found")
})

test_that("samedi_get() refreshes the client id once on HTTP 403", {
  withr::defer(rm(list = ls(.cache), envir = .cache))
  withr::local_envvar(SAMEDI_CLIENT_ID = "")
  withr::local_options(api.potsdam.samedi_client_id = NULL)

  client_ids <- character(0L)

  local_mocked_bindings(http_get = function(url, query = NULL) {
    if (is.null(query)) {
      # booking page with the current widget configuration
      return(list(
        status = 200L,
        text = paste0(
          '<script>window.ENV={REACT_APP_BOOKING_WIDGET_API_URL:"https://p/api",',
          'REACT_APP_BOOKING_WIDGET_CLIENT_ID:"new-id",',
          'REACT_APP_BOOKING_WIDGET_API_KEY:"KEY"}</script>'
        )
      ))
    }

    client_ids <<- c(client_ids, query$client_id)

    if (identical(query$client_id, "new-id")) {
      json_response(list(data = list(list(time = "2026-12-03T08:55:00+01:00"))))
    } else {
      list(status = 403L, text = "forbidden: invalid client_id")
    }
  })

  result <- samedi_get("times")

  expect_identical(client_ids, c(samedi_defaults$client_id, "new-id"))
  expect_identical(result$data[[1L]]$time, "2026-12-03T08:55:00+01:00")
  expect_identical(samedi_credentials()$api_key, "KEY")
})

test_that("samedi_get() does not retry forever if refreshing does not help", {
  withr::defer(rm(list = ls(.cache), envir = .cache))
  withr::local_envvar(SAMEDI_CLIENT_ID = "")
  withr::local_options(api.potsdam.samedi_client_id = NULL)

  calls <- 0L

  local_mocked_bindings(http_get = function(url, query = NULL) {
    if (is.null(query)) {
      return(list(status = 200L, text = 'REACT_APP_BOOKING_WIDGET_CLIENT_ID:"other-id"'))
    }
    calls <<- calls + 1L
    list(status = 403L, text = "forbidden")
  })

  expect_error(samedi_get("times"), "HTTP 403")
  expect_identical(calls, 2L)
})

test_that("samedi_widget_config() extracts the configuration", {
  local_mocked_bindings(http_get = function(url, query = NULL) {
    list(
      status = 200L,
      text = paste0(
        'window.ENV={NODE_ENV:"production",',
        'REACT_APP_BOOKING_WIDGET_API_URL:"https://patient.samedi.de/api/booking/v3",',
        'REACT_APP_BOOKING_WIDGET_CLIENT_ID:"abc123",',
        "REACT_APP_BOOKING_WIDGET_API_KEY:'TESTING'}"
      )
    )
  })

  expect_identical(
    samedi_widget_config(),
    list(
      api_url = "https://patient.samedi.de/api/booking/v3",
      client_id = "abc123",
      api_key = "TESTING"
    )
  )
})

test_that("samedi_widget_config() fails on HTTP errors", {
  local_mocked_bindings(http_get = function(url, query = NULL) {
    list(status = 500L, text = "")
  })
  expect_error(samedi_widget_config(), "HTTP 500")
})

test_that("get_practice_ids() returns the ids", {
  local_mocked_bindings(samedi_get = fake_samedi_get())
  expect_identical(
    get_practice_ids(),
    list(practice_id = "gw3b78v5pxq9h6fr", event_category_id = 188822L)
  )
})

test_that("get_practice_ids() fails for unknown practices", {
  local_mocked_bindings(samedi_get = function(...) list(error = "not found"))
  expect_error(get_practice_ids(), "Could not find practice")
})

test_that("get_event_types() returns all appointment types", {
  requests <- new.env()
  local_mocked_bindings(samedi_get = fake_samedi_get(requests = requests))

  types <- get_event_types()

  expect_s3_class(types, "data.frame")
  expect_named(types, c("id", "letter", "name", "slug", "description"))
  expect_identical(types$letter, c("A", "B", "C", "D", "E"))
  expect_identical(types$id[types$letter == "D"], 490648L)
  expect_identical(types$slug[types$letter == "D"], "sauglings-u-kleinkindsprechstunde-unter-3-jahre")
  expect_false(any(grepl("<", types$description)))

  event_type_call <- requests$calls[[2L]]
  expect_identical(event_type_call$endpoint, "event_types")
  expect_identical(event_type_call$query$insurance_id, "public")
  expect_identical(event_type_call$query$event_category_id, 188822L)
})

test_that("get_times() returns sorted times and passes the date range", {
  requests <- new.env()
  local_mocked_bindings(samedi_get = fake_samedi_get(requests = requests))

  times <- get_times(490648L, 188822L, from = as.Date("2026-11-11"))

  expect_s3_class(times, "POSIXct")
  expect_identical(
    format(times, "%Y-%m-%d %H:%M"),
    c("2026-12-03 08:55", "2026-12-10 08:55")
  )

  query <- requests$calls[[1L]]$query
  expect_identical(query$from, "2026-11-11")
  expect_identical(query$to, "2027-11-11")
  expect_identical(query$insurance_id, "public")
  expect_identical(query$event_type_id, 490648L)
})

test_that("get_times() returns an empty vector if there is no appointment", {
  local_mocked_bindings(samedi_get = fake_samedi_get(times = "times_empty"))
  times <- get_times(490648L, 188822L)
  expect_s3_class(times, "POSIXct")
  expect_length(times, 0L)
})

test_that("get_times() validates the date range", {
  expect_error(get_times(1L, 2L, from = "2026-12-01", to = "2026-11-01"), "from <= to")
  expect_error(get_times(1L, 2L, from = NA), "from <= to")
})
