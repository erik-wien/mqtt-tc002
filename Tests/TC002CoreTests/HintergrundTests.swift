import XCTest
@testable import TC002Core

/// Der Nachweis, dass blockierende Arbeit **nicht** im kooperativen Pool
/// landet. Ohne ihn wäre `Hintergrund` eine Behauptung: Ein Rückfall auf
/// `Task.detached` verhält sich im Kleinen genauso — er fällt erst auf, wenn
/// mehrere Uhren gleichzeitig nicht antworten, und dann als Hänger, den
/// niemand einem Commit zuordnet.
final class HintergrundTests: XCTestCase {
    func testDieArbeitLaeuftAufDerEigenenWarteschlange() async {
        let drauf = await Hintergrund.lauf { Hintergrund.aufEigenerSchlange }
        XCTAssertTrue(drauf, "die Arbeit lief nicht auf der eigenen Warteschlange — "
                      + "dann blockiert sie wieder den kooperativen Pool")
    }

    /// Die Gegenprobe, damit die Zusicherung oben nicht einfach „immer wahr"
    /// ist: Ausserhalb ist das Kennzeichen nicht gesetzt.
    func testAusserhalbIstDasKennzeichenNichtGesetzt() {
        XCTAssertFalse(Hintergrund.aufEigenerSchlange)
    }

    /// Auch der werfende Zweig läuft dort — er ist der häufigere, denn jeder
    /// Geräteaufruf wirft.
    func testAuchDerWerfendeZweigLaeuftDort() async throws {
        let drauf = try await Hintergrund.lauf { () throws -> Bool in
            Hintergrund.aufEigenerSchlange
        }
        XCTAssertTrue(drauf)
    }

    /// Ein Fehler kommt als Fehler zurück und nicht als verschluckter Wert.
    func testEinFehlerKommtDurch() async {
        struct Eigen: Error {}
        do {
            _ = try await Hintergrund.lauf { () throws -> Int in throw Eigen() }
            XCTFail("der Fehler ist unterwegs verlorengegangen")
        } catch is Eigen {
            // so soll es sein
        } catch {
            XCTFail("falscher Fehler: \(error)")
        }
    }

    /// **Die Warteschlange ist nebenläufig, nicht seriell.** Wäre sie seriell,
    /// wäre der Umbau eine Verschlechterung: Fünf Uhren würden nacheinander
    /// abgefragt statt nebeneinander, und eine tote Uhr hielte die vier
    /// anderen zehn Sekunden auf.
    func testMehrereArbeitenLaufenNebeneinander() async {
        let sperre = DispatchSemaphore(value: 0)
        async let eine: Void = Hintergrund.lauf { sperre.wait() }
        // Käme die zweite erst nach der ersten dran, liefe sie nie los und
        // dieser Aufruf kehrte nicht zurück — der Test bliebe hängen.
        await Hintergrund.lauf { sperre.signal() }
        await eine
    }
}
