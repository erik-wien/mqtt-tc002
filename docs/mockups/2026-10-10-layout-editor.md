# Freigabe: Layout-Editor (10.10.2026)

Mockup: `2026-10-10-layout-editor.html` (Sprint 5b). Grundlage: `docs/awtrix-ng-protokoll.md` §9. Status: **zurückgestellt** (Erik, 10.10.2026).

Layouts gibt es nur auf der TC002 (52 × 16); die TC001 (32 × 8) weist sie ab. Bis zu 16 Kästen, je genau ein Inhalt (Text, Symbol, Diagramm, Fortschritt, Zeichnung), darüber Hintergrund, Effekt, Overlay und Palette des ganzen Layouts (dieselben Regler wie im Mockup „Darstellung“). Grenzen der Uhr stehen im Reiter „Layout“ (Regionen 16, laufende Texte 8, Icons 4, Text 8192 Byte).

## Varianten und Empfehlung

- **Ort:** Seitenleistenpunkt „Layouts“ unter „Icons“ (Mac/iPad); Mitte Zeichenfläche (1 Pixel = 11 pt) mit Zeichenreihenfolge, rechts Inspektor „Region | Layout“. Layouts werden wie Icons gespeichert und per iCloud abgeglichen.
- **Kasten zeichnen:**
  - Maus: Werkzeug „Kasten“ aufziehen (Fadenkreuz, Maß am Zeiger), „Auswählen“ verschiebt und zieht Griffe; Pfeiltasten 1 Pixel.
  - Finger (iPad), A empfohlen: dieselbe Geste, Griffe mit 44 pt Fläche, Lupe über dem Finger, Zahlenfelder immer sichtbar. B: zwei Tipper (Ecke, Gegenecke). C: „+“ legt 16 × 8 an, dann Zahlen. B und C sind nur andere Wege zur selben Fähigkeit.
- **iPhone:**
  - R1 voller Editor: nicht empfohlen. Ein Pixel ist 5,6 pt, das Diagramm-Kästchen 45 pt hoch, ein Finger 44 pt breit.
  - R2, empfohlen: Layouts wählen und befüllen (Texte, Werte, Symbol), Form nur am Mac/iPad. Begründung: Geometrie ist vom Platz erzwungen (Projektregel), der Inhalt nicht.
  - R3: gar kein Layout am iPhone; verschenkt das Senden und lässt Anzeigen unsichtbar.
- **Senden:** B empfohlen, drittes Segment „Text | Grafik | Layout“ in „Senden“ (Felder des Layouts, Plätze, Anzeige/Nachricht wie sonst, auch am iPhone). A: eigenes „Senden an …“ im Editor, mit zweiter Platzleiste. Der Editor hat nur ein „Senden …“, das zu „Senden“ springt.
- **TC001 als Ziel:** Segment „Layout“ ausgegraut mit Grund; bei mehreren Zielen geht das Layout nur an die TC002.
- Abhängigkeit: setzt das Segment „Text | Grafik“ und die Regler aus `2026-10-10-darstellung` voraus.

## Fragen

1. Eigener Seitenleistenpunkt „Layouts“ zwischen „Icons“ und „Protokoll“, oder Reiter innerhalb von „Icons“?
2. Senden über drittes Segment „Layout“ in „Senden“ (B, empfohlen) oder „Senden an …“ im Editor (A)?
3. iPhone: gespeicherte Layouts wählen und Felder ändern, keine Kästen bauen (R2, empfohlen) oder nichts (R3)?
4. iPad: Kästen ziehen mit großen Griffen und Lupe (A) oder zwei Tipper (B)?
5. Zieht man einen Kasten über einen anderen: liegt er darüber (Zeichenreihenfolge) oder rastet er am Rand des anderen ein?
6. Mit TC001 als Ziel: „Layout“ ausgegraut mit Grund oder ganz fehlend?
7. Mehrere Uhren, darunter eine TC001: bekommt sie nichts, mit Hinweis neben dem Sendezeichen, oder wird das Senden ganz verweigert?
8. Merkt sich der Platz das Layout samt Feldwerten (Antippen stellt es wieder her) oder zeigt der Block nur sein Bild?
9. Namen: „Layouts“ und „Kasten“, oder „Aufteilungen“/„Seiten“ und „Feld“/„Bereich“?
10. Neues Layout leer beginnen oder drei Vorlagen (Symbol + Text, Zweizeilig, Text + Balken) anbieten? Am iPhone wären Vorlagen der einzige Anlegeweg.

## Entscheidung

Erik, 10.10.2026: **Zurückgestellt.** Layouts gehen wie Grafik (Diagramm, Fortschritt) vorerst nur über Home Assistant und das Werkzeug (`mqtttc002 layout`, Sprint 5a); Editor (5b) und Sammlung (5c) werden nicht gebaut. Ein Layout lebt von automatisch gefüllten Werten (Temperatur u. ä.), und die kann die Uhr nicht selbst holen — sie bekäme sie nur von einem Absender wie Home Assistant oder einem Kurzbefehl. Die Fragen oben bleiben für eine spätere Wiederaufnahme stehen.
