# Einstellungen: kein „Sichern"-Knopf, Kennwort als vorhanden erkennbar

**Gewicht: 8 von 10.**

## Was heute geschieht

`TC002Ansichten/VerbindungView.swift`, Abschnitt „Broker" (166–211): vier
Felder (Adresse, Port, Benutzer, Kennwort), darunter der Knopf **„Sichern
und prüfen"** mit dem Stand „noch nicht geprüft" daneben (207, 281). Das
Kennwort wandert beim Verlassen des Feldes von selbst in den
Schluesselbund (200–202, `onDisappear` 232).

Zwei Dinge daran:

1. **Ein Sichern-Knopf in Einstellungen ist ein Web-Formular.** Apples
   Einstellungen sichern beim Aendern; ein Knopf, der „Sichern" heisst,
   sagt dem Anwender, dass ohne ihn nichts gilt — und laesst ihn raten, ob
   die anderen Schalter auf dem Bildschirm auch erst nach einem Druck
   gelten.
2. **Das leere Kennwortfeld sieht aus, als waere keines gesetzt.** Es ist
   leer, weil das Kennwort traege gelesen wird und nicht angezeigt werden
   soll (richtig so) — aber die Fussnote „liegt im Schluesselbund" erklaert
   nur, wo es waere, nicht ob es da ist.

## Was gelten soll

- **Zu pruefen zuerst:** Binden Adresse, Port und Benutzer direkt an
  `zustand` (dann sichern sie schon beim Tippen, und der Knopf sichert
  nichts, was nicht schon gesichert waere) oder in Zwischenwerte? Das
  entscheidet, ob `brokerSichernUndPruefen` einen Sicherungsteil hat.
  Ergebnis als Satz in den Kommentar am Knopf.
- **Der Knopf heisst „Verbindung prüfen"** und tut nur das. Was zu sichern
  ist, wird beim Verlassen des Feldes gesichert — wie das Kennwort heute
  schon. Der Stand daneben („verbunden", „keine Antwort", „noch nicht
  geprüft") bleibt.
- **Kennwort vorhanden = sichtbar vorhanden:** Das `SecureField` bekommt
  als `prompt` „••••••••" (oder `lok("gespeichert")`), wenn im
  Schluesselbund eines liegt, sonst „Kennwort". Dafuer braucht die Ansicht
  eine Auskunft `zustand.kennwortVorhanden: Bool`, die den Schluesselbund
  **nicht** liest (`Einstellungen.kennwort` ist traege, weil das Lesen
  fragt) — nur nachsieht, ob ein Eintrag existiert, oder sich beim letzten
  Sichern gemerkt hat, dass einer geschrieben wurde. Was die Schluesselbund-
  API dafuer hergibt, ohne den Dialog auszuloesen, prueft der Bearbeiter
  und schreibt es an die Stelle.
- **Der obere Rand:** Auf dem iPad beginnt die erste Karte („Verlauf
  führen") buendig unter der Werkzeugleiste, ohne Luft. Der Formularstil
  `.grouped` bringt am Mac Luft mit; am iPad fehlt sie —
  `.contentMargins(.top, …, for: .scrollContent)` wie unten (223) auch
  oben, Wert im Simulator ablesen.

## Abnahme

- Bildschirmfoto iPad: kein Knopf mit „Sichern" im Wort; Kennwortfeld
  zeigt Punkte, wenn eines gespeichert ist.
- Adresse aendern, Ansicht verlassen, zurueckkommen: Adresse steht noch.
- Schluesselbund fragt beim Aufschlagen der Einstellungen **nicht**
  (Test gegen einen Doppelgaenger von `Einstellungen`, der zaehlt, wie oft
  gelesen wird — `EinstellungenTests` hat die Vorlage).
- Die Hilfe (Einstellungen → Broker) beschreibt den neuen Knopf.

## Nicht anfassen

Die Uhrenliste darueber, `Wolkenabschnitt`, die virtuelle Uhr.
