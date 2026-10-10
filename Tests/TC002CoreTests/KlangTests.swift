import XCTest
@testable import TC002Core

/// Prüfregeln, JSON-Bau und Fähigkeitssperren für Klang (§3.2.1, §5.6, §8) —
/// ohne Netz.
final class KlangTests: XCTestCase {
    private let melodie = "ping:d=4,o=5,b=120:c,e,g"

    private func wirft(_ erwartet: KlangFehler, _ tat: () throws -> Any,
                       datei: StaticString = #filePath, zeile: UInt = #line) {
        XCTAssertThrowsError(try tat(), file: datei, line: zeile) {
            XCTAssertEqual($0 as? KlangFehler, erwartet, file: datei, line: zeile)
        }
    }

    // MARK: - JSON

    func testEinzelnerKlangIstEinObjektMitQuellenschluessel() throws {
        XCTAssertEqual(try Klangbau.spielen([Klang(.datei("ding"))]), #"{"file":"ding"}"#)
        XCTAssertEqual(try Klangbau.spielen([Klang(.rtttl(melodie))]), #"{"rtttl":"ping:d=4,o=5,b=120:c,e,g"}"#)
        XCTAssertEqual(try Klangbau.spielen([Klang(.lied("Lied"))]), #"{"song":"Lied"}"#)
        XCTAssertEqual(try Klangbau.spielen([Klang(.sprache("Hallo Welt"))]), #"{"speech":"Hallo Welt"}"#)
        XCTAssertEqual(try Klangbau.spielen([Klang(.sender("Radio Beispiel"))]), #"{"station":"Radio Beispiel"}"#)
        XCTAssertEqual(try Klangbau.spielen([Klang(.senderPosition(0))]), #"{"station":0}"#)
        XCTAssertEqual(try Klangbau.spielen([Klang(.sender("http://example.com/stream"))]),
                       #"{"station":"http://example.com/stream"}"#, "Schrägstriche bleiben unmaskiert")
    }

    func testLoopSteht_nurWennGewiederholtWird() throws {
        XCTAssertEqual(try Klangbau.spielen([Klang(.datei("ding"), wiederholen: true)]),
                       #"{"file":"ding","loop":true}"#)
        XCTAssertEqual(try Klangbau.spielen([Klang(.sprache("a"), wiederholen: false)]), #"{"speech":"a"}"#)
    }

    func testListeVonEinsBisVier() throws {
        let zwei = [Klang(.datei("a")), Klang(.rtttl(melodie), wiederholen: true)]
        XCTAssertEqual(try Klangbau.spielen(zwei),
                       #"[{"file":"a"},{"rtttl":"ping:d=4,o=5,b=120:c,e,g","loop":true}]"#)
        let vier = Array(repeating: Klang(.datei("a")), count: 4)
        XCTAssertEqual(try Klangbau.spielen(vier), "[" + Array(repeating: #"{"file":"a"}"#, count: 4).joined(separator: ",") + "]")
        wirft(.ungueltigeAnzahl(0)) { try Klangbau.spielen([]) }
        wirft(.ungueltigeAnzahl(5)) { try Klangbau.spielen(Array(repeating: Klang(.datei("a")), count: 5)) }
    }

    func testAnfuehrungszeichenUndUmlauteWerdenMaskiertBzwBleiben() throws {
        XCTAssertEqual(try Klangbau.spielen([Klang(.sprache("Er sagte \"ja\" – Grüße"))]),
                       #"{"speech":"Er sagte \"ja\" – Grüße"}"#)
    }

    func testStoppen() {
        XCTAssertEqual(Klangbau.stoppen(.alarm), #"{"group":"alert"}"#)
        XCTAssertEqual(Klangbau.stoppen(.app), #"{"group":"app"}"#)
        XCTAssertEqual(Klangbau.stoppen(.radio), #"{"group":"radio"}"#)
        XCTAssertEqual(Klangbau.stoppen(nil), "{}")
        XCTAssertEqual(Tongruppe(wort: "Alarm"), .alarm)
        XCTAssertEqual(Tongruppe(wort: "alert"), .alarm)
        XCTAssertNil(Tongruppe(wort: "alles"))
    }

    func testSenderliste() throws {
        XCTAssertEqual(try Klangbau.sender([]), #"{"stations":[]}"#)
        XCTAssertEqual(try Klangbau.sender([Radiosender(name: "Eins", url: "http://example.com/a"),
                                            Radiosender(name: "Zwei", url: "https://example.com/b")]),
                       #"{"stations":[{"name":"Eins","url":"http://example.com/a"},{"name":"Zwei","url":"https://example.com/b"}]}"#)
    }

    func testMelodie() throws {
        XCTAssertEqual(try Klangbau.melodie(name: "ping", rtttl: melodie), #"{"rtttl":"ping:d=4,o=5,b=120:c,e,g"}"#)
    }

    func testBenachrichtigungstonAlsNameObjektOderListe() throws {
        XCTAssertEqual(try Klangbau.benachrichtigungston([Klang(.datei("ding"))]), #""ding""#)
        XCTAssertEqual(try Klangbau.benachrichtigungston([Klang(.datei("ding"), wiederholen: true)]),
                       #"{"file":"ding","loop":true}"#)
        XCTAssertEqual(try Klangbau.benachrichtigungston([Klang(.sprache("Post"))]), #"{"speech":"Post"}"#)
        XCTAssertEqual(try Klangbau.benachrichtigungston([Klang(.datei("a")), Klang(.rtttl(melodie))]),
                       #"[{"file":"a"},{"rtttl":"ping:d=4,o=5,b=120:c,e,g"}]"#)
    }

    func testBenachrichtigungMitTonImRichtigenFeld() throws {
        let rahmen = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x", weg: .text)))
        let o = Benachrichtigungsoptionen(name: "n", halten: false, einreihen: true, aufwecken: false,
                                          wiederholungen: nil, klang: [Klang(.datei("ding"))])
        let json = try NGNutzlast.benachrichtigung(rahmen, o)
        XCTAssertTrue(json.hasSuffix(#","name":"n","sound":"ding"}"#), json)
        let ohne = try NGNutzlast.benachrichtigung(rahmen, Benachrichtigungsoptionen(name: "n"))
        XCTAssertFalse(ohne.contains("sound"), "ohne Klang bleibt es stumm und unverändert")
    }

    func testBenachrichtigungsoptionenBleibenOhneKlangCodable() throws {
        var o = Benachrichtigungsoptionen(name: "n")
        o.klang = [Klang(.datei("ding"))]
        let daten = try JSONEncoder().encode(o)
        XCTAssertFalse(String(decoding: daten, as: UTF8.self).contains("klang"), "Der Ton gehört nicht zum Dateiformat")
        let zurueck = try JSONDecoder().decode(Benachrichtigungsoptionen.self, from: daten)
        XCTAssertEqual(zurueck.klang, [])
        XCTAssertEqual(zurueck.name, "n")
    }

    // MARK: - Prüfregeln

    func testLeereQuellenSindAbgewiesen() {
        wirft(.leer(feld: "file")) { try Klangbau.spielen([Klang(.datei(""))]) }
        wirft(.leer(feld: "rtttl")) { try Klangbau.spielen([Klang(.rtttl(""))]) }
        wirft(.leer(feld: "song")) { try Klangbau.spielen([Klang(.lied(""))]) }
        wirft(.leer(feld: "speech")) { try Klangbau.spielen([Klang(.sprache(""))]) }
        wirft(.leer(feld: "station")) { try Klangbau.spielen([Klang(.sender(""))]) }
    }

    func testGrenzeRTTTL_512Zeichen() throws {
        let kopf = "a:d=4:"
        let genau = kopf + String(repeating: "c", count: 512 - kopf.count)
        XCTAssertEqual(genau.count, 512)
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.rtttl(genau))]))
        wirft(.zuLang(feld: "rtttl", grenze: 512, einheit: lok("Zeichen"))) {
            try Klangbau.spielen([Klang(.rtttl(genau + "c"))])
        }
    }

    func testGrenzeSprechtext_512Byte() throws {
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.sprache(String(repeating: "a", count: 512)))]))
        wirft(.zuLang(feld: "speech", grenze: 512, einheit: "Byte")) {
            try Klangbau.spielen([Klang(.sprache(String(repeating: "a", count: 513)))])
        }
        // Umlaute zählen zwei Byte: 256 genügen, 257 sind zu viel.
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.sprache(String(repeating: "ä", count: 256)))]))
        wirft(.zuLang(feld: "speech", grenze: 512, einheit: "Byte")) {
            try Klangbau.spielen([Klang(.sprache(String(repeating: "ä", count: 257)))])
        }
    }

    func testGrenzeLiedUndDateiname() throws {
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.lied(String(repeating: "a", count: 16384)))]))
        wirft(.zuLang(feld: "song", grenze: 16384, einheit: "Byte")) {
            try Klangbau.spielen([Klang(.lied(String(repeating: "a", count: 16385)))])
        }
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.datei(String(repeating: "a", count: 512)))]))
        wirft(.zuLang(feld: "file", grenze: 512, einheit: lok("Zeichen"))) {
            try Klangbau.spielen([Klang(.datei(String(repeating: "a", count: 513)))])
        }
    }

    func testEndungImNamenIstAbgewiesen_eineAdresseDarfSieHaben() throws {
        wirft(.endungImNamen("ding.mp3")) { try Klangbau.spielen([Klang(.datei("ding.mp3"))]) }
        wirft(.endungImNamen("Ding.TXT")) { try Klangbau.spielen([Klang(.datei("Ding.TXT"))]) }
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.datei("http://example.com/ding.mp3"))]))
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.datei("Skript/ding"))]))
    }

    func testRTTTLMussDreiTeileHaben() {
        wirft(.unlesbareMelodie) { try Klangbau.spielen([Klang(.rtttl("nur Text"))]) }
        wirft(.unlesbareMelodie) { try Klangbau.spielen([Klang(.rtttl("a:d=4,o=5:"))]) }
    }

    func testLoopNichtMitSender() {
        wirft(.wiederholenMitSender) { try Klangbau.spielen([Klang(.sender("x"), wiederholen: true)]) }
        wirft(.wiederholenMitSender) { try Klangbau.spielen([Klang(.senderPosition(1), wiederholen: true)]) }
    }

    func testNegativePosition() {
        wirft(.negativePosition(-1)) { try Klangbau.spielen([Klang(.senderPosition(-1))]) }
    }

    func testBenachrichtigungKenntKeinLiedKeinenSender() {
        wirft(.nichtInBenachrichtigung(feld: "song")) { try Klangbau.benachrichtigungston([Klang(.lied("x"))]) }
        wirft(.nichtInBenachrichtigung(feld: "station")) { try Klangbau.benachrichtigungston([Klang(.sender("x"))]) }
        wirft(.nichtInBenachrichtigung(feld: "station")) { try Klangbau.benachrichtigungston([Klang(.senderPosition(1))]) }
        wirft(.ungueltigeAnzahl(5)) {
            try Klangbau.benachrichtigungston(Array(repeating: Klang(.datei("a")), count: 5))
        }
        // In einer Liste zählt jeder Klang.
        wirft(.nichtInBenachrichtigung(feld: "song")) {
            try Klangbau.benachrichtigungston([Klang(.datei("a")), Klang(.lied("x"))])
        }
    }

    func testMelodienamen_1Bis24Zeichen() throws {
        XCTAssertNoThrow(try Klangbau.melodie(name: "a", rtttl: melodie))
        XCTAssertNoThrow(try Klangbau.melodie(name: String(repeating: "a", count: 24), rtttl: melodie))
        wirft(.ungueltigerMelodiename("")) { try Klangbau.melodie(name: "", rtttl: melodie) }
        let zuLang = String(repeating: "a", count: 25)
        wirft(.ungueltigerMelodiename(zuLang)) { try Klangbau.melodie(name: zuLang, rtttl: melodie) }
        wirft(.ungueltigerMelodiename("a/b")) { try Klangbau.melodie(name: "a/b", rtttl: melodie) }
        wirft(.ungueltigerMelodiename("a.txt")) { try Klangbau.melodie(name: "a.txt", rtttl: melodie) }
        wirft(.leer(feld: "rtttl")) { try Klangbau.melodie(name: "a", rtttl: "") }
    }

    func testSenderGrenzen() throws {
        let gut = Radiosender(name: "N", url: "http://example.com/s")
        XCTAssertNoThrow(try Klangbau.sender(Array(repeating: gut, count: 32)))
        wirft(.zuvieleSender(33)) { try Klangbau.sender(Array(repeating: gut, count: 33)) }
        // Name 1–24 Zeichen.
        XCTAssertNoThrow(try Klangbau.sender([Radiosender(name: String(repeating: "n", count: 24), url: gut.url)]))
        wirft(.ungueltigerSender(zeile: 1, feld: "name")) {
            try Klangbau.sender([Radiosender(name: "", url: gut.url)])
        }
        wirft(.ungueltigerSender(zeile: 2, feld: "name")) {
            try Klangbau.sender([gut, Radiosender(name: String(repeating: "n", count: 25), url: gut.url)])
        }
        // Adresse: höchstens 255 Zeichen, mit http(s).
        let url255 = "http://example.com/" + String(repeating: "a", count: 255 - 19)
        XCTAssertEqual(url255.count, 255)
        XCTAssertNoThrow(try Klangbau.sender([Radiosender(name: "N", url: url255)]))
        wirft(.ungueltigerSender(zeile: 1, feld: "url")) {
            try Klangbau.sender([Radiosender(name: "N", url: url255 + "a")])
        }
        wirft(.ungueltigerSender(zeile: 1, feld: "url")) {
            try Klangbau.sender([Radiosender(name: "N", url: "ftp://example.com/x")])
        }
        wirft(.ungueltigerSender(zeile: 1, feld: "url")) {
            try Klangbau.sender([Radiosender(name: "N", url: "http://example.com/a b")])
        }
    }

    // MARK: - Fähigkeiten

    private func faehigkeiten(_ ton: Tonfaehigkeiten?) -> Geraetefaehigkeiten {
        Geraetefaehigkeiten(ton: ton)
    }

    func testFaehigkeitenAusDerAuskunft() throws {
        let antwort: [String: Any] = ["effects": ["Fade"],
                                      "audio": ["mp3": true, "rtttl": true, "song": false, "speech": true,
                                                "radio": false, "url": true, "effect": true, "clip": true,
                                                "track": false]]
        let f = try XCTUnwrap(Geraetefaehigkeiten(antwort: antwort))
        XCTAssertEqual(f.ton, Tonfaehigkeiten(mp3: true, rtttl: true, song: false, speech: true, radio: false,
                                              url: true, effect: true, clip: true, track: false))
        // Ohne `audio` kann die Uhr nichts davon.
        let alt = try XCTUnwrap(Geraetefaehigkeiten(antwort: ["effects": ["Fade"]]))
        XCTAssertEqual(alt.ton, Tonfaehigkeiten())
    }

    func testFaehigkeitssperren() {
        let nichts = faehigkeiten(Tonfaehigkeiten())
        wirft(.nichtGekonnt(faehigkeit: "audio.rtttl")) { try Klangbau.spielen([Klang(.rtttl(melodie))], faehigkeiten: nichts) }
        wirft(.nichtGekonnt(faehigkeit: "audio.song")) { try Klangbau.spielen([Klang(.lied("x"))], faehigkeiten: nichts) }
        wirft(.nichtGekonnt(faehigkeit: "audio.speech")) { try Klangbau.spielen([Klang(.sprache("x"))], faehigkeiten: nichts) }
        wirft(.nichtGekonnt(faehigkeit: "audio.radio")) { try Klangbau.spielen([Klang(.sender("x"))], faehigkeiten: nichts) }
        wirft(.nichtGekonnt(faehigkeit: "audio.radio")) { try Klangbau.spielen([Klang(.senderPosition(0))], faehigkeiten: nichts) }
        wirft(.nichtGekonnt(faehigkeit: "audio.url")) {
            try Klangbau.spielen([Klang(.datei("http://example.com/a.mp3"))], faehigkeiten: nichts)
        }
        wirft(.nichtGekonnt(faehigkeit: "audio.mp3")) { try Klangbau.spielen([Klang(.datei("ding"))], faehigkeiten: nichts) }
        wirft(.nichtGekonnt(faehigkeit: "audio.rtttl")) {
            try Klangbau.melodie(name: "a", rtttl: melodie, faehigkeiten: nichts)
        }
        // Ein Name kann auch eine Melodie sein: rtttl allein genügt.
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.datei("ding"))], faehigkeiten: faehigkeiten(Tonfaehigkeiten(rtttl: true))))
        // Der Benachrichtigungston prüft gleich.
        wirft(.nichtGekonnt(faehigkeit: "audio.speech")) {
            try Klangbau.benachrichtigungston([Klang(.sprache("x"))], faehigkeiten: nichts)
        }
        // Eine Liste: jeder Klang muss gekonnt sein.
        wirft(.nichtGekonnt(faehigkeit: "audio.song")) {
            try Klangbau.spielen([Klang(.datei("a")), Klang(.lied("x"))],
                                 faehigkeiten: faehigkeiten(Tonfaehigkeiten(mp3: true)))
        }
    }

    func testOhneAuskunftBleibtDieFaehigkeitUngeprueft() {
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.lied("x"))], faehigkeiten: nil))
        XCTAssertNoThrow(try Klangbau.spielen([Klang(.lied("x"))], faehigkeiten: faehigkeiten(nil)))
    }

    // MARK: - Lesen

    func testTonzustandAusDerAuskunft() throws {
        let antwort: [String: Any] = [
            "radio": ["playing": true, "station": "Eins", "title": "Lied", "error": ""],
            "app": ["playing": false, "name": "", "error": "x"],
            "alert": ["playing": true, "name": "ding", "error": ""],
            "stations": [["name": "Eins", "url": "http://example.com/a"]],
        ]
        let z = try XCTUnwrap(Tonzustand(antwort: antwort))
        XCTAssertEqual(z.radio, Tonzustand.Radio(spielt: true, sender: "Eins", titel: "Lied", fehler: ""),
                       "die Messfelder des Radios sind optional")
        let laufend = try XCTUnwrap(Tonzustand(antwort: ["radio": ["playing": true, "underruns": 2, "decodeUs": 5,
                                                                   "starvedMs": 0, "bufferBytes": 4096]]))
        XCTAssertEqual(laufend.radio.underruns, 2)
        XCTAssertEqual(laufend.radio.bufferBytes, 4096)
        XCTAssertEqual(z.app.fehler, "x")
        XCTAssertEqual(z.alarm, Tonzustand.Wiedergabe(spielt: true, name: "ding", fehler: ""))
        XCTAssertEqual(z.sender, [Radiosender(name: "Eins", url: "http://example.com/a")])
        XCTAssertNil(Tonzustand(antwort: ["version": "1"]), "das war keine Tonauskunft")
    }

    func testTonablageNimmtNamenAlsTextOderObjekt() {
        let a = Tonablage(antwort: ["melodies": ["a", ["name": "b", "size": 3]], "usedBytes": 10, "totalBytes": 100],
                          liste: "melodies")
        XCTAssertEqual(a.namen, ["a", "b"])
        XCTAssertEqual(a.belegteBytes, 10)
        XCTAssertEqual(a.gesamteBytes, 100)
    }
}
