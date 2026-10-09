import Foundation

/// Was an der Firmware AWTRIX NG auf der Ulanzi TC002 feststeht und die
/// Oberflaeche wissen muss: Anzeigemass, Lauftempo und welche Regler der
/// Sendeansicht auf ihr ueberhaupt etwas bewirken.
public enum AwtrixNG {
    /// Das Raster der TC002: fest 52 × 16 (`docs/awtrix-ng-protokoll.md` §1).
    /// Eine Vorgabe fuer eine Uhr, die noch nicht gefragt wurde; die
    /// gemeldete Groesse steht in `Uhr.panelbreite`/`panelhoehe`.
    public static let vorgabebreite = 52
    public static let vorgabehoehe = 16

    /// Was die Herstellerangaben fuer alle NG-Geraete zulassen: TC001 32 × 8,
    /// DIY-Matrizen 32…128 × 8, TC002 52 × 16.
    public static let breitenbereich = 32...128
    public static let hoehenbereich = 8...16
    /// Obergrenze der Pixelzahl, wenn die Uhr keine `maxPixels` nennt (128 × 16).
    public static let hoechstePixelzahl = 2048

    /// Das Mass aus einer Geraeteantwort, wenn es plausibel ist. Die Zahlen
    /// bestimmen Pixelfelder und Schleifen; ein Geraet, das 2 000 000 000
    /// meldet, darf damit weder Speicher noch Rechenzeit verbrauchen. `nil`
    /// heisst: Es gilt weiter die Vorgabe. `maxPixels` der Uhr kann die Grenze
    /// nur senken, nie ueber `hoechstePixelzahl` heben.
    public static func plausiblesMass(breite: Int, hoehe: Int, maxPixel: Int? = nil) -> (breite: Int, hoehe: Int)? {
        guard breitenbereich.contains(breite), hoehenbereich.contains(hoehe) else { return nil }
        let grenze = min(maxPixel ?? hoechstePixelzahl, hoechstePixelzahl)
        guard breite * hoehe <= grenze else { return nil }
        return (breite, hoehe)
    }

    /// Wie schnell NG bei `scroll.speed: 100` laeuft: rund 21 Pixel je
    /// Sekunde (§5.2).
    ///
    /// Gebraucht wird die Zahl, um unsere drei Stufen in Prozente
    /// umzurechnen: `scroll.speed` ist ein Prozentsatz hiervon, und ohne
    /// diese Zahl waere jeder Prozentsatz geraten.
    public static let grundgeschwindigkeit = 21.0

    /// Was ueber die Vorschau von „als Text" zu sagen ist.
    ///
    /// AWTRIX NG setzt den Text dort mit ihrer eigenen Schrift; unsere Rasterung
    /// ist nur eine Naeherung. Auf dem Pixelweg zeigt die Vorschau dagegen
    /// genau das Feld, das hinausgeht.
    ///
    /// Im Kern und nicht in der Ansicht: Beide Oberflaechen sagen denselben
    /// Satz, und zwei Abschriften waeren zwei Uebersetzungsschluessel. Er geht
    /// als gewoehnliches `String` weiter (an `Hilfezeichen` und an
    /// `.help(_:)`), deshalb `lok`.
    public static var vorschauhinweis: String {
        lok("Nur eine Näherung — die Uhr setzt diesen Text selbst und zeigt ihn anders. Läuft er, weil er nicht passt, gilt das Lauftempo dieser Meldung.")
    }

    /// Ob dieser Regler etwas bewirkt. Auf dem Pixelweg rastert die App selbst,
    /// und jeder Regler wirkt. Bei „als Text" setzt AWTRIX NG den Text, und
    /// damit fallen genau die Regler weg, die unsere Rasterung steuern.
    public static func wirkt(_ regler: Regler, weg: SendeWeg) -> Bool {
        guard weg == .text else { return true }
        switch regler {
        case .schriftart, .groesse, .fett, .senkrecht, .rand, .abstand: return false
        case .grossbuchstaben, .waagrecht, .tempo, .farbe, .dauer, .iconLaeuftMit: return true
        }
    }

    /// Warum nicht — ein Satz fuer den `.help`-Text des gesperrten Reglers.
    /// `nil`, wo der Regler wirkt: Dort gilt der gewohnte Hilfetext der
    /// Ansicht, und ein zweiter daneben waere eine Erklaerung fuer etwas, das
    /// gar nicht gesperrt ist.
    ///
    /// Die Saetze gehen als gewoehnliches `String` an `.help(_:)` weiter, das
    /// in dieser Ueberladung nichts nachschlaegt — deshalb `lok`.
    public static func begruendung(_ regler: Regler, weg: SendeWeg) -> String? {
        guard !wirkt(regler, weg: weg) else { return nil }
        switch regler {
        case .schriftart:
            return lok("Die AWTRIX setzt den Text mit ihrer eigenen Schrift. Eine Schriftwahl gibt es dort nicht.")
        case .groesse:
            return lok("Die AWTRIX setzt den Text mit ihrer eigenen Schrift. Eine Größenwahl gibt es dort nicht.")
        case .fett:
            return lok("Die Schrift der AWTRIX hat keinen fetten Schnitt.")
        case .senkrecht:
            return lok("Die Grundlinie liegt auf der AWTRIX fest. Senkrecht ausrichten lässt sich dort nichts.")
        case .rand:
            return lok("Der Rand ist die senkrechte Achse, und die gibt es auf der AWTRIX nicht.")
        case .abstand:
            return lok("Den Abstand zwischen den Zeichen bestimmt auf der AWTRIX ihre eigene Schrift.")
        default:
            return nil
        }
    }

    /// Welche waagrechten Ausrichtungen der Weg kennt.
    ///
    /// Auf dem Pixelweg alle drei, die App rastert. Bei „als Text" der einzige
    /// halbe Fall. NG kennt `textCenter` als bool: mittig oder
    /// linksbuendig. Rechtsbuendig ginge nur ueber eine Verschiebung in Pixeln
    /// — und dafuer muesste diese App die Breite des Textes in einer Schrift
    /// kennen, die sie nicht hat. Ein Eintrag, der nichts taete, waere
    /// schlimmer als keiner.
    public static func waagrechteAusrichtungen(weg: SendeWeg) -> [SendenHAusrichtung] {
        weg == .pixel ? SendenHAusrichtung.allCases : [.links, .mittig]
    }
}

/// Die Regler der Sendeansicht, soweit die Firmware ueber sie entscheidet.
///
/// Eine Aussage ueber das Geraet, keine ueber die Oberflaeche. Ob ein
/// Regler zusaetzlich am gewaehlten Weg (`SendeWeg`) haengt, steht weiter in
/// der Ansicht.
///
/// Liegt im Kern und wird dort geprueft, damit Mac- und iPhone-Fassung
/// dieselbe Antwort bekommen. Zwei Abschriften derselben Tabelle liefen
/// frueher oder spaeter auseinander, und die abweichende waere die falsche.
public enum Regler: String, CaseIterable, Sendable {
    case schriftart, groesse, fett, grossbuchstaben, waagrecht, senkrecht
    case rand, abstand, tempo, farbe, dauer, iconLaeuftMit
}
