import Foundation

/// Ein benannter Sendestand: der Auftrag samt allem, was zum Senden gehört.
public struct Favorit: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var titel: String
    public var auftrag: Sendeauftrag

    public init(id: UUID = UUID(), titel: String, auftrag: Sendeauftrag) {
        self.id = id
        self.titel = titel
        self.auftrag = auftrag
    }

    // Die Datei kann in iCloud liegen und von älteren oder neueren Fassungen
    // geschrieben sein: ein fehlender Titel wirft nicht.
    private enum CodingKeys: String, CodingKey { case id, titel, auftrag }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        titel = try c.decodeIfPresent(String.self, forKey: .titel) ?? ""
        auftrag = try c.decode(Sendeauftrag.self, forKey: .auftrag)
    }
}

/// Listenoperationen als reine Funktionen: Reihenfolge ist die der Liste,
/// jede Änderung liefert eine neue.
public enum Favoriten {
    /// Getrimmt; `nil`, wenn nichts übrig bleibt.
    public static func gueltigerTitel(_ roh: String) -> String? {
        let t = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    public static func anfuegen(_ f: Favorit, an liste: [Favorit]) -> [Favorit] { liste + [f] }

    /// Gleiche `id`, gleiche Stelle; unbekannte `id` ändert nichts.
    public static func ersetzen(_ f: Favorit, in liste: [Favorit]) -> [Favorit] {
        liste.map { $0.id == f.id ? f : $0 }
    }

    /// Für das Duplizieren: direkt hinter dem Original, fehlt es ans Ende.
    public static func einfuegen(_ f: Favorit, hinter id: UUID, in liste: [Favorit]) -> [Favorit] {
        guard let i = liste.firstIndex(where: { $0.id == id }) else { return liste + [f] }
        var neu = liste
        neu.insert(f, at: i + 1)
        return neu
    }

    public static func umbenennen(_ id: UUID, zu titel: String, in liste: [Favorit]) -> [Favorit] {
        liste.map { f in
            guard f.id == id else { return f }
            var g = f
            g.titel = titel
            return g
        }
    }

    public static func entfernen(_ id: UUID, aus liste: [Favorit]) -> [Favorit] {
        liste.filter { $0.id != id }
    }

    public static func kopietitel(_ titel: String) -> String { lokf("%@ Kopie", titel) }
}

/// Die Favoriten als eine Datei für die ganze Liste. Bei Änderungen auf zwei
/// Geräten gewinnt, wer zuletzt schreibt; eine Datei je Gerät wie beim
/// `Sendeverlauf` würde die Reihenfolge und das Löschen unlösbar machen.
public final class Favoritenablage: @unchecked Sendable {
    private let datei: URL

    public init(ordner: URL = Ablageort.gemeinsam.ordner(.favoriten)) {
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        datei = ordner.appendingPathComponent("Favoriten.json")
    }

    /// Fehlende oder unlesbare Datei ergibt eine leere Liste.
    public func alle() -> [Favorit] {
        guard let daten = try? Data(contentsOf: datei),
              let liste = try? JSONDecoder().decode([Favorit].self, from: daten) else { return [] }
        return liste
    }

    @discardableResult
    public func sichern(_ liste: [Favorit]) -> Bool {
        guard let daten = try? JSONEncoder().encode(liste) else { return false }
        return (try? daten.write(to: datei, options: .atomic)) != nil
    }
}
