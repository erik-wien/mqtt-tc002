import Foundation

/// Der Stand einer Verbindung der Uhr (`wifi` und `mqtt` in `GET /api/v1/device`,
/// §7.1): beide haben dieselben Schlüssel.
public struct Verbindungsstand: Equatable, Sendable {
    public var aktiv: Bool
    /// `disabled`, `offline`, `connecting`, `connected`.
    public var zustand: String
    /// `null`, solange verbunden.
    public var fehler: String?
    public var letzterFehler: String?
    public var versuche: Int

    init?(_ wert: Any?) {
        guard let o = wert as? [String: Any], let z = o["state"] as? String else { return nil }
        aktiv = o["enabled"] as? Bool ?? false
        zustand = z
        fehler = o["error"] as? String
        letzterFehler = o["lastError"] as? String
        versuche = o["attempts"] as? Int ?? 0
    }

    public var verbunden: Bool { zustand == "connected" }
}

public struct Indikatorstand: Equatable, Sendable {
    public var an: Bool
    public var farbe: String
    public var blinkMs: Int
    public var fadeMs: Int

    public init(an: Bool, farbe: String, blinkMs: Int, fadeMs: Int) {
        self.an = an; self.farbe = farbe; self.blinkMs = blinkMs; self.fadeMs = fadeMs
    }
}

/// Was die Uhr über sich sagt (`GET /api/v1/device` und `<P>/state/device`,
/// dieselbe Form, §7.1) — ohne Kennungen, Adressen und Namen: die braucht die
/// Steuerung nicht, und sie gehören nicht in einen Zustand, der in Protokolle
/// wandert.
///
/// Felder, die fehlen können (Batterie, Stromversorgung), sind `nil`.
public struct Geraetezustand: Equatable, Sendable {
    public enum Fehler: Error, LocalizedError, Equatable {
        case unlesbar
        public var errorDescription: String? { lok("Die Uhr hat keinen lesbaren Zustand geliefert.") }
    }

    public var fassung: String?
    public var platine: String?
    public var wlanSignal: Int?
    public var laufzeitSekunden: Int?
    /// Der gerade benutzte Wert, 0–255.
    public var helligkeit: Int?
    /// `matrixPower`: ob das Panel Strom hat.
    public var panelAn: Bool?
    public var aktiveAnzeige: String?
    public var indikatoren: [Indikatorstand]
    public var batterieProzent: Int?
    public var batterieSchwach: Bool?
    public var usbStrom: Bool?
    public var nachrichten: Int?
    public var wlan: Verbindungsstand?
    public var mqtt: Verbindungsstand?

    public init(daten: Data) throws {
        guard let o = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any] else {
            throw Fehler.unlesbar
        }
        fassung = o["version"] as? String
        platine = o["boardType"] as? String
        wlanSignal = o["wifiRssi"] as? Int
        laufzeitSekunden = o["uptimeSeconds"] as? Int
        helligkeit = o["brightness"] as? Int
        panelAn = o["matrixPower"] as? Bool
        aktiveAnzeige = o["currentApp"] as? String
        indikatoren = (o["indicators"] as? [[String: Any]] ?? []).map {
            Indikatorstand(an: $0["on"] as? Bool ?? false, farbe: $0["color"] as? String ?? "#000000",
                           blinkMs: $0["blinkMs"] as? Int ?? 0, fadeMs: $0["fadeMs"] as? Int ?? 0)
        }
        batterieProzent = o["batteryPercent"] as? Int
        batterieSchwach = o["lowBattery"] as? Bool
        usbStrom = o["usbPower"] as? Bool
        nachrichten = o["messageCount"] as? Int
        wlan = Verbindungsstand(o["wifi"])
        mqtt = Verbindungsstand(o["mqtt"])
    }
}

/// `{color, brightness}` des laufenden Moodlights (`GET /api/v1/display`, §7.5).
public struct Moodlightstand: Equatable, Sendable {
    /// `#RRGGBB`. ❓ Die Doku nennt die Schreibweise nicht; eine gepackte Ganzzahl
    /// wird in diese Form gebracht.
    public var farbe: String
    public var helligkeit: Int

    public init(farbe: String, helligkeit: Int) { self.farbe = farbe; self.helligkeit = helligkeit }
}

/// `GET /api/v1/display` (§7.5): Strom, Helligkeit, Overlay, Moodlight.
public struct Anzeigestand: Equatable, Sendable {
    public var an: Bool
    public var helligkeit: Int
    public var overlay: String?
    public var moodlight: Moodlightstand?

    public init(daten: Data) throws {
        guard let o = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any],
              let an = o["power"] as? Bool, let h = o["brightness"] as? Int else {
            throw Geraetezustand.Fehler.unlesbar
        }
        self.an = an; helligkeit = h
        let ov = o["overlay"] as? String
        overlay = (ov?.isEmpty ?? true) ? nil : ov
        if let m = o["moodlight"] as? [String: Any], let b = m["brightness"] as? Int {
            let farbe: String?
            if let t = m["color"] as? String { farbe = t }
            else if let n = m["color"] as? Int, (0...0xFFFFFF).contains(n) { farbe = String(format: "#%06X", n) }
            else { farbe = nil }
            moodlight = farbe.map { Moodlightstand(farbe: $0, helligkeit: b) }
        }
    }
}

/// `GET /api/v1/mqtt/tls` (§11.1): wie die Uhr dem Broker vertraut.
///
/// ❓ Gemessen ist nur `{"ca":"public","pending":null}`. Welche Werte `ca` sonst
/// annimmt, was `pending` bedeutet und unter welchem Schlüssel der SHA-256-
/// Fingerabdruck steht, nennt die Doku nicht; deshalb bleibt `ca` ein Wort und
/// `pending` ein Text, und `roh` trägt die ganze Antwort.
public struct TLSStatus: Equatable, Sendable {
    public var ca: String
    public var pending: String?
    public var roh: JSONWert

    public init(daten: Data) throws {
        guard case .objekt(let o)? = JSONWert.lesen(daten), case .text(let ca)? = o["ca"] else {
            throw Geraetezustand.Fehler.unlesbar
        }
        self.ca = ca
        switch o["pending"] {
        case nil, .null?: pending = nil
        case .text(let t)?: pending = t
        case let w?: pending = Einstellungsart.kurz(w)
        }
        roh = .objekt(o)
    }

    /// Die Uhr vertraut öffentlichen Zertifizierungsstellen und hat keine eigene
    /// CA. ❓ Nur der Wert `public` ist gemessen.
    public var oeffentlich: Bool { ca == "public" }
}

/// Eine der Tasten oder der Knopf des Drehknopfs (`state/buttons/*`, §3.5).
public enum Taste: String, Equatable, Sendable, CaseIterable {
    case links = "left", mitte = "select", rechts = "right", knopf = "knob"
}

/// Eine Abweisung, die die Uhr auf `<P>/event/error` meldet (§3.4): für jedes
/// abgewiesene Kommando, über MQTT wie über HTTP.
public struct Uhrenfehler: Equatable, Sendable {
    /// `mqtt` oder `http`.
    public var quelle: String
    public var anfrage: String
    /// ❓ Ob `error` ein Wort oder der Fehlerrumpf ist, steht nicht da; ein Objekt
    /// wird als `code (feld)` zusammengefasst.
    public var fehler: String
}

/// Was die Uhr von sich aus veröffentlicht und die App mitliest.
public enum Uhrenereignis: Equatable, Sendable {
    case geraet(Geraetezustand)
    case einstellungen(Geraeteeinstellungen)
    case aktiveAnzeige(String)
    case taste(Taste, gedrueckt: Bool)
    /// `{"turn":N}`, positiv im Uhrzeigersinn; schnelles Drehen bündelt Rasten.
    case drehknopf(Int)
    case fehler(Uhrenfehler)

    /// Liest eine Nachricht auf einem der `NGThema.zustandsthemen`. `nil` für alles
    /// andere — auch für eine Nutzlast, die nicht lesbar ist.
    public static func lesen(thema: String, nutzlast: Data, praefix: String) -> Uhrenereignis? {
        let text = String(decoding: nutzlast, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        switch thema {
        case NGThema.zustandGeraet(praefix: praefix):
            return (try? Geraetezustand(daten: nutzlast)).map(Uhrenereignis.geraet)
        case NGThema.zustandEinstellungen(praefix: praefix):
            return (try? Geraeteeinstellungen(daten: nutzlast)).map(Uhrenereignis.einstellungen)
        case NGThema.zustandAktiveAnzeige(praefix: praefix):
            // Eine blanke Zeichenkette, kein JSON.
            return text.isEmpty ? nil : .aktiveAnzeige(text)
        case NGThema.ereignisDrehknopf(praefix: praefix):
            guard case .objekt(let o)? = JSONWert.lesen(nutzlast), let n = o["turn"]?.ganzzahl else { return nil }
            return .drehknopf(n)
        case NGThema.ereignisFehler(praefix: praefix):
            guard case .objekt(let o)? = JSONWert.lesen(nutzlast) else { return nil }
            func wort(_ w: JSONWert?) -> String {
                switch w {
                case nil, .null?: return ""
                case .text(let t)?: return t
                case .objekt(let e)?:
                    if case .text(let code)? = e["code"] {
                        if case .text(let feld)? = e["field"], !feld.isEmpty { return "\(code) (\(feld))" }
                        return code
                    }
                    return Einstellungsart.kurz(.objekt(e))
                case let w?: return Einstellungsart.kurz(w)
                }
            }
            return .fehler(Uhrenfehler(quelle: wort(o["source"]), anfrage: wort(o["request"]),
                                       fehler: wort(o["error"])))
        default:
            let vorsilbe = "\(praefix)/state/buttons/"
            guard thema.hasPrefix(vorsilbe), let taste = Taste(rawValue: String(thema.dropFirst(vorsilbe.count))),
                  text == "1" || text == "0" else { return nil }
            return .taste(taste, gedrueckt: text == "1")
        }
    }
}

extension Geraet {
    /// `GET /api/v1/device` (§7.1).
    public func geraetezustand() throws -> Geraetezustand {
        try parsen("/api/v1/device") { try Geraetezustand(daten: $0) }
    }

    /// `GET /api/v1/display` (§7.5).
    public func anzeigestand() throws -> Anzeigestand {
        try parsen("/api/v1/display") { try Anzeigestand(daten: $0) }
    }

    /// `GET /api/v1/settings` (§10).
    public func einstellungen() throws -> Geraeteeinstellungen {
        try parsen("/api/v1/settings") { try Geraeteeinstellungen(daten: $0) }
    }

    /// `GET /api/v1/mqtt/tls` (§11.1). `404`, wenn die Uhr es nicht kann
    /// (`capabilities.mqttTls`).
    public func tlsStatus() throws -> TLSStatus {
        try parsen("/api/v1/mqtt/tls") { try TLSStatus(daten: $0) }
    }

    private func parsen<T>(_ pfad: String, _ lesen: (Data) throws -> T) throws -> T {
        let daten = try self.lesen(pfad)
        do { return try lesen(daten) } catch { throw GeraetFehler.unerwarteteAntwort(pfad) }
    }

    /// `PATCH /api/v1/display`: Strom und Overlay, alles oder nichts.
    func anzeigeAendern(_ json: String) throws {
        try ngAnfrage("PATCH", "/api/v1/display", koerper: Data(json.utf8))
    }

    func moodlightSetzen(_ json: String) throws {
        try ngAnfrage("PUT", "/api/v1/display/moodlight", koerper: Data(json.utf8))
    }

    func moodlightAus() throws {
        try ngAnfrage("DELETE", "/api/v1/display/moodlight", koerper: nil)
    }

    func indikatorSetzen(nummer: Int, json: String) throws {
        try ngAnfrage("PUT", "/api/v1/indicators/\(nummer)", koerper: Data(json.utf8))
    }

    func indikatorAus(nummer: Int) throws {
        try ngAnfrage("DELETE", "/api/v1/indicators/\(nummer)", koerper: nil)
    }

    func einstellungenAendern(_ json: String) throws {
        try ngAnfrage("PATCH", "/api/v1/settings", koerper: Data(json.utf8))
    }

    /// Lädt die CA des Brokers hoch (`PUT /api/v1/mqtt/tls/ca`, §11.1) und
    /// liefert den Stand danach, falls die Antwort einer ist (❓ die Doku nennt
    /// die Antwort des `PUT` nicht).
    @discardableResult
    public func tlsCAHochladen(pem: String) throws -> TLSStatus? {
        try TLSZertifikat.pruefen(pem: pem)
        let rumpf = Steuerfarbe.json([("certificate", .text(pem))])
        return try? TLSStatus(daten: ngAnfrage("PUT", "/api/v1/mqtt/tls/ca", koerper: Data(rumpf.utf8)))
    }

    /// Entfernt die hochgeladene CA; die Uhr „antwortet mit dem Stand“.
    @discardableResult
    public func tlsCAEntfernen() throws -> TLSStatus? {
        try? TLSStatus(daten: ngAnfrage("DELETE", "/api/v1/mqtt/tls/ca", koerper: nil))
    }
}

/// Die Prüfung vor dem Hochladen einer CA. Die Uhr nennt als Grenze 65536 Byte
/// (`422`); dass sie einen PEM-Block verlangt, ist ❓ angenommen — ein Rumpf ohne
/// den Kopf wäre in jedem Fall kein Zertifikat.
public enum TLSZertifikat {
    public static let hoechstGroesse = 65536

    public static func pruefen(pem: String) throws {
        guard pem.utf8.count <= hoechstGroesse else {
            throw SteuerungsFehler.ungueltigesZertifikat(
                lokf("%d Byte, höchstens %d", pem.utf8.count, hoechstGroesse))
        }
        guard pem.contains("-----BEGIN CERTIFICATE-----"), pem.contains("-----END CERTIFICATE-----") else {
            throw SteuerungsFehler.ungueltigesZertifikat(lok("kein PEM-Zertifikat („-----BEGIN CERTIFICATE-----“)"))
        }
    }
}
