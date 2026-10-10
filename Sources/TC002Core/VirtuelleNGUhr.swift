import Foundation
import ImageIO
import CoreGraphics

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
    public static func lesen(_ daten: Data) -> JSONWert? {
        try? JSONDecoder().decode(JSONWert.self, from: daten)
    }

    public var daten: Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? e.encode(self)) ?? Data("null".utf8)
    }

    public var ganzzahl: Int? {
        if case .zahl(let w) = self, w == w.rounded(), abs(w) < 1e15 { return Int(w) }
        return nil
    }
}

/// Eine Benachrichtigung in der Warteschlange: die Nutzlast, wie sie kam, und
/// ihr Name, falls sie einen trägt (nur darüber lässt sie sich zurückziehen).
public struct NGBenachrichtigung: Equatable, Sendable {
    public var name: String?
    public var nutzlast: [String: JSONWert]

    /// `hold`: bleibt, bis sie weggenommen wird. Gespeichert, nicht gespielt —
    /// die virtuelle Uhr kennt keine Zeit.
    public var haelt: Bool { nutzlast["hold"] == .bool(true) }
    /// `wakeup`: erscheint auch bei ausgeschaltetem Panel.
    public var weckt: Bool { nutzlast["wakeup"] == .bool(true) }
}

/// Eine App in der Liste der NG-Uhr. `nutzlast` ist bei eingebauten Apps `nil`.
public struct NGApp: Equatable, Sendable {
    public var name: String
    public var aktiv: Bool
    public var eingebaut: Bool
    public var nutzlast: JSONWert?
    /// Die Lebensdauer ist abgelaufen und `lifetimeExpiry` war `mark`: Die
    /// Anzeige bleibt, die Uhr zeichnet ihr einen dunkelroten Rahmen (§5.4).
    public var markiert = false
    /// `present` im Inventar. `false` ist der Geistereintrag einer
    /// ausgeschalteten Anzeige, die gelöscht wurde: Der Name bleibt, mit
    /// `enabled:false`, bis jemand `enabled true` setzt (gemessen 09.10.2026).
    public var vorhanden = true

    /// `lifetimeMs` der Nutzlast; `nil` bei 0 (nie) und wo es fehlt.
    public var lebensdauerMs: Int? {
        guard case .objekt(let o)? = nutzlast, let ms = o["lifetimeMs"]?.ganzzahl, ms > 0 else { return nil }
        return ms
    }
}

public struct NGIndikator: Equatable, Sendable {
    public var an = false
    /// `#RRGGBB`. Bleibt beim Ausschalten stehen, wie in der Firmware.
    public var farbe = "#000000"
    public var blinkMs = 0
    public var fadeMs = 0
}

/// Das laufende Moodlight (`GET /api/v1/display`, §7.5).
public struct NGMoodlight: Equatable, Sendable {
    /// `#RRGGBB`.
    public var farbe = "#FFFFFF"
    /// Roh, wie die Uhr ihn behält (nicht geprüft: 300 wird zu 44).
    public var helligkeit = 120
}

/// Der Zustand einer AWTRIX-NG-1.2.2-Uhr (TC002, 52×16), so weit die HTTP-
/// Schnittstelle ihn berührt. Vorgabewerte stammen aus einer Messung an einer
/// echten Uhr, Kennungen sind durch erfundene ersetzt.
public struct NGUhrzustand: Equatable, Sendable {
    public var einstellungen: [String: JSONWert]
    public var power = true
    public var overlay: String?
    /// `nil`: aus.
    public var moodlight: NGMoodlight?
    /// Eine hochgeladene Broker-CA liegt auf der Uhr (`PUT /api/v1/mqtt/tls/ca`).
    public var eigeneCA = false
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
    /// `mqttPrefix` der Systemkonfiguration (§11); leer heisst: die uid.
    public var mqttPrefix = ""

    public init() {
        einstellungen = VirtuelleNGUhr.vorgabeEinstellungen
    }

    var helligkeit: Int { einstellungen["brightness"]?.ganzzahl ?? 128 }
}

/// Beantwortet die HTTP-Anfragen einer AWTRIX-NG-1.2.2-Uhr auf der TC002 — als
/// reine Funktion. Fehlerform, Statuscodes und Meldungen folgen der
/// Herstellerdoku (`reference/errors`).
///
/// Gehalten wird der Zustand, damit sich die Wirkung eines Aufrufs prüfen
/// lässt. Gezeichnet werden von der aktiven Anzeige nur die Zeichenbefehle
/// `pixel`, `pixels`, `line`, `rect`, `rectFill`, `circle`, `circleFill` und
/// `bitmap` (`bildschirm`) sowie das erste Bild eines GIFs in `icon`; Text und
/// Effekte einer Anzeige bleiben schwarz. Ein `layout` wird geprüft und
/// gezeichnet (`VirtuelleNGUhrLayout.swift`).
///
/// Oberste Schlüssel, die §5 nicht kennt, sind `422` mit dem Schlüssel als
/// `field`, wie bei der Uhr.
///
/// Bewusst nicht geprüft:
/// - Inhalt einer App- oder Benachrichtigungsnutzlast über die obersten
///   Schlüssel hinaus (Töne, Schriften, Text- und Icon-Felder); geprüft sind
///   die Schlüssel aus §5.5 (Hintergrund, Effekt, Overlay, Palette, Diagramme,
///   Fortschritt — `pruefeDarstellung`), die Zeichenbefehle und `layout`,
/// - Wertebereiche von Schlüsseln der Systemkonfiguration; die Einstellungen
///   (§10) sind geprüft (`VirtuelleNGUhrSteuerung.swift`), ein Schlüssel ohne
///   Regel nur nach Typ,
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
/// - `PUT /apps/{name}/enabled` auf einen unbekannten Namen ist ok und legt nichts
///   an (gemessen 09.10.2026); `enabled` bleibt beim Ersetzen und beim Löschen
///   erhalten (Geistereintrag `present:false`), `true` räumt ihn weg;
/// - läuft die Lebensdauer einer ausgeschalteten Anzeige ab (`remove`), bleibt
///   derselbe Geistereintrag (nicht gemessen);
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
        case geraet, version, system, einstellungen, anzeige, bildschirm, apps, faehigkeiten, ton
        case moodlight, tlsStatus, tlsCA
        case appSenden(String), appLoeschen(String), appAktiv, appWeiter, appZurueck
        case appFreigabe(String)
        case meldungSenden, meldungAktivLoeschen, meldungLoeschen(String)
        case indikator(String)

        var methoden: [String] {
            switch self {
            case .geraet, .version, .system, .bildschirm, .apps, .faehigkeiten, .ton: return ["GET"]
            case .einstellungen, .anzeige: return ["GET", "PATCH"]
            case .appSenden, .appAktiv, .appFreigabe: return ["PUT"]
            case .appLoeschen, .meldungAktivLoeschen, .meldungLoeschen: return ["DELETE"]
            case .appWeiter, .appZurueck, .meldungSenden: return ["POST"]
            case .indikator, .moodlight, .tlsCA: return ["PUT", "DELETE"]
            case .tlsStatus: return ["GET"]
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
        case (1, "system"): return .system
        case (1, "settings"): return .einstellungen
        case (1, "display"): return .anzeige
        case (1, "apps"): return .apps
        case (1, "capabilities"): return .faehigkeiten
        case (1, "audio"): return .ton
        case (1, "notifications"): return .meldungSenden
        case (2, "display") where r[1] == "screen": return .bildschirm
        case (2, "display") where r[1] == "moodlight": return .moodlight
        case (2, "mqtt") where r[1] == "tls": return .tlsStatus
        case (3, "mqtt") where r[1] == "tls" && r[2] == "ca": return .tlsCA
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
        case .system:
            return json(.objekt(["mqttEnabled": .bool(false), "mqttHost": .text(""),
                                 "mqttPort": .zahl(1883), "mqttPrefix": .text(z.mqttPrefix),
                                 "hostname": .text("virtuelle-uhr"), "webPort": .zahl(80)]))
        case .einstellungen:
            return anfrage.methode == "GET" ? json(.objekt(z.einstellungen)) : einstellungenAendern(anfrage, &z)
        case .anzeige:
            return anfrage.methode == "GET" ? json(anzeige(z)) : anzeigeAendern(anfrage, &z)
        case .bildschirm:
            return Antwort(koerper: bildschirmantwort(z))
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
        case .moodlight: return moodlight(anfrage, &z)
        case .tlsStatus: return json(tlsStand(z))
        case .tlsCA: return tlsCA(anfrage, &z)
        }
    }

    private static func erwartetJSON(_ route: Route) -> Bool {
        switch route {
        case .appAktiv, .appFreigabe: return false
        default: return true
        }
    }

    // MARK: - Bildspeicher

    public static let breite = 52
    public static let hoehe = 16

    /// Ein Zeichenbrett mit Ursprung oben links; was außerhalb liegt, fällt weg.
    struct Brett {
        let breite: Int, hoehe: Int
        var punkte: [Int]
        /// Welche Punkte ein Befehl berührt hat — Schwarz ist eine Farbe und
        /// kein „nichts".
        var belegt: [Bool]
        init(breite: Int, hoehe: Int, fuellung: Int = 0) {
            self.breite = breite; self.hoehe = hoehe
            punkte = [Int](repeating: fuellung, count: breite * hoehe)
            belegt = [Bool](repeating: false, count: breite * hoehe)
        }
        mutating func setze(_ x: Int, _ y: Int, _ farbe: Int) {
            guard x >= 0, y >= 0, x < breite, y < hoehe else { return }
            punkte[y * breite + x] = farbe
            belegt[y * breite + x] = true
        }
    }

    /// Der Rumpf von `GET /api/v1/display/screen` und die Nutzlast von
    /// `<P>/state/screen` (§7.3).
    public static func bildschirmantwort(_ z: NGUhrzustand) -> Data {
        let punkte = bildschirm(z).map(String.init).joined(separator: ",")
        return Data(#"{"width":\#(breite),"height":\#(hoehe),"pixels":[\#(punkte)]}"#.utf8)
    }

    /// Was die Uhr gerade zeigt: `breite × hoehe` gepackte RGB-Werte,
    /// zeilenweise von oben links. Gezeigt wird die erste Benachrichtigung,
    /// sonst die aktive App.
    ///
    /// Gemessen an NG 1.2.2 auf der TC002 (09.10.2026, `enlargeApps: true`):
    /// `draw` einer Anzeige rechnet auf einem Raster von 26 × 8, jedes Pixel
    /// belegt 2 × 2 (`["pixel",0,0]` belegt 0…1 × 0…1, `["pixel",51,15]` fällt
    /// weg); in einem `layout` rechnet `draw` auf dem vollen 52 × 16 relativ
    /// zur Box der Region. Ohne `enlargeApps` rechnet auch die Anzeige auf
    /// 52 × 16.
    ///
    /// Annahmen, die die Doku nicht belegt (❓): Bei ausgeschaltetem Panel ist das
    /// Bild schwarz, und ein Moodlight füllt es mit seiner Farbe (ohne
    /// Helligkeit, wie bei den Apps).
    public static func bildschirm(_ z: NGUhrzustand) -> [Int] {
        var bild = Brett(breite: breite, hoehe: hoehe)
        if !z.power { return bild.punkte }
        if let licht = z.moodlight {
            return [Int](repeating: Int(licht.farbe.dropFirst(), radix: 16) ?? 0, count: breite * hoehe)
        }
        let nutzlast: [String: JSONWert]
        if let meldung = z.benachrichtigungen.first {
            nutzlast = meldung.nutzlast
        } else if case .objekt(let o)? = z.apps.first(where: { $0.name == z.aktiveApp })?.nutzlast {
            nutzlast = o
        } else {
            return bild.punkte
        }
        var vorgabe = 0xFFFFFF
        if let w = z.einstellungen["textColor"], let f = farbwert(w) { vorgabe = f }
        if let w = nutzlast["textColor"], let f = farbwert(w) { vorgabe = f }

        if case .objekt(let layout)? = nutzlast["layout"] {
            return layoutBild(layout, vorgabe: vorgabe, einstellungen: z.einstellungen).punkte
        }

        let faktor = z.einstellungen["enlargeApps"] == .bool(false) ? 1 : 2
        var brett = Brett(breite: breite / faktor, hoehe: hoehe / faktor)
        if let w = nutzlast["backgroundColor"], let f = farbwert(w) {
            brett = Brett(breite: brett.breite, hoehe: brett.hoehe, fuellung: f)
        }
        if case .liste(let befehle)? = nutzlast["draw"] {
            for befehl in befehle { zeichne(befehl, auf: &brett, farbe: vorgabe) }
        }
        for y in 0..<brett.hoehe {
            for x in 0..<brett.breite {
                for dy in 0..<faktor {
                    for dx in 0..<faktor {
                        bild.setze(x * faktor + dx, y * faktor + dy, brett.punkte[y * brett.breite + x])
                    }
                }
            }
        }
        // Ein GIF als `icon` der Anzeige, groesser als 26 × 8 (bei
        // `enlargeApps`) bzw. als das Raster: Die Anzeige rechnet dann auf dem
        // vollen 52 × 16 (§1.1; gemessen 09.10.2026), das Bild sitzt mittig.
        // Kleinere Icons zeichnet die Emulation nicht. Das erste Bild genuegt.
        if case .text(let uri)? = nutzlast["icon"], let g = gifBild(uri),
           g.breite > breite / faktor || g.hoehe > hoehe / faktor {
            let ox = (breite - g.breite) / 2, oy = (hoehe - g.hoehe) / 2
            for y in 0..<g.hoehe {
                for x in 0..<g.breite { bild.setze(ox + x, oy + y, g.punkte[y * g.breite + x]) }
            }
        }
        return bild.punkte
    }

    /// Das erste Bild eines GIFs aus einer Data-URL, gepackt als RGB.
    struct GIFBild {
        let breite: Int, hoehe: Int
        let punkte: [Int]
    }

    /// Hoechstens so viel Base64 wird gelesen und so gross darf das Bild sein:
    /// Die Nutzlast kommt vom Absender, Speicher und Rechenzeit der virtuellen
    /// Uhr duerfen nicht von ihm abhaengen.
    private static let hoechsteGIFLaenge = 2 * 1024 * 1024
    private static let hoechsteGIFKante = 256

    static func gifBild(_ uri: String) -> GIFBild? {
        let kopf = "data:image/gif;base64,"
        guard uri.hasPrefix(kopf), uri.utf8.count <= hoechsteGIFLaenge,
              let daten = Data(base64Encoded: String(uri.dropFirst(kopf.count))),
              let quelle = CGImageSourceCreateWithData(daten as CFData, nil),
              CGImageSourceGetCount(quelle) > 0,
              let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any],
              let b = eigenschaften[kCGImagePropertyPixelWidth] as? Int,
              let h = eigenschaften[kCGImagePropertyPixelHeight] as? Int,
              (1...hoechsteGIFKante).contains(b), (1...hoechsteGIFKante).contains(h),
              let bild = CGImageSourceCreateImageAtIndex(quelle, 0, nil) else { return nil }
        var bytes = [UInt8](repeating: 0, count: b * h * 4)
        guard let kontext = CGContext(data: &bytes, width: b, height: h, bitsPerComponent: 8,
                                      bytesPerRow: b * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        kontext.draw(bild, in: CGRect(x: 0, y: 0, width: b, height: h))
        // Vor Schwarz gelegt: Durchsichtiges bleibt 0, also schwarz.
        let punkte = (0..<(b * h)).map { i in
            Int(bytes[4 * i]) << 16 | Int(bytes[4 * i + 1]) << 8 | Int(bytes[4 * i + 2])
        }
        return GIFBild(breite: b, hoehe: h, punkte: punkte)
    }

    static func farbwert(_ w: JSONWert) -> Int? {
        guard let hex = farbe(w) else { return nil }
        return Int(hex.dropFirst(), radix: 16)
    }

    /// Ein Zeichenbefehl. Unbekannte und kaputte Befehle zeichnen nichts.
    static func zeichne(_ befehl: JSONWert, auf brett: inout Brett, farbe vorgabe: Int) {
        guard case .liste(let teile) = befehl, case .text(let name)? = teile.first else { return }
        let a = Array(teile.dropFirst())
        func zahl(_ i: Int) -> Int? { a.indices.contains(i) ? a[i].ganzzahl : nil }
        func farbeAn(_ i: Int) -> Int {
            guard a.indices.contains(i), let f = farbwert(a[i]) else { return vorgabe }
            return f
        }
        switch name {
        case "pixel":
            guard let x = zahl(0), let y = zahl(1) else { return }
            brett.setze(x, y, farbeAn(2))
        case "pixels":
            let f = farbeAn(0)
            let koordinaten = a.dropFirst().compactMap(\.ganzzahl)
            guard koordinaten.count == a.count - 1 else { return }
            for i in stride(from: 0, to: koordinaten.count - 1, by: 2) {
                brett.setze(koordinaten[i], koordinaten[i + 1], f)
            }
        case "line":
            guard let x1 = zahl(0), let y1 = zahl(1), let x2 = zahl(2), let y2 = zahl(3) else { return }
            linie(x1, y1, x2, y2, farbeAn(4), auf: &brett)
        case "rect", "rectFill":
            guard let x = zahl(0), let y = zahl(1), let w = zahl(2), let h = zahl(3), w > 0, h > 0 else { return }
            let f = farbeAn(4)
            // Auf das Brett beschnitten, bevor iteriert wird. Die Werte sind
            // durch `JSONWert.ganzzahl` auf ±1e15 begrenzt, die Summen laufen
            // nicht ueber.
            for j in bereich(y, y + h - 1, bis: brett.hoehe - 1) {
                for i in bereich(x, x + w - 1, bis: brett.breite - 1)
                where name == "rectFill" || i == x || i == x + w - 1 || j == y || j == y + h - 1 {
                    brett.setze(i, j, f)
                }
            }
        case "circle", "circleFill":
            guard let cx = zahl(0), let cy = zahl(1), let r = zahl(2), r >= 0, r <= 4096 else { return }
            let f = farbeAn(3)
            // Mittelpunktverfahren; gefuellt als waagrechte Linien je Zeile.
            // ❓ Die Firmware nennt ihr Verfahren nicht; Kanten koennen um ein
            // Pixel abweichen.
            var x = r, y = 0, fehler = 1 - r
            while x >= y {
                if name == "circleFill" {
                    for (dy, dx) in [(y, x), (-y, x), (x, y), (-x, y)] {
                        for i in bereich(cx - dx, cx + dx, bis: brett.breite - 1) { brett.setze(i, cy + dy, f) }
                    }
                } else {
                    for (dx, dy) in [(x, y), (y, x), (-x, y), (-y, x), (x, -y), (y, -x), (-x, -y), (-y, -x)] {
                        brett.setze(cx + dx, cy + dy, f)
                    }
                }
                y += 1
                if fehler < 0 { fehler += 2 * y + 1 } else { x -= 1; fehler += 2 * (y - x) + 1 }
            }
        case "bitmap":
            guard a.count == 5, let x = zahl(0), let y = zahl(1), let w = zahl(2), let h = zahl(3),
                  w > 0, h > 0 else { return }
            var farben: [Int?] = []
            switch a[4] {
            case .text(let roh):
                guard let daten = Data(base64Encoded: roh) else { return }
                let bytes = [UInt8](daten)
                for i in 0..<(bytes.count / 3) {
                    farben.append(Int(bytes[3 * i]) << 16 | Int(bytes[3 * i + 1]) << 8 | Int(bytes[3 * i + 2]))
                }
            case .liste(let l):
                farben = l.map(farbwert)
            default:
                return
            }
            // Nur die sichtbaren Zeilen und Spalten; der Index in die Daten
            // zaehlt trotzdem ab der Ecke des Bildes. `w * h` wird nie
            // gebildet: Es kaeme ueber den Wertebereich.
            let zeilen = (farben.count - 1) / w
            guard !farben.isEmpty else { return }
            for j in bereich(0, min(h - 1, zeilen), bis: brett.hoehe - 1 - y, ab: -y) {
                for i in bereich(0, w - 1, bis: brett.breite - 1 - x, ab: -x) {
                    let index = j * w + i
                    guard index < farben.count else { break }
                    if let f = farben[index] { brett.setze(x + i, y + j, f) }
                }
            }
        default:
            return
        }
    }

    /// Die Werte von `von` bis `bis` (beide eingeschlossen), nach oben auf
    /// `hoechstens` und nach unten auf `ab` (Vorgabe 0) beschnitten; leer, wenn
    /// nichts uebrig bleibt.
    private static func bereich(_ von: Int, _ bis: Int, bis hoechstens: Int, ab: Int = 0) -> Range<Int> {
        let unten = max(von, ab), oben = min(bis, hoechstens)
        return unten..<max(unten, oben + 1)
    }

    /// Bresenham mit beiden Endpunkten. Liegt ein Endpunkt ausserhalb, wird die
    /// Strecke vorher auf das Brett beschnitten (Liang-Barsky) — sonst liefe
    /// die Schleife ueber die ganze Laenge der Strecke.
    static func linie(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ f: Int, auf brett: inout Brett) {
        var (ax, ay, bx, by) = (x1, y1, x2, y2)
        let (breite, hoehe) = (brett.breite, brett.hoehe)
        let innen = { (x: Int, y: Int) in x >= 0 && y >= 0 && x < breite && y < hoehe }
        if !(innen(ax, ay) && innen(bx, by)) {
            let dx = Double(x2 - x1), dy = Double(y2 - y1)
            var t0 = 0.0, t1 = 1.0
            let p = [-dx, dx, -dy, dy]
            let q = [Double(x1), Double(brett.breite - 1 - x1), Double(y1), Double(brett.hoehe - 1 - y1)]
            for k in 0..<4 {
                if p[k] == 0 {
                    if q[k] < 0 { return }
                } else {
                    let t = q[k] / p[k]
                    if p[k] < 0 { t0 = max(t0, t) } else { t1 = min(t1, t) }
                }
            }
            guard t0 <= t1 else { return }
            ax = Int((Double(x1) + t0 * dx).rounded()); ay = Int((Double(y1) + t0 * dy).rounded())
            bx = Int((Double(x1) + t1 * dx).rounded()); by = Int((Double(y1) + t1 * dy).rounded())
        }
        var (x, y) = (ax, ay)
        let ddx = abs(bx - ax), ddy = -abs(by - ay)
        let sx = ax < bx ? 1 : -1, sy = ay < by ? 1 : -1
        var fehler = ddx + ddy
        while true {
            brett.setze(x, y, f)
            if x == bx && y == by { break }
            let e2 = 2 * fehler
            if e2 >= ddy { fehler += ddy; x += sx }
            if e2 <= ddx { fehler += ddx; y += sy }
        }
    }

    // MARK: - Lesen

    static func geraet(_ z: NGUhrzustand) -> JSONWert {
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
                 "overlaySettings": .objekt(z.overlaySettings),
                 "moodlight": z.moodlight.map { .objekt(["color": .text($0.farbe),
                                                         "brightness": .zahl(Double($0.helligkeit))]) } ?? .null])
    }

    private static func appEintrag(_ a: NGApp) -> JSONWert {
        .objekt(["name": .text(a.name), "enabled": .bool(a.aktiv), "inLoop": .bool(a.aktiv && a.vorhanden),
                 "slot": .null, "present": .bool(a.vorhanden),
                 "origin": .text(a.eingebaut ? "builtin" : "pushed"),
                 "config": .bool(a.eingebaut && a.name == "Time")])
    }

    // MARK: - Einstellungen und Anzeige

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

    static func gueltigerName(_ name: String) -> Bool {
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
            if let falsch = pruefeAnzeigenschluessel(o) { return falsch }
            neue = [(name, wert)]
        case .liste(let l):
            guard !l.isEmpty else { return ungueltig("body required") }
            for (i, e) in l.enumerated() {
                guard case .objekt(let o) = e else { return ungueltig("must be an object", feld: "[\(i)]") }
                if let falsch = pruefeAnzeigenschluessel(o) { return falsch }
                neue.append((name + String(i), e))
            }
        default:
            return ungueltig("must be an object")
        }

        var apps = z.apps
        // Nur neue Namen zählen gegen die Grenze; ein Array gilt ganz oder gar nicht.
        let vorhanden = Set(apps.filter { !$0.eingebaut && $0.vorhanden }.map(\.name))
        let neueNamen = neue.filter { !vorhanden.contains($0.0) }.count
        guard vorhanden.count + neueNamen <= maxPushApps else {
            return fehler(507, "insufficientStorage", "storage full")
        }
        let ersetzt: (String) -> Bool = { n in
            if neue.count == 1, case .objekt = wert { return n == name }
            return n == name || Self.istNummeriert(n, von: name)
        }
        // Ersetzt wird der Inhalt, nicht der Schalter: Eine ausgeschaltete Anzeige
        // bleibt ausgeschaltet (gemessen 09.10.2026).
        let ausgeschaltet = Set(apps.filter { !$0.eingebaut && !$0.aktiv }.map(\.name))
        apps.removeAll { !$0.eingebaut && ersetzt($0.name) }
        for (n, w) in neue {
            apps.append(NGApp(name: n, aktiv: !ausgeschaltet.contains(n), eingebaut: false, nutzlast: w))
        }
        z.apps = apps
        return ok
    }

    /// Die Schlüssel, die nur `POST /notifications` annimmt (§5.6). In einer
    /// gepushten Anzeige sind sie `422`.
    static let nurFuerBenachrichtigungen = ["name", "hold", "stack", "wakeup", "sound"]

    /// Prüft, was §5.4 und §5.6 für eine Anzeige verlangen: keine Schlüssel nur für
    /// Benachrichtigungen, und `lifetimeExpiry` aus der Liste. Ein falscher Typ
    /// bei `lifetimeMs` ist kein Fehler, der Wert wird übergangen (§5).
    private static func pruefeAnzeigenschluessel(_ o: [String: JSONWert]) -> Antwort? {
        if let falsch = nurFuerBenachrichtigungen.first(where: { o[$0] != nil }) {
            return ungueltig("not allowed in an app", feld: falsch)
        }
        return pruefeNutzlast(o)
    }

    /// Was für Anzeige und Benachrichtigung gleich gilt: oberste Schlüssel,
    /// Zeichenbefehle, `layout`, Ablauf und Darstellung.
    static func pruefeNutzlast(_ o: [String: JSONWert]) -> Antwort? {
        if let falsch = pruefeSchluessel(o) { return falsch }
        if let falsch = pruefeAblauf(o) { return falsch }
        if let falsch = pruefeDarstellung(o) { return falsch }
        if let w = o["draw"], let falsch = pruefeZeichenbefehle(w, feld: "draw") { return falsch }
        if let l = o["layout"], let falsch = pruefeLayout(l, daneben: o) { return falsch }
        return nil
    }

    /// Die Schlüssel aus §5.5, so wie NG sie prüft (§5, §5.8):
    ///
    /// - Falsche Typen bei `effect`, `overlay`, Zahlen und bool sind **kein**
    ///   Fehler, der Wert wird übergangen; `effectSpeed` und `paletteSpeed`
    ///   klemmt die Uhr, ohne abzuweisen.
    /// - Ein unbekannter `effect`-, `overlay`- oder `palette`-Name, eine
    ///   unlesbare Farbe und eine falsch gebaute Palette sind `422` mit dem
    ///   Schlüssel als `field`.
    ///
    /// Annahmen, wo die Doku schweigt (❓): Ein `barChart`/`lineChart`, das kein
    /// Feld ist, ist `422`; ein `lineChart` mit weniger als zwei Werten wird
    /// angenommen (und nicht gezeichnet). Gerendert wird nichts davon.
    private static func pruefeDarstellung(_ o: [String: JSONWert]) -> Antwort? {
        func farbig(_ w: JSONWert?) -> Bool { w == nil || w == .null || farbe(w!) != nil }
        for feld in ["backgroundColor", "progressTrackColor"] where !farbig(o[feld]) {
            return ungueltig("invalid color", feld: feld)
        }
        for feld in ["chartColor", "progressColor"] {
            if o[feld] == .text("palette") { continue }
            if !farbig(o[feld]) { return ungueltig("invalid color", feld: feld) }
        }
        for (feld, liste) in [("effect", "effects"), ("overlay", "overlays")] {
            if case .text(let name)? = o[feld], !name.isEmpty,
               !listeEnthaelt(liste, name) {
                return ungueltig("unknown \(feld)", feld: feld)
            }
        }
        for feld in ["barChart", "lineChart"] {
            if let w = o[feld], w != .null {
                guard case .liste = w else { return ungueltig("must be an array", feld: feld) }
            }
        }
        if let falsch = pruefePalette(o["palette"], feld: "palette") { return falsch }
        return nil
    }

    /// Name aus der Liste der Uhr, 1–16 Farben oder Stützstellen `{color, pos}` —
    /// nicht gemischt (§5.5).
    static func pruefePalette(_ w: JSONWert?, feld: String) -> Antwort? {
        switch w {
        case nil, .null?: return nil
        case .text(let name)?:
            if !name.isEmpty, !listeEnthaelt("palettes", name) { return ungueltig("unknown palette", feld: feld) }
        case .liste(let stellen)?:
            guard (1...16).contains(stellen.count) else { return ungueltig("invalid palette", feld: feld) }
            let mitLage = stellen.map { st -> Bool? in
                if case .objekt = st { return true }
                return farbe(st) != nil ? false : nil
            }
            guard !mitLage.contains(where: { $0 == nil }), Set(mitLage.compactMap { $0 }).count == 1 else {
                return ungueltig("invalid palette", feld: feld)
            }
            for st in stellen {
                guard case .objekt(let obj) = st else { continue }
                guard let f = obj["color"], farbe(f) != nil, let pos = obj["pos"]?.ganzzahl,
                      (0...100).contains(pos) else { return ungueltig("invalid palette", feld: feld) }
            }
        default:
            return ungueltig("invalid palette", feld: feld)
        }
        return nil
    }

    static func listeEnthaelt(_ liste: String, _ name: String) -> Bool {
        guard case .objekt(let c) = capabilities, case .liste(let l)? = c[liste] else { return false }
        return l.contains { if case .text(let t) = $0 { return t.caseInsensitiveCompare(name) == .orderedSame }; return false }
    }

    private static func pruefeAblauf(_ o: [String: JSONWert]) -> Antwort? {
        if case .text(let wort)? = o["lifetimeExpiry"], !["remove", "mark"].contains(wort) {
            return ungueltig("must be remove or mark", feld: "lifetimeExpiry")
        }
        return nil
    }

    /// Die Lebensdauer einer Anzeige ist um: `remove` löscht sie, `mark` lässt
    /// sie stehen und markiert sie. Die virtuelle Uhr kennt keine Zeit — der
    /// Test oder der Aufrufer bestimmt, wann das geschieht.
    public static func lebensdauerAbgelaufen(_ name: String, _ z: inout NGUhrzustand) {
        guard let i = z.apps.firstIndex(where: { !$0.eingebaut && $0.name == name }),
              z.apps[i].lebensdauerMs != nil else { return }
        if case .objekt(let o)? = z.apps[i].nutzlast, o["lifetimeExpiry"] == .text("mark") {
            z.apps[i].markiert = true
            return
        }
        inhaltEntfernen(i, &z)
    }

    /// Löscht den Inhalt. Eine ausgeschaltete Anzeige bleibt als Geistereintrag
    /// (`present:false`) im Inventar, eine eingeschaltete verschwindet ganz.
    private static func inhaltEntfernen(_ i: Int, _ z: inout NGUhrzustand) {
        if z.apps[i].aktiv {
            z.apps.remove(at: i)
        } else {
            z.apps[i].vorhanden = false
            z.apps[i].nutzlast = nil
            z.apps[i].markiert = false
        }
        if !z.apps.contains(where: { $0.name == z.aktiveApp && $0.vorhanden }) {
            z.aktiveApp = z.apps.first(where: { $0.vorhanden })?.name ?? ""
        }
    }

    private static func istNummeriert(_ n: String, von name: String) -> Bool {
        guard n.hasPrefix(name), n.count > name.count else { return false }
        return n.dropFirst(name.count).allSatisfy(\.isNumber)
    }

    private static func appLoeschen(_ name: String, _ z: inout NGUhrzustand) -> Antwort {
        guard gueltigerName(name) else { return ungueltigerName }
        for i in z.apps.indices.reversed()
        where !z.apps[i].eingebaut && (z.apps[i].name == name || istNummeriert(z.apps[i].name, von: name)) {
            inhaltEntfernen(i, &z)
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
        guard z.apps.contains(where: { $0.name == name && $0.vorhanden }) else { return appFehlt }
        z.aktiveApp = name
        return ok
    }

    private static func wechseln(_ schritt: Int, _ z: inout NGUhrzustand) {
        let imLauf = z.apps.filter { $0.aktiv && $0.vorhanden }.map(\.name)
        guard !imLauf.isEmpty else { return }
        guard let i = imLauf.firstIndex(of: z.aktiveApp) else { z.aktiveApp = imLauf[0]; return }
        z.aktiveApp = imLauf[(i + schritt + imLauf.count) % imLauf.count]
    }

    private static func appFreigabe(_ name: String, _ a: Anfrage, _ z: inout NGUhrzustand) -> Antwort {
        guard gueltigerName(name) else { return ungueltigerName }
        let text = String(decoding: a.koerper, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text == "true" || text == "false" else { return ungueltig("must be true or false") }
        // Ein unbekannter Name ist ok und legt nichts an (gemessen 09.10.2026).
        guard let i = z.apps.firstIndex(where: { $0.name == name }) else { return ok }
        if !z.apps[i].vorhanden {
            // Einschalten räumt den Geistereintrag weg; Ausschalten ändert nichts.
            if text == "true" { z.apps.remove(at: i) }
            return ok
        }
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
            guard gueltigerName(s), s != "active" else { return ungueltigerName }
            name = s
        }
        if let falsch = pruefeNutzlast(o) { return falsch }
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
