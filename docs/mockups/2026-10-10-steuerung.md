# Freigabe: Steuerung der Uhr (10.10.2026)

Mockup: `2026-10-10-steuerung.html` (Sprint 6). Grundlage: `docs/awtrix-ng-protokoll.md` §3.2, §3.5, §7, §10, §11. Status: **freigegeben** (Erik, 10.10.2026), mit den Änderungen unter „Entscheidung“.

## Was in die App gehört und was bei der Uhr bleibt

- **App, Fernbedienung „Uhr“ (oft, live):** Display an/aus, Helligkeit, Overlay, Moodlight (Farbe oder Weißton, Helligkeit), Indikatoren 1–3 (Farbe, Blinken, Blenden), Live-Ansicht des Bildspeichers, Zustand (Gerät, aktive App mit vor/zurück, Erreichbarkeit, WLAN-Stärke, Laufzeit, Batterie), Tasten und Drehknopf (nur im MQTT-Betrieb, weil nur Mitlesen sie sieht).
- **App, Einstellungen › Uhr (gespeichert, selten), acht Gruppen:** Helligkeit & Farbe, Text & Laufschrift, Schleife (inkl. 22 Übergänge), Uhr (Zifferblätter), Zeit & Datum, Wochentagsleiste, Klang, Tasten (`blockNavigation`); dazu MQTT-Verschlüsselung (Status, CA laden, CA entfernen mit Rückfrage; nur wenn `capabilities.mqttTls`).
- **Bleibt in der Web-Oberfläche der Uhr** (Link „Konfigurieren“ gibt es schon): WLAN und Netz, MQTT-Zugang und Präfix, TLS ein/aus samt Port, Anmeldung, Firmware, Neustart, Werkszustand, Hostname, Zeitzone und Zeitserver, Dateien, Skripte, Melodien, Radio, Spiegeln, Tastenvertauschung und Rückruf, Batterieschwelle, Debug, die wirkungslosen Schlüssel (Lichtsensor, Fühler). `enlargeApps` fasst die App laut Projektregel nie an.

## Varianten und Empfehlung

- A: ein Seitenleistenpunkt „Uhr“ mit Reitern Live | Einstellungen | Verbindung. Zwei Orte für „Uhr einstellen“ bleiben.
- B: alles in Einstellungen › Küche, Live-Bild oben. Kein neuer Punkt, aber der Regler hinter Einstellungen.
- **C, empfohlen:** Seitenleistenpunkt „Uhr“ = Fernbedienung; Einstellungen › Küche (die Uhrseite gibt es schon) = die gespeicherten Gruppen. iPhone: Titelmenü bekommt „Steuerung …“ (Blatt) und „Einstellungen der Uhr …“.
- Live-Bild: HTTP `display/screen` bzw. MQTT `cmd/screen/get`, alle 2 s, solange die Seite offen ist; es zeigt die Farben der Apps, nicht die Panelhelligkeit.

## Fragen

1. Eigener Punkt „Uhr“ plus gespeicherte Gruppen unter Einstellungen (C, empfohlen), oder alles an einem Ort (A/B)?
2. iPhone: Titelmenü „Küche ⌄“ mit „Steuerung …“ als Blatt, oder Knopf in der Pille?
3. Live-Bild aktualisiert sich sichtbar alle 2 s, solange offen, oder nur auf „Aktualisieren“?
4. Helligkeit als „50 %“ oder als Rohwert „128“ (0–255)?
5. Ein Moodlight lässt die Uhr nur noch einfarbiges Licht zeigen: genügt der Schalter, oder soll die Seite das zeigen?
6. Gilt „Display aus“ nur für die gewählte Uhr oder auch für alle gewählten auf einmal?
7. Acht Gruppen so, oder zusammengefasst (Uhr, Zeit & Datum, Wochentagsleiste in eine)?
8. Namen der Zifferblätter (sheet, ring, flap, month, big): „Blatt, Ring, Klappzahlen, Monat, Groß“?
9. `blockNavigation` ist ohne Erklärung: bis zur Messung weglassen oder mit Gerätenamen zeigen?
10. Tasten und Drehknopf nur im MQTT-Betrieb, im HTTP-Betrieb grau „nur im MQTT-Betrieb“?
11. „Anzeige vergrößert“ nur nennen (schreibgeschützt, mit Link) oder gar nicht erwähnen?
12. TLS ein/aus bleibt in der Web-Oberfläche; die App zeigt Status, lädt und entfernt die CA?
13. Eigene CA entfernen mit Rückfrage (gezeichnet) oder sofort mit Rückgängig?
14. Fehlt in der rechten Spalte (Web-Oberfläche) etwas, das die App tun sollte, etwa Neustart?

Offen aus dem Protokoll: Welche Werte `ca` außer `public` annimmt und was `pending` bedeutet, steht nicht da; „Eigene CA des Brokers“ ist eine Annahme.

## Entscheidung

Erik, 10.10.2026 (wo er unsicher war, gilt die Empfehlung; Einspruch möglich):

1. **C**: Seitenleistenpunkt „Uhr“ als Fernbedienung, gespeicherte Gruppen unter Einstellungen › Uhr.
2. iPhone: Titelmenü (Name der Uhr oben) mit „Steuerung …“ als Blatt und „Einstellungen der Uhr …“ (Empfehlung).
3. Live-Bild aktualisiert sich alle 2 s, solange die Seite offen ist.
4. Helligkeit in Prozent („50 %“).
5. Moodlight: der Schalter genügt, keine Lichtvorschau.
6. „Display aus“ **beides**: je Uhr und ein Knopf für alle gewählten Uhren.
7. **Sieben Gruppen**: Uhr, Zeit & Datum und Wochentagsleiste werden **eine** Gruppe.
8. Zifferblätter „Blatt, Ring, Klappzahlen, Monat, Groß“.
9. „Blocknavigation“ **fehlt** bis zur Messung (Empfehlung; Bedeutung unbekannt).
10. Tasten und Drehknopf nur im MQTT-Betrieb, sonst grau mit Grund.
11. „Anzeige vergrößert“ wird **nicht erwähnt** (Empfehlung; die App sendet immer volle 52×16).
12. TLS ein/aus bleibt in der Web-Oberfläche; die App zeigt den Status und lädt/entfernt die CA.
13. CA entfernen **mit Rückfrage**.
14. **Neustart der Uhr** kommt in die App (Fernbedienung, mit Rückfrage).
