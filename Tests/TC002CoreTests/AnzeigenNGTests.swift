import XCTest
@testable import TC002Core

private final class NGMitschreiber: NachrichtSendend {
    var gesendet: [(thema: String, nutzlast: String)] = []
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        gesendet.append((thema, String(data: nutzlast, encoding: .utf8) ?? ""))
    }
}

/// **Zwei Achsen, vier Faelle.** Der Kanal (HTTP oder MQTT) sagt, wie die Bytes
/// hinkommen; die Gattung, welche Bytes es sind. Diese Datei prueft, dass beide
/// unabhaengig voneinander wirken — und dass eine Sendung, die auf einer AWTRIX
/// nichts ergeben kann, gar nicht erst abgeschickt wird.
final class AnzeigenNGTests: XCTestCase {
    private let zugang = MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p")

    /// Ein Rahmen, wie ihn `Meldungsbau.rahmen` baut: Pixel fuer die
    /// Werksfirmware **und** die Regler, aus denen sie entstanden.
    private func rahmenMitHerkunft(_ text: String = "hallo") -> Frame {
        Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 2, hoehe: 1, farbe: "#00FF66")],
              herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: text)))
    }

    private func ngKanal(_ sender: NachrichtSendend, praefix: String = "wohnzimmer/uhr") -> Anzeigen {
        Anzeigen(sender: sender, zugang: zugang, praefix: praefix, gattung: .awtrixNG)
    }

    // MARK: - Dieselbe Uhr, zwei Gattungen, zwei Themen

    /// Das Thema ist ein voellig anderes — kein `custom`, sondern
    /// `cmd/apps/pushed`. Ein Schreibfehler waere auf beiden Gattungen
    /// unsichtbar: MQTT 3.1.1 quittiert eine Veroeffentlichung nicht, und NG
    /// antwortet auf ein Thema ohne Route ueberhaupt nicht.
    func testDieGattungEntscheidetUeberDasThema() throws {
        let alt = NGMitschreiber(), neu = NGMitschreiber()
        try Anzeigen(sender: alt, zugang: zugang, praefix: "awtrix_a86b")
            .zeigen(rahmenMitHerkunft(), auf: "meldung1")
        try ngKanal(neu).zeigen(rahmenMitHerkunft(), auf: "meldung1")

        XCTAssertEqual(alt.gesendet.first?.thema, "awtrix_a86b/custom/meldung1")
        XCTAssertEqual(neu.gesendet.first?.thema, "wohnzimmer/uhr/cmd/apps/pushed/meldung1")
    }

    /// Und die Nutzlast ebenso: Die Werksfirmware bekommt Pixel, NG den Text.
    func testDieGattungEntscheidetUeberDieNutzlast() throws {
        let alt = NGMitschreiber(), neu = NGMitschreiber()
        try Anzeigen(sender: alt, zugang: zugang, praefix: "awtrix_a86b")
            .zeigen(rahmenMitHerkunft("Grüße"), auf: "meldung1")
        try ngKanal(neu).zeigen(rahmenMitHerkunft("Grüße"), auf: "meldung1")

        XCTAssertTrue(alt.gesendet.first?.nutzlast.contains(#""df""#) == true,
                      "die Werksfirmware bekommt Zeichenbefehle")
        XCTAssertFalse(neu.gesendet.first?.nutzlast.contains(#""df""#) == true,
                       "eine AWTRIX kann mit unseren Pixeln nichts anfangen")
        XCTAssertTrue(neu.gesendet.first?.nutzlast.contains(#""text":"Grüße""#) == true)
    }

    /// **Ueber MQTT loeschen beide Gattungen gleich** — genau null Bytes. Nur
    /// das Thema wechselt.
    func testLoeschenIstAufBeidenGattungenDieLeereNutzlast() throws {
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

    // MARK: - Was auf einer AWTRIX nicht geht

    /// **Der Kern der Regel „die Oberflaeche sagt es, statt still zu
    /// scheitern".** Ein gemaltes Bild bringt keine Regler mit; auf 32×8
    /// gestaucht waere es nicht dasselbe Bild. Also wird nichts geschickt und
    /// gesagt, warum.
    func testEinGemaltesBildGehtNichtAnEineAwtrixUndSagtDas() {
        let sender = NGMitschreiber()
        let gemalt = Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 52, hoehe: 16, farbe: "#FF0000")])

        XCTAssertThrowsError(try ngKanal(sender).zeigen(gemalt, auf: "meldung1")) { fehler in
            guard case NGFehler.keinPixelweg = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
        }
        XCTAssertTrue(sender.gesendet.isEmpty, "es darf nichts abgeschickt worden sein")
    }

    /// Dasselbe Bild geht an die Werksfirmware unveraendert durch — die
    /// Gegenprobe, damit die Sperre oben nicht alles abweist.
    func testDasselbeBildGehtAnDieWerksfirmware() throws {
        let sender = NGMitschreiber()
        let gemalt = Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 52, hoehe: 16, farbe: "#FF0000")])
        try Anzeigen(sender: sender, zugang: zugang, praefix: "awtrix_a86b")
            .zeigen(gemalt, auf: "meldung1")
        XCTAssertEqual(sender.gesendet.count, 1)
    }

    // MARK: - Der Kanal einer Uhr

    /// `Anzeigen.fuer` ist die eine Stelle, an der aus einer `Uhr` ein Kanal
    /// wird — App, Werkzeug und Kurzbefehle rufen alle hierher. Die Gattung
    /// muss dabei mitkommen, sonst sendete das Werkzeug anders als die App.
    func testDieGattungDerUhrKommtInDenKanal() throws {
        let mqtt = Uhr(name: "a", host: "10.0.0.9", praefix: "wohnzimmer/uhr",
                       typ: .awtrixNG, betriebsart: .mqtt)
        XCTAssertEqual(try XCTUnwrap(Anzeigen.fuer(mqtt, brokerzugang: zugang)).gattung, .awtrixNG)

        let http = Uhr(name: "b", host: "10.0.0.9", typ: .awtrixNG, betriebsart: .http)
        XCTAssertEqual(try XCTUnwrap(Anzeigen.fuer(http, brokerzugang: nil)).gattung, .awtrixNG)

        // Und eine Uhr ohne eingetragene Art bleibt die Werksfirmware.
        let alt = Uhr(name: "c", host: "10.0.0.1", betriebsart: .http)
        XCTAssertEqual(try XCTUnwrap(Anzeigen.fuer(alt, brokerzugang: nil)).gattung, .tc002)
    }

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
