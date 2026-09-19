# Übergabe, 19.09.2026 nachts

Schliesst an `uebergabe-19-09-abend.md` an. Alles committet und gepusht,
`main` ist der Stand.

## Der Prüfdurchgang über die iOS-Oberflächen

Der Auftraggeber: *„mir wäre am liebsten, wenn du jetzt die iOS Apps
durchtestest und ich das nicht tun muss."* Der delegierte Agent war an der
Nutzungsgrenze gescheitert und hatte nichts hinterlassen; der Durchgang lief
deshalb in der Sitzung selbst, am Simulator, mit `// SCHAUBILD`-Patches für
Zustände, die sich ohne Tippen nicht erreichen lassen.

**Angesehen:** Icons-Blatt, Einstellungen, Hilfeabschnitt „Einstellungen",
Sendeansicht und Protokoll am iPhone; Sendeansicht, Icons-Galerie,
Icon-Editor und Einstellungen am iPad; Sendeansicht und Editor am Mac zur
Gegenprobe.

### Sechs Befunde, alle behoben und am Bild nachgesehen

1. **Icons-Blatt am iPhone** — das Feld für die LaMetric-Nummer nahm die obere
   Bildschirmhälfte, die Sammlung begann unterhalb des Rands. Sammlung jetzt
   zuerst. Vier Spalten statt fünf, sonst blieben rund 60 Punkte je Kachel und
   Namen wie „Best Real Fire Flame" standen auch zweizeilig mit „…" da. Das
   leere Band von rund 45 Punkten unter dem Titel war der obere Rand, den eine
   gruppierte `List` für eine Abschnittsüberschrift freihält
   (`contentMargins(.top,…)`, nicht `listSectionSpacing`).
2. **„MQTT-Broker" statt „Broker"** — Einstellungsthema, Abschnittskopf,
   Aufzählung der fünf Bereiche, Überschrift in beiden Hilfen. Der Satz stand
   in beiden Hilfen wortgleich und liegt jetzt als `HilfeInhalt.brokerEintragen`
   an einer Stelle.
3. **Die Vorschau reservierte die volle Resthöhe**, obwohl die Spaltenbreite
   ihre Grösse begrenzt. Am iPad blieb dadurch rund ein Drittel der Seite leer.
   Sie trägt jetzt das Seitenverhältnis des Geräterahmens
   (`Geraetezeichnung.Masse.seitenverhaeltnis`); der übrige Platz gehört dem
   Verlauf. Am Mac, wo das Fenster breiter als hoch ist, begrenzt weiter die
   Höhe.
4. **Die Sendezeile des Editors** brauchte rund 500 Punkte, die mittlere Spalte
   am iPad im Hochformat bietet neben Seitenleiste und Inspektor rund 450.
   Beschnitten wurde nicht die Zeile, sondern der ganze Stapel — er ist so
   breit wie sein breitestes Kind und sass mittig. Jetzt zwei Zeilen, überall
   gleich. **Kein `ViewThatFits`:** Die Slotblöcke dehnen sich, ihre gemessene
   Idealbreite ist auch am Mac grösser als die Spalte, die Wahl fiel ohnehin
   immer gleich aus.
5. **Am iPhone fehlte der Sendeknopf.** Geschickt wurde allein über die
   Sendetaste der Tastatur; mit unten liegender Tastatur war ein getippter Text
   nicht abzuschicken. Der Auftraggeber wollte es wie in Nachrichten, mit einem
   Bild: Löschzeichen und blauer Pfeil **im** Feld, kein Plus links. Dafür gab
   es den Baustein schon — `eingabefeld(loeschbar:senden:laeuft:gelungen:)`,
   den der Schreibtisch benutzt. Damit steht die Abbildung der Sendezeile jetzt
   auch in der Telefonhilfe.
6. **Das Protokoll am iPhone** trug seinen Namen zweimal untereinander.

Dazu ein Fund ausserhalb der Oberfläche: **`scripts/dmg-bauen.sh` legte seinen
Arbeitsordner nicht an.** `build/` ist ignoriert und in einem frischen Klon
nicht da; `hdiutil create` brach mit „No such file or directory" ab — mitten in
`release.sh`, nach Tests, Bau und Signatur.

## Nachtrag: drei Beanstandungen am iPad-Editor

Der Auftraggeber sah sich den Editor an, waehrend der Durchgang lief.

7. **Der Titel „Icons" nannte nicht, was offen ist**, und der Bildname stand
   in einer eigenen Zeile ueber der Leinwand. Sein Vorschlag: „Icons — Matrix",
   und dann koennten Sichern und Abbrechen mit nach oben. So ist es jetzt — am
   iPad. Am Mac bleibt die Zeile: Dort traegt das Fenster den Programmnamen
   und kann den Bildnamen nicht aufnehmen.
8. **Der Grund fuer einen gesperrten Sendeknopf stand unter ihm** und damit am
   unteren Rand der Ansicht, wo er abgeschnitten wurde. Wer eine AWTRIX als
   Ziel hat, sah einen toten Knopf ohne Erklaerung — genau der Fall auf seinem
   Bildschirmfoto. Der Satz steht jetzt ueber Bloecken und Knopf.
9. **Eine gelungene Sendung meldete sich im Editor nicht.** Unter „Senden"
   wird der Knopf eine Sekunde lang gruen; hier geschah nichts, und der
   Slotblock daneben aendert sich nur, wenn die angesehene Uhr zugleich die
   Zieluhr ist.

**Die Rueckfrage vor dem Verwerfen funktioniert.** Nachgesehen, indem
`rueckfrage` als Anfangswert gesetzt wurde: Der Dialog „Aenderungen
verwerfen?" geht auf. `ungesichert` vergleicht die Leinwand gegen den
gesicherten Stand (`Leinwandverlauf.weichtAb`), den `oeffnen` setzt — nach
jedem Strich weicht sie ab.

## Stand der Fassung 1.6

`./release.sh 1.6` ist **bis zur Notarisierung** gelaufen: getestet, gebaut,
App und mitreisendes Werkzeug mit der Developer ID signiert, Abbild geschnürt
und signiert — 4,1 MB. Das Abbild ist danach **weggeräumt**: Es stammte von
einem Stand vor den drei Nachträgen oben und war nicht notarisiert; ein
solches Abbild herumliegen zu lassen lädt dazu ein, es weiterzugeben.

**Die Notarisierung fehlt**, und sie lässt sich nicht nachholen, ohne dass der
Auftraggeber einmal seine Zugangsdaten ablegt:

    xcrun notarytool store-credentials "MQTT-TC002" \
      --apple-id <apple-id> --team-id 25ZK4SS655

Danach genügt ein erneuter `./release.sh 1.6`. Ohne Notarisierung warnt
Gatekeeper auf fremden Rechnern; zum Weitergeben taugt das Abbild also noch
nicht. Veröffentlicht ist nichts — `gh release create` gibt `release.sh` nur
als letzte Zeile aus, es führt sie nicht aus.

Installiert ist 1.6 in `/Applications`; beide Simulatoren tragen den
gleichnamigen iOS-Bau.

## Offen, nach Gewicht

1. **Die Hilfe ist nur halb auf menschenfreundlichen Ton gebracht.**
   `wolkenabgleich`, `blockwissen`, `verlaufEntstehung`, `randUndAbstand`,
   `fettUndGross`, `fehlerStille` lesen sich inzwischen als Prosa mit
   Begründung; was fehlt, sind Sätze, die „Nutzlast" und „Rahmen" erklären,
   bevor sie gebraucht werden.
2. **Das Slotbild überlebt keinen Neustart.** `slotInhalt` liegt im
   Arbeitsspeicher; dauerhaft merkt sich die App nur Regler. Ein Bild dauerhaft
   zu merken hiesse, das Format von `Slotgedaechtnis` zu ändern — das teilen
   App, Kurzbefehle und Kommandozeilenwerkzeug. **Entscheidung des
   Auftraggebers.**
3. **Das Telefon warnt nicht vor einer grossen Nutzlast.** Über den Blöcken
   steht zwar „Läuft durch: N Einzelbilder", aber nicht, wie gross das wird;
   `Nutzlastzeile` gibt es dort nicht.
4. **Umbenennen und Löschen einer 52 × 16 fehlt am Telefon.** Icons haben dort
   ein Mehr-Menü, Anzeigen nicht; am Schreibtisch haben beide eines.
5. **Zwei ⊗-Zeichen in der Mac-Seitenleiste** unter „Icons", auf einem
   Bildschirmfoto des Auftraggebers zu sehen. Ursache ungeklärt, nicht
   nachgestellt.

## Zwei Dinge über das Werkzeug, die Zeit gekostet haben

- **Simulator.app gibt es in Xcode 27 nicht mehr** als eigenes Programm; die
  Simulatoren liegen im Device Hub. Damit fällt auch die Möglichkeit weg, per
  AppleScript in ein Simulatorfenster zu klicken. `simctl` kann fotografieren,
  aber nicht tippen — Zustände erreicht man weiter nur über `// SCHAUBILD`.
- **`sips --cropOffset` schneidet nicht, wo man denkt.** Für einen Ausschnitt
  am Mac ist `screencapture -R x,y,w,h` verlässlich; am Simulator lieber das
  ganze Bild lesen.
