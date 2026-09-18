import XCTest
@testable import TC002Core

/// Ein Leerzeichen am Rand der Adresse ist unsichtbar: In einer Uhrenzeile
/// ` 127.0.0.1:8752` sieht man nichts falsch, gemeldet wird es erst beim
/// Senden, mitten in der Arbeit. Beides ist hier abgestellt: Getrimmt wird
/// beim Setzen, und ob eine Adresse ueberhaupt taugt, laesst sich vorher
/// fragen.
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
        XCTAssertFalse(Geraet.adresseTaugt(" 127.0.0.1:8752"))
        XCTAssertFalse(Geraet.adresseTaugt("10.0.0.5 /pfad"))
    }

    /// Was `URL(string:)` allein nicht faengt: ein Schema ohne
    /// Rechnernamen. `http:///getBase` ist gueltig und zeigt nirgendwohin.
    func testEinLeererRechnernameFaelltAuf() {
        XCTAssertFalse(Geraet.adresseTaugt("/uhr"))
    }
}

/// Auch das Werkzeug und die Kurzbefehle lesen diese Datei. Sie gehen nicht
/// ueber `AppZustand`, sondern ueber `Einstellungen.gelesen()` — und zwar
/// moeglicherweise, bevor die App das naechste Mal laeuft und die Adresse
/// von selbst heilt.
final class GelesenAdresseTests: XCTestCase {
    func testDerLeserTrimmtDieAdressen() {
        let krumm = [Uhr(name: "a", host: " 10.0.0.5 "), Uhr(name: "b", host: "10.0.0.6")]
        XCTAssertEqual(krumm.mitSauberenAdressen().map(\.host), ["10.0.0.5", "10.0.0.6"])
    }

    /// Und zwar wirklich beim Lesen, nicht nur als Funktion, die niemand
    /// aufruft. Geprueft wird durch `Einstellungen.gelesen` hindurch, mit
    /// einem eigenen Ablagebereich — die Einrichtung des Auftraggebers
    /// bleibt unberuehrt.
    func testEinstellungenGelesenTrimmtDieAdressen() throws {
        let bereich = "cloud.eriks.mqtt-tc002.test." + UUID().uuidString
        let ablage = try XCTUnwrap(UserDefaults(suiteName: bereich))
        defer { UserDefaults().removePersistentDomain(forName: bereich) }

        let krumm = [Uhr(name: "Probe", host: " 10.0.0.5 ")]
        ablage.set(try JSONEncoder().encode(krumm), forKey: "uhren")

        let gelesen = Einstellungen.gelesen(bereich: bereich)
        XCTAssertEqual(gelesen.uhren.map(\.host), ["10.0.0.5"])
    }
}
