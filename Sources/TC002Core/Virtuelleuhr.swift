import Foundation

/// **Eine Uhr, die es nicht gibt** — damit sich die App ohne Gerät ausprobieren
/// lässt.
///
/// Der Zustand einer Ulanzi mit Werksfirmware, so weit diese App ihn anfasst:
/// das eingestellte Präfix, die MAC (aus beidem baut die Firmware das
/// Themen-Präfix), die beiden Zeitwerte aus `/getConfig` und die benannten
/// Anzeigen.
///
/// **AWTRIX NG spricht sie nicht.** Das war eine Entscheidung des
/// Auftraggebers am 14.09.2026: Die Werksfirmware ist der Weg, an dem die fünf
/// Plätze, das Mitlesen und der Rahmenbau hängen. Für NG bräuchte es die
/// zweite Hälfte der Schnittstelle — nachzutragen, wenn es gebraucht wird;
/// `Geraetetyp` und die Routen dafür stehen alle schon.
public struct Uhrzustand: Equatable, Sendable {
    /// Was in der Uhr als Präfix eingetragen ist. Das **Themen**-Präfix ist
    /// etwas anderes: Die Firmware hängt einen Unterstrich und die letzten
    /// vier Stellen der MAC an (siehe `Geraet.praefixUndBasis`). Genau das
    /// soll die virtuelle Uhr auch tun, sonst übt man an einer Vereinfachung.
    public var praefix: String
    public var mac: String
    /// Wie lange die Uhr eine Anzeige stehen lässt, bevor sie weiterblättert.
    public var seitenwechsel: Int
    public var scrolltempo: Int
    /// Name → Nutzlast, genau die Bytes, die angekommen sind.
    public var anzeigen: [String: Data]
    /// Die Reihenfolge, in der sie angekommen sind — danach wird geblättert.
    /// Ein Wörterbuch hat keine, und „irgendeine" wäre beim zweiten Blick eine
    /// andere.
    public var reihenfolge: [String]
    /// Worauf zuletzt umgeschaltet wurde (`/api/switchDiyApp`).
    public var aktuelle: String?

    public init(praefix: String = "tc002", mac: String = "aabbccdd1234",
                seitenwechsel: Int = 10, scrolltempo: Int = 100,
                anzeigen: [String: Data] = [:], reihenfolge: [String] = [],
                aktuelle: String? = nil) {
        self.praefix = praefix
        self.mac = mac
        self.seitenwechsel = seitenwechsel
        self.scrolltempo = scrolltempo
        self.anzeigen = anzeigen
        self.reihenfolge = reihenfolge
        self.aktuelle = aktuelle
    }

    /// Das Themen-Präfix, das die Firmware daraus bildet — dieselbe Formel wie
    /// in `Geraet.praefixUndBasis`.
    public var themenpraefix: String { praefix + "_" + String(mac.suffix(4)) }
}

/// Beantwortet die Anfragen einer Uhr — **als reine Funktion**.
///
/// Das Zuhören am Port ist Beiwerk (`Uhrenserver`); was eine Uhr auf welche
/// Anfrage antwortet, steht hier und lässt sich ohne Steckdose prüfen.
public enum Virtuelleuhr {
    public struct Anfrage: Equatable, Sendable {
        public var methode: String
        public var pfad: String
        public var abfrage: [String: String]
        public var koerper: Data

        public init(_ methode: String = "GET", _ pfad: String,
                    abfrage: [String: String] = [:], koerper: Data = Data()) {
            self.methode = methode
            self.pfad = pfad
            self.abfrage = abfrage
            self.koerper = koerper
        }
    }

    public struct Antwort: Equatable, Sendable {
        public var status: Int
        public var koerper: Data

        public init(status: Int = 200, koerper: Data) {
            self.status = status
            self.koerper = koerper
        }

        static func json(_ objekt: [String: Any], status: Int = 200) -> Antwort {
            let daten = (try? JSONSerialization.data(withJSONObject: objekt)) ?? Data("{}".utf8)
            return Antwort(status: status, koerper: daten)
        }

        /// Die Quittung der Werksfirmware: `200` im Rumpf, nicht im Status.
        static let angenommen = Antwort.json(["code": 200, "message": "ok"])
    }

    public static func beantworten(_ anfrage: Anfrage, _ zustand: inout Uhrzustand) -> Antwort {
        switch anfrage.pfad {
        case "/getBase":
            return .json(["mac": zustand.mac, "devSn": "VIRTUELL-0001",
                          "mcuVer": "0.0-virtuell", "appVer": "0.0-virtuell"])

        case "/getMqttConfig":
            // `isMqtt: false` ist die Wahrheit: Diese Uhr hängt an keinem
            // Broker. Das Präfix steht trotzdem da — die App holt es hier,
            // und ohne es bliebe der MQTT-Weg in der Oberfläche unerklärt.
            return .json(["isMqtt": false, "ip": "", "port": "1883",
                          "mqtt_name": "", "mqtt_prefix": zustand.praefix])

        case "/getMqttStatus":
            return .json(["data": ["connected": false]])

        case "/getConfig":
            return .json(["carouselSpeed": zustand.seitenwechsel,
                          "scrollSpeed": zustand.scrolltempo])

        case "/setConfig":
            // Die Firmware bekommt **die ganze** Konfiguration zurück, nicht
            // nur das geänderte Feld (siehe `Geraet.konfigurationSetzen`) —
            // gelesen wird daraus, was diese Uhr führt.
            if let objekt = try? JSONSerialization.jsonObject(with: anfrage.koerper),
               let k = objekt as? [String: Any] {
                if let wert = k["carouselSpeed"] as? Int { zustand.seitenwechsel = wert }
                if let wert = k["scrollSpeed"] as? Int { zustand.scrolltempo = wert }
            }
            return .json([:])

        case "/api/custom":
            guard let name = anfrage.abfrage["name"], !name.isEmpty else {
                return .json(["code": 400, "message": "no name"])
            }
            // **`{}` löscht, leer nicht.** Über MQTT ist es genau umgekehrt;
            // diese Verwechslung steht in `Geraet.anzeigeLoeschen` schon
            // angeschrieben, und die virtuelle Uhr muss sie mitmachen, sonst
            // übt man gegen eine Uhr, die es so nicht gibt.
            let rumpf = String(decoding: anfrage.koerper, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if rumpf == "{}" || rumpf.isEmpty {
                zustand.anzeigen[name] = nil
                zustand.reihenfolge.removeAll { $0 == name }
                if zustand.aktuelle == name { zustand.aktuelle = zustand.reihenfolge.first }
                return .angenommen
            }
            zustand.anzeigen[name] = anfrage.koerper
            if !zustand.reihenfolge.contains(name) { zustand.reihenfolge.append(name) }
            // Die Uhr zeigt eine neu angekommene Anzeige sofort (§5.6).
            zustand.aktuelle = name
            return .angenommen

        case "/api/customList":
            return .json(["apps": zustand.reihenfolge, "count": zustand.reihenfolge.count])

        case "/api/switchDiyApp":
            guard let name = anfrage.abfrage["name"], zustand.anzeigen[name] != nil else {
                return .json(["code": 404, "message": "no such app"])
            }
            zustand.aktuelle = name
            return .angenommen

        default:
            // **Alles andere ist 404, und das ist wichtig.** Die App erkennt
            // die Geräteart daran, ob `/api/v1/device` antwortet
            // (`Geraet.erkannteArt`). Eine virtuelle Werksfirmware, die dort
            // irgendetwas sagte, gälte als AWTRIX NG.
            return .json(["code": 404, "message": "not found"], status: 404)
        }
    }
}
