# Kleinigkeiten: der Chip „belegt" und der Uhrenname im Titel

**Gewicht: 6 von 10.** Zwei kleine Stellen, ein Commit je Stelle.

## A. Der Chip „belegt"

`TC002Ansichten/Slotblock.swift:93`: Ein Slot, auf dem etwas liegt, das die
App nicht kennt (`.unbekannt`), zeigt einen grauen Block mit dem Wort
„belegt" in `caption`. Das Wort in einem Kaestchen von 44 Punkten Hoehe
wirkt roh — ein Etikett, wo sonst Bilder stehen.

**Soll:** Der Block bleibt grau gefuellt, aber ohne Wort; stattdessen ein
Muster, das „da ist etwas, wir wissen nicht was" sagt — ein feines
diagonales Schraffur-`Canvas` oder das Zeichen `questionmark` in
`.tertiary`, mittig. Der Zustand bleibt fuer die Sprachausgabe „Slot 2,
belegt" (Zeile 116) — das Wort geht nur aus dem Bild, nicht aus der
Auskunft. `.help(lok("belegt — von einer anderen Quelle"))` am Mac.

Abnahme: Bildschirmfoto der Slotleiste mit einem unbekannten Slot; er ist
von leer (gestrichelt) und eigen (Motiv) auf einen Blick zu unterscheiden.
Waechter: `LaufbehauptungTests`, `EinblendtextGegenstueckTests` —
`grep -rn "belegt" Tests/`.

## B. Der Name der Uhr im Titel

Der Titel des iPhone-Bildschirms lautet `<Name der Uhr> · an 4 Uhren`
(`SendeniOS.swift:391–394`, `lokf("%@ · an %d Uhren", uhr.name, …)`). Auf
dem Foto des Auftraggebers ist der Name der Praefix-String der Uhr
(`hersteller_xxxx`), weil die Uhr so benannt wurde — vermutlich, weil beim
Anlegen der Hostname oder das Praefix als Name vorgeschlagen wird.

**Zu klaeren, bevor gebaut wird:** Woher kommt der Vorschlag fuer
`Uhr.name` beim Anlegen (`VerbindungView.swift`, `VerbindungiOS.swift`,
`AppZustand.uhrAnlegen` o. ae.)? Wenn dort Praefix oder Hostname als Name
vorbelegt wird: Vorbelegung auf einen sprechenden Vorschlag aendern („Uhr
1", „Uhr 2" — oder leer mit Platzhalter „Name, z. B. Küche"), und der
Titel nimmt weiterhin `uhr.name`. Das Praefix bleibt in der Kennzeile der
Einstellungen (`kennzeile`), wo es hingehoert.

Wenn der Name vom Auftraggeber selbst so getippt wurde: nichts zu tun,
und dieses Papier B wird mit dem Vermerk geschlossen.

Abnahme: Neue Uhr anlegen ohne Namen zu tippen — der Titel zeigt keinen
Praefix-String. Tests in `Tests/TC002ModellTests` fuer die Vorbelegung, falls
sie sich aendert.
