import Foundation

/// Was ein Klang von der Uhr verlangt, gemessen an `capabilities.audio` (§7.4).
/// `melodie` und `rtttl` brauchen dieselbe Fähigkeit (`rtttl`): Eine gespeicherte
/// Melodie liegt unter `/MELODIES/` und wird von demselben Spieler gespielt wie
/// ein RTTTL-Text. Die TC001 spielt Melodien, aber keine MP3 (gemessen
/// 10. Oktober 2026).
public enum Klangart: String, CaseIterable, Sendable {
    case mp3, melodie, rtttl, lied, sprache, radio, adresse
}

extension Tonfaehigkeiten {
    public func kann(_ art: Klangart) -> Bool {
        switch art {
        case .mp3: return mp3
        case .melodie, .rtttl: return rtttl
        case .lied: return song
        case .sprache: return speech
        case .radio: return radio
        case .adresse: return url
        }
    }
}

extension Geraetefaehigkeiten {
    /// Ob die Uhr diese Klangart spielt. Fehlt die Auskunft über `audio`
    /// (`ton == nil`), gilt sie als fähig: Eine ältere oder noch nicht
    /// abgefragte Uhr wird nicht ausgesperrt, und die Prüfung vor dem Senden
    /// sowie die Uhr selbst weisen Falsches ab.
    public func kann(_ art: Klangart) -> Bool {
        ton?.kann(art) ?? true
    }
}

extension Klang {
    /// Die Klangarten, von denen eine genügt. Ein Dateiname ohne Pfad ist eine
    /// MP3 oder eine gespeicherte Melodie: Welche, sagen die Listen der Uhr
    /// (`listen`); ist der Name dort nicht zu finden (Listen fehlen oder er ist
    /// neu), kommt beides infrage.
    public func arten(listen: Tonlisten?) -> [Klangart] {
        switch quelle {
        case .rtttl: return [.rtttl]
        case .lied: return [.lied]
        case .sprache: return [.sprache]
        case .sender, .senderPosition: return [.radio]
        case .datei(let name):
            if Self.istAdresse(name) { return [.adresse] }
            let klein = name.lowercased()
            if klein.hasPrefix("melodies/") || klein.hasPrefix("/melodies/") { return [.melodie] }
            if klein.hasPrefix("mp3/") || klein.hasPrefix("/mp3/") { return [.mp3] }
            if let listen {
                if listen.melodien.contains(name) { return [.melodie] }
                if listen.mp3.contains(name) { return [.mp3] }
            }
            return [.mp3, .melodie]
        }
    }

    /// Ob die Uhr diesen Klang spielen kann.
    public func gekonnt(von faehigkeiten: Geraetefaehigkeiten?, listen: Tonlisten? = nil) -> Bool {
        guard let faehigkeiten else { return true }
        return arten(listen: listen).contains { faehigkeiten.kann($0) }
    }
}

/// Eine Uhr, an die ein Klang gehen soll, mit dem, was über sie bekannt ist.
public struct Klangziel: Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var faehigkeiten: Geraetefaehigkeiten?
    public var listen: Tonlisten?

    public init(id: UUID, name: String, faehigkeiten: Geraetefaehigkeiten? = nil, listen: Tonlisten? = nil) {
        self.id = id
        self.name = name
        self.faehigkeiten = faehigkeiten
        self.listen = listen
    }
}

/// Was von einem Klang bei welcher Uhr ankommt.
public struct Klangverteilung: Equatable, Sendable {
    /// Je Uhr die Klänge, die sie spielen kann (womöglich keine).
    public var klaenge: [UUID: [Klang]]
    /// Die Uhren, bei denen mindestens ein Klang entfällt — für den Hinweis.
    public var uebersprungen: [Klangziel]

    public init(klaenge: [UUID: [Klang]] = [:], uebersprungen: [Klangziel] = []) {
        self.klaenge = klaenge
        self.uebersprungen = uebersprungen
    }

    /// Die Namen der Uhren, bei denen etwas entfällt, für Meldungen.
    public var uebersprungeneNamen: [String] { uebersprungen.map(\.name) }
}

/// Die Regel für mehrere Zieluhren: Ein Klang geht nur an die Uhren, die ihn
/// spielen; die Nachricht selbst geht an alle.
public enum Klangeignung {
    public static func verteilen(_ klaenge: [Klang], an ziele: [Klangziel]) -> Klangverteilung {
        var ergebnis = Klangverteilung()
        for ziel in ziele {
            let spielbar = klaenge.filter { $0.gekonnt(von: ziel.faehigkeiten, listen: ziel.listen) }
            ergebnis.klaenge[ziel.id] = spielbar
            if spielbar.count < klaenge.count { ergebnis.uebersprungen.append(ziel) }
        }
        return ergebnis
    }

    /// Die Klangarten, die alle Ziele spielen. Ohne Ziel ist es jede.
    public static func gemeinsam(_ ziele: [Klangziel]) -> Set<Klangart> {
        Set(Klangart.allCases.filter { art in ziele.allSatisfy { $0.faehigkeiten?.kann(art) ?? true } })
    }

    /// Die Ziele, die diese Klangart nicht spielen.
    public static func ohne(_ art: Klangart, in ziele: [Klangziel]) -> [Klangziel] {
        ziele.filter { !($0.faehigkeiten?.kann(art) ?? true) }
    }

    /// Die Ziele, die diese Wahl nicht spielen: für „Von der Uhr“ ohne Namen
    /// die, die weder MP3 noch Melodien können.
    public static func ohne(_ wahl: Klangwahl, in ziele: [Klangziel]) -> [Klangziel] {
        ziele.filter { !wahl.gekonnt(von: $0.faehigkeiten, listen: $0.listen) }
    }

    /// Ob nur ein Teil der Ziele die Wahl spielt (mindestens eines kann, eines nicht).
    public static func teilweise(_ wahl: Klangwahl, in ziele: [Klangziel]) -> Bool {
        let nein = ohne(wahl, in: ziele).count
        return nein > 0 && nein < ziele.count
    }

    /// Ob MP3-Dateien für diese Ziele überhaupt vorkommen: nicht, wenn jedes Ziel
    /// sie als nicht spielbar meldet. Ohne Ziel oder ohne Auskunft gelten sie als da.
    public static func mp3Zeigen(in ziele: [Klangziel]) -> Bool {
        ziele.isEmpty || ohne(.mp3, in: ziele).count < ziele.count
    }

    /// Ob das Hochladen einer MP3 bei dieser Uhr sinnvoll ist: Die TC001 nimmt
    /// die Datei an, kann sie aber nicht spielen.
    public static func mp3Hochladbar(_ faehigkeiten: Geraetefaehigkeiten?) -> Bool {
        faehigkeiten?.kann(.mp3) ?? true
    }
}
