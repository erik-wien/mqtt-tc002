import Foundation

/// Blockierende Arbeit gehört nicht in den kooperativen Pool.
///
/// Der Kern spricht Uhr und Broker mit einem `DispatchSemaphore` an: Der Aufruf
/// kehrt erst zurück, wenn die Antwort da ist oder die Frist abgelaufen. Das ist
/// Absicht — `mqtttc002` ist ein Kommandozeilenwerkzeug und braucht einen
/// Aufruf, der dasteht, bis er fertig ist.
///
/// Falsch war, wo die App ihn aufrief. `Task.detached` ist kein freier
/// Thread, sondern der kooperative Pool von Swift Concurrency, und der hat
/// ungefähr so viele Threads, wie der Rechner Kerne hat. Wer dort zehn Sekunden
/// auf ein Semaphor wartet, hält einen knappen Platz besetzt; sind mehrere
/// Uhren eingetragen und eine davon nicht erreichbar, blockieren mehrere
/// zugleich, und im schlimmsten Fall hungert alles aus, was auf `await` wartet
/// — auch die Rückkehr zum Hauptakteur. Xcode nennt das
/// „unsafeForcedSync called from Swift Concurrent context".
///
/// Hier läuft die Arbeit deshalb auf einer eigenen nebenläufigen
/// Warteschlange. Deren Threads darf man blockieren; das System legt bei Bedarf
/// weitere an. Zurück kommt das Ergebnis über eine Fortsetzung, der Aufrufer
/// bleibt also ein gewöhnlicher `await`.
///
/// Nicht dafür gedacht ist reine Rechenarbeit. Rastern, GIFs bauen,
/// Schriftproben — das gehört weiterhin in `Task.detached`, denn genau dafür
/// ist der kooperative Pool da. Der Unterschied ist nicht „dauert lange",
/// sondern „wartet auf etwas anderes".
public enum Hintergrund {
    /// Zum Nachweis, dass die Arbeit wirklich hier läuft (siehe
    /// `aufEigenerSchlange`) — sonst wäre dieser ganze Typ nicht prüfbar,
    /// und ein Rückfall auf `Task.detached` fiele niemandem auf.
    private static let kennzeichen = DispatchSpecificKey<Bool>()

    private static let schlange: DispatchQueue = {
        let s = DispatchQueue(label: "cloud.eriks.mqtt-tc002.blockierend",
                              qos: .userInitiated, attributes: .concurrent)
        s.setSpecific(key: kennzeichen, value: true)
        return s
    }()

    /// Läuft der gerade ausgeführte Code auf der Warteschlange dieses Typs?
    public static var aufEigenerSchlange: Bool {
        DispatchQueue.getSpecific(key: kennzeichen) == true
    }

    /// Führt `arbeit` abseits des kooperativen Pools aus und gibt ihr Ergebnis
    /// zurück. Wirft weiter, was sie wirft.
    public static func lauf<T: Sendable>(
        _ arbeit: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { fortsetzung in
            schlange.async {
                do { fortsetzung.resume(returning: try arbeit()) }
                catch { fortsetzung.resume(throwing: error) }
            }
        }
    }

    /// Dieselbe Sache für Arbeit, die nicht wirft.
    public static func lauf<T: Sendable>(
        _ arbeit: @escaping @Sendable () -> T
    ) async -> T {
        await withCheckedContinuation { fortsetzung in
            schlange.async { fortsetzung.resume(returning: arbeit()) }
        }
    }
}
