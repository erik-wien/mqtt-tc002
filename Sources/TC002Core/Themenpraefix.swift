import Foundation

/// **Ein Leerzeichen am Rand eines Präfixes ist unsichtbar und entscheidend.**
///
/// Am 14.09.2026 stand im `mqttPrefix` einer AWTRIX NG ein abschließendes
/// Leerzeichen — `"awtrix "`. Das Gerät hörte damit auf
/// `awtrix /cmd/apps/pushed/#`, die App schrieb auf `awtrix/cmd/…`, und weil
/// MQTT 3.1.1 keinen Rückkanal für eine verpuffte Veröffentlichung hat und NG
/// auf ein Thema ohne Route gar nicht antwortet, blieb die Uhr dunkel, ohne
/// dass irgendwo etwas stand. Gesucht wurde eine Stunde lang an der falschen
/// Stelle, denn in der Uhrenzeile stand — richtig und nutzlos — `awtrix`.
///
/// NG nimmt das Präfix wörtlich, ein Leerzeichen darin ist also erlaubt. Was
/// fehlte, war nicht eine Regel, sondern die Sichtbarkeit.
public enum Themenpraefix {
    /// Das Präfix so, dass man ein Leerzeichen am Rand **sieht**: Jedes
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
}
