import Foundation

/// Die Formatangaben, die ein Kurzbefehl mitgeben kann — jede einzelne
/// wahlfrei.
///
/// Warum das im Kern steht und nicht bei den Kurzbefehlen. Was hier
/// geschieht, ist eine Rechnung ueber `Meldungsoptionen`: Vorgaben nehmen,
/// Angegebenes darueberlegen, die Groesse gegen die abgesegnete Liste halten.
/// Der Intent in `TC002iOS` liefert nur die Werte — er hat die Auswahllisten
/// (`AppEnum`), die eine Fehleingabe von vornherein ausschliessen. Und nur
/// hier laesst sich das mit `swift test` pruefen; das iOS-Ziel baut SwiftPM
/// nicht.
///
/// Was nicht angegeben ist, bleibt bei der Vorgabe des Aufrufers — beim
/// Intent also bei dem, was zuletzt unter „Senden" eingestellt war
/// (`Meldungsoptionen.ausAblage`). Eine hier erfundene Vorgabe gaebe es nicht:
/// Dieselbe Meldung saehe aus einem Kurzbefehl anders aus als aus der App.
public struct Formatangaben {
    public var weg: SendeWeg?
    public var schrift: String?
    public var groesse: Double?
    public var fett: Bool?
    public var grossbuchstaben: Bool?
    public var farbe: String?
    public var waagrecht: SendenHAusrichtung?
    public var senkrecht: SendenVAusrichtung?
    public var rand: Int?
    public var abstand: Int?
    public var tempo: Lauftempo?
    public var iconLaeuftMit: Bool?

    public init(weg: SendeWeg? = nil,
                schrift: String? = nil,
                groesse: Double? = nil,
                fett: Bool? = nil,
                grossbuchstaben: Bool? = nil,
                farbe: String? = nil,
                waagrecht: SendenHAusrichtung? = nil,
                senkrecht: SendenVAusrichtung? = nil,
                rand: Int? = nil,
                abstand: Int? = nil,
                tempo: Lauftempo? = nil,
                iconLaeuftMit: Bool? = nil) {
        self.weg = weg
        self.schrift = schrift
        self.groesse = groesse
        self.fett = fett
        self.grossbuchstaben = grossbuchstaben
        self.farbe = farbe
        self.waagrecht = waagrecht
        self.senkrecht = senkrecht
        self.rand = rand
        self.abstand = abstand
        self.tempo = tempo
        self.iconLaeuftMit = iconLaeuftMit
    }

    /// Was Rand und Abstand haben duerfen — dieselben Grenzen wie die Stepper
    /// der Sendeansicht. Ein Wert daneben kann nur aus einer Variablen
    /// stammen; er wird geklemmt, nicht abgewiesen: Genau das tut ein Stepper
    /// auch, und die beiden Zahlen sind eine Bequemlichkeit, keine
    /// durchgesehene Entscheidung.
    public static let randbereich = 0...3

    public enum Fehler: Error, LocalizedError, Equatable {
        /// Die verlangte Groesse steht nicht auf der abgesegneten Liste der
        /// (dann geltenden) Schrift.
        case groesseNichtAngeboten(groesse: Double, schrift: String, angeboten: [Double])

        public var errorDescription: String? {
            switch self {
            case let .groesseNichtAngeboten(groesse, schrift, angeboten):
                return lokf("„%@“ wird in %d Pixeln nicht angeboten. Möglich sind: %@.",
                            schrift, Int(groesse),
                            angeboten.map { String(Int($0)) }.joined(separator: ", "))
            }
        }
    }

    /// Legt die Angaben ueber die Vorgaben.
    ///
    /// Die Groesse zuletzt, und das ist keine Formsache: Welche Groessen
    /// angeboten werden, haengt an der Schrift (`Pixelgroessen`). Geprueft
    /// wird deshalb gegen die Schrift, die nachher gilt — wer „Micro 5"
    /// und acht Pixel zusammen angibt, bekommt den Fehler, obwohl acht bei der
    /// vorher eingestellten Schrift zu haben waere.
    ///
    /// Zwei Faelle, und beide bilden ab, was die Sendeansicht tut:
    ///
    /// - Groesse ausdruecklich angegeben — sie muss auf der Liste stehen,
    ///   sonst ein Fehler. Das Groessenmenue der Ansicht bietet nichts
    ///   anderes an; stillschweigend etwas anderes zu senden, als im
    ///   Kurzbefehl steht, waere schlimmer als die Absage.
    /// - Nur die Schrift gewechselt — die geerbte Groesse faellt auf die
    ///   naechstgelegene der neuen Liste, genau wie `.onChange(of: schrift)`
    ///   in `SendenView` und `SendeniOS`. Hier hat niemand eine Groesse
    ///   verlangt, es gibt also auch nichts abzuweisen.
    public func angewendet(auf vorgabe: Meldungsoptionen) throws -> Meldungsoptionen {
        var o = vorgabe
        if let weg { o.weg = weg }
        if let fett { o.fett = fett }
        if let grossbuchstaben { o.grossbuchstaben = grossbuchstaben }
        if let farbe { o.farbe = farbe }
        if let waagrecht { o.waagrecht = waagrecht }
        if let senkrecht { o.senkrecht = senkrecht }
        if let tempo { o.tempo = tempo }
        if let iconLaeuftMit { o.iconLaeuftMit = iconLaeuftMit }
        if let rand { o.rand = Self.geklemmt(rand) }
        if let abstand { o.abstand = Self.geklemmt(abstand) }
        if let schrift { o.schrift = schrift }

        let angeboten = Pixelgroessen.angeboten(fuer: o.schrift)
        if let groesse {
            guard angeboten.contains(groesse) else {
                throw Fehler.groesseNichtAngeboten(groesse: groesse, schrift: o.schrift,
                                                   angeboten: angeboten)
            }
            o.groesse = groesse
        } else if schrift != nil {
            o.groesse = Pixelgroessen.naechstgelegene(zu: o.groesse, fuer: o.schrift)
        }
        return o
    }

    private static func geklemmt(_ wert: Int) -> Int {
        min(max(wert, randbereich.lowerBound), randbereich.upperBound)
    }
}
