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

    /// Fasst waagrechte Laeufe gleicher Farbe zu einem Rechteck zusammen.
    public func alsDrawBefehle() -> [DrawBefehl] {
        var befehle: [DrawBefehl] = []
        for y in 0..<hoehe {
            var x = 0
            while x < breite {
                guard let farbe = punkte[y * breite + x] else { x += 1; continue }
                var laenge = 1
                while x + laenge < breite, punkte[y * breite + x + laenge] == farbe { laenge += 1 }
                befehle.append(DrawBefehl(x: x, y: y, breite: laenge, hoehe: 1, farbe: farbe))
                x += laenge
            }
        }
        return befehle
    }
}
