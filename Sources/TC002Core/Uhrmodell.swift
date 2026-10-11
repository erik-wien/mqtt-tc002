import Foundation

/// Das Modell einer Uhr. Es bestimmt die Zeichnung der Vorschau und, bei der
/// selbstgebauten ESP32-Uhr, welche Ausstattung angenommen wird; die
/// Fähigkeiten selbst kommen weiter aus der Antwort der Uhr.
public enum Uhrmodell: String, Codable, CaseIterable, Sendable {
    case tc002, tc001, esp32DIY

    /// Der Name für die Auswahl. Die Bauform gibt es nur als Produkt- bzw.
    /// Eigenbaubezeichnung, die zweite wird übersetzt.
    public var bezeichnung: String {
        switch self {
        case .tc002: return "Ulanzi TC002"
        case .tc001: return "Ulanzi TC001"
        case .esp32DIY: return lok("ESP32 (selbstgebaut)")
        }
    }

    /// Schlägt das Modell aus dem vor, was die Uhr über sich sagt. `nil`, wenn
    /// das nicht reicht: unbekannte Plattform, oder bei einem ESP32 fehlt der
    /// Gerätezustand bzw. sein `ldrRaw`.
    ///
    /// - `platform.id` `tc002`: TC002.
    /// - ESP32 mit Batterie (`Geraetezustand.hatBatterie`) und Lichtsensor
    ///   (`ldrRaw` über 0): TC001 — die Platine der Ulanzi hat beides fest.
    /// - jeder andere ESP32: selbstgebaut.
    ///
    /// Gemessen 11. Oktober 2026 (NG 1.2.2): `platform.id` und `boardType` sind
    /// bei TC001 und Eigenbau gleich, `capabilities.sensors.light` ist auf jedem
    /// ESP32 `true` und taugt nicht; `ldrRaw` ist ohne Fotowiderstand genau 0.
    public static func vorschlag(faehigkeiten: Geraetefaehigkeiten?, zustand: Geraetezustand?) -> Uhrmodell? {
        switch faehigkeiten?.plattform {
        case "tc002": return .tc002
        case "esp32":
            guard let zustand, let ldr = zustand.ldrRoh else { return nil }
            return zustand.hatBatterie && ldr > 0 ? .tc001 : .esp32DIY
        default: return nil
        }
    }
}

/// Was eine Uhr an Bauteilen hat, soweit sie es verrät — für die Anzeige bei
/// der selbstgebauten Uhr. `nil` heißt „nicht bekannt" (noch nicht abgefragt).
public struct Ausstattung: Equatable, Sendable {
    public var anzeige: Anzeigemass
    public var akku: Bool?
    public var lichtsensor: Bool?
    public var temperatur: Bool?
    public var feuchte: Bool?
    public var mp3Player: Bool?

    /// Der Akku steht für `Geraetezustand.hatBatterie`, der Lichtsensor für
    /// `ldrRaw` über 0 (bei der Eigenbauuhr; ein Sensor in völliger Dunkelheit
    /// kann 0 lesen und gälte dann als fehlend), Temperatur und Feuchte für
    /// ihren Schlüssel in `/api/v1/device`, der MP3-Player für `audio.mp3`.
    public init(uhr: Uhr, zustand: Geraetezustand?, faehigkeiten: Geraetefaehigkeiten?) {
        anzeige = Anzeigemass.fuer(uhr)
        akku = zustand?.hatBatterie
        lichtsensor = zustand?.ldrRoh.map { $0 > 0 }
        temperatur = zustand.map { $0.temperatur != nil }
        feuchte = zustand.map { $0.feuchte != nil }
        mp3Player = faehigkeiten?.tonGemeldet?.mp3
    }
}
