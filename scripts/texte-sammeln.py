#!/usr/bin/env python3
"""Sammelt alle sichtbaren Texte aus den Swift-Quellen.

SwiftUI uebersetzt Zeichenketten, die als `LocalizedStringKey` ankommen, von
selbst — der deutsche Wortlaut ist dabei der Schluessel. Xcode zieht diese
Schluessel beim Bauen heraus; ein Swift-Paket mit handgeschnuertem Buendel tut
das nicht. Also hier.

    python3 scripts/texte-sammeln.py            # Schluessel auf die Ausgabe
    python3 scripts/texte-sammeln.py --pruefen  # meldet, was in en.lproj fehlt

Gefunden wird zweierlei:
  1. Zeichenketten an Stellen, die SwiftUI als `LocalizedStringKey` nimmt
     (`Text`, `Button`, `Label`, `.help`, `Toggle`, `Picker`, `.navigationTitle`,
     `confirmationDialog`, `alert`, `TextField`, `Section`, `Stepper` …).
  2. Zeichenketten in `lok("…")` — der Weg fuer alles, was als gewoehnliches
     `String` weitergereicht wird und deshalb nie durch SwiftUI laeuft.

Nicht gefunden wird, was in einer Variablen steht, bevor es angezeigt wird.
Genau dafuer gibt es `lok(…)`.
"""

import re
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
QUELLEN = [WURZEL / "Sources" / "TC002App",
           WURZEL / "Sources" / "TC002CLI",
           WURZEL / "Sources" / "TC002Core"]
SPRACHDATEI = WURZEL / "Resources" / "Sprachen" / "en.lproj" / "Localizable.strings"

# Aufrufe, deren erstes Argument SwiftUI als LocalizedStringKey behandelt.
ERSTES_ARGUMENT = [
    "Text", "Button", "Label", "Toggle", "Picker", "TextField", "SecureField",
    "Section", "Stepper", "Slider", "Link", "Menu", "DisclosureGroup",
    "confirmationDialog", "alert", "Tab", "GroupBox", "LabeledContent",
    "NavigationLink", "ProgressView", "ToolbarItem",
]
# Modifikatoren, deren einziges Argument ein LocalizedStringKey ist.
MODIFIKATOREN = ["help", "navigationTitle", "navigationSubtitle", "accessibilityLabel"]
# Eigene Bausteine der Hilfe und des Werkzeugs.
EIGENE = ["lok", "lokf", "ueberschrift", "absatz"]

# Eine Swift-Zeichenkette ohne Escapes am Rand: absichtlich streng, damit
# nichts halb Gefangenes in die Liste rutscht.
ZEICHENKETTE = r'"((?:[^"\\]|\\.)*)"'

MUSTER = (
    [re.compile(rf'\b{n}\(\s*{ZEICHENKETTE}') for n in ERSTES_ARGUMENT] +
    [re.compile(rf'\.{n}\(\s*{ZEICHENKETTE}') for n in MODIFIKATOREN] +
    [re.compile(rf'\b{re.escape(n)}\(\s*{ZEICHENKETTE}') for n in EIGENE]
)


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
                        schluessel = treffer.group(1)
                        # Systemnamen und Platzhalter sind keine Texte.
                        if not schluessel or schluessel.isspace():
                            continue
                        if re.fullmatch(r"[a-z0-9.]+", schluessel):
                            continue          # SF-Symbole, Schluesselnamen
                        gesehen.setdefault(schluessel, datei.name)
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
