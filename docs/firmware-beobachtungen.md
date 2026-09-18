# Was uns an der Firmware aufgefallen ist

*[English version](en/firmware-observations.md)*

Gesammelt beim Bau von MQTT-TC002. Zwei Zwecke: eine Liste zum **Nachprüfen,
sobald eine neue Firmware erscheint**, und eine Grundlage, falls jemand das dem
Hersteller melden möchte.

**Geprüfter Stand:** `mcuVer V1.0.17`, `appVer 1.1.1`, abgelesen über
`GET /getBase` (Gerätereferenz §5.1). Messungen vom 11. bis 13.09.2026.

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
| 2 | leerer HTTP-Rumpf meldet Erfolg, ohne zu löschen | `POST /api/custom?name=x` mit leerem Rumpf, danach `GET /api/customList` | ❌ |
| 3 | GIF-Verfahren 1 wird nicht umgesetzt | deckendes Lauf-GIF schicken | ❌ |
| 4 | Platzhalter im Präfix macht das Gerät unbrauchbar | `#` als Präfix eintragen | ❌ |
| 5 | kein HTTP-Weg zum Umschalten — **kein Mangel**, unser Pfadfehler | `POST /api/switchDiyApp?name=x` | ✅ geht |
| 6 | Anzeigenliste nur über MQTT — **kein Mangel**, unser Pfadfehler | `GET /api/customList` | ✅ geht |
| 7 | Schrift ohne Umlaute | `"content":"Grüße"` schicken | ❌ |
| 8 | Uhr wird unerreichbar, bis sie stromlos war | `curl http://<adresse>/getBase` | ❌ |
| 9 | das wirksame Präfix steht nirgends | in der Geräteoberfläche nachsehen | ❌ |

Die Nummern sind Bezeichner: Sie bleiben stehen, auch wenn ein Punkt keiner mehr
ist — andere Dokumente verweisen darauf.

**Ein reiner HTTP-Betrieb ist möglich.** Anlegen und Löschen (Gerätereferenz
§5.6), Umschalten (§5.8) und die Anzeigenliste (§5.7) gehen ohne Broker, alle
vier am Gerät gemessen und am Display nachgesehen. Umgeschaltet werden muss
dabei wirklich: Die erste Anzeige erscheint sofort, eine zweite übernimmt nicht
von selbst (§5.8). Was allein MQTT liefert: den **Inhalt** einer Anzeige,
mitgelesen auf `custom` (§3.1), und die Meldung, ob die Uhr online ist (§3.4).

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

**Was daran hängt (18.09.2026).** Solange das so ist, hat „Scrolltempo" für
alles, was diese App schickt, keine Wirkung — es gilt allein den Anzeigen, die
das Gerät selbst verwaltet (Uhrzeit, Temperatur). Die Oberfläche sagt das seit
dem 18.09.2026 auch so; vorher versprach sie an vier Stellen das Gegenteil.

Daraus folgt eine Arbeit, die **erst nach der Behebung** sinnvoll ist: ein
gemeinsames Vokabular für beide Lauftempi. Auf AWTRIX NG gibt es das längst —
`scroll.speed` ist dort ein Prozentsatz, und `NGNutzlast.tempo` schickt je
Meldung 66 · 100 · 145 für langsam · mittel · schnell. Auf der Werksfirmware
wäre dieselbe Dreiteilung heute eine Behauptung über einen Regler, der nichts
tut. Läuft selbst geschickter Text eines Tages durch, sind es wirklich zwei
Namen für dieselbe Sache, und dann gehört `scrollSpeed` (Bereich
undokumentiert, die Oberfläche bietet 0…20) **gemessen** auf langsam / mittel /
schnell abgebildet — nicht geraten.

---

## 2. Ein leerer HTTP-Rumpf meldet Erfolg, ohne zu löschen

**Gerätereferenz §5.6.** `POST /api/custom?name=x` löscht die Anzeige, wenn der
Rumpf `{}` ist. Ein **leerer** Rumpf antwortet dasselbe
`{"code":200,"message":"ok"}`, lässt die Anzeige aber stehen.

**Warum das zählt.** Eine Erfolgsmeldung für etwas, das nicht geschieht, ist
schlimmer als ein Fehler. Und der leere Rumpf ist gerade der naheliegende
Versuch, weil über MQTT genau die **leere** Nutzlast löscht (§3.2) — dieselbe
Absicht, zwei Wege, gegensätzliche Mittel.

**Prüfung.** Anzeige anlegen, `POST /api/custom?name=x` mit leerem Rumpf
hinterherschicken, `GET /api/customList` (§5.7) abfragen: Steht die Anzeige noch
in der Liste, besteht der Mangel. Die Prüfung verändert eine wirkliche Anzeige
und gehört deshalb an das Gerät, nicht in einen Test.

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

## 5. Kein HTTP-Weg zum Umschalten — kein Mangel, unser Pfadfehler

**Gerätereferenz §5.8.** `POST /api/switchDiyApp?name=<name>` gibt es, und es
wirkt. Am 13.09.2026 gemessen, bei abgeschaltetem Seitenwechsel („kein Wechsel"
am Gerät), und am Display nachgesehen:

```json
{"code":200,"message":"app switch requested","data":{"name":"probe2","index":111}}
```

Die Uhr sprang darauf auf `probe2`. „requested" ist die Wortwahl der Antwort,
kein Vorbehalt. Einen Namen, den es nicht gibt, weist der Endpunkt mit
`{"code":404,"message":"custom app not found"}` ab.

Der Endpunkt war da; gesucht worden war an der falschen Stelle. Nichts daran ist
ein Mangel der Firmware, und beim nächsten Update ist dazu nichts zu prüfen.

> ❓ **Was `index` bedeutet, bleibt unbelegt.** Beobachtet sind `100` und `111`
> — fest ist die Zahl also nicht. Sie steht unter „Noch nicht nachgeprüft".

---

## 6. Anzeigenliste nur über MQTT — kein Mangel, unser Pfadfehler

**Gerätereferenz §5.7.** `GET /api/customList` nennt die benannten Anzeigen des
Geräts, am 13.09.2026 gemessen. Der Pfad ist `/api/customList`; `GET /customList`
— ohne `/api` — liefert nichts. Das ist der ganze Unterschied.

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

## 9. Das wirksame Präfix steht nirgends

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

## Noch nicht nachgeprüft

Diese Punkte sind keine Mängel, sondern Lücken in unserem Wissen. Eine neue
Firmware wäre ein guter Anlass, sie gleich mitzuklären — die Prüfungen stehen
jeweils in der Gerätereferenz §7.

- Ob die Gerätschrift Großbuchstaben kennt (§1).
- Ob `status` und `customList` aufbewahrt veröffentlicht werden (§3.5). Das
  entscheidet, ob ein frisches Abonnement sofort einen Stand bekommt.
- Wie sich das **MQTT**-Thema `switchDiyApp` bei einer nicht vorhandenen
  Anzeige verhält (§3.3) — über HTTP ist es belegt: `404 custom app not found`.
- Was `index` in der Antwort von `POST /api/switchDiyApp` bedeutet; beobachtet
  sind `100` und `111` (§5.8).
- Ob eine neu angelegte Anzeige auch bei eingeschaltetem Seitenwechsel sofort
  erscheint und eine zweite auch dann nicht übernimmt (§5.8).
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
