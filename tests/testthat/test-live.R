# Read-only requests to the real samedi booking API. Only run on demand:
# Sys.setenv(API_POTSDAM_LIVE_TESTS = "true")
skip_if_not_live <- function() {
  skip_on_cran()
  skip_if_not(
    identical(Sys.getenv("API_POTSDAM_LIVE_TESTS"), "true"),
    "Set API_POTSDAM_LIVE_TESTS=true to run tests against the samedi API"
  )
}

test_that("the booking page still offers appointment type D", {
  skip_if_not_live()

  types <- get_event_types()

  expect_true("D" %in% types$letter)
  expect_match(types$name[types$letter == "D"], "Kleinkindsprechstunde")
})

test_that("get_free_appointments() works with the real API", {
  skip_if_not_live()

  appointments <- get_free_appointments(event_type = c("A", "D"))

  expect_named(appointments, names(empty_appointments()))
  expect_true(all(as.Date(appointments$time, tz = "Europe/Berlin") >= Sys.Date() - 1L))
})
