import Foundation

/// Wie breit die Seitenleiste des Schreibtischs ist.
///
/// **Gemessen, nicht geschaetzt.** Bis zum 13.09.2026 standen dort feste 170
/// Punkte; auf jedem Bildschirmfoto vom iPad brach der letzte Eintrag um und
/// stand als „Einstel-lungen" da. Die 170 waren einmal richtig — sie stammen
/// aus der Zeit, als am Mac das Fenster zu schmal wurde —, aber sie sind am
/// Mac gemessen, wo die Zeilenschrift 13 Punkte hat. Auf dem iPad sind es 17.
///
/// Die Summanden stehen einzeln da, damit die Zahl nachrechenbar ist und nicht
/// beim naechsten Eintrag wieder geraten wird.
enum Seitenleiste {
    /// Der laengste Eintrag ist „Einstellungen". Mit CoreText an der
    /// Systemschrift gemessen: 81,0 Punkte bei 13 pt (Mac), 101,6 bei 17 pt
    /// (iPad). Massgeblich ist der groessere — eine Breite gilt fuer beide.
    static let laengsterEintrag: Double = 102

    /// Die Symbolspalte, an der `Label` in einer Seitenleiste alle Icons
    /// ausrichtet, samt ihrem Abstand zum Text.
    static let symbolspalte: Double = 28
    static let symbolAbstand: Double = 6

    /// Was die Zeile links und rechts an Innenpolsterung mitbringt.
    static let zeilenrand: Double = 20

    /// Eine Stufe groessere Systemschrift (19 statt 17 Punkt) macht den
    /// laengsten Eintrag um rund ein Achtel breiter. Wer noch groesser stellt,
    /// bekommt weiterhin einen Umbruch — das ist dann keine feste Breite mehr
    /// wert.
    static let eineSchriftstufe: Double = laengsterEintrag / 8

    /// 20 + 28 + 6 + 102 + 20 = 176 gemessen, plus 12,75 fuer eine Schriftstufe
    /// = 188,75 — aufgerundet auf einen glatten Wert.
    static let breite: Double = 190
}
