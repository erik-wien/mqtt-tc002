import Foundation

/// Trägt ein Ergebnis von einer Rückrufwarteschlange zum wartenden, blockierenden
/// Aufrufer.
///
/// Ein Rückruf, der erst nach der Frist feuert, darf nichts mehr schreiben: Der
/// Aufrufer ist da längst mit einem Fehler zurück, und Variablen, die er
/// erfasst hat, würden von zwei Threads ohne Schloss berührt. `abwarten`
/// schließt das Fach nach der Frist; ein späteres `abgeben` wird verworfen.
final class Rueckruffach<Wert>: @unchecked Sendable {
    private let sperre = NSLock()
    private let signal = DispatchSemaphore(value: 0)
    private var wert: Wert?
    private var geschlossen = false

    /// Legt das Ergebnis ab. `false`, wenn die Frist schon vorbei war oder schon
    /// etwas darin liegt — dann bleibt der alte Stand unberührt.
    @discardableResult
    func abgeben(_ neu: Wert) -> Bool {
        sperre.lock(); defer { sperre.unlock() }
        guard !geschlossen, wert == nil else { return false }
        wert = neu
        signal.signal()
        return true
    }

    /// Wartet bis zur Frist. `nil`, wenn nichts kam; das Fach ist danach zu.
    func abwarten(frist: TimeInterval) -> Wert? {
        _ = signal.wait(timeout: .now() + frist)
        sperre.lock(); defer { sperre.unlock() }
        geschlossen = true
        return wert
    }
}
