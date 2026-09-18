import Foundation

/// Was die eingebaute Schrift der Uhr kennt — und was sie stillschweigend
/// weglaesst.
///
/// Belegt sind Buchstaben und Ziffern, von den Satzzeichen nur `%`, `.`, `-`
/// und `:` (Geraetereferenz, §1). Alles andere zeigt die Uhr nicht an: kein
/// Ersatzzeichen, keine Meldung — an der Stelle steht einfach nichts.
///
/// Gilt nur fuer den Weg „als Text", auf dem die Uhr selbst setzt. Beim Weg
/// „als Pixel" rastert diese App, und dort gehen Umlaute und alles Uebrige.
///
/// Im Kern und nicht in der Sendeansicht, damit Mac- und
/// iPhone-Fassung dieselbe Tabelle pruefen, statt zwei Abschriften zu
/// fuehren, die auseinanderlaufen koennen.
public enum Geraeteschrift {
    /// Die Satzzeichen, die die Geraetschrift kennt.
    public static let erlaubteSatzzeichen = Set("%.-:")

    /// Die Zeichen dieses Textes, die auf der Uhr nicht ankaemen — in der
    /// Reihenfolge ihres Auftretens, jedes nur einmal.
    public static func unbekannteZeichen(in text: String) -> [Character] {
        var gefunden: [Character] = []
        for zeichen in text where !gefunden.contains(zeichen) {
            if zeichen.isASCII && (zeichen.isLetter || zeichen.isNumber) { continue }
            if zeichen == " " { continue }
            if erlaubteSatzzeichen.contains(zeichen) { continue }
            gefunden.append(zeichen)
        }
        return gefunden
    }

    /// Dieselben Zeichen als Aufzaehlung fuer eine Meldung: „a", „b", „c".
    public static func unbekannteZeichenText(in text: String) -> String {
        unbekannteZeichen(in: text).map { "„\($0)“" }.joined(separator: ", ")
    }
}
