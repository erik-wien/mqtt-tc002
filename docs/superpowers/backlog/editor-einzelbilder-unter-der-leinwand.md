# Editor: Einzelbilder unter der Leinwand, Abspielzeichen mit Kontrast, „Alles loeschen" aus der Werkzeugkarte

**Gewicht: 7 von 10.** Drei Stellen an derselben Ansicht, drei Commits.

## A. Der Einzelbildstreifen gehoert unter die Leinwand

**Heute:** Eine Animation mit 16 Bildern zeigt auf der Leinwand ein
Bild und rechts unten ein Abspielzeichen — dass es 16 sind, steht nur in
der Fusszeile („Animation · 16 Bilder") und im Inspektor unter dem
Reiter „Animation" (`EditorBereichView.swift`, `animationAbschnitte`
657–660, `einzelbildstreifen` 837). Wer den Reiter nicht oeffnet, sieht
keine Animation, nur ein Bild mit Play-Knopf.

**Soll:** Der Streifen steht **unter der Leinwand**, waagrecht rollend,
das gewaehlte Bild hervorgehoben — so zeigen Fotos (Bearbeiten), Procreate
und jeder Videoschnitt ihre Bilder: am Werkstueck, nicht in einem Reiter.
Er erscheint nur bei mehr als einem Bild; bei einem Bild bleibt die
Fusszeile, wie sie ist. Das Kontextmenue je Bild (Verdoppeln, Entfernen,
Nach vorn, Nach hinten) und das Antippen zum Waehlen bleiben, wie sie im
Streifen heute stehen. Der Reiter „Animation" im Inspektor behaelt
Verzoegerung und „Bild anhaengen" (das darf zusaetzlich auch als `+` am
Ende des Streifens stehen — ein Weg im Bild, einer im Inspektor, dieselbe
Funktion).

**Abnahme:** Bildschirmfoto iPad mit einer 16-Bild-Animation: Streifen
sichtbar, ohne den Inspektor zu oeffnen; Waehlen eines Bildes tauscht die
Leinwand; das kleine Abspielzeichen neben „Bild anhaengen" bleibt.
Waechter: `EinblendtextGegenstueckTests.testEinzelbildKnoepfeHabenEinKontextmenue`
sucht den Streifen per `ausschnitt(…, von: "private var einzelbildstreifen")`
— bleibt gueltig, wenn der Name bleibt.

## B. Das Abspielzeichen hat auf dunklem Raster keinen Kontrast

**Heute:** `abspielknopf` (696–704), `play.circle` in `.light`, Stil
`.plain`, Farbe `primary` — schwarz auf dem dunklen Bild, auf einem
schwarzen Motiv unsichtbar.

**Soll:** Wie AVKit und Fotos: **weiss auf einer dunklen, halbdurch-
sichtigen Scheibe** — `Circle().fill(.black.opacity(0.45))` als
Hintergrund, Zeichen `play.fill` in `.white`, oder ein
`.ultraThinMaterial`-Kreis. Groesse wie heute (`abspielGross`,
`abspielKlein`). Das kleine Zeichen neben „Bild anhaengen" bleibt in
`secondary` — es liegt auf dem Inspektor, nicht auf dem Bild.

**Abnahme:** Bildschirmfotos auf einem schwarzen und einem weissen 8×8:
Zeichen in beiden Faellen zu erkennen.

## C. „Alles loeschen" ist kein Werkzeug

**Heute:** In der Karte „Werkzeug" stehen Farbe, Pinsel/Radierer und
darunter ein rot getoenter Knopf „Alles löschen" (619). Eine zerstoerende
Handlung zwischen den Werkzeugen, in Warnfarbe, dauerhaft sichtbar.

**Soll:** Raus aus der Karte. Zwei systemuebliche Orte, einer davon:
- als letzte Zeile des Inspektors, rot, ohne Fuellung — so stehen
  „Alle Daten loeschen" in Einstellungen;
- oder in einem `Menu` mit `ellipsis.circle` in der Werkzeugleiste des
  Editors, neben Rueckgaengig/Wiederherstellen, mit `role: .destructive`.
Die Rueckfrage bleibt (ist heute ueber `schritt()` rueckgaengig machbar —
das darf so bleiben und erspart die Rueckfrage; im Kommentar festhalten).

**Abnahme:** Werkzeugkarte enthaelt nur Farbe und Pinsel/Radierer;
„Alles löschen" erreichbar, per Rueckgaengig zurueckholbar. Waechter:
`KnopfstilTests` (`.knopfBefehl()`-Ledger), `grep -rn "Alles löschen" Tests/`.
