# Hilfe-Nachzug: Editor und Icons

> **Erledigt.** Beide Punkte waren schon eingeloest, als dieser Durchgang
> begann; nachgeprueft am Quelltext von heute. Was dabei zusaetzlich auffiel,
> steht in `hilfe-nachzug-umformen.md`.

Die Bahn „Editor und Icons" der UX-Runde vom 19.09. aendert die Bedienung, die
Hilfe aber nicht — sie macht zum Schluss ein eigener Durchgang. Hier steht,
was dabei nachzuziehen ist: je Punkt der betroffene Absatz, was daran jetzt
falsch ist, und wie er lauten soll.

Betroffen ist nur `Sources/TC002Ansichten/HilfeView.swift` (Schreibtisch);
`HilfeInhalt.swift` und `HilfeiOS.swift` sagen zu diesen Stellen nichts. Jeder
geaenderte Wortlaut braucht seinen Eintrag in
`Resources/Sprachen/en.lproj/Localizable.strings`, der alte wird dort
gestrichen.

## 1. Der Einzelbildstreifen steht nicht mehr im Inspektor (Nr. 7A)

**Absatz:** Abschnitt „Icons", Ueberschrift „Animation", erster Absatz — „Ein
Bild kann aus mehreren Einzelbildern bestehen; … **Der Streifen im Inspektor
zeigt alle**, das gerade bearbeitete hervorgehoben; ein Klick darauf schaltet
die Leinwand um. …"

**Falsch daran:** Der Streifen steht unter der Leinwand und nicht mehr im
Reiter „Animation". Wer der Hilfe folgt, oeffnet den Inspektor und findet dort
nur noch „Bild anhaengen" und die Verzoegerung.

**Soll lauten:** „Ein Bild kann aus mehreren Einzelbildern bestehen; das ergibt
beim Sichern ein animiertes GIF, das in Schleife läuft. Der Streifen unter der
Leinwand zeigt alle, das gerade bearbeitete hervorgehoben; ein Klick darauf
schaltet die Leinwand um. Er steht nur da, wenn es mehr als ein Einzelbild
gibt. „Bild anhängen" im Reiter „Animation" hängt ein leeres an und schaltet
die Leinwand gleich darauf um."

## 2. „Alles löschen" steht nicht mehr in der Karte „Werkzeug" (Nr. 7C)

**Absatz a:** Abschnitt „Icons" — „Gemalt wird mit gedrückter Maustaste oder
mit dem Finger. Im Inspektor stellt „Farbe" den Systemfarbwähler, „Stift"
schaltet zwischen Malen und Radieren um, und „Alles löschen" leert das gerade
bearbeitete Einzelbild — nicht die anderen."

**Falsch daran:** Der Satz stellt „Alles löschen" neben die zwei Werkzeuge, wo
es nicht mehr steht. Es ist die letzte Zeile des Reiters „Malen".

**Soll lauten:** „Gemalt wird mit gedrückter Maustaste oder mit dem Finger. Im
Inspektor stellt „Farbe" den Systemfarbwähler und „Stift" schaltet zwischen
Malen und Radieren um. Ganz unten im Reiter „Malen" steht „Alles löschen"; es
leert das gerade bearbeitete Einzelbild — nicht die anderen — und
„Rückgängig" holt es zurück."

**Absatz b:** Abschnitt „Senden" — „… Es und „Alles löschen" **im Inspektor**
nicht verwechseln: „Alles löschen" leert die Leinwand, das ⊗ löscht die
Anzeige auf der Uhr."

**Falsch daran:** Nur die Ortsangabe; sie stimmt noch, ist aber ungenau
geworden.

**Soll lauten:** „… Es und „Alles löschen" im Reiter „Malen" nicht
verwechseln: …" (Rest unverändert).

**Nicht zu ändern:** Der Absatz „Ein Strich ist ein Schritt, nicht ein Pixel:
… Je ein Schritt sind außerdem „Alles löschen", …" bleibt richtig — der Knopf
legt weiterhin einen Schritt auf den Rückgängig-Stapel.
