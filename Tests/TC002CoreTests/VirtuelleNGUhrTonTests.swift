import XCTest
@testable import TC002Core

/// Die Audio-Routen der virtuellen NG-Uhr als reine Funktion: Fehlercodes nach
/// §3.2.1, §8 und §12, und was sie sich vom Spielen merkt.
final class VirtuelleNGUhrTonTests: XCTestCase {
    private let json = ["content-type": "application/json"]

    private struct Ergebnis {
        var status: Int
        var wert: JSONWert
        var objekt: [String: JSONWert] { if case .objekt(let o) = wert { return o }; return [:] }
        var fehler: [String: JSONWert] { if case .objekt(let o)? = objekt["error"] { return o }; return [:] }
    }

    private func senden(_ methode: String, _ pfad: String, _ z: inout NGUhrzustand) -> Ergebnis {
        senden(methode, pfad, "", &z)
    }

    private func senden(_ methode: String, _ pfad: String, _ rumpf: String,
                        _ z: inout NGUhrzustand) -> Ergebnis {
        let a = Virtuelleuhr.Anfrage(methode, "/api/v1" + pfad, koerper: Data(rumpf.utf8), kopf: json)
        let r = VirtuelleNGUhr.beantworten(a, &z)
        return Ergebnis(status: r.status, wert: JSONWert.lesen(r.koerper) ?? .null)
    }

    private func abgewiesen(_ e: Ergebnis, _ status: Int, _ code: String, feld: String? = nil,
                            meldung: String? = nil,
                            datei: StaticString = #filePath, zeile: UInt = #line) {
        if let meldung { XCTAssertEqual(e.fehler["message"], .text(meldung), file: datei, line: zeile) }
        XCTAssertEqual(e.status, status, file: datei, line: zeile)
        XCTAssertEqual(e.fehler["code"], .text(code), file: datei, line: zeile)
        XCTAssertEqual(e.fehler["field"], feld.map { .text($0) }, file: datei, line: zeile)
    }

    private let ok = JSONWert.objekt(["ok": .bool(true)])

    private func zustand() -> NGUhrzustand {
        var z = NGUhrzustand()
        z.ton.melodien["ping"] = "ping:d=4,o=5,b=120:c"
        z.ton.mp3 = ["ding"]
        return z
    }

    // MARK: - audio/play

    func testSpieltEineDateiUndMerktSichDenKlang() {
        var z = zustand()
        let e = senden("POST", "/audio/play", #"{"file":"ding","loop":true}"#, &z)
        XCTAssertEqual(e.status, 200)
        XCTAssertEqual(e.wert, ok)
        XCTAssertEqual(z.ton.gespielt, [.objekt(["file": .text("ding"), "loop": .bool(true)])])
        XCTAssertEqual(z.ton.alarm, NGTon.Wiedergabe(spielt: true, name: "ding"))
        XCTAssertEqual(senden("GET", "/audio", &z).objekt["alert"],
                       .objekt(["playing": .bool(true), "name": .text("ding"), "error": .text("")]))
    }

    func testEinNameIstDieMelodieOderDieMP3_eineBlankeZeichenketteIstDatei() {
        var z = zustand()
        XCTAssertEqual(senden("POST", "/audio/play", #"{"file":"ping"}"#, &z).status, 200)
        XCTAssertEqual(senden("POST", "/audio/play", #""ding""#, &z).status, 200)
        XCTAssertEqual(z.ton.gespielt.count, 2)
    }

    func testFehlendeDateiIst404() {
        var z = zustand()
        abgewiesen(senden("POST", "/audio/play", #"{"file":"gibtsnicht"}"#, &z), 404, "notFound",
                   meldung: #"nothing called "gibtsnicht""#)
        XCTAssertTrue(z.ton.gespielt.isEmpty)
    }

    func testZweiSchluesselUndKeinSchluesselSind422() {
        var z = zustand()
        // Gemessen: das Feld ist der erste Schlüssel.
        abgewiesen(senden("POST", "/audio/play", #"{"rtttl":"a:b:c","speech":"x"}"#, &z), 422, "validationFailed",
                   feld: "rtttl", meldung: "one sound key only")
        abgewiesen(senden("POST", "/audio/play", #"{"loop":true}"#, &z), 422, "validationFailed")
        abgewiesen(senden("POST", "/audio/play", #"{"sound":"x"}"#, &z), 422, "validationFailed", feld: "sound")
    }

    func testEndungImNamenUndUnlesbareMelodieSind422() {
        var z = zustand()
        abgewiesen(senden("POST", "/audio/play", #"{"file":"ding.mp3"}"#, &z), 422, "validationFailed", feld: "file",
                   meldung: "invalid name")
        abgewiesen(senden("POST", "/audio/play", #"{"file":"ping.txt"}"#, &z), 422, "validationFailed", feld: "file")
        abgewiesen(senden("POST", "/audio/play", #"{"rtttl":"kaputt"}"#, &z), 422, "validationFailed", feld: "rtttl")
        XCTAssertEqual(senden("POST", "/audio/play", #"{"file":"http://example.com/x.mp3"}"#, &z).status, 200,
                       "eine Adresse darf die Endung haben")
    }

    func testGrenzenRTTTLSprechtextLied() {
        var z = zustand()
        let kopf = "a:d=4:"
        let genau = kopf + String(repeating: "c", count: 512 - kopf.count)
        XCTAssertEqual(senden("POST", "/audio/play", #"{"rtttl":"\#(genau)"}"#, &z).status, 200)
        abgewiesen(senden("POST", "/audio/play", #"{"rtttl":"\#(genau)c"}"#, &z), 422, "validationFailed", feld: "rtttl")
        XCTAssertEqual(senden("POST", "/audio/play", #"{"speech":"\#(String(repeating: "a", count: 512))"}"#, &z).status, 200)
        abgewiesen(senden("POST", "/audio/play", #"{"speech":"\#(String(repeating: "a", count: 513))"}"#, &z),
                   422, "validationFailed", feld: "speech", meldung: "must be 1..512 bytes")
        abgewiesen(senden("POST", "/audio/play", #"{"speech":""}"#, &z), 422, "validationFailed", feld: "speech")
        XCTAssertEqual(senden("POST", "/audio/play", #"{"song":"\#(String(repeating: "a", count: 16384))"}"#, &z).status, 200)
        abgewiesen(senden("POST", "/audio/play", #"{"song":"\#(String(repeating: "a", count: 16385))"}"#, &z),
                   422, "validationFailed", feld: "song")
    }

    func testLoopMitStationIst422() {
        var z = zustand()
        abgewiesen(senden("POST", "/audio/play", #"{"station":"Fm4","loop":true}"#, &z), 422, "validationFailed", feld: "loop",
                   meldung: "not with station")
        abgewiesen(senden("POST", "/audio/play", #"{"file":"ding","loop":"ja"}"#, &z), 422, "validationFailed", feld: "loop")
    }

    func testListeVonEinsBisVierSpieltDenErstenSpielbaren() {
        var z = zustand()
        let e = senden("POST", "/audio/play", #"[{"file":"gibtsnicht"},{"file":"ding"},{"file":"ping"}]"#, &z)
        XCTAssertEqual(e.status, 200)
        XCTAssertEqual(z.ton.gespielt, [.objekt(["file": .text("ding")])])
        abgewiesen(senden("POST", "/audio/play", "[]", &z), 422, "validationFailed", meldung: "must have 1 to 4 entries")
        abgewiesen(senden("POST", "/audio/play", #"[{"file":"a"},{"file":"a"},{"file":"a"},{"file":"a"},{"file":"a"}]"#, &z),
                   422, "validationFailed")
        // Der falsch gebaute Klang in der Liste wird mit seiner Stelle benannt.
        abgewiesen(senden("POST", "/audio/play", #"[{"file":"ding"},{"file":"x.mp3"}]"#, &z),
                   422, "validationFailed", feld: "[2].file")
    }

    func testStationNachNamePositionOderAdresse() {
        var z = zustand()
        XCTAssertEqual(senden("POST", "/audio/play", #"{"station":"fm4"}"#, &z).status, 200)
        XCTAssertEqual(z.ton.radio, NGTon.Wiedergabe(spielt: true, name: "Fm4"))
        XCTAssertEqual(senden("POST", "/audio/play", #"{"station":0}"#, &z).status, 200)
        XCTAssertEqual(senden("POST", "/audio/play", #"{"station":"http://example.com/s"}"#, &z).status, 200)
        abgewiesen(senden("POST", "/audio/play", #"{"station":7}"#, &z), 404, "notFound")
        abgewiesen(senden("POST", "/audio/play", #"{"station":"Unbekannt"}"#, &z), 404, "notFound")
    }

    func testOhneAusgangIst503() {
        var z = zustand()
        z.ton.ohneAusgabe = true
        abgewiesen(senden("POST", "/audio/play", #"{"file":"ding"}"#, &z), 503, "unavailable")
        // Erst wird der Klang geprüft, dann der Ausgang.
        abgewiesen(senden("POST", "/audio/play", #"{"file":"ding","rtttl":"a:b:c"}"#, &z), 422, "validationFailed", feld: "file")
    }

    func testFalscheMethodeIst405() {
        var z = zustand()
        abgewiesen(senden("GET", "/audio/play", &z), 405, "methodNotAllowed")
        abgewiesen(senden("PUT", "/audio/stop", &z), 405, "methodNotAllowed")
    }

    func testKaputtesJSONIst400() {
        var z = zustand()
        abgewiesen(senden("POST", "/audio/play", "{kaputt", &z), 400, "invalidJson")
    }

    // MARK: - audio/stop

    func testStoppGruppeUndAlles() {
        var z = zustand()
        _ = senden("POST", "/audio/play", #"{"file":"ding"}"#, &z)
        _ = senden("POST", "/audio/play", #"{"station":"Fm4"}"#, &z)
        XCTAssertEqual(senden("POST", "/audio/stop", #"{"group":"radio"}"#, &z).wert, ok)
        XCTAssertFalse(z.ton.radio.spielt)
        XCTAssertTrue(z.ton.alarm.spielt, "nur die Gruppe wird angehalten")
        XCTAssertEqual(senden("POST", "/audio/stop", &z).wert, ok, "leer = alles")
        XCTAssertFalse(z.ton.alarm.spielt)
        XCTAssertEqual(senden("POST", "/audio/stop", "{}", &z).wert, ok)
        XCTAssertEqual(z.ton.gestoppt, ["radio", "all", "all"])
    }

    func testStoppMitUnbekannterGruppeIst422() {
        var z = zustand()
        abgewiesen(senden("POST", "/audio/stop", #"{"group":"alles"}"#, &z), 422, "validationFailed", feld: "group",
                   meldung: "must be alert, app or radio")
        abgewiesen(senden("POST", "/audio/stop", #"{"scope":"all"}"#, &z), 422, "validationFailed", feld: "scope")
    }

    func testZustandMeldetDieMessfelderDesRadios() {
        var z = zustand()
        _ = senden("POST", "/audio/play", #"{"station":"Fm4"}"#, &z)
        let radio = senden("GET", "/audio", &z).objekt["radio"]
        guard case .objekt(let r)? = radio else { return XCTFail("kein radio") }
        XCTAssertEqual(r["playing"], .bool(true))
        for k in ["underruns", "decodeUs", "starvedMs", "bufferBytes", "station", "title", "error"] {
            XCTAssertNotNil(r[k], k)
        }
    }

    // MARK: - Melodien

    func testMelodieNeuErsetztLoescht() {
        var z = NGUhrzustand()
        XCTAssertEqual(senden("PUT", "/audio/melodies/neu", #"{"rtttl":"a:d=4:c"}"#, &z).status, 201)
        XCTAssertEqual(senden("PUT", "/audio/melodies/neu", #"{"rtttl":"a:d=4:d"}"#, &z).status, 200)
        XCTAssertEqual(z.ton.melodien["neu"], "a:d=4:d")
        let liste = senden("GET", "/audio/melodies", &z)
        XCTAssertEqual(liste.objekt["melodies"], .liste([.objekt(["name": .text("neu"), "size": .zahl(7)])]))
        XCTAssertEqual(senden("DELETE", "/audio/melodies/neu", &z).wert, ok)
        abgewiesen(senden("DELETE", "/audio/melodies/neu", &z), 404, "notFound")
    }

    func testMelodiegrenzen() {
        var z = NGUhrzustand()
        let name24 = String(repeating: "a", count: 24)
        XCTAssertEqual(senden("PUT", "/audio/melodies/\(name24)", #"{"rtttl":"a:d=4:c"}"#, &z).status, 201)
        abgewiesen(senden("PUT", "/audio/melodies/\(name24)b", #"{"rtttl":"a:d=4:c"}"#, &z), 422, "validationFailed", feld: "name")
        abgewiesen(senden("PUT", "/audio/melodies/x", #"{"rtttl":"kaputt"}"#, &z), 422, "validationFailed", feld: "rtttl")
        abgewiesen(senden("PUT", "/audio/melodies/x", "{}", &z), 422, "validationFailed", feld: "rtttl")
        let lang = "a:d=4:" + String(repeating: "c", count: 507)
        abgewiesen(senden("PUT", "/audio/melodies/x", #"{"rtttl":"\#(lang)"}"#, &z), 422, "validationFailed", feld: "rtttl")
    }

    func testNameGemeinsamMitMP3Eindeutig() {
        var z = zustand()
        abgewiesen(senden("PUT", "/audio/melodies/ding", #"{"rtttl":"a:d=4:c"}"#, &z), 409, "nameTaken")
    }

    func testMelodienUndMP3Listen() {
        var z = zustand()
        XCTAssertEqual(senden("GET", "/audio/melodies", &z).objekt["melodies"],
                       .liste([.objekt(["name": .text("ping"), "size": .zahl(20)])]))
        XCTAssertEqual(senden("GET", "/audio/mp3", &z).objekt["files"], .liste([.objekt(["name": .text("ding")])]))
    }

    // MARK: - Sender

    func testSenderlisteErsetzen() {
        var z = NGUhrzustand()
        XCTAssertEqual(senden("GET", "/audio/stations", &z).objekt["stations"]?.liste?.count, 1)
        let rumpf = #"{"stations":[{"name":"Eins","url":"http://example.com/a"},{"name":"Zwei","url":"https://example.com/b"}]}"#
        XCTAssertEqual(senden("PUT", "/audio/stations", rumpf, &z).wert, ok)
        XCTAssertEqual(z.ton.sender, [Radiosender(name: "Eins", url: "http://example.com/a"),
                                      Radiosender(name: "Zwei", url: "https://example.com/b")])
        XCTAssertEqual(senden("PUT", "/audio/stations", #"{"stations":[]}"#, &z).wert, ok)
        XCTAssertTrue(z.ton.sender.isEmpty)
        XCTAssertEqual(senden("PUT", "/audio/stations", #"[{"name":"A","url":"http://example.com/a"}]"#, &z).wert, ok,
                       "auch das blanke Feld")
    }

    func testSenderGrenzenWerdenMitDerZeileBenannt() {
        var z = NGUhrzustand()
        let gut = #"{"name":"N","url":"http://example.com/s"}"#
        let zuViele = "[" + Array(repeating: gut, count: 33).joined(separator: ",") + "]"
        abgewiesen(senden("PUT", "/audio/stations", #"{"stations":\#(zuViele)}"#, &z), 422, "validationFailed", feld: "stations")
        let genau = "[" + Array(repeating: gut, count: 32).joined(separator: ",") + "]"
        XCTAssertEqual(senden("PUT", "/audio/stations", #"{"stations":\#(genau)}"#, &z).status, 200)
        abgewiesen(senden("PUT", "/audio/stations", #"{"stations":[\#(gut),{"name":"","url":"http://example.com/s"}]}"#, &z),
                   422, "validationFailed", feld: "stations[1].name")
        abgewiesen(senden("PUT", "/audio/stations", #"{"stations":[{"name":"N","url":"ftp://example.com/s"}]}"#, &z),
                   422, "validationFailed", feld: "stations[0].url")
        XCTAssertEqual(z.ton.sender.count, 32, "abgewiesen heißt: nichts geändert")
    }

    // MARK: - Benachrichtigungston

    func testBenachrichtigungMitTon() {
        var z = zustand()
        XCTAssertEqual(senden("POST", "/notifications", #"{"text":"x","sound":"ding"}"#, &z).status, 200)
        XCTAssertEqual(senden("POST", "/notifications", #"{"text":"x","sound":{"rtttl":"a:d=4:c","loop":true}}"#, &z).status, 200)
        XCTAssertEqual(senden("POST", "/notifications", #"{"text":"x","sound":[{"file":"a"},{"speech":"hi"}]}"#, &z).status, 200)
        XCTAssertEqual(senden("POST", "/notifications", #"{"text":"x","sound":""}"#, &z).status, 200)
        XCTAssertEqual(senden("POST", "/notifications", #"{"text":"x","sound":null}"#, &z).status, 200)
        XCTAssertEqual(senden("POST", "/notifications", #"{"text":"x","sound":"gibtsnicht"}"#, &z).status, 200,
                       "ein nicht gespeicherter Klang ist kein Fehler: die Benachrichtigung erscheint stumm")
        XCTAssertEqual(z.benachrichtigungen.count, 6)
        XCTAssertEqual(z.benachrichtigungen[0].nutzlast["sound"], .text("ding"))
    }

    func testFalscherBenachrichtigungstonIst422MitStelle() {
        var z = zustand()
        abgewiesen(senden("POST", "/notifications", #"{"text":"x","sound":{"station":"Fm4"}}"#, &z),
                   422, "validationFailed", feld: "sound.station")
        abgewiesen(senden("POST", "/notifications", #"{"text":"x","sound":{"song":"x"}}"#, &z),
                   422, "validationFailed", feld: "sound.song")
        abgewiesen(senden("POST", "/notifications", #"{"text":"x","sound":{"file":"a","rtttl":"a:b:c"}}"#, &z),
                   422, "validationFailed", feld: "sound.file")
        abgewiesen(senden("POST", "/notifications", #"{"text":"x","sound":[{"file":"a"},{"file":"b.mp3"}]}"#, &z),
                   422, "validationFailed", feld: "sound[2].file")
        abgewiesen(senden("POST", "/notifications", #"{"text":"x","sound":[]}"#, &z), 422, "validationFailed", feld: "sound")
        abgewiesen(senden("POST", "/notifications", #"{"text":"x","sound":5}"#, &z), 422, "validationFailed", feld: "sound")
        XCTAssertTrue(z.benachrichtigungen.isEmpty, "nichts eingereiht")
    }

    func testEineAnzeigeKenntKeinenTon() {
        var z = zustand()
        abgewiesen(senden("PUT", "/apps/pushed/x", #"{"text":"x","sound":"ding"}"#, &z), 422, "validationFailed", feld: "sound")
    }

    func testNichtNachgebildeteRoutenSindUnbekannt() {
        var z = zustand()
        abgewiesen(senden("POST", "/audio/clip", &z), 404, "notFound")
    }
}

private extension JSONWert {
    var liste: [JSONWert]? { if case .liste(let l) = self { return l }; return nil }
}
