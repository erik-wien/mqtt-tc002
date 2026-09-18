import Foundation

/// Es gibt zwei Icon-Bestände, und wer nur einen durchsucht, findet die
/// Hälfte nicht.
///
/// Die kanonischen 8×8 liegen in `Iconordner.eigene`, die eigenen 16×16 in
/// `Iconordner.eigene16` — je Größe ein eigener Ordner, aus den Gründen, die
/// bei `Iconsammlung` stehen. Die App durchsucht beide; ein Aufrufer, der nur
/// einen absucht, meldet „Kein Icon", obwohl es das Icon gibt — ein Fehler,
/// den nichts anzeigt, weil die Meldung stimmig klingt.
///
/// Deshalb steht die Entscheidung hier, an einer Stelle, statt an dreien.
public enum Iconbestaende {
    /// Beide Bestände, 8×8 zuerst.
    ///
    /// Die Reihenfolge ist die Entscheidung bei einem Zusammenstoß: Trägt ein
    /// 16×16 zufällig den Dateinamen einer LaMetric-Nummer, gewinnt das
    /// LaMetric-Icon. Es ist der ältere Bestand und der, auf den sich eine
    /// Nummer in einem Kurzbefehl bezieht.
    public static func alle() -> [Iconsammlung] {
        [Iconsammlung(schreibordner: Iconordner.eigene),
         Iconsammlung(schreibordner: Iconordner.eigene16, kante: 16)]
    }

    /// Das Icon zu einem Schlüssel, über alle Bestände.
    ///
    /// Der Schlüssel ist bei 8×8 die LaMetric-Nummer, bei 16×16 der Dateiname
    /// — beide stehen in `Icon.nummer`, weshalb hier nur ein Feld verglichen
    /// wird und die Meldungen von „Nummer oder Name" sprechen.
    ///
    /// Für `Meldungsbau.rahmen` bleibt die 8er-Sammlung die richtige, auch
    /// wenn ein 16×16 gefunden wurde: Der liest daraus allein die Daten-URI
    /// der Datei, und die hängt am Icon (`Icon.datei`, `Icon.kante`), nicht am
    /// Ordner.
    public static func suchen(_ schluessel: String, in bestaende: [Iconsammlung]) -> Icon? {
        for sammlung in bestaende {
            if let icon = sammlung.alle().first(where: { $0.nummer == schluessel }) { return icon }
        }
        return nil
    }
}
