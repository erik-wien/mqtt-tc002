import Foundation

/// Der Name einer MP3-Datei auf der Uhr. Gemessen an der TC002 (NG 1.2.2,
/// 10. Oktober 2026, `docs/awtrix-ng-protokoll.md` §4.2): `[A-Za-z0-9_-]`, 1–32
/// Zeichen, die Uhr hängt `.mp3` an; alles andere weist sie mit `400 invalidName`
/// ab. Der Vorschlag macht aus jedem Dateinamen einen, den sie nimmt.
public enum Klangname {
    public static let hoechstlaenge = 32
    /// Ersatz, wenn von einem Dateinamen nichts übrig bleibt.
    public static let leererName = "klang"

    private static func erlaubt(_ z: Unicode.Scalar) -> Bool {
        switch z.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x5F, 0x2D: return true
        default: return false
        }
    }

    /// Die Prüfregel der Uhr (ohne Endung).
    public static func gueltig(_ name: String) -> Bool {
        (1...hoechstlaenge).contains(name.unicodeScalars.count) && name.unicodeScalars.allSatisfy(erlaubt)
    }

    /// Die Zeichen eines Namens, die die Uhr nicht nimmt, ohne Wiederholung und in
    /// der Reihenfolge ihres ersten Auftretens.
    public static func ungueltigeZeichen(in name: String) -> [Character] {
        var gesehen = Set<Character>()
        return name.filter { c in
            !c.unicodeScalars.allSatisfy(erlaubt) && gesehen.insert(c).inserted
        }
    }

    /// Ein gültiger Name aus einem Dateinamen: Endung `.mp3` weg, Umlaute und ß
    /// ausgeschrieben, übrige Akzente entfernt, Leerzeichen, Punkte und
    /// Satzzeichen zu `-`, alles Übrige gestrichen, Wiederholungen von `-`
    /// zusammengezogen, `-` und `_` am Rand gestrichen, auf 32 Zeichen gekürzt.
    /// Bleibt nichts übrig, ist es `klang`.
    ///
    /// Dateinamen aus dem Finder sind zerlegt (`u` + U+0308); darum wird zuerst
    /// zusammengesetzt, dann ausgeschrieben.
    public static func vorschlag(ausDateiname datei: String) -> String {
        var text = datei
        if text.lowercased().hasSuffix(".mp3") { text = String(text.dropLast(4)) }
        text = text.precomposedStringWithCanonicalMapping
        for (von, zu) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"), ("ẞ", "SS"),
                          ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue")] {
            text = text.replacingOccurrences(of: von, with: zu)
        }
        let trenner = Set(" \t.,;:/\\+&|~()[]{}")
        var ergebnis = ""
        for c in text.decomposedStringWithCanonicalMapping {
            if trenner.contains(c) || c.isWhitespace {
                ergebnis.append("-")
            } else {
                for z in c.unicodeScalars where erlaubt(z) { ergebnis.unicodeScalars.append(z) }
            }
        }
        while ergebnis.contains("--") { ergebnis = ergebnis.replacingOccurrences(of: "--", with: "-") }
        let rand = CharacterSet(charactersIn: "-_")
        ergebnis = ergebnis.trimmingCharacters(in: rand)
        ergebnis = String(ergebnis.prefix(hoechstlaenge)).trimmingCharacters(in: rand)
        return ergebnis.isEmpty ? leererName : ergebnis
    }

    /// `name`, wenn frei, sonst `name-2`, `name-3` …, mit Rücksicht auf die 32
    /// Zeichen. `vorhanden` sind die MP3-Dateien **und** Melodien der Uhr:
    /// Beide Namensräume sind gemeinsam eindeutig.
    public static func freierName(_ name: String, vorhanden: some Collection<String>) -> String {
        let belegt = Set(vorhanden)
        guard belegt.contains(name) else { return name }
        let rand = CharacterSet(charactersIn: "-_")
        for n in 2... {
            let endung = "-\(n)"
            let kopf = String(name.prefix(hoechstlaenge - endung.count)).trimmingCharacters(in: rand)
            let kandidat = (kopf.isEmpty ? leererName : kopf) + endung
            if !belegt.contains(kandidat) { return kandidat }
        }
        return name
    }
}
