import Foundation

/// Die drei Groessen, in denen gemalt wird — und alles, was daraus folgt.
///
/// **Es ist eine Taetigkeit: Pixel malen.** Was dabei herauskommt, entscheidet
/// allein die Leinwandgroesse. Bis zum 13.09.2026 waren daraus zwei Bereiche
/// geworden („Icons" und „Bilder"), und der Auftraggeber hat beim Testen
/// gesagt, er verstehe den Unterschied nicht — zu Recht, denn es gab keinen.
///
/// Damit die Unterschiede, die es wirklich gibt, nicht als Sonderfaelle durch
/// die Oberflaeche wandern, stehen sie hier **abgeleitet** und an einer Stelle:
///
/// | Groesse | Was es ist              | Nummer | Senden |
/// |---------|-------------------------|--------|--------|
/// | 8×8     | kanonisches LaMetric-Icon | ja   | nein   |
/// | 16×16   | Icon ohne Nummer        | nein   | nein   |
/// | 16×52   | die ganze Anzeige       | nein   | ja     |
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
    public var beschriftung: String {
        switch self {
        case .icon8: return "8 × 8"
        case .icon16: return "16 × 16"
        case .anzeige: return "16 × 52"
        }
    }

    /// Nur die ganze Anzeige laesst sich an die Uhr schicken. Ein Icon ist fuer
    /// sich keine Anzeige — es steht unter „Senden" neben einem Text.
    public var sendbar: Bool {
        breite == Pixelfeld.breiteStandard && hoehe == Pixelfeld.hoeheStandard
    }

    /// Nur das kanonische 8×8 hat eine LaMetric-Nummer. Bei den anderen beiden
    /// ist der Name der Dateiname.
    public var mitNummer: Bool { breite == 8 && hoehe == 8 }

    /// Ein fertiges 8×8 laesst sich dort als Ausgangspunkt einsetzen, wo eine
    /// ganze Anzeige entsteht — nicht in ein Icon hinein.
    public var iconEinfuegbar: Bool { sendbar }

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
