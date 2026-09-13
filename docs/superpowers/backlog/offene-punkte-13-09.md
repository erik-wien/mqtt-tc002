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

**A4. Der Zwischendialog beim Dateihinzufuegen ist haesslich**, und man
erkennt nicht, dass dort **LaMetric-Nummer und Titel** einzutragen sind.

**Dazu ein Vorschlag des Auftraggebers, der die Eingabe meist ganz erspart:**
Beginnt der Dateiname mit `<Nummer>_<Titel>`, wird er automatisch getrennt —
aus `2981_Severe TStorm.gif` also Nummer `2981`, Titel `Severe TStorm`.

Heute wird der ganze Dateiname **in beide Felder** vorbelegt
(`EditorBereichView`, `importNummer = basis; importName = basis`) — bei einer
solchen Datei steht die Nummer also zweimal falsch da.

Zu bedenken: Bei **16×16 und 16×52 gibt es keine Nummer**; der Dialog muss sich
nach der Groesse richten, nicht nach einer festen Form. Und was geschieht, wenn
die Nummer schon vergeben ist — sie muss eindeutig sein.

**A5. Ein 16×16-Icon stellt die Regler nicht wieder her.** `Slotgedaechtnis`
rechnet die Pruefsumme mit Kante 8; bei 16 beginnt der Text erst bei Spalte 18.
Braucht ein Feld `iconKante` im `Slotstand` — das ist ein Dateiformat.
*(Aus dem Editor-Durchgang.)*

---

## B — Oberflaeche

**B1. Schaltflaechen muessen als solche erkennbar sein.** Grauer abgerundeter
Kasten ohne Rahmen, beim Klicken dunkler, beim Ueberfahren hervorgehoben,
Schrift schwarz. **Das ist eine durchgaengige Stilentscheidung**, nicht eine
Stelle — sie betrifft Mac und iPad ueberall. *(Neu gemeldet.)*

**B2. „Datei einlesen" heisst „Oeffnen".** *(Neu gemeldet.)*

**B3. „Abspielen" weg, dafuer ein Wiedergabesymbol rechts neben den Sekunden.**
*(Neu gemeldet.)*

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

**C1. Import behaelt die Quellgroesse**, statt auf die eingestellte zu rechnen.
**Eine Fremdgroesse (32×32, 104×32) wird abgelehnt** — entschieden am
13.09.2026. Also: 8×8, 16×16 und 16×52 werden aufgenommen, alles andere weist
die App **mit Begruendung** zurueck („Das Bild ist 32×32. Aufgenommen werden
8×8, 16×16 und 16×52."), statt stillschweigend zu rechnen.
Grund: Herunterrechnen zerstoert, und es geschah bisher unsichtbar — genau
daran ist der Auftraggeber mit seinen `maze`-GIFs haengengeblieben.
*(Eigener Eintrag: `editor-groessen-und-import.md`.)*

**C2. Hochrechnen 8×8 → 16×16 als eigene Funktion**, und zwar **bei „Icon
einfuegen"** — praezisiert gegenueber dem ersten Eintrag.

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

**E2. AWTRIX NG.** Erhebung liegt (`~1000 Zeilen Textweg`). **Offen: neben oder
statt der TC002?** Bei gemischten Zielen kann die Vorschau nur eine von zwei
Darstellungen zeigen.

**E3. MQTT 5.** Gemessen, Bericht liegt, vom Auftraggeber auf spaeter gelegt.
Gewinn auf dem Hauptweg vom eigenen Mitleser aufgefressen; `0x10` traegt nur
dort, wo die App selbst nicht abonniert.

---

## F — Kleinkram

**F1. Der Schluesselbund in den Tests.** `AppZustand.init` liest ihn; ein
Testlauf kann einen Dialog aufziehen, und einmal stand ein Kennwort im
Klartext in der Fehlerausgabe. Naht wie bei `gedaechtnis:` und `sitzung:`.
*(Zugesagt, noch offen.)*

**F2. Werkzeug und Kurzbefehle sehen nur den 8×8-Bestand.** Ein selbstgemaltes
16×16 ist von dort nicht erreichbar.

**F3. Ein vermischter Commit.** `a2306a5` traegt eine Doku-Nachricht, enthaelt
aber auch die zweite Stufe der Kurzbefehle — ein `commit -a` des
Parallelagenten hat den fremden Index eingesammelt. Inhalt vollstaendig in
`main`. **Nicht repariert**: Historie umzuschreiben, waehrend andere auf
denselben Zweig committen, ist gefaehrlicher als eine schiefe Nachricht.

**F4. Erledigt:** „LaMetric hinzufuegen" war nur bei 8×8 sichtbar und lag im
Modus „Sichern" — beides behoben (`8c43725`), die Handlungen am Bestand haengen
nicht mehr an der Leinwandgroesse.
