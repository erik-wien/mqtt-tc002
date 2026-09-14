import Foundation

/// **Was von einem Icon-Bestand zu sehen ist.** Suche, Größe, Bewegung — drei
/// Fragen an dieselbe Liste, an einer Stelle beantwortet statt in jeder
/// Oberfläche neu.
///
/// Die Bewegung steht **nicht** im `Icon`: Ob eine Datei mehr als ein
/// Einzelbild hat, steht in der Datei, nicht in der Einrichtung, und ein
/// Bestand von sechzig Icons bei jedem Tastendruck neu zu befragen wäre
/// Verschwendung. Der Filter bekommt sie deshalb als Funktion gereicht; die
/// Oberfläche liest sie einmal beim Laden und merkt sie sich
/// (`Bildraster.bewegt` liest nur den Kopf, aber eben doch die Datei).
public struct Iconfilter: Equatable, Sendable {
    /// Name oder Nummer, Groß- und Kleinschreibung egal. Leer heißt: alles.
    public var suche: String
    /// Kantenlänge in Pixeln — 8 oder 16. `nil` heißt: beide.
    public var kante: Int?
    /// Nur Icons mit mehr als einem Einzelbild.
    public var nurBewegte: Bool

    public init(suche: String = "", kante: Int? = nil, nurBewegte: Bool = false) {
        self.suche = suche
        self.kante = kante
        self.nurBewegte = nurBewegte
    }

    /// Ob überhaupt etwas eingeschränkt ist — für eine Oberfläche, die sagen
    /// will, warum die Liste leer ist.
    public var schraenktEin: Bool {
        !suche.trimmingCharacters(in: .whitespaces).isEmpty || kante != nil || nurBewegte
    }
}

public extension Array where Element == Icon {
    /// Der Bestand, wie der Filter ihn übrig lässt. Die Reihenfolge bleibt.
    func gefiltert(_ filter: Iconfilter, bewegt: (Icon) -> Bool) -> [Icon] {
        var ergebnis = gefiltert(nach: filter.suche)
        if let kante = filter.kante { ergebnis = ergebnis.filter { $0.kante == kante } }
        if filter.nurBewegte { ergebnis = ergebnis.filter(bewegt) }
        return ergebnis
    }
}

public extension Array where Element == Icon {
    /// Die Kennungen der **bewegten** Icons, einmal gelesen.
    ///
    /// Dafür wird jede Datei angefasst — `Bildraster.bewegt` liest zwar nur
    /// den Kopf und keine Pixel, aber eben doch die Datei. Einmal beim Laden
    /// des Bestands, nicht bei jedem Neuzeichnen und erst recht nicht bei
    /// jedem Tastendruck in der Suche: Ein Raster aus sechzig Icons fragt
    /// sonst hundertzwanzigmal je Bild nach.
    func bewegteKennungen() -> Set<String> {
        Set(filter { Bildraster.bewegt($0.datei) }.map(\.kennung))
    }
}
