import Foundation

/// Die MQTT-Client-Kennungen der App. Ein Broker trennt die bestehende Sitzung,
/// sobald dieselbe Kennung erneut verbindet. Die Uhr-UUID kommt über iCloud auf
/// jedes Gerät; eine Kennung nur aus ihr wäre auf Mac, iPad und iPhone dieselbe,
/// und die Geräte würfen sich gegenseitig hinaus — beim Mitlesen im Takt des
/// Neuverbindens. Deshalb steht eine Kennung dieser Installation darin
/// (`Sendeverlauf.eigeneKennung`, je Installation fest).
///
/// Länge: MQTT 3.1.1 verlangt nur 23 Zeichen von einem Broker. Der Aufbau
/// `tc2-<Rolle>-<Uhr 4>-<Gerät 4>` ist 15 Zeichen lang; mit dem längsten
/// Zusatz, den der Kern anhängt („-antwort“, `Ergebnislauscher`), bleibt es
/// bei 23.
public enum MQTTKennung {
    public static let hoechstlaenge = 23

    /// Eine Rolle je Verbindungsart: Senden, Mitlesen und Kurzbefehl laufen
    /// gleichzeitig und dürfen sich nicht hinauswerfen.
    public enum Rolle: String, Sendable {
        case senden = "s", horchen = "h", kurzbefehl = "k"
    }

    /// Vier Zeichen, die diese Installation benennen.
    public static func geraet(_ ablage: UserDefaults = .standard) -> String {
        String(Sendeverlauf.eigeneKennung(ablage).lowercased().prefix(4))
    }

    public static func fuer(_ rolle: Rolle, uhr: UUID, ablage: UserDefaults = .standard) -> String {
        "tc2-\(rolle.rawValue)-\(uhr.uuidString.lowercased().prefix(4))-\(geraet(ablage))"
    }

    /// Die Prüfverbindung der Einstellungen (`AppZustand.brokerPruefen`).
    public static func pruefung(ablage: UserDefaults = .standard) -> String {
        "tc2-p-\(geraet(ablage))"
    }
}
