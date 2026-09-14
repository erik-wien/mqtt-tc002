import XCTest
@testable import TC002Core

/// Die virtuelle Uhr soll sich verhalten wie eine echte — und **nicht** wie
/// eine, gegen die es sich bequem entwickelt. Jeder Test hier hält eine
/// Eigenheit der Werksfirmware fest, die in `Geraet` schon angeschrieben steht.
final class VirtuelleuhrTests: XCTestCase {
    private func antwort(_ a: Virtuelleuhr.Anfrage,
                         _ zustand: inout Uhrzustand) -> [String: Any] {
        let ergebnis = Virtuelleuhr.beantworten(a, &zustand)
        return (try? JSONSerialization.jsonObject(with: ergebnis.koerper)) as? [String: Any] ?? [:]
    }

    /// **Das Themen-Präfix ist nicht das eingestellte.** Die Firmware hängt
    /// einen Unterstrich und die letzten vier Stellen der MAC an; wer dagegen
    /// entwickelt, ohne dass die virtuelle Uhr das tut, übt an einer
    /// Vereinfachung und scheitert am Gerät.
    func testDasThemenpraefixWirdWieInDerFirmwareGebildet() {
        let zustand = Uhrzustand(praefix: "tc002", mac: "aabbccdda86b")
        XCTAssertEqual(zustand.themenpraefix, "tc002_a86b")
    }

    func testGetBaseNenntDieMac() {
        var zustand = Uhrzustand(mac: "aabbccdda86b")
        let d = antwort(.init("GET", "/getBase"), &zustand)
        XCTAssertEqual(d["mac"] as? String, "aabbccdda86b")
    }

    func testGetMqttConfigNenntDasEingestelltePraefix() {
        var zustand = Uhrzustand(praefix: "meins")
        let d = antwort(.init("GET", "/getMqttConfig"), &zustand)
        XCTAssertEqual(d["mqtt_prefix"] as? String, "meins")
    }

    /// **Alles Unbekannte ist 404.** Daran erkennt `Geraet.erkannteArt` die
    /// Werksfirmware: Antwortete `/api/v1/device` irgendetwas, gälte die
    /// virtuelle Uhr als AWTRIX NG — und die App schickte ihr Nutzlasten, die
    /// eine Ulanzi nie bekäme.
    func testDieNgAuskunftGibtEsNicht() {
        var zustand = Uhrzustand()
        let ergebnis = Virtuelleuhr.beantworten(.init("GET", "/api/v1/device"), &zustand)
        XCTAssertEqual(ergebnis.status, 404)
    }

    func testEineAnzeigeKommtAnUndStehtInDerListe() {
        var zustand = Uhrzustand()
        let nutzlast = Data(#"{"text":"hallo"}"#.utf8)
        _ = Virtuelleuhr.beantworten(.init("POST", "/api/custom", abfrage: ["name": "meldung1"],
                                           koerper: nutzlast), &zustand)
        XCTAssertEqual(zustand.anzeigen["meldung1"], nutzlast)
        XCTAssertEqual(zustand.aktuelle, "meldung1")

        let liste = antwort(.init("GET", "/api/customList"), &zustand)
        XCTAssertEqual(liste["apps"] as? [String], ["meldung1"])
        XCTAssertEqual(liste["count"] as? Int, 1)
    }

    /// **`{}` löscht, die leere Nutzlast nicht** — über HTTP. Über MQTT ist es
    /// genau umgekehrt. Diese Verwechslung steht in `Geraet.anzeigeLoeschen`
    /// angeschrieben, und die virtuelle Uhr muss sie mitmachen.
    func testEinLeeresObjektLoeschtDieAnzeige() {
        var zustand = Uhrzustand()
        _ = Virtuelleuhr.beantworten(.init("POST", "/api/custom", abfrage: ["name": "meldung1"],
                                           koerper: Data(#"{"text":"hallo"}"#.utf8)), &zustand)
        _ = Virtuelleuhr.beantworten(.init("POST", "/api/custom", abfrage: ["name": "meldung1"],
                                           koerper: Data("{}".utf8)), &zustand)
        XCTAssertNil(zustand.anzeigen["meldung1"])
        XCTAssertEqual(zustand.reihenfolge, [])
        XCTAssertNil(zustand.aktuelle)
    }

    /// Die Reihenfolge ist die des Eintreffens, nicht die eines Wörterbuchs —
    /// danach blättert die Anzeige.
    func testDieReihenfolgeIstDieDesEintreffens() {
        var zustand = Uhrzustand()
        for name in ["meldung3", "meldung1", "meldung2"] {
            _ = Virtuelleuhr.beantworten(.init("POST", "/api/custom", abfrage: ["name": name],
                                               koerper: Data(#"{"text":"x"}"#.utf8)), &zustand)
        }
        XCTAssertEqual(zustand.reihenfolge, ["meldung3", "meldung1", "meldung2"])
        // Dieselbe Anzeige noch einmal reiht sich nicht ein zweites Mal ein.
        _ = Virtuelleuhr.beantworten(.init("POST", "/api/custom", abfrage: ["name": "meldung3"],
                                           koerper: Data(#"{"text":"y"}"#.utf8)), &zustand)
        XCTAssertEqual(zustand.reihenfolge, ["meldung3", "meldung1", "meldung2"])
    }

    /// `/setConfig` bekommt die **ganze** Konfiguration zurück; gelesen wird
    /// daraus, was diese Uhr führt.
    func testSetConfigAendertDenSeitenwechsel() {
        var zustand = Uhrzustand(seitenwechsel: 10, scrolltempo: 100)
        let koerper = Data(#"{"carouselSpeed":30,"scrollSpeed":80,"anderes":1}"#.utf8)
        _ = Virtuelleuhr.beantworten(.init("POST", "/setConfig", koerper: koerper), &zustand)
        XCTAssertEqual(zustand.seitenwechsel, 30)
        XCTAssertEqual(zustand.scrolltempo, 80)
        let gelesen = antwort(.init("GET", "/getConfig"), &zustand)
        XCTAssertEqual(gelesen["carouselSpeed"] as? Int, 30)
    }

    func testUmschaltenAufEineUnbekannteAnzeigeGehtNicht() {
        var zustand = Uhrzustand()
        let d = antwort(.init("POST", "/api/switchDiyApp", abfrage: ["name": "gibtsnicht"]), &zustand)
        XCTAssertEqual(d["code"] as? Int, 404)
        XCTAssertNil(zustand.aktuelle)
    }

    /// Die Quittung der Werksfirmware steht im **Rumpf**, nicht im Status —
    /// `Geraet.anAnzeige` liest `code` und wirft erst dann.
    func testDieQuittungStehtImRumpf() {
        var zustand = Uhrzustand()
        let ergebnis = Virtuelleuhr.beantworten(.init("POST", "/api/custom",
                                                      abfrage: ["name": "meldung1"],
                                                      koerper: Data(#"{"text":"x"}"#.utf8)), &zustand)
        XCTAssertEqual(ergebnis.status, 200)
        let d = (try? JSONSerialization.jsonObject(with: ergebnis.koerper)) as? [String: Any]
        XCTAssertEqual(d?["code"] as? Int, 200)
    }
}

/// Das Zerlegen roher Bytes zu einer Anfrage — die einzige Stelle im
/// `Uhrenserver`, die etwas rechnet und nicht bloß Netz ist.
final class UhrenserverZerlegenTests: XCTestCase {
    private func bytes(_ text: String) -> Data { Data(text.utf8) }

    func testEineVollstaendigeAnfrageWirdZerlegt() throws {
        let roh = bytes("POST /api/custom?name=meldung1 HTTP/1.1\r\n"
                        + "Host: 127.0.0.1:8752\r\nContent-Length: 16\r\n\r\n"
                        + #"{"text":"hallo"}"#)
        let a = try XCTUnwrap(Uhrenserver.zerlegen(roh))
        XCTAssertEqual(a.methode, "POST")
        XCTAssertEqual(a.pfad, "/api/custom")
        XCTAssertEqual(a.abfrage["name"], "meldung1")
        XCTAssertEqual(String(decoding: a.koerper, as: UTF8.self), #"{"text":"hallo"}"#)
    }

    /// **Unvollständig heißt weiterlesen, nicht raten.** Ein Rumpf kommt in
    /// mehreren Paketen; wer beim ersten antwortet, verwirft den Rest.
    func testEinHalberRumpfIstNochKeineAnfrage() {
        let ohneRumpf = bytes("POST /api/custom?name=a HTTP/1.1\r\nContent-Length: 20\r\n\r\n{\"te")
        XCTAssertNil(Uhrenserver.zerlegen(ohneRumpf))
        let ohneKopfende = bytes("GET /getBase HTTP/1.1\r\nHost: x\r\n")
        XCTAssertNil(Uhrenserver.zerlegen(ohneKopfende))
    }

    /// Ein Anzeigename darf alles enthalten, was jemand eintippt — er kommt
    /// deshalb kodiert an und muss dekodiert wieder herauskommen.
    func testEinKodierterNameWirdDekodiert() throws {
        let roh = bytes("POST /api/switchDiyApp?name=mein%20Platz HTTP/1.1\r\nContent-Length: 0\r\n\r\n")
        let a = try XCTUnwrap(Uhrenserver.zerlegen(roh))
        XCTAssertEqual(a.abfrage["name"], "mein Platz")
    }

    /// Ohne Rumpf und ohne `Content-Length` — so kommt jedes `GET`.
    func testEinGetOhneRumpf() throws {
        let a = try XCTUnwrap(Uhrenserver.zerlegen(bytes("GET /getConfig HTTP/1.1\r\nHost: x\r\n\r\n")))
        XCTAssertEqual(a.methode, "GET")
        XCTAssertEqual(a.pfad, "/getConfig")
        XCTAssertTrue(a.koerper.isEmpty)
    }
}

/// **Die Probe aufs Ganze**: `Geraet` spricht mit der virtuellen Uhr über
/// einen echten Port — dieselbe `URLSession`, dieselben Pfade, dieselbe
/// Auswertung wie am Gerät. Nichts daran ist ein Doppelgänger.
///
/// Kein Verstoß gegen „das echte Gerät ist in Tests tabu": Hier hört diese
/// Testreihe sich selbst zu, auf `127.0.0.1` und einem Port, den sie selbst
/// aufmacht. Es geht kein Byte ins Hausnetz.
final class VirtuelleuhrAmDrahtTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    /// Sucht sich einen freien Port — ein fester waere in einer Testreihe, die
    /// zweimal zugleich laeuft, ein Wettlauf.
    private func gestartet(_ zustand: Uhrzustand) throws -> (Uhrenserver, String) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: zustand)
            do {
                try s.starten()
                // Dem Lauscher einen Augenblick geben, ehe verbunden wird.
                Thread.sleep(forTimeInterval: 0.05)
                server = s
                return (s, "127.0.0.1:\(port)")
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    func testDieAppLiestPraefixUndBasisVonDerVirtuellenUhr() throws {
        let (_, adresse) = try gestartet(Uhrzustand(praefix: "tc002", mac: "aabbccdda86b"))
        let geraet = Geraet(host: adresse)
        let ergebnis = try geraet.praefixUndBasis()
        // Dieselbe Formel wie in der Firmware — und der Grund, warum die
        // virtuelle Uhr sie mitmachen muss.
        XCTAssertEqual(ergebnis.praefix, "tc002_a86b")
        XCTAssertEqual(ergebnis.basis.mac, "aabbccdda86b")
    }

    /// Die Geraeteart wird **erkannt**, nicht angenommen: Die virtuelle Uhr
    /// antwortet auf `/api/v1/device` mit 404, und genau daran haengt es.
    func testDieVirtuelleUhrGiltAlsWerksfirmware() throws {
        let (_, adresse) = try gestartet(Uhrzustand())
        XCTAssertEqual(try Geraet(host: adresse).erkannteArt(), .tc002)
    }

    func testSendenLoeschenUndDieListeDazwischen() throws {
        let (server, adresse) = try gestartet(Uhrzustand())
        let geraet = Geraet(host: adresse)

        try geraet.anzeigeSetzen(#"{"text":"hallo"}"#, name: "meldung1")
        XCTAssertEqual(try geraet.anzeigennamen(), ["meldung1"])
        XCTAssertEqual(server.zustand.anzeigen["meldung1"],
                       Data(#"{"text":"hallo"}"#.utf8))

        try geraet.umschalten(auf: "meldung1")
        XCTAssertEqual(server.zustand.aktuelle, "meldung1")

        try geraet.anzeigeLoeschen(name: "meldung1")
        XCTAssertEqual(try geraet.anzeigennamen(), [])
    }

    func testDerSeitenwechselLaesstSichSetzenUndLesen() throws {
        let (server, adresse) = try gestartet(Uhrzustand(seitenwechsel: 10))
        try Geraet(host: adresse).konfigurationSetzen("carouselSpeed", 30)
        XCTAssertEqual(server.zustand.seitenwechsel, 30)
    }
}
