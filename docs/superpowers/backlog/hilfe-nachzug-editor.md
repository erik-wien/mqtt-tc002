# Hilfe-Nachzug: Editor und Icons

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
