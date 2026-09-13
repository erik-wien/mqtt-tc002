import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Die Ablage der Tests. Sie merkt sich, was geschrieben wurde, und faehrt
/// `NSUbiquitousKeyValueStore` **nie** an — dort haengt ein iCloud-Konto dran,
/// und in Tests gibt es kein Netz.
final class Wolkendoppelgaenger: Wolkenablage, @unchecked Sendable {
    var inhalt: Data?
    var geschrieben: [Data] = []
    private(set) var angestossen = 0

    init(_ inhalt: Data? = nil) { self.inhalt = inhalt }

    func lesen() -> Data? { inhalt }

    @discardableResult
    func schreiben(_ daten: Data) -> Bool {
        geschrieben.append(daten)
        inhalt = daten
        return true
    }

    @discardableResult
    func anstossen() -> Bool { angestossen += 1; return true }

    /// Setzt die Ablage auf einen Stand und vergisst, was bisher geschrieben
    /// wurde. Ohne das waeren die Tests selbsterfuellend: Der Zustand hat beim
    /// Bauen schon einmal gelesen und bei der ersten Aenderung geschrieben,
    /// die Ablage kennt also laengst beide Seiten — und jede Behauptung ueber
    /// das Zusammenfuehren waere schon vorher wahr.
    func stellen(_ stand: Einrichtungsstand) {
        inhalt = stand.alsDaten
        geschrieben = []
    }

    var letzterStand: Einrichtungsstand? {
        guard let daten = geschrieben.last else { return nil }
        return try? JSONDecoder().decode(Einrichtungsstand.self, from: daten)
    }
}

/// Der Abgleich der Einstellungen. Wie in `AppZustandTests` werden die
/// angefassten Schluessel des Testprozesses vorher gesichert und nachher
/// wiederhergestellt; angefasst wird nie die Ablage der echten App.
@MainActor
final class WolkenabgleichTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer"]
    private var sicherung: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        for schl in schluessel { d.removeObject(forKey: schl) }
    }

    override func tearDown() {
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func zustand(_ wolke: Wolkendoppelgaenger, gewaehlt: Bool = true) -> AppZustand {
        AppZustand(schluesselbund: Schluesselbunddoppelgaenger(),
                   wolke: wolke, wolkeGewaehlt: gewaehlt)
    }

    // MARK: Hinaus

    /// Ohne gewaehlten Abgleich geht nichts in die Wolke — auch nicht
    /// versehentlich beim ersten Tastendruck.
    func testOhneWahlWirdNichtsGeschrieben() {
        let wolke = Wolkendoppelgaenger()
        let z = zustand(wolke, gewaehlt: false)
        z.uhrHinzufuegen(host: "10.0.0.5")
        z.brokerHost = "10.0.0.20"
        XCTAssertTrue(wolke.geschrieben.isEmpty)
        XCTAssertEqual(wolke.angestossen, 0, "ohne Wahl wird nicht einmal gehorcht")
    }

    func testEineNeueUhrLandetInDerWolke() throws {
        let wolke = Wolkendoppelgaenger()
        let z = zustand(wolke)
        z.uhrHinzufuegen(host: "10.0.0.5")
        let stand = try XCTUnwrap(wolke.letzterStand)
        XCTAssertEqual(stand.uhren.map(\.host), ["10.0.0.5"])
    }

    func testDerBrokerLandetInDerWolke() throws {
        let wolke = Wolkendoppelgaenger()
        let z = zustand(wolke)
        z.brokerHost = "10.0.0.20"
        z.benutzer = "pixdeck"
        let stand = try XCTUnwrap(wolke.letzterStand)
        XCTAssertEqual(stand.brokerHost, "10.0.0.20")
        XCTAssertEqual(stand.benutzer, "pixdeck")
    }

    // MARK: Herein — und warum das Werkzeug folgt

    /// **Der Kern der Sache.** Was aus der Wolke kommt, wird zusammengefuehrt
    /// *und in die gewoehnlichen Einstellungen geschrieben*. Nur deshalb sieht
    /// das Kommandozeilenwerkzeug dieselben Uhren wie die App: Es liest
    /// weiterhin `UserDefaults` und faehrt iCloud nie an. Ein Werkzeug, das
    /// andere Uhren saehe als die App, waere eine Falle.
    func testWasAusDerWolkeKommtStehtDanachInDenEinstellungen() throws {
        let wolke = Wolkendoppelgaenger()
        let z = zustand(wolke)
        z.uhrHinzufuegen(host: "10.0.0.5")
        // Jetzt erst meldet sich das andere Geraet.
        let fremde = Uhr(name: "Büro", host: "10.0.0.9", betriebsart: .http)
        wolke.stellen(Einrichtungsstand(uhren: [fremde]))
        XCTAssertEqual(try JSONDecoder().decode(
            [Uhr].self, from: try XCTUnwrap(d.data(forKey: "uhren"))).map(\.host), ["10.0.0.5"])

        z.wolkeLesen()

        XCTAssertEqual(Set(z.uhren.map(\.host)), ["10.0.0.5", "10.0.0.9"])
        let ausDenEinstellungen = try JSONDecoder().decode(
            [Uhr].self, from: try XCTUnwrap(d.data(forKey: "uhren")))
        XCTAssertEqual(Set(ausDenEinstellungen.map(\.host)), ["10.0.0.5", "10.0.0.9"],
                       "so — und nur so — folgt das Werkzeug dem Abgleich")
    }

    /// Was beim Zusammenfuehren dazugekommen ist, muss zurueck: Sonst kennte
    /// das andere Geraet die hier eingetragene Uhr nie.
    func testWasNurHierStehtGehtZurueckInDieWolke() throws {
        let wolke = Wolkendoppelgaenger()
        let z = zustand(wolke)
        z.uhrHinzufuegen(host: "10.0.0.5")
        let fremde = Uhr(name: "Büro", host: "10.0.0.9")
        wolke.stellen(Einrichtungsstand(uhren: [fremde]))

        z.wolkeLesen()

        let stand = try XCTUnwrap(wolke.letzterStand)
        XCTAssertEqual(Set(stand.uhren.map(\.host)), ["10.0.0.5", "10.0.0.9"])
    }

    /// Kein Echo: Bringt die Wolke nichts Neues, wird nichts zurueckgeschrieben.
    /// Sonst schaukelten sich zwei Geraete gegenseitig hoch.
    func testEinUnveraenderterStandLoestKeinSchreibenAus() {
        let wolke = Wolkendoppelgaenger()
        let z = zustand(wolke)
        z.uhrHinzufuegen(host: "10.0.0.5")
        wolke.stellen(z.eigenerStand)

        z.wolkeLesen()

        XCTAssertTrue(wolke.geschrieben.isEmpty, "nichts Neues, nichts zu schreiben")
    }

    /// Verschwindet die aktive Uhr nicht, bleibt sie aktiv — und ist gar keine
    /// da, wird die erste aus dem uebernommenen Stand aktiv. Ohne das zeigte
    /// „Senden" auf nichts, obwohl Uhren eingetragen sind.
    func testNachDemUebernehmenIstEineUhrAktiv() {
        let fremde = Uhr(name: "Büro", host: "10.0.0.9")
        let wolke = Wolkendoppelgaenger()
        let z = zustand(wolke)
        wolke.stellen(Einrichtungsstand(uhren: [fremde]))
        z.wolkeLesen()
        XCTAssertEqual(z.aktiveID, fremde.id)
    }

    /// Beim Einschalten wird gehorcht und gelesen — sonst bekaeme das Geraet
    /// erst beim naechsten Griff des anderen mit, dass es etwas gibt.
    func testBeimStartMitWahlWirdGelesen() {
        let fremde = Uhr(name: "Büro", host: "10.0.0.9")
        let wolke = Wolkendoppelgaenger(Einrichtungsstand(uhren: [fremde]).alsDaten)
        let z = zustand(wolke)
        XCTAssertEqual(wolke.angestossen, 1)
        XCTAssertEqual(z.uhren.map(\.host), ["10.0.0.9"])
    }
}
