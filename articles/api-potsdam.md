# Freie Termine bei der API Potsdam

Die Ambulanz der Akademie für Psychotherapie und Interventionsforschung
(API) Potsdam vergibt Termine über die Online-Terminbuchung von samedi.
Dieses Paket fragt den Terminkalender ab, also genau das, was die
Buchungsseite im Browser auch tut, und meldet sich per Pushover, sobald
etwas frei wird.

``` r

library(api.potsdam)
```

## Terminarten

Auf der Buchungsseite werden die Terminarten mit Buchstaben (A bis E)
bezeichnet. Diese Buchstaben können in
[`get_free_appointments()`](https://mrustl.github.io/api-potsdam/reference/get_free_appointments.md)
und
[`check_appointments()`](https://mrustl.github.io/api-potsdam/reference/check_appointments.md)
verwendet werden.

``` r

types <- get_event_types(insurance = "gesetzlich")
types[, c("letter", "name")]
#>   letter
#> 1      A
#> 2      B
#> 3      C
#> 4      D
#> 5      E
#>                                                                                                                          name
#> 1                                                   A. Erstgespräch / psychotherapeutische Sprechstunde / Wiedervorstellungen
#> 2                            B. Erstgespräch / Spezialsprechstunde für Aufmerksamkeits- und Konzentrationsprobleme, ADS, ADHS
#> 3 C. Diagnostik für Teilleistungsstörung (Lese-Rechtschreib-Störung, Dyskalkulie) / Wiedervorstellung mit erneuter Diagnostik
#> 4                                                                      D. Säuglings- u. Kleinkindsprechstunde (unter 3 Jahre)
#> 5                                                      E. Krisenvorstellung (Klinikanschluss, Klinikbefunde bitte mitbringen)
```

## Freie Termine

Voreingestellt ist “D. Säuglings- u. Kleinkindsprechstunde” für
gesetzlich Versicherte:

``` r

get_free_appointments()
#>   event_type                                        event_type_name
#> 1          D D. Säuglings- u. Kleinkindsprechstunde (unter 3 Jahre)
#> 2          D D. Säuglings- u. Kleinkindsprechstunde (unter 3 Jahre)
#>   event_type_id  insurance                time
#> 1        490648 gesetzlich 2026-12-03 08:55:00
#> 2        490648 gesetzlich 2026-12-10 08:55:00
#>                                                                                                                                                       booking_url
#> 1 https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api/sauglings-u-kleinkindsprechstunde-unter-3-jahre?insuranceId=public
#> 2 https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api/sauglings-u-kleinkindsprechstunde-unter-3-jahre?insuranceId=public
```

Mehrere Terminarten auf einmal:

``` r

appointments <- get_free_appointments(event_type = c("A", "D"))
appointments[, c("event_type", "time")]
#>   event_type                time
#> 1          D 2026-12-03 08:55:00
#> 2          D 2026-12-10 08:55:00
```

*Stand: 11.11.2026, 06:41 Uhr*

## Pushover-Benachrichtigung

[`check_appointments()`](https://mrustl.github.io/api-potsdam/reference/check_appointments.md)
schickt eine Nachricht mit allen neuen freien Terminen und einem
direkten Link zur Buchungsseite. Die Zugangsdaten werden aus den
Umgebungsvariablen `PUSHOVER_USER` und `PUSHOVER_APP` gelesen.

``` r

Sys.setenv(PUSHOVER_USER = "<dein User Key>", PUSHOVER_APP = "<dein API Token>")

# Testnachricht
send_test_notification()

# Nur über neue Termine benachrichtigen, nicht bei jeder Prüfung erneut
check_appointments(
  event_type = "D",
  insurance = "gesetzlich",
  send_pushover_notification = TRUE,
  state_file = "notified-appointments.txt"
)
```

Für die regelmäßige Prüfung alle 5 Minuten siehe den
GitHub-Actions-Workflow `check-appointments` und die Anleitung in der
README.
