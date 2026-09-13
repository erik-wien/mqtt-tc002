import Foundation

/// Wo Icons liegen. Mitgeliefertes wird nur gelesen, Eigenes nur geschrieben.
///
/// **Wo „eigen" ist, entscheidet `Ablageort`** — oertlich oder im
/// iCloud-Behaelter. Hier steht nur noch, welcher der vier Bestaende gemeint
/// ist; angelegt wird der Ordner einmal beim Ermitteln des Orts, nicht bei
/// jedem Zugriff.
public enum Iconordner {
    /// Die mitgelieferten Icons, im Bundle neben der App.
    public static var mitgeliefert: URL {
        Programmbuendel.eigenes.resourceURL?.appendingPathComponent("Icons")
            ?? URL(fileURLWithPath: "Icons")
    }

    /// Selbst gemalte und von LaMetric geholte Icons, 8×8. Im Bundle haetten sie
    /// nichts verloren: dort waeren sie beim naechsten Bau weg, und unter
    /// /Applications ist der Ordner nicht beschreibbar.
    public static var eigene: URL { Ablageort.gemeinsam.ordner(.icons8) }

    /// Die eigenen 16×16-Icons — **ein eigener Ordner neben den 8×8**.
    ///
    /// Ein 16×16 ist kein LaMetric-Icon: Es hat keine Nummer, laesst sich nicht
    /// nachladen und geht anders auf die Uhr (volle Hoehe, doppelte Breite).
    /// Sie in denselben Ordner zu legen hiesse, beim Lesen jeder Datei erst
    /// nachsehen zu muessen, was sie ist — und, schlimmer, den vorhandenen
    /// Bestand zu veraendern: Eine aeltere Fassung der App liest `Icons/`
    /// weiterhin als 8×8 und rechnete jedes 16×16 darin stillschweigend
    /// herunter. So bleibt `Icons/` genau das, was es war, und eine aeltere
    /// Fassung sieht den neuen Ordner einfach nicht.
    public static var eigene16: URL { Ablageort.gemeinsam.ordner(.icons16) }
}
