test_that("resolve_insurance() maps names, aliases and ids", {
  expect_identical(resolve_insurance("gesetzlich"), "public")
  expect_identical(resolve_insurance(" Gesetzlich "), "public")
  expect_identical(resolve_insurance("GKV"), "public")
  expect_identical(resolve_insurance("public"), "public")
  expect_identical(resolve_insurance("privat"), "private")
  expect_identical(resolve_insurance("PKV"), "private")
  expect_identical(resolve_insurance("selbstzahler"), "280")
  expect_identical(resolve_insurance("bg"), "283")
  expect_identical(resolve_insurance(392), "392")
  expect_identical(resolve_insurance("392"), "392")
})

test_that("resolve_insurance() rejects invalid input", {
  expect_error(resolve_insurance("gesetzlicher"), "Unknown insurance")
  expect_error(resolve_insurance(c("gesetzlich", "privat")), "single")
  expect_error(resolve_insurance(NA), "single")
  expect_error(resolve_insurance(NULL), "single")
  expect_error(resolve_insurance(TRUE), "single")
})

test_that("insurance_label() returns German labels", {
  expect_identical(insurance_label("public"), "gesetzlich")
  expect_identical(insurance_label("gkv"), "gesetzlich")
  expect_identical(insurance_label("280"), "selbstzahler")
  expect_identical(insurance_label(392), "Versicherung 392")
})

test_that("booking_url() builds the URL of the booking page", {
  expect_identical(
    booking_url("sauglings-u-kleinkindsprechstunde-unter-3-jahre"),
    paste0(
      "https://termin.samedi.de/b/",
      "akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api/",
      "sauglings-u-kleinkindsprechstunde-unter-3-jahre?insuranceId=public"
    )
  )
  expect_identical(
    booking_url(insurance = "privat"),
    paste0(
      "https://termin.samedi.de/b/",
      "akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api",
      "?insuranceId=private"
    )
  )
})
