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

    /// Das Icon, das diese Anzeige bekommt: ist das gewaehlte hoeher als die
    /// Anzeige (16×16 auf acht Zeilen), die 8×8-Fassung **desselben** Icons,
    /// wenn es sie gibt, sonst das gewaehlte selbst.
    ///
    /// Die Zuordnung ist die Namenskonvention der 16er: Sie heissen
    /// `<Nummer oder Name der 8×8-Fassung>-16` (`haus` / `haus-16`). Eine
    /// andere Verknuepfung gibt es nicht; ein eigenes 16×16 ohne diese Endung
    /// oder ohne 8×8 gleichen Namens bleibt unveraendert. Umgekehrt wird ein
    /// 8×8 nie durch ein 16×16 ersetzt: Es sitzt auf der TC002 mittig in 16
    /// Zeilen und laesst dem Text die Breite, ein 16×16 nimmt ihm acht Spalten.
    ///
    /// `bestaende` wird nur gelesen, wenn ersetzt werden muss.
    public static func passend(_ icon: Icon, fuer mass: Anzeigemass,
                               in bestaende: (() -> [Iconsammlung])? = nil) -> Icon {
        guard icon.kante > mass.hoehe, icon.nummer.hasSuffix(kennungDerSechzehner) else { return icon }
        let grundname = String(icon.nummer.dropLast(kennungDerSechzehner.count))
        let sammlungen = bestaende?() ?? alle()
        for sammlung in sammlungen {
            if let treffer = sammlung.alle().first(where: {
                $0.nummer == grundname && $0.kante <= mass.hoehe
            }) { return treffer }
        }
        return icon
    }

    /// Der Satz fuer die Vorschau und die Kommandozeile, wenn eine Uhr statt des
    /// gewaehlten Icons dessen kleinere Fassung bekommt; sonst `nil`.
    public static func hinweis(gewaehlt: Icon, tatsaechlich: Icon?, uhr: String) -> String? {
        guard let t = tatsaechlich, t.kante != gewaehlt.kante else { return nil }
        return lokf("Für %@ das %d×%d-Icon statt %d×%d", uhr, t.kante, t.kante, gewaehlt.kante, gewaehlt.kante)
    }

    /// Endung des Schluessels eines 16×16, das zu einem 8×8 gehoert.
    static let kennungDerSechzehner = "-16"
}
