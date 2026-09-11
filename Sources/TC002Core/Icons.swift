import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct Icon: Equatable, Sendable {
    public var nummer: String, name: String, kategorie: String
    public var datei: URL
    public init(nummer: String, name: String, kategorie: String, datei: URL) {
        self.nummer = nummer; self.name = name; self.kategorie = kategorie; self.datei = datei
    }
}

public enum IconFehler: Error, LocalizedError {
    case nichtLesbar(String)
    case nichtGefunden(String)
    case nichtSchreibbar(String)

    public var errorDescription: String? {
        switch self {
        case .nichtLesbar(let n): return "Das Icon \(n) lässt sich nicht lesen."
        case .nichtGefunden(let n): return "Für die Nummer \(n) gibt es bei LaMetric kein Icon."
        case .nichtSchreibbar(let n): return "Das Icon \(n) lässt sich nicht speichern."
        }
    }
}

/// Die 8×8-Icons. Mitgeliefert im Ordner `Icons/`, erweiterbar ueber LaMetric-Nummern
/// und eigene Zeichnungen.
public struct Iconsammlung {
    /// Nimmt neue und nachgeladene Icons auf.
    private let schreibordner: URL
    /// Zusaetzliche Quellen, die nur gelesen werden — die mitgelieferten.
    private let leseordner: [URL]

    public init(schreibordner: URL, leseordner: [URL] = []) {
        self.schreibordner = schreibordner
        self.leseordner = leseordner
    }

    /// Ein Ordner, aus dem gelesen und in den geschrieben wird.
    public init(ordner: URL) {
        self.init(schreibordner: ordner)
    }

    public func alle() -> [Icon] {
        let namen = geladeneNamen()
        var gefunden: [String: Icon] = [:]
        // Schreibordner zuletzt: gleiche Nummer aus eigenem Bestand gewinnt.
        for ordner in leseordner + [schreibordner] {
            let dateien = (try? FileManager.default.contentsOfDirectory(at: ordner,
                           includingPropertiesForKeys: nil)) ?? []
            for datei in dateien where ["gif", "png", "jpg"].contains(datei.pathExtension.lowercased()) {
                let nummer = datei.deletingPathExtension().lastPathComponent
                let eintrag = namen[nummer]
                gefunden[nummer] = Icon(nummer: nummer,
                                        name: eintrag?.0 ?? nummer,
                                        kategorie: eintrag?.1 ?? "",
                                        datei: datei)
            }
        }
        return gefunden.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func datenURI(fuer icon: Icon) throws -> String {
        guard let daten = try? Data(contentsOf: icon.datei) else {
            throw IconFehler.nichtLesbar(icon.nummer)
        }
        let typ: String
        switch icon.datei.pathExtension.lowercased() {
        case "png": typ = "image/png"
        case "jpg", "jpeg": typ = "image/jpeg"
        default: typ = "image/gif"
        }
        return "data:\(typ);base64," + daten.base64EncodedString()
    }

    /// Liest ein Icon als 8×8-Raster, zeilenweise von oben links. `nil` heisst aus:
    /// bei selbst gesicherten Icons kommt das praktisch nie vor, da `sichern` keine
    /// Durchsichtigkeit kennt — mitgelieferte oder von LaMetric geholte Icons koennen
    /// aber echte durchsichtige Pixel tragen.
    public func pixel(fuer icon: Icon) throws -> [String?] {
        guard let quelle = CGImageSourceCreateWithURL(icon.datei as CFURL, nil),
              let bild = CGImageSourceCreateImageAtIndex(quelle, 0, nil) else {
            throw IconFehler.nichtLesbar(icon.nummer)
        }
        var bytes = [UInt8](repeating: 0, count: 64 * 4)
        guard let kontext = CGContext(data: &bytes, width: 8, height: 8, bitsPerComponent: 8,
                                      bytesPerRow: 8 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw IconFehler.nichtLesbar(icon.nummer)
        }
        kontext.interpolationQuality = .none
        kontext.draw(bild, in: CGRect(x: 0, y: 0, width: 8, height: 8))

        // Kein Ursprungsunterschied auszugleichen: `draw(_:in:)` haelt sich an die
        // visuelle Ausrichtung der Quelle, die Pufferzeile 0 ist bereits die oberste.
        var pixel = [String?](repeating: nil, count: 64)
        for i in 0..<64 {
            let q = i * 4
            guard bytes[q + 3] != 0 else { continue }   // durchsichtig bleibt nil
            pixel[i] = String(format: "#%02X%02X%02X", bytes[q], bytes[q + 1], bytes[q + 2])
        }
        return pixel
    }

    /// Holt ein Icon ueber seine LaMetric-Nummer: erst das Bild, dann Name und
    /// Kategorie. Beides ohne Anmeldung erreichbar. Schlaegt nur die Namensabfrage
    /// fehl, bleibt das Icon trotzdem bestehen, dann eben mit der Nummer als Namen.
    public func holen(nummer: String, sitzung: URLSession = .shared) throws -> Icon {
        let bildURL = URL(string: "https://developer.lametric.com/content/apps/icon_thumbs/\(nummer)")!
        let bild = try fuehreAus(URLRequest(url: bildURL), sitzung: sitzung, nummer: nummer)
        guard bild.count > 16 else {
            throw IconFehler.nichtGefunden(nummer)
        }
        try? FileManager.default.createDirectory(at: schreibordner, withIntermediateDirectories: true)
        let ziel = schreibordner.appendingPathComponent("\(nummer).gif")
        try bild.write(to: ziel, options: .atomic)

        var name = nummer, kategorie = ""
        let infoURL = URL(string: "https://developer.lametric.com/api/v1/dev/preloadicons?icon_id=\(nummer)")!
        if let info = try? fuehreAus(URLRequest(url: infoURL), sitzung: sitzung, nummer: nummer),
           let objekt = try? JSONSerialization.jsonObject(with: info) as? [String: Any] {
            name = objekt["name"] as? String ?? nummer
            kategorie = objekt["category_name"] as? String ?? ""
        }
        namenErgaenzen(nummer: nummer, name: name, kategorie: kategorie)
        return Icon(nummer: nummer, name: name, kategorie: kategorie, datei: ziel)
    }

    /// Legt ein selbst gemaltes 8×8-Icon als GIF ab. `pixel` ist zeilenweise von oben
    /// links, `nil` heisst aus. GIF kennt nur volle Durchsichtigkeit und die Uhr hat
    /// ohnehin einen schwarzen Grund — aus wird deshalb zu Schwarz.
    @discardableResult
    public func sichern(nummer: String, name: String, pixel: [String?]) throws -> Icon {
        guard pixel.count == 64 else { throw IconFehler.nichtSchreibbar(nummer) }
        var bytes = [UInt8](repeating: 0, count: 64 * 4)
        for (i, farbe) in pixel.enumerated() {
            let (r, g, b) = Self.zerlegen(farbe)
            bytes[i * 4] = r; bytes[i * 4 + 1] = g; bytes[i * 4 + 2] = b; bytes[i * 4 + 3] = 255
        }
        guard let anbieter = CGDataProvider(data: Data(bytes) as CFData),
              let bild = CGImage(width: 8, height: 8, bitsPerComponent: 8, bitsPerPixel: 32,
                                 bytesPerRow: 8 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: anbieter, decode: nil, shouldInterpolate: false,
                                 intent: .defaultIntent)
        else { throw IconFehler.nichtSchreibbar(nummer) }

        try? FileManager.default.createDirectory(at: schreibordner, withIntermediateDirectories: true)
        let ziel = schreibordner.appendingPathComponent("\(nummer).gif")
        guard let senke = CGImageDestinationCreateWithURL(ziel as CFURL,
                            UTType.gif.identifier as CFString, 1, nil) else {
            throw IconFehler.nichtSchreibbar(nummer)
        }
        CGImageDestinationAddImage(senke, bild, nil)
        guard CGImageDestinationFinalize(senke) else { throw IconFehler.nichtSchreibbar(nummer) }

        namenErgaenzen(nummer: nummer, name: name, kategorie: "eigen")
        return Icon(nummer: nummer, name: name, kategorie: "eigen", datei: ziel)
    }

    /// Entfernt ein eigenes Icon. Mitgelieferte bleiben unangetastet — sie liegen im
    /// Bundle und tauchen nach einem Loeschversuch ohnehin wieder auf.
    public func loeschen(_ icon: Icon) throws {
        // deletingLastPathComponent() haengt einen abschliessenden Schraegstrich an,
        // standardizedFileURL entfernt ihn nicht — deshalb ueber die Pfad-Strings
        // vergleichen statt ueber die URLs selbst.
        guard Self.ordnerPfad(icon.datei.deletingLastPathComponent()) == Self.ordnerPfad(schreibordner) else {
            throw IconFehler.nichtSchreibbar(icon.nummer)
        }
        try FileManager.default.removeItem(at: icon.datei)
        namenEntfernen(nummer: icon.nummer)
    }

    private static func ordnerPfad(_ url: URL) -> String {
        var pfad = url.standardizedFileURL.path
        if pfad.hasSuffix("/") { pfad.removeLast() }
        return pfad
    }

    /// "#RRGGBB" in drei Bytes. Alles Unbrauchbare wird schwarz.
    private static func zerlegen(_ farbe: String?) -> (UInt8, UInt8, UInt8) {
        guard var s = farbe else { return (0, 0, 0) }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let wert = UInt32(s, radix: 16) else { return (0, 0, 0) }
        return (UInt8((wert >> 16) & 0xFF), UInt8((wert >> 8) & 0xFF), UInt8(wert & 0xFF))
    }

    /// Fuehrt eine Anfrage synchron ueber die uebergebene Sitzung aus, mit zehn
    /// Sekunden Frist. Ein Fehler, eine ueberschrittene Frist oder ein HTTP-Fehlercode
    /// zaehlen hier allesamt als "nicht gefunden" — LaMetric antwortet auf unbekannte
    /// Nummern nicht einheitlich.
    private func fuehreAus(_ anfrage: URLRequest, sitzung: URLSession, nummer: String) throws -> Data {
        var ergebnis: Data?
        var antwort: URLResponse?
        var netzwerkFehler: Error?
        let fertig = DispatchSemaphore(value: 0)
        sitzung.dataTask(with: anfrage) { d, r, f in
            ergebnis = d; antwort = r; netzwerkFehler = f; fertig.signal()
        }.resume()
        guard fertig.wait(timeout: .now() + 10) == .success else {
            throw IconFehler.nichtGefunden(nummer)
        }
        if netzwerkFehler != nil {
            throw IconFehler.nichtGefunden(nummer)
        }
        if let http = antwort as? HTTPURLResponse, http.statusCode >= 400 {
            throw IconFehler.nichtGefunden(nummer)
        }
        guard let ergebnis else { throw IconFehler.nichtGefunden(nummer) }
        return ergebnis
    }

    private func namenDatei() -> URL { schreibordner.appendingPathComponent("names.json") }

    private func geladeneNamen() -> [String: (String, String)] {
        var tabelle: [String: (String, String)] = [:]
        for ordner in leseordner + [schreibordner] {
            guard let daten = try? Data(contentsOf: ordner.appendingPathComponent("names.json")),
                  let liste = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]]
            else { continue }
            for e in liste {
                if let n = e["nummer"] { tabelle[n] = (e["name"] ?? n, e["kategorie"] ?? "") }
            }
        }
        return tabelle
    }

    private func namenErgaenzen(nummer: String, name: String, kategorie: String) {
        var liste: [[String: String]] = []
        if let daten = try? Data(contentsOf: namenDatei()),
           let vorhanden = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]] {
            liste = vorhanden.filter { $0["nummer"] != nummer }
        }
        liste.append(["nummer": nummer, "name": name, "kategorie": kategorie])
        if let daten = try? JSONSerialization.data(withJSONObject: liste, options: [.prettyPrinted]) {
            try? daten.write(to: namenDatei())
        }
    }

    private func namenEntfernen(nummer: String) {
        guard let daten = try? Data(contentsOf: namenDatei()),
              let vorhanden = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]]
        else { return }
        let liste = vorhanden.filter { $0["nummer"] != nummer }
        if let neu = try? JSONSerialization.data(withJSONObject: liste, options: [.prettyPrinted]) {
            try? neu.write(to: namenDatei())
        }
    }
}
