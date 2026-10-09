import XCTest
@testable import TC002Core

private final class NGMitschreiber: NachrichtSendend {
    var gesendet: [(thema: String, nutzlast: String)] = []
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        gesendet.append((thema, String(data: nutzlast, encoding: .utf8) ?? ""))
    }
}

/// Der Kanal (HTTP oder MQTT) sagt, wie die Bytes hinkommen. Diese Datei
/// prueft die Themen und Nutzlasten von AWTRIX NG — und dass eine Sendung, die
/// auf einer AWTRIX nichts ergeben kann, gar nicht erst abgeschickt wird.
final class AnzeigenNGTests: XCTestCase {
    private let zugang = MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p")

    /// Ein Rahmen, wie ihn `Meldungsbau.rahmen` baut: mit den Reglern, aus
    /// denen er entstand.
    private func rahmenMitHerkunft(_ text: String = "hallo") -> Frame {
        Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: text, weg: .text)))
    }

    private func ngKanal(_ sender: NachrichtSendend, praefix: String = "wohnzimmer/uhr") -> Anzeigen {
        Anzeigen(sender: sender, zugang: zugang, praefix: praefix)
    }

    // MARK: - Thema und Nutzlast

    /// Die Nutzlast ist der Text, nicht Pixel.
    func testDieNutzlastIstDerText() throws {
        let neu = NGMitschreiber()
        try ngKanal(neu).zeigen(rahmenMitHerkunft("Grüße"), auf: "meldung1")

        XCTAssertFalse(neu.gesendet.first?.nutzlast.contains(#""df""#) == true,
                       "eine AWTRIX kann mit unseren Pixeln nichts anfangen")
        XCTAssertTrue(neu.gesendet.first?.nutzlast.contains(#""text":"Grüße""#) == true)
    }

    /// Ueber MQTT loescht die leere Nutzlast, genau null Bytes.
    func testLoeschenIstDieLeereNutzlast() throws {
        let sender = NGMitschreiber()
        try ngKanal(sender).loeschen("meldung1")
        XCTAssertEqual(sender.gesendet.first?.thema, "wohnzimmer/uhr/cmd/apps/pushed/meldung1")
        XCTAssertEqual(sender.gesendet.first?.nutzlast, "")
    }

    /// Umschalten: anderes Thema, und der Name als JSON statt blank — damit die
    /// MQTT-Nutzlast byteweise derselbe Rumpf ist wie die der HTTP-Anfrage.
    func testUmschaltenGehtAufDasSwitchThema() throws {
        let sender = NGMitschreiber()
        try ngKanal(sender).umschalten(auf: "meldung2")
        XCTAssertEqual(sender.gesendet.first?.thema, "wohnzimmer/uhr/cmd/apps/switch")
        XCTAssertEqual(sender.gesendet.first?.nutzlast, #"{"name":"meldung2"}"#)
    }

    // MARK: - Was nicht abgeschickt wird

    /// Ein Rahmen ohne Text und ohne Pixel ist nichts zu senden — und wird
    /// nicht gesendet.
    func testEinLeererRahmenWirdNichtGesendet() {
        let sender = NGMitschreiber()
        XCTAssertThrowsError(try ngKanal(sender).zeigen(Frame(), auf: "meldung1")) { fehler in
            guard case NGFehler.leer = fehler else { return XCTFail("war stattdessen \(fehler)") }
        }
        XCTAssertTrue(sender.gesendet.isEmpty)
    }

    // MARK: - Der Kanal einer Uhr

    // MARK: - Das Inventar

    /// Am Geraet gelesen (§7.2). `origin` trennt unsere Anzeigen von den
    /// eingebauten und den Skripten.
    func testNurPushedZaehltAlsUnsereAnzeige() {
        let inventar: [Any] = [["name": "Time", "origin": "builtin"],
                               ["name": "meldung2", "origin": "pushed"],
                               ["name": "meldung5", "origin": "pushed"],
                               ["name": "tempo", "origin": "script"]]
        XCTAssertEqual(Anzeigen.namenAusNGInventar(inventar), ["meldung2", "meldung5"])
    }

    /// Leer ist eine Auskunft, unlesbar ist keine — derselbe Unterschied wie
    /// bei `namenAusCustomList`.
    func testEinUnlesbaresInventarIstNichtDieLeereListe() {
        XCTAssertEqual(Anzeigen.namenAusNGInventar([]), [])
        XCTAssertNil(Anzeigen.namenAusNGInventar(nil))
        XCTAssertNil(Anzeigen.namenAusNGInventar("online"))
    }
}
