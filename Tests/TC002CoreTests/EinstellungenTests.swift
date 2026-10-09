import XCTest
@testable import TC002Core

/// Die Einstellungen sind die Nahtstelle zwischen App und Kommandozeilen-
/// werkzeug. Was hier schiefgeht, faellt erst auf, wenn das Werkzeug
/// stillschweigend an die falsche Uhr sendet — oder an gar keine.
final class EinstellungenTests: XCTestCase {

    private func uhr(_ name: String, _ host: String, praefix: String = "awtrix_0000") -> Uhr {
        Uhr(name: name, host: host, praefix: praefix)
    }

    private func einstellungen(uhren: [Uhr], zielIDs: Set<UUID> = []) -> Einstellungen {
        Einstellungen(brokerHost: "broker.local", brokerPort: 1883, benutzer: "u",
                      kennwort: "k", uhren: uhren, zielIDs: zielIDs)
    }

    /// Ohne Auswahl gilt: alle. Das ist die Lage nach einer frischen
    /// Installation — die App legt `zielIDs` erst ab, wenn jemand waehlt.
    func testOhneAuswahlSindAlleUhrenZiel() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        XCTAssertEqual(einstellungen(uhren: [a, b]).ziele.map(\.name), ["Küche", "Bad"])
    }

    func testAuswahlGrenztEin() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        let e = einstellungen(uhren: [a, b], zielIDs: [b.id])
        XCTAssertEqual(e.ziele.map(\.name), ["Bad"])
    }

    /// Eine Auswahl, die nur noch auf geloeschte Uhren zeigt, darf nicht als
    /// „keine Auswahl" durchgehen und damit plötzlich alle treffen — das waere
    /// aus Sicht des Anwenders eine Sendung an Geraete, die er abgewaehlt hat.
    /// Sie faellt deshalb auf „alle" zurueck, aber nur weil nichts uebrig ist;
    /// dieser Test haelt das Verhalten fest, damit es nicht unbemerkt kippt.
    func testVerwaisteAuswahlFaelltAufAlleZurueck() {
        let a = uhr("Küche", "10.0.0.1")
        let e = einstellungen(uhren: [a], zielIDs: [UUID()])
        XCTAssertEqual(e.ziele.map(\.name), ["Küche"])
    }

    func testSuchePerNameUndAdresse() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        let e = einstellungen(uhren: [a, b])
        XCTAssertEqual(e.uhr(benannt: "Bad")?.id, b.id)
        XCTAssertEqual(e.uhr(benannt: "bad")?.id, b.id, "Gross- und Kleinschreibung zaehlt nicht")
        XCTAssertEqual(e.uhr(benannt: "10.0.0.1")?.id, a.id, "die Adresse geht auch")
        XCTAssertNil(e.uhr(benannt: "Keller"))
    }

    /// Der Name gewinnt gegen die Adresse: Wer eine Uhr „10.0.0.2" nennt,
    /// meint mit diesem Wort die Uhr mit dem Namen, nicht die dahinter.
    func testNameSchlaegtAdresse() {
        let getarnt = uhr("10.0.0.2", "10.0.0.9"), echt = uhr("Bad", "10.0.0.2")
        let e = einstellungen(uhren: [getarnt, echt])
        XCTAssertEqual(e.uhr(benannt: "10.0.0.2")?.id, getarnt.id)
    }

    func testZugangTraegtDieKennung() {
        let z = einstellungen(uhren: []).zugang(clientID: "tc002-cli-abc")
        XCTAssertEqual(z?.clientID, "tc002-cli-abc")
        XCTAssertEqual(z?.host, "broker.local")
        XCTAssertEqual(z?.port, 1883)
    }

    /// Ohne Broker gibt es keinen Zugang — und das Werkzeug soll das melden,
    /// statt an Port 0 zu laufen.
    func testOhneBrokerKeinZugang() {
        let ohneHost = Einstellungen(brokerHost: "", brokerPort: 1883, benutzer: nil,
                                     kennwort: nil, uhren: [], zielIDs: [])
        let ohnePort = Einstellungen(brokerHost: "broker.local", brokerPort: 0, benutzer: nil,
                                     kennwort: nil, uhren: [], zielIDs: [])
        XCTAssertNil(ohneHost.zugang(clientID: "x"))
        XCTAssertNil(ohnePort.zugang(clientID: "x"))
    }

    /// Eine Einstellungszeile, wie eine laufende Installation sie abgelegt hat:
    /// ohne `typ` und ohne `einrichtung`.
    private static let alteZeile = """
    [{"id":"0E5E2F1A-6B4C-4E9B-9F3E-6A0C1D2E3F40","name":"Küche",\
    "host":"10.0.0.1","praefix":"awtrix_a86b","mac":"AA:BB"}]
    """

    /// Drei Uhren in der Form, in der frühere Fassungen sie geschrieben haben:
    /// ohne `typ`, als `"tc002"` und als `"awtrixNG"` (mit den 32 × 8 einer
    /// TC001). Die Kennungen sind Platzhalter.
    private static let alteListe = """
    [{"id":"0E5E2F1A-6B4C-4E9B-9F3E-6A0C1D2E3F40","name":"Küche",\
    "host":"10.0.0.1","praefix":"awtrix_a86b","mac":"AA:BB","betriebsart":"mqtt"},\
    {"id":"1F6F3A2B-7C5D-4FAC-8A4F-7B1D2E3F4A51","name":"Flur",\
    "host":"10.0.0.2","praefix":"awtrix_c3d4","mac":"CC:DD","typ":"tc002","betriebsart":"http"},\
    {"id":"2A703B3C-8D6E-4ABD-9B50-8C2E3F4A5B62","name":"Bad",\
    "host":"10.0.0.3","praefix":"bad/uhr","mac":"EE:FF","typ":"awtrixNG",\
    "panelbreite":32,"panelhoehe":8,"betriebsart":"mqtt"}]
    """

    /// Die Codable-Form von `Uhr` ist ein Dateiformat: Die App hat sie
    /// geschrieben, das Werkzeug liest sie. Wer die Feldnamen aendert, macht
    /// die Einstellungen einer laufenden Installation unlesbar.
    func testUhrBleibtLesbar() throws {
        let uhren = try JSONDecoder().decode([Uhr].self, from: Data(Self.alteZeile.utf8))
        XCTAssertEqual(uhren.count, 1)
        XCTAssertEqual(uhren[0].name, "Küche")
        XCTAssertEqual(uhren[0].host, "10.0.0.1")
        XCTAssertEqual(uhren[0].mac, "AA:BB")
    }

    /// Alle drei Altformen bleiben lesbar, ohne dass eine Uhr verloren geht
    /// (die Leser lesen mit `try?`: ein Fehler waere eine leere Liste). Das
    /// Präfix der Werksfirmware stimmt für NG nicht und wird verworfen, die
    /// 32 × 8 ebenso; der Rest bleibt.
    func testAlteUhrenAllerArtenBleibenLesbarUndVerlierenNurPraefixUndMass() throws {
        let uhren = try JSONDecoder().decode([Uhr].self, from: Data(Self.alteListe.utf8))
        XCTAssertEqual(uhren.map(\.name), ["Küche", "Flur", "Bad"])
        XCTAssertEqual(uhren.map(\.host), ["10.0.0.1", "10.0.0.2", "10.0.0.3"])
        XCTAssertEqual(uhren.map(\.mac), ["AA:BB", "CC:DD", "EE:FF"])
        XCTAssertEqual(uhren.map(\.praefix), ["", "", ""])
        XCTAssertTrue(uhren.allSatisfy { $0.anzeigemass == (52, 16) })
        XCTAssertEqual(uhren.map(\.wirksameBetriebsart), [.mqtt, .http, .mqtt])
    }

    /// Eine MQTT-Uhr ohne Präfix ist nicht beschickbar: Es wird nichts auf das
    /// alte Thema gesendet, bis „Abfragen" das richtige geholt hat.
    func testEineMigrierteMqttUhrIstBisZurAbfrageNichtBeschickbar() throws {
        let uhren = try JSONDecoder().decode([Uhr].self, from: Data(Self.alteListe.utf8))
        XCTAssertFalse(uhren[0].beschickbar)
        XCTAssertFalse(uhren[2].beschickbar)
        XCTAssertTrue(uhren[1].beschickbar, "HTTP braucht kein Präfix")
    }

    /// Was die aktuelle Fassung schreibt, bleibt unverändert lesbar: Das
    /// Präfix und das Maß überleben, ein `typ` wird nicht mehr geschrieben.
    func testDieAktuelleFormUeberstehtDieDatei() throws {
        let uhr = Uhr(name: "Flur", host: "10.0.0.2", praefix: "flur/uhr",
                      panelbreite: 52, panelhoehe: 16)
        let daten = try JSONEncoder().encode([uhr])
        let text = String(decoding: daten, as: UTF8.self)
        XCTAssertFalse(text.contains("\"typ\""), "war: \(text)")

        let zurueck = try JSONDecoder().decode([Uhr].self, from: daten)
        XCTAssertEqual(zurueck, [uhr])
        XCTAssertEqual(zurueck[0].praefix, "flur/uhr")
    }

    // MARK: - Betriebsart

    /// Die Entscheidung ueber den Bestand. Eine Datei ohne `betriebsart`
    /// hat eine Fassung vor dieser Aenderung geschrieben — und jede dort
    /// eingerichtete Uhr ist eine MQTT-Uhr: Sie hat ein abgefragtes Praefix,
    /// einen eingetragenen Broker, ein Kennwort im Schluesselbund, und
    /// gesendet wurde bisher ausschliesslich darueber.
    ///
    /// Wuerde `nil` als `.http` gelesen, verloere jede bestehende Installation
    /// beim ersten Start nach dem Update stillschweigend das Mitlesen. Die
    /// Vorgabe HTTP gilt fuer neue Uhren, und die traegt
    /// `AppZustand.uhrHinzufuegen` ausdruecklich ein.
    func testAlteUhrOhneBetriebsartBleibtBeiMqtt() throws {
        let uhren = try JSONDecoder().decode([Uhr].self, from: Data(Self.alteZeile.utf8))
        XCTAssertNil(uhren[0].betriebsart, "in der Datei steht der Schluessel gar nicht")
        XCTAssertEqual(uhren[0].wirksameBetriebsart, .mqtt,
                       "eine bestehende Einrichtung sendet weiter ueber den Broker")
    }

    /// Solange nichts gewaehlt ist, schreibt der Encoder das
    /// Feld nicht — eine aeltere Fassung liest die Datei weiterhin. Und eine
    /// getroffene Wahl uebersteht das Schreiben und Lesen unveraendert.
    func testDieGewaehlteBetriebsartUeberstehtDieDatei() throws {
        let ohne = try JSONEncoder().encode([Uhr(name: "Küche", host: "10.0.0.1")])
        XCTAssertFalse(String(decoding: ohne, as: UTF8.self).contains("betriebsart"))

        let mit = try JSONEncoder().encode([Uhr(name: "Küche", host: "10.0.0.1", betriebsart: .http)])
        XCTAssertTrue(String(decoding: mit, as: UTF8.self).contains("\"betriebsart\":\"http\""))
        XCTAssertEqual(try JSONDecoder().decode([Uhr].self, from: mit)[0].wirksameBetriebsart, .http)
    }

    /// Woran eine Uhr beschickbar ist, haengt an ihrer Betriebsart: Die
    /// HTTP-Uhr wird unter ihrer Adresse angesprochen und braucht kein
    /// Praefix, die MQTT-Uhr unter ihrem Thema und braucht eines. Der alte,
    /// einheitliche Praefix-Filter haette jede HTTP-Uhr stillschweigend
    /// uebersprungen.
    func testBeschickbarFragtDieBetriebsart() {
        let httpOhnePraefix = Uhr(name: "a", host: "10.0.0.1", betriebsart: .http)
        XCTAssertTrue(httpOhnePraefix.beschickbar, "HTTP braucht kein Präfix")

        let httpOhneAdresse = Uhr(name: "a", host: "", praefix: "p", betriebsart: .http)
        XCTAssertFalse(httpOhneAdresse.beschickbar, "ohne Adresse gibt es kein Ziel")

        let mqttOhnePraefix = Uhr(name: "a", host: "10.0.0.1", betriebsart: .mqtt)
        XCTAssertFalse(mqttOhnePraefix.beschickbar, "ohne Präfix gibt es kein Thema")

        let mqttMitPraefix = Uhr(name: "a", host: "", praefix: "p", betriebsart: .mqtt)
        XCTAssertTrue(mqttMitPraefix.beschickbar)
    }

    /// Ein Broker ist nur noetig, wenn wenigstens eine Uhr ihn benutzt. Wer
    /// ausschliesslich ueber HTTP sendet, soll nicht an einer Bedingung
    /// haengenbleiben, die seine Einrichtung gar nicht betrifft.
    func testBrokerIstNurFuerMqttUhrenNoetig() {
        let http = Uhr(name: "a", host: "10.0.0.1", betriebsart: .http)
        let mqtt = Uhr(name: "b", host: "10.0.0.2", praefix: "p", betriebsart: .mqtt)
        let alt = Uhr(name: "c", host: "10.0.0.3", praefix: "p")   // ohne Feld: MQTT

        XCTAssertFalse(Einstellungen.brokerNoetig(fuer: []))
        XCTAssertFalse(Einstellungen.brokerNoetig(fuer: [http]))
        XCTAssertTrue(Einstellungen.brokerNoetig(fuer: [mqtt]))
        XCTAssertTrue(Einstellungen.brokerNoetig(fuer: [http, mqtt]),
                      "eine einzige MQTT-Uhr genügt")
        XCTAssertTrue(Einstellungen.brokerNoetig(fuer: [alt]),
                      "eine Uhr aus dem Bestand zählt als MQTT-Uhr")
    }

    /// Die Vorgaben muessen dieselben sein wie in der App — sie legt einen
    /// unveraenderten Wert gar nicht erst ab, und dann gilt hier der Rueckfall.
    ///
    /// Adresse und Benutzer sind leer, und das ist die Zusicherung: Eine
    /// erfundene Vorgabe stuende auf einer frischen Installation im Feld, ohne
    /// dass jemand sie eingetragen haette — und `brokerEingerichtet` waere dort
    /// wahr, obwohl es keinen Broker gibt. Der Port ist der Gegenfall: 1883 ist
    /// der Standardport von MQTT und sagt nichts ueber diese Installation.
    func testVorgabenSindGesetzt() {
        XCTAssertEqual(Einstellungen.Vorgabe.brokerPort, "1883")
        XCTAssertTrue(Einstellungen.Vorgabe.benutzer.isEmpty,
                      "ein vorausgefuellter Benutzername ist schlechter als ein leeres Feld")
        XCTAssertTrue(Einstellungen.Vorgabe.brokerHost.isEmpty,
                      "eine erfundene Brokeradresse taeuscht eine Einrichtung vor")
    }

    /// Und was daraus folgt: Aus einem leeren Bereich kommt kein
    /// eingerichteter Broker. Das Werkzeug meldet dann, dass keiner eingetragen
    /// ist, statt an eine Adresse zu senden, die niemand genannt hat.
    func testFrischeInstallationHatKeinenBroker() {
        let bereich = "test.mqtt-tc002." + UUID().uuidString
        let e = Einstellungen.gelesen(bereich: bereich)
        XCTAssertEqual(e.brokerHost, "")
        XCTAssertNil(e.benutzer, "ein leerer Benutzername heisst „kein Konto“")
        XCTAssertFalse(e.brokerEingerichtet)
        XCTAssertNil(e.zugang(clientID: "x"))
        UserDefaults.standard.removePersistentDomain(forName: bereich)
    }

    /// Aus einem leeren Bereich kommen die Vorgaben, nicht Unsinn: ein Port 0
    /// liesse `NWEndpoint.Port` abstuerzen.
    func testLeererBereichLiefertVorgaben() {
        let bereich = "test.mqtt-tc002." + UUID().uuidString
        let e = Einstellungen.gelesen(bereich: bereich)
        XCTAssertEqual(e.brokerPort, 1883)
        XCTAssertTrue(e.uhren.isEmpty)
        XCTAssertTrue(e.ziele.isEmpty)
        UserDefaults.standard.removePersistentDomain(forName: bereich)
    }

    /// Das Kennwort wird erst beim Zugriff geholt, nicht beim Lesen der
    /// Einstellungen. Sonst fragt der Schluesselbund auch dann, wenn gar nicht
    /// gesendet wird — `mqtttc002 uhren` etwa.
    func testKennwortWirdErstBeiBedarfGelesen() {
        let bereich = "test-\(UUID().uuidString)"
        defer { Schluesselbund.loeschen("broker", dienst: bereich) }

        let e = Einstellungen.gelesen(bereich: bereich)
        Schluesselbund.setzen("geheim", fuer: "broker", dienst: bereich)

        XCTAssertEqual(e.kennwort, "geheim",
                       "Eifrig gelesen waere es hier nil — der Eintrag entstand danach.")
    }
}
