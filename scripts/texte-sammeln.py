#!/usr/bin/env python3
"""Sammelt alle sichtbaren Texte aus den Swift-Quellen.

SwiftUI uebersetzt Zeichenketten, die als `LocalizedStringKey` ankommen, von
selbst — der deutsche Wortlaut ist dabei der Schluessel. Xcode zieht diese
Schluessel beim Bauen heraus; ein Swift-Paket mit handgeschnuertem Buendel tut
das nicht. Also hier.

    python3 scripts/texte-sammeln.py            # Schluessel auf die Ausgabe
    python3 scripts/texte-sammeln.py --pruefen  # meldet, was in en.lproj fehlt

Gefunden wird dreierlei:
  1. Zeichenketten an Stellen, die SwiftUI als `LocalizedStringKey` nimmt
     (`Text`, `Button`, `Label`, `.help`, `Toggle`, `Picker`, `.navigationTitle`,
     `confirmationDialog`, `alert`, `TextField`, `Section`, `Stepper` …).
  2. Zeichenketten in `lok("…")` — der Weg fuer alles, was als gewoehnliches
     `String` weitergereicht wird und deshalb nie durch SwiftUI laeuft.
  3. `title:`/`description:` in `@Parameter(...)` (AppIntents, Kurzbefehle.swift)
     — sichtbarer Text in Apples Kurzbefehle-App, aber als benanntes Argument
     statt als erstes Argument uebergeben.

Nicht gefunden wird, was in einer Variablen steht, bevor es angezeigt wird.
Genau dafuer gibt es `lok(…)`.
"""

import re
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
QUELLEN = [WURZEL / "Sources" / "TC002App",
           WURZEL / "Sources" / "TC002CLI",
           WURZEL / "Sources" / "TC002Core",
           WURZEL / "Sources" / "TC002Modell",
           WURZEL / "Sources" / "TC002iOS",
           # Plattformfreie, geteilte Ansichten (Mac, iPhone, künftig iPad) —
           # seit `Slotblock.swift` der erste eigene, übersetzte Text hier.
           WURZEL / "Sources" / "TC002Ansichten"]
SPRACHDATEI = WURZEL / "Resources" / "Sprachen" / "en.lproj" / "Localizable.strings"

# Aufrufe, deren erstes Argument SwiftUI als LocalizedStringKey behandelt.
ERSTES_ARGUMENT = [
    "Text", "Button", "Label", "Toggle", "Picker", "TextField", "SecureField",
    "Section", "Stepper", "Slider", "Link", "Menu", "DisclosureGroup",
    "confirmationDialog", "alert", "Tab", "GroupBox", "LabeledContent",
    "NavigationLink", "ProgressView", "ToolbarItem", "ContentUnavailableView",
    "ColorPicker",
]
# Aufrufe, die eine *Liste* von Texten bekommen — die Hilfe baut ihre
# Aufzaehlungen und Tabellen so. Hier steht der Text nicht hinter der Klammer,
# sondern verteilt auf die Zeilen danach, deshalb die eigene Behandlung.
LISTEN = ["punkte", "tabelle"]
# Modifikatoren, deren einziges Argument ein LocalizedStringKey ist.
MODIFIKATOREN = ["help", "navigationTitle", "navigationSubtitle", "accessibilityLabel"]
# Eigene Bausteine der Hilfe und des Werkzeugs.
EIGENE = ["lok", "lokf", "ueberschrift", "absatz"]
# Schluesselwoerter von `@Parameter(...)` (AppIntents, Kurzbefehle.swift), die
# als sichtbare Beschriftung in der Kurzbefehle-App auftauchen. Kein Aufruf
# mit Text als erstem Argument, sondern ein benanntes Argument irgendwo in der
# Klammer — deshalb eine eigene Suche nach dem Schluesselwort statt nach dem
# Aufrufnamen.
PARAMETER_SCHLUESSEL = ["title", "description"]
# Die Anzeigenamen der Auswahllisten in den Kurzbefehlen (`AppEnum`, siehe
# TC002iOS/KurzbefehleAuswahl.swift): `DisplayRepresentation(title: "…")` je
# Fall, `TypeDisplayRepresentation(name: "…")` fuer die Liste selbst. Beide
# nehmen ein `LocalizedStringResource`; genau dieser Wortlaut landet als
# Schluessel im gebauten Buendel (`Metadata.appintents/extract.actionsdata`,
# `enums[].cases[].displayRepresentation.title.key`) und wird dort zur Laufzeit
# nachgeschlagen. Ohne diese Suche bliebe die Kurzbefehle-App deutsch, ohne
# dass irgendetwas darauf hinwiese.
ANZEIGENAMEN = [("DisplayRepresentation", "title"), ("TypeDisplayRepresentation", "name")]

# Texte, die als Variable nachgeschlagen werden — `lok(a.rawValue)` — und
# deshalb nicht im Quelltext stehen koennen. Sie muessen von Hand hier gefuehrt
# werden, sonst faellt ihr Fehlen erst dem Anwender auf.
DYNAMISCH = [
    # Bereiche der Seitenleiste (SchreibtischView.swift, enum Bereich)
    "Senden", "Editor", "Verlauf", "Einstellungen",
    # Die vier Nebenfenster (Nebenfenster.swift, `titel` schlaegt ueber
    # `lok(rawValue)` nach). Drei davon stehen heute zufaellig auch als
    # Literal in einem Menueeintrag oder Knopf — verlassen darf sich darauf
    # niemand: Faellt der Knopf weg, faende der Sammler den Schluessel nicht
    # mehr, und das Fenster hiesse auf einem englischen Geraet deutsch.
    "Über", "Hilfe", "Gerätereferenz", "Schriftprobe",
    # Die drei Leinwandgroessen (Leinwandgroesse.beschriftung im Kern,
    # nachgeschlagen ueber lok(groesse.beschriftung)).
    "8 × 8", "16 × 16", "16 × 52",
    # Abschnitte der Hilfe (HilfeView.swift, enum Abschnitt)
    "Was das Programm tut", "Wenn nichts erscheint",
    # Kurzbefehle (AppIntents). LocalizedStringResource schlaegt im Buendel
    # nach, steht aber nicht in einem Aufruf, den der Sammler erkennt.
    "Meldung an die Uhr schicken",
    "Meldung von der Uhr nehmen",
    "Schickt einen Text an eine eingerichtete Ulanzi TC002. Schrift und Ausrichtung kommen aus den zuletzt in der App gewählten Einstellungen.",
    "Entfernt eine der fünf Meldungen wieder von der Uhr.",
    "Meldung schicken",
    "Meldung nehmen",
    # `Summary(...)` in Kurzbefehle.swift: Im Quelltext steht SwiftUIs
    # Parameterverweis-Syntax `\(\.$…)`, aber `appintentsmetadataprocessor`
    # baut daraus beim Bauen einen eigenen Platzhalter `${…}` — nachgesehen in
    # `Metadata.appintents/extract.actionsdata` des gebauten Buendels
    # (`actionConfiguration.actionSummary.wrapper.summaryString.formatString`).
    # Genau dieser Wortlaut, nicht der aus dem Quelltext, wird zur Laufzeit
    # nachgeschlagen — deshalb hier von Hand eingetragen statt ein wackliges
    # Muster zu bauen.
    r"${text} an die Uhr schicken",
    r"Slot ${platz} von der Uhr nehmen",
]

# Eine Swift-Zeichenkette ohne Escapes am Rand: absichtlich streng, damit
# nichts halb Gefangenes in die Liste rutscht.
ZEICHENKETTE = r'"((?:[^"\\]|\\.)*)"'

MUSTER = (
    [re.compile(rf'\b{n}\(\s*{ZEICHENKETTE}') for n in ERSTES_ARGUMENT] +
    # Beschriftungen in einer Fallunterscheidung: Button(x ? "A" : "B").
    [re.compile(rf'\b{n}\([^,)"]*\?\s*{ZEICHENKETTE}\s*:\s*{ZEICHENKETTE}')
     for n in ERSTES_ARGUMENT] +
    [re.compile(rf'\.{n}\(\s*{ZEICHENKETTE}') for n in MODIFIKATOREN] +
    [re.compile(rf'\b{re.escape(n)}\(\s*{ZEICHENKETTE}') for n in EIGENE] +
    # title:/description: von @Parameter(...) — beide auf derselben Zeile wie
    # die oeffnende Klammer, wie in Kurzbefehle.swift durchgehend der Fall.
    [re.compile(rf'@Parameter\([^\n]*?\b{n}:\s*{ZEICHENKETTE}') for n in PARAMETER_SCHLUESSEL] +
    [re.compile(rf'\b{typ}\([^\n]*?\b{n}:\s*{ZEICHENKETTE}') for typ, n in ANZEIGENAMEN]
)

# Modifikatoren mit einer Fallunterscheidung: .help(x ? "A" : "B"). Die
# Bedingung und die beiden Zweige koennen auf zwei Zeilen verteilt sein (Zweig
# eins hinter dem Fragezeichen, Zweig zwei hinter dem Doppelpunkt in der
# naechsten Zeile) — deshalb ueber den ganzen Dateitext gesucht, nicht
# zeilenweise wie die uebrigen MUSTER.
MODIFIKATOR_TERNAER = [
    re.compile(rf'\.{n}\([^,)"]*?\?\s*{ZEICHENKETTE}\s*:\s*{ZEICHENKETTE}')
    for n in MODIFIKATOREN
]


def brauchbar(schluessel):
    """Ist das ein sichtbarer Text — oder ein Symbolname, ein Platzhalter?"""
    if not schluessel or schluessel.isspace():
        return False
    # Bezeichner mit Punkt und ohne Leerzeichen sind Symbolnamen oder
    # Schluesselnamen, keine Texte. Ein einzelnes Wort dagegen schon:
    # „langsam" ist eine Beschriftung.
    return not re.fullmatch(r"[a-z0-9]+(\.[a-z0-9]+)+", schluessel)


def aus_listen(text):
    """Texte aus `punkte([...])` und `tabelle([...])`.

    Gesucht wird ab der oeffnenden Klammer bis zur passenden schliessenden;
    alles dazwischen an Zeichenketten gehoert dazu. Ueber den ganzen Dateitext,
    nicht zeilenweise — die Eintraege stehen je auf einer eigenen Zeile.
    """
    for name in LISTEN:
        for anfang in re.finditer(rf'\.{name}\(\[', text):
            tiefe, i = 1, anfang.end()
            while i < len(text) and tiefe > 0:
                if text[i] == '"':                       # Zeichenkette ueberspringen
                    i += 1
                    while i < len(text) and text[i] != '"':
                        i += 2 if text[i] == '\\' else 1
                elif text[i] in '([':
                    tiefe += 1
                elif text[i] in ')]':
                    tiefe -= 1
                i += 1
            for treffer in re.finditer(ZEICHENKETTE, text[anfang.end():i]):
                yield treffer.group(1)


def sammeln():
    """Alle gefundenen Schluessel, in der Reihenfolge des ersten Auftretens."""
    gesehen = {}
    for ordner in QUELLEN:
        for datei in sorted(ordner.rglob("*.swift")):
            text = datei.read_text(encoding="utf-8")
            for zeile in text.splitlines():
                nackt = zeile.strip()
                if nackt.startswith("//") or nackt.startswith("///"):
                    continue
                for muster in MUSTER:
                    for treffer in muster.finditer(zeile):
                        for schluessel in treffer.groups():
                            if schluessel and brauchbar(schluessel):
                                gesehen.setdefault(schluessel, datei.name)
            for schluessel in aus_listen(text):
                if brauchbar(schluessel):
                    gesehen.setdefault(schluessel, datei.name)
            for muster in MODIFIKATOR_TERNAER:
                for treffer in muster.finditer(text):
                    for schluessel in treffer.groups():
                        if schluessel and brauchbar(schluessel):
                            gesehen.setdefault(schluessel, datei.name)
    for schluessel in DYNAMISCH:
        gesehen.setdefault(schluessel, "dynamisch")
    return gesehen


def vorhandene_uebersetzungen():
    if not SPRACHDATEI.exists():
        return set()
    inhalt = SPRACHDATEI.read_text(encoding="utf-8")
    return set(re.findall(r'^\s*"((?:[^"\\]|\\.)*)"\s*=', inhalt, re.MULTILINE))


def main():
    gesehen = sammeln()
    if "--pruefen" in sys.argv:
        da = vorhandene_uebersetzungen()
        fehlend = [k for k in gesehen if k not in da]
        ueberzaehlig = [k for k in da if k not in gesehen]
        for k in fehlend:
            print(f"fehlt   {gesehen[k]}: {k}")
        for k in ueberzaehlig:
            print(f"unnoetig        : {k}")
        print(f"\n{len(gesehen)} Texte, {len(fehlend)} ohne Uebersetzung, "
              f"{len(ueberzaehlig)} ueberzaehlig")
        return 1 if fehlend else 0
    for schluessel, datei in gesehen.items():
        print(f"{datei}\t{schluessel}")
    print(f"\n{len(gesehen)} Texte", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
