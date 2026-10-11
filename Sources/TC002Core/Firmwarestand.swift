import Foundation

/// Die Firmware-Fassung, gegen die diese App gebaut und geprüft ist
/// (AWTRIX NG), und der Vergleich mit dem, was eine Uhr meldet.
///
/// Ältere Fassungen melden ihre Fähigkeiten unvollständig (1.1.0: kein
/// `platform`, `display`, `fonts`, `sensors`, Audio nach altem Schlüsselsatz);
/// die App behandelt solche Uhren dann falsch. Es bleibt ein Hinweis: gesperrt
/// wird nichts.
public enum Firmwarestand {
    /// Die erste Fassung, deren `/api/v1/capabilities` und `/api/v1/settings`
    /// dem Schlüsselsatz der App entsprechen (gemessen 11. Oktober 2026).
    public static let unterstuetzt = "1.2.2"

    /// Die Zahlen einer Fassung: `1.2.2` → `[1, 2, 2]`. Ein führendes `v` und
    /// alles ab dem ersten Zeichen, das weder Ziffer noch Punkt ist
    /// (`1.2.2-beta`, `1.2.2+abc`), bleiben unbeachtet. `nil`, wenn keine
    /// Zahl am Anfang steht oder eine Gruppe leer ist (`1..2`).
    public static func zahlen(_ fassung: String) -> [Int]? {
        var text = fassung.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        let kopf = text.prefix { $0.isASCII && ($0.isNumber || $0 == ".") }
        guard !kopf.isEmpty else { return nil }
        var zahlen: [Int] = []
        for gruppe in kopf.split(separator: ".", omittingEmptySubsequences: false) {
            guard let n = Int(gruppe) else { return nil }
            zahlen.append(n)
        }
        return zahlen
    }

    /// Ordnet zwei Fassungen nach ihren Zahlen, fehlende gelten als 0
    /// (`1.2` = `1.2.0`). `nil`, wenn eine von beiden nicht lesbar ist.
    public static func vergleichen(_ a: String, _ b: String) -> ComparisonResult? {
        guard let za = zahlen(a), let zb = zahlen(b) else { return nil }
        for i in 0..<max(za.count, zb.count) {
            let x = i < za.count ? za[i] : 0, y = i < zb.count ? zb[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    /// Der Hinweis zu einer gemeldeten Fassung: nur, wenn sie lesbar und
    /// älter als `unterstuetzt` ist. Unbekannt oder unlesbar heißt kein Hinweis.
    public static func hinweis(fuer gemeldet: String?, unterstuetzt: String = Firmwarestand.unterstuetzt)
        -> Firmwarehinweis? {
        guard let gemeldet, vergleichen(gemeldet, unterstuetzt) == .orderedAscending else { return nil }
        return Firmwarehinweis(gemeldet: gemeldet, erwartet: unterstuetzt)
    }
}

/// Dass eine Uhr eine ältere Firmware trägt, als die App kennt.
public struct Firmwarehinweis: Equatable, Sendable {
    public let gemeldet: String
    public let erwartet: String

    public init(gemeldet: String, erwartet: String) {
        self.gemeldet = gemeldet
        self.erwartet = erwartet
    }

    public var meldung: String {
        lokf("Firmware %@ ist älter als %@. Bitte die Uhr aktualisieren — ältere Fassungen melden ihre Fähigkeiten unvollständig.",
             gemeldet, erwartet)
    }

    public static var anleitung: String {
        lok("Aktualisieren über die Weboberfläche der Uhr (Update) oder den Web-Installer von AWTRIX NG.")
    }

    /// Meldung und Anleitung in einem Satz für Hilfetext und Terminal.
    public var volltext: String { meldung + " " + Firmwarehinweis.anleitung }
}

extension Geraetezustand {
    /// `nil`, solange die Fassung unbekannt ist oder reicht.
    public var firmwarehinweis: Firmwarehinweis? { Firmwarestand.hinweis(fuer: fassung) }
}
