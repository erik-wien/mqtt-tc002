import Foundation

/// Ein Leerzeichen am Rand eines Präfixes ist unsichtbar und entscheidend:
/// Steht im `mqttPrefix` einer AWTRIX NG ein abschließendes Leerzeichen
/// (`"awtrix "`), hört das Gerät auf `awtrix /cmd/apps/pushed/#`, während die
/// App auf `awtrix/cmd/…` schreibt. MQTT 3.1.1 hat keinen Rückkanal für eine
/// verpuffte Veröffentlichung, und NG antwortet auf ein Thema ohne Route gar
/// nicht — die Uhr bleibt dunkel, ohne dass irgendwo etwas darauf hinweist.
///
/// NG nimmt das Präfix wörtlich, ein Leerzeichen darin ist also erlaubt. Was
/// fehlt, ist nicht eine Regel, sondern die Sichtbarkeit.
public enum Themenpraefix {
    /// Das Präfix so, dass man ein Leerzeichen am Rand sieht: Jedes
    /// Leerraumzeichen vorn und hinten wird zu `␣` (U+2423, „open box“, das
    /// übliche Zeichen dafür). In der Mitte bleibt alles, wie es ist — dort
    /// ist eine Lücke in der dicktengleichen Schrift ohnehin zu sehen.
    public static func sichtbar(_ praefix: String) -> String {
        let zeichen = Array(praefix)
        var vorn = 0
        while vorn < zeichen.count, zeichen[vorn].isWhitespace { vorn += 1 }
        // Ein Praefix aus lauter Leerraum ist ganz Rand: Es einmal von vorn
        // und einmal von hinten zu ersetzen, ergaebe die doppelte Laenge.
        guard vorn < zeichen.count else { return String(repeating: "␣", count: zeichen.count) }
        var hinten = zeichen.count - 1
        while hinten > vorn, zeichen[hinten].isWhitespace { hinten -= 1 }
        return String(repeating: "␣", count: vorn)
            + String(zeichen[vorn...hinten])
            + String(repeating: "␣", count: zeichen.count - 1 - hinten)
    }

    /// Hoechstlaenge in Byte. Ein Praefix steht in jedem Thema; was weit ueber
    /// jede vernuenftige Einstellung hinausgeht, kommt nicht von einer Uhr.
    public static let maxLaenge = 128

    /// Ob ein von der Uhr gemeldetes Praefix als Themenanfang taugt: nicht
    /// laenger als `maxLaenge` Byte, keine Steuerzeichen, kein `#` und kein `+`.
    /// Die beiden Platzhalter machen aus Veroeffentlichungen Muster und legen den
    /// MQTT-Client der Uhr lahm (gemessen 09.10.2026). Leerzeichen am Rand und
    /// `/` bleiben erlaubt, NG nimmt das Praefix woertlich.
    public static func gueltig(_ praefix: String) -> Bool {
        guard !praefix.isEmpty, praefix.utf8.count <= maxLaenge else { return false }
        return !praefix.unicodeScalars.contains { $0.properties.generalCategory == .control || $0 == "#" || $0 == "+" }
    }
}
