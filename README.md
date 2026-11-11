[![R-CMD-check](https://github.com/mrustl/api-potsdam/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mrustl/api-potsdam/actions/workflows/R-CMD-check.yaml)
[![check-appointments](https://github.com/mrustl/api-potsdam/actions/workflows/check-appointments.yaml/badge.svg)](https://github.com/mrustl/api-potsdam/actions/workflows/check-appointments.yaml)
[![pkgdown](https://github.com/mrustl/api-potsdam/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/mrustl/api-potsdam/actions/workflows/pkgdown.yaml)
[![Project Status](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)

# api.potsdam

R-Paket, das den Online-Terminkalender (samedi) der Ambulanz der
[Akademie für Psychotherapie und Interventionsforschung (API) Potsdam](https://www.api-potsdam.de/)
auf freie Termine prüft und per [Pushover](https://pushover.net) Bescheid
gibt, sobald ein Termin frei wird.

Voreingestellt ist die Terminart
**D. Säuglings- u. Kleinkindsprechstunde (unter 3 Jahre)** für **gesetzlich**
Versicherte
([Buchungsseite](https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api/sauglings-u-kleinkindsprechstunde-unter-3-jahre?insuranceId=public)).
Was tatsächlich geprüft wird, lässt sich über Funktionsargumente bzw. im
GitHub-Workflow über Secrets einstellen.

Das Paket stellt nur lesende Anfragen an die samedi-Booking-API, also
dieselben, die die Buchungsseite im Browser stellt. Es bucht keine Termine.
Buchen musst du selbst über den Link in der Benachrichtigung.

## Installation

```r
# Install package "remotes" from CRAN
if (! require("remotes")) {
  install.packages("remotes", repos = "https://cloud.r-project.org")
}

# Install package "api.potsdam" from GitHub
remotes::install_github("mrustl/api-potsdam")
```

## Benutzung

```r
library(api.potsdam)

# Online buchbare Terminarten (A bis E)
get_event_types()

# Freie Termine für die Standard-Terminart D, gesetzlich versichert
get_free_appointments()

# Mehrere Terminarten auf einmal, z. B. A und D
get_free_appointments(event_type = c("A", "D"))

# Prüfen und bei freien Terminen eine Pushover-Nachricht senden
Sys.setenv(PUSHOVER_USER = "<dein User Key>", PUSHOVER_APP = "<dein API Token>")
check_appointments(
  event_type = "D",
  insurance = "gesetzlich",
  send_pushover_notification = TRUE,
  state_file = "notified-appointments.txt"
)
```

Mit `state_file` kommt pro freiem Termin nur **eine** Nachricht, nicht bei
jeder Prüfung erneut. Wird ein Termin zwischendurch vergeben und später
wieder frei, kommt wieder eine Nachricht.

## Verfügbare Optionen

`event_type` akzeptiert den Buchstaben von der Buchungsseite, die samedi-Id,
den Slug oder einen eindeutigen Teil des Namens. Welche Terminarten online
buchbar sind, hängt von der Versicherung (`insurance`) ab.

**`insurance = "gesetzlich"`** (Standard)

| `event_type` | Terminart | samedi-Id | Slug |
|---|---|---|---|
| `"A"` | Erstgespräch / psychotherapeutische Sprechstunde / Wiedervorstellungen | `489167` | `erstgesprach` |
| `"B"` | Erstgespräch / Spezialsprechstunde für Aufmerksamkeits- und Konzentrationsprobleme, ADS, ADHS | `490647` | `diagnostik-ads-adhs` |
| `"C"` | Diagnostik für Teilleistungsstörung (Lese-Rechtschreib-Störung, Dyskalkulie) / Wiedervorstellung mit erneuter Diagnostik | `490646` | `diagnostik-gkv` |
| `"D"` (Standard) | Säuglings- u. Kleinkindsprechstunde (unter 3 Jahre) | `490648` | `sauglings-u-kleinkindsprechstunde-unter-3-jahre` |
| `"E"` | Krisenvorstellung (Klinikanschluss, Klinikbefunde bitte mitbringen) | `490645` | `krisenvorstellung-gkv` |

A bis C sowie E sind laut Buchungsseite für Kinder und Jugendliche bis unter
21 Jahren.

**`insurance = "privat"`**

| `event_type` | Terminart | samedi-Id | Slug |
|---|---|---|---|
| `"A"` | Erstgespräch ausschließlich Privatpatient\*in / psychotherapeutische Privatsprechstunde / Diagnostik / Therapie / keine medikamentöse Behandlung | `490644` | `erstgesprach-psychotherapeutische-privatsprechstunde` |

Für `"selbstzahler"` und `"berufsgenossenschaft"` bietet die API derzeit
keine Online-Termine an. Weitere Schreibweisen für `insurance`: `"gkv"`,
`"pkv"` oder eine numerische samedi-Versicherungs-Id.

Stand: 11.11.2026. Die aktuelle Liste liefert jederzeit:

```r
get_event_types(insurance = "gesetzlich")
get_event_types(insurance = "privat")
```

## Automatisch alle 5 Minuten prüfen (GitHub Actions)

Der Workflow [`check-appointments.yaml`](.github/workflows/check-appointments.yaml)
prüft alle 5 Minuten (das Minimum bei GitHub) und schickt bei neuen freien
Terminen eine Pushover-Nachricht mit hoher Priorität und direktem
Buchungslink.

Einrichtung:

1. In der [Pushover-App](https://pushover.net) unter
   *Your Applications → Create an Application/API Token* eine App anlegen.
2. Im GitHub-Repository unter *Settings → Secrets and variables → Actions*
   zwei **Secrets** anlegen:
   * `PUSHOVER_USER`: dein Pushover *User Key*
   * `PUSHOVER_APP`: der *API Token* der angelegten App
3. Optional, ebenfalls als **Secrets**, die Prüfung anpassen:
   * `API_POTSDAM_EVENT_TYPE`: Terminart(en), kommagetrennt (Standard: `D`).
     Am besten den Slug oder die samedi-Id aus `get_event_types()` verwenden
     statt des einzelnen Buchstabens, damit GitHub den Wert in den Logs
     zuverlässig mit `***` maskiert.
   * `API_POTSDAM_INSURANCE`: Versicherung (Standard: `gesetzlich`).
     Die Terminarten hängen von der Versicherung ab (siehe Tabelle oben).
     Wer `privat` einträgt, muss auch `API_POTSDAM_EVENT_TYPE` setzen,
     z. B. auf `erstgesprach-psychotherapeutische-privatsprechstunde`, sonst
     schlägt jede Prüfung fehl, weil es D für privat nicht gibt.

   Secrets statt Variables, weil Logs und Job-Zusammenfassung öffentlicher
   Repositories für alle sichtbar sind. Der Workflow gibt dort nur die
   Anzahl freier Termine aus. Terminart, Uhrzeiten und Buchungslink stehen nur
   in der Pushover-Nachricht.

   Optional unter *Variables* (Tab neben *Secrets*):
   * `API_POTSDAM_PRIORITY`: Pushover-Priorität von `-2` bis `2`
     (Standard: `1`, hoch, kommt auch in der Ruhezeit der Pushover-App
     durch). Mit `2` (Notfall) wiederholt Pushover die Nachricht alle 60
     Sekunden, bis du sie in der App bestätigst, höchstens eine Stunde lang.
     Damit der Alarm auf dem iPhone auch bei stummgeschaltetem Telefon
     klingelt, in der Pushover-App *Critical Alerts* erlauben.
4. Den Workflow auf den Default-Branch bringen. GitHub führt
   zeitgesteuerte Workflows nur dort aus, und der Workflow prüft auch bei
   manuellem Start nur dort. Solange die Pushover-Secrets fehlen, wird die
   Prüfung mit einer Warnung übersprungen.
5. Unter *Actions → check-appointments → Run workflow* einmal manuell
   starten. Mit dem Haken bei *Zuerst eine Pushover-Testnachricht senden*
   kommt zusätzlich eine Testnachricht, damit du siehst, dass Pushover
   funktioniert.

Gut zu wissen:

* GitHub startet zeitgesteuerte Workflows oft einige Minuten zu spät, bei
  hoher Last auch später. Die tatsächlichen Abstände liegen daher eher bei
  5 bis 15 Minuten.
* In öffentlichen Repositories deaktiviert GitHub zeitgesteuerte Workflows
  nach 60 Tagen ohne Aktivität im Repository. GitHub schickt vorher eine
  E-Mail, und der Workflow lässt sich unter *Actions* mit einem Klick
  wieder aktivieren.
* Schlägt eine Prüfung fehl (z. B. weil samedi seine Buchungsseite
  ändert), schickt GitHub eine E-Mail über den fehlgeschlagenen Workflow.

## Dokumentation

[https://mrustl.github.io/api-potsdam](https://mrustl.github.io/api-potsdam)
