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
        /// **Bis zum 18.09.2026 war er fest JSON.** Das stimmte, solange nur
        /// die App fragte; seit die Wurzel eine Seite fuer den Browser
        /// ausliefert, muss die Antwort sagen koennen, was sie ist.
        public var inhaltstyp: String

        public init(status: Int = 200, koerper: Data,
                    inhaltstyp: String = "application/json") {
            self.status = status
            self.koerper = koerper
            self.inhaltstyp = inhaltstyp
        }

        static func json(_ objekt: [String: Any], status: Int = 200) -> Antwort {
            let daten = (try? JSONSerialization.data(withJSONObject: objekt)) ?? Data("{}".utf8)
            return Antwort(status: status, koerper: daten)
        }

        /// Die Quittung der Werksfirmware: `200` im Rumpf, nicht im Status.
        static let angenommen = Antwort.json(["code": 200, "message": "ok"])

        /// Die Seite an der Wurzel — **für Augen, nicht für die App.**
        ///
        /// Wer die Adresse der virtuellen Uhr in den Browser tippt, erwartet
        /// etwas zu sehen. Hier steht deshalb kein Nachbau der Anzeige: Der
        /// ginge nur halb — ein Lauf-GIF und ein Textblock, den die Uhr selbst
        /// setzt, liefern keine Pixel (dieselbe Grenze, an der die Blöcke in
        /// der App „belegt, Inhalt unbekannt" sagen). Eine Seite, die mal ein
        /// Bild zeigt und mal nicht, erklärt weniger als ein freundlicher Satz,
        /// der sagt, wo das ganze Bild steht.
        ///
        /// Alles in einer Antwort, ohne zweite Anfrage: Das Symbol steht als
        /// SVG mitten im Dokument (`Programmsymbol`), die Gestaltung im
        /// `<style>`. Ein Server, der Dateien ausliefern müsste, wäre für eine
        /// Seite, die einmal jemand aufruft, das Falsche.
        static func seite(_ zustand: Uhrzustand) -> Antwort {
            let belegt = zustand.reihenfolge.isEmpty
                ? lok("noch nichts")
                : zustand.reihenfolge.joined(separator: ", ")
            let html = """
            <!doctype html><html><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>\(lok("Hier gibt’s leider nichts zu sehen"))</title>
            <style>
              :root { color-scheme: light dark }
              body { font: 17px/1.6 -apple-system, system-ui, "Helvetica Neue", sans-serif;
                     margin: 0; min-height: 100vh; display: grid; place-items: center;
                     padding: 2rem 1.25rem; background: #f6f5f3; color: #1c1c1e }
              @media (prefers-color-scheme: dark) { body { background: #111; color: #f2f2f7 } }
              .karte { max-width: 32rem; text-align: center }
              svg { width: 132px; height: 132px; margin-bottom: 1.25rem }
              h1 { font-size: 1.45rem; line-height: 1.25; margin: 0 0 .75rem; font-weight: 600 }
              p { margin: 0 0 1rem; opacity: .85 }
              dl { display: grid; grid-template-columns: auto auto; gap: .2rem 1rem;
                   justify-content: center; margin: 1.75rem 0 0; font-size: .92rem; opacity: .7 }
              dt { text-align: right; font-weight: 600 }
              dd { text-align: left; margin: 0; font-variant-numeric: tabular-nums }
            </style>
            <div class="karte">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img"
                 aria-label="Pixel Clock Messenger">\(Programmsymbol.svg)</svg>
            <h1>\(lok("Hier gibt’s leider nichts zu sehen"))</h1>
            <p>\(lok("Diese Adresse ist die virtuelle Uhr: Sie beantwortet dieselben Anfragen wie eine echte Ulanzi — für die App, nicht für den Browser."))</p>
            <p>\(lok("Was auf einer Uhr stünde, zeigt die App selbst: unter „Senden“ die Vorschau im Geräterahmen, darunter die fünf Plätze mit ihrem Inhalt."))</p>
            <dl>
            <dt>\(lok("Belegte Plätze"))</dt><dd>\(belegt)</dd>
            <dt>\(lok("Präfix"))</dt><dd>\(zustand.praefix)</dd>
            <dt>\(lok("Seitenwechsel"))</dt><dd>\(zustand.seitenwechsel)</dd>
            <dt>\(lok("Scrolltempo"))</dt><dd>\(zustand.scrolltempo)</dd>
            </dl>
            </div>
            </html>
            """
            return Antwort(koerper: Data(html.utf8), inhaltstyp: "text/html; charset=utf-8")
        }
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

        case "", "/", "/index.html":
            // **Ein Hinweis, kein Nachbau.** Ein Bild dessen, was die Uhr
            // zeigte, liesse sich hier zwar rechnen — aber nur halb: Ein
            // Lauf-GIF und ein Textblock, den die Uhr selbst setzt, liefern
            // keine Pixel (dieselbe Grenze, an der die Bloecke in der App
            // „belegt, Inhalt unbekannt" sagen). Eine Seite, die mal ein Bild
            // zeigt und mal nicht, erklaert weniger als ein Satz, der sagt, wo
            // das ganze Bild steht.
            return .seite(zustand)

        default:
            // **Alles andere ist 404, und das ist wichtig.** Die App erkennt
            // die Geräteart daran, ob `/api/v1/device` antwortet
            // (`Geraet.erkannteArt`). Eine virtuelle Werksfirmware, die dort
            // irgendetwas sagte, gälte als AWTRIX NG.
            return .json(["code": 404, "message": "not found"], status: 404)
        }
    }
}
