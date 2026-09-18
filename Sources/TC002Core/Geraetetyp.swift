import Foundation

// `Geraetetyp` selbst steht in `Einstellungen.swift`, weil es dort als Feld von
// `Uhr` gebraucht wird und `Uhr` ein Dateiformat ist. Was die Gattung
// bedeutet, steht hier: der Name in der Oberflaeche, und welche Regler der
// Sendeansicht auf ihr ueberhaupt etwas bewirken.

extension Geraetetyp {
    /// Wie die Gattung in der Oberflaeche heisst. Zwei Eigennamen, keine
    /// uebersetzbaren Saetze — deshalb ohne `lok`.
    public var beschriftung: String {
        switch self {
        case .tc002: return "Ulanzi TC002"
        case .awtrixNG: return "AWTRIX NG"
        }
    }

    /// Die Hoehe einer AWTRIX-NG-Anzeige: fest 8 Pixel, nicht einstellbar
    /// (`docs/awtrix-ng-protokoll.md` §1).
    public static let ngHoehe = 8

    /// Die dokumentierte Vorgabe der Breite (`panelWidth × panels`, ab Werk
    /// `32 × 1`). Ausdruecklich eine Vorgabe und keine Tatsache ueber ein
    /// bestimmtes Geraet: Die wirkliche Breite steht in `/api/v1/system` und
    /// wird beim Abfragen geholt (`Uhr.panelbreite`). Zulaessig ist alles
    /// zwischen 32 und 128; alles andere weist NG mit `422` ab.
    public static let ngVorgabebreite = 32

    /// Wie schnell NG bei `scroll.speed: 100` laeuft: rund 21 Pixel je
    /// Sekunde (bei 40 Bildern je Sekunde, Herstellerdokumentation, siehe
    /// `docs/awtrix-ng-protokoll.md` §5.2).
    ///
    /// Gebraucht wird die Zahl, um unsere drei Stufen in Prozente
    /// umzurechnen: `scroll.speed` ist ein Prozentsatz hiervon, und ohne
    /// diese Zahl waere jeder Prozentsatz geraten.
    public static let ngGrundgeschwindigkeit = 21.0
    public static let ngBreitenbereich = 32...128

    /// Wieviele Zeilen die Anzeige dieser Gattung hat — die eine Tatsache,
    /// aus der `iconKanten` und `grafikSperre` beide folgen.
    ///
    /// Die Werksfirmware hat sechzehn Zeilen, NG hat acht (§1). Die Breite
    /// steht ausdruecklich nicht hier: Sie ist bei NG einstellbar und deshalb
    /// eine Frage an die einzelne Uhr (`Uhr.anzeigemass`, `Anzeigemass`). Die
    /// Hoehe ist eine Eigenschaft der Gattung.
    public var grafikhoehe: Int {
        switch self {
        case .tc002: return Pixelfeld.hoeheStandard
        case .awtrixNG: return Self.ngHoehe
        }
    }

    /// Warum eine Grafik dieser Hoehe hier nicht geht — `nil`, wenn sie geht.
    ///
    /// Ein 16×16-Icon ist auf NG nicht bloss gross, es geht gar nicht: Die
    /// Leinwand fuer Icons ist 32×8, und ein GIF, dessen erstes Bild hoeher
    /// ist, spielt ueberhaupt nicht (§8) — ohne jede Meldung. Dasselbe gilt
    /// fuer eine ganze 16×52-Anzeige. Das ist eine Eigenschaft des Geraets und
    /// kein Fehler, der sich glattbuegeln liesse; gesagt gehoert er trotzdem,
    /// und zwar bevor jemand waehlt, was nicht ankommen kann.
    ///
    /// Der Satz geht als gewoehnliches `String` an `.help(_:)` und an das
    /// Hilfezeichen weiter — beide schlagen in dieser Ueberladung nichts nach,
    /// deshalb `lok`.
    public func grafikSperre(hoehe: Int) -> String? {
        guard hoehe > grafikhoehe else { return nil }
        return lokf("Die TC001 unter AWTRIX NG hat acht Zeilen. Ein %d Pixel hohes Bild spielt dort überhaupt nicht ab — ohne Meldung, und verkleinert wird auch nichts.",
                    hoehe)
    }

    /// Welche Icon-Kantenlaengen auf dieser Gattung ueberhaupt Platz haben.
    ///
    /// Abgeleitet und nicht abgeschrieben: Eine zweite Liste neben
    /// `grafikhoehe` liefe frueher oder spaeter auseinander, und die
    /// abweichende waere die falsche (siehe `Regler` unten). Die bekannten
    /// Werte — [8, 16] und [8] — stehen unveraendert in `MeldungsherkunftTests`
    /// und in `GrafiksperreTests`.
    public var iconKanten: [Int] {
        [8, 16].filter { grafikSperre(hoehe: $0) == nil }
    }

    /// Ob diese Gattung ihren Text selbst setzt.
    ///
    /// Der ganze Unterschied in einem Satz: Die Werksfirmware bekommt von
    /// dieser App fertige Pixel, AWTRIX NG bekommt den Text und setzt ihn mit
    /// ihrer eigenen Schrift. Daran haengt alles Weitere — die Regler unten,
    /// die Nutzlast (`NGNutzlast`) und die Themen (`NGThema`).
    public var setztSelbst: Bool { self == .awtrixNG }
}

/// Die Regler der Sendeansicht, soweit die Geraeteart ueber sie entscheidet.
///
/// Eine Aussage ueber das Geraet, keine ueber die Oberflaeche. Ob ein
/// Regler zusaetzlich am gewaehlten Weg (`SendeWeg`) haengt, steht weiter in
/// der Ansicht; hier steht nur, was die Gattung hergibt. Zwei Achsen, zwei
/// Stellen — die Ansicht sperrt, sobald eine davon nein sagt.
///
/// Liegt im Kern und wird dort geprueft, damit Mac- und iPhone-Fassung
/// dieselbe Antwort bekommen. Zwei Abschriften derselben Tabelle liefen
/// frueher oder spaeter auseinander, und die abweichende waere die falsche.
public enum Regler: String, CaseIterable, Sendable {
    case schriftart, groesse, fett, grossbuchstaben, waagrecht, senkrecht
    case rand, abstand, tempo, farbe, dauer, iconLaeuftMit
}

extension Geraetetyp {
    /// Ob dieser Regler auf dieser Gattung ueberhaupt etwas bewirkt.
    ///
    /// Auf der TC002 bewirken alle etwas — die App rastert dort selbst, jeder
    /// Regler formt das Bild. Auf AWTRIX NG rastert das Geraet, und damit
    /// fallen genau die Regler weg, die unsere Rasterung steuern.
    public func wirkt(_ regler: Regler) -> Bool {
        switch self {
        case .tc002: return true
        case .awtrixNG:
            switch regler {
            case .schriftart, .groesse, .fett, .senkrecht, .rand, .abstand: return false
            case .grossbuchstaben, .waagrecht, .tempo, .farbe, .dauer, .iconLaeuftMit: return true
            }
        }
    }

    /// Warum nicht — ein Satz fuer den `.help`-Text des gesperrten Reglers.
    /// `nil`, wo der Regler wirkt: Dort gilt der gewohnte Hilfetext der
    /// Ansicht, und ein zweiter daneben waere eine Erklaerung fuer etwas, das
    /// gar nicht gesperrt ist.
    ///
    /// Die Saetze gehen als gewoehnliches `String` an `.help(_:)` weiter, das
    /// in dieser Ueberladung nichts nachschlaegt — deshalb `lok`.
    public func begruendung(_ regler: Regler) -> String? {
        guard !wirkt(regler) else { return nil }
        switch regler {
        case .schriftart:
            return lok("Die AWTRIX setzt den Text mit ihrer eigenen Schrift. Eine Schriftwahl gibt es dort nicht.")
        case .groesse:
            return lok("Die AWTRIX hat acht Zeilen und setzt den Text mit ihrer eigenen Schrift. Eine Größenwahl gibt es dort nicht — die durchgesehenen Größen dieser App gelten für sechzehn Zeilen.")
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

    /// Welche waagrechten Ausrichtungen diese Gattung kennt.
    ///
    /// Der einzige halbe Fall. NG kennt `textCenter` als bool: mittig oder
    /// linksbuendig. Rechtsbuendig ginge nur ueber eine Verschiebung in Pixeln
    /// — und dafuer muesste diese App die Breite des Textes in einer Schrift
    /// kennen, die sie nicht hat. Ein Eintrag, der nichts taete, waere
    /// schlimmer als keiner.
    public var waagrechteAusrichtungen: [SendenHAusrichtung] {
        switch self {
        case .tc002: return SendenHAusrichtung.allCases
        case .awtrixNG: return [.links, .mittig]
        }
    }

    /// Ob diese Gattung ueberhaupt ein gemaltes Bild annimmt.
    ///
    /// Die Werksfirmware ja — ein Pixelfeld wird zu `draw`-Rechtecken. NG
    /// nein: Die App malt auf 52×16, NG ist 32×8, und ein auf acht Zeilen
    /// gestauchtes Bild waere nicht dasselbe Bild. Wer es trotzdem schickte,
    /// bekaeme von NG nichts als Stille (siehe `NGFehler.keinPixelweg`).
    public var nimmtGemaltes: Bool { self == .tc002 }
}
