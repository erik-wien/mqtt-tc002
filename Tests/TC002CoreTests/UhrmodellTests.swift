import XCTest
@testable import TC002Core

/// Das Uhrmodell, die Ausstattung der selbstgebauten ESP32-Uhr und was daraus
/// für die Fähigkeiten folgt (`docs/funktionen-je-uhr.md`). Die Antworten sind
/// die gemessenen vom 11. Oktober 2026 (NG 1.2.2) ohne Kennungen.
final class UhrmodellTests: XCTestCase {
    private func faehigkeiten(plattform: String, lichtsensor: Bool = true, rtttl: Bool = true,
                              mp3: Bool = false) throws -> Geraetefaehigkeiten {
        let text = """
        {"effects":["Fade"],"platform":{"id":"\(plattform)"},"sensors":{"light":\(lichtsensor)},
         "display":{"width":32,"height":8,"configurable":true,"minWidth":32,"maxWidth":128,"minHeight":8,"maxHeight":8},
         "audio":{"mp3":\(mp3),"rtttl":\(rtttl),"song":false,"speech":false,"track":false,
                  "radio":false,"url":false,"effect":false,"clip":false}}
        """
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        return try XCTUnwrap(Geraetefaehigkeiten(antwort: o))
    }

    private func zustand(_ json: String) throws -> Geraetezustand {
        try Geraetezustand(daten: Data(json.utf8))
    }

    /// Eine TC001: Akku mit 3,9 V, Fotowiderstand liest 281.
    private let tc001Zustand = #"{"boardType":"awtrixng","batteryVoltage":3.9,"batteryPercent":63,"ldrRaw":281}"#
    /// Eigenbau ohne Akku (offener Messpin), ohne Fotowiderstand, ohne Fühler.
    private let eigenbauZustand = #"{"boardType":"awtrixng","batteryVoltage":0.25,"batteryPercent":0,"ldrRaw":0}"#
    /// Eigenbau mit Fühler.
    private let eigenbauMitFuehler = #"{"batteryVoltage":0.25,"ldrRaw":0,"temperature":21.4,"humidity":37}"#

    // MARK: - Vorschlag

    func testVorschlagTC002() throws {
        XCTAssertEqual(Uhrmodell.vorschlag(faehigkeiten: try faehigkeiten(plattform: "tc002", lichtsensor: false),
                                           zustand: nil), .tc002)
    }

    func testVorschlagTC001HatAkkuUndLichtsensor() throws {
        let f = try faehigkeiten(plattform: "esp32")
        XCTAssertEqual(Uhrmodell.vorschlag(faehigkeiten: f, zustand: try zustand(tc001Zustand)), .tc001)
    }

    func testVorschlagJederAndereESP32IstEigenbau() throws {
        let f = try faehigkeiten(plattform: "esp32")
        // `sensors.light` ist auf jedem ESP32 true und entscheidet nichts.
        XCTAssertEqual(Uhrmodell.vorschlag(faehigkeiten: f, zustand: try zustand(eigenbauZustand)), .esp32DIY)
        // Mit Akku, aber ohne Fotowiderstand.
        let nurAkku = try zustand(#"{"batteryVoltage":3.9,"ldrRaw":0}"#)
        XCTAssertEqual(Uhrmodell.vorschlag(faehigkeiten: f, zustand: nurAkku), .esp32DIY)
        // Mit Fotowiderstand, aber ohne Akku.
        let nurLicht = try zustand(#"{"batteryVoltage":0.25,"ldrRaw":1454}"#)
        XCTAssertEqual(Uhrmodell.vorschlag(faehigkeiten: f, zustand: nurLicht), .esp32DIY)
    }

    func testVorschlagBleibtOffenWennDasNichtReicht() throws {
        let f = try faehigkeiten(plattform: "esp32")
        XCTAssertNil(Uhrmodell.vorschlag(faehigkeiten: f, zustand: nil), "Gerätezustand fehlt")
        XCTAssertNil(Uhrmodell.vorschlag(faehigkeiten: f, zustand: try zustand(#"{"batteryVoltage":3.9}"#)),
                     "ldrRaw fehlt")
        XCTAssertNil(Uhrmodell.vorschlag(faehigkeiten: try faehigkeiten(plattform: "unbekannt"),
                                         zustand: try zustand(tc001Zustand)))
        XCTAssertNil(Uhrmodell.vorschlag(faehigkeiten: nil, zustand: try zustand(tc001Zustand)))
    }

    // MARK: - Gerätezustand

    func testGeraetezustandLiestLdrUndFuehler() throws {
        let z = try zustand(eigenbauMitFuehler)
        XCTAssertEqual(z.ldrRoh, 0)
        XCTAssertEqual(z.temperatur, 21.4)
        XCTAssertEqual(z.feuchte, 37)
        let ohne = try zustand(eigenbauZustand)
        XCTAssertNil(ohne.temperatur)
        XCTAssertNil(ohne.feuchte)
        XCTAssertEqual(try zustand(tc001Zustand).ldrRoh, 281)
    }

    // MARK: - Ausstattung

    func testAusstattungDerEigenbauuhr() throws {
        let uhr = Uhr(name: "Bastel", host: "h", panelbreite: 64, panelhoehe: 8, modell: .esp32DIY)
        let a = Ausstattung(uhr: uhr, zustand: try zustand(eigenbauZustand),
                            faehigkeiten: try faehigkeiten(plattform: "esp32"))
        XCTAssertEqual(a.anzeige, Anzeigemass(breite: 64, hoehe: 8))
        XCTAssertEqual(a.akku, false)
        XCTAssertEqual(a.lichtsensor, false)
        XCTAssertEqual(a.temperatur, false)
        XCTAssertEqual(a.feuchte, false)
        XCTAssertEqual(a.mp3Player, false)
        let voll = Ausstattung(uhr: uhr, zustand: try zustand(#"{"batteryVoltage":3.9,"ldrRaw":900,"temperature":21.4,"humidity":37}"#),
                               faehigkeiten: try faehigkeiten(plattform: "esp32", mp3: true))
        XCTAssertEqual([voll.akku, voll.lichtsensor, voll.temperatur, voll.feuchte, voll.mp3Player],
                       [true, true, true, true, true])
        // Noch nichts abgefragt: unbekannt, nicht „nein“.
        let leer = Ausstattung(uhr: uhr, zustand: nil, faehigkeiten: nil)
        XCTAssertNil(leer.akku)
        XCTAssertNil(leer.mp3Player)
    }

    func testMP3PlayerBleibtDieAuskunftDerUhr() throws {
        // `audio.mp3` ist die Auskunft der Uhr; der Schalter wirkt auf `ton`.
        var uhr = Uhr(name: "x", host: "h", modell: .esp32DIY, lautsprecher: false)
        let f = try faehigkeiten(plattform: "esp32", mp3: true).mitAusstattung(fuer: uhr, zustand: nil)
        XCTAssertEqual(Ausstattung(uhr: uhr, zustand: nil, faehigkeiten: f).mp3Player, true)
        XCTAssertFalse(f.kann(.mp3))
        uhr.lautsprecher = nil
        XCTAssertTrue(f.mitAusstattung(fuer: uhr, zustand: nil).kann(.mp3))
    }

    // MARK: - Lautsprecher

    func testLautsprecherGiltNurFuerDieEigenbauuhr() {
        XCTAssertTrue(Uhr(name: "x", host: "h").hatLautsprecher)
        XCTAssertTrue(Uhr(name: "x", host: "h", modell: .esp32DIY).hatLautsprecher)
        XCTAssertFalse(Uhr(name: "x", host: "h", modell: .esp32DIY, lautsprecher: false).hatLautsprecher)
        XCTAssertTrue(Uhr(name: "x", host: "h", modell: .tc001, lautsprecher: false).hatLautsprecher,
                      "TC001 und TC002 haben einen festen Lautsprecher")
        XCTAssertTrue(Uhr(name: "x", host: "h", lautsprecher: false).hatLautsprecher, "Modell nicht bestimmt")
    }

    func testOhneLautsprecherKannDieUhrKeineKlangart() throws {
        let uhr = Uhr(name: "x", host: "h", modell: .esp32DIY, lautsprecher: false)
        let f = try faehigkeiten(plattform: "esp32").mitAusstattung(fuer: uhr, zustand: nil)
        for art in Klangart.allCases { XCTAssertFalse(f.kann(art), "\(art)") }
        XCTAssertEqual(f.ton, Tonfaehigkeiten())
        XCTAssertFalse(Klangeignung.mp3Hochladbar(f))
        XCTAssertFalse(Klangwahl(art: .uhr).gekonnt(von: f))
        XCTAssertFalse(Geraeteeinstellung.volume.wirkt(faehigkeiten: f))
        XCTAssertFalse(Geraeteeinstellung.bootSound.wirkt(faehigkeiten: f))
        XCTAssertTrue(Geraeteeinstellung.brightness.wirkt(faehigkeiten: f))
        // Mit Lautsprecher bleibt die Auskunft der Uhr, wie sie war.
        let mit = f.mitAusstattung(fuer: Uhr(name: "x", host: "h", modell: .esp32DIY), zustand: nil)
        XCTAssertTrue(mit.kann(.rtttl))
        XCTAssertTrue(Geraeteeinstellung.volume.wirkt(faehigkeiten: mit))
    }

    func testKeinKlangNurWennKeinZielEtwasKann() throws {
        let stumm = try faehigkeiten(plattform: "esp32")
            .mitAusstattung(fuer: Uhr(name: "x", host: "h", modell: .esp32DIY, lautsprecher: false), zustand: nil)
        let laut = try faehigkeiten(plattform: "esp32")
        let a = Klangziel(id: UUID(), name: "Stumm", faehigkeiten: stumm)
        let b = Klangziel(id: UUID(), name: "Laut", faehigkeiten: laut)
        XCTAssertTrue(Klangeignung.keinKlang(in: [a]))
        XCTAssertFalse(Klangeignung.keinKlang(in: [a, b]), "mehrere Ziele: bleibt, wenn eines es kann")
        XCTAssertFalse(Klangeignung.keinKlang(in: [Klangziel(id: UUID(), name: "Unbekannt")]))
        XCTAssertFalse(Klangeignung.keinKlang(in: []))
        // Der Klang geht nur an die Uhr, die ihn spielt.
        let klang = Klang(.rtttl("ping:d=4,o=5,b=120:c"))
        let v = Klangeignung.verteilen([klang], an: [a, b])
        XCTAssertEqual(v.klaenge[a.id], [])
        XCTAssertEqual(v.klaenge[b.id], [klang])
        XCTAssertEqual(v.uebersprungeneNamen, ["Stumm"])
    }

    // MARK: - Lichtsensor

    func testLdrNullMeintBeimEigenbauKeinenLichtsensor() throws {
        let f = try faehigkeiten(plattform: "esp32")
        XCTAssertTrue(f.lichtsensor, "die Fähigkeit meldet auf jedem ESP32 true")
        let diy = Uhr(name: "x", host: "h", modell: .esp32DIY)
        let ohne = f.mitAusstattung(fuer: diy, zustand: try zustand(eigenbauZustand))
        XCTAssertFalse(ohne.lichtsensor)
        XCTAssertFalse(Geraeteeinstellung.autoBrightness.wirkt(faehigkeiten: ohne))
        let mit = f.mitAusstattung(fuer: diy, zustand: try zustand(#"{"ldrRaw":1454}"#))
        XCTAssertTrue(mit.lichtsensor)
        // Ohne Auskunft über den Zustand bleibt die Fähigkeit stehen.
        XCTAssertTrue(f.mitAusstattung(fuer: diy, zustand: nil).lichtsensor)
        // Ein späterer Wert über 0 hebt die Sperre wieder auf.
        XCTAssertTrue(ohne.mitAusstattung(fuer: diy, zustand: try zustand(#"{"ldrRaw":5}"#)).lichtsensor)
    }

    func testBeiDerTC001GiltLdrNullNicht() throws {
        // Ein echter Sensor in völliger Dunkelheit könnte 0 lesen.
        let f = try faehigkeiten(plattform: "esp32")
        let tc001 = Uhr(name: "x", host: "h", modell: .tc001)
        XCTAssertTrue(f.mitAusstattung(fuer: tc001, zustand: try zustand(#"{"ldrRaw":0}"#)).lichtsensor)
    }

    // MARK: - Dateiformat

    func testAlteUhrOhneNeueFelderBleibtLesbar() throws {
        let alt = #"[{"id":"7C1B3F4E-0000-4000-8000-000000000001","name":"Küche","host":"h","praefix":"p","mac":"","einrichtung":2}]"#
        let uhr = try JSONDecoder().decode([Uhr].self, from: Data(alt.utf8))[0]
        XCTAssertNil(uhr.modell)
        XCTAssertNil(uhr.lautsprecher)
        XCTAssertNil(uhr.klangAbgleich)
        XCTAssertTrue(uhr.hatLautsprecher)
        XCTAssertTrue(uhr.gleichtKlaengeAb)
        // Nil wird nicht geschrieben: Eine ältere Fassung liest die Datei weiter.
        let geschrieben = String(decoding: try JSONEncoder().encode(uhr), as: UTF8.self)
        XCTAssertFalse(geschrieben.contains("modell"))
        XCTAssertFalse(geschrieben.contains("lautsprecher"))
        XCTAssertFalse(geschrieben.contains("klangAbgleich"))
    }

    func testNeueFelderUeberstehenDieDatei() throws {
        let uhr = Uhr(name: "Bastel", host: "h", modell: .esp32DIY, lautsprecher: false, klangAbgleich: false)
        let zurueck = try JSONDecoder().decode(Uhr.self, from: try JSONEncoder().encode(uhr))
        XCTAssertEqual(zurueck.modell, .esp32DIY)
        XCTAssertEqual(zurueck.lautsprecher, false)
        XCTAssertEqual(zurueck.klangAbgleich, false)
        XCTAssertFalse(zurueck.gleichtKlaengeAb)
    }

    func testEinUnbekanntesModellMachtDieListeNichtUnlesbar() throws {
        let neu = #"[{"id":"7C1B3F4E-0000-4000-8000-000000000001","name":"x","host":"h","modell":"zukunft"}]"#
        let uhr = try JSONDecoder().decode([Uhr].self, from: Data(neu.utf8))[0]
        XCTAssertNil(uhr.modell)
    }

    func testKlangAbgleichBrauchtLautsprecherUndWahl() {
        XCTAssertTrue(Uhr(name: "x", host: "h").gleichtKlaengeAb)
        XCTAssertFalse(Uhr(name: "x", host: "h", klangAbgleich: false).gleichtKlaengeAb)
        XCTAssertFalse(Uhr(name: "x", host: "h", modell: .esp32DIY, lautsprecher: false).gleichtKlaengeAb)
    }
}
