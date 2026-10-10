# Freigabe: Darstellung — Hintergrund, Effekt, Overlay, Palette, Grafik, Fortschritt (10.10.2026)

Mockup: `2026-10-10-darstellung.html` (Sprint 4). Grundlage: `docs/awtrix-ng-protokoll.md` §5.5. Status: **freigegeben** (Erik, 10.10.2026), mit den Änderungen unter „Entscheidung“.

**Kernregel, die die Oberfläche sichtbar machen muss:** Text geht normal als GIF im `icon` („Text als Bild“). Das deckt Hintergrundfarbe und Effekt zu; Overlay und Palette gehen. Dazu kommen Text in Gerätschrift (alles geht, plus Palette für den Text) und Grafik (Diagramm/Fortschritt, kein Text). Die Tabelle im Mockup (Abschnitt 0) ordnet jeden Regler den drei Zuständen zu.

## Varianten und Empfehlung

- **Ort der Regler:** Mac/iPad: dritter Inspektor-Reiter „Darstellung“ neben „Format“ und „Zeit“ (in beiden Varianten gleich).
  - 1A, empfohlen: iPhone-Formatblatt bekommt oben „Zeit | Darstellung“. Ein Blatt, keine neue Tür.
  - 1B: iPhone: Chip „✦ Darstellung“ in der Formatpille öffnet ein eigenes Blatt. Ein Griff weniger, aber längere Pille.
- **Text | Grafik:** zweites Segment neben „Anzeige | Nachricht“, weil es ändert, was Senden bedeutet.
- **Gesperrtes bei Bild:** X (empfohlen) ausgegraut mit Fußnote, die Grund und Ausweg nennt (wie „Behalten“ im vorigen Mockup: gesperrt, nicht versteckt). Y: ausgeblendet. Ein Effekt macht den Farbkreis grau.
- **Diagrammwerte:** 3A (empfohlen) ein Listenfeld „3, 5, 8, …“ mit Zähler „n von 16“, Einfügen möglich. 3B Wertezeile mit einem Feld je Wert.
- **Namenslisten** (Effekt, Overlay, Palette) kommen aus `capabilities` der Uhr, also erst nach der ersten Abfrage; davor steht im Menü „Keiner“ und „Uhr abfragen …“.
- **Eigene Palette:** Popover (Mac/iPad) bzw. Blatt (iPhone), 1–16 Farben gleichmäßig oder mit Position 0–100.
- „Weich | Hart“ ist ein Segment mit diesen Wörtern (kein verneinter Schalter); Fortschritt ist Schalter plus Regler.

## Fragen

1. „Darstellung“ als dritter Reiter am Mac/iPad (empfohlen) oder Abschnitt im Reiter „Format“?
2. iPhone: Reiter „Zeit | Darstellung“ im Formatblatt (1A, empfohlen) oder Chip „✦ Darstellung“ mit eigenem Blatt (1B)?
3. „Text | Grafik“ als zweites Segment (gezeichnet) oder anders?
4. Bei Text als Bild: Hintergrund und Effekt ausgegraut mit Fußnote (X, empfohlen) oder ausgeblendet (Y)?
5. Diagrammwerte: Listenfeld (3A, empfohlen) oder Wertezeile (3B)?
6. „Weich | Hart“ als Segment oder „Überblenden“ als Schalter?
7. „Text aus Palette“, Spanne, Lauf: bei Text als Bild ausgegraut sichtbar (gezeichnet) oder erst mit Gerätschrift sichtbar?
8. Fortschritt: Schalter plus Regler 0–100 (gezeichnet) oder nur Regler, links = aus?
9. „Leerer Teil“ als Wort für den ungefüllten Rest des Fortschritts verständlich?
10. Merkt sich der Platz die Darstellung als Regler (wie die Lebensdauer) oder gilt sie nur für die eine Sendung?
11. Eigene Palette gleich oder zuerst nur die acht benannten Paletten der Uhr?

## Entscheidung

Erik, 10.10.2026:

- **Grafik (Diagramm und Fortschritt) gibt es nur für Home Assistant und das Werkzeug**, nicht in der Oberfläche: Diagramme von Hand zu erstellen braucht niemand. Damit entfallen das Segment „Text | Grafik“ (Frage 3), die Diagrammwerte (Frage 5) und alle Fortschrittsfragen (8, 9).
1. Darstellung als **dritter Reiter** neben Format und Zeit (Mac/iPad).
2. iPhone: **1A**, Formatblatt mit „Zeit | Darstellung“.
4. Bei Text als Bild: Hintergrund und Effekt **ausgegraut mit Fußnote** (X).
6. Palette: **Schalter „Überblenden“** (ein = Farben fließen ineinander, aus = scharfe Streifen) statt Segment „Weich | Hart“.
7. Text aus Palette, Spanne, Lauf: bei Text als Bild **ausgegraut sichtbar**.
10. Der Platz **merkt** die Darstellung als Regler (wie die Lebensdauer).
11. Eigene Palette **gleich im Mockup-Umfang** (bis 16 Stützen mit Position).
