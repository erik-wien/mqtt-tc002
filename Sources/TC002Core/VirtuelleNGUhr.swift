import Foundation

/// Ein JSON-Wert, der sich vergleichen und über Threads reichen lässt. Hält
/// den Zustand der virtuellen NG-Uhr (`[String: Any]` wäre weder `Equatable`
/// noch `Sendable`) und unterscheidet Wahrheitswerte sauber von Zahlen.
public enum JSONWert: Equatable, Sendable, Codable {
    case null
    case bool(Bool)
    case zahl(Double)
    case text(String)
    case liste([JSONWert])
    case objekt([String: JSONWert])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let w = try? c.decode(Bool.self) { self = .bool(w) }
        else if let w = try? c.decode(Double.self) { self = .zahl(w) }
        else if let w = try? c.decode(String.self) { self = .text(w) }
        else if let w = try? c.decode([JSONWert].self) { self = .liste(w) }
        else { self = .objekt(try c.decode([String: JSONWert].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let w): try c.encode(w)
        case .zahl(let w):
            // Ganze Zahlen ohne Nachkommastelle, wie die Firmware sie schreibt.
            if w == w.rounded(), abs(w) < 1e15 { try c.encode(Int(w)) } else { try c.encode(w) }
        case .text(let w): try c.encode(w)
        case .liste(let w): try c.encode(w)
        case .objekt(let w): try c.encode(w)
        }
    }

    /// `nil`, wenn `daten` kein JSON ist.
    static func lesen(_ daten: Data) -> JSONWert? {
        try? JSONDecoder().decode(JSONWert.self, from: daten)
    }

    var daten: Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? e.encode(self)) ?? Data("null".utf8)
    }

    var ganzzahl: Int? {
        if case .zahl(let w) = self, w == w.rounded(), abs(w) < 1e15 { return Int(w) }
        return nil
    }
}

/// Eine Benachrichtigung in der Warteschlange: die Nutzlast, wie sie kam, und
/// ihr Name, falls sie einen trägt (nur darüber lässt sie sich zurückziehen).
public struct NGBenachrichtigung: Equatable, Sendable {
    public var name: String?
    public var nutzlast: [String: JSONWert]
}

/// Eine App in der Liste der NG-Uhr. `nutzlast` ist bei eingebauten Apps `nil`.
public struct NGApp: Equatable, Sendable {
    public var name: String
    public var aktiv: Bool
    public var eingebaut: Bool
    public var nutzlast: JSONWert?
}

public struct NGIndikator: Equatable, Sendable {
    public var an = false
    /// `#RRGGBB`. Bleibt beim Ausschalten stehen, wie in der Firmware.
    public var farbe = "#000000"
    public var blinkMs = 0
    public var fadeMs = 0
}

/// Der Zustand einer AWTRIX-NG-1.2.2-Uhr (TC002, 52×16), so weit die HTTP-
/// Schnittstelle ihn berührt. Vorgabewerte stammen aus einer Messung an einer
/// echten Uhr, Kennungen sind durch erfundene ersetzt.
public struct NGUhrzustand: Equatable, Sendable {
    public var einstellungen: [String: JSONWert]
    public var power = true
    public var overlay: String?
    public var overlaySettings: [String: JSONWert] =
        ["speed": .zahl(1), "palette": .null, "blend": .bool(true)]
    public var apps: [NGApp] = [
        NGApp(name: "Time", aktiv: true, eingebaut: true, nutzlast: nil),
        NGApp(name: "Status", aktiv: true, eingebaut: true, nutzlast: nil),
    ]
    public var aktiveApp = "Time"
    public var indikatoren = [NGIndikator](repeating: NGIndikator(), count: 3)
    /// Die erste ist die, die gerade zu sehen wäre.
    public var benachrichtigungen: [NGBenachrichtigung] = []

    public init() {
        einstellungen = VirtuelleNGUhr.vorgabeEinstellungen
    }

    var helligkeit: Int { einstellungen["brightness"]?.ganzzahl ?? 128 }
}

/// Beantwortet die HTTP-Anfragen einer AWTRIX-NG-1.2.2-Uhr auf der TC002 — als
/// reine Funktion, Gegenstück zu `Virtuelleuhr` (Werksfirmware). Fehlerform,
/// Statuscodes und Meldungen folgen der Herstellerdoku (`reference/errors`).
///
/// Gehalten wird nur der Zustand, damit sich die Wirkung eines Aufrufs prüfen
/// lässt. Gerendert wird nicht: `display/screen` liefert ein schwarzes Bild.
///
/// Bewusst nicht geprüft:
/// - Inhalt einer App- oder Benachrichtigungsnutzlast über „gültiges JSON-
///   Objekt“ hinaus (Schlüssel, Farben, Töne, Schriften),
/// - Wertebereiche der Einstellungen außer `brightness` (0–255); sonst nur
///   Schlüssel und Typ,
/// - Authentifizierung, `X-HTTP-Method-Override`, Setup-Modus, Anfragen
///   mit `HEAD`/`OPTIONS`,
/// - `Content-Type` bei `PUT /apps/active` und `PUT /apps/{name}/enabled`:
///   Dort ist der Rumpf ein bloßer Name bzw. `true`/`false`,
/// - unbekannte Schlüssel in `PATCH /display` (werden überlesen).
///
/// Fundstellen (Herstellerdoku `tc002/reference/`):
/// - `http`, Apps › PUT pushed: ein Array legt `{name}0`, `{name}1` … an;
/// - `http`, Settings › PATCH: Antwort ist `200` mit allen Einstellungen;
/// - `http`, Apps › PUT active: ein kaputter JSON-Rumpf wird als Name gelesen
///   und ergibt `404 app not found`;
/// - `http`, Apps › Names: ungültiger App-Name ist `400 invalidName` mit
///   `field: "name"`;
/// - `limits`: 32 Benachrichtigungen einschließlich der angezeigten, bei
///   `stack: true` (Vorgabe) und voller Schlange `507`, `stack: false` ersetzt
///   die angezeigte; 50 Push-Apps, gezählt werden nur neue Namen, ein Array
///   gilt ganz oder gar nicht;
/// - `conventions`: die fünf Farbformen (siehe `farbe(_:)`).
///
/// Annahmen der Emulation, wo die Doku schweigt:
/// - `PUT /apps/{name}/enabled` auf eine unbekannte App ist `404 app not found`;
/// - ein einzelnes Objekt ersetzt nur die App `{name}`, ein Array zusätzlich
///   `{name}0`, `{name}1` …;
/// - Einstellungen: ein Wert mit anderem Typ als die Vorgabe ist
///   `422 wrong type`; `null`-Vorgaben nehmen jeden Typ.
public enum VirtuelleNGUhr {
    public typealias Anfrage = Virtuelleuhr.Anfrage
    public typealias Antwort = Virtuelleuhr.Antwort

    /// Rumpfgrenze der Firmware.
    public static let maxRumpf = 2 * 1024 * 1024
    static let maxPushApps = 50
    /// Einschließlich der gerade angezeigten (`reference/limits`).
    static let maxWarteschlange = 32

    // MARK: - Vorgaben (Messung NG 1.2.2, TC002)

    static let vorgabeEinstellungen: [String: JSONWert] = lesenStatisch(#"""
    {"autoBrightness":false,"brightness":128,"autoTransition":true,"textColor":"#FFFFFF","transitionEffect":"Rain","transitionDirection":"normal","transitionDurationMs":1000,"appDurationMs":7000,"timeMode":1,"calendarHeaderColor":"#FF0000","calendarTextColor":"#000000","calendarBodyColor":"#FFFFFF","time24h":true,"timeLeadingZero":true,"timeShowSeconds":false,"timeShowAmPm":false,"timeSeparatorMode":"pulse","dateOrder":"dayMonthYear","dateSeparator":"dot","dateYearMode":"twoDigit","dateShowWeekday":false,"dateMonthNames":false,"useCelsius":true,"blockNavigation":false,"uppercase":true,"timeColor":null,"dateColor":null,"humidityColor":null,"temperatureColor":null,"batteryColor":null,"volume":100,"radioVolume":80,"appVolume":100,"alertVolume":100,"saturation":100,"gamma":1.899999976,"colorCorrection":null,"colorTint":null,"clockFace":"sheet","musicSource":"auto","calendarAnimation":true,"bootSound":true,"enlargeApps":true,"scroll":{"mode":"wrap","direction":"left","entry":"inline","whenFits":"static","speed":100,"gap":8,"holdMs":1000},"weekdayBar":{"show":true,"startOnMonday":true,"weekendDays":["sunday","saturday"],"activeColor":"#FFFFFF","inactiveColor":"#666666","weekendActiveColor":"#FFFFFF","weekendInactiveColor":"#666666"},"dateWeekdayBar":{"show":true,"startOnMonday":true,"weekendDays":["sunday","saturday"],"activeColor":"#FFFFFF","inactiveColor":"#666666","weekendActiveColor":"#FFFFFF","weekendInactiveColor":"#666666"}}
    """#)

    static let capabilities: JSONWert = lesenWert(#"""
    {"effects":["BrickBreaker","Checkerboard","ColorWaves","Fade","Fireworks","LookingEyes","Matrix","MovingLine","Pacifica","PingPong","Plasma","PlasmaCloud","Radar","Ripple","Snake","SwirlIn","SwirlOut","TheaterChase","TwinklingStars"],"paletteEffects":["BrickBreaker","Checkerboard","ColorWaves","Fade","Fireworks","MovingLine","Pacifica","Plasma","PlasmaCloud","Radar","Ripple","Snake","SwirlIn","SwirlOut","TheaterChase","TwinklingStars"],"transitions":["Random","Slide","Dim","Zoom","Rotate","Pixelate","Curtain","Ripple","Blink","Reload","Fade","Cover","Uncover","Split","Blinds","Blocks","Flash","Diamond","Wave","Rain","Melt","Interlace"],"overlays":["drizzle","frost","rain","snow","storm","thunder"],"palettes":["Cloud","Lava","Ocean","Forest","Stripe","Party","Heat","Rainbow"],"audio":{"mp3":true,"rtttl":true,"song":true,"speech":true,"track":false,"radio":true,"url":true,"effect":true,"clip":true},"microphone":true,"scriptUpdates":true,"gpio":null,"platform":{"id":"tc002"},"sensors":{"light":false},"display":{"width":52,"height":16,"configurable":false,"requestedWidth":52,"requestedHeight":16,"restartRequired":false,"ready":true,"minWidth":52,"maxWidth":52,"minHeight":16,"maxHeight":16,"maxPixels":832},"fonts":[{"name":"small","ascent":6,"descent":1,"lineHeight":7},{"name":"large","ascent":6,"descent":2,"lineHeight":9},{"name":"matrix-chunky6","ascent":6,"descent":0,"lineHeight":6},{"name":"matrix-chunky6x","ascent":6,"descent":0,"lineHeight":6},{"name":"matrix-light6","ascent":6,"descent":0,"lineHeight":6},{"name":"matrix-light6x","ascent":6,"descent":0,"lineHeight":6},{"name":"matrix-chunky8","ascent":8,"descent":0,"lineHeight":8},{"name":"matrix-chunky8x","ascent":8,"descent":0,"lineHeight":8},{"name":"matrix-chunky8x6","ascent":8,"descent":0,"lineHeight":8},{"name":"matrix-light8","ascent":8,"descent":0,"lineHeight":8},{"name":"matrix-light8x","ascent":8,"descent":0,"lineHeight":8},{"name":"matrix-light8x6","ascent":8,"descent":0,"lineHeight":8}],"ble":true,"gamepad":true,"oauth":true,"crypto":true,"tcp":true,"layout":true,"layouts":{"version":1,"limits":{"regions":16,"scrollers":8,"assets":4,"chartPoints":128,"textBytes":8192,"preparedBytes":262144,"scriptHandles":8,"scriptHandlesPerScript":4}},"gamepadRemote":true,"voice":true,"clockFaces":["sheet","ring","flap","month","big"],"mqttTls":true,"bootSound":true,"enlargeApps":true}
    """#)

    static let audio: JSONWert = lesenWert(#"""
    {"radio":{"playing":false,"station":"","title":"","error":"","underruns":0,"decodeUs":0,"starvedMs":0,"bufferBytes":0},"app":{"playing":false,"name":"","error":""},"alert":{"playing":false,"name":"","error":""},"stations":[{"name":"Fm4","url":"http://orf-live.ors-shoutcast.at/fm4-q2a"}]}
    """#)

    private static func lesenWert(_ text: String) -> JSONWert {
        JSONWert.lesen(Data(text.utf8)) ?? .null
    }

    private static func lesenStatisch(_ text: String) -> [String: JSONWert] {
        if case .objekt(let o) = lesenWert(text) { return o }
        return [:]
    }

    // MARK: - Antworten

    static func json(_ wert: JSONWert, status: Int = 200) -> Antwort {
        Antwort(status: status, koerper: wert.daten)
    }

    static let ok = json(.objekt(["ok": .bool(true)]))

    static func fehler(_ status: Int, _ code: String, _ meldung: String,
                       feld: String? = nil) -> Antwort {
        var inhalt: [String: JSONWert] = ["code": .text(code), "message": .text(meldung)]
        if let feld { inhalt["field"] = .text(feld) }
        return json(.objekt(["error": .objekt(inhalt)]), status: status)
    }

    static func ungueltig(_ meldung: String, feld: String? = nil) -> Antwort {
        fehler(422, "validationFailed", meldung, feld: feld)
    }

    static let keinJSON = fehler(400, "invalidJson", "invalid JSON")
    static let appFehlt = fehler(404, "notFound", "app not found")

    // MARK: - Routen

    private enum Route {
        case geraet, version, einstellungen, anzeige, bildschirm, apps, faehigkeiten, ton
        case appSenden(String), appLoeschen(String), appAktiv, appWeiter, appZurueck
        case appFreigabe(String)
        case meldungSenden, meldungAktivLoeschen, meldungLoeschen(String)
        case indikator(String)

        var methoden: [String] {
            switch self {
            case .geraet, .version, .bildschirm, .apps, .faehigkeiten, .ton: return ["GET"]
            case .einstellungen, .anzeige: return ["GET", "PATCH"]
            case .appSenden, .appAktiv, .appFreigabe: return ["PUT"]
            case .appLoeschen, .meldungAktivLoeschen, .meldungLoeschen: return ["DELETE"]
            case .appWeiter, .appZurueck, .meldungSenden: return ["POST"]
            case .indikator: return ["PUT", "DELETE"]
            }
        }
    }

    private static func route(_ pfad: String) -> Route? {
        let teile = pfad.components(separatedBy: "/")
        guard teile.count >= 4, teile[0].isEmpty, teile[1] == "api", teile[2] == "v1" else { return nil }
        let r = Array(teile[3...])
        switch (r.count, r[0]) {
        case (1, "device"): return .geraet
        case (1, "version"): return .version
        case (1, "settings"): return .einstellungen
        case (1, "display"): return .anzeige
        case (1, "apps"): return .apps
        case (1, "capabilities"): return .faehigkeiten
        case (1, "audio"): return .ton
        case (1, "notifications"): return .meldungSenden
        case (2, "display") where r[1] == "screen": return .bildschirm
        case (2, "apps"):
            switch r[1] {
            case "active": return .appAktiv
            case "next": return .appWeiter
            case "previous": return .appZurueck
            default: return .appLoeschen(r[1])
            }
        case (3, "apps") where r[1] == "pushed": return .appSenden(r[2])
        case (3, "apps") where r[2] == "enabled": return .appFreigabe(r[1])
        case (2, "notifications"):
            return r[1] == "active" ? .meldungAktivLoeschen : .meldungLoeschen(r[1])
        case (2, "indicators"): return .indikator(r[1])
        default: return nil
        }
    }

    public static func beantworten(_ anfrage: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let route = route(anfrage.pfad) else {
            return fehler(404, "notFound", "unknown route")
        }
        guard route.methoden.contains(anfrage.methode) else {
            return fehler(405, "methodNotAllowed", "allowed: " + route.methoden.joined(separator: ", "))
        }
        if anfrage.koerper.count > maxRumpf {
            return fehler(413, "payloadTooLarge", "payload too large")
        }
        if ["PUT", "PATCH"].contains(anfrage.methode), erwartetJSON(route) {
            let typ = anfrage.kopf["content-type"]?.lowercased() ?? ""
            guard typ.hasPrefix("application/json") else {
                return fehler(415, "unsupportedMediaType", "expected application/json")
            }
        }

        switch route {
        case .geraet: return json(geraet(z))
        case .version: return json(.objekt(["version": .text("1.2.2")]))
        case .einstellungen:
            return anfrage.methode == "GET" ? json(.objekt(z.einstellungen)) : einstellungenAendern(anfrage, &z)
        case .anzeige:
            return anfrage.methode == "GET" ? json(anzeige(z)) : anzeigeAendern(anfrage, &z)
        case .bildschirm:
            let punkte = Array(repeating: "0", count: 832).joined(separator: ",")
            return Antwort(koerper: Data(#"{"width":52,"height":16,"pixels":[\#(punkte)]}"#.utf8))
        case .apps: return json(.liste(z.apps.map(appEintrag)))
        case .faehigkeiten: return json(capabilities)
        case .ton: return json(audio)
        case .appSenden(let name): return appSenden(name, anfrage, &z)
        case .appLoeschen(let name): return appLoeschen(name, &z)
        case .appAktiv: return appAktivieren(anfrage, &z)
        case .appWeiter: wechseln(+1, &z); return ok
        case .appZurueck: wechseln(-1, &z); return ok
        case .appFreigabe(let name): return appFreigabe(name, anfrage, &z)
        case .meldungSenden: return meldungSenden(anfrage, &z)
        case .meldungAktivLoeschen:
            if !z.benachrichtigungen.isEmpty { z.benachrichtigungen.removeFirst() }
            return ok
        case .meldungLoeschen(let name):
            guard z.benachrichtigungen.contains(where: { $0.name == name }) else {
                return fehler(404, "notFound", "notification not found")
            }
            z.benachrichtigungen.removeAll { $0.name == name }
            return ok
        case .indikator(let id): return indikator(id, anfrage, &z)
        }
    }

    private static func erwartetJSON(_ route: Route) -> Bool {
        switch route {
        case .appAktiv, .appFreigabe: return false
        default: return true
        }
    }

    // MARK: - Lesen

    private static func geraet(_ z: NGUhrzustand) -> JSONWert {
        let anzeigeApp = z.aktiveApp
        let indikatoren: [JSONWert] = z.indikatoren.map {
            .objekt(["on": .bool($0.an), "color": .text($0.farbe),
                     "blinkMs": .zahl(Double($0.blinkMs)), "fadeMs": .zahl(Double($0.fadeMs))])
        }
        let ip = JSONWert.text("127.0.0.1")
        func verbindung(_ host: String, _ endpunkt: String, _ status: String, _ aktiv: Bool) -> JSONWert {
            .objekt(["enabled": .bool(aktiv), "state": .text(status), "host": .text(host),
                     "endpoint": .text(endpunkt), "attempts": .zahl(0), "retryInMs": .zahl(0),
                     "connects": .zahl(aktiv ? 1 : 0), "error": .null, "lastError": .null])
        }
        return .objekt([
            "version": .text("1.2.2"), "uid": .text("000000000000"), "boardType": .text("tc002"),
            "soc": .text("armv7l"), "updateImage": .text("awtrix-ng-tc002.awup"),
            "ipAddress": ip, "macAddress": .text("00:00:00:00:00:00"),
            "hostname": .text("virtuelle-uhr"), "wifiRssi": .zahl(-40),
            "uptimeSeconds": .zahl(1000), "freeHeapBytes": .zahl(13_553_664),
            "minFreeHeapBytes": .zahl(13_488_128), "scriptingRunning": .bool(true),
            "scriptHeapPool": .text("system"), "scriptHeapBudgetBytes": .zahl(4_194_304),
            "resetReason": .text("software"), "fps": .zahl(42),
            "brightness": .zahl(Double(z.helligkeit)), "batteryPercent": .zahl(73),
            "batteryVoltage": .zahl(4.03), "lowBattery": .bool(false),
            "matrixPower": .bool(z.power), "currentApp": .text(anzeigeApp),
            "indicators": .liste(indikatoren), "messageCount": .zahl(Double(z.benachrichtigungen.count)),
            "wifi": verbindung("virtuelles-netz", "127.0.0.1", "connected", true),
            "mqtt": verbindung("127.0.0.1", "127.0.0.1:1883", "offline", false),
            "mirror": .objekt(["sharing": .bool(false), "viewers": .zahl(0),
                               "source": .text(""), "state": .text("off")]),
            "usbPower": .bool(false),
            "update": .objekt(["state": .text("idle"), "release": .text(""), "error": .text("")]),
        ])
    }

    private static func anzeige(_ z: NGUhrzustand) -> JSONWert {
        .objekt(["power": .bool(z.power), "brightness": .zahl(Double(z.helligkeit)),
                 "overlay": z.overlay.map { .text($0) } ?? .null,
                 "overlaySettings": .objekt(z.overlaySettings), "moodlight": .null])
    }

    private static func appEintrag(_ a: NGApp) -> JSONWert {
        .objekt(["name": .text(a.name), "enabled": .bool(a.aktiv), "inLoop": .bool(a.aktiv),
                 "slot": .null, "present": .bool(true),
                 "origin": .text(a.eingebaut ? "builtin" : "pushed"),
                 "config": .bool(a.eingebaut && a.name == "Time")])
    }

    // MARK: - Einstellungen und Anzeige

    private static func einstellungenAendern(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        guard case .objekt(let neu) = wert else { return ungueltig("body required") }
        // Erst alles prüfen, dann schreiben: Ein falscher Schlüssel ändert nichts.
        for schluessel in neu.keys.sorted() {
            guard let alt = z.einstellungen[schluessel], let v = neu[schluessel] else {
                return ungueltig("unknown field", feld: schluessel)
            }
            if schluessel == "brightness" {
                guard let n = v.ganzzahl else { return ungueltig("must be a number", feld: schluessel) }
                guard (0...255).contains(n) else { return ungueltig("out of range", feld: schluessel) }
                continue
            }
            switch (alt, v) {
            case (.null, _), (.bool, .bool), (.zahl, .zahl), (.text, .text),
                 (.liste, .liste), (.objekt, .objekt):
                continue
            default:
                return ungueltig("wrong type", feld: schluessel)
            }
        }
        for (k, v) in neu { z.einstellungen[k] = v }
        return json(.objekt(z.einstellungen))
    }

    private static func anzeigeAendern(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        guard case .objekt(let neu) = wert else { return ungueltig("body required") }
        var power = z.power
        var overlay = z.overlay
        var einstellungen = z.overlaySettings

        if let p = neu["power"] {
            guard case .bool(let b) = p else { return ungueltig("must be a boolean", feld: "power") }
            power = b
        }
        if let o = neu["overlay"] {
            switch o {
            case .null: overlay = nil
            case .text(let s):
                if s.isEmpty { overlay = nil }
                else if bekannt("overlays", s) { overlay = s }
                else { return ungueltig("unknown overlay", feld: "overlay") }
            default: return ungueltig("must be a string or null", feld: "overlay")
            }
        }
        if let s = neu["overlaySettings"] {
            guard case .objekt(let teil) = s else {
                return ungueltig("must be an object", feld: "overlaySettings")
            }
            if let p = teil["palette"], p != .null {
                guard case .text(let name) = p, bekannt("palettes", name) else {
                    return ungueltig("unknown palette", feld: "overlaySettings.palette")
                }
            }
            for (k, v) in teil { einstellungen[k] = v }
        }
        z.power = power
        z.overlay = overlay
        z.overlaySettings = einstellungen
        return ok
    }

    private static func bekannt(_ liste: String, _ name: String) -> Bool {
        guard case .objekt(let o) = capabilities, case .liste(let l)? = o[liste] else { return false }
        return l.contains(.text(name))
    }

    // MARK: - Apps

    private static func gueltigerName(_ name: String) -> Bool {
        (1...32).contains(name.utf8.count)
            && name.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
                || ($0 >= 97 && $0 <= 122) || $0 == 95 || $0 == 45 }
    }

    private static let ungueltigerName = fehler(400, "invalidName", "invalid name", feld: "name")

    private static func appSenden(_ name: String, _ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard gueltigerName(name) else { return ungueltigerName }
        let leer = a.koerper.allSatisfy { $0 == 32 || $0 == 10 || $0 == 13 || $0 == 9 }
        guard !leer else { return ungueltig("body required") }
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }

        var neue: [(String, JSONWert)] = []
        switch wert {
        case .objekt(let o):
            guard !o.isEmpty else { return ungueltig("body required") }
            neue = [(name, wert)]
        case .liste(let l):
            guard !l.isEmpty else { return ungueltig("body required") }
            for (i, e) in l.enumerated() {
                guard case .objekt = e else { return ungueltig("must be an object", feld: "[\(i)]") }
                neue.append((name + String(i), e))
            }
        default:
            return ungueltig("must be an object")
        }

        var apps = z.apps
        // Nur neue Namen zählen gegen die Grenze; ein Array gilt ganz oder gar nicht.
        let vorhanden = Set(apps.filter { !$0.eingebaut }.map(\.name))
        let neueNamen = neue.filter { !vorhanden.contains($0.0) }.count
        guard vorhanden.count + neueNamen <= maxPushApps else {
            return fehler(507, "insufficientStorage", "storage full")
        }
        let ersetzt: (String) -> Bool = { n in
            if neue.count == 1, case .objekt = wert { return n == name }
            return n == name || Self.istNummeriert(n, von: name)
        }
        apps.removeAll { !$0.eingebaut && ersetzt($0.name) }
        for (n, w) in neue {
            apps.append(NGApp(name: n, aktiv: true, eingebaut: false, nutzlast: w))
        }
        z.apps = apps
        return ok
    }

    private static func istNummeriert(_ n: String, von name: String) -> Bool {
        guard n.hasPrefix(name), n.count > name.count else { return false }
        return n.dropFirst(name.count).allSatisfy(\.isNumber)
    }

    private static func appLoeschen(_ name: String, _ z: inout NGUhrzustand) -> Antwort {
        guard gueltigerName(name) else { return ungueltigerName }
        z.apps.removeAll { !$0.eingebaut && ($0.name == name || istNummeriert($0.name, von: name)) }
        if !z.apps.contains(where: { $0.name == z.aktiveApp }) {
            z.aktiveApp = z.apps.first?.name ?? ""
        }
        return ok
    }

    private static func appAktivieren(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        let text = String(decoding: a.koerper, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        var name = text
        if text.hasPrefix("{") {
            // Ein kaputter Rumpf ist hier 404, nicht 400 (so die Firmware).
            guard case .objekt(let o)? = JSONWert.lesen(a.koerper), case .text(let n)? = o["name"] else {
                return appFehlt
            }
            name = n
        }
        guard z.apps.contains(where: { $0.name == name }) else { return appFehlt }
        z.aktiveApp = name
        return ok
    }

    private static func wechseln(_ schritt: Int, _ z: inout NGUhrzustand) {
        let imLauf = z.apps.filter(\.aktiv).map(\.name)
        guard !imLauf.isEmpty else { return }
        guard let i = imLauf.firstIndex(of: z.aktiveApp) else { z.aktiveApp = imLauf[0]; return }
        z.aktiveApp = imLauf[(i + schritt + imLauf.count) % imLauf.count]
    }

    private static func appFreigabe(_ name: String, _ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard gueltigerName(name) else { return ungueltigerName }
        let text = String(decoding: a.koerper, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text == "true" || text == "false" else { return ungueltig("must be true or false") }
        guard let i = z.apps.firstIndex(where: { $0.name == name }) else { return appFehlt }
        z.apps[i].aktiv = text == "true"
        return ok
    }

    // MARK: - Benachrichtigungen und Indikatoren

    private static func meldungSenden(_ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard var wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        if case .liste(let l) = wert {
            guard l.count == 1 else { return ungueltig("one notification per request") }
            wert = l[0]
        }
        guard case .objekt(let o) = wert else { return ungueltig("must be an object") }
        var name: String?
        if let n = o["name"] {
            guard case .text(let s) = n else { return ungueltig("must be a string", feld: "name") }
            name = s
        }
        var stapeln = true
        if let st = o["stack"] {
            guard case .bool(let b) = st else { return ungueltig("must be a boolean", feld: "stack") }
            stapeln = b
        }
        let neu = NGBenachrichtigung(name: name, nutzlast: o)
        if stapeln {
            guard z.benachrichtigungen.count < maxWarteschlange else {
                return fehler(507, "insufficientStorage", "queue full")
            }
            z.benachrichtigungen.append(neu)
        } else if z.benachrichtigungen.isEmpty {
            z.benachrichtigungen = [neu]
        } else {
            z.benachrichtigungen[0] = neu
        }
        return ok
    }

    private static func indikator(_ id: String, _ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard let n = Int(id), (1...3).contains(n) else {
            return fehler(404, "notFound", "indicator id must be 1..3")
        }
        if a.methode == "DELETE" {
            z.indikatoren[n - 1] = NGIndikator()
            return ok
        }
        let leer = a.koerper.allSatisfy { $0 == 32 || $0 == 10 || $0 == 13 || $0 == 9 }
        guard !leer else { return ungueltig("body required") }
        guard let wert = JSONWert.lesen(a.koerper) else { return keinJSON }
        guard case .objekt(let o) = wert else { return ungueltig("must be an object") }

        var neu = z.indikatoren[n - 1]
        switch o["color"] ?? .null {
        case .null, .zahl(0): neu.an = false
        case let w:
            guard let hex = farbe(w) else { return ungueltig("invalid color", feld: "color") }
            neu.farbe = hex; neu.an = true
        }
        for (feld, ziel) in [("blinkMs", \NGIndikator.blinkMs), ("fadeMs", \NGIndikator.fadeMs)] {
            if let v = o[feld] {
                guard let i = v.ganzzahl, i >= 0 else { return ungueltig("out of range", feld: feld) }
                neu[keyPath: ziel] = i
            } else {
                neu[keyPath: ziel] = 0
            }
        }
        z.indikatoren[n - 1] = neu
        return ok
    }

    /// Die fünf Farbformen der Doku (`reference/conventions`), als `#RRGGBB`
    /// groß; `nil`, wenn keine passt. `"RRGGBB"` und `"RGB"` mit wahlfreiem `#`;
    /// `[r,g,b]` mit auf 0–255 begrenzten Kanälen; `["HSV",h,s,v]` mit auf 0–359
    /// umgebrochenem h und auf 0–100 begrenzten s, v; gepackte Ganzzahl
    /// `0xRRGGBB`. Kanäle müssen ganze Zahlen sein, Bruchwerte werden abgewiesen.
    static func farbe(_ w: JSONWert) -> String? {
        func hex(_ r: Int, _ g: Int, _ b: Int) -> String { String(format: "#%02X%02X%02X", r, g, b) }
        func begrenzt(_ n: Int, _ o: Int) -> Int { min(max(n, 0), o) }
        switch w {
        case .text(let t):
            let h = t.hasPrefix("#") ? String(t.dropFirst()) : t
            guard h.allSatisfy(\.isHexDigit) else { return nil }
            if h.count == 6 { return "#" + h.uppercased() }
            if h.count == 3 { return "#" + h.uppercased().map { "\($0)\($0)" }.joined() }
            return nil
        case .zahl:
            guard let i = w.ganzzahl, (0...0xFFFFFF).contains(i) else { return nil }
            return hex(i >> 16, (i >> 8) & 255, i & 255)
        case .liste(let l):
            if l.count == 3 {
                let k = l.compactMap(\.ganzzahl)
                guard k.count == 3 else { return nil }
                return hex(begrenzt(k[0], 255), begrenzt(k[1], 255), begrenzt(k[2], 255))
            }
            if l.count == 4, l[0] == .text("HSV") {
                let k = l[1...].compactMap(\.ganzzahl)
                guard k.count == 3 else { return nil }
                let h = Double(((k[0] % 360) + 360) % 360)
                let sat = Double(begrenzt(k[1], 100)) / 100, v = Double(begrenzt(k[2], 100)) / 100
                let c = v * sat
                let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
                let m = v - c
                let (r, g, b): (Double, Double, Double)
                switch Int(h / 60) {
                case 0: (r, g, b) = (c, x, 0)
                case 1: (r, g, b) = (x, c, 0)
                case 2: (r, g, b) = (0, c, x)
                case 3: (r, g, b) = (0, x, c)
                case 4: (r, g, b) = (x, 0, c)
                default: (r, g, b) = (c, 0, x)
                }
                return hex(Int(((r + m) * 255).rounded()), Int(((g + m) * 255).rounded()),
                           Int(((b + m) * 255).rounded()))
            }
            return nil
        default:
            return nil
        }
    }
}
