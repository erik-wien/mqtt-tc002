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

public extension Array where Element == Icon {
    /// Filtert nach Name und Nummer, unabhaengig von Gross-/Kleinschreibung. Eine
    /// leere oder nur aus Leerraum bestehende Suche laesst die Liste unveraendert —
    /// dieselbe Logik fuer jede Stelle, die Icons durchsuchbar macht.
    func gefiltert(nach suche: String) -> [Icon] {
        let s = suche.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return self }
        return filter {
            $0.name.localizedCaseInsensitiveContains(s) || $0.nummer.localizedCaseInsensitiveContains(s)
        }
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

/// Rechnet Bilddateien (GIF, PNG, JPEG) auf eine gewuenschte Pixelgroesse herunter —
/// der gemeinsame Weg fuer Icons (8×8) und die Bildersammlung (52×16), damit es
/// nur eine Stelle gibt, die das tut.
public enum Bildraster {
    /// Liest eine Bilddatei als Farbraster, ein Eintrag je Einzelbild. Zeilenweise
    /// von oben links, `nil` heisst aus. Passt die Groesse nicht, wird ohne
    /// Glaettung gerechnet — bei acht oder sechzehn Pixeln Hoehe waere jede
    /// Zwischenfarbe Matsch.
    ///
    /// Der Ursprung bleibt die Falle: `CGContext` faengt unten links an, das
    /// Raster oben links. `draw(_:in:)` haelt sich an die visuelle Ausrichtung
    /// der Quelle, die Pufferzeile 0 ist bereits die oberste — eine
    /// Zeilen-Spiegelung hat sich hier schon zweimal als falsch erwiesen.
    public static func lesen(_ datei: URL, breite: Int, hoehe: Int) throws -> [[String?]] {
        guard let quelle = CGImageSourceCreateWithURL(datei as CFURL, nil) else {
            throw BildrasterFehler.nichtLesbar
        }
        let anzahl = CGImageSourceGetCount(quelle)
        guard anzahl > 0 else { throw BildrasterFehler.nichtLesbar }
        return try (0..<anzahl).map { i in
            guard let bild = CGImageSourceCreateImageAtIndex(quelle, i, nil) else {
                throw BildrasterFehler.nichtLesbar
            }
            return try pixel(aus: bild, breite: breite, hoehe: hoehe)
        }
    }

    /// Ein Einzelbild mitsamt der Zeit, die es vor dem naechsten steht.
    public struct Einzelbild: Equatable, Sendable {
        public var pixel: [String?]
        /// Sekunden bis zum naechsten Bild, aus der Datei gelesen.
        public var dauer: Double
    }

    /// Wie `lesen`, aber mit den Standzeiten je Einzelbild aus der Datei — fuer
    /// die abspielende Vorschau. Fehlt der Wert oder ist er unsinnig klein (unter
    /// 20 ms), gilt wie bei Browsern ueblich 0,1 Sekunden.
    public static func lesenMitZeiten(_ datei: URL, breite: Int, hoehe: Int) throws -> [Einzelbild] {
        guard let quelle = CGImageSourceCreateWithURL(datei as CFURL, nil) else {
            throw BildrasterFehler.nichtLesbar
        }
        let anzahl = CGImageSourceGetCount(quelle)
        guard anzahl > 0 else { throw BildrasterFehler.nichtLesbar }
        return try (0..<anzahl).map { i in
            guard let bild = CGImageSourceCreateImageAtIndex(quelle, i, nil) else {
                throw BildrasterFehler.nichtLesbar
            }
            let p = try pixel(aus: bild, breite: breite, hoehe: hoehe)
            return Einzelbild(pixel: p, dauer: verzoegerung(quelle, index: i))
        }
    }

    /// Liest die Standzeit eines Einzelbilds aus den GIF-Eigenschaften. Bevorzugt
    /// `UnclampedDelayTime` (die eigentlich gemeinte Zeit), ersatzweise `DelayTime`.
    private static func verzoegerung(_ quelle: CGImageSource, index: Int) -> Double {
        guard let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, index, nil) as? [CFString: Any],
              let gif = eigenschaften[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let wert = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
        guard let wert, wert >= 0.02 else { return 0.1 }
        return wert
    }

    /// Die Pixelgroesse des ersten Einzelbilds einer Datei, wenn lesbar — fuer den
    /// Hinweis, wenn eine eingelesene Datei umgerechnet werden musste.
    public static func groesse(_ datei: URL) -> (breite: Int, hoehe: Int)? {
        guard let quelle = CGImageSourceCreateWithURL(datei as CFURL, nil),
              let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any],
              let breite = eigenschaften[kCGImagePropertyPixelWidth] as? Int,
              let hoehe = eigenschaften[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (breite, hoehe)
    }

    /// Zeichnet erst 1:1 in einen Puffer in Quellgroesse — bei dieser Groesse
    /// gibt es nichts zu rechnen, `draw(_:in:)` kopiert nur — und tastet danach
    /// selbst ohne CoreGraphics ab. Ein Umweg ueber `draw(_:in:)` direkt auf
    /// Zielgroesse tastet naemlich um die Pixelmitte jedes Zielpixels ab: bei
    /// einem einzelnen farbigen Pixel in einem sonst leeren Bild trifft das
    /// oft daneben, und aus einer 16×16-Vorlage mit einem roten Pixel oben
    /// links wuerde beim Verkleinern auf 8×8 Schwarz statt Rot.
    private static func pixel(aus bild: CGImage, breite: Int, hoehe: Int) throws -> [String?] {
        let quellBreite = bild.width, quellHoehe = bild.height
        var quellBytes = [UInt8](repeating: 0, count: quellBreite * quellHoehe * 4)
        guard quellBreite > 0, quellHoehe > 0,
              let quellKontext = CGContext(data: &quellBytes, width: quellBreite, height: quellHoehe,
                                           bitsPerComponent: 8, bytesPerRow: quellBreite * 4,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw BildrasterFehler.nichtLesbar
        }
        quellKontext.interpolationQuality = .none
        quellKontext.draw(bild, in: CGRect(x: 0, y: 0, width: quellBreite, height: quellHoehe))

        var pixel = [String?](repeating: nil, count: breite * hoehe)
        for y in 0..<hoehe {
            let qy = min(quellHoehe - 1, y * quellHoehe / hoehe)
            for x in 0..<breite {
                let qx = min(quellBreite - 1, x * quellBreite / breite)
                let q = (qy * quellBreite + qx) * 4
                guard quellBytes[q + 3] != 0 else { continue }   // durchsichtig bleibt nil
                pixel[y * breite + x] = String(format: "#%02X%02X%02X",
                                               quellBytes[q], quellBytes[q + 1], quellBytes[q + 2])
            }
        }
        return pixel
    }

    /// Rechnet ein Farbraster in ein CGImage um. Zeilenweise von oben links, `nil`
    /// heisst aus und bleibt durchsichtig — warum, steht in der Schleife.
    /// Gemeinsamer Kern fuer jede Stelle, die ein Farbraster als Bild braucht —
    /// Icons wie Laufschrift.
    static func cgBild(aus pixel: [String?], breite: Int, hoehe: Int) throws -> CGImage {
        guard pixel.count == breite * hoehe else { throw BildrasterFehler.nichtLesbar }
        var bytes = [UInt8](repeating: 0, count: breite * hoehe * 4)
        for (i, farbe) in pixel.enumerated() {
            // Aus heisst durchsichtig, nicht schwarz. Das ist nicht kosmetisch:
            // ImageIO waehlt danach das Entsorgungsverfahren des GIFs. Deckende
            // Bilder ergeben Verfahren 1 ("stehenlassen, darueberzeichnen"), und
            // damit fehlen auf der Uhr einzelne Pixel — sie setzt das nicht um.
            // Durchsichtige ergeben Verfahren 2 ("vor jedem Bild loeschen"), und
            // damit steht jedes Einzelbild fuer sich. Am 11.09.2026 gemessen.
            guard let farbe else { continue }
            let (r, g, b) = zerlegen(farbe)
            bytes[i * 4] = r; bytes[i * 4 + 1] = g; bytes[i * 4 + 2] = b; bytes[i * 4 + 3] = 255
        }
        guard let anbieter = CGDataProvider(data: Data(bytes) as CFData),
              let bild = CGImage(width: breite, height: hoehe, bitsPerComponent: 8, bitsPerPixel: 32,
                                 bytesPerRow: breite * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: anbieter, decode: nil, shouldInterpolate: false,
                                 intent: .defaultIntent)
        else { throw BildrasterFehler.nichtLesbar }
        return bild
    }

    /// "#RRGGBB" in drei Bytes. Alles Unbrauchbare wird schwarz.
    private static func zerlegen(_ farbe: String?) -> (UInt8, UInt8, UInt8) {
        guard var s = farbe else { return (0, 0, 0) }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let wert = UInt32(s, radix: 16) else { return (0, 0, 0) }
        return (UInt8((wert >> 16) & 0xFF), UInt8((wert >> 8) & 0xFF), UInt8(wert & 0xFF))
    }

    /// Baut aus mehreren gleich grossen Farbrastern ein animiertes GIF in Schleife
    /// und gibt es direkt als Daten-URI zurueck, ohne Umweg ueber eine Datei — fuer
    /// Faelle wie die Laufschrift, die kein eigenes Icon in der Sammlung anlegen.
    public static func alsDatenURI(_ bilder: [[String?]], breite: Int, hoehe: Int, verzoegerung: Double) throws -> String {
        guard !bilder.isEmpty, bilder.allSatisfy({ $0.count == breite * hoehe }) else {
            throw BildrasterFehler.nichtLesbar
        }
        guard let daten = CFDataCreateMutable(nil, 0),
              let senke = CGImageDestinationCreateWithData(daten, UTType.gif.identifier as CFString, bilder.count, nil)
        else { throw BildrasterFehler.nichtLesbar }
        CGImageDestinationSetProperties(senke, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let jeBild = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: verzoegerung]
        ] as CFDictionary
        for pixel in bilder {
            CGImageDestinationAddImage(senke, try cgBild(aus: pixel, breite: breite, hoehe: hoehe), jeBild)
        }
        guard CGImageDestinationFinalize(senke) else { throw BildrasterFehler.nichtLesbar }
        return "data:image/gif;base64," + (daten as Data).base64EncodedString()
    }
}

public enum BildrasterFehler: Error, LocalizedError {
    case nichtLesbar

    public var errorDescription: String? {
        "Diese Datei lässt sich nicht als Bild lesen."
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
        do {
            guard let erstes = try Bildraster.lesen(icon.datei, breite: 8, hoehe: 8).first else {
                throw IconFehler.nichtLesbar(icon.nummer)
            }
            return erstes
        } catch {
            throw IconFehler.nichtLesbar(icon.nummer)
        }
    }

    /// Wie `bilder(fuer:)`, aber mit den Standzeiten aus der Datei. Der Editor
    /// braucht sie, um die Verzoegerung eines geoeffneten Icons anzuzeigen —
    /// ohne sie stuende dort immer der Anfangswert, und beim naechsten Sichern
    /// waere die eingestellte Zeit still ueberschrieben.
    public func einzelbilder(fuer icon: Icon) throws -> [Bildraster.Einzelbild] {
        do {
            let bilder = try Bildraster.lesenMitZeiten(icon.datei, breite: 8, hoehe: 8)
            guard !bilder.isEmpty else { throw IconFehler.nichtLesbar(icon.nummer) }
            return bilder
        } catch {
            throw IconFehler.nichtLesbar(icon.nummer)
        }
    }

    /// Liest alle Einzelbilder eines Icons — bei einem unbewegten Icon genau
    /// eines, bei einem animierten GIF jedes Frame in gespeicherter Reihenfolge.
    public func bilder(fuer icon: Icon) throws -> [[String?]] {
        do {
            let raster = try Bildraster.lesen(icon.datei, breite: 8, hoehe: 8)
            guard !raster.isEmpty else { throw IconFehler.nichtLesbar(icon.nummer) }
            return raster
        } catch {
            throw IconFehler.nichtLesbar(icon.nummer)
        }
    }

    /// Nimmt eine Bilddatei (GIF, PNG, JPEG) in die Sammlung auf, auf 8×8
    /// gerechnet. Animierte GIFs behalten ihre Einzelbilder. Die Quelldatei wird
    /// nicht kopiert, sondern ueber `sichern` neu geschrieben, damit in der
    /// Sammlung ausschliesslich Dateien in der richtigen Groesse liegen.
    @discardableResult
    public func einfuegen(datei: URL, nummer: String, name: String) throws -> Icon {
        let raster = try Bildraster.lesen(datei, breite: 8, hoehe: 8)
        return try sichern(nummer: nummer, name: name, bilder: raster, verzoegerung: 0.2)
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
    /// ohnehin einen schwarzen Grund — aus wird deshalb zu Schwarz. Abkuerzung auf
    /// ein einzelnes Bild.
    @discardableResult
    public func sichern(nummer: String, name: String, pixel: [String?]) throws -> Icon {
        try sichern(nummer: nummer, name: name, bilder: [pixel], verzoegerung: 0.2)
    }

    /// Legt ein selbst gemaltes Icon aus einem oder mehreren 8×8-Einzelbildern als
    /// GIF ab — mehrere ergeben ein animiertes GIF, das in Schleife laeuft.
    /// `verzoegerung` gilt je Einzelbild, in Sekunden.
    @discardableResult
    public func sichern(nummer: String, name: String,
                        bilder: [[String?]], verzoegerung: Double) throws -> Icon {
        guard !bilder.isEmpty, bilder.allSatisfy({ $0.count == 64 }) else {
            throw IconFehler.nichtSchreibbar(nummer)
        }
        try? FileManager.default.createDirectory(at: schreibordner, withIntermediateDirectories: true)
        let ziel = schreibordner.appendingPathComponent("\(nummer).gif")
        guard let senke = CGImageDestinationCreateWithURL(ziel as CFURL,
                            UTType.gif.identifier as CFString, bilder.count, nil) else {
            throw IconFehler.nichtSchreibbar(nummer)
        }
        CGImageDestinationSetProperties(senke, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let jeBild = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: verzoegerung]
        ] as CFDictionary
        for pixel in bilder {
            guard let bild = try? Bildraster.cgBild(aus: pixel, breite: 8, hoehe: 8) else {
                throw IconFehler.nichtSchreibbar(nummer)
            }
            CGImageDestinationAddImage(senke, bild, jeBild)
        }
        guard CGImageDestinationFinalize(senke) else { throw IconFehler.nichtSchreibbar(nummer) }

        namenErgaenzen(nummer: nummer, name: name, kategorie: "eigen")
        return Icon(nummer: nummer, name: name, kategorie: "eigen", datei: ziel)
    }

    /// Entfernt ein Icon aus dem Schreibordner. Alles ausserhalb — etwa der
    /// Grundschatz im Bundle, falls eine Sammlung ihn als Leseordner fuehrt —
    /// wird abgelehnt, nicht still uebergangen: die Oberflaeche baut ihre
    /// Sammlungen zwar ohne Leseordner, aber die Bibliothek soll auch ohne
    /// diese Ruecksicht nichts im App-Paket anfassen.
    public func loeschen(_ icon: Icon) throws {
        guard istEigen(icon) else {
            throw IconFehler.nichtSchreibbar(icon.nummer)
        }
        try FileManager.default.removeItem(at: icon.datei)
        namenEntfernen(nummer: icon.nummer)
    }

    /// Kopiert Dateien aus den Leseordnern, deren Nummer im Schreibordner noch
    /// fehlt, dorthin — mitsamt ihrem Eintrag in `names.json`. Vorhandene
    /// Dateien gleicher Nummer bleiben unangetastet: wer schon ein eigenes
    /// Icon mit dieser Nummer hat, behaelt es. Gibt zurueck, wie viele Dateien
    /// tatsaechlich kopiert wurden — Grundlage fuer die Meldung bei
    /// „Grundschatz wiederherstellen“.
    @discardableResult
    public func mitgelieferteUebernehmen() -> Int {
        guard !leseordner.isEmpty else { return 0 }
        try? FileManager.default.createDirectory(at: schreibordner, withIntermediateDirectories: true)
        var vorhandeneNummern = Set(
            ((try? FileManager.default.contentsOfDirectory(at: schreibordner,
                                                            includingPropertiesForKeys: nil)) ?? [])
                .filter { ["gif", "png", "jpg"].contains($0.pathExtension.lowercased()) }
                .map { $0.deletingPathExtension().lastPathComponent })
        let namen = geladeneNamen()
        var kopiert = 0
        // Die Namen werden gesammelt und am Ende in einem Zug geschrieben —
        // nicht je Datei einmal: dreissig Runden ueber eine wachsende
        // `names.json`, und ein Absturz mittendrin hinterliesse eine halbe.
        var neueNamen: [(String, String, String)] = []
        for ordner in leseordner {
            let dateien = (try? FileManager.default.contentsOfDirectory(at: ordner,
                           includingPropertiesForKeys: nil)) ?? []
            for datei in dateien where ["gif", "png", "jpg"].contains(datei.pathExtension.lowercased()) {
                let nummer = datei.deletingPathExtension().lastPathComponent
                guard !vorhandeneNummern.contains(nummer) else { continue }
                let ziel = schreibordner.appendingPathComponent(datei.lastPathComponent)
                guard (try? FileManager.default.copyItem(at: datei, to: ziel)) != nil else { continue }
                if let eintrag = namen[nummer] { neueNamen.append((nummer, eintrag.0, eintrag.1)) }
                vorhandeneNummern.insert(nummer)
                kopiert += 1
            }
        }
        if !neueNamen.isEmpty { namenErgaenzen(neueNamen) }
        return kopiert
    }

    /// Holt die mitgelieferten Icons genau einmal — beim allerersten Aufruf
    /// nach der Installation — in den Schreibordner; danach sind es ganz
    /// normale eigene Icons, loeschbar und aenderbar. Ein Merker in `defaults`
    /// sorgt dafuer, dass das nur einmal geschieht: der Ordnerinhalt selbst
    /// waere kein verlaesslicher Massstab — leer koennte auch "aufgeraeumt"
    /// statt "noch nie uebernommen" heissen, und ein zuvor geloeschtes Icon
    /// duerfte dann nicht zurueckkommen.
    @discardableResult
    public func grundschatzEinmalUebernehmen(defaults: UserDefaults = .standard) -> Int {
        let schluessel = "icons.grundschatzUebernommen"
        guard !defaults.bool(forKey: schluessel) else { return 0 }
        let kopiert = mitgelieferteUebernehmen()
        // Der Merker erst hinterher, und nur, wenn tatsaechlich etwas da war:
        // Schlaegt das Kopieren fehl — Leseordner nicht gefunden, Zielordner
        // nicht anlegbar —, bekommt der naechste Start noch einen Versuch,
        // statt den Anwender mit leerer Liste sitzen zu lassen.
        if kopiert > 0 || leseordnerLeer() { defaults.set(true, forKey: schluessel) }
        return kopiert
    }

    /// Ob in keinem Leseordner eine Bilddatei liegt — dann gibt es nichts zu
    /// holen, und der Merker darf trotz 0 kopierter Dateien gesetzt werden.
    private func leseordnerLeer() -> Bool {
        leseordner.allSatisfy { ordner in
            // Ein Ordner, der sich nicht lesen laesst, ist nicht leer, sondern
            // unerreichbar — das darf den Merker nicht setzen.
            guard let inhalt = try? FileManager.default.contentsOfDirectory(at: ordner,
                                                                           includingPropertiesForKeys: nil)
            else { return false }
            return inhalt.filter { ["gif", "png", "jpg"].contains($0.pathExtension.lowercased()) }.isEmpty
        }
    }

    /// Ob dieses Icon im Schreibordner liegt und sich damit ueber `loeschen`
    /// entfernen laesst. Nur relevant, wenn `icon` aus einer Sammlung mit
    /// gesetztem Leseordner stammt — die Oberflaeche liest inzwischen
    /// ausschliesslich den Schreibordner, dort ist es immer `true`.
    public func istEigen(_ icon: Icon) -> Bool {
        // deletingLastPathComponent() haengt einen abschliessenden Schraegstrich an,
        // standardizedFileURL entfernt ihn nicht — deshalb ueber die Pfad-Strings
        // vergleichen statt ueber die URLs selbst.
        Self.ordnerPfad(icon.datei.deletingLastPathComponent()) == Self.ordnerPfad(schreibordner)
    }

    private static func ordnerPfad(_ url: URL) -> String {
        var pfad = url.standardizedFileURL.path
        if pfad.hasSuffix("/") { pfad.removeLast() }
        return pfad
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
        namenErgaenzen([(nummer, name, kategorie)])
    }

    /// Traegt mehrere Namen in einem Schreibvorgang ein; vorhandene Eintraege
    /// derselben Nummer werden ersetzt. Geschrieben wird atomar — eine halbe
    /// `names.json` waere schlimmer als eine alte.
    private func namenErgaenzen(_ eintraege: [(nummer: String, name: String, kategorie: String)]) {
        var liste: [[String: String]] = []
        let neueNummern = Set(eintraege.map(\.nummer))
        if let daten = try? Data(contentsOf: namenDatei()),
           let vorhanden = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]] {
            liste = vorhanden.filter { !neueNummern.contains($0["nummer"] ?? "") }
        }
        for e in eintraege { liste.append(["nummer": e.nummer, "name": e.name, "kategorie": e.kategorie]) }
        if let daten = try? JSONSerialization.data(withJSONObject: liste, options: [.prettyPrinted]) {
            try? daten.write(to: namenDatei(), options: .atomic)
        }
    }

    private func namenEntfernen(nummer: String) {
        guard let daten = try? Data(contentsOf: namenDatei()),
              let vorhanden = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]]
        else { return }
        let liste = vorhanden.filter { $0["nummer"] != nummer }
        if let neu = try? JSONSerialization.data(withJSONObject: liste, options: [.prettyPrinted]) {
            try? neu.write(to: namenDatei(), options: .atomic)
        }
    }
}
