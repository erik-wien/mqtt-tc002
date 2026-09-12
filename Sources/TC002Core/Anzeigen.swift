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

/// Was die App über einen der fünf festen Plätze weiß — nicht zwei bequeme
/// Fälle, sondern drei ehrliche (Entwurf, Abschnitt „Drei Zustände je Block“).
///
/// Die Uhr verrät über `customList` nur **Namen**, nie den Inhalt. Belegt
/// oder frei ist damit Tatsache; was darauf steht, weiß die App nur, wenn sie
/// die Sendung mitgelesen hat oder sich die Regler gemerkt hat:
///
/// - `.frei` — kein Name auf diesem Platz.
/// - `.bekannt(punkte)` — ein Name ist da, und die App hat ein Bild dazu.
///   `punkte` sind die 52×16 Pixel in derselben Form, die
///   `Meldungsbau.feld(...).punkteRoh` liefert — genau diese Form gibt auch
///   das Zerlegen einer mitgelesenen Nutzlast zurück. **Woher** das Bild
///   stammt, steht nicht mehr darin: mitgelesen (Tatsache) oder aus dem
///   Slotgedächtnis neu gerechnet (Erinnerung). Wer darauf angewiesen ist,
///   fragt das Gedächtnis und die Prüfsumme selbst — siehe `slotWaehlen` in
///   den Sendeansichten.
/// - `.unbekannt` — ein Name ist da, aber die App weiß nicht, was darauf
///   steht (nie mitgelesen und nichts gemerkt, oder ein Weg, der sich nicht
///   zerlegen lässt, z. B. ein Lauf-GIF eines fremden Absenders). Das ist
///   keine Lücke, sondern die Auskunft: ein Block, der hier einen Inhalt
///   zeigte, behauptete etwas, das niemand mehr belegen kann.
///
/// Warum ein Platz `.unbekannt` ist, steht nicht hier — das sagt die Hilfe.
///
/// Liegt im Kern und nicht bei `Slotblock`, weil beide Seiten ihn brauchen:
/// `AppZustand.slotzustand(_:belegt:)` entscheidet ihn, `Slotblock` zeigt ihn.
public enum Slotzustand: Equatable, Sendable {
    case frei
    case bekannt([String?])
    case unbekannt
}
