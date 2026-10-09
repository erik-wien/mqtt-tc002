import Foundation

/// Das Display als Raster. Dient dem Malwerkzeug und der Textrasterung gleichermassen.
public struct Pixelfeld: Equatable, Sendable {
    public static let breiteStandard = 52
    public static let hoeheStandard = 16

    public let breite: Int
    public let hoehe: Int
    private var punkte: [String?]

    public init(breite: Int = breiteStandard, hoehe: Int = hoeheStandard) {
        self.breite = breite; self.hoehe = hoehe
        punkte = Array(repeating: nil, count: breite * hoehe)
    }

    /// Alle Punkte zeilenweise von oben links. `nil` heisst aus. Fuer die
    /// Sicherung ausserhalb dieses Typs (z. B. UserDefaults) — Zugriff sonst
    /// nur ueber `farbe(x:y:)` und `setzen(x:y:farbe:)`.
    public var punkteRoh: [String?] { punkte }

    /// Baut ein Feld aus so einem Feld zurueck. Passt die Laenge nicht zu
    /// breite × hoehe, kommt nil heraus statt eines halben Bildes.
    public init?(breite: Int = breiteStandard, hoehe: Int = hoeheStandard, punkte: [String?]) {
        guard punkte.count == breite * hoehe else { return nil }
        self.breite = breite; self.hoehe = hoehe
        self.punkte = punkte
    }

    private func drin(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < breite && y < hoehe
    }

    public mutating func setzen(x: Int, y: Int, farbe: String) {
        guard drin(x, y) else { return }
        punkte[y * breite + x] = farbe
    }

    public mutating func loeschen(x: Int, y: Int) {
        guard drin(x, y) else { return }
        punkte[y * breite + x] = nil
    }

    public func farbe(x: Int, y: Int) -> String? {
        drin(x, y) ? punkte[y * breite + x] : nil
    }

    public mutating func alleLoeschen() {
        punkte = Array(repeating: nil, count: breite * hoehe)
    }

    /// Das Feld in 2 × 2 grossen Bloecken, so wie NG eine Anzeige zeichnet,
    /// solange `enlargeApps` gilt (§1.1): Ein Block ist gesetzt, sobald einer
    /// seiner vier Punkte es ist, und nimmt dessen Farbe.
    public func inDoppelpixeln() -> Pixelfeld {
        var aus = Pixelfeld(breite: breite, hoehe: hoehe)
        for y in stride(from: 0, to: hoehe, by: 2) {
            for x in stride(from: 0, to: breite, by: 2) {
                let farbe = [(0, 0), (1, 0), (0, 1), (1, 1)]
                    .lazy.compactMap { self.farbe(x: x + $0.0, y: y + $0.1) }.first
                guard let farbe else { continue }
                for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
                    aus.setzen(x: x + dx, y: y + dy, farbe: farbe)
                }
            }
        }
        return aus
    }
}
