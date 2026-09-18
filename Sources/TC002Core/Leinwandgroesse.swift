import Foundation

/// Die drei Groessen, in denen gemalt wird — und alles, was daraus folgt.
///
/// Es ist eine Taetigkeit: Pixel malen. Was dabei herauskommt, entscheidet
/// allein die Leinwandgroesse, nicht zwei getrennte Bereiche „Icons" und
/// „Bilder" mit unklarem Unterschied.
///
/// Damit die Unterschiede, die es wirklich gibt, nicht als Sonderfaelle durch
/// die Oberflaeche wandern, stehen sie hier abgeleitet und an einer Stelle:
///
/// | Groesse | Was es ist              | Nummer | heisst nach | Senden |
/// |---------|-------------------------|--------|-------------|--------|
/// | 8×8     | kanonisches LaMetric-Icon | ja   | der Nummer  | nein   |
/// | 16×16   | Icon ohne Nummer        | nein   | dem Namen   | nein   |
/// | 16×52   | die ganze Anzeige       | ja     | dem Namen   | ja     |
public enum Leinwandgroesse: String, CaseIterable, Sendable, Identifiable {
    case icon8, icon16, anzeige

    public var id: String { rawValue }

    public var breite: Int {
        switch self {
        case .icon8: return 8
        case .icon16: return 16
        case .anzeige: return Pixelfeld.breiteStandard
        }
    }

    public var hoehe: Int {
        switch self {
        case .icon8: return 8
        case .icon16: return 16
        case .anzeige: return Pixelfeld.hoeheStandard
        }
    }

    /// Wie die Groesse in der Oberflaeche heisst. Hoehe × Breite bei der
    /// Anzeige, weil sie liegend ist und „52×16" sich niemand als Bild denkt.
    ///
    /// Nachgeschlagen wird das ueber `lok(...)`, also ueber eine Variable —
    /// deshalb stehen die drei Zeichenketten von Hand als `DYNAMISCH` in
    /// `scripts/texte-sammeln.py`.
    /// Ob ein Stück dieser Größe selbst als Anzeige auf die Uhr geht — dann
    /// hat es eine eigene Standzeit. Ein Icon ist Zubehör einer Meldung; seine
    /// Dauer bestimmt die Meldung, nicht das Icon.
    public var eigeneStandzeit: Bool {
        switch self {
        case .icon8, .icon16: return false
        case .anzeige: return true
        }
    }

    public var beschriftung: String {
        switch self {
        case .icon8: return "8 × 8"
        case .icon16: return "16 × 16"
        case .anzeige: return "16 × 52"
        }
    }

    /// Dieselbe Groesse in einem Wort — fuer eine Filterleiste, die im
    /// schmalen Inspektor am iPad sonst „8…", „16…", „16…" anzeigt und damit
    /// zwei Groessen ununterscheidbar macht.
    ///
    /// Genommen wird die Zahl, die unterscheidet: 8×8 und 16×16 an ihrer
    /// Kante, 16×52 an ihrer Breite. Nebeneinander in einer Leiste ist das
    /// eindeutig, und daneben steht in jeder Zeile der Liste die ganze
    /// Angabe.
    public var kurzbeschriftung: String {
        switch self {
        case .icon8: return "8"
        case .icon16: return "16"
        case .anzeige: return "52"
        }
    }

    /// Nur die ganze Anzeige laesst sich an die Uhr schicken. Ein Icon ist fuer
    /// sich keine Anzeige — es steht unter „Senden" neben einem Text.
    public var sendbar: Bool {
        breite == Pixelfeld.breiteStandard && hoehe == Pixelfeld.hoeheStandard
    }

    /// Ob es zu dieser Groesse ueberhaupt eine Nummer gibt — und das ist eine
    /// Tatsache ueber die Welt, keine ueber die Masse: nicht ableitbar,
    /// deshalb aufgezaehlt.
    ///
    /// | Groesse | Nummer | woher |
    /// |---------|--------|-------|
    /// | 8×8     | ja     | die LaMetric-Iconnummer |
    /// | 16×16   | nein   | nicht kanonisch, von uns eingefuehrt |
    /// | 16×52   | ja     | die Ulanzi-Werknummer (`ugc.ulanzistudio.com`, Kategorie „Pixel Art 16×52") |
    public var mitNummer: Bool {
        switch self {
        case .icon8: return true
        case .icon16: return false
        case .anzeige: return true
        }
    }

    /// Ob die Nummer zugleich der Dateiname ist. Nur beim 8×8: Dort ist sie
    /// der Schluessel, unter dem das Icon liegt, und muss deshalb eindeutig
    /// sein und da sein.
    ///
    /// Bei 16×52 traegt die Datei weiter den Namen, die Nummer steht daneben in
    /// `names.json`. Das ist der Unterschied zwischen „hat eine Nummer" und
    /// „heisst nach der Nummer", und er entscheidet ueber bestehende
    /// Sammlungen: Wer dort den Dateinamen umstellte, machte jede vorhandene
    /// Bildersammlung unlesbar.
    public var nummerIstDateiname: Bool { breite == 8 && hoehe == 8 }

    /// Welche Groessen sich in eine Leinwand dieser Groesse setzen lassen:
    /// nur kleinere oder gleich grosse.
    ///
    /// Der umgekehrte Weg kommt ausdruecklich nicht vor — Verkleinern
    /// zerstoert. Abgeleitet aus den Massen und
    /// nicht aufgezaehlt: Eine vierte Groesse haette hier nichts zu aendern.
    public var aufnehmbar: [Leinwandgroesse] {
        Self.allCases.filter { $0 != self && $0.breite <= breite && $0.hoehe <= hoehe }
    }

    /// Ob „Icon einfuegen" in dieser Groesse ueberhaupt etwas anzubieten hat.
    /// Bei 8×8 nichts: Es ist die kleinste.
    public var iconEinfuegbar: Bool { !aufnehmbar.isEmpty }

    /// Wie ein Icon dieser Groesse in `ziel` gesetzt wird — mit welchem
    /// Faktor hochgerechnet und mit welcher linken oberen Ecke. `nil`, wenn es
    /// dort nicht hineingehoert.
    ///
    /// Hochgerechnet wird nur in ein Icon. 8×8 auf 16×16 heisst: Jedes
    /// Pixel wird ein Viererblock, das Ergebnis fuellt die Flaeche. In die
    /// Anzeige geht ein Icon dagegen in seiner Groesse — an genau der
    /// Stelle, an der es auch unter „Senden" laege (`Meldungsbau.iconY`): ein
    /// 8×8 senkrecht mittig auf Zeile 4, ein 16×16 ueber die volle Hoehe.
    public func einsatz(in ziel: Leinwandgroesse) -> (faktor: Int, x: Int, y: Int)? {
        guard ziel.aufnehmbar.contains(self) else { return nil }
        let faktor = ziel.breite == ziel.hoehe ? ziel.hoehe / hoehe : 1
        return (faktor, 0, (ziel.hoehe - hoehe * faktor) / 2)
    }

    /// Eine leere Leinwand dieser Groesse.
    public var leereLeinwand: Leinwand { Leinwand(breite: breite, hoehe: hoehe) }

    /// Welche Groesse eine Leinwand hat — `nil`, wenn es keine der drei ist.
    public static func fuer(breite: Int, hoehe: Int) -> Leinwandgroesse? {
        allCases.first { $0.breite == breite && $0.hoehe == hoehe }
    }

    public static func fuer(_ leinwand: Leinwand) -> Leinwandgroesse? {
        fuer(breite: leinwand.breite, hoehe: leinwand.hoehe)
    }
}
