import Foundation

/// Wie gross ein Kaestchen der Malflaeche wird.
///
/// **Deutlich groesser als bis zum 13.09.2026.** Damals waren es im
/// Icon-Editor feste 28 Punkte und in der Malflaeche hoechstens 14 — am iPad
/// gemeldet: zu klein, um mit dem Finger ein bestimmtes Pixel zu treffen.
/// Jetzt fuellt die Flaeche die Spalte, die sie hat, und wird je Kaestchen bis
/// zu `kanteMax` gross.
///
/// Eine eigene Rechnung und keine Zeile in der Ansicht, weil sie drei Grenzen
/// gegeneinander abwaegt und sich das pruefen laesst.
enum Malraster {
    /// Kleiner wird ein Kaestchen nie — darunter ist die Flaeche unbedienbar,
    /// dann soll lieber das Fenster zu schmal sein.
    static let kanteMin: Double = 6

    /// Und groesser auch nicht. 44 Punkte sind das Mass, das Apple fuer eine
    /// Trefferflaeche nennt; darueber gewinnt niemand etwas, und ein 8×8
    /// wuerde albern gross.
    static let kanteMax: Double = 44

    /// Wie hoch die Flaeche hoechstens wird. Ohne diese Grenze haette ein
    /// 16×16 bei Kante 44 ganze 704 Punkte Hoehe und schoebe Bildleiste,
    /// Namensfeld und Sendezeile aus dem Fenster — der Editor waere groesser
    /// und zugleich unbrauchbar.
    static let hoeheMax: Double = 420

    /// `verfuegbareBreite` ist gemessen; 0 heisst „noch nicht gemessen" und
    /// laesst die Breite ausser Betracht, damit der erste Aufbau nicht mit
    /// einem Kaestchen von sechs Punkten beginnt.
    static func kante(breite: Int, hoehe: Int, verfuegbareBreite: Double) -> Double {
        guard breite > 0, hoehe > 0 else { return kanteMin }
        let nachBreite = verfuegbareBreite > 0 ? verfuegbareBreite / Double(breite) : kanteMax
        let nachHoehe = hoeheMax / Double(hoehe)
        return max(kanteMin, min(kanteMax, nachBreite, nachHoehe).rounded(.down))
    }
}
