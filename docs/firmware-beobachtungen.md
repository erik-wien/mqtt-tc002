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
| 2 | leerer HTTP-Rumpf löscht nicht | `POST /api/custom?name=x` mit `{}` statt leerem Rumpf | ⚠️ Verdacht |
| 3 | GIF-Verfahren 1 wird nicht umgesetzt | deckendes Lauf-GIF schicken | ❌ |
| 4 | Platzhalter im Präfix macht das Gerät unbrauchbar | `#` als Präfix eintragen | ❌ |
| 5 | kein HTTP-Weg zum Umschalten | `POST /api/switchDiyApp` | ⚠️ Verdacht |
| 6 | Anzeigenliste nur über MQTT — **kein Mangel**, falscher Pfad | `GET /api/customList` | ✅ geht |
| 7 | Schrift ohne Umlaute | `"content":"Grüße"` schicken | ❌ |
| 8 | Uhr wird unerreichbar, bis sie stromlos war | `curl http://<adresse>/getBase` | ❌ |

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
schlimmer als ein Fehler. Und wenn es dabei bleibt, taugt HTTP allein nicht als
Betriebsart: ohne Broker ließe sich keine Anzeige mehr entfernen.

> ⚠️ **Unter Verdacht, Prüfung offen.** Ein fremdes Projekt beschreibt an
> derselben Firmwarefassung das Löschen mit dem Rumpf `{}` statt eines leeren
> Rumpfes. Geprüft ist hier nur der leere Rumpf. Ist `{}` der richtige Weg, ist
> das kein Mangel der Firmware, sondern eine Lücke in unserer Kenntnis — wie
> bei der Anzeigenliste in Punkt 6.

**Prüfung.** Anzeige anlegen, `POST /api/custom?name=x` mit dem Rumpf `{}`
hinterherschicken, hinsehen. Die Prüfung entfernt eine wirkliche Anzeige und
gehört deshalb an das Gerät, nicht in einen Test.

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

## 6. Über HTTP fehlt das Umschalten

**Gerätereferenz §3.3 und §5.7.**

Zum Umschalten auf eine Anzeige kennen wir nur das MQTT-Thema `switchDiyApp`.

> ⚠️ **Unter Verdacht, Prüfung offen.** Ein fremdes Projekt beschreibt an
> derselben Firmwarefassung `POST /api/switchDiyApp`. Gesucht haben wir danach,
> gefunden nichts — was nicht dasselbe ist wie „gibt es nicht".

**Warum das zählt.** Zusammen mit Punkt 2 entscheidet es, ob ein reiner
HTTP-Betrieb möglich ist. Wer keinen Broker betreiben will — und danach wird
gefragt —, kann heute senden und erfahren, was auf der Uhr steht, aber nach
unserem Kenntnisstand weder löschen noch umschalten.

**Die Anzeigenliste gehört nicht mehr hierher.** `GET /api/customList` (§5.7)
nennt die benannten Anzeigen des Geräts, am 13.09.2026 gemessen. Der Pfad ist
`/api/customList`; `GET /customList` liefert nichts, und genau das haben wir
für einen Mangel der Firmware gehalten. Es war unser Pfadfehler.

Die Liste meldet **auch** Anzeigen, die über HTTP entstanden sind (§3.5) — sie
ist der Zustand des Geräts und nicht die Buchführung eines Senders. Es sind
aber nur Namen: Was auf einer Anzeige steht, gibt das Gerät auf keinem Weg
heraus.

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

## 8. Die Uhr verschwindet aus dem Netz und kommt nur über den Strom zurück

**Am 12.09.2026 beobachtet.** Die Uhr antwortete auf keine HTTP-Anfrage mehr —
weder aus der App noch aus Safari auf einem anderen Gerät. Erreichbar war sie
erst wieder, nachdem sie vom Strom getrennt und neu gestartet wurde. Der
Broker war zur selben Zeit einwandfrei erreichbar, es lag also nicht am Netz.

**Warum das zählt, und warum es so schwer zu sehen ist.** In diesem Zustand
nimmt der Broker Sendungen weiterhin an und meldet Erfolg — die Uhr abonniert
ja nichts mehr, und eine Veröffentlichung an ein Thema ohne Abonnenten bleibt
in MQTT 3.1.1 stumm (§3). Eine sendende App sieht also **keinen Unterschied
zwischen „angekommen" und „ins Leere gegangen"**. Wir haben eine Stunde im
Netz gesucht: Freigabe für das lokale Netzwerk, WLAN-Client-Isolation,
getrennte Teilnetze, ein VPN. Keines davon war es.

**Prüfung.** `curl -s --max-time 3 http://<adresse>/getBase`. Kommt nichts und
antwortet der Broker gleichzeitig, ist es dieser Fall. HTTP ist dafür der
verlässliche Test, weil es die Uhr unmittelbar anspricht statt über den
Broker.

**Was noch offen ist.** Ob die Uhr dabei ganz aus dem WLAN fällt oder nur ihr
HTTP-Dienst hängt, ist ungeklärt — ebenso, ob sie in diesem Zustand noch am
Broker angemeldet ist. Beim nächsten Mal zuerst nachsehen, ob sie im Router
noch als verbunden geführt wird und ob `customList` noch etwas meldet.

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
