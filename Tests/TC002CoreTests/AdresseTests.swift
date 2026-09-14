import XCTest
@testable import TC002Core

/// **Ein Leerzeichen am Rand der Adresse ist unsichtbar und toedlich.**
///
/// Am 14.09.2026 stand in einer Uhrenzeile ` 127.0.0.1:8752`. Zu sehen war
/// nichts; gemeldet wurde es erst beim Senden, als Fenster mitten in der
/// Arbeit. Beides ist hier abgestellt: Getrimmt wird beim Setzen, und ob eine
/// Adresse ueberhaupt taugt, laesst sich vorher fragen.
final class AdresseTests: XCTestCase {
    func testDerRandWirdBeimSetzenGetrimmt() {
        var uhr = Uhr(name: "x", host: " 127.0.0.1:8752 ")
        // Schon beim Anlegen? Nein — Beobachter laufen beim Initialisieren
        // nicht. Beim naechsten Setzen aber schon, und das ist der Weg, den
        // ein Eingabefeld geht.
        uhr.host = " 127.0.0.1:8752 "
        XCTAssertEqual(uhr.host, "127.0.0.1:8752")

        uhr.host = "\n10.0.0.5\t"
        XCTAssertEqual(uhr.host, "10.0.0.5")
    }

    /// In der Mitte wird nichts angetastet — dort ist ein Leerzeichen sichtbar,
    /// und was ein gueltiger Rechnername ist, entscheidet kein Trimmer.
    func testInDerMitteBleibtAllesStehen() {
        var uhr = Uhr(name: "x", host: "a")
        uhr.host = "mein geraet"
        XCTAssertEqual(uhr.host, "mein geraet")
    }

    func testEineTaugendeAdresse() {
        XCTAssertTrue(Geraet.adresseTaugt("10.0.0.5"))
        XCTAssertTrue(Geraet.adresseTaugt("127.0.0.1:8752"))
        XCTAssertTrue(Geraet.adresseTaugt("uhr.local"))
    }

    func testEineAdresseDieNichtTaugt() {
        XCTAssertFalse(Geraet.adresseTaugt(""))
        XCTAssertFalse(Geraet.adresseTaugt("   "))
        // Der Fall aus dem Bildschirmfoto.
        XCTAssertFalse(Geraet.adresseTaugt(" 127.0.0.1:8752"))
        XCTAssertFalse(Geraet.adresseTaugt("10.0.0.5 /pfad"))
    }

    /// Was `URL(string:)` allein **nicht** faengt: ein Schema ohne
    /// Rechnernamen. `http:///getBase` ist gueltig und zeigt nirgendwohin.
    func testEinLeererRechnernameFaelltAuf() {
        XCTAssertFalse(Geraet.adresseTaugt("/uhr"))
    }
}
