# Offene Punkte, Stand 13.09.2026 abends

**Stand am Abend des 13.09. — was erledigt ist:** A1, A3 (Editorfehler), B1
(Schaltflaechen- und Feldstil durchgaengig), B2, B3, B4, A4, C1, C2 (Editor),
F1 (Schluesselbund aus den Tests), F5 (Eingabetaste), F6 (Ternaere), B6
(Nutzlastwarnung), dazu Umbenennen in der Bestandsliste, das geladene Bild auf
der Leinwand samt Rueckfrage, und die Ulanzi-Werknummer fuer 16×52.
**443 Tests gruen.**

**Zuletzt in Arbeit:** Abschnitt D, die Betriebsart HTTP/MQTT je Uhr — Kern,
Werkzeug und Kurzbefehle sind committet, die Ansichten waren noch offen.

**Reihenfolge danach, vom Auftraggeber bestaetigt:** iCloud (E1) → AWTRIX NG
(E2/E2a). Begruendung fuer das Vorziehen der Betriebsart: AWTRIX braucht
dieselbe Verzweigung im Sendeweg; andersherum baut man sie zweimal.

**Offen geblieben:** B5 (`.help` am iPad unsichtbar), A5 (16×16 stellt die
Regler nicht her), F2 (Werkzeug sieht nur 8×8), F1a (zwei Tests am echten
Schluesselbund), F3 (vermischter Commit), dazu **zwei Stellen mit demselben
unuebersetzten Wortpaar** „Am Broker angemeldet" (`VerbindungView:55`,
`ZielauswahlView:85`). Spaeter: MQTT 5, Rahmengrafiken.

**Eine Prozesslehre des Tages:** Zwei Agenten haben mit `commit -a` den Index
eines Parallelagenten eingesammelt. Kuenftig **nur `git add <datei>`** — das
stand im Auftrag, wurde aber zweimal missachtet.

---

Zusammengefuehrt aus der Liste des Auftraggebers und dem, was aus den
Durchgaengen des Tages offen geblieben ist.

---

## A — Fehler

**A1. Icon sichern loest „Neu" aus.** Sichern funktioniert nicht; stattdessen
faengt der Editor von vorn an. *(Neu gemeldet.)*

**A2. ~~Die 16×52-Leinwand schaltet nicht um.~~ Kein App-Fehler — die Uhr war
haengengeblieben.** Nachgemessen: `GET /api/customList` antwortete
`{"apps":[],"count":0}`, also **HTTP lebte und alle Anzeigen waren weg**. Nach
einem Neustart des Geraets ging es wieder.
**Das ist eine neue Firmwarebeobachtung** und ein *anderer* Ausfall als Punkt 8
der Maengelliste, bei dem die Uhr ganz aus dem Netz verschwindet: Hier
antwortete sie und hatte trotzdem ihren Anzeigenbestand verloren.
→ Gehoert in `docs/firmware-beobachtungen.md` (beide Sprachen), samt der
Erkenntnis, dass die App in dem Fall **richtig** „frei" zeigt.

**A3. Die Modusleiste ueberlagert „Seitenleiste schliessen".** Am Mac sitzt es
gut, am iPad nicht — dort liegt die neue Dreierleiste ueber dem schon
vorhandenen Knopf. **Und am iPad fehlt Rueckgaengig ganz.** Zu klaeren: laesst
sich die vorhandene Leiste erweitern; wenn nicht, die drei Symbole
**kleiner und in die Seitenleiste**. *(Neu gemeldet.)*

**A4. Erledigt (`d91b3e5`).** Das Blatt hinter „Oeffnen…" ist gebaut wie der
Inspektor (beschriftete Zeilen, gefasste Felder, Kopf und Fuss),
`Editorbestand.vorschlag(fuerDateinamen:)` trennt `<Nummer>_<Titel>` — nur
eine reine Ziffernfolge vor dem ersten Unterstrich zaehlt, sonst bleibt die
Nummer leer statt einen Dateinamen vorzutaeuschen. Ob nach einer Nummer
gefragt wird, leitet **eine** Ansicht aus der Groesse der **Datei** ab.

**Zur schon vergebenen Nummer entschieden:** Sie wird **nicht** abgewiesen,
sondern ersetzt — aber sichtbar. Das Blatt nennt beim Tippen, was dort liegt,
und der Knopf heisst dann „Ersetzen" statt „Oeffnen". Gruende: Ersetzen ist
die Semantik des Bestands (Sichern tut es auch, und die Hilfe sagt es),
dasselbe Icon in besserer Fassung noch einmal zu holen ist der haeufigste
Fall, und die Eindeutigkeit bleibt ohnehin gewahrt (eine Datei je Nummer).
Falsch war nicht das Ersetzen, sondern dass man es erst hinterher merkte.

**A5. Ein 16×16-Icon stellt die Regler nicht wieder her.** `Slotgedaechtnis`
rechnet die Pruefsumme mit Kante 8; bei 16 beginnt der Text erst bei Spalte 18.
Braucht ein Feld `iconKante` im `Slotstand` — das ist ein Dateiformat.
*(Aus dem Editor-Durchgang.)*

---

## B — Oberflaeche

**B1. Schaltflaechen muessen als solche erkennbar sein.** Grauer abgerundeter
Kasten ohne Rahmen, beim Klicken dunkler, beim Ueberfahren hervorgehoben,
**Schrift dunkel, nicht blau**. Vorbild ist der Pages-Inspektor (Bildschirmfoto
vom 13.09.2026: „Verbinden …" gesperrt neben „Fertig").
**Das ist eine durchgaengige Entscheidung**, nicht eine Stelle — sie betrifft
Mac und iPad ueberall. Heute benutzt die App den randlosen Stil: blaue
Beschriftung ohne Flaeche. Der ist laut Richtlinien fuer Verweise gedacht,
nicht fuer Befehle; deshalb sieht „Radieren" aus wie ein Link.

**Drei Abstufungen**, sonst wirkt alles gleich wichtig:
- `.bordered` fuer gewoehnliche Befehle (Radieren, Oeffnen, Verdoppeln, Nachladen)
- `.borderedProminent` fuer die **eine** Haupthandlung je Ansicht (Senden, Sichern)
- rot getoent fuer Zerstoerendes (Alles loeschen, Entfernen, Papierkorb)

**Nicht** dorthin gehoeren: echte Verweise (LaMetric-Galerie, Lizenzadresse),
Symbole in der Werkzeugleiste, Zeilen in einer Liste.

**⚠ Die Falle, die auf einem Geraet richtig und auf dem anderen falsch
aussieht:** Am Mac faerbt `.bordered` die Beschriftung dunkel — auf iPadOS in
der **Akzentfarbe**, also blau. Dort braucht es zusaetzlich die Textfarbe,
sonst trifft es Pages nicht. Ebenso pruefen: wie der **gesperrte** Zustand
aussieht (im Vorbild sichtbar abgeblendet, nicht verschwunden).

**B2. Erledigt (`76e6fe2`).** Der Knopf heisst „Oeffnen…", das Blatt dahinter
ebenso. Die Auslassungspunkte bleiben — es folgt ein Dialog.

**B3. Erledigt (`4ed79ec`).** `play.fill`/`stop.fill` unmittelbar rechts vom
Sekundenwert, in beiden Zustaenden mit Beschriftung fuer die Sprachausgabe.

**B4. Der Modus „Sichern" heisst falsch.** Er ist seit heute der Startmodus und
zeigt zuerst den Bestand — „Sichern" beschreibt, was man zuletzt tut.
**Name offen** (Vorschlag: „Ablage" oder „Bestand"). *(Offen seit dem
Editor-Umbau.)*

**B5. 23 `.help()`-Hinweise sind am iPad unsichtbar** — dort gibt es kein
Verweilen mit dem Zeiger. *(Aus dem Umzug.)*

**B6. Im Editor fehlt die Nutzlastwarnung**, die es unter „Senden" gibt. Ein
langes Laufbild kann zu gross werden, und wo die Uhr aussteigt, weiss niemand
(Geraetereferenz §4.2a). *(Aus dem Editor-Durchgang.)*

---

## C — Editor: Groessen und Import

**C1. Erledigt (`07d8577`).** `Editorbestand.zielgroesse(fuer:)` entscheidet,
`einlesen` nimmt keine Groesse mehr entgegen; eine Fremdgroesse wird mit
Begruendung abgelehnt, und zwar **bevor** das Blatt aufgeht. Die Hilfe
behauptete bis dahin das Gegenteil und zieht mit.

**C2. Erledigt (`d6bcbb5`).** „Icon einfuegen" ist der eine Weg: bei 16×16 die
8×8-Icons, verdoppelt; bei 16×52 beide Icongroessen in ihrer Groesse, an der
Sendestelle (`Meldungsbau.iconY`). Gerechnet wird im Kern
(`Leinwandgroesse.aufnehmbar`/`einsatz(in:)`, `Leinwand.iconEinsetzen`).

**C3. Die Dreier-Umschaltung 8×8 / 16×16 / 16×52 gibt es bereits** seit der
Zusammenlegung. *(Erledigt — der Auftraggeber hatte den Stand noch nicht.)*

---

## D — Betriebsart der Uhr

**D1. Je Uhr HTTP oder MQTT, Vorgabe HTTP.** Ueber HTTP sind belegt: anlegen
(erscheint sofort), loeschen mit `{}`, umschalten, auflisten, dazu echte
Fehlercodes (404). Ueber MQTT gibt es davon nichts.

**D2. Ein Broker bleibt moeglich und dient dann als Ohr** — der Auftraggeber:
„wenn zusaetzlich ein broker angelegt wird, kann man ja ueber den erfolgte
http sendungen mitbekommen."
**Unbelegt und messbar:** ob die Uhr den **Inhalt** von HTTP-Anzeigen auf
`<praefix>/custom/#` weiterreicht oder nur die **Namen** ueber `customList`.
Davon haengt ab, ob die Bloecke im HTTP-Betrieb Bilder zeigen oder nur
Belegung. **Braucht Brokerzugang.**

**D3. `AppZustand.eingerichtet` verlangt heute Uhr *und* Broker.** Fuer eine
reine HTTP-Uhr ist das falsch.

**D4. Namensfalle:** Der Kurzbefehl-Parameter `weg` meint „als Pixel/als Text".
Die Betriebsart braucht deshalb ein anderes Wort — **„Betriebsart"**, nicht
„Weg". Ein Umbenennen von `weg` braeche jeden gespeicherten Kurzbefehl.

---

## E — Groesseres, eigene Durchgaenge

**E1. Ueber iCloud abgleichen — „ja alles":** Icons (8×8 und 16×16), Bilder,
**und die Einstellungen.** Als Option in den Einstellungen.

**Die schoene Nebenwirkung, die den Aufwand mittraegt:** Wandert auch das
**Slotgedaechtnis** mit, weiss das Telefon, was der Mac geschickt hat. Genau
darueber hat der Auftraggeber am Anfang dieses Vorhabens geklagt: *„wenn ich im
Buero bin kriegt mein handy nicht mit was in der Zwischenzeit auf die Uhr
daheim geschickt wird."* Das war der Anlass fuer den Mitleser und das
Slotgedaechtnis — ein Abgleich loest es an der Wurzel.

**Vier Entscheidungen, die daran haengen:**

1. **Was womit abgeglichen wird.** Dateien (Icons, Bilder, Slots) gehoeren in
   einen iCloud-Behaelter; Einstellungen liegen in `UserDefaults` und braeuchten
   `NSUbiquitousKeyValueStore` (1 MB, 1024 Schluessel). Zwei Mechanismen, nicht
   einer.
2. **Das Werkzeug liest die Einstellungen mit** (`mqtttc002`, `Einstellungen`
   im Kern, ausdruecklich nur lesend). Es laeuft ausserhalb der App — folgt es
   dem Abgleich, oder bleibt es auf dem oertlichen Bestand?
3. **Das Brokerkennwort liegt im Schluesselbund.** Ein Abgleich hiesse
   iCloud-Schluesselbund (`kSecAttrSynchronizable`) — ein eigener Mechanismus
   und eine eigene Entscheidung.
4. **Widerspruch zweier Geraete.** Zwei Installationen aendern dasselbe Icon:
   letzter gewinnt, oder Konfliktkopie?

**Das Risiko, das ernst zu nehmen ist:** Die Bestaende liegen heute unter
`Application Support`. Ein Abgleich heisst Umzug — und in diesem Projekt hat
ein Formatwechsel schon einmal beinahe alle Einstellungen unlesbar gemacht
(`EinstellungenTests.testUhrBleibtLesbar` ist seither das Netz). **Der Umzug
braucht einen Rueckweg**, nicht nur einen Hinweg.

**E1a. Gebaut am 14.09.2026 — es fehlt nur noch die Berechtigung.**

Sieben Stufen, alle gruen: `Ablageort` (eine Stelle entscheidet, wo die vier
Bestaende liegen), `Bestandsumzug` (Hinweg und Rueckweg, beide kopierend),
`Einrichtungsstand` (die Einstellungen als ein Schluessel, je Uhr
zusammengefuehrt), `Wolkenablage` (Protokoll vor `NSUbiquitousKeyValueStore`),
die Verdrahtung in `AppZustand`, der Abschnitt „iCloud" in den Einstellungen
(Mac und Telefon derselbe), die Hilfe.

**Umgezogen, nicht gespiegelt.** Ein Spiegel waere ein eigener Abgleichmotor
mit zwei Richtungen, Grabsteinen fuer Geloeschtes und eigener
Konfliktaufloesung; ein Behaelter ist dasselbe Ergebnis, nur macht es das
System. Der Umzug selbst **kopiert** in beide Richtungen — deshalb ist der
Rueckweg schon eingebaut.

**Das Werkzeug folgt, ohne es zu wissen.** Ein uebernommener Stand laeuft durch
dieselben `didSet`-Schreiber wie jede Aenderung von Hand und landet damit in
`UserDefaults`; `mqtttc002` liest weiter dort und faehrt iCloud nie an. Fuer
die Dateien reicht `Ablageort` — vorausgesetzt, `build.sh` signiert das
mitreisende Werkzeug mit denselben Berechtigungen (tut es, sobald
`TC002_ENTITLEMENTS` gesetzt ist).

**Was der Auftraggeber tun muss, in dieser Reihenfolge:**

1. **Behaelter anlegen.** In Xcode ein beliebiges Ziel oeffnen, „Signing &
   Capabilities" → „+ Capability" → **iCloud**, dort **iCloud Documents** und
   **Key-value storage** ankreuzen und den Behaelter
   `iCloud.cloud.eriks.mqtt-tc002` hinzufuegen (Team 25ZK4SS655). Das legt ihn
   im Entwicklerkonto an und erneuert das Bereitstellungsprofil.
2. **Die Aenderung in Xcode wieder wegwerfen.** Sie steht in der
   `.xcodeproj`, die nicht eingecheckt ist und beim naechsten
   `xcodegen generate` ohnehin ueberschrieben wird. Gebraucht wurde nur
   Schritt 1.
3. **In `project.yml` die eine Zeile entkommentieren:**
   `CODE_SIGN_ENTITLEMENTS: Resources/MQTT-TC002.entitlements`, dann
   `xcodegen generate`.
4. **iOS bauen und aufs Geraet laden.** Ein Simulatorbau gelingt auch ohne all
   das — er beweist also nichts; das Geraet ist die Probe.
5. **Mac:** das Profil als `.provisionprofile` laden und
   `TC002_PROFIL=<pfad> TC002_ENTITLEMENTS=Resources/MQTT-TC002.entitlements ./build.sh`.
6. **Probe:** In den Einstellungen muss der Schalter jetzt anzufassen sein und
   die Zeile darunter nicht mehr „nicht bereit" sagen. Einschalten, dann in
   iCloud Drive nach dem Ordner **MQTT-TC002** sehen — darin `Icons`,
   `Icons16`, `Bilder`, `Slots`.

**Noch ungeprueft, weil es ohne Behaelter nicht zu pruefen ist:** ob
`NSUbiquitousKeyValueStore` unter der Signatur wirklich traegt, wie lange ein
Umzug mit vollem Bestand dauert, und ob nicht materialisierte Dateien
(`.icloud`-Platzhalter) im Bestand fehlen, bis das System sie nachgeladen hat —
`Ablageort.herunterladenAnstossen()` stoesst das an, wartet aber nicht.

**E2. AWTRIX NG — entschieden: „statt", nicht „neben".** Eine Uhr ist entweder
eine TC002 oder eine AWTRIX; gemischte Ziele gibt es nicht. **Damit faellt die
schwerste Frage der Erhebung weg** — die Vorschau muss nie zwei Darstellungen
zugleich zeigen, und `ziele()` bleibt, wie es ist. Zuschnitt: Textweg (~1000
Zeilen, `.superpowers/sdd/awtrix/aufwand.md`).

### E2 — gebaut am 14.09.2026: der Nachrichtenweg steht

Was jetzt geht, wenn eine Uhr als AWTRIX NG eingetragen ist: **Text senden, Icon
senden, loeschen, umschalten, Belegung lesen, mitlesen** — ueber HTTP wie ueber
MQTT, auf den Themen und Routen von NG. Die Geraeteart stellt „Abfragen" selbst
fest (`GET /api/v1/device`, `boardType`) und traegt sie in die Uhr ein; von Hand
waehlbar ist sie in `VerbindungView` fuer den Fall, dass die Erkennung nicht
gelingt.

**Die Bauform in einem Satz:** `Meldungsbau.rahmen` haengt an jeden Rahmen seine
`Meldungsherkunft` (die Regler und das Icon), und `Anzeigen` entscheidet an einer
Stelle, ob daraus der Pixelrahmen der Werksfirmware oder die Textnutzlast von NG
wird. Damit koennen **App, Kommandozeilenwerkzeug und Kurzbefehle** an beide
Gattungen senden, ohne dass eine dieser drei Stellen davon weiss.

**Was NG mehr kann als die Werksfirmware — notiert, nicht gebaut:**

| Kann NG | Warum es hier nicht gebaut ist |
|---|---|
| Benachrichtigungen (`cmd/notify`), die die Schleife unterbrechen, mit Ton, `hold` und Warteschlange | Ein eigener Begriff neben den fuenf Plaetzen; danach hat niemand gefragt |
| Zeichenbefehle (`draw`: Linie, Kreis, Rechteck, Bitmap) unmittelbar in der Anzeige | Waere der Pixelweg auf 32×8 — Zuschnitt (B), ausdruecklich nicht gewaehlt |
| Balken- und Liniendiagramm, Fortschrittsbalken | Kein Gegenstueck in dieser App |
| 19 Hintergrundeffekte, 22 Uebergaenge, 6 Overlays, 8 Paletten | Dito; `GET /api/v1/capabilities` nennt sie, wenn es je gebraucht wird |
| Moodlight, die drei Randindikatoren, Audio (MP3, Melodien, Webradio) | Nichts davon hat die Werksfirmware |
| Berry-Skripte, Dateiablage, Sicherung, Firmware-Update | Weit ausserhalb |
| Reihenfolge und Sichtbarkeit der Anzeigen (`cmd/apps/order`) | Die App verwaltet fuenf feste Plaetze, keine Schleife |
| `cmd/screen/get` — ein Foto des Bildspeichers | Kostet ein sichtbares Umschalten der Uhr **je Block** und liefert ein Standbild aus einer Bewegung. Der Preis ist hoeher als der Gewinn |

**Was auf NG nicht geht, und wie die App es sagt:**

| | Wie es gesagt wird |
|---|---|
| Gemaltes Bild, Bild aus der Sammlung | `NGFehler.keinPixelweg` — eine Sendung ohne Regler wird **nicht abgeschickt**, die Meldung nennt 52 × 16 gegen 32 × 8 |
| 16 × 16-Icon | `NGFehler.iconZuHoch` — auf acht Zeilen kein Platz, und ein zu hohes GIF spielt auf NG **gar nicht** |
| PNG als Icon | `NGFehler.iconFormat` — NG liest nur GIF und JPEG und faellt sonst still auf „kein Icon" zurueck |
| Schriftart, Groesse, Fett, Rand, Zeichenabstand, senkrechte Ausrichtung | `Geraetetyp.wirkt(_:)` sagt nein, `Geraetetyp.begruendung(_:)` liefert den Satz fuer den Einblendtext |
| Rechtsbuendig | `Geraetetyp.waagrechteAusrichtungen` nennt nur `links` und `mittig` |
| Seitenwechsel, Scrolltempo | `/getConfig` gibt es bei NG nicht; der Abschnitt in `VerbindungView` sagt das, statt eine 404 als Fehler zu melden |
| Bild eines Slotblocks | `slotzustand` gibt auf NG `.unbekannt` statt eines aus dem Gedaechtnis gerechneten 52×16-Bildes in **unserer** Schrift |

**Die Masse kommen vom Geraet**, nicht aus einer Konstanten: `Uhr.panelbreite`
wird beim Abfragen aus `panelWidth × panels` geholt (32…128, alles andere gilt
als nicht beantwortet), die Hoehe ist bei NG fest 8. Wer rechnet, fragt
`Uhr.anzeigemass` — `Pixelfeld.breiteStandard/hoeheStandard` sind die Masse der
**Werksfirmware**.

**Was liegengeblieben ist** (fremde Dateien, oder es fehlt das Geraet):

1. **Die Regler in `SendenView`/`SendeniOS` sind noch nicht gesperrt.** Die
   Tabelle dafuer steht fertig im Kern (`Geraetetyp.wirkt`, `.begruendung`,
   `.waagrechteAusrichtungen`, `.iconKanten`) und ist mutationsgeprueft; es fehlt
   allein der Griff in den beiden Sendeansichten. Bis dahin lassen sich auf einer
   NG-Uhr Regler bewegen, die nichts bewirken.
2. **Malen und Bildersammlung sperren.** `MalenView`/`BilderBereichView` schicken
   heute und bekommen `NGFehler.keinPixelweg` zurueck — eine ehrliche Meldung,
   aber ein gesperrter Knopf waere besser als ein Fehler nach dem Druck.
3. **Vorschau und Slotblock rechnen weiter mit 52×16.** `Uhr.anzeigemass` liegt
   bereit; `VorschauView`, `VorschauiOS` und `Slotblock` gehoeren anderen
   Durchgaengen.
4. **`docs/awtrix-ng-protokoll.md` ist in keinem Buendel.** Dafuer sind `build.sh`
   und `project.yml` zu aendern (S12 der Aufwandsschaetzung) — und danach
   `sh scripts/buendel-pruefen.sh`, nicht der Compiler, ist der Beweis.
5. **Das Icon „ein bisschen nach rechts".** Der Auftraggeber woertlich: *„Das
   einzig spezielle ist, dass das Icon ein bisschen nach rechts rücken müsste."*
   NG reserviert dafuer eine 9-px-Spalte von selbst, und `iconOffsetX` schoebe das
   Icon **unter** den Text statt neben ihn. Wie viele Pixel richtig sind, laesst
   sich ohne Blick auf das Geraet nicht sagen — deshalb nicht geraten.
6. **Basic-Auth.** Steht `authEnabled`, antwortet die ganze Schnittstelle mit
   `401`; dann ist weder die Geraeteart noch das Praefix zu holen. Die App sagt
   das (`GeraetFehler.anmeldungNoetig`) und verweist auf die Wahl von Hand — mehr
   geht ohne Anmeldedaten nicht.
7. **Ein anderer `webPort`** ist bei NG einstellbar; `Geraet` setzt Port 80
   voraus. Unveraendert gegenueber der Werksfirmware, aber dort war es keine
   Einstellung.

**Unbelegt geblieben, weil das Hausnetz tabu war:** dass eine Sendung dieser App
auf `<P>/cmd/apps/pushed/<name>` das Geraet wirklich erreicht; dass ein Praefix
mit Schraegstrich als Kommandothema traegt; dass `textCase: "asTyped"` gegen das
global eingeschaltete `uppercase` gewinnt; wie die Werksfirmware auf
`/api/v1/device` antwortet (die Erkennung ruht darauf). Das Gegenmittel gegen die
gefaehrlichste dieser Unbekannten ist eingebaut: **`<P>/…/result` wird
mitabonniert** — bleibt die Antwort aus, hat das Thema keine Route getroffen.

**E2a. Ein eigener Geraeterahmen fuer die AWTRIX (32×8).**
Der heutige Rahmen ist gezeichnet, nicht fotografiert: `GeraeteRahmen.swift`
(66 Zeilen) haelt eine viewBox 680×356 mit dem schwarzen Feld bei x=48 y=93,
584×177, dazu die Schriftzuege „U-Clock TC002" und „Pixbar".

Vorlage des Auftraggebers: ein Bild der **Ulanzi TC001** — schwarzes Feld,
heller Kunststoffkoerper, duenner Rand ringsum. **Ausdruecklich frontal, nicht
schraeg.**

Seine eigene Einschaetzung, und sie stimmt: *„Mir ist klar, dass es dann
eigentlich nur ein duenner weisser Rand ist. Ich schlage vor zu schummeln und
wie beim jetzigen Simulator links unten ‚Ulanzi TC001' hinzuschreiben."*

**Drei Unterschiede zum TC002-Rahmen, die es wirklich gibt:**
1. **Rundere Ecken.**
2. **Keine Tasten oben** — der rote Knopf und die schwarze Leiste des
   TC002-Rahmens fallen weg.
3. Der Schriftzug „Ulanzi TC001" links unten.

Damit ist es mehr als eine Beschriftung: Die beiden Geraete sind auch ohne
Lesen auseinanderzuhalten. Der Schriftzug ist trotzdem noetig — frontal bleibt
ein schwarzes Feld mit hellem Rand fuer beide.

**Ebenfalls gezeichnet, im selben Stil** — kein Foto, keine zweite Bildsprache.
Der TC002-Rahmen ist heute reines SwiftUI; der AWTRIX-Rahmen wird es auch.

Und **eine** Zeichnung mit Geraetemassen, nicht zwei nebeneinander:
`GeraeteRahmen` rechnet heute mit festen Werten aus **einer** viewBox
(680×356, Feld x=48 y=93, 584×177). Die muessen zur Eigenschaft werden, nicht
zur Konstante — sonst steht bald dieselbe Zeichnung zweimal da und laeuft
auseinander. **Das ist in diesem Projekt schon passiert** (`slotzustand` gab es
dreimal, zweimal gleich und einmal abweichend — die abweichende war falsch).

Zu bedenken: Das Feld ist **32×8, also 4:1** gegenueber 52:16 = 3,25 — ein
anderes Seitenverhaeltnis, nicht nur andere Zahlen. Die Vorschau richtet den
Inhalt heute an der Feldhoehe aus und zentriert waagrecht; **pruefen, ob das
bei 4:1 noch traegt.**

**Die Pixel sind groesser und eckiger.** Groesser ergibt sich von selbst —
dieselbe Panelbreite durch 32 statt 52 macht jedes Pixel rund anderthalbmal so
breit. Eckiger ist eine Entscheidung: `Rasterbild` zeichnet heute schlichte
Rechtecke ohne Rundung und ohne Fuge; **such, wo die Vorschau im Geraeterahmen
ihre Pixel zeichnet**, und pruef, ob dort gerundet oder mit Abstand gezeichnet
wird. Am Vorbild sind es deutlich abgesetzte Quadrate mit sichtbarer Fuge —
das kommt daher, dass man bei 32 Spalten die einzelne Leuchtdiode sieht.

**E3. MQTT 5.** Gemessen, Bericht liegt, vom Auftraggeber auf spaeter gelegt.
Gewinn auf dem Hauptweg vom eigenen Mitleser aufgefressen; `0x10` traegt nur
dort, wo die App selbst nicht abonniert.

---

## F — Kleinkram

**F1. Erledigt:** Der Schluesselbund kommt als `Schluesselbundzugriff` ueber
ein Vorgabeargument in `AppZustand.init` herein (`1a3c5e5`), die Modelltests
geben durchweg einen Doppelgaenger mit. Belegt mit einem Stolperdraht:
`Schluesselbund.lesen/setzen/loeschen` voruebergehend auf `fatalError`
gesetzt, `swift test` blieb gruen — kein Testweg faehrt den echten mehr an.

**F1a. Zwei Tests fassen den echten Schluesselbund weiter an**, und zwar mit
Absicht: `SchluesselbundTests` prueft den Wrapper selbst,
`testKennwortWirdErstBeiBedarfGelesen` die Traegheit von
`Einstellungen.kennwort`. Beide schreiben ihren Eintrag vorher selbst, unter
einem Wegwerfkonto — kein Dialog, nie das Kennwort des Nutzers, aber eben
doch der Schluesselbund des Rechners. Wer das ganz zumachen will, braucht
einen zweiten Wrapper oder eine Kennzeichnung, die diese beiden vom
Standardlauf ausnimmt. **Nicht geaendert**: Sie pruefen genau das, was sonst
niemand prueft.

**F2. Werkzeug und Kurzbefehle sehen nur den 8×8-Bestand.** Ein selbstgemaltes
16×16 ist von dort nicht erreichbar.

**F3. Ein vermischter Commit.** `a2306a5` traegt eine Doku-Nachricht, enthaelt
aber auch die zweite Stufe der Kurzbefehle — ein `commit -a` des
Parallelagenten hat den fremden Index eingesammelt. Inhalt vollstaendig in
`main`. **Nicht repariert**: Historie umzuschreiben, waehrend andere auf
denselben Zweig committen, ist gefaehrlicher als eine schiefe Nachricht.

**F5. Zwei Haupthandlungen im Editor.** „Sichern" **und** „Senden" tragen
beide `keyboardShortcut(.defaultAction)` (`EditorBereichView`). Bei 16×52
stehen damit zwei Knoepfe auf der Eingabetaste; welcher gewinnt, entscheidet
SwiftUI. **Gesehen am 13.09.2026, nicht behoben** — welcher von beiden die
Eingabetaste bekommen soll, ist eine Entscheidung, keine Ableitung.

**F6. `SendenView.sendeKnopf` uebersetzt nicht.** Dort steht ein Ternaer mit
zwei blanken `String`-Zweigen; SwiftUI nimmt die `StringProtocol`-Ueberladung,
und die schlaegt nichts nach. Abhilfe ist `lok(…)` in beiden Zweigen, wie im
gleichnamigen Knopf des Editors. **Gesehen am 13.09.2026, nicht behoben.**

**F4. Erledigt:** „LaMetric hinzufuegen" war nur bei 8×8 sichtbar und lag im
Modus „Sichern" — beides behoben (`8c43725`), die Handlungen am Bestand haengen
nicht mehr an der Leinwandgroesse.
