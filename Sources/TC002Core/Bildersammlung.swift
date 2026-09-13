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

    /// Legt das aktuelle Feld unter `name` ab — die Abkuerzung auf ein
    /// einzelnes Bild.
    @discardableResult
    public func sichern(name: String, feld: Pixelfeld) throws -> Gemaltes {
        try sichern(name: name, bilder: [feld.punkteRoh], verzoegerung: 0.2)
    }

    /// Legt ein oder mehrere 52×16-Raster unter `name` ab; mehrere ergeben ein
    /// animiertes GIF, das in Schleife laeuft. Gleicher Name ersetzt, statt zu
    /// verdoppeln — der Dateiname ergibt sich aus dem Namen, bereinigt um
    /// alles, was in Dateinamen nichts verloren hat.
    ///
    /// „Aus" bleibt durchsichtig statt Schwarz zu werden (`Bildraster.cgBild`):
    /// Ein ganzes Bild soll beim Laden wieder genauso leer sein, wie es gemalt
    /// wurde, und nur durchsichtige Einzelbilder laufen auf der Uhr sauber
    /// (Geraetereferenz, §4.2a).
    @discardableResult
    public func sichern(name: String, bilder: [[String?]], verzoegerung: Double) throws -> Gemaltes {
        let bereinigt = name.trimmingCharacters(in: .whitespaces)
        guard !bereinigt.isEmpty else { throw BildersammlungFehler.leererName }
        let breite = Pixelfeld.breiteStandard, hoehe = Pixelfeld.hoeheStandard
        guard !bilder.isEmpty, bilder.allSatisfy({ $0.count == breite * hoehe }) else {
            throw BildersammlungFehler.nichtSchreibbar
        }

        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let schluessel = Dateiname.aus(bereinigt)
        let ziel = ordner.appendingPathComponent("\(schluessel).gif")
        guard let senke = CGImageDestinationCreateWithURL(ziel as CFURL,
                            UTType.gif.identifier as CFString, bilder.count, nil) else {
            throw BildersammlungFehler.nichtSchreibbar
        }
        CGImageDestinationSetProperties(senke, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let jeBild = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: verzoegerung]
        ] as CFDictionary
        for pixel in bilder {
            guard let bild = try? Bildraster.cgBild(aus: pixel, breite: breite, hoehe: hoehe) else {
                throw BildersammlungFehler.nichtSchreibbar
            }
            CGImageDestinationAddImage(senke, bild, jeBild)
        }
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

    /// Liest ein gesichertes Bild mit allen seinen Einzelbildern und ihren
    /// Standzeiten zurueck — was der Editor braucht, um ein Laufbild wieder
    /// bearbeiten zu koennen. Ein unbewegtes Bild ergibt genau eines.
    public func einzelbilder(_ gemaltes: Gemaltes) throws -> [Bildraster.Einzelbild] {
        do {
            let bilder = try Bildraster.lesenMitZeiten(gemaltes.datei,
                                                       breite: Pixelfeld.breiteStandard,
                                                       hoehe: Pixelfeld.hoeheStandard)
            guard !bilder.isEmpty else { throw BildersammlungFehler.nichtLesbar }
            return bilder
        } catch {
            throw BildersammlungFehler.nichtLesbar
        }
    }

    /// Nimmt eine Bilddatei (GIF, PNG, JPEG) in die Sammlung auf, auf 52×16
    /// gerechnet. Ein animiertes GIF behaelt alle seine Einzelbilder.
    @discardableResult
    public func einfuegen(datei: URL, name: String) throws -> Gemaltes {
        let breite = Pixelfeld.breiteStandard, hoehe = Pixelfeld.hoeheStandard
        let gelesen = try Bildraster.lesenMitZeiten(datei, breite: breite, hoehe: hoehe)
        guard let erstes = gelesen.first else { throw BildersammlungFehler.nichtLesbar }
        return try sichern(name: name, bilder: gelesen.map(\.pixel),
                           verzoegerung: erstes.dauer)
    }

    public func loeschen(_ gemaltes: Gemaltes) throws {
        try FileManager.default.removeItem(at: gemaltes.datei)
        namenEntfernen(schluessel: gemaltes.datei.deletingPathExtension().lastPathComponent)
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
