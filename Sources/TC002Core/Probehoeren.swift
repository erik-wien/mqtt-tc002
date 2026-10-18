import Foundation

/// Welche Uhren zum Probehören einer Melodie infrage kommen und welche davon
/// vorgewählt ist. Probehören spielt auf genau einer Uhr; ohne Wahl wüsste
/// niemand, welche es ist.
public enum Probehoeren {
    /// Uhren mit Adresse (Melodien gehen nur über HTTP) und Lautsprecher, die
    /// Melodien nicht ausdrücklich ablehnen (`audio.rtttl` `false`). Unbekannt
    /// (nie abgefragt) zählt als fähig.
    public static func uhren(_ uhren: [Uhr], faehigkeiten: [UUID: Geraetefaehigkeiten]) -> [Uhr] {
        uhren.filter { !$0.host.isEmpty && spielt($0, faehigkeiten) }
    }

    /// Die vorgewählte Uhr: die gezeigte, wenn sie infrage kommt, sonst die erste.
    public static func vorgabe(unter infrage: [Uhr], gezeigt: UUID?) -> UUID? {
        if let gezeigt, infrage.contains(where: { $0.id == gezeigt }) { return gezeigt }
        return infrage.first?.id
    }

    /// Die Wahl des Nutzers, solange sie noch infrage kommt, sonst die Vorgabe.
    public static func ziel(gewaehlt: UUID?, unter infrage: [Uhr], gezeigt: UUID?) -> UUID? {
        if let gewaehlt, infrage.contains(where: { $0.id == gewaehlt }) { return gewaehlt }
        return vorgabe(unter: infrage, gezeigt: gezeigt)
    }

    /// Ob ein Hinweis „braucht eine Adresse“ angebracht ist: keine Uhr kommt
    /// infrage, und mindestens eine, die Melodien spielen kann, hat keine
    /// Adresse. Nur das kann der Nutzer ändern; eine Uhr ohne Lautsprecher oder
    /// ohne `rtttl` bekommt nie einen Hinweis.
    public static func brauchtAdresse(_ alle: [Uhr], faehigkeiten: [UUID: Geraetefaehigkeiten]) -> Bool {
        uhren(alle, faehigkeiten: faehigkeiten).isEmpty
            && alle.contains { $0.host.isEmpty && spielt($0, faehigkeiten) }
    }

    private static func spielt(_ uhr: Uhr, _ faehigkeiten: [UUID: Geraetefaehigkeiten]) -> Bool {
        uhr.hatLautsprecher && faehigkeiten[uhr.id]?.kann(.rtttl) != false
    }
}
