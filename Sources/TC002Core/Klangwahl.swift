import Foundation

/// Der Klang einer Nachricht, wie ihn die Oberfläche wählt: keiner, ein Name von
/// der Uhr oder Vorlesen. Gemerkt wird die Wahl wie die übrigen Nachrichtenregler
/// (`@AppStorage`, JSON-Text); gesendet wird `klaenge(nachrichtentext:)`.
public struct Klangwahl: Hashable, Sendable, Codable {
    public enum Art: String, Sendable, Codable, CaseIterable {
        case keiner, uhr, vorlesen
    }

    public var art = Art.keiner
    /// Melodie oder MP3 von der Uhr; leer heißt: noch keine gewählt.
    public var name = ""
    /// Eigener Sprechtext; leer heißt: der Text der Nachricht.
    public var sprechtext = ""
    /// `loop`: Der Klang wiederholt sich, bis die Nachricht geht.
    public var wiederholen = false

    public init(art: Art = .keiner, name: String = "", sprechtext: String = "", wiederholen: Bool = false) {
        self.art = art
        self.name = name
        self.sprechtext = sprechtext
        self.wiederholen = wiederholen
    }

    // Von Hand und nachsichtig, wie `Darstellungswahl`: Ein fehlendes Feld heißt
    // Vorgabe; und die Vorgabe von `RawRepresentable` läuft so nicht in sich selbst.
    private enum CodingKeys: String, CodingKey { case art, name, sprechtext, wiederholen }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        art = (try? c.decodeIfPresent(Art.self, forKey: .art)) ?? .keiner
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        sprechtext = try c.decodeIfPresent(String.self, forKey: .sprechtext) ?? ""
        wiederholen = try c.decodeIfPresent(Bool.self, forKey: .wiederholen) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(art, forKey: .art)
        try c.encode(name, forKey: .name)
        try c.encode(sprechtext, forKey: .sprechtext)
        try c.encode(wiederholen, forKey: .wiederholen)
    }

    /// Mehr als so viele Byte nimmt die Uhr nicht zum Sprechen (§8).
    public static let sprechgrenze = Klang.sprechGrenze

    /// Höchstens `sprechgrenze` Byte; ein Zeichen wird nie halbiert.
    public static func gekuerzt(_ text: String) -> String {
        guard text.utf8.count > sprechgrenze else { return text }
        var kurz = text
        while kurz.utf8.count > sprechgrenze { kurz.removeLast() }
        return kurz
    }

    /// Was zu senden ist: leer bei „keiner“, bei „Von der Uhr“ ohne gewählten Namen
    /// und beim Vorlesen ohne Text. Der Sprechtext wird auf die Grenze gekürzt,
    /// damit eine lange Nachricht nicht den Klang (und mit ihm die Sendung) kippt.
    public func klaenge(nachrichtentext: String) -> [Klang] {
        switch art {
        case .keiner:
            return []
        case .uhr:
            guard !name.isEmpty else { return [] }
            return [Klang(.datei(name), wiederholen: wiederholen)]
        case .vorlesen:
            let eigener = sprechtext.trimmingCharacters(in: .whitespacesAndNewlines)
            let satz = Self.gekuerzt(eigener.isEmpty
                ? nachrichtentext.trimmingCharacters(in: .whitespacesAndNewlines) : eigener)
            guard !satz.isEmpty else { return [] }
            return [Klang(.sprache(satz), wiederholen: wiederholen)]
        }
    }

    /// Die Wahl, wie sie hinausgeht: Kann die Uhr es nicht, ist sie stumm — die
    /// Oberfläche sperrt die Wahl und sagt, warum.
    public func wirksam(von faehigkeiten: Geraetefaehigkeiten?) -> Klangwahl {
        gekonnt(von: faehigkeiten) ? self : Klangwahl()
    }

    /// Ob die Uhr die Fähigkeit meldet, die diese Art braucht. Eine Uhr, deren
    /// Fähigkeiten noch nicht abgefragt sind (`nil`), gilt als fähig: Die Prüfung
    /// vor dem Senden greift ohnehin.
    public func gekonnt(von faehigkeiten: Geraetefaehigkeiten?) -> Bool {
        guard let faehigkeiten else { return true }
        let ton = faehigkeiten.ton ?? Tonfaehigkeiten()
        switch art {
        case .keiner: return true
        case .uhr: return ton.mp3 || ton.rtttl
        case .vorlesen: return ton.speech
        }
    }
}

extension Klangwahl: RawRepresentable {
    /// Als JSON-Text: `@AppStorage` kennt nur einfache Typen.
    public init?(rawValue: String) {
        guard let daten = rawValue.data(using: .utf8),
              let w = try? JSONDecoder().decode(Klangwahl.self, from: daten) else { return nil }
        self = w
    }

    public var rawValue: String {
        let k = JSONEncoder()
        k.outputFormatting = [.sortedKeys]
        return (try? k.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}

/// Die Namen auf der Uhr, aus denen ein Klang gewählt wird.
public struct Tonlisten: Equatable, Sendable {
    public var melodien: [String]
    public var mp3: [String]

    public init(melodien: [String] = [], mp3: [String] = []) {
        self.melodien = melodien
        self.mp3 = mp3
    }

    public var leer: Bool { melodien.isEmpty && mp3.isEmpty }
}
