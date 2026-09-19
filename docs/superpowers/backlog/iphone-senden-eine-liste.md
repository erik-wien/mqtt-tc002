# iPhone Senden: der ganze Bildschirm ist eine Liste

**Gewicht: 1 von 10.** Das ist der eine Befund, der die Ansicht unfertig
aussehen laesst.

## Was heute geschieht

Auf dem iPhone steht zwischen der Slotleiste und der Ueberschrift „Auf der
Uhr und zuletzt geschickt" ein Drittel des Bildschirms leer, und unter der
Ueberschrift noch einmal so viel; die drei Verlaufszeilen kleben am unteren
Rand ueber der Formatpille.

Ursache: `SendeniOS.swift`, `mitte` (Zeilen 458–479). Eine `ScrollView`
enthaelt Vorschau, Punktreihe, Slotleiste und dann `Verlaufsliste` mit
`.frame(height: 260)`. `Verlaufsliste` (`TC002Ansichten/Verlaufsliste.swift`,
105–134) ist selbst eine `List(zeilen)` mit `.listStyle(.plain)` und einer
Ueberschrift darueber. Eine `List` in einer `ScrollView` bekommt keine
eigene Hoehe, deshalb der feste Rahmen — und eine `List` mit wenigen Zeilen
in einem zu hohen Rahmen verteilt den Rest als Leere. Zwei ineinander
rollende Bereiche sind ausserdem am Finger nicht auseinanderzuhalten.

Die 260 stehen mit Begruendung im Kommentar („Feste Hoehe, weil eine Liste in
einem Scrollbereich sonst keine eigene bekommt") — die Begruendung ist
richtig, die Folgerung falsch: Nicht die Liste braucht eine Hoehe, die
ScrollView ist zu viel.

## Was gelten soll

Der Bildschirm zwischen Werkzeugleiste und Formatpille ist **eine** `List`,
so wie Mail, Nachrichten und Einstellungen ihre Bildschirme bauen:

1. Erste Zeile: `Uhrenblaetterer` mit der Vorschau und `Uhrenpunkte`
   darunter — ohne Trennlinie (`.listRowSeparator(.hidden)`), ohne
   Zeilenhintergrund (`.listRowBackground(Color.clear)`), mit
   `.listRowInsets` so, dass die Vorschau wie heute an den Rand kommt.
2. Zweite Zeile: die Slotleiste (`blockZeile`), ebenso ohne Trennlinie.
   Die Zeile „Laeuft durch: N Einzelbilder" bleibt daran gebunden wie heute.
3. Dann die Verlaufszeilen als `Section` mit der Ueberschrift „Auf der Uhr
   und zuletzt geschickt" als `header:` — nicht als eigene `Text`-Zeile.
   Die Zeilen selbst, Wisch-Aktionen und der Druck darauf bleiben, wie sie
   in `Verlaufsliste` stehen.

Kein `.frame(height:)` mehr. Wenig Verlauf heisst wenig Zeilen und darunter
nichts; viel Verlauf rollt mit der Vorschau nach oben weg, wie eine
Nachrichtenliste.

`Verlaufsliste` wird dafuer so umgebaut, dass sie ihre Zeilen **in eine
bestehende `List` liefert** statt selbst eine zu sein — etwa als
`Verlaufsabschnitt: View`, das eine `Section` zurueckgibt und in einer `List`
des Aufrufers steht. Der Mac (`SendenView.swift`) benutzt dieselbe
`Verlaufsliste`; dort steht sie heute unter den Bloecken in der freien
Flaeche des Fensters und darf eine eigene `List` bleiben — die Datei kennt
dann beide Formen, mit einem Satz dazu, warum: Am Mac ist die Vorschau kein
Listeneintrag, sie hat die Werkzeugleiste ueber sich und den Inspektor
neben sich.

## Abnahme

- Bildschirmfoto iPhone 17 (Simulator) mit drei Verlaufszeilen: keine leere
  Flaeche zwischen Slotleiste und Ueberschrift, keine zwischen Ueberschrift
  und erster Zeile.
- Dasselbe mit null Verlaufszeilen: Slotleiste, darunter nichts, kein Rahmen,
  keine Ueberschrift.
- Dasselbe mit zwanzig Zeilen: Der Bildschirm rollt als Ganzes; die Vorschau
  verschwindet nach oben.
- Wischen ueber der Vorschau wechselt weiterhin die Uhr (die waagrechte
  Geste des `Uhrenblaetterers` liegt in einer senkrecht rollenden Liste —
  im Simulator pruefen, dass beides geht).
- Ein Druck auf eine Verlaufszeile uebernimmt weiter die Regler; Wischen nach
  links loescht, nach rechts „Zeigen" bei Fremdanzeigen.
- Am Mac aendert sich nichts Sichtbares (Bildschirmfoto vorher/nachher).

## Waechter, die sich melden werden

`EinblendtextGegenstueckTests.testSendenView…` und Tests, die
`Verlaufsliste(` oder `.frame(height: 260)` im Quelltext suchen — nachsehen
mit `grep -rn "Verlaufsliste\|height: 260" Tests/`.

## Nicht anfassen

Die Zeilen selbst (das ist Papier 2), die Formatpille (Papier 5), der Mac.
