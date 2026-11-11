#' Health Insurances ("Krankenversicherung")
#'
#' Insurance identifiers as used by the "Krankenversicherung" selector of the
#' samedi booking page.
#'
#' @return named character vector. Names are the (lower case) German labels,
#'   values are the identifiers used by the samedi booking API.
#' @export
#' @examples
#' insurances()
insurances <- function() {
  c(
    gesetzlich = "public",
    privat = "private",
    selbstzahler = "280",
    berufsgenossenschaft = "283"
  )
}

# Resolve an insurance given by name (or samedi id) to the samedi id ----------
resolve_insurance <- function(insurance) {
  if (
    !(is.character(insurance) || is.numeric(insurance)) ||
      length(insurance) != 1L ||
      is.na(insurance)
  ) {
    stop("'insurance' must be a single string or number.", call. = FALSE)
  }

  x <- tolower(trimws(as.character(insurance)))

  aliases <- c(
    insurances(),
    gkv = "public",
    public = "public",
    pkv = "private",
    private = "private",
    "self-pay" = "280",
    bg = "283"
  )

  if (x %in% names(aliases)) {
    return(unname(aliases[x]))
  }

  if (grepl("^[0-9]+$", x)) {
    return(x)
  }

  stop(
    sprintf(
      "Unknown insurance '%s'. Use one of %s or a numeric samedi insurance id.",
      insurance,
      paste0("'", names(insurances()), "'", collapse = ", ")
    ),
    call. = FALSE
  )
}

# German label of an insurance (for notifications) -----------------------------
insurance_label <- function(insurance) {
  id <- resolve_insurance(insurance)
  ids <- insurances()
  if (id %in% ids) {
    names(ids)[match(id, ids)]
  } else {
    sprintf("Versicherung %s", id)
  }
}
