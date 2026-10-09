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

/// Der Pixelweg zu AWTRIX NG (`docs/awtrix-ng-protokoll.md` §1.1, §5.3, §8).
///
/// Alles Gerasterte geht als animiertes oder einbildriges GIF im `icon` der
/// Anzeige hinaus, in **voller Anzeigegroesse der Ziel-Uhr** (`Uhr.anzeigemass`,
/// 52 × 16 der TC002, 32 × 8 der TC001). Gemessen am 09.10.2026 (NG 1.2.2):
///
/// - Ein Icon, das groesser ist als 26 × 8, schaltet die TC002 auf das volle
///   Raster; das GIF landet dort pixelgenau (Eckpixel exakt). Auf der TC001
///   (ESP32) gibt es kein `enlargeApps`, das GIF landet in 32 × 8 ebenso.
/// - `draw`/`bitmap` direkt in der Anzeige ist auf der TC002 2 × 2
///   vergroessert; `layout` gibt es auf dem ESP32 nicht
///   (`422 unknown field`, `capabilities.layout` fehlt). Beide Wege entfallen.
///
/// Ein GIF kleiner als das Anzeigemass waere auf der TC002 vergroessert: Die
/// Masse des Inhalts sind darum immer genau das Anzeigemass.
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

    /// Hoechste GIF-Groesse. Gemessen am 09.10.2026 (NG 1.2.2, TC002, HTTP):
    /// Als `icon` der Anzeige nimmt NG ein GIF bis 58 761 Byte an und weist
    /// eines von 87 KB ab (`field: icon`). 56 KiB liegen darunter.
    public static let hoechsteGIFBytes = 56 * 1024

    /// Bildzeit eines Standbilds im GIF: lang, damit die Uhr nicht vor Ablauf
    /// der Standzeit zum naechsten Bild des GIFs weiterschaltet.
    public static let standbildzeit = 1.0

    /// Die Nutzlast der Anzeige: das GIF als `icon`, ohne Layout. `dauer` in
    /// Sekunden wie bei den Reglern, gesendet als `durationMs`.
    ///
    /// Bei Bewegtem gilt mindestens die Laufzeit eines Durchlaufs als
    /// `durationMs`; die Uhr schneidet sonst nach `appDurationMs` (7000) ab. Eine
    /// laengere Dauer des Nutzers geht vor. Ein Standbild traegt `durationMs`
    /// nur, wenn der Nutzer eine Dauer gewaehlt hat; sonst gilt die der Uhr.
    public static func nutzlast(_ inhalt: Pixelinhalt, dauer: Int?) throws -> String {
        try pruefen(inhalt)
        let uri = try gifDatenURI(inhalt, festeZeit: inhalt.istBewegt ? nil : standbildzeit)
        let bytes = (uri.utf8.count - "data:image/gif;base64,".utf8.count) / 4 * 3
        guard bytes <= hoechsteGIFBytes else { throw NGFehler.laufschriftZuLang(bytes: bytes) }
        var json = #"{"icon":"\#(uri)""#
        if inhalt.istBewegt {
            let durchlauf = Int(inhalt.bilder.reduce(0.0) { $0 + Bildraster.gifZeit($1.dauer) } * 1000)
            json += #","durationMs":\#(max(durchlauf, (dauer ?? 0) * 1000))"#
        } else if let dauer {
            json += #","durationMs":\#(dauer * 1000)"#
        }
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

    /// Das GIF. Durchsichtiges wird schwarz gefuellt: Durchsichtige
    /// Pixel zeigen auf NG, was das vorige Bild dort gezeichnet hat (§5.3), und
    /// eine Laufschrift bliebe sonst als Spur stehen. `festeZeit` ersetzt die
    /// Bildzeiten (Standbild).
    static func gifDatenURI(_ inhalt: Pixelinhalt, festeZeit: Double? = nil) throws -> String {
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
                                                    festeZeit ?? Bildraster.gifZeit(bild.dauer)]
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
