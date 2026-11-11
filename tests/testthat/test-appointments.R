types <- data.frame(
  id = c(489167L, 490647L, 490648L),
  letter = c("A", "B", "D"),
  name = c(
    "A. Erstgespr\u00e4ch / psychotherapeutische Sprechstunde",
    "B. Erstgespr\u00e4ch / Spezialsprechstunde f\u00fcr Aufmerksamkeitsprobleme",
    "D. S\u00e4uglings- u. Kleinkindsprechstunde (unter 3 Jahre)"
  ),
  slug = c("erstgesprach", "diagnostik-ads-adhs", "sauglings-u-kleinkindsprechstunde-unter-3-jahre"),
  description = "",
  stringsAsFactors = FALSE
)

test_that("resolve_event_types() selects by letter, id, slug or name", {
  expect_identical(resolve_event_types(types, "D")$id, 490648L)
  expect_identical(resolve_event_types(types, "d.")$id, 490648L)
  expect_identical(resolve_event_types(types, 489167)$id, 489167L)
  expect_identical(resolve_event_types(types, "489167")$id, 489167L)
  expect_identical(
    resolve_event_types(types, "sauglings-u-kleinkindsprechstunde-unter-3-jahre")$id,
    490648L
  )
  expect_identical(resolve_event_types(types, "Kleinkind")$id, 490648L)
  expect_identical(resolve_event_types(types, c("D", "A", "D"))$id, c(490648L, 489167L))
})

test_that("resolve_event_types() fails for unknown or ambiguous types", {
  # a single letter must not match parts of names ("f" in "f\u00fcr")
  expect_error(resolve_event_types(types, "F"), "No appointment type matches 'F'")
  expect_error(resolve_event_types(types, "sprechstunde"), "More than one")
  expect_error(resolve_event_types(types, "Z"), "diagnostik-ads-adhs")
  expect_error(resolve_event_types(types, character(0L)), "must not be empty")
  expect_error(resolve_event_types(types, NA), "must not be empty")
  expect_error(resolve_event_types(types[0L, ], "D"), "no online bookable")
})

test_that("get_free_appointments() returns the free appointments of type D", {
  requests <- new.env()
  local_mocked_bindings(samedi_get = fake_samedi_get(requests = requests))

  appointments <- get_free_appointments(from = as.Date("2026-11-11"))

  expect_s3_class(appointments, "data.frame")
  expect_named(
    appointments,
    c("event_type", "event_type_name", "event_type_id", "insurance", "time", "booking_url")
  )
  expect_identical(nrow(appointments), 2L)
  expect_identical(unique(appointments$event_type), "D")
  expect_identical(unique(appointments$event_type_id), 490648L)
  expect_identical(unique(appointments$insurance), "gesetzlich")
  expect_identical(attr(appointments$time, "tzone"), "Europe/Berlin")
  expect_identical(
    unique(appointments$booking_url),
    booking_url("sauglings-u-kleinkindsprechstunde-unter-3-jahre", "gesetzlich")
  )

  endpoints <- vapply(requests$calls, `[[`, "", "endpoint")
  expect_identical(endpoints, c("practices/slug_to_id", "event_types", "times"))
  expect_identical(requests$calls[[3L]]$query$event_type_id, 490648L)
  expect_identical(requests$calls[[3L]]$query$event_category_id, 188822L)
  expect_identical(requests$calls[[3L]]$query$insurance_id, "public")
})

test_that("get_free_appointments() combines several appointment types", {
  local_mocked_bindings(samedi_get = fake_samedi_get(
    times = function(query) {
      if (query$event_type_id == 490648L) "times" else "times_empty"
    }
  ))

  appointments <- get_free_appointments(event_type = c("A", "D"))

  expect_identical(nrow(appointments), 2L)
  expect_identical(unique(appointments$event_type), "D")
})

test_that("get_free_appointments() returns zero rows if nothing is free", {
  local_mocked_bindings(samedi_get = fake_samedi_get(times = "times_empty"))

  appointments <- get_free_appointments()

  expect_identical(nrow(appointments), 0L)
  expect_named(appointments, names(empty_appointments()))
  expect_s3_class(appointments$time, "POSIXct")
})
