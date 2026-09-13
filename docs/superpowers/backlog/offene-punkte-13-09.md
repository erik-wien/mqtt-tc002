# Offene Punkte, Stand 13.09.2026 abends

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

**E2. AWTRIX NG — entschieden: „statt", nicht „neben".** Eine Uhr ist entweder
eine TC002 oder eine AWTRIX; gemischte Ziele gibt es nicht. **Damit faellt die
schwerste Frage der Erhebung weg** — die Vorschau muss nie zwei Darstellungen
zugleich zeigen, und `ziele()` bleibt, wie es ist. Zuschnitt: Textweg (~1000
Zeilen, `.superpowers/sdd/awtrix/aufwand.md`).

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
