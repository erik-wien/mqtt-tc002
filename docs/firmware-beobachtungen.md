# Was uns an der Firmware aufgefallen ist

*[English version](en/firmware-observations.md)*

Gesammelt beim Bau von MQTT-TC002. Zwei Zwecke: eine Liste zum **Nachprüfen,
sobald eine neue Firmware erscheint**, und eine Grundlage, falls jemand das dem
Hersteller melden möchte.

**Geprüfter Stand:** `mcuVer V1.0.17`, `appVer 1.1.1`, abgelesen über
`GET /getBase` (Gerätereferenz §5.1). Alle Messungen vom 11.09.2026.

Die Belege stehen jeweils in [`tc002-protokoll.md`](tc002-protokoll.md); hier
steht nur, was daran ein Mangel ist und wie man in zwei Minuten prüft, ob er
noch besteht.

---

## Beim nächsten Firmware-Update prüfen

Der Reihe nach durchgehen, Ergebnis samt neuer Fassungsnummer hier eintragen.
Wird eine Zeile grün, gehört die entsprechende Stelle in der Gerätereferenz
geändert — und womöglich etwas in der App.

| # | Mangel | Prüfung | Stand 1.0.17 |
|---|---|---|---|
| 1 | `text` läuft nicht durch | langen Text als `text` schicken | ❌ |
| 2 | leerer HTTP-Rumpf löscht nicht | `POST /api/custom?name=x` mit leerem Rumpf | ❌ |
| 3 | GIF-Verfahren 1 wird nicht umgesetzt | deckendes Lauf-GIF schicken | ❌ |
| 4 | Platzhalter im Präfix macht das Gerät unbrauchbar | `#` als Präfix eintragen | ❌ |
| 5 | kein HTTP-Weg zum Umschalten | HTTP-Entsprechung zu `switchDiyApp` suchen | ❌ |
| 6 | `customList` nur über MQTT | `GET /customList` | ❌ |
| 7 | Schrift ohne Umlaute | `"content":"Grüße"` schicken | ❌ |

---

## 1. `text` läuft nicht durch, obwohl es soll

**Gerätereferenz §4.3.** Ein Text, der breiter ist als die 52 Pixel, wird
abgeschnitten statt durchzulaufen — auch bei `scrollSpeed` über null. Mit drei
Fassungen geprüft: mit `rect` und allen Feldern, ohne `rect`, und mit nichts als
`content` und `color`. Keine davon lief.

**Warum das zählt.** `scrollSpeed` ist eine Geräteeinstellung, die es gibt
(§5.4). Dass sie auf eigene Anzeigen über `custom` nicht wirkt, sieht nach einem
vergessenen Fall aus, nicht nach Absicht. Wäre es behoben, bräuchte es für
langen Text kein selbstgebautes Lauf-GIF mehr — und damit keine Nutzlast von
mehreren Kilobyte für einen Satz.

**Prüfung.** Einen Text mit sechzig Zeichen als `text` schicken und hinsehen.

---

## 2. Ein leerer HTTP-Rumpf meldet Erfolg und tut nichts

**Gerätereferenz §5.6.** `POST /api/custom?name=x` mit leerem Rumpf antwortet
`{"code":200,"message":"ok"}`, die Anzeige bleibt aber stehen. Über MQTT löscht
dieselbe leere Nutzlast zuverlässig (§3.2).

**Warum das zählt.** Eine Erfolgsmeldung für etwas, das nicht geschieht, ist
schlimmer als ein Fehler. Und es ist der Grund, warum HTTP allein nicht als
Betriebsart taugt: ohne Broker ließe sich keine Anzeige mehr entfernen.

**Prüfung.** Anzeige anlegen, leeren Rumpf hinterherschicken, hinsehen.

---

## 3. Von den GIF-Entsorgungsverfahren wird nur eines umgesetzt

**Gerätereferenz §4.2a.** Jedes Einzelbild eines animierten GIFs trägt eine
Anweisung, was vor dem nächsten Bild mit dem Bildschirm geschehen soll.
Verfahren 2 heißt „vorher löschen", Verfahren 1 „stehenlassen und nur den
geänderten Ausschnitt darüberzeichnen". Die Uhr setzt Verfahren 1 nicht um: Die
Formen stimmen, aber es fehlen einzelne Pixel.

**Warum das zählt.** Verfahren 1 ist das gebräuchlichere und in jedem
Bildprogramm die Vorgabe. Wer ein GIF von irgendwoher nimmt, bekommt mit hoher
Wahrscheinlichkeit ein löchriges Bild — ohne jeden Hinweis, woran es liegt. Uns
hat dieser eine Punkt einen ganzen Abend gekostet, und die falsche Spur führte
über sieben widerlegte Vermutungen.

**Prüfung.** Dasselbe Lauf-GIF zweimal bauen, einmal mit deckenden und einmal
mit durchsichtigen unbeleuchteten Pixeln, beide schicken. Nachsehen lässt sich
das Verfahren im dritten Byte jeder Grafiksteuer-Erweiterung (`0x21 0xF9`),
Bits 2 bis 4.

---

## 4. Ein Platzhalter im Präfix macht das Gerät unerreichbar

**Gerätereferenz §2.** Steht im eingetragenen Präfix ein `#` oder `+`, baut die
Firmware ein ungültiges CONNECT-Paket. Der Broker protokolliert
`bad socket read/write: Invalid input` und weist die Verbindung ab.

**Warum das zählt.** Das Gerät hängt danach an keinem Broker mehr, und die
Oberfläche sagt nicht, warum. Eine Eingabeprüfung im Einstellungsdialog wäre
eine Zeile Arbeit.

**Prüfung.** `#` als Präfix eintragen, Brokerprotokoll ansehen. Danach wieder
zurückstellen.

---

## 5. Das wirksame Präfix steht nirgends

**Gerätereferenz §2.** Die Firmware hängt an das eingetragene Präfix die letzten
vier Stellen der MAC-Adresse an. Aus `awtrix` wird `awtrix_a86b`. In der
Bedienoberfläche erscheint dieses vollständige Präfix nicht — ermitteln lässt es
sich nur über HTTP oder daran, welche Themen das Gerät beim Broker abonniert.

**Warum das zählt.** Es ist die häufigste Fehlerquelle überhaupt beim Einrichten,
und sie fällt mit MQTT 3.1.1 nicht auf: Eine Veröffentlichung auf ein Thema, das
niemand abonniert, bleibt stumm. Genau deshalb ermittelt diese App das Präfix
selbst, statt es eintragen zu lassen.

**Prüfung.** In der Geräteoberfläche nachsehen, ob das vollständige Thema
irgendwo steht.

---

## 6. Über HTTP fehlen zwei Dinge ganz

**Gerätereferenz §3.3 und §3.5.**

- Zum Umschalten auf eine Anzeige gibt es nur das MQTT-Thema `switchDiyApp`,
  keine HTTP-Entsprechung.
- `customList` ist ein MQTT-Thema; `GET /customList` liefert nichts.

**Warum das zählt.** Beides zusammen mit Punkt 2 verhindert einen reinen
HTTP-Betrieb. Wer keinen Broker betreiben will — und danach wird gefragt —, kann
zwar senden, aber weder löschen noch umschalten noch erfahren, was auf der Uhr
steht.

Bemerkenswert ist dabei: Die Uhr meldet über `customList` **auch** Anzeigen, die
über HTTP entstanden sind (§3.5). Der Zustand ist also da, er wird nur nicht
über HTTP herausgegeben.

---

## 7. Die eingebaute Schrift kennt keine Umlaute

**Gerätereferenz §1.** Kleinbuchstaben und Ziffern gehen; von den Satzzeichen
nur `%`, `.`, `-` und `:`. Alles andere fehlt ersatzlos — das Gerät zeigt an der
Stelle nichts an und meldet auch nichts.

**Warum das zählt.** Für ein Gerät, das in Europa verkauft wird, ist das eine
spürbare Lücke. Diese App umgeht sie, indem sie Text selbst rastert und als
Pixel schickt; das kostet Nutzlast und schließt die Gerätefunktionen für Text
aus.

**Prüfung.** `"content":"Grüße"` schicken.

---

## Noch nicht nachgeprüft

Diese Punkte sind keine Mängel, sondern Lücken in unserem Wissen. Eine neue
Firmware wäre ein guter Anlass, sie gleich mitzuklären — die Prüfungen stehen
jeweils in der Gerätereferenz §7.

- Ob die Gerätschrift Großbuchstaben kennt (§1).
- Ob `status` und `customList` aufbewahrt veröffentlicht werden (§3.5). Das
  entscheidet, ob ein frisches Abonnement sofort einen Stand bekommt.
- Ob `switchDiyApp` auf nicht vorhandene Anzeigen wirkt (§3.3).
- Wie `duration` und der geräteweite Seitenwechsel zusammenwirken (§4.4).
- Wie groß eine Nutzlast sein darf. Belegt sind rund 14 KB (§4.2a).
- Ob eine Teilangabe an `POST /setConfig` die übrigen Felder verliert (§5.5).
- Ob es weitere Themen unterhalb des Präfixes gibt — das Gerät abonniert
  `<präfix>/#`, also alles (§7).
- Ob sich Wecker, Lautstärke und Helligkeit auch über MQTT setzen lassen (§7).

---

## Wo es eine neue Firmware gäbe

Das Herstellerrepository
[UlanziTechnology/Ulanzi-U-Clock-TC002](https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002)
und Ulanzi Studio. Die laufende Fassung steht in der App unter „Verbindung"
nicht, aber `curl -s http://<adresse>/getBase` nennt sie.
