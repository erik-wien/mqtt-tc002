import Foundation

/// Welche Schriftgroessen die Sendeansicht anbietet.
///
/// **Eine Entscheidung, keine Messung.** Die Listen unten stammen aus der
/// durchgesehenen Schriftprobe vom 13.09.2026: Ein Augenpaar hat jede Groesse
/// jeder mitgelieferten Schrift angesehen und diese hier abgesegnet.
/// `Schriftprobe` rechnet daran nicht mit — sie kann eine Groesse
/// ausschliessen, nie eine empfehlen. Was angeboten wird, steht deshalb hier
/// und nicht dort; die Schriftprobe zeigt beides nebeneinander, damit man den
/// Unterschied sieht.
public enum Pixelgroessen {
    /// Der volle Bereich: ganze Pixel von 6 bis 16. Ihn bekommt jede Schrift,
    /// zu der es keine durchgesehene Liste gibt.
    public static let freierBereich: [Double] = Array(stride(from: 6.0, through: 16.0, by: 1.0))

    /// Die abgesegneten Groessen der drei mitgelieferten Pixelschriften —
    /// durchgesehene Schriftprobe, 13.09.2026.
    ///
    /// Alle drei haben Luecken. Eine arithmetische Folge ist das nicht, ein
    /// Schieber mit Schrittweite kann sie also nicht ausdruecken; das
    /// Bedienelement ist deshalb eine Liste.
    public static let abgesegnet: [String: [Double]] = [
        "Micro 5": [10, 14, 16],
        "Silkscreen": [7, 8, 9, 10, 12, 14, 16],
        "Tiny5": [7, 8, 9, 10, 12, 14, 16],
    ]

    /// Was das Bedienelement anbietet.
    ///
    /// Eine Schrift ohne eigene Liste bekommt den vollen Bereich — das sind
    /// alle Systemschriften der Auswahl (Geneva, Monaco, Andale Mono, Menlo,
    /// PT Mono) und jede frueher gewaehlte, seither aus der Auswahl gefallene
    /// Schrift. Fuer sie hat niemand eine Schriftprobe durchgesehen, und eine
    /// erfundene Einschraenkung waere schlimmer als keine.
    public static func angeboten(fuer schrift: String) -> [Double] {
        abgesegnet[schrift] ?? freierBereich
    }

    /// Dasselbe, aber mit der eingestellten Groesse darin — auch wenn sie nicht
    /// auf der Liste steht.
    ///
    /// Das kommt vor: Eine aeltere Fassung hat sie gespeichert, oder sie stammt
    /// von einem Meldungsplatz. Ein Aufklappmenue ohne Eintrag fuer den eigenen
    /// Wert zeigte gar nichts an — dieselbe Regel wie bei der Schriftart, wo
    /// eine aus der Auswahl gefallene Schrift gesetzt bleibt, statt
    /// kommentarlos verworfen zu werden.
    public static func auswahl(fuer schrift: String, mit groesse: Double) -> [Double] {
        let liste = angeboten(fuer: schrift)
        guard !liste.contains(groesse) else { return liste }
        return (liste + [groesse]).sorted()
    }

    /// Die naechstgelegene angebotene Groesse — fuer den Schriftwechsel.
    ///
    /// Nicht die kleinste: Der Sprung von 15 auf 7 waere eine Ueberraschung,
    /// wo 16 danebenliegt. Bei gleichem Abstand gewinnt die kleinere — sie
    /// passt in jedem Fall noch in die sechzehn Zeilen, die groessere nicht
    /// unbedingt.
    public static func naechstgelegene(zu groesse: Double, fuer schrift: String) -> Double {
        let liste = angeboten(fuer: schrift).sorted()
        return liste.min(by: { abs($0 - groesse) < abs($1 - groesse) }) ?? groesse
    }
}
