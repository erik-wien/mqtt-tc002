import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Ein Bild oder eine Folge von Bildern, die die App selbst gerastert hat und
/// pixelgenau auf die Uhr bringt. Ein Einzelbild steht, mehrere laufen mit
/// ihren Standzeiten.
public struct Pixelinhalt: Equatable, Sendable {
    public var breite: Int
    public var hoehe: Int
    public var bilder: [Bildraster.Einzelbild]

    public init(breite: Int, hoehe: Int, bilder: [Bildraster.Einzelbild]) {
        self.breite = breite
        self.hoehe = hoehe
        self.bilder = bilder
    }

    public var istBewegt: Bool { bilder.count > 1 }
}

/// Wie eine fertige Nutzlast zur Uhr kommt.
public enum Zustellweg: Equatable, Sendable {
    case mqtt
    /// `PUT /api/v1/apps/pushed/{name}` an die Adresse der Uhr.
    case http
}

/// Der Pixelweg zu AWTRIX NG (`docs/awtrix-ng-protokoll.md` §1.1, §6, §8, §9).
///
/// `draw` direkt in einer Anzeige rechnet bei `enlargeApps` (Vorgabe der Uhr)
/// auf 26 × 8 mit 2 × 2 je Pixel (gemessen 09.10.2026) und taugt nicht fuer
/// pixelgenaue Bilder; die globale Einstellung faesst die App nicht an.
/// Eine `layout`-Region ueber das ganze Raster rechnet dagegen auf 52 × 16:
///
/// - Standbild: `draw` mit einem `bitmap` (Base64-RGB888), rund 3,3 KB.
/// - Bewegtes: `icon` als `data:image/gif;base64,…` mit einem animierten GIF in
///   Rastergroesse; es laeuft mit den Bildzeiten der Datei (beides gemessen
///   09.10.2026, NG 1.2.2, TC002).
///
/// Reine Funktionen: nichts wird gesendet oder gelesen.
public enum Pixelweg {
    /// Mehr Einzelbilder als das gibt es nicht — eine Laufschrift hat rund
    /// 150 bis 250, und eine Zahl aus Fremddaten darf keine Schleife und keinen
    /// Speicher ohne Grenze bestimmen.
    public static let hoechsteBildzahl = 512
    /// Groesste Kante eines Bildes: die breiteste NG-Matrix (`AwtrixNG`).
    public static let hoechsteBreite = 128
    public static let hoechsteHoehe = 16

    /// MQTT-Nachricht samt Thema (§8). Darueber verwirft NG ohne Antwort.
    public static let mqttGrenze = 8192
    /// Rumpf ueber HTTP (§8), `413` darueber.
    public static let httpGrenze = 2 * 1024 * 1024

    /// Die Nutzlast der Anzeige. `dauer` in Sekunden wie bei den Reglern,
    /// gesendet als `durationMs`.
    public static func nutzlast(_ inhalt: Pixelinhalt, dauer: Int?) throws -> String {
        try pruefen(inhalt)
        let b = inhalt.breite, h = inhalt.hoehe
        let kopf = #"{"id":"bild","box":[0,0,\#(b),\#(h)],"#
        let region: String
        if inhalt.bilder.count == 1 {
            let daten = rgb888(inhalt.bilder[0].pixel).base64EncodedString()
            region = kopf + #""draw":[["bitmap",0,0,\#(b),\#(h),"\#(daten)"]]}"#
        } else {
            region = kopf + #""icon":"\#(try gifDatenURI(inhalt))"}"#
        }
        var json = #"{"layout":{"version":1,"regions":[\#(region)]}"#
        if let dauer { json += #","durationMs":\#(dauer * 1000)"# }
        return json + "}"
    }

    /// Mass und Bildzahl, bevor etwas gebaut wird.
    public static func pruefen(_ inhalt: Pixelinhalt) throws {
        guard (1...hoechsteBreite).contains(inhalt.breite), (1...hoechsteHoehe).contains(inhalt.hoehe),
              (1...hoechsteBildzahl).contains(inhalt.bilder.count),
              inhalt.bilder.allSatisfy({ $0.pixel.count == inhalt.breite * inhalt.hoehe }) else {
            throw BildrasterFehler.nichtLesbar
        }
    }

    /// Dunkel ist schwarz: `nil` heisst bei uns „aus", ein `bitmap` kennt keine
    /// Durchsicht.
    static func rgb888(_ pixel: [String?]) -> Data {
        var daten = Data(capacity: pixel.count * 3)
        for farbe in pixel {
            let (r, g, bl) = Bildraster.rgb(farbe)
            daten.append(contentsOf: [r, g, bl])
        }
        return daten
    }

    /// Das animierte GIF. Durchsichtiges wird schwarz gefuellt: Durchsichtige
    /// Pixel zeigen auf NG, was das vorige Bild dort gezeichnet hat (§5.3), und
    /// eine Laufschrift bliebe sonst als Spur stehen.
    static func gifDatenURI(_ inhalt: Pixelinhalt) throws -> String {
        guard let daten = CFDataCreateMutable(nil, 0),
              let senke = CGImageDestinationCreateWithData(daten, UTType.gif.identifier as CFString,
                                                           inhalt.bilder.count, nil)
        else { throw BildrasterFehler.nichtLesbar }
        CGImageDestinationSetProperties(senke, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        for bild in inhalt.bilder {
            let gefuellt = bild.pixel.map { $0 ?? "#000000" }
            let eigenschaften = [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime:
                                                    Bildraster.gifZeit(bild.dauer)]
            ] as CFDictionary
            CGImageDestinationAddImage(
                senke, try Bildraster.cgBild(aus: gefuellt, breite: inhalt.breite, hoehe: inhalt.hoehe),
                eigenschaften)
        }
        guard CGImageDestinationFinalize(senke) else { throw BildrasterFehler.nichtLesbar }
        return "data:image/gif;base64," + (daten as Data).base64EncodedString()
    }

    /// Welchen Weg eine fertige Nutzlast nimmt.
    ///
    /// Ueber MQTT verwirft NG, was samt Thema 8192 Byte uebersteigt, **ohne
    /// Antwort**; dann geht diese eine Anzeige ueber HTTP an dieselbe Uhr. Was
    /// auch dort nicht passt (2 MiB), wird vor dem Senden gemeldet.
    public static func zustellweg(nutzlastBytes: Int, themaBytes: Int,
                                  betriebsart: Betriebsart) throws -> Zustellweg {
        guard nutzlastBytes <= httpGrenze else { throw NGFehler.zuGross(bytes: nutzlastBytes) }
        switch betriebsart {
        case .http: return .http
        case .mqtt: return nutzlastBytes + themaBytes <= mqttGrenze ? .mqtt : .http
        }
    }
}
