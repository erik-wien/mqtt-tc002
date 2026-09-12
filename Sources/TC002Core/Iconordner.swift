import Foundation

/// Wo Icons liegen. Mitgeliefertes wird nur gelesen, Eigenes nur geschrieben.
public enum Iconordner {
    /// Die mitgelieferten Icons, im Bundle neben der App.
    public static var mitgeliefert: URL {
        Programmbuendel.eigenes.resourceURL?.appendingPathComponent("Icons")
            ?? URL(fileURLWithPath: "Icons")
    }

    /// Selbst gemalte und von LaMetric geholte Icons. Im Bundle haetten sie nichts
    /// verloren: dort waeren sie beim naechsten Bau weg, und unter /Applications
    /// ist der Ordner nicht beschreibbar.
    public static var eigene: URL {
        let ordner = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MQTT-TC002/Icons")
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner
    }
}
