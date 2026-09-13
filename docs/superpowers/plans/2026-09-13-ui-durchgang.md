# UI-Durchgang nach der iPad-Rueckmeldung

**Grundlage:** `.superpowers/sdd/ipad/rueckmeldung-13-09.md` (sechs Bildschirm-
fotos vom echten iPad, 13.09.2026).

**Zuschnitt:** Ein Durchgang, ohne Ruecksprache. AWTRIX und MQTT 5 sind **nicht**
Teil davon — beides ist erhoben und liegt bereit
(`.superpowers/sdd/awtrix/aufwand.md`, `.superpowers/sdd/mqtt5/pruefung.md`,
`.superpowers/sdd/mqtt-status/erhebung.md`).

---

## A — Der Fehler zuerst

**A1. Die Hilfe hat keinen Schliessknopf.** Am iPad sitzt der Nutzer fest und
muss die App beenden. `Nebenfenster.eigenerRahmen` sollte das abfangen.
**Gilt es auch fuer Geraetereferenz und Schriftprobe?** Beide sind ebenfalls
nackte `ScrollView`. Pruefen, nicht annehmen.
*Probe:* Jedes der vier Nebenfenster oeffnet und schliesst sich am iPad.

## B — Einstellungen

**B1.** Platzhalter der Uhrenadresse: Beispiel statt Beschreibung — `z. B.
192.168.0.10`.
**B2.** Die drei Brokerfelder beschriften (Adresse / Port / Benutzer).
**B3.** Unten fehlt der Rand.
**B4. Keine vorausgefuellten Zugangsdaten.** Benutzer und Kennwort leer, mit
erkennbarem Platzhalter. **Auch die Brokeradresse** (`Vorgabe.brokerHost`
= `192.168.1.10`) steht heute da, ohne dass jemand sie eingetragen hat.
*Achtung:* `AppZustand.eingerichtet` haengt bewusst am **Schluessel** statt am
Wert, weil die Vorgabe sonst „eingerichtet" vortaeuscht. Wird die Vorgabe
entfernt, muss diese Erkennung mitgeprueft werden — sonst kippt der Erststart.

## C — Ueber

**C1.** Fenstertitel „Ueber MQTT-TC002" doppelt die Ueberschrift darunter.
Nur **„Ueber"**.

## D — Senden

**D1.** Farbwaehler in die Zeile zu „Stil" (B / Grossbuchstaben).
**D2.** Dem Eingabefeld fehlt der Rahmen.
**D3. Die Schrift ist auf iPad und Mac zu klein.** Das ist keine Zahl, sondern
eine Grundsatzentscheidung fuer die ganze Desktop-Oberflaeche — einmal
festlegen und durchziehen, nicht Ansicht fuer Ansicht.

## E — Ein Editor statt zweier (der groesste Brocken)

**E1.** `MalenView` (201 Z.) und `IconEditorView` (496 Z.) sind zwei Editoren
fuer dieselbe Taetigkeit. Zusammenlegen zu **einem** Editor mit drei
Leinwandgroessen:
- **8×8** — kanonische LaMetric-Icons, bekommen eine Nummer
- **16×16** — nicht kanonisch
- **16×52** — die Anzeige selbst (heute „Malen")

Der Icon-Editor kann heute mehrere Einzelbilder, Verzoegerung, Abspielen und
Dateiimport; „Malen" kann das nicht. Nach der Zusammenlegung erbt die grosse
Leinwand das — damit werden Laufbilder fuer die ganze Anzeige malbar.

**Was es schon gibt und nicht neu gebaut wird:** Breite Bilder lassen sich ueber
„Bilder" (`BilderView`, `Bildersammlung`) speichern und aus Dateien einlesen.
Sie bekommen nur keine LaMetric-Nummer. Beim Zusammenlegen pruefen, ob das
auffindbar genug ist.

**E2.** Malraster deutlich groesser (gilt dann fuer alle drei Groessen).
**E3.** Pfeilkreuz: verschiebt die ganze Grafik pixelweise.

**Offen, nicht Teil dieses Durchgangs:** die „Umrechnung" zwischen den Groessen
mit maschineller Hilfe („mit ios27 ki?"). Das Ziel ist heute iOS 17; eine
Anhebung ist eine eigene Entscheidung. Eine **einfache** Umrechnung (skalieren,
beschneiden, zentrieren) ist davon unberuehrt und gehoert dazu.

## F — Die Uhr nach ihrem Stand fragen (am Geraet belegt, 13.09.2026)

`GET http://<uhr>/customList` liefert **nichts**.
`GET http://<uhr>/api/customList` liefert
`{"apps":["meldung2","meldung5","meldung3"],"count":3}`.

**Punkt 6 unserer Maengelliste — „`customList` nur ueber MQTT" — ist unser
eigener Pfadfehler**, kein Mangel der Firmware. Punkt 2 („leerer Rumpf loescht
nicht") und Punkt 5 („kein HTTP-Weg zum Umschalten") stehen unter demselben
Verdacht; beide lassen sich nur mit einem `POST` pruefen, der eine Anzeige
wirklich entfernt — gehoert dem Auftraggeber, nicht diesem Durchgang.

**F1.** `Geraet` lernt `GET /api/customList` (der vorhandene `hole(_:)` traegt
das). Beim Verbinden und beim Abfragen wird die Belegung damit **Tatsache**
statt Erinnerung — Quelle `.geraet`, auch fuer Anzeigen fremder Absender.
Der **Inhalt** bleibt geraten; daran aendert das nichts, und die Hilfe muss
weiter genau das sagen.

**F2.** `docs/firmware-beobachtungen.md` und `docs/en/firmware-observations.md`:
Punkt 6 richtigstellen — **beide Sprachen**. Kein Umschreiben der Geschichte,
sondern: was gilt, und dass `/api` der richtige Pfad ist. Punkt 2 und 5 als
„unter Verdacht, Pruefung offen" kennzeichnen.
**`docs/tc002-protokoll.md` §3.5 und `docs/en/tc002-protocol.md`** behaupten
dasselbe Falsche — mitziehen.

**Der Gewinn gegenueber RETAIN:** kein dauerhafter Zustand beim Broker, keine
bis zu 115 KB im Speicher haengend, und die Auskunft ist beim Start sofort da,
statt auf eine Nachricht zu warten, die vielleicht nie kommt.

---

## Bindend

- **`TC002Core` und `TC002Ansichten` bleiben plattformfrei.**
- **Kein Storytelling in der Oberflaeche. Dafuer ist die Hilfe.**
- **UI Kanon der Geraete vor zwanghafter Gleichheit.** Was am iPad richtig ist,
  ist es am iPhone selten.
- **Deutscher Wortlaut ist der Uebersetzungsschluessel.** `Text(_ content:
  String)` schlaegt **nichts** nach — der Pruefer sieht nur, ob der Eintrag da
  ist, nicht ob ihn jemand liest.
- **Die Hilfe zieht mit.** Sie redet an sieben Stellen von Fenster, Maus und
  Finder und kennt die Schriftprobe nicht. Was dieser Durchgang aendert, aendert
  sie mit.
- Jede Stufe fuer sich gruen; `swift test`, beide Simulatorbauten, `./build.sh`,
  beide Buendelpruefungen, `--pruefen`.

## Reihenfolge

A (Fehler) → B, C **und F parallel** (beruehren verschiedene Dateien) →
D1, D2, D3 (Senden, D3 ist Grundsatz) → E (Umbau).

E zuletzt, weil es die groesste Flaeche anfasst und von D3 abhaengt.

## Was dieser Durchgang NICHT enthaelt

- AWTRIX-NG-Unterstuetzung — erhoben, Empfehlung liegt vor, Entscheidung offen
  (**neben oder statt der TC002?**).
- MQTT 5 — erhoben; Gewinn auf dem Hauptweg vom eigenen Mitleser aufgefressen.
- RETAIN — unbelegt, und ein aufbewahrtes `customList` braechte nur die
  Belegung, nicht den Inhalt.
- Der Loeschtest (`POST /api/custom?name=x` mit `{}`) und der Umschalttest
  (`POST /api/switchDiyApp`) — beide veraendern die Anzeige und gehoeren dem
  Auftraggeber. Die Lesepruefung ist erledigt, siehe F.
