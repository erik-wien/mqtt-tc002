import Foundation

/// Wie breit die Seitenleiste des Schreibtischs ist.
///
/// Gemessen, nicht geschaetzt: Der laengste Eintrag ist „Einstellungen", und
/// die Zeilenschrift ist am Mac 13 Punkte gross, am iPad 17 — eine einzige
/// Breite fuer beide Plattformen bricht auf einer von beiden um
/// („Einstel-lungen").
///
/// Die Summanden stehen einzeln da, damit die Zahl nachrechenbar ist und nicht
/// beim naechsten Eintrag wieder geraten wird.
enum Seitenleiste {
    /// Der laengste Eintrag ist „Einstellungen". Mit CoreText an der
    /// Systemschrift gemessen: 81,0 Punkte bei 13 pt (Mac), 101,6 bei 17 pt
    /// (iPad).
    static let laengsterEintragMac: Double = 81
    static let laengsterEintragTouch: Double = 102

    /// Was die Zeile selbst verbraucht, links und rechts zusammen. Am Mac aus
    /// Einzelposten gerechnet (Symbolspalte 28, Abstand 6, Innenrand zweimal
    /// 20 = 74); am iPad gemessen statt gerechnet, denn dieselbe Rechnung
    /// ergibt auch dort nur 74, waehrend das Bildschirmfoto ein Textfeld von
    /// 65 bis 152 zeigt — 87 Punkte statt der veranschlagten 116, „Einstellungen"
    /// bricht sonst als „Einstellun-gen" um. 190 minus 87 macht rund 103 Punkte
    /// Verbrauch. iPadOS legt also um eine Seitenleistenzeile mehr herum, als
    /// sich aus den sichtbaren Teilen (Auswahlkapsel, Listeneinzug,
    /// Abschnittsrand) zusammenzaehlen laesst.
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

    /// Zwei Zahlen, nicht eine — die Schrift ist am Mac 13 Punkte gross und
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
