import Foundation

/// Die drei Dinge, die man mit einer benannten Anzeige auf der Uhr tun kann.
public struct Anzeigen {
    private let sender: NachrichtSendend
    private let zugang: MQTTZugang
    private let praefix: String

    public init(sender: NachrichtSendend, zugang: MQTTZugang, praefix: String) {
        self.sender = sender
        self.zugang = zugang
        var normalisiert = praefix
        while normalisiert.hasSuffix("/") {
            normalisiert.removeLast()
        }
        self.praefix = normalisiert
    }

    public func zeigen(_ frame: Frame, auf name: String) throws {
        try sender.senden(Data(frame.alsJSON().utf8), an: "\(praefix)/custom/\(name)", zugang: zugang)
    }

    /// Eine leere Nutzlast entfernt die Anzeige vom Geraet.
    public func loeschen(_ name: String) throws {
        try sender.senden(Data(), an: "\(praefix)/custom/\(name)", zugang: zugang)
    }

    public func umschalten(auf name: String) throws {
        try sender.senden(Data(name.utf8), an: "\(praefix)/switchDiyApp", zugang: zugang)
    }
}

extension Anzeigen {
    /// Liest die Anzeigenliste, die die Uhr selbst veroeffentlicht (§3.5):
    /// `{"apps":[{"appName":"scrolltest"}],"count":1}`.
    ///
    /// nil heisst „das war keine lesbare Liste" — etwas anderes als die leere
    /// Liste, die sehr wohl eine Aussage ist: auf der Uhr steht gerade nichts.
    public static func namenAusCustomList(_ daten: Data) -> [String]? {
        guard let objekt = try? JSONSerialization.jsonObject(with: daten),
              let woerterbuch = objekt as? [String: Any],
              let apps = woerterbuch["apps"] as? [[String: Any]] else { return nil }
        return apps.compactMap { $0["appName"] as? String }
    }

    /// Zerlegt eine mitgelesene `custom`-Nutzlast (unser eigenes Format,
    /// `Frame.alsJSON()`) in die 52×16-Pixel, die daraus auf der Uhr staenden.
    ///
    /// Deckt den stehenden Fall ab: `draw` mit Rechtecken. Ein Bild-Weg
    /// (`image`: eine Icon-Bitmap oder ein Lauf-GIF als Daten-URI) und der
    /// Geraeteschrift-Weg (`text`) liefern noch keine Pixel — nil heisst
    /// „nicht zerlegbar", nicht „leer".
    public static func pixelAusCustomNutzlast(_ daten: Data) -> [String?]? {
        guard !daten.isEmpty,
              let objekt = try? JSONSerialization.jsonObject(with: daten),
              let woerterbuch = objekt as? [String: Any],
              let rechtecke = woerterbuch["draw"] as? [[String: Any]] else { return nil }
        var feld = Pixelfeld()
        for rechteck in rechtecke {
            guard let df = rechteck["df"] as? [Any], df.count == 5,
                  let x = df[0] as? Int, let y = df[1] as? Int,
                  let breite = df[2] as? Int, let hoehe = df[3] as? Int,
                  let farbe = df[4] as? String else { continue }
            for dy in 0..<max(0, hoehe) {
                for dx in 0..<max(0, breite) {
                    feld.setzen(x: x + dx, y: y + dy, farbe: farbe)
                }
            }
        }
        return feld.punkteRoh
    }
}

/// Was zuletzt auf einem Slot der Uhr zu sehen war — aus einer mitgelesenen
/// `custom`-Nutzlast gewonnen, nicht von der Uhr erfragt (sie verraet den
/// Inhalt selbst nicht, siehe `namenAusCustomList`).
public struct Slotbild: Equatable, Sendable {
    public var pixel: [String?]
    public var zeitpunkt: Date
    public init(pixel: [String?], zeitpunkt: Date) {
        self.pixel = pixel
        self.zeitpunkt = zeitpunkt
    }
}
