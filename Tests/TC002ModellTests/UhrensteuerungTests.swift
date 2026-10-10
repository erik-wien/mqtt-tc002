import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Der Zustand und die Befehle der Steuerung im `AppZustand`. Die Uhr ist die
/// virtuelle auf `127.0.0.1` (HTTP) bzw. eine von Hand gefüllte Meldung (MQTT);
/// nichts verlässt den Rechner, der Schlüsselbund wird nie angefasst.
@MainActor
final class UhrensteuerungTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn"]
    private var sicherung: [String: Any?] = [:]
    private var schluesselbund = Schluesselbunddoppelgaenger()
    private var server: Uhrenserver?

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        schluesselbund = Schluesselbunddoppelgaenger()
    }

    override func tearDown() {
        server?.beenden()
        server = nil
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func zustand(mit uhren: [Uhr]) throws -> AppZustand {
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(uhren[0].id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set(uhren.map(\.id))), forKey: "zielIDs")
        return AppZustand(schluesselbund: schluesselbund)
    }

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    /// Eine HTTP-Uhr an einer virtuellen Uhr.
    private func httpUhr() throws -> (AppZustand, Uhr, Uhrenserver) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()
                server = s
                let uhr = Uhr(name: "Küche", host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
                return (try zustand(mit: [uhr]), uhr, s)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func mqttUhr() throws -> (AppZustand, Uhr) {
        let uhr = Uhr(name: "Wohnzimmer", host: "10.0.0.9", praefix: "wz/uhr", betriebsart: .mqtt)
        return (try zustand(mit: [uhr]), uhr)
    }

    private func gemeldet(_ z: AppZustand, _ uhr: Uhr, _ thema: String, _ nutzlast: String) {
        z.gemeldet(thema: "wz/uhr/" + thema, nutzlast: Data(nutzlast.utf8), fuer: uhr.id,
                   gedaechtnis: Slotgedaechtnis(ordner: temp()))
    }

    // MARK: - Abfragen

    func testZustandAbfragenFuelltAllesUndMachtErreichbar() async throws {
        let (z, uhr, _) = try httpUhr()
        z.faehigkeiten[uhr.id] = Geraetefaehigkeiten(mqttTlsUnterstuetzt: true)
        let ok = await z.zustandAbfragen(uhr.id)
        XCTAssertTrue(ok)
        XCTAssertEqual(z.erreichbar[uhr.id], true)
        XCTAssertEqual(z.geraetezustand[uhr.id]?.fassung, "1.2.2")
        XCTAssertEqual(z.aktiveAnzeige[uhr.id], "Time")
        XCTAssertEqual(z.anzeigestand[uhr.id]?.an, true)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.ganzzahl(.brightness), 128)
        XCTAssertEqual(z.tlsStatus[uhr.id]?.oeffentlich, true)
    }

    /// Ohne `capabilities.mqttTls` wird `/mqtt/tls` nicht gefragt (sonst `404`).
    func testOhneTLSFaehigkeitBleibtDerTLSStandLeer() async throws {
        let (z, uhr, _) = try httpUhr()
        z.faehigkeiten[uhr.id] = Geraetefaehigkeiten()
        await z.zustandAbfragen(uhr.id)
        XCTAssertNil(z.tlsStatus[uhr.id])
        XCTAssertNotNil(z.geraetezustand[uhr.id])
    }

    func testEineStummeUhrIstUnerreichbarOhneFehlerleiste() async throws {
        let (z, uhr, s) = try httpUhr()
        s.beenden()
        let ok = await z.zustandAbfragen(uhr.id)
        XCTAssertFalse(ok)
        XCTAssertEqual(z.erreichbar[uhr.id], false)
        XCTAssertNil(z.fehler, "kein Fenster vor den Rest der App")
        XCTAssertNil(z.geraetezustand[uhr.id])
    }

    func testOhneAdresseGibtEsNichtsZuFragen() async throws {
        let uhr = Uhr(name: "X", host: "", praefix: "wz/uhr", betriebsart: .mqtt)
        let z = try zustand(mit: [uhr])
        let ok = await z.zustandAbfragen(uhr.id)
        XCTAssertFalse(ok)
    }

    // MARK: - Helligkeit je Uhr, Lichtsensor

    private var weitereServer: [Uhrenserver] = []

    /// Zwei HTTP-Uhren an zwei virtuellen Uhren: die erste wie die TC002 (ohne
    /// Sensor, Helligkeit 128), die zweite wie die TC001 (Sensor, Automatik an).
    private func zweiUhren() throws -> (AppZustand, Uhr, Uhr) {
        var uhren: [Uhr] = []
        for (name, sensor) in [("Küche", false), ("Vorzimmer", true)] {
            var start = NGUhrzustand()
            start.lichtsensor = sensor
            start.einstellungen["autoBrightness"] = .bool(sensor)
            var gestartet = false
            for _ in 0..<20 where !gestartet {
                let port = UInt16.random(in: 20_000...60_000)
                let s = Uhrenserver(port: port, zustand: start)
                do {
                    try s.starten()
                    weitereServer.append(s)
                    uhren.append(Uhr(name: name, host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http))
                    gestartet = true
                } catch { continue }
            }
            if !gestartet { throw XCTSkip("kein freier Port") }
        }
        addTeardownBlock { [weitereServer] in weitereServer.forEach { $0.beenden() } }
        return (try zustand(mit: uhren), uhren[0], uhren[1])
    }

    /// Die Fernbedienung liest den Regler je Uhr aus dem Zustand dieser Uhr:
    /// Was von der einen gelesen ist, steht nie für die andere da.
    func testPanelhelligkeitGiltJeUhr() async throws {
        let (z, a, b) = try zweiUhren()
        XCTAssertNil(z.panelhelligkeit(fuer: a.id), "nichts gelesen, kein erfundener Wert")
        await z.zustandAbfragen(a.id)
        XCTAssertEqual(z.panelhelligkeit(fuer: a.id), 128)
        XCTAssertNil(z.panelhelligkeit(fuer: b.id), "die andere Uhr ist noch nicht gelesen")
        await z.zustandAbfragen(b.id)
        XCTAssertEqual(z.panelhelligkeit(fuer: b.id), 32, "das Panel der TC001 folgt dem Sensor")
        XCTAssertEqual(z.panelhelligkeit(fuer: a.id), 128)
        z.uhrAnsehen(b.id)
        XCTAssertEqual(z.panelhelligkeit(fuer: z.referenzUhr!.id), 32)
    }

    func testFaehigkeitenKommenMitDemZustandUndZeigenDenSensor() async throws {
        let (z, a, b) = try zweiUhren()
        await z.zustandAbfragen(a.id)
        await z.zustandAbfragen(b.id)
        XCTAssertEqual(z.faehigkeiten[a.id]?.lichtsensor, false)
        XCTAssertEqual(z.faehigkeiten[b.id]?.lichtsensor, true)
        XCTAssertFalse(z.helligkeitAutomatisch(fuer: a.id))
        XCTAssertTrue(z.helligkeitAutomatisch(fuer: b.id))
    }

    func testAutomatikUmschaltenSchaltetDenReglerFrei() async throws {
        let (z, _, b) = try zweiUhren()
        await z.zustandAbfragen(b.id)
        _ = await z.helligkeitSetzen(200, fuer: b.id)
        XCTAssertEqual(z.uhreneinstellungen[b.id]?.ganzzahl(.brightness), 200)
        XCTAssertEqual(z.panelhelligkeit(fuer: b.id), 32, "mit Automatik bleibt das Panel beim Sensor")
        XCTAssertTrue(z.helligkeitAutomatisch(fuer: b.id))

        let aus = await z.helligkeitAutomatikSetzen(false, fuer: b.id)
        XCTAssertTrue(aus.ganz)
        XCTAssertFalse(z.helligkeitAutomatisch(fuer: b.id))
        XCTAssertEqual(z.panelhelligkeit(fuer: b.id), 200)
        _ = await z.helligkeitAutomatikSetzen(true, fuer: b.id)
        XCTAssertEqual(z.panelhelligkeit(fuer: b.id), 32)
    }

    func testOhneSensorLehntDieAutomatikAb() async throws {
        let (z, a, _) = try zweiUhren()
        await z.zustandAbfragen(a.id)
        let b = await z.helligkeitAutomatikSetzen(true, fuer: a.id)
        XCTAssertEqual(b.erreicht, [])
        XCTAssertNotNil(z.fehler)
        XCTAssertEqual(z.uhreneinstellungen[a.id]?.wahrheit(.autoBrightness), false)
    }

    // MARK: - Befehle

    func testPanelAusSchaltenHolztDenStandNach() async throws {
        let (z, uhr, s) = try httpUhr()
        let b = await z.panelSchalten(an: false)
        XCTAssertTrue(b.ganz)
        XCTAssertFalse(s.zustand.power)
        XCTAssertEqual(z.anzeigestand[uhr.id]?.an, false, "der Stand kommt von der Uhr")
        XCTAssertEqual(z.geraetezustand[uhr.id]?.panelAn, false)
        _ = await z.panelSchalten(an: true)
        XCTAssertEqual(z.anzeigestand[uhr.id]?.an, true)
    }

    func testHelligkeitMoodlightUndAnzeiger() async throws {
        let (z, uhr, s) = try httpUhr()
        let h = await z.helligkeitSetzen(20)
        XCTAssertTrue(h.ganz)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.ganzzahl(.brightness), 20)
        XCTAssertEqual(z.anzeigestand[uhr.id]?.helligkeit, 20)

        _ = await z.moodlightSetzen(Moodlight(farbe: "#112233", helligkeit: 60))
        XCTAssertEqual(z.anzeigestand[uhr.id]?.moodlight, Moodlightstand(farbe: "#112233", helligkeit: 60))
        _ = await z.moodlightSetzen(Moodlight(helligkeit: 70))
        XCTAssertEqual(z.anzeigestand[uhr.id]?.moodlight, Moodlightstand(farbe: "#112233", helligkeit: 70),
                       "fehlende Felder behalten ihren Wert — das weiß nur die Uhr")
        _ = await z.moodlightAusschalten()
        XCTAssertNil(z.anzeigestand[uhr.id]?.moodlight)

        _ = await z.indikatorSetzen(Indikator(nummer: 1, farbe: "#FF0000", blinkMs: 100))
        XCTAssertEqual(z.geraetezustand[uhr.id]?.indikatoren[0].an, true)
        XCTAssertEqual(s.zustand.indikatoren[0].blinkMs, 100)
        _ = await z.indikatorAusschalten(1)
        XCTAssertEqual(z.geraetezustand[uhr.id]?.indikatoren[0].an, false)
    }

    func testOverlayMitDenNamenDerUhr() async throws {
        let (z, uhr, s) = try httpUhr()
        z.faehigkeiten[uhr.id] = Geraetefaehigkeiten(overlays: ["rain", "snow"])
        _ = await z.overlaySetzen("SNOW")
        XCTAssertEqual(s.zustand.overlay, "snow")
        XCTAssertEqual(z.anzeigestand[uhr.id]?.overlay, "snow")
        let falsch = await z.overlaySetzen("hagel")
        XCTAssertTrue(falsch.nichts)
        XCTAssertNotNil(z.fehler, "die Abweisung ist sichtbar")
        XCTAssertEqual(s.zustand.overlay, "snow")
    }

    func testEinstellungenAendernUndBlaettern() async throws {
        let (z, uhr, s) = try httpUhr()
        await z.zustandAbfragen(uhr.id)
        var a = Einstellungsaenderung()
        try a.setzen(.volume, .zahl(30))
        try a.setzen(.clockFace, .text("big"))
        let b = await z.einstellungenAendern(a)
        XCTAssertTrue(b.ganz)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.ganzzahl(.volume), 30)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.text(.clockFace), "big")
        XCTAssertEqual(s.zustand.einstellungen["enlargeApps"], .bool(true))

        _ = await z.anzeigeBlaettern(vor: true)
        await z.zustandAbfragen(uhr.id)
        XCTAssertEqual(z.aktiveAnzeige[uhr.id], "Status")
    }

    func testTLSCAHochladenUndEntfernenSchaltetNichtsEin() async throws {
        let (z, uhr, s) = try httpUhr()
        z.faehigkeiten[uhr.id] = Geraetefaehigkeiten(mqttTlsUnterstuetzt: true)
        let pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n"
        let ok = await z.tlsCAHochladen(pem, fuer: uhr.id)
        XCTAssertTrue(ok)
        XCTAssertTrue(s.zustand.eigeneCA)
        XCTAssertEqual(z.tlsStatus[uhr.id]?.oeffentlich, false)
        XCTAssertEqual(s.zustand.einstellungen["mqttTls"], nil, "TLS einzuschalten ist Sache der Web-Oberfläche")
        let weg = await z.tlsCAEntfernen(fuer: uhr.id)
        XCTAssertTrue(weg)
        XCTAssertEqual(z.tlsStatus[uhr.id]?.oeffentlich, true)
        let schlecht = await z.tlsCAHochladen("kein Zertifikat", fuer: uhr.id)
        XCTAssertFalse(schlecht)
        XCTAssertNotNil(z.fehler)
    }

    // MARK: - Mitlesen

    func testMitgelesenerZustandKommtInsModell() throws {
        let (z, uhr) = try mqttUhr()
        gemeldet(z, uhr, "state/apps/active", "Status")
        XCTAssertEqual(z.aktiveAnzeige[uhr.id], "Status")
        gemeldet(z, uhr, "state/device", #"{"version":"1.2.2","brightness":12,"matrixPower":false,"currentApp":"Time"}"#)
        XCTAssertEqual(z.geraetezustand[uhr.id]?.helligkeit, 12)
        XCTAssertEqual(z.aktiveAnzeige[uhr.id], "Time")
        gemeldet(z, uhr, "state/settings", #"{"volume":42,"brightness":99}"#)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.ganzzahl(.volume), 42)
    }

    func testMitgeleseneHelligkeitFuehrtDenAnzeigestandNach() throws {
        let (z, uhr) = try mqttUhr()
        z.anzeigestand[uhr.id] = try Anzeigestand(daten: Data(#"{"power":true,"brightness":1}"#.utf8))
        gemeldet(z, uhr, "state/settings", #"{"brightness":99}"#)
        XCTAssertEqual(z.anzeigestand[uhr.id]?.helligkeit, 99)
        gemeldet(z, uhr, "state/device", #"{"matrixPower":false}"#)
        XCTAssertEqual(z.anzeigestand[uhr.id]?.an, false)
    }

    func testTastenDrehknopfUndFehler() throws {
        let (z, uhr) = try mqttUhr()
        gemeldet(z, uhr, "state/buttons/left", "1")
        gemeldet(z, uhr, "state/buttons/knob", "1")
        gemeldet(z, uhr, "state/buttons/left", "0")
        XCTAssertEqual(z.tasten[uhr.id], [.links: false, .knopf: true])

        gemeldet(z, uhr, "event/knob", #"{"turn":2}"#)
        gemeldet(z, uhr, "event/knob", #"{"turn":2}"#)
        gemeldet(z, uhr, "event/knob", #"{"turn":-1}"#)
        XCTAssertEqual(z.drehknopf[uhr.id], Drehknopfstand(letzteRasten: -1, summe: 3, zaehler: 3))

        XCTAssertNil(z.uhrenfehler[uhr.id])
        gemeldet(z, uhr, "event/error", #"{"source":"http","request":"PATCH settings","error":{"code":"validationFailed","field":"volume"}}"#)
        XCTAssertEqual(z.uhrenfehler[uhr.id]?.fehler, "validationFailed (volume)")
        XCTAssertNil(z.fehler, "ein Ereignis ist kein Fenster; die Ansicht entscheidet")
    }

    func testHugeKnobPayloadsDoNotCrash() throws {
        let (z, uhr) = try mqttUhr()
        for roh in ["9223372036854775807", "-9223372036854775808", "1e308", "1001", "-1001", "1e400"] {
            gemeldet(z, uhr, "event/knob", "{\"turn\":\(roh)}")
        }
        XCTAssertNil(z.drehknopf[uhr.id], "alles ausserhalb von ±1000 wird verworfen")
        gemeldet(z, uhr, "event/knob", #"{"turn":1000}"#)
        gemeldet(z, uhr, "event/knob", #"{"turn":-1000}"#)
        XCTAssertEqual(z.drehknopf[uhr.id], Drehknopfstand(letzteRasten: -1000, summe: 0, zaehler: 2))
        z.drehknopf[uhr.id] = Drehknopfstand(letzteRasten: 0, summe: Int.max - 5, zaehler: Int.max)
        gemeldet(z, uhr, "event/knob", #"{"turn":1000}"#)
        XCTAssertEqual(z.drehknopf[uhr.id]?.summe, Int.max)
        XCTAssertEqual(z.drehknopf[uhr.id]?.zaehler, Int.max)
        z.drehknopf[uhr.id] = Drehknopfstand(letzteRasten: 0, summe: Int.min + 5, zaehler: 0)
        gemeldet(z, uhr, "event/knob", #"{"turn":-1000}"#)
        XCTAssertEqual(z.drehknopf[uhr.id]?.summe, Int.min)
        for _ in 0..<5000 { gemeldet(z, uhr, "event/knob", #"{"turn":7}"#) }
        XCTAssertNotNil(z.drehknopf[uhr.id])
    }

    func testDerAbrissDesMitlesensLeertDieTasten() throws {
        let (z, uhr) = try mqttUhr()
        gemeldet(z, uhr, "state/buttons/right", "1")
        XCTAssertEqual(z.tasten[uhr.id], [.rechts: true])
        z.horchzustand(true, nil, fuer: uhr.id)
        z.horchzustand(false, "weg", fuer: uhr.id)
        XCTAssertNil(z.tasten[uhr.id])
    }

    func testEineEntferntUhrBehaeltKeinenZustand() throws {
        let (z, uhr) = try mqttUhr()
        gemeldet(z, uhr, "state/apps/active", "Time")
        gemeldet(z, uhr, "event/knob", #"{"turn":1}"#)
        z.uhrEntfernen(uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        XCTAssertNil(z.aktiveAnzeige[uhr.id])
        XCTAssertNil(z.drehknopf[uhr.id])
    }

    // MARK: - Steuerungsseite

    /// Zwei HTTP-Uhren an zwei virtuellen Uhren, beide gewählt.
    private func zweiUhren() throws -> (AppZustand, Uhr, Uhr, Uhrenserver, Uhrenserver) {
        var gestartet: [(Uhrenserver, UInt16)] = []
        while gestartet.count < 2 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            if (try? s.starten()) != nil { gestartet.append((s, port)) }
        }
        let a = Uhr(name: "Küche", host: "127.0.0.1:\(gestartet[0].1)", praefix: "", betriebsart: .http)
        let b = Uhr(name: "Büro", host: "127.0.0.1:\(gestartet[1].1)", praefix: "", betriebsart: .http)
        server = gestartet[0].0
        addTeardownBlock { gestartet[1].0.beenden() }
        return (try zustand(mit: [a, b]), a, b, gestartet[0].0, gestartet[1].0)
    }

    func testEinBefehlMitKennungTrifftNurDieseUhr() async throws {
        let (z, a, b, sa, sb) = try zweiUhren()
        let nur = await z.panelSchalten(an: false, fuer: b.id)
        XCTAssertTrue(nur.ganz)
        XCTAssertEqual(nur.ziele, 1)
        XCTAssertTrue(sa.zustand.power, "die andere gewählte Uhr bleibt an")
        XCTAssertFalse(sb.zustand.power)
        let alle = await z.panelSchalten(an: true)
        XCTAssertEqual(alle.ziele, 2, "ohne Kennung gelten alle gewählten")
        XCTAssertTrue(sb.zustand.power)
        _ = a
    }

    func testEineUnbekannteKennungSendetNichts() async throws {
        let (z, _, _, sa, sb) = try zweiUhren()
        let b = await z.panelSchalten(an: false, fuer: UUID())
        XCTAssertEqual(b, Sendebilanz(erreicht: [], ziele: 0))
        XCTAssertTrue(sa.zustand.power)
        XCTAssertTrue(sb.zustand.power)
    }

    func testEinstellungSetzenZerlegtSchluesselUndLiestDenStandZurueck() async throws {
        let (z, uhr, s) = try httpUhr()
        await z.zustandAbfragen(uhr.id)
        let b = await z.einstellungSetzen("scroll.speed", wert: "7", fuer: uhr.id)
        XCTAssertTrue(b.ganz)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.lauftext?.speed, 7)
        _ = await z.einstellungSetzen("uppercase", wert: "ein", fuer: uhr.id)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.wahrheit(.uppercase), true)
        XCTAssertEqual(s.zustand.einstellungen["uppercase"], .bool(true))
        let schlecht = await z.einstellungSetzen("volume", wert: "101", fuer: uhr.id)
        XCTAssertTrue(schlecht.nichts)
        XCTAssertNotNil(z.fehler, "eine Eingabe, die jemand berichtigen kann, ist ein Dialog")
    }

    func testNeustartKommtAnUndHolztNichtsZurueck() async throws {
        let (z, uhr, s) = try httpUhr()
        z.bildschirm[uhr.id] = (Bildschirmauszug(breite: 52, hoehe: 16, pixel: [Int](repeating: 0, count: 832))!, Date())
        let b = await z.neustarten(fuer: uhr.id)
        XCTAssertTrue(b.ganz)
        XCTAssertEqual(s.zustand.neustarts, 1)
        XCTAssertNil(z.geraetezustand[uhr.id], "keine Abfrage gegen eine Uhr, die gerade hochfährt")
        XCTAssertNil(z.bildschirm[uhr.id], "das alte Bild gilt nicht mehr")
    }

    func testBildschirmFolgenHoertMitDerAufgabeAuf() async throws {
        let (z, uhr, _) = try httpUhr()
        let aufgabe = Task { await z.bildschirmFolgen(uhr.id, takt: .milliseconds(20)) }
        for _ in 0..<100 where z.bildschirm[uhr.id] == nil { try await Task.sleep(for: .milliseconds(20)) }
        let erstes = try XCTUnwrap(z.bildschirm[uhr.id])
        XCTAssertEqual(erstes.bild.breite, 52)
        XCTAssertEqual(erstes.bild.hoehe, 16)
        for _ in 0..<100 where z.bildschirm[uhr.id]?.abgerufen == erstes.abgerufen {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNotEqual(z.bildschirm[uhr.id]?.abgerufen, erstes.abgerufen, "es läuft im Takt")
        aufgabe.cancel()
        await aufgabe.value
        let stand = z.bildschirm[uhr.id]?.abgerufen
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(z.bildschirm[uhr.id]?.abgerufen, stand, "nach dem Abbruch fragt nichts mehr")
    }

    func testEinBildschirmFehlschlagLaesstDasLetzteBildStehen() async throws {
        let (z, uhr, s) = try httpUhr()
        let ersteres = await z.bildschirmAbfragen(uhr.id)
        XCTAssertTrue(ersteres)
        let erstes = z.bildschirm[uhr.id]?.abgerufen
        s.beenden()
        let zweites = await z.bildschirmAbfragen(uhr.id)
        XCTAssertFalse(zweites)
        XCTAssertEqual(z.bildschirm[uhr.id]?.abgerufen, erstes)
        XCTAssertNil(z.fehler)
    }
}
