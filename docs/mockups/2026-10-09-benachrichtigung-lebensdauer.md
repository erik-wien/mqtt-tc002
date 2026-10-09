# Freigabe: Benachrichtigung, Lebensdauer, Anzeigen ein/aus (09.10.2026)

Mockup: `2026-10-09-benachrichtigung-lebensdauer.html`. Grundlage: `docs/awtrix-ng-protokoll.md` §5.4 und §5.6. Status: **offen**, noch nicht freigegeben.

**Varianten für die Wahl Anzeige | Benachrichtigung**
- A: Segment (`Picker`, `.segmented`) über dem Eingabefeld; bei Benachrichtigung sind die fünf Plätze ausgegraut. Empfohlen: Die Art der Sendung kommt vor dem Ziel, und es bleibt bei fünf gleich großen Blöcken, auch am iPhone.
- B: Sechstes, gestricheltes Ziel mit Glocke in der Platzleiste.
- Verworfen: Wahl im Inspektor. Sie wäre am iPhone hinter dem Formatblatt versteckt, obwohl sie ändert, was Senden bedeutet.

**Optionen:** Benachrichtigung (Halten, Aufwecken, Ersetzen, Wiederholungen, Dauer) und Lebensdauer einer Anzeige stehen im Inspektor-Reiter „Zeit“ bzw. im Formatblatt am iPhone. Ein/Aus einer Anzeige im Kontextmenü des Blocks; „Benachrichtigung zurückziehen“ nur bei gehaltener Benachrichtigung.

## Fragen

1. Variante A (Segment, empfohlen) oder B (sechstes Ziel)?
2. „Benachrichtigung“ oder kürzer „Hinweis“?
3. Standardwerte der Benachrichtigung: Halten, Aufwecken, Ersetzen aus; Wiederholungen 1; Dauer wie bei der Anzeige. Passt das?
4. Lebensdauer: Standard aus; Einheit wählbar (Minuten/Stunden) oder nur Minuten; Vorgabe der Aktion „Entfernen“ oder „Rot markieren“?
5. Soll der Platz die Lebensdauer als Regler mitmerken oder gilt sie nur für die eine Sendung?
6. Ein/Aus im Kontextmenü des Blocks, ausgeschaltet grau, oder lieber ein sichtbarer Schalter am Block?
7. „Zurückziehen“ nur bei gehaltener Benachrichtigung sichtbar; Wortlaut „Benachrichtigung zurückziehen“?
8. Mehrere Uhren als Ziel: Benachrichtigung und Zurückziehen gelten für alle gewählten Uhren. Recht so?

## Entscheidung

(leer)
