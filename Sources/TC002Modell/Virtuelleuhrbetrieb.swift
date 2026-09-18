import Foundation
import Observation
import TC002Core

/// Die virtuelle Uhr im Betrieb — der Dienst, sein Zustand und der
/// Schalter dafür, an einer Stelle für alle drei Oberflächen.
///
/// Eine gemeinsame Instanz und nicht je Ansicht eine: Es gibt genau einen
/// Port, also genau eine virtuelle Uhr. Zwei Objekte hieße zwei Dienste, von
/// denen der zweite nicht starten kann — und ein Fenster, das den Zustand des
/// falschen zeigt.
///
/// Der Schalter überlebt den Programmstart (`UserDefaults`): Wer eine Uhr mit
/// der Adresse `127.0.0.1:8752` eingetragen hat, findet sie sonst nach dem
/// nächsten Start tot vor.
@MainActor
@Observable
public final class Virtuelleuhrbetrieb {
    public static let gemeinsam = Virtuelleuhrbetrieb()

    private static let schluessel = "virtuelleuhr.an"

    public private(set) var laeuft = false
    public private(set) var zustand = Uhrzustand()
    /// Warum sie nicht läuft — etwa, weil der Port belegt ist.
    public private(set) var fehler: String?

    @ObservationIgnored private var server: Uhrenserver?

    /// Die Adresse, die in den Einstellungen einzutragen ist.
    public nonisolated var adresse: String { "127.0.0.1:\(Uhrenserver.vorgabePort)" }

    private init() {}

    /// Beim Start des Programms: Der Dienst kommt wieder hoch, wenn er beim
    /// Beenden lief.
    public func beimStart() {
        guard UserDefaults.standard.bool(forKey: Self.schluessel) else { return }
        starten()
    }

    public func starten() {
        fehler = nil
        let neu = Uhrenserver(port: Uhrenserver.vorgabePort, zustand: zustand)
        neu.beiAenderung = { [weak self] neuerZustand in
            MainActor.assumeIsolated { self?.zustand = neuerZustand }
        }
        do {
            try neu.starten()
            server = neu
            laeuft = true
            UserDefaults.standard.set(true, forKey: Self.schluessel)
        } catch {
            fehler = lokf("Der Port %d lässt sich nicht öffnen: %@",
                          Int(Uhrenserver.vorgabePort), "\(error)")
            laeuft = false
        }
    }

    public func beenden() {
        server?.beenden()
        server = nil
        laeuft = false
        UserDefaults.standard.set(false, forKey: Self.schluessel)
    }

    /// Was die Uhr gerade zeigt, als Pixelfeld — `nil`, wenn dort nichts liegt
    /// oder die Nutzlast sich nicht zerlegen lässt (ein Lauf-GIF etwa). Der
    /// Rückweg ist derselbe, den die App beim Mitlesen über MQTT geht.
    public func bild(von name: String?) -> Pixelfeld? {
        guard let name, let daten = zustand.anzeigen[name],
              let punkte = Anzeigen.pixelAusCustomNutzlast(daten) else { return nil }
        return Pixelfeld(punkte: punkte)
    }
}
