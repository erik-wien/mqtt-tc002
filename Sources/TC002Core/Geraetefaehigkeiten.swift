import Foundation

/// Die Namenslisten einer AWTRIX NG aus `GET /api/v1/capabilities`
/// (`docs/awtrix-ng-protokoll.md` §5.5, §7.4).
///
/// Die Listen stehen nie im Code: Eine Firmware kann Effekte, Overlays oder
/// Paletten hinzufügen oder streichen, und ein fest eingetragener Name wäre dann
/// ein stiller `422`. Gelesen werden sie je Uhr zur Laufzeit; Oberflächen
/// zeigen daraus ihre Auswahl, `Darstellung.pruefen(gegen:)` prüft damit.
///
/// Die Namen behalten die Schreibweise der Uhr. Die Uhr vergleicht `effect` und
/// `overlay` ohne Rücksicht auf Groß-/Kleinschreibung (§5.5); `aufgeloest` tut
/// dasselbe und liefert die Schreibweise der Liste.
public struct Geraetefaehigkeiten: Equatable, Sendable {
    public var effekte: [String]
    /// Die Effekte, die eine Palette nutzen (`paletteEffects`).
    public var paletteneffekte: [String]
    public var overlays: [String]
    public var paletten: [String]
    public var uebergaenge: [String]

    public init(effekte: [String] = [], paletteneffekte: [String] = [], overlays: [String] = [],
                paletten: [String] = [], uebergaenge: [String] = []) {
        self.effekte = effekte
        self.paletteneffekte = paletteneffekte
        self.overlays = overlays
        self.paletten = paletten
        self.uebergaenge = uebergaenge
    }

    /// Aus der Antwort von `GET /api/v1/capabilities`. Eine fehlende oder
    /// anders getypte Liste ist leer; `nil` nur, wenn gar keine der fünf Listen
    /// darin steht (das war dann keine Fähigkeitsauskunft).
    public init?(antwort: [String: Any]) {
        func liste(_ schluessel: String) -> [String]? {
            (antwort[schluessel] as? [Any])?.compactMap { $0 as? String }
        }
        let alle = ["effects", "paletteEffects", "overlays", "palettes", "transitions"].map(liste)
        guard alle.contains(where: { $0 != nil }) else { return nil }
        self.init(effekte: alle[0] ?? [], paletteneffekte: alle[1] ?? [], overlays: alle[2] ?? [],
                  paletten: alle[3] ?? [], uebergaenge: alle[4] ?? [])
    }

    /// Die Schreibweise aus der Liste, ohne Rücksicht auf Groß-/Kleinschreibung.
    public static func aufgeloest(_ name: String, in liste: [String]) -> String? {
        liste.first { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Ob dieser Effekt die Palette der Anzeige nutzt (§5.5: alle außer
    /// `PingPong`, `Matrix`, `LookingEyes`).
    public func nutztPalette(effekt: String) -> Bool {
        Self.aufgeloest(effekt, in: paletteneffekte) != nil
    }
}
