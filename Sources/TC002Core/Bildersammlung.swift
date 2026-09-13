import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Ein gesichertes 52×16-Bild in der Sammlung.
public struct Gemaltes: Equatable, Sendable {
    public var name: String
    public var datei: URL
    public init(name: String, datei: URL) {
        self.name = name; self.datei = datei
    }
}

public enum BildersammlungFehler: Error, LocalizedError {
    case leererName
    case nichtLesbar
    case nichtSchreibbar

    public var errorDescription: String? {
        switch self {
        case .leererName: return lok("Ein Name wird gebraucht.")
        case .nichtLesbar: return lok("Das Bild lässt sich nicht lesen.")
        case .nichtSchreibbar: return lok("Das Bild lässt sich nicht speichern.")
        }
    }
}

/// Mehrere gemalte 52×16-Bilder unter Namen — die Ablage neben dem einen
/// Arbeitsstand, den der Bereich „Bilder" ohnehin schon ueber Neustarts hinweg behaelt.
/// Gesichert wird als GIF, wie bei den Icons: so sind die Bilder auch
/// ausserhalb der App zu sehen.
public struct Bildersammlung {
    private let ordner: URL

    public init(ordner: URL) {
        self.ordner = ordner
    }

    public func alle() -> [Gemaltes] {
        let namen = geladeneNamen()
        let dateien = (try? FileManager.default.contentsOfDirectory(at: ordner,
                       includingPropertiesForKeys: nil)) ?? []
        return dateien
            .filter { $0.pathExtension.lowercased() == "gif" }
            .map { datei -> Gemaltes in
                let schluessel = datei.deletingPathExtension().lastPathComponent
                return Gemaltes(name: namen[schluessel] ?? schluessel, datei: datei)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Legt das aktuelle Feld unter `name` ab. Gleicher Name ersetzt, statt zu
    /// verdoppeln — der Dateiname ergibt sich aus dem Namen, bereinigt um
    /// alles, was in Dateinamen nichts verloren hat.
    @discardableResult
    public func sichern(name: String, feld: Pixelfeld) throws -> Gemaltes {
        let bereinigt = name.trimmingCharacters(in: .whitespaces)
        guard !bereinigt.isEmpty else { throw BildersammlungFehler.leererName }

        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let schluessel = Self.dateiname(aus: bereinigt)
        let ziel = ordner.appendingPathComponent("\(schluessel).gif")
        guard let senke = CGImageDestinationCreateWithURL(ziel as CFURL,
                            UTType.gif.identifier as CFString, 1, nil) else {
            throw BildersammlungFehler.nichtSchreibbar
        }
        CGImageDestinationAddImage(senke, try Self.cgBild(aus: feld), nil)
        guard CGImageDestinationFinalize(senke) else { throw BildersammlungFehler.nichtSchreibbar }

        namenErgaenzen(schluessel: schluessel, name: bereinigt)
        return Gemaltes(name: bereinigt, datei: ziel)
    }

    /// Liest ein gesichertes Bild als Pixelfeld zurueck, zeilenweise von oben
    /// links wie das Feld selbst.
    public func laden(_ gemaltes: Gemaltes) throws -> Pixelfeld {
        let breite = Pixelfeld.breiteStandard, hoehe = Pixelfeld.hoeheStandard
        do {
            guard let punkte = try Bildraster.lesen(gemaltes.datei, breite: breite, hoehe: hoehe).first,
                  let feld = Pixelfeld(breite: breite, hoehe: hoehe, punkte: punkte) else {
                throw BildersammlungFehler.nichtLesbar
            }
            return feld
        } catch {
            throw BildersammlungFehler.nichtLesbar
        }
    }

    /// Nimmt eine Bilddatei (GIF, PNG, JPEG) in die Sammlung auf, auf 52×16
    /// gerechnet. Bei mehreren Einzelbildern (animiertes GIF) zaehlt nur das
    /// erste — die Bildersammlung kennt, anders als Icons, keine Animation.
    @discardableResult
    public func einfuegen(datei: URL, name: String) throws -> Gemaltes {
        let breite = Pixelfeld.breiteStandard, hoehe = Pixelfeld.hoeheStandard
        guard let punkte = try Bildraster.lesen(datei, breite: breite, hoehe: hoehe).first,
              let feld = Pixelfeld(breite: breite, hoehe: hoehe, punkte: punkte) else {
            throw BildersammlungFehler.nichtLesbar
        }
        return try sichern(name: name, feld: feld)
    }

    public func loeschen(_ gemaltes: Gemaltes) throws {
        try FileManager.default.removeItem(at: gemaltes.datei)
        namenEntfernen(schluessel: gemaltes.datei.deletingPathExtension().lastPathComponent)
    }

    /// Rechnet ein Pixelfeld in ein CGImage um — der gemeinsame Kern von `sichern`.
    /// Anders als bei den Icons bleibt „aus" hier durchsichtig statt Schwarz zu
    /// werden: ein ganzes Bild soll beim Laden wieder genauso leer sein, wie es
    /// gemalt wurde, nicht mit schwarzen Flaechen ueberzogen.
    private static func cgBild(aus feld: Pixelfeld) throws -> CGImage {
        var bytes = [UInt8](repeating: 0, count: feld.breite * feld.hoehe * 4)
        for y in 0..<feld.hoehe {
            for x in 0..<feld.breite {
                let i = y * feld.breite + x
                guard let farbe = feld.farbe(x: x, y: y) else { continue }   // bleibt durchsichtig
                let (r, g, b) = zerlegen(farbe)
                bytes[i * 4] = r; bytes[i * 4 + 1] = g; bytes[i * 4 + 2] = b; bytes[i * 4 + 3] = 255
            }
        }
        guard let anbieter = CGDataProvider(data: Data(bytes) as CFData),
              let bild = CGImage(width: feld.breite, height: feld.hoehe, bitsPerComponent: 8, bitsPerPixel: 32,
                                 bytesPerRow: feld.breite * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: anbieter, decode: nil, shouldInterpolate: false,
                                 intent: .defaultIntent)
        else { throw BildersammlungFehler.nichtSchreibbar }
        return bild
    }

    /// "#RRGGBB" in drei Bytes. Unbrauchbares wird schwarz.
    private static func zerlegen(_ farbe: String) -> (UInt8, UInt8, UInt8) {
        var s = farbe
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let wert = UInt32(s, radix: 16) else { return (0, 0, 0) }
        return (UInt8((wert >> 16) & 0xFF), UInt8((wert >> 8) & 0xFF), UInt8(wert & 0xFF))
    }

    /// Entfernt aus einem Namen alles, was in Dateinamen nichts verloren hat.
    private static func dateiname(aus name: String) -> String {
        var ergebnis = name
        for zeichen in ["/", ":"] { ergebnis = ergebnis.replacingOccurrences(of: zeichen, with: "-") }
        return ergebnis
    }

    private func namenDatei() -> URL { ordner.appendingPathComponent("names.json") }

    private func geladeneNamen() -> [String: String] {
        guard let daten = try? Data(contentsOf: namenDatei()),
              let liste = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]]
        else { return [:] }
        var tabelle: [String: String] = [:]
        for e in liste {
            if let schluessel = e["datei"] { tabelle[schluessel] = e["name"] ?? schluessel }
        }
        return tabelle
    }

    private func namenErgaenzen(schluessel: String, name: String) {
        var liste: [[String: String]] = []
        if let daten = try? Data(contentsOf: namenDatei()),
           let vorhanden = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]] {
            liste = vorhanden.filter { $0["datei"] != schluessel }
        }
        liste.append(["datei": schluessel, "name": name])
        if let daten = try? JSONSerialization.data(withJSONObject: liste, options: [.prettyPrinted]) {
            try? daten.write(to: namenDatei())
        }
    }

    private func namenEntfernen(schluessel: String) {
        guard let daten = try? Data(contentsOf: namenDatei()),
              let vorhanden = try? JSONSerialization.jsonObject(with: daten) as? [[String: String]]
        else { return }
        let liste = vorhanden.filter { $0["datei"] != schluessel }
        if let neu = try? JSONSerialization.data(withJSONObject: liste, options: [.prettyPrinted]) {
            try? neu.write(to: namenDatei())
        }
    }
}

/// Wo die Bildersammlung liegt — neben den eigenen Icons, eigener Unterordner.
public enum Bilderordner {
    public static var eigene: URL {
        let ordner = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MQTT-TC002/Bilder")
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner
    }
}
