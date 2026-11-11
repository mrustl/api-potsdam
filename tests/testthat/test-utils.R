test_that("parse_samedi_time() handles offsets, DST and empty input", {
  time <- parse_samedi_time(c(
    "2026-12-03T08:55:00+01:00",
    "2026-07-02T09:30:00+02:00",
    "2026-07-02T07:30:00Z",
    "2026-07-02T09:30:00.000+0200"
  ))

  expect_s3_class(time, "POSIXct")
  expect_identical(attr(time, "tzone"), "Europe/Berlin")
  expect_identical(
    format(time, "%Y-%m-%d %H:%M"),
    c("2026-12-03 08:55", "2026-07-02 09:30", "2026-07-02 09:30", "2026-07-02 09:30")
  )

  empty <- parse_samedi_time(character(0L))
  expect_s3_class(empty, "POSIXct")
  expect_length(empty, 0L)

  expect_error(parse_samedi_time("tomorrow"), "Could not parse")
})

test_that("format_time_de() uses German weekdays and Berlin time", {
  time <- parse_samedi_time(c("2026-12-03T08:55:00+01:00", "2026-07-05T07:30:00Z"))
  expect_identical(
    format_time_de(time),
    c("Do, 03.12.2026, 08:55 Uhr", "So, 05.07.2026, 09:30 Uhr")
  )
  expect_identical(format_time_de(time[0L]), character(0L))
})

test_that("extract_letter() returns the letter of an appointment type", {
  expect_identical(
    extract_letter(c(
      "D. Kleinkindsprechstunde",
      " a. Erstgespr\u00e4ch",
      "Kleinkindsprechstunde",
      "D.Kleinkind",
      NA
    )),
    c("D", "A", NA, NA, NA)
  )
})

test_that("strip_html() removes tags and entities", {
  expect_identical(
    strip_html("<p>f\u00fcr Kinder<br>\nund&nbsp;Jugendliche &amp; mehr</p>\n"),
    "f\u00fcr Kinder und Jugendliche & mehr"
  )
})

test_that("escape_html() escapes special characters", {
  expect_identical(escape_html("a < b & c > d"), "a &lt; b &amp; c &gt; d")
})
