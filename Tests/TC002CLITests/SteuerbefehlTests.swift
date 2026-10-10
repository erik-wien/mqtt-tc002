import XCTest
import TC002Core
@testable import TC002CLI

/// Das Zerlegen der Steuerbefehle — ohne Netz und ohne Gerät.
final class SteuerbefehlTests: XCTestCase {
    private func befehl(_ a: String...) throws -> Optionen.Befehl { try Optionen.zerlegt(a).befehl }

    func testNeustart() throws {
        XCTAssertEqual(try befehl("neustart"), .neustart)
        XCTAssertEqual(try befehl("reboot"), .neustart)
        XCTAssertThrowsError(try befehl("neustart", "jetzt"))
    }

    func testDisplayAnUndAus() throws {
        XCTAssertEqual(try befehl("display", "an"), .display(an: true))
        XCTAssertEqual(try befehl("display", "aus"), .display(an: false))
        XCTAssertEqual(try befehl("display", "off"), .display(an: false))
        XCTAssertThrowsError(try befehl("display"))
        XCTAssertThrowsError(try befehl("display", "vielleicht"))
        XCTAssertThrowsError(try befehl("display", "an", "aus"))
    }

    func testHelligkeitMitBereich() throws {
        XCTAssertEqual(try befehl("helligkeit", "0"), .helligkeit(0))
        XCTAssertEqual(try befehl("helligkeit", "255"), .helligkeit(255))
        XCTAssertEqual(try befehl("brightness", "128"), .helligkeit(128))
        XCTAssertThrowsError(try befehl("helligkeit", "256"))
        XCTAssertThrowsError(try befehl("helligkeit", "-1"))
        XCTAssertThrowsError(try befehl("helligkeit", "hell"))
        XCTAssertThrowsError(try befehl("helligkeit"))
    }

    func testMoodlight() throws {
        XCTAssertEqual(try befehl("moodlight", "aus"), .moodlightAus)
        XCTAssertEqual(try befehl("moodlight", "--farbe", "#ff8800", "--helligkeit", "90"),
                       .moodlight(Moodlight(farbe: "#ff8800", helligkeit: 90)))
        XCTAssertEqual(try befehl("moodlight", "#112233"), .moodlight(Moodlight(farbe: "#112233")))
        XCTAssertEqual(try befehl("moodlight", "--kelvin", "2700"), .moodlight(Moodlight(kelvin: 2700)))
        XCTAssertThrowsError(try befehl("moodlight"), "ohne Angabe")
        XCTAssertThrowsError(try befehl("moodlight", "--kelvin", "2700", "--farbe", "#FFFFFF"))
        XCTAssertThrowsError(try befehl("moodlight", "--kelvin", "999"))
        XCTAssertThrowsError(try befehl("moodlight", "--helligkeit", "300"))
        XCTAssertThrowsError(try befehl("moodlight", "aus", "--kelvin", "3000"))
    }

    func testIndikator() throws {
        XCTAssertEqual(try befehl("indikator", "2", "--farbe", "#00FF00", "--blinken", "500", "--blenden", "100"),
                       .indikator(Indikator(nummer: 2, farbe: "#00FF00", blinkMs: 500, fadeMs: 100)))
        XCTAssertEqual(try befehl("indikator", "3", "aus"), .indikatorAus(nummer: 3))
        XCTAssertEqual(try befehl("indicator", "1", "off"), .indikatorAus(nummer: 1))
        XCTAssertThrowsError(try befehl("indikator", "4", "aus"))
        XCTAssertThrowsError(try befehl("indikator", "0", "--farbe", "#FFFFFF"))
        XCTAssertThrowsError(try befehl("indikator", "1"), "weder aus noch Farbe")
        XCTAssertThrowsError(try befehl("indikator", "1", "--farbe", "#FFFFFF", "--blinken", "70000"))
        XCTAssertThrowsError(try befehl("indikator"))
    }

    func testWeiterZurueckZustandEinstellungenTLS() throws {
        XCTAssertEqual(try befehl("weiter"), .weiter)
        XCTAssertEqual(try befehl("next"), .weiter)
        XCTAssertEqual(try befehl("zurueck"), .zurueck)
        XCTAssertEqual(try befehl("zustand"), .zustand)
        XCTAssertEqual(try befehl("einstellungen"), .einstellungen)
        XCTAssertEqual(try befehl("einstellungen", "setzen", "volume", "40"),
                       .einstellungenSetzen(schluessel: "volume", wert: "40"))
        XCTAssertEqual(try befehl("settings", "set", "scroll.speed", "200"),
                       .einstellungenSetzen(schluessel: "scroll.speed", wert: "200"))
        XCTAssertThrowsError(try befehl("einstellungen", "setzen", "volume"))
        XCTAssertThrowsError(try befehl("einstellungen", "loeschen"))
        XCTAssertEqual(try befehl("tls"), .tls)
        XCTAssertEqual(try befehl("tls", "ca", "ca.pem"), .tlsCA(datei: "ca.pem"))
        XCTAssertEqual(try befehl("tls", "ca", "entfernen"), .tlsCAEntfernen)
        XCTAssertEqual(try befehl("tls", "ca", "remove"), .tlsCAEntfernen)
        XCTAssertThrowsError(try befehl("tls", "ca"))
        XCTAssertThrowsError(try befehl("tls", "ein"), "TLS einzuschalten gibt es nicht")
        XCTAssertThrowsError(try befehl("weiter", "noch"))
    }

    func testOptionenDerSteuerungGeltenNurDort() {
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--kelvin", "3000"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "x", "--blinken", "3"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["display", "an", "--farbe", "#FFFFFF"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["moodlight", "--blinken", "3", "--kelvin", "3000"]))
    }

    func testDasTextKommandoBleibtErhalten() throws {
        XCTAssertEqual(try befehl("senden", "display"), .senden(text: "display"))
        XCTAssertEqual(try befehl("senden", "--farbe", "#112233", "hallo"), .senden(text: "hallo"))
    }
}
