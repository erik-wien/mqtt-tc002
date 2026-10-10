import Foundation

/// Was beim Zusammenstellen eines Steuerbefehls schiefgehen kann, bevor etwas
/// hinausgeht. Die Uhr prüft nicht alles (`brightness` des Moodlights wird
/// nicht geprüft: 300 wird zu 44, 256 zu 0, `docs/awtrix-ng-protokoll.md` §4.2),
/// und über MQTT bliebe ein falscher Wert ohnehin ohne Antwort.
public enum SteuerungsFehler: Error, LocalizedError, Equatable {
    /// Eine Zahl außerhalb ihres Bereichs.
    case ausserhalb(feld: String, wert: String, bereich: String)
    case keineFarbe(feld: String, wert: String)
    case unbekannterName(feld: String, wert: String)
    /// Ein Wert der falschen Art (Text statt Zahl, Zahl statt Ja/Nein …).
    case falscheArt(feld: String, wert: String, erwartet: String)
    /// Ein Befehl ohne jede Angabe.
    case nichtsAngegeben
    /// Farbe und Kelvin zugleich: Die Uhr nimmt Kelvin und überliest die Farbe.
    case farbeUndKelvin
    case unbekannteEinstellung(String)
    /// Ein Schlüssel, den diese App nie schreibt (`enlargeApps`, Zugangsdaten …).
    case gesperrteEinstellung(String)
    /// Ein Schlüssel, den die Uhr nicht beachtet (`autoBrightness` ohne Lichtsensor).
    case wirkungslos(String)
    case ungueltigeKennziffer(Int)
    /// Eine CA-Datei, die kein PEM-Zertifikat ist oder die Grenze überschreitet.
    case ungueltigesZertifikat(String)

    public var errorDescription: String? {
        switch self {
        case .ausserhalb(let feld, let wert, let bereich):
            return lokf("„%@“ ist %@, erlaubt ist %@.", feld, wert, bereich)
        case .keineFarbe(let feld, let wert):
            return lokf("„%@“ erwartet eine Farbe der Form #RRGGBB, bekam aber „%@“.", feld, wert)
        case .unbekannterName(let feld, let wert):
            return lokf("„%@“ kennt die Uhr nicht als „%@“.", wert, feld)
        case .falscheArt(let feld, let wert, let erwartet):
            return lokf("„%@“ erwartet %@, bekam aber „%@“.", feld, erwartet, wert)
        case .nichtsAngegeben:
            return lok("Es ist nichts angegeben, das sich senden ließe.")
        case .farbeUndKelvin:
            return lok("Farbe und Kelvin schließen sich aus: Die Uhr nimmt den Kelvinwert und überliest die Farbe.")
        case .unbekannteEinstellung(let s):
            return lokf("„%@“ ist keine Einstellung, die diese App kennt.", s)
        case .gesperrteEinstellung(let s):
            return lokf("„%@“ stellt diese App nie ein.", s)
        case .wirkungslos(let s):
            return lokf("„%@“ hat auf dieser Uhr keine Wirkung: Sie hat keinen Lichtsensor.", s)
        case .ungueltigeKennziffer(let n):
            return lokf("Es gibt die Anzeiger 1 bis 3, nicht %d.", n)
        case .ungueltigesZertifikat(let grund):
            return lokf("Das Zertifikat taugt nicht: %@", grund)
        }
    }
}

/// Gemeinsame Prüfungen und die Schreibweise der Nutzlasten.
enum Steuerfarbe {
    /// Eine Farbe der Form `#RRGGBB`, wie diese App sie schickt. Die Uhr nähme
    /// noch vier weitere Formen; die App schreibt nur eine, und zwar groß.
    static func pruefen(_ wert: String, feld: String) throws -> String {
        guard wert.hasPrefix("#"), wert.count == 7,
              wert.dropFirst().allSatisfy(\.isHexDigit) else {
            throw SteuerungsFehler.keineFarbe(feld: feld, wert: wert)
        }
        return wert.uppercased()
    }

    static func ganzzahl(_ wert: Int, _ bereich: ClosedRange<Int>, feld: String) throws {
        guard bereich.contains(wert) else {
            throw SteuerungsFehler.ausserhalb(feld: feld, wert: String(wert),
                                              bereich: "\(bereich.lowerBound)–\(bereich.upperBound)")
        }
    }

    /// Ein Objekt mit fester Schlüsselreihenfolge, damit Tests byteweise prüfen.
    static func json(_ paare: [(String, JSONWert)]) -> String {
        "{" + paare.map { "\"\($0.0)\":" + String(decoding: $0.1.daten, as: UTF8.self) }.joined(separator: ",") + "}"
    }
}

/// Das Moodlight: das Panel einfarbig fluten (`PUT /api/v1/display/moodlight`,
/// MQTT `cmd/display/moodlight`, §4.2).
///
/// Farbe **oder** Kelvin, dazu die Helligkeit; fehlende Felder behalten ihren
/// Wert, das erste Mal ist es weiß bei 120. Ohne jede Angabe ist es `422`
/// (HTTP) — und über MQTT würde ein leerer Rumpf das Moodlight ausschalten, das
/// ist `Anzeigen.moodlightAus`.
public struct Moodlight: Equatable, Sendable {
    public static let kelvinBereich = 1000...40000
    /// Die Uhr prüft die Helligkeit nicht (300 → 44, 256 → 0); die App schon.
    public static let helligkeitsbereich = 0...255

    public var farbe: String?
    public var kelvin: Int?
    public var helligkeit: Int?

    public init(farbe: String? = nil, kelvin: Int? = nil, helligkeit: Int? = nil) {
        self.farbe = farbe; self.kelvin = kelvin; self.helligkeit = helligkeit
    }

    public func pruefen() throws {
        guard farbe != nil || kelvin != nil || helligkeit != nil else { throw SteuerungsFehler.nichtsAngegeben }
        if farbe != nil, kelvin != nil { throw SteuerungsFehler.farbeUndKelvin }
        if let farbe { _ = try Steuerfarbe.pruefen(farbe, feld: "color") }
        if let kelvin { try Steuerfarbe.ganzzahl(kelvin, Self.kelvinBereich, feld: "kelvin") }
        if let helligkeit { try Steuerfarbe.ganzzahl(helligkeit, Self.helligkeitsbereich, feld: "brightness") }
    }

    public func json() throws -> String {
        try pruefen()
        var paare: [(String, JSONWert)] = []
        if let farbe { paare.append(("color", .text(try Steuerfarbe.pruefen(farbe, feld: "color")))) }
        if let kelvin { paare.append(("kelvin", .zahl(Double(kelvin)))) }
        if let helligkeit { paare.append(("brightness", .zahl(Double(helligkeit)))) }
        return Steuerfarbe.json(paare)
    }
}

/// Einer der drei Anzeiger am Rand (`PUT /api/v1/indicators/{id}`, §4.2, §3.2):
/// `id` 1–3 von oben nach unten.
///
/// `color` schaltet ein; `blinkMs` und `fadeMs` (0–65535) setzt jede Anfrage
/// neu, fehlende gelten als 0. Ausschalten und zurücksetzen ist
/// `Anzeigen.indikatorAus`.
public struct Indikator: Equatable, Sendable {
    public static let nummern = 1...3
    public static let zeitbereich = 0...65535

    public var nummer: Int
    public var farbe: String
    public var blinkMs: Int
    public var fadeMs: Int

    public init(nummer: Int, farbe: String, blinkMs: Int = 0, fadeMs: Int = 0) {
        self.nummer = nummer; self.farbe = farbe; self.blinkMs = blinkMs; self.fadeMs = fadeMs
    }

    public func pruefen() throws {
        guard Self.nummern.contains(nummer) else { throw SteuerungsFehler.ungueltigeKennziffer(nummer) }
        _ = try Steuerfarbe.pruefen(farbe, feld: "color")
        try Steuerfarbe.ganzzahl(blinkMs, Self.zeitbereich, feld: "blinkMs")
        try Steuerfarbe.ganzzahl(fadeMs, Self.zeitbereich, feld: "fadeMs")
    }

    public func json() throws -> String {
        try pruefen()
        return Steuerfarbe.json([("color", .text(try Steuerfarbe.pruefen(farbe, feld: "color"))),
                                 ("blinkMs", .zahl(Double(blinkMs))), ("fadeMs", .zahl(Double(fadeMs)))])
    }
}

extension NGThema {
    /// `{"power":bool?,"overlay":string|null?}` (§3.2).
    public static func anzeigeSteuern(praefix: String) -> String { "\(praefix)/cmd/display" }
    /// Moodlight setzen; eine leere Nutzlast schaltet es aus.
    public static func moodlight(praefix: String) -> String { "\(praefix)/cmd/display/moodlight" }
    /// Anzeiger 1–3; eine leere Nutzlast setzt zurück. Die Kennziffer muss ein
    /// einzelnes Zeichen `1`, `2` oder `3` sein, alles andere trifft keine Route.
    public static func indikator(praefix: String, nummer: Int) -> String { "\(praefix)/cmd/indicators/\(nummer)" }
    /// Teilmenge der Einstellungen (`PATCH /api/v1/settings`).
    public static func einstellungen(praefix: String) -> String { "\(praefix)/cmd/settings" }

    // Was die Uhr von sich aus veröffentlicht (§3.5).
    public static func zustandGeraet(praefix: String) -> String { "\(praefix)/state/device" }
    public static func zustandEinstellungen(praefix: String) -> String { "\(praefix)/state/settings" }
    public static func zustandAktiveAnzeige(praefix: String) -> String { "\(praefix)/state/apps/active" }
    /// `left`, `select`, `right`, `knob` — `"1"` oder `"0"`.
    public static func zustandTasten(praefix: String) -> String { "\(praefix)/state/buttons/+" }
    public static func ereignisDrehknopf(praefix: String) -> String { "\(praefix)/event/knob" }
    public static func ereignisFehler(praefix: String) -> String { "\(praefix)/event/error" }

    /// Alles, was die App zusätzlich zur Erreichbarkeit mitliest, um den Zustand
    /// jeder Uhr zu führen. Die Themen sind einzeln genannt: Ein Muster auf
    /// `state/#` brächte auch `state/audio` und `state/capabilities` mit, die
    /// niemand liest.
    public static func zustandsthemen(praefix: String) -> [String] {
        [zustandGeraet(praefix: praefix), zustandEinstellungen(praefix: praefix),
         zustandAktiveAnzeige(praefix: praefix), zustandTasten(praefix: praefix),
         ereignisDrehknopf(praefix: praefix), ereignisFehler(praefix: praefix)]
    }
}
