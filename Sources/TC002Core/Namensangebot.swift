import Foundation

/// Die Namen, die ein Menü anbietet, wenn die Nachricht an mehrere Uhren geht:
/// die Vereinigung über die Zieluhren, nicht die Liste der gerade angesehenen
/// Uhr. Ein Name genügt, wenn ihn eine Zieluhr kennt; die anderen weist
/// `Darstellung.pruefen(gegen:)` bzw. `Klangeignung` je Uhr ab, und die Ansicht
/// sagt vorher, welche das sind.
public enum Namensangebot {
    /// Alle Namen genau einmal, in der Schreibweise der ersten Uhr, sortiert.
    public static func vereinigt(_ listen: [[String]]) -> [String] {
        var gesehen = Set<String>()
        var ergebnis: [String] = []
        for name in listen.joined() where gesehen.insert(name.lowercased()).inserted {
            ergebnis.append(name)
        }
        return ergebnis.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

/// Eine Zieluhr, wie die Darstellungsmenüs sie sehen.
public struct Darstellungsziel: Equatable, Sendable {
    public var name: String
    /// `nil`, solange die Uhr nicht befragt ist: Sie trägt nichts zum Angebot
    /// bei und wird auch nicht als fehlend gezählt.
    public var faehigkeiten: Geraetefaehigkeiten?

    public init(name: String, faehigkeiten: Geraetefaehigkeiten? = nil) {
        self.name = name
        self.faehigkeiten = faehigkeiten
    }
}

/// Effekte, Overlays und Paletten, die mindestens eine Zieluhr kennt.
public struct Darstellungsangebot: Equatable, Sendable {
    public var effekte: [String]
    public var overlays: [String]
    public var paletten: [String]
    let ziele: [Darstellungsziel]

    public init(ziele: [Darstellungsziel]) {
        self.ziele = ziele
        let f = ziele.compactMap(\.faehigkeiten)
        effekte = Namensangebot.vereinigt(f.map(\.effekte))
        overlays = Namensangebot.vereinigt(f.map(\.overlays))
        paletten = Namensangebot.vereinigt(f.map(\.paletten))
    }

    /// Die Uhren, die diesen Effekt abweisen (`Darstellung.pruefen`: bei
    /// bekannten Listen muss er darin stehen).
    public func ohneEffekt(_ name: String) -> [String] {
        ziele.filter { z in z.faehigkeiten.map { Geraetefaehigkeiten.aufgeloest(name, in: $0.effekte) == nil } ?? false }.map(\.name)
    }

    public func ohneOverlay(_ name: String) -> [String] {
        ziele.filter { z in z.faehigkeiten.map { Geraetefaehigkeiten.aufgeloest(name, in: $0.overlays) == nil } ?? false }.map(\.name)
    }

    /// Eine Uhr mit leerer Palettenliste prüft den Namen nicht
    /// (`Palettenwahl.pruefen`), weist ihn also auch nicht ab.
    public func ohnePalette(_ name: String) -> [String] {
        ziele.filter { z in
            guard let f = z.faehigkeiten, !f.paletten.isEmpty else { return false }
            return Geraetefaehigkeiten.aufgeloest(name, in: f.paletten) == nil
        }.map(\.name)
    }
}
