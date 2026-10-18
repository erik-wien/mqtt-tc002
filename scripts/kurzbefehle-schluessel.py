#!/usr/bin/env python3
"""Welche Texte der Kurzbefehle fehlen in der englischen Uebersetzung?

    kurzbefehle-schluessel.py <extract.actionsdata> <en.lproj/Localizable.strings>

Der Metadatenerzeuger (`appintentsmetadataprocessor`) baut aus dem Quelltext
eine eigene Fassung jedes sichtbaren Textes — aus `Summary("\\(\\.$text) ...")`
wird im Buendel `${text} ...`, und genau dieser Wortlaut wird zur Laufzeit
nachgeschlagen, nicht der aus dem Quelltext. `texte-sammeln.py` liest nur die
Quellen und kann das nicht sehen; deshalb wird hier das **gebaute** Buendel
geprueft (iOS und Mac, `buendel-pruefen.sh`).

Ausgabe: je fehlendem Schluessel eine Zeile; Rueckgabewert 1, wenn welche fehlen.
"""
import json
import re
import sys

daten = json.load(open(sys.argv[1]))
da = set(re.findall(r'^\s*"((?:[^"\\]|\\.)*)"\s*=',
                    open(sys.argv[2], encoding="utf-8").read(), re.M))
gesucht = []
for name, a in daten.get("actions", {}).items():
    gesucht.append(a["title"]["key"])
    gesucht.append(a["descriptionMetadata"]["descriptionText"]["key"])
    zus = a["actionConfiguration"]["actionSummary"]["wrapper"]["summaryString"]
    gesucht.append(zus["formatString"])
    for p in a.get("parameters", []):
        gesucht.append(p["title"]["key"])
        if "parameterDescription" in p:
            gesucht.append(p["parameterDescription"]["key"])
for e in daten.get("enums", []):
    gesucht.append(e["displayTypeName"]["key"])
    for f in e["cases"]:
        gesucht.append(f["displayRepresentation"]["title"]["key"])
for s in daten.get("autoShortcuts", []):
    gesucht.append(s["shortTitle"]["key"])
fehlend = sorted({k for k in gesucht if k not in da})
print("\n".join(fehlend))
sys.exit(1 if fehlend else 0)
