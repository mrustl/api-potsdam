# Health Insurances ("Krankenversicherung")

Insurance identifiers as used by the "Krankenversicherung" selector of
the samedi booking page.

## Usage

``` r
insurances()
```

## Value

named character vector. Names are the (lower case) German labels, values
are the identifiers used by the samedi booking API.

## Examples

``` r
insurances()
#>           gesetzlich               privat         selbstzahler 
#>             "public"            "private"                "280" 
#> berufsgenossenschaft 
#>                "283" 
```
