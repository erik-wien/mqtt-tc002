import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Anlegen, Bearbeiten und Duplizieren: Die Werte der Senden-Ansicht liegen in
/// einer eigenen Suite, `zielIDs` in den Standardeinstellungen (gesichert).
@MainActor
final class FavoritenbearbeitungTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "zielIDs"]
    private var sicherung: [String: Any?] = [:]
    private var ordner: [URL] = []
    private var suiteName = ""
    private var suite = UserDefaults.standard

    private let uhrA = Uhr(name: "Wohnzimmer", host: "", praefix: "wz/uhr", betriebsart: .mqtt)
    private let uhrB = Uhr(name: "Küche", host: "", praefix: "kue/uhr", betriebsart: .mqtt)

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        suiteName = "favoritenbearbeitung-" + UUID().uuidString
        suite = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        suite.removePersistentDomain(forName: suiteName)
        ordner.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    private func zustand() throws -> AppZustand {
        d.set(try JSONEncoder().encode([uhrA, uhrB]), forKey: "uhren")
        d.set(uhrA.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhrA.id])), forKey: "zielIDs")
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("favoriten-" + UUID().uuidString)
        ordner.append(u)
        return AppZustand(schluesselbund: Schluesselbunddoppelgaenger(), favoritenablage: Favoritenablage(ordner: u))
    }

    private func fav(_ titel: String, text: String, ziele: [UUID]) -> Favorit {
        Favorit(titel: titel, auftrag: Sendeauftrag(optionen: Meldungsoptionen(text: text), zielIDs: ziele))
    }

    func testAnlegenHebtAktuelleWerteAuf() throws {
        let z = try zustand()
        suite.set("Telco läuft", forKey: "senden.text")
        z.favoritAnlegen(titel: "  Telco  ", ablage: suite)
        XCTAssertEqual(z.favoriten.last?.titel, "Telco")
        XCTAssertEqual(z.favoriten.last?.auftrag.optionen.text, "Telco läuft")
        XCTAssertEqual(z.favoriten.last?.auftrag.zielIDs, [uhrA.id])
    }

    func testAnlegenMitLeeremTitelTutNichts() throws {
        let z = try zustand()
        z.favoritAnlegen(titel: "   ", ablage: suite)
        XCTAssertTrue(z.favoriten.isEmpty)
    }

    func testBearbeitenLaedtUndAbbrechenStelltHer() throws {
        let z = try zustand()
        let f = fav("F", text: "fav", ziele: [uhrB.id])
        z.favoriten = [f]
        suite.set("vorher", forKey: "senden.text")
        z.favoritBearbeiten(f.id, ablage: suite)
        XCTAssertEqual(suite.string(forKey: "senden.text"), "fav")
        XCTAssertEqual(z.zielIDs, [uhrB.id])
        XCTAssertEqual(z.bearbeitung?.titel, "F")
        z.bearbeitungAbbrechen(ablage: suite)
        XCTAssertEqual(suite.string(forKey: "senden.text"), "vorher")
        XCTAssertEqual(z.zielIDs, [uhrA.id])
        XCTAssertNil(z.bearbeitung)
    }

    func testZweitesBearbeitenBehaeltErstenVorherstand() throws {
        let z = try zustand()
        let f1 = fav("F1", text: "eins", ziele: [uhrB.id])
        let f2 = fav("F2", text: "zwei", ziele: [uhrB.id])
        z.favoriten = [f1, f2]
        suite.set("vorher", forKey: "senden.text")
        z.favoritBearbeiten(f1.id, ablage: suite)
        z.favoritBearbeiten(f2.id, ablage: suite)
        XCTAssertEqual(suite.string(forKey: "senden.text"), "zwei")
        z.bearbeitungAbbrechen(ablage: suite)
        XCTAssertEqual(suite.string(forKey: "senden.text"), "vorher")
        XCTAssertEqual(z.zielIDs, [uhrA.id])
    }

    func testSpeichernUeberschreibtFavorit() throws {
        let z = try zustand()
        let f = fav("F", text: "fav", ziele: [uhrB.id])
        z.favoriten = [f]
        z.favoritBearbeiten(f.id, ablage: suite)
        suite.set("neu", forKey: "senden.text")
        z.bearbeitungSpeichern(titel: "Neu", ablage: suite)
        XCTAssertEqual(z.favoriten.count, 1)
        XCTAssertEqual(z.favoriten[0].id, f.id)
        XCTAssertEqual(z.favoriten[0].titel, "Neu")
        XCTAssertEqual(z.favoriten[0].auftrag.optionen.text, "neu")
        XCTAssertEqual(suite.string(forKey: "senden.text"), "neu")
        XCTAssertNil(z.bearbeitung)
    }

    func testSpeichernMitLeeremTitelTutNichts() throws {
        let z = try zustand()
        let f = fav("F", text: "fav", ziele: [uhrB.id])
        z.favoriten = [f]
        z.favoritBearbeiten(f.id, ablage: suite)
        z.bearbeitungSpeichern(titel: " ", ablage: suite)
        XCTAssertNotNil(z.bearbeitung)
        XCTAssertEqual(z.favoriten, [f])
    }

    func testDuplizierenLegtHinterOriginalAn() throws {
        let z = try zustand()
        let a = fav("A", text: "a", ziele: [uhrB.id])
        let b = fav("B", text: "b", ziele: [uhrB.id])
        z.favoriten = [a, b]
        z.favoritDuplizieren(a.id, ablage: suite)
        XCTAssertNil(z.bearbeitung?.favoritID)
        XCTAssertEqual(z.bearbeitung?.titel, Favoriten.kopietitel("A"))
        z.bearbeitungSpeichern(titel: "A Kopie", ablage: suite)
        XCTAssertEqual(z.favoriten.map(\.titel), ["A", "A Kopie", "B"])
        XCTAssertEqual(z.favoriten[1].auftrag.optionen.text, "a")
        XCTAssertNotEqual(z.favoriten[1].id, a.id)
    }

    func testUnbekannteIDTutNichts() throws {
        let z = try zustand()
        z.favoritBearbeiten(UUID(), ablage: suite)
        z.favoritDuplizieren(UUID(), ablage: suite)
        XCTAssertNil(z.bearbeitung)
    }

    func testSpeichernNachLoeschenLegtNeuAn() throws {
        let z = try zustand()
        let f = fav("F", text: "fav", ziele: [uhrB.id])
        z.favoriten = [f]
        z.favoritBearbeiten(f.id, ablage: suite)
        z.favoritLoeschen(f.id)
        z.bearbeitungSpeichern(titel: "F", ablage: suite)
        XCTAssertEqual(z.favoriten.count, 1)
        XCTAssertEqual(z.favoriten[0].auftrag.optionen.text, "fav")
        XCTAssertNil(z.bearbeitung)
    }
}
