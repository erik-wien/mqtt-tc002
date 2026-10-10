import Foundation

/// Wo die Klangsammlung liegt: einer der Bestände von `Ablageort`, also
/// örtlich oder im iCloud-Behälter, und damit für App und Werkzeug derselbe.
public enum Klangordner {
    public static var eigene: URL { Ablageort.gemeinsam.ordner(.klaenge) }
}

public enum Sammlungsart: String, Sendable, Equatable {
    case melodie, mp3
}

/// Ein Klang der Sammlung. Eine Melodie liegt als `<name>.txt` (der RTTTL-Text,
/// wie die Uhr sie unter `/MELODIES/` führt), eine MP3 als `<name>.mp3`.
public struct Sammlungsklang: Equatable, Sendable, Identifiable {
    public var name: String
    public var art: Sammlungsart
    /// Byte: bei einer Melodie die Länge des Textes, bei einer MP3 die der Datei.
    public var groesse: Int
    public var datei: URL
    /// Der RTTTL-Text mit dem Melodienamen als Namensteil; bei einer MP3 `nil`.
    public var rtttl: String?

    public var id: String { art.rawValue + "/" + name }

    public init(name: String, art: Sammlungsart, groesse: Int, datei: URL, rtttl: String?) {
        self.name = name; self.art = art; self.groesse = groesse; self.datei = datei; self.rtttl = rtttl
    }
}

public enum SammlungFehler: Error, LocalizedError, Equatable {
    case nameBelegt(String)
    case unbekannt(String)
    case nichtLesbar(String)
    case nichtSchreibbar(String)

    public var errorDescription: String? {
        switch self {
        case .nameBelegt(let n): return lokf("„%@“ gibt es in der Sammlung schon. Melodien und MP3-Dateien teilen sich die Namen.", n)
        case .unbekannt(let n): return lokf("„%@“ ist nicht in der Sammlung.", n)
        case .nichtLesbar(let n): return lokf("Die Datei „%@“ lässt sich nicht lesen.", n)
        case .nichtSchreibbar(let n): return lokf("„%@“ lässt sich nicht speichern.", n)
        }
    }
}

/// Die Klangsammlung der App: das Original, nach dem die Uhren abgeglichen
/// werden (`Klangabgleich`). Namen gelten wie auf der Uhr — Melodie
/// `[A-Za-z0-9_-]` 1–24 Zeichen, MP3 1–32 — und sind über beide Arten hinweg
/// eindeutig, denn die Uhr weist einen gleichen Namen mit `409 nameTaken` ab.
public struct Klangsammlung {
    private let ordner: URL

    public init(ordner: URL) { self.ordner = ordner }

    private func datei(_ name: String, _ art: Sammlungsart) -> URL {
        ordner.appendingPathComponent(name + (art == .melodie ? ".txt" : ".mp3"))
    }

    // MARK: - Lesen

    public func alle() -> [Sammlungsklang] {
        let dateien = (try? FileManager.default.contentsOfDirectory(
            at: ordner, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        var ergebnis: [Sammlungsklang] = []
        for d in dateien {
            let name = d.deletingPathExtension().lastPathComponent
            switch d.pathExtension.lowercased() {
            case "txt":
                guard (try? Klangbau.melodienameInOrdnung(name)) != nil,
                      let text = try? String(contentsOf: d, encoding: .utf8),
                      let rtttl = try? Rtttl.geprueft(text) else { continue }
                ergebnis.append(Sammlungsklang(name: name, art: .melodie, groesse: rtttl.utf8.count,
                                               datei: d, rtttl: rtttl))
            case "mp3":
                guard Klangname.gueltig(name) else { continue }
                let g = (try? d.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                ergebnis.append(Sammlungsklang(name: name, art: .mp3, groesse: g, datei: d, rtttl: nil))
            default: continue
            }
        }
        return ergebnis.sorted {
            $0.art != $1.art ? $0.art == .melodie : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public func melodien() -> [Sammlungsklang] { alle().filter { $0.art == .melodie } }
    public func mp3() -> [Sammlungsklang] { alle().filter { $0.art == .mp3 } }

    public func klang(_ name: String) -> Sammlungsklang? { alle().first { $0.name == name } }

    private func belegt(_ name: String, ausser: String? = nil) -> Bool {
        name != ausser && alle().contains { $0.name == name }
    }

    // MARK: - Schreiben

    /// Legt eine Melodie an oder ersetzt eine gleichnamige Melodie. Der Namensteil
    /// des Textes wird auf `name` gesetzt, wie die Uhr es auch tut.
    @discardableResult
    public func melodieSichern(name: String, rtttl: String) throws -> Sammlungsklang {
        try Klangbau.melodienameInOrdnung(name)
        let text = try Rtttl.geprueft(Rtttl.mitName(try Rtttl.geprueft(rtttl), name: name))
        if let vorhanden = klang(name), vorhanden.art == .mp3 { throw SammlungFehler.nameBelegt(name) }
        let ziel = datei(name, .melodie)
        try schreiben(Data(text.utf8), nach: ziel, name: name)
        return Sammlungsklang(name: name, art: .melodie, groesse: text.utf8.count, datei: ziel, rtttl: text)
    }

    /// Legt eine MP3 an oder ersetzt eine gleichnamige MP3. Grenzen und Format
    /// wie beim Hochladen auf die Uhr.
    @discardableResult
    public func mp3Sichern(name: String, daten: Data) throws -> Sammlungsklang {
        guard Klangname.gueltig(name) else { throw KlangFehler.ungueltigerKlangname(name) }
        guard !daten.isEmpty else { throw KlangFehler.mp3Leer }
        guard daten.count <= Geraet.mp3Hoechstgroesse else {
            throw KlangFehler.mp3ZuGross(bytes: daten.count, grenze: Geraet.mp3Hoechstgroesse)
        }
        guard Self.istMP3(daten) else { throw KlangFehler.keinMP3 }
        if let vorhanden = klang(name), vorhanden.art == .melodie { throw SammlungFehler.nameBelegt(name) }
        let ziel = datei(name, .mp3)
        try schreiben(daten, nach: ziel, name: name)
        return Sammlungsklang(name: name, art: .mp3, groesse: daten.count, datei: ziel, rtttl: nil)
    }

    /// Als MP3 gilt, was mit `ID3` oder einem MPEG-Frame-Sync beginnt.
    public static func istMP3(_ daten: Data) -> Bool {
        let b = [UInt8](daten.prefix(3))
        if b == [0x49, 0x44, 0x33] { return true }
        return b.count >= 2 && b[0] == 0xFF && b[1] & 0xE0 == 0xE0
    }

    private func schreiben(_ daten: Data, nach ziel: URL, name: String) throws {
        do {
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try daten.write(to: ziel, options: .atomic)
        } catch { throw SammlungFehler.nichtSchreibbar(name) }
    }

    public func umbenennen(_ klang: Sammlungsklang, nach neu: String) throws {
        guard neu != klang.name else { return }
        switch klang.art {
        case .melodie: try Klangbau.melodienameInOrdnung(neu)
        case .mp3: guard Klangname.gueltig(neu) else { throw KlangFehler.ungueltigerKlangname(neu) }
        }
        guard !belegt(neu) else { throw SammlungFehler.nameBelegt(neu) }
        guard FileManager.default.fileExists(atPath: klang.datei.path) else {
            throw SammlungFehler.unbekannt(klang.name)
        }
        switch klang.art {
        case .melodie:
            try melodieSichern(name: neu, rtttl: klang.rtttl ?? "")
            try? FileManager.default.removeItem(at: klang.datei)
        case .mp3:
            do { try FileManager.default.moveItem(at: klang.datei, to: datei(neu, .mp3)) }
            catch { throw SammlungFehler.nichtSchreibbar(neu) }
        }
    }

    public func loeschen(_ klang: Sammlungsklang) throws {
        do { try FileManager.default.removeItem(at: klang.datei) }
        catch { throw SammlungFehler.unbekannt(klang.name) }
    }

    // MARK: - Von der Uhr übernehmen

    public struct Uebernahme: Equatable, Sendable {
        public var neu: [String] = []
        public var ersetzt: [String] = []
        public var gleich: [String] = []
        /// Name, Grund.
        public var uebersprungen: [(name: String, grund: String)] = []

        public static func == (a: Uebernahme, b: Uebernahme) -> Bool {
            a.neu == b.neu && a.ersetzt == b.ersetzt && a.gleich == b.gleich
                && a.uebersprungen.map(\.name) == b.uebersprungen.map(\.name)
        }
    }

    /// Übernimmt die Melodien einer Uhr (`GET /api/v1/audio/melodies` mit
    /// `rtttl`). Was die Sammlung anders führt, bleibt, wie es ist — die Sammlung
    /// ist das Original —, außer `ersetzen` ist gesetzt. MP3-Dateien kommen nicht
    /// mit: Ein Abruf der gespeicherten Datei ist nicht gemessen.
    public func uebernehmen(melodien liste: Tonablage, ersetzen: Bool = false) -> Uebernahme {
        var bilanz = Uebernahme()
        for name in liste.namen {
            guard let text = liste.texte[name] else {
                bilanz.uebersprungen.append((name, lok("Die Uhr nennt den Text nicht.")))
                continue
            }
            do {
                let neuerText = try Rtttl.geprueft(Rtttl.mitName(try Rtttl.geprueft(text), name: name))
                if let alt = klang(name) {
                    if alt.art == .mp3 { throw SammlungFehler.nameBelegt(name) }
                    if alt.rtttl == neuerText { bilanz.gleich.append(name); continue }
                    if !ersetzen {
                        bilanz.uebersprungen.append((name, lok("Die Sammlung hat eine andere Fassung.")))
                        continue
                    }
                    try melodieSichern(name: name, rtttl: neuerText)
                    bilanz.ersetzt.append(name)
                } else {
                    try melodieSichern(name: name, rtttl: neuerText)
                    bilanz.neu.append(name)
                }
            } catch {
                bilanz.uebersprungen.append((name, (error as? LocalizedError)?.errorDescription ?? "\(error)"))
            }
        }
        return bilanz
    }
}
