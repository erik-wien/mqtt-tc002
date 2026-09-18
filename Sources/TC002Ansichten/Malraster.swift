import Foundation

/// Wie gross ein Kaestchen der Malflaeche wird.
///
/// Die Leinwand nimmt, was da ist — sie fordert nichts. Eine Rechnung allein
/// mit der Breite, die der Ansicht eine feste Kantenlaenge in ein starres
/// `.frame(width:)` schreibt, laesst sich nicht zusammendruecken: Wo die
/// Spalte schmaler war als 52 Kaestchen, zeichnete die Flaeche einfach ueber
/// ihre Grenzen hinaus — am iPad lief die Bedienzeile links unter die
/// Seitenleiste, die Slot-Zeile begann sichtbar bei Block 3, und die rechte
/// Spalte blieb ein Streifen.
///
/// Deshalb gehen beide Maße ein. Wer sie ruft, hat sie von einem
/// `GeometryReader` ueber der Flaeche — nicht von einem Hintergrund innerhalb
/// dessen, was er gerade bemisst.
///
/// Eine eigene Rechnung und keine Zeile in der Ansicht, weil sie drei Grenzen
/// gegeneinander abwaegt und sich das pruefen laesst.
enum Malraster {
    /// Kleiner wird ein Kaestchen nie — darunter ist die Flaeche unbedienbar.
    /// Passt sie dann nicht mehr in die Spalte, rollt die Leinwand waagrecht;
    /// der Bereich um sie herum bleibt heil.
    static let kanteMin: Double = 6

    /// Und groesser auch nicht. 44 Punkte sind das Mass, das Apple fuer eine
    /// Trefferflaeche nennt; darueber gewinnt niemand etwas, und ein 8×8
    /// wuerde albern gross.
    static let kanteMax: Double = 44

    /// `verfuegbareBreite`/`verfuegbareHoehe` sind gemessen; 0 heisst „noch
    /// nicht gemessen" und laesst das jeweilige Mass ausser Betracht, damit der
    /// erste Aufbau nicht mit einem Kaestchen von sechs Punkten beginnt.
    ///
    /// Bei 8×8 und 16×16 ist die Hoehe der Engpass — dort gewinnt die Flaeche
    /// den Platz, den sie frueher an eine feste Obergrenze verlor. Bei 52
    /// Spalten ist es die Breite, und dort bleiben die Kaestchen zwangslaeufig
    /// kleiner: lieber klein als hinausgelaufen.
    static func kante(breite: Int, hoehe: Int,
                      verfuegbareBreite: Double, verfuegbareHoehe: Double) -> Double {
        guard breite > 0, hoehe > 0 else { return kanteMin }
        let nachBreite = verfuegbareBreite > 0 ? verfuegbareBreite / Double(breite) : kanteMax
        let nachHoehe = verfuegbareHoehe > 0 ? verfuegbareHoehe / Double(hoehe) : kanteMax
        return max(kanteMin, min(kanteMax, nachBreite, nachHoehe).rounded(.down))
    }
}
