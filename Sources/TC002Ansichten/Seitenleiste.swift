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
    /// Systemschrift gemessen: **81,0 Punkte bei 13 pt (Mac), 101,6 bei 17 pt
    /// (iPad).**
    static let laengsterEintragMac: Double = 81
    static let laengsterEintragTouch: Double = 102

    /// **Was die Zeile selbst verbraucht, links und rechts zusammen.**
    ///
    /// Hier stand bis zum 14.09.2026 eine Summe aus Einzelposten —
    /// Symbolspalte 28, Abstand 6, Innenrand zweimal 20, macht 74 — und **eine**
    /// Breite fuer beide Plattformen. Beides war falsch.
    ///
    /// Am iPad begann der Text auf dem Bildschirmfoto erst bei rund 65 Punkten
    /// und endete bei 152: 87 Punkte Textfeld statt der veranschlagten 116, und
    /// „Einstellungen" brach als „Einstellun-gen" um. 190 minus 87 macht rund
    /// **103** Punkte Verbrauch, nicht 74. Die Posten einzeln nachzubessern
    /// hiesse weiterraten; iPadOS legt um eine Seitenleistenzeile mehr herum,
    /// als man aus den sichtbaren Teilen zusammenzaehlen kann — Auswahlkapsel,
    /// Listeneinzug, Abschnittsrand.
    static let zeilenverbrauchMac: Double = 74
    static let zeilenverbrauchTouch: Double = 105

    /// Eine Stufe groessere Systemschrift macht den laengsten Eintrag um rund
    /// ein Achtel breiter. Wer noch groesser stellt, bekommt weiterhin einen
    /// Umbruch — das ist dann keine feste Breite mehr wert.
    static let schriftstufeMac: Double = laengsterEintragMac / 8
    static let schriftstufeTouch: Double = laengsterEintragTouch / 8

    /// 74 + 81 + 10 = 165, aufgerundet auf 190 — dort war seit je Luft, und
    /// mehr kostete unnoetig Fensterbreite (siehe `SchreibtischView`, wo die
    /// Mindestbreite des Fensters daran haengt).
    static let breiteMac: Double = 190

    /// 105 + 102 + 12,75 = 219,75, aufgerundet. Deutlich mehr als die 190 von
    /// vorher, und trotzdem weit unter der iPad-Vorgabe von rund 320: Fuer
    /// Mitte und Inspektor bleibt quer reichlich.
    static let breiteTouch: Double = 220

    /// **Zwei Zahlen, nicht eine** — die Schrift ist am Mac 13 Punkte gross und
    /// am iPad 17. Eine gemeinsame Breite hiesse, dem Mac die iPad-Zahl
    /// aufzuzwingen, und die traegt sein Mindestfenster nicht mehr.
    static var breite: Double {
        #if os(macOS)
        breiteMac
        #else
        breiteTouch
        #endif
    }
}
