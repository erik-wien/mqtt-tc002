import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Was der Zustand der App anders macht, sobald eine Uhr eine AWTRIX NG ist.
///
/// Kein Broker, kein Geraet: `gemeldet` wird von Hand aufgerufen — dieselbe
/// Naht, die `AppZustandTests` fuer den Rueckkanal benutzen —
/// und `themen(fuer:)` ist ausdruecklich `static`, damit sich die Abonnements
/// nachrechnen lassen, ohne eines aufzubauen.
///
/// Der Schluesselbund wird nie angefasst (`Schluesselbunddoppelgaenger` aus
/// `AppZustandTests`), die Slotdateien liegen in einem Wegwerfordner.
@MainActor
final class AwtrixNGZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer",
                              // Zwei Schalter, die Tests umlegen — und die sonst
                              // in den naechsten Test hinueberleckten: Der
                              // abgeschaltete Verlauf liess dort jede
                              // Aufzeichnung ausfallen, und es sah aus, als
                              // zeichne er gar nicht auf.
                              "protokollAn", "verlaufAn"]
    private var sicherung: [String: Any?] = [:]
    private var schluesselbund = Schluesselbunddoppelgaenger()

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        schluesselbund = Schluesselbunddoppelgaenger()
        // Nichts von hier geht je ins Netz: `Belegungsdoppelgaenger` faengt
        // jede Anfrage ab (dieselbe Naht wie in `AppZustandTests`).
        Belegungsdoppelgaenger.antwort = "{}"
        Belegungsdoppelgaenger.weitere = [:]
        Belegungsdoppelgaenger.pfade = []
    }

    override func tearDown() {
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private func mitUhr(_ uhr: Uhr) throws -> AppZustand {
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        return AppZustand(schluesselbund: schluesselbund)
    }

    private func ngUhr(praefix: String = "wohnzimmer/uhr") -> Uhr {
        Uhr(name: "Wohnzimmer", host: "10.0.0.9", praefix: praefix,
            betriebsart: .mqtt)
    }

    private func mitUhren(_ uhren: [Uhr]) throws -> AppZustand {
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(uhren[0].id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set(uhren.map(\.id))), forKey: "zielIDs")
        return AppZustand(schluesselbund: schluesselbund)
    }

    // MARK: - Worauf gehorcht wird

    /// NG hoert auf `availability` und auf alles unter `cmd/apps/pushed`, dazu
    /// auf die Antworten zu Benachrichtigungen und zum Ein-/Ausschalten. Die
    /// Anzeigenliste kommt allein ueber HTTP.
    func testDieAbonnierteThemen() {
        XCTAssertEqual(AppZustand.themen(fuer: ngUhr()),
                       ["wohnzimmer/uhr/availability", "wohnzimmer/uhr/cmd/apps/pushed/#",
                        "wohnzimmer/uhr/cmd/notify/#", "wohnzimmer/uhr/cmd/apps/+/enabled/result"])
    }

    // MARK: - Was hereinkommt

    /// NG meldet sich unter `availability` und nicht unter `status` — und mit
    /// zwei Woertern statt einem, weil `offline` als Last Will beim Broker
    /// hinterlegt ist.
    func testErreichbarkeitKommtVonAvailability() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)

        zustand.gemeldet(thema: "wohnzimmer/uhr/availability", nutzlast: Data("online".utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        XCTAssertEqual(zustand.geraetOnline[uhr.id], true)

        zustand.gemeldet(thema: "wohnzimmer/uhr/availability", nutzlast: Data("offline".utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        XCTAssertEqual(zustand.geraetOnline[uhr.id], false)
    }

    /// Der einzige Ort, an dem eine abgewiesene Sendung ueberhaupt auftaucht.
    /// Auf der MQTT-Ebene war alles in Ordnung: Der Broker hat die
    /// Veroeffentlichung angenommen, das Protokoll sagt „gesendet". Ohne
    /// diese Zeile bliebe es dabei, und nur die Uhr waere dunkel.
    func testEineAbweisungAufResultWirdSichtbar() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)

        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung1/result",
                         nutzlast: Data(#"{"ok":false,"error":{"code":"validationFailed","field":"durationMs"}}"#.utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        let meldung = try XCTUnwrap(zustand.fehler)
        XCTAssertTrue(meldung.contains("validationFailed"), "war stattdessen: \(meldung)")
        XCTAssertTrue(meldung.contains("meldung1"))
    }

    /// Und Erfolg bleibt still. Eine Fehlerzeile bei jeder geglueckten Sendung
    /// waere schlimmer als keine.
    func testEineGeglueckteSendungMeldetNichts() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung1/result",
                         nutzlast: Data(#"{"ok":true}"#.utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        XCTAssertNil(zustand.fehler)
    }

    /// Genau null Bytes loeschen die Anzeige, gleich von wem geschickt. Der Platz zaehlt danach wieder
    /// als frei.
    func testEineLeereNutzlastRaeumtDenPlatz() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        zustand.anzeigeGemerkt("meldung1", fuer: uhr.id)

        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung1", nutzlast: Data(),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        XCTAssertFalse(zustand.anzeigenAufUhr(uhr.id).contains("meldung1"))
    }

    /// Eine mitgelesene fremde Sendung belegt den Platz. Bei NG kommt die
    /// Belegung sonst nur aus einem HTTP-Abruf von vorhin — sie kaeme also erst
    /// bei der naechsten Abfrage nach.
    func testEineMitgeleseneSendungBelegtDenPlatz() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        zustand.gemeldeteAnzeigen[uhr.id] = []

        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung3",
                         nutzlast: Data(#"{"text":"von wem anders"}"#.utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        XCTAssertEqual(zustand.anzeigenAufUhr(uhr.id), ["meldung3"])
    }

    // MARK: - Was ein Block zeigen darf

    /// Ein Block zeigt ein Bild, weil `Anzeigemass` auf die 52×16 der Uhr
    /// rastert und `Meldungsoptionen.naeherung` dieselbe Naeherungsschrift
    /// setzt, die die Vorschau ohnehin zeigt. Nichts zu zeigen waere die
    /// staerkere Behauptung: „wir wissen es nicht", obwohl wir es selbst
    /// geschickt haben.
    func testEinNGBlockZeigtDasBildAufIhremEigenenMass() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        gedaechtnis.merken(Meldungsoptionen(text: "Bus kommt"), icon: nil, iconKante: 8, fuer: uhr.id, platz: 2)

        guard case let .bekannt(pixel) = zustand.slotzustand(2, belegt: true, gedaechtnis: gedaechtnis) else {
            return XCTFail("Der Block zeigt nichts, obwohl der Stand gemerkt ist.")
        }
        XCTAssertEqual(pixel.count, 52 * 16)
        XCTAssertTrue(pixel.contains { $0 != nil }, "Vom Text ist nichts uebriggeblieben.")
    }


    // MARK: - Das Praefix einer migrierten Uhr

    /// Eine Uhr aus der Zeit der Werksfirmware traegt deren Praefix, und das
    /// stimmt fuer AWTRIX NG nicht. Beim Lesen faellt es weg; ohne Praefix ist
    /// die MQTT-Uhr nicht beschickbar, und beim Start holt die App das richtige
    /// von der Uhr. Die Uhr ist hier die virtuelle auf 127.0.0.1.
    func testEineMigrierteUhrHoltIhrPraefixVonDerUhr() throws {
        var nutzstand = NGUhrzustand()
        nutzstand.mqttPrefix = "wohnzimmer/uhr"
        let (server, port) = try serverStarten(zustand: nutzstand)
        defer { server.beenden() }

        let alt = """
        [{"id":"0E5E2F1A-6B4C-4E9B-9F3E-6A0C1D2E3F40","name":"Küche",\
        "host":"127.0.0.1:\(port)","praefix":"awtrix_a86b","mac":"AA:BB",\
        "typ":"tc002","betriebsart":"mqtt"}]
        """
        d.set(Data(alt.utf8), forKey: "uhren")
        d.set("0E5E2F1A-6B4C-4E9B-9F3E-6A0C1D2E3F40", forKey: "aktiveID")
        d.removeObject(forKey: "brokerHost")
        let zustand = AppZustand(schluesselbund: schluesselbund)

        XCTAssertEqual(zustand.uhren.count, 1)
        XCTAssertEqual(zustand.uhren[0].praefix, "", "das Praefix der Werksfirmware gilt nicht weiter")
        XCTAssertFalse(zustand.uhren[0].beschickbar, "auf das alte Thema darf nichts gehen")

        zustand.horchenStarten()
        warteBis { !zustand.uhren[0].praefix.isEmpty }

        XCTAssertEqual(zustand.uhren[0].praefix, "wohnzimmer/uhr")
        XCTAssertEqual(zustand.uhren[0].mac, "000000000000")
        XCTAssertTrue(zustand.uhren[0].anzeigemass == (52, 16))
        XCTAssertTrue(zustand.uhren[0].beschickbar)
    }

    /// Ohne eingestelltes Praefix gilt die uid der Uhr (§2).
    func testOhneEingestelltesPraefixHoltDieMigrierteUhrDieUid() throws {
        let (server, port) = try serverStarten(zustand: NGUhrzustand())
        defer { server.beenden() }
        let uhr = Uhr(name: "Küche", host: "127.0.0.1:\(port)", betriebsart: .mqtt)
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.removeObject(forKey: "brokerHost")
        let zustand = AppZustand(schluesselbund: schluesselbund)

        zustand.horchenStarten()
        warteBis { !zustand.uhren[0].praefix.isEmpty }

        XCTAssertEqual(zustand.uhren[0].praefix, "000000000000")
    }

    /// Eine Uhr, die nicht antwortet, bleibt ohne Praefix und nicht
    /// beschickbar — es geht nichts auf ein erratenes Thema.
    func testEineStummeMigrierteUhrBleibtOhnePraefix() throws {
        let (server, port) = try serverStarten(zustand: NGUhrzustand())
        server.beenden()
        let uhr = Uhr(name: "Küche", host: "127.0.0.1:\(port)", betriebsart: .mqtt)
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.removeObject(forKey: "brokerHost")
        let zustand = AppZustand(schluesselbund: schluesselbund)

        zustand.horchenStarten()
        warteBis({ zustand.erreichbar[uhr.id] == false }, frist: 3)

        XCTAssertEqual(zustand.uhren[0].praefix, "")
        XCTAssertFalse(zustand.uhren[0].beschickbar)
    }

    // MARK: - Gemerkte Regler eines Platzes

    /// Die Regler eines Platzes gelten, solange die App nicht gesehen hat, dass
    /// jemand anderes ihn beschrieben hat. Eine fremde Nutzlast hebt sie auf.
    func testEineFremdeNutzlastMachtDieGemerktenReglerUngueltig() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        gedaechtnis.merken(Meldungsoptionen(text: "von mir"), icon: nil, iconKante: 8, fuer: uhr.id, platz: 1)
        XCTAssertNotNil(zustand.wiederherstellbarerStand(platz: 1, fuer: uhr, gedaechtnis: gedaechtnis))

        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung1",
                         nutzlast: Data(#"{"text":"von wem anders"}"#.utf8),
                         fuer: uhr.id, gedaechtnis: gedaechtnis)

        XCTAssertNil(zustand.wiederherstellbarerStand(platz: 1, fuer: uhr, gedaechtnis: gedaechtnis))
        XCTAssertNotNil(gedaechtnis.gemerkt(fuer: uhr.id, platz: 1), "gemerkt bleibt es, nur nicht gueltig")
    }

    /// Das Echo der eigenen Sendung ist keine fremde Nutzlast.
    func testDasEchoDerEigenenSendungMachtNichtsUngueltig() async throws {
        let uhr = Uhr(name: "Küche", host: "uhr.example", praefix: "wohnzimmer/uhr", betriebsart: .http)
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        zustand.netzsitzung = Belegungsdoppelgaenger.sitzung()
        defer { _ = Slotgedaechtnis.gemeinsam.vergessen(fuer: uhr.id, platz: 4) }
        let optionen = Meldungsoptionen(text: "eigen")
        let rahmen = Frame(herkunft: Meldungsherkunft(optionen: optionen))

        await zustand.senden(rahmen, als: "meldung4", slotOptionen: optionen, slotPlatz: 4)
        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung4",
                         nutzlast: Data(try Anzeigen.nutzlast(rahmen).utf8), fuer: uhr.id)

        XCTAssertNotNil(zustand.wiederherstellbarerStand(platz: 4, fuer: uhr))
    }

    private func serverStarten(zustand: NGUhrzustand) throws -> (Uhrenserver, UInt16) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: zustand)
            do {
                try s.starten()
                Thread.sleep(forTimeInterval: 0.05)
                return (s, port)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    /// Laesst den Hauptthread laufen, bis die losgeloeste Abfrage
    /// zurueckgemeldet hat.
    private func warteBis(_ bedingung: () -> Bool, frist: TimeInterval = 5) {
        let ende = Date().addingTimeInterval(frist)
        while !bedingung(), Date() < ende {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}
