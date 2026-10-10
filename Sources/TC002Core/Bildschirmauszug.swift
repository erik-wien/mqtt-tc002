import Foundation
import ImageIO

/// Was die Uhr gerade zeigt: das Bild, das die Apps gezeichnet haben
/// (`docs/awtrix-ng-protokoll.md` §7.3). `GET /api/v1/display/screen` und —
/// als Antwort auf `cmd/screen/get` — `<P>/state/screen` tragen dieselbe Form.
///
/// Helligkeit und Farbkorrektur der Uhr stecken nicht darin, die Farben sind
/// die der Zeichnung.
public struct Bildschirmauszug: Equatable, Sendable {
    public let breite: Int
    public let hoehe: Int
    /// `0xRRGGBB`, zeilenweise von oben links; `breite × hoehe` Einträge.
    public let pixel: [Int]

    public enum Fehler: Error, LocalizedError, Equatable {
        case unlesbar
        public var errorDescription: String? {
            lok("Die Uhr hat kein lesbares Bild ihres Displays geliefert.")
        }
    }

    public init?(breite: Int, hoehe: Int, pixel: [Int]) {
        // Dieselbe Plausibilitätsgrenze wie beim Anzeigemaß: Die Zahlen kommen
        // aus dem Netz und bestimmen Speicher und Schleifen.
        guard AwtrixNG.plausiblesMass(breite: breite, hoehe: hoehe) != nil,
              pixel.count == breite * hoehe,
              pixel.allSatisfy({ (0...0xFFFFFF).contains($0) }) else { return nil }
        self.breite = breite; self.hoehe = hoehe; self.pixel = pixel
    }

    /// Aus `{"width":W,"height":H,"pixels":[…]}`.
    public init(daten: Data) throws {
        guard let o = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any],
              let b = o["width"] as? Int, let h = o["height"] as? Int,
              let roh = o["pixels"] as? [Any] else { throw Fehler.unlesbar }
        let werte = roh.compactMap { ($0 as? NSNumber)?.intValue }
        guard werte.count == roh.count, let a = Bildschirmauszug(breite: b, hoehe: h, pixel: werte) else {
            throw Fehler.unlesbar
        }
        self = a
    }

    public func farbe(x: Int, y: Int) -> Int? {
        guard x >= 0, y >= 0, x < breite, y < hoehe else { return nil }
        return pixel[y * breite + x]
    }

    /// Wie `Pixelfeld.punkteRoh`: `nil` für Schwarz, sonst `#RRGGBB`.
    public var punktfeld: [String?] {
        pixel.map { $0 == 0 ? nil : String(format: "#%06X", $0) }
    }

    /// Das Bild als Text, eine Zeile je Pixelreihe. Schwarz ist `.`; die erste
    /// andere Farbe in Leserichtung ist `#`, die weiteren `A`, `B`, … Danach
    /// eine Legende mit dem Wert je Zeichen. Mehr als 26 Farben zeigen `*`.
    public func ascii() -> String {
        var zeichenJeFarbe: [Int: Character] = [0: "."]
        var legende: [(Character, Int)] = []
        let vorrat = Array("#ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var zeilen: [String] = []
        for y in 0..<hoehe {
            var zeile = ""
            for x in 0..<breite {
                let f = pixel[y * breite + x]
                if let z = zeichenJeFarbe[f] { zeile.append(z); continue }
                let z: Character = legende.count < vorrat.count ? vorrat[legende.count] : "*"
                if legende.count < vorrat.count {
                    zeichenJeFarbe[f] = z
                    legende.append((z, f))
                }
                zeile.append(z)
            }
            zeilen.append(zeile)
        }
        return (zeilen + legende.map { String(format: "%@ = #%06X", String($0.0), $0.1) }).joined(separator: "\n")
    }
}

/// Wartet auf eine Nachricht der Uhr auf einem bestimmten Thema, während ein
/// Kommando hinausgeht (`<P>/state/screen` nach `cmd/screen/get`). Das Thema
/// ist nicht aufbewahrt: Gehört wird vor dem Senden.
public protocol ThemaLauschend: Sendable {
    /// Hört auf `thema`, führt `tat` aus und wartet danach höchstens `frist`
    /// Sekunden. `nil` heißt: keine Nachricht.
    func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                  waehrend tat: () throws -> Void) throws -> Data?
}

/// Der wirkliche Lauscher: eine eigene Verbindung zum Broker mit eigener
/// Kennung, weil ein Broker die Sitzung trennt, sobald dieselbe Kennung erneut
/// verbindet — und gesendet wird auf der Kennung des Absenders.
public struct MQTTThemenlauscher: ThemaLauschend {
    private let abonnierfrist: TimeInterval
    private let kennungszusatz: String

    public init(abonnierfrist: TimeInterval = 5, kennungszusatz: String = "-lesen") {
        self.abonnierfrist = abonnierfrist
        self.kennungszusatz = kennungszusatz
    }

    public func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                         waehrend tat: () throws -> Void) throws -> Data? {
        var eigener = zugang
        eigener.clientID += kennungszusatz
        let abonnent = MQTTAbonnent(zugang: eigener, themen: [thema], anmeldefrist: abonnierfrist)
        let abonniert = DispatchSemaphore(value: 0)
        let angekommen = DispatchSemaphore(value: 0)
        let fach = Antwortfach()
        abonnent.beiAbonniert = { abonniert.signal() }
        abonnent.beiNachricht = { eintreffend, nutzlast in
            guard eintreffend == thema else { return }
            fach.merken(nutzlast)
            angekommen.signal()
        }
        abonnent.starten()
        defer { abonnent.beenden() }
        // Wird das Abonnement nicht bestätigt, geht die Anfrage trotzdem hinaus;
        // das Ausbleiben der Antwort beweist dann nichts mehr.
        _ = abonniert.wait(timeout: .now() + abonnierfrist)
        try tat()
        guard angekommen.wait(timeout: .now() + frist) == .success else { return nil }
        return fach.wert
    }
}

final class Antwortfach: @unchecked Sendable {
    private let sperre = NSLock()
    private var _wert: Data?
    func merken(_ neu: Data) { sperre.lock(); if _wert == nil { _wert = neu }; sperre.unlock() }
    var wert: Data? { sperre.lock(); defer { sperre.unlock() }; return _wert }
}

extension Anzeigen {
    /// Liest das Display der Uhr: über MQTT mit `cmd/screen/get` und der Antwort
    /// auf `state/screen`, über HTTP mit `GET /api/v1/display/screen`. Bleibt die
    /// MQTT-Antwort bis `frist` aus und hat die Uhr eine Adresse, wird dort
    /// gelesen; sonst ist es ein Fehler (`NGFehler.keineBildschirmantwort`).
    public func bildschirmLesen(frist: TimeInterval = 5,
                                lauscher: ThemaLauschend = MQTTThemenlauscher()) throws -> Bildschirmauszug {
        switch kanal {
        case .http(let geraet):
            return try geraet.bildschirm()
        case .mqtt(let sender, let zugang, let praefix, let ausweich):
            let antwort = try lauscher.erwarten(thema: NGThema.bildschirm(praefix: praefix),
                                                zugang: zugang, frist: frist) {
                try sender.senden(Data(), an: NGThema.bildschirmAnfordern(praefix: praefix), zugang: zugang)
            }
            if let antwort { return try Bildschirmauszug(daten: antwort) }
            if let ausweich { return try ausweich.bildschirm() }
            throw NGFehler.keineBildschirmantwort
        }
    }
}
