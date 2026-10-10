# Freigabe: Benachrichtigung, Lebensdauer, Anzeigen ein/aus (09.10.2026)

Mockup: `2026-10-09-benachrichtigung-lebensdauer.html`. Grundlage: `docs/awtrix-ng-protokoll.md` §5.4 und §5.6. Status: **freigegeben** (Erik, 10.10.2026), umgesetzt in Sprint 3b.

**Varianten für die Wahl Anzeige | Benachrichtigung**
- A: Segment (`Picker`, `.segmented`) über dem Eingabefeld; bei Benachrichtigung sind die fünf Plätze ausgegraut. Empfohlen: Die Art der Sendung kommt vor dem Ziel, und es bleibt bei fünf gleich großen Blöcken, auch am iPhone.
- B: Sechstes, gestricheltes Ziel mit Glocke in der Platzleiste.
- Verworfen: Wahl im Inspektor. Sie wäre am iPhone hinter dem Formatblatt versteckt, obwohl sie ändert, was Senden bedeutet.

**Optionen:** Benachrichtigung (Halten, Aufwecken, Ersetzen, Durchläufe, Dauer) und Lebensdauer einer Anzeige stehen im Inspektor-Reiter „Zeit“ bzw. im Formatblatt am iPhone. Ein/Aus einer Anzeige im Kontextmenü des Blocks; „Benachrichtigung zurückziehen“ nur bei gehaltener Benachrichtigung.

## Fragen

1. Variante A (Segment, empfohlen) oder B (sechstes Ziel)?
2. „Benachrichtigung“ oder kürzer „Hinweis“?
3. Standardwerte der Benachrichtigung: Halten, Aufwecken, Ersetzen aus; Durchläufe 1; Dauer wie bei der Anzeige. Passt das?
4. Lebensdauer: Standard aus; Einheit wählbar (Minuten/Stunden) oder nur Minuten; Vorgabe der Aktion „Entfernen“ oder „Rot markieren“?
5. Soll der Platz die Lebensdauer als Regler mitmerken oder gilt sie nur für die eine Sendung?
6. Ein/Aus im Kontextmenü des Blocks, ausgeschaltet grau, oder lieber ein sichtbarer Schalter am Block?
7. „Zurückziehen“ nur bei gehaltener Benachrichtigung sichtbar; Wortlaut „Benachrichtigung zurückziehen“?
8. Mehrere Uhren als Ziel: Benachrichtigung und Zurückziehen gelten für alle gewählten Uhren. Recht so?

## Entscheidung

Erik, 09.10.2026:

1. **Variante A** — Segment über dem Eingabefeld.
2. Die Oberfläche sagt **„Nachricht“** (Segment „Anzeige | Nachricht“, „Nachricht zurückziehen“). Im Code und im Protokoll bleibt `notification`/Benachrichtigung.
3. Vorgaben der Nachricht: **Halten ein, Aufwecken ein, Ersetzen aus, Durchläufe 2.** Dauer wie bei der Anzeige.
4. Lebensdauer: Schalter **„Behalten“, Vorgabe aus** — eine neue Anzeige verschwindet von selbst; „Behalten“ ein heißt, sie bleibt, bis man sie löscht. Solange „Behalten“ aus ist: Vorgabezeit 30 min (aus dem Mockup, zur Korrektur offen), Einheit wählbar (Minuten/Stunden), Aktion danach Vorgabe „Entfernen“. Der zuerst gezeichnete Schalter „Selbst entfernen“ ist dadurch ersetzt (er erzeugte eine doppelte Verneinung). Steht „Behalten“ auf ein, sind „Nach“ und „Dann“ deaktiviert (`.disabled`), nicht ausgeblendet.
5. Der Platz **merkt** die Lebensdauer als Regler — bis der Platz gelöscht wird oder eine neue Sendung mit anderen Werten kommt.
6. Ja: Ein/Aus im Kontextmenü des Blocks („In der Schleife“), ausgeschaltet grau. Der Platz bleibt belegt, die Anzeige auf der Uhr gespeichert; sie läuft nur nicht in der Schleife.
7. Ja: „Zurückziehen“ nur bei gehaltener Nachricht sichtbar.
8. Ja: Nachricht und Zurückziehen gelten für alle gewählten Uhren.
