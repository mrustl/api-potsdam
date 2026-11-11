# api.potsdam

R-Paket, das den Online-Terminkalender (samedi) der Ambulanz der
[Akademie für Psychotherapie und Interventionsforschung (API)
Potsdam](https://www.api-potsdam.de/) auf freie Termine prüft und per
[Pushover](https://pushover.net) und/oder E-Mail Bescheid gibt, sobald
ein Termin frei wird.

Voreingestellt ist die Terminart **D. Säuglings- u.
Kleinkindsprechstunde (unter 3 Jahre)** für **gesetzlich** Versicherte
([Buchungsseite](https://termin.samedi.de/b/akademie-fur-psychotherapie-und-interventionsforschung-gmbh/1/api/sauglings-u-kleinkindsprechstunde-unter-3-jahre?insuranceId=public)).
Was tatsächlich geprüft wird, lässt sich über Funktionsargumente bzw. im
GitHub-Workflow über Secrets einstellen.

Das Paket stellt nur lesende Anfragen an die samedi-Booking-API, also
dieselben, die die Buchungsseite im Browser stellt. Es bucht keine
Termine. Buchen musst du selbst über den Link in der Benachrichtigung.

## Installation

``` r

# Install package "remotes" from CRAN
if (! require("remotes")) {
  install.packages("remotes", repos = "https://cloud.r-project.org")
}

# Install package "api.potsdam" from GitHub
remotes::install_github("mrustl/api-potsdam")
```

## Benutzung

``` r

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

Zusätzlich oder statt Pushover per E-Mail, z. B. über IONOS:

``` r

Sys.setenv(
  SMTP_SERVER = "smtp.ionos.de",
  SMTP_USER = "du@deine-domain.de",
  SMTP_PASSWORD = "<Passwort des Postfachs>",
  EMAIL_TO = "du@deine-domain.de"
)
send_test_email()

# Nur per E-Mail
check_appointments(
  send_email_notification = TRUE,
  state_file = "notified-appointments.txt"
)

# Per Pushover und E-Mail (Pushover-Variablen wie oben setzen)
check_appointments(
  send_pushover_notification = TRUE,
  send_email_notification = TRUE,
  state_file = "notified-appointments.txt"
)
```

Mit `state_file` kommt pro freiem Termin nur **eine** Nachricht, nicht
bei jeder Prüfung erneut. Wird ein Termin zwischendurch vergeben und
später wieder frei, kommt wieder eine Nachricht.

## Verfügbare Optionen

`event_type` akzeptiert den Buchstaben von der Buchungsseite, die
samedi-Id, den Slug oder einen eindeutigen Teil des Namens. Welche
Terminarten online buchbar sind, hängt von der Versicherung
(`insurance`) ab.

**`insurance = "gesetzlich"`** (Standard)

| `event_type` | Terminart | samedi-Id | Slug |
|----|----|----|----|
| `"A"` | Erstgespräch / psychotherapeutische Sprechstunde / Wiedervorstellungen | `489167` | `erstgesprach` |
| `"B"` | Erstgespräch / Spezialsprechstunde für Aufmerksamkeits- und Konzentrationsprobleme, ADS, ADHS | `490647` | `diagnostik-ads-adhs` |
| `"C"` | Diagnostik für Teilleistungsstörung (Lese-Rechtschreib-Störung, Dyskalkulie) / Wiedervorstellung mit erneuter Diagnostik | `490646` | `diagnostik-gkv` |
| `"D"` (Standard) | Säuglings- u. Kleinkindsprechstunde (unter 3 Jahre) | `490648` | `sauglings-u-kleinkindsprechstunde-unter-3-jahre` |
| `"E"` | Krisenvorstellung (Klinikanschluss, Klinikbefunde bitte mitbringen) | `490645` | `krisenvorstellung-gkv` |

A bis C sowie E sind laut Buchungsseite für Kinder und Jugendliche bis
unter 21 Jahren.

**`insurance = "privat"`**

| `event_type` | Terminart | samedi-Id | Slug |
|----|----|----|----|
| `"A"` | Erstgespräch ausschließlich Privatpatient\*in / psychotherapeutische Privatsprechstunde / Diagnostik / Therapie / keine medikamentöse Behandlung | `490644` | `erstgesprach-psychotherapeutische-privatsprechstunde` |

Für `"selbstzahler"` und `"berufsgenossenschaft"` bietet die API derzeit
keine Online-Termine an. Weitere Schreibweisen für `insurance`: `"gkv"`,
`"pkv"` oder eine numerische samedi-Versicherungs-Id.

Stand: 11.11.2026. Die aktuelle Liste liefert jederzeit:

``` r

get_event_types(insurance = "gesetzlich")
get_event_types(insurance = "privat")
```

## Automatisch alle 6 Minuten prüfen (GitHub Actions)

Der Workflow
[`check-appointments.yaml`](https://mrustl.github.io/api-potsdam/.github/workflows/check-appointments.yaml)
prüft alle 6 Minuten (zu den Minuten 3, 9, 15 … 57) und schickt bei
neuen freien Terminen eine Pushover-Nachricht mit hoher Priorität
und/oder eine E-Mail, jeweils mit direktem Buchungslink.

Einrichtung:

1.  Im GitHub-Repository unter *Settings → Secrets and variables →
    Actions* die **Secrets** für mindestens einen der beiden Wege
    anlegen.

    **Pushover:** In der [Pushover-App](https://pushover.net) unter
    *Your Applications → Create an Application/API Token* eine App
    anlegen, dann:

    - `PUSHOVER_USER`: dein Pushover *User Key*
    - `PUSHOVER_APP`: der *API Token* der angelegten App

    **E-Mail** (Beispielwerte für IONOS):

    - `SMTP_SERVER`: `smtp.ionos.de`
    - `SMTP_PORT`: optional, `465` (SSL/TLS, Standard) oder `587`
      (STARTTLS)
    - `SMTP_USER`: die vollständige E-Mail-Adresse des IONOS-Postfachs
    - `SMTP_PASSWORD`: das Passwort dieses Postfachs
    - `EMAIL_FROM`: optional, Absender (Standard: `SMTP_USER`). IONOS
      akzeptiert nur das eigene Postfach oder einen Alias davon, z. B.
      `API Potsdam <du@deine-domain.de>`.
    - `EMAIL_TO`: Empfänger, mehrere durch Kommas getrennt

    Sind beide Wege eingerichtet und schlägt nur einer fehl (z. B. ein
    falsches SMTP-Passwort oder ein noch fehlendes Secret), kommt die
    Nachricht über den anderen trotzdem, und zwar nur einmal. Der Lauf
    wird dann rot markiert, damit GitHub dich per Mail auf den Fehler
    hinweist.

2.  Optional, ebenfalls als **Secrets**, die Prüfung anpassen:

    - `API_POTSDAM_EVENT_TYPE`: Terminart(en), kommagetrennt (Standard:
      `D`). Am besten den Slug oder die samedi-Id aus
      [`get_event_types()`](https://mrustl.github.io/api-potsdam/reference/get_event_types.md)
      verwenden statt des einzelnen Buchstabens, damit GitHub den Wert
      in den Logs zuverlässig mit `***` maskiert.
    - `API_POTSDAM_INSURANCE`: Versicherung (Standard: `gesetzlich`).
      Die Terminarten hängen von der Versicherung ab (siehe Tabelle
      oben). Wer `privat` einträgt, muss auch `API_POTSDAM_EVENT_TYPE`
      setzen,
      26. B. auf `erstgesprach-psychotherapeutische-privatsprechstunde`,
          sonst schlägt jede Prüfung fehl, weil es D für privat nicht
          gibt.

    Secrets statt Variables, weil Logs und Job-Zusammenfassung
    öffentlicher Repositories für alle sichtbar sind. Der Workflow gibt
    dort nur die Anzahl freier Termine aus. Terminart, Uhrzeiten und
    Buchungslink stehen nur in der Pushover-Nachricht bzw. E-Mail.

    Optional unter *Variables* (Tab neben *Secrets*):

    - `API_POTSDAM_PRIORITY`: Pushover-Priorität von `-2` bis `2`
      (Standard: `1`, hoch, kommt auch in der Ruhezeit der Pushover-App
      durch). Mit `2` (Notfall) wiederholt Pushover die Nachricht alle
      60 Sekunden, bis du sie in der App bestätigst, höchstens eine
      Stunde lang. Damit der Alarm auf dem iPhone auch bei
      stummgeschaltetem Telefon klingelt, in der Pushover-App *Critical
      Alerts* erlauben.

3.  Den Workflow auf den Default-Branch bringen. GitHub führt
    zeitgesteuerte Workflows nur dort aus, und der Workflow prüft auch
    bei manuellem Start nur dort. Solange weder Pushover- noch
    E-Mail-Secrets gesetzt sind, wird die Prüfung mit einer Warnung
    übersprungen.

4.  Unter *Actions → check-appointments → Run workflow* einmal manuell
    starten. Mit dem Haken bei *Zuerst eine Testnachricht senden
    (Pushover und/oder E-Mail)* kommt zusätzlich eine Testnachricht über
    jeden eingerichteten Weg.

Gut zu wissen:

- GitHub startet zeitgesteuerte Workflows oft einige Minuten zu spät,
  bei hoher Last auch später, und manchmal gar nicht. Zuverlässiger ist
  ein externer Cron-Dienst (z. B. cron-job.org), der den Workflow per
  `workflow_dispatch` startet: POST auf
  `https://api.github.com/repos/<owner>/<repo>/actions/workflows/check-appointments.yaml/dispatches`
  mit dem Body `{"ref":"main"}` und einem fein abgegrenzten Token (nur
  *Actions: Read and write* für dieses Repository) im Header
  `Authorization: Bearer <token>`.
- In öffentlichen Repositories deaktiviert GitHub zeitgesteuerte
  Workflows nach 60 Tagen ohne Aktivität im Repository. GitHub schickt
  vorher eine E-Mail, und der Workflow lässt sich unter *Actions* mit
  einem Klick wieder aktivieren.
- Schlägt eine Prüfung fehl (z. B. weil samedi seine Buchungsseite
  ändert), schickt GitHub eine E-Mail über den fehlgeschlagenen
  Workflow.

## Dokumentation

<https://mrustl.github.io/api-potsdam>
