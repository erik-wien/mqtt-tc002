# Hilfeschuld aus der Bahn „Senden" (UX-Runde 19.09.)

Die Bahn „Senden" der UX-Runde hat die Hilfe nicht angefasst — sie macht zum
Schluss ein eigener Durchgang. Was dabei nachzuziehen ist, steht hier: je
Punkt der betroffene Absatz, was daran jetzt falsch ist, und wie er lauten
soll.

Die Dateien der Hilfe sind `Sources/TC002Ansichten/HilfeInhalt.swift`
(gemeinsam), `Sources/TC002Ansichten/HilfeView.swift` (Mac/iPad) und
`Sources/TC002iOS/HilfeiOS.swift` (iPhone).

---

## 1. `HilfeInhalt.verlaufHerkunft`, erster Absatz — die Zeile zeigt anderes

**Steht da:** „… die eigenen Sendungen mit allem, was dazugehört — Zeit,
Platz, Icon, Text in seiner Farbe, Empfänger —, und das, was sonst noch auf
der angesehenen Uhr liegt."

**Falsch daran:** Die Aufzählung nennt die alte Reihenfolge und das alte
Icon. Die Zeile steht jetzt in der Reihenfolge der Auskunft — was, an wen,
wann: vorn das Icon als **Bild** (nicht als Nummer), daneben der Text in
seiner Farbe, darunter die Empfänger, rechts Zeit und Platz. Die Empfänger
stehen nur da, wenn mehr als eine Uhr eingerichtet ist; bei einer einzigen
wäre ihr Name in jeder Zeile dasselbe Wort. Hat eine Sendung keinen Text,
steht dort der Name des Icons.

**Soll lauten:** „… die eigenen Sendungen: vorn das Icon als Bild, daneben
der Text in der Farbe, in der er geschickt wurde, darunter die Empfänger,
rechts Zeit und Platz. Eine Sendung ohne Text nennt stattdessen den Namen
ihres Icons. Bei nur einer eingerichteten Uhr bleibt die Zeile mit den
Empfängern weg — und dazu das, was sonst noch auf der angesehenen Uhr liegt."

---

## 2. Das Löschen am Block — das ⊗ steht nicht mehr da

**Steht da:** nichts Ausdrückliches zum Löschen eines Platzes; die Hilfe
beschreibt es nur über die Wischgeste in der Liste darunter
(`HilfeInhalt.verlaufHerkunft`, dritter Absatz — der Satz bleibt richtig).

**Falsch daran:** Das rote ⊗ an jedem belegten Block gibt es nicht mehr. Wer
es aus der Hilfe kennt, sucht es. Gelöscht wird jetzt über das Menü des
Blocks; am Schreibtisch erscheint das ⊗ zusätzlich, solange der Zeiger über
dem Block steht.

**Soll dazukommen** in `HilfeInhalt`, im Abschnitt „Senden" beim Absatz über
die fünf Blöcke (gilt für beide Oberflächen): „Ein langer Druck auf einen
belegten Block öffnet sein Menü: „Zeigen" schaltet die Uhr auf diese
Meldung um, „Löschen" räumt den Platz. Am Schreibtisch zeigt der Block
zusätzlich ein ⊗, sobald der Zeiger darüber steht — am Finger gibt es kein
Überfahren, und ein Zeichen, das immer dasteht, sähe aus wie der
Wackelmodus des Home-Bildschirms."

---

## 3. Näherung und Nutzlast stehen woanders

**Steht da:** `HilfeView`, Abschnitt „Senden": der Absatz zur Nutzlastgröße
und der zur NG-Vorschau beschreiben zwei Zeilen unter der Vorschau.

**Falsch daran:** Unter der Vorschau steht kein Satz mehr. Setzt die
angesehene Uhr den Text selbst, hängt die Erklärung an einem (?) neben der
Punktreihe — am Zeiger im Einblendtext, am Finger als Blase; das gilt jetzt
für beide Oberflächen, das iPhone hatte diese Auskunft vorher gar nicht. Wie
groß die nächste Nutzlast wird, steht als Einblendtext am ⏎ im Eingabefeld.
Sichtbar unter der Vorschau bleibt allein die Warnung über der Schwelle.

**Soll lauten:** „Setzt die angesehene Uhr den Text selbst (AWTRIX NG), ist
die Vorschau nur eine Näherung; das (?) neben der Punktreihe sagt, warum.
Wie groß die nächste Nutzlast wird, steht am ⏎ im Eingabefeld — es ist die
Antwort auf „was passiert, wenn ich drücke". Wird sie auffällig groß, sagt
es eine Zeile unter der Vorschau von selbst."

---

## 4. Die Formatpille — Reihenfolge und Schriftmenü

**Steht da:** `HilfeiOS`, Absatz zur Formatpille.

**Falsch daran:** Die Reihenfolge ist jetzt nach Häufigkeit geordnet: Icon,
Schrift, Größe, Fett, Großbuchstaben, Farbe — die sechs sind ohne Schieben
erreichbar —, dahinter die Ausrichtungen, Rand und Abstand, ganz hinten das
Formatblatt und das Bild aus dem Bestand. Die Schriftwahl trägt ein Zeichen
mit ihrem Wert daneben, wie die Größe, statt des Namens als blankem Wort.
Der rechte Rand blendet aus, statt hart zu enden; den Pfeil, der dasselbe
noch einmal sagte, gibt es nicht mehr.

**Soll lauten:** „In der Pille über dem Eingabefeld steht links, was man am
häufigsten ändert: Icon, Schrift, Größe, Fett, Großbuchstaben, Farbe.
Dahinter die Ausrichtungen, Rand und Abstand, und ganz hinten das
Formatblatt (Dauer, Lauftempo, mitlaufendes Icon) und das Bild aus dem
Bestand. Wo die Pille am rechten Rand ausblendet, geht es weiter — dort
schieben."
