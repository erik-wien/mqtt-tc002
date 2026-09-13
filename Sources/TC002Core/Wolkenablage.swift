import Foundation

/// Die Schluessel-Wert-Ablage in iCloud, hinter einem Protokoll — wie
/// `Schluesselbundzugriff` beim Schluesselbund. Die App reicht nichts mit und
/// bekommt die echte, die Tests geben einen Doppelgaenger. **Kein Test fasst
/// iCloud an.**
public protocol Wolkenablage: Sendable {
    func lesen() -> Data?
    @discardableResult func schreiben(_ daten: Data) -> Bool
    /// Stoesst den Abgleich an. `false` heisst nur: Die Ablage war nicht
    /// erreichbar — nicht, dass etwas verlorenging.
    @discardableResult func anstossen() -> Bool
}

/// `NSUbiquitousKeyValueStore` unter **einem** Schluessel (siehe
/// `Einrichtungsstand`).
///
/// Ohne die Berechtigung `com.apple.developer.ubiquity-kvstore-identifier`
/// gibt es keine Ablage: `synchronize()` meldet `false`, Geschriebenes bleibt
/// oertlich liegen und kommt nirgends an. Das ist kein Fehler, der zu melden
/// waere — es ist derselbe Normalfall wie ein fehlender Dateibehaelter, und
/// `Ablageort` laesst den Abgleich dann gar nicht erst angehen.
public struct EchteWolkenablage: Wolkenablage {
    public static let schluessel = "einrichtung"

    public init() {}

    private var ablage: NSUbiquitousKeyValueStore { .default }

    public func lesen() -> Data? { ablage.data(forKey: Self.schluessel) }

    @discardableResult
    public func schreiben(_ daten: Data) -> Bool {
        ablage.set(daten, forKey: Self.schluessel)
        return ablage.synchronize()
    }

    @discardableResult
    public func anstossen() -> Bool { ablage.synchronize() }
}
