import XCTest
@testable import TC002Core

/// Die HTTP-Seite einer AWTRIX NG — gegen denselben `URLProtocol`-Doppelgaenger
/// wie `GeraetTests`. Kein Netz, kein Geraet.
///
/// Die Antworten stammen aus `docs/awtrix-ng-protokoll.md` §7, dort mit 🔬
/// gekennzeichnet: am Geraet des Auftraggebers gelesen. Kennungen, Adressen und
/// Namen sind darin bereits durch Platzhalter ersetzt.
final class GeraetNGTests: XCTestCase {

    private func sitzung() -> URLSession {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [Doppelgaenger.self]
        return URLSession(configuration: k)
    }

    private func geraet(_ typ: Geraetetyp = .awtrixNG) -> Geraet {
        Geraet(host: "10.0.0.9", sitzung: sitzung(), typ: typ)
    }

    override func setUp() {
        Doppelgaenger.antworten = [
            "/api/v1/device": #"{"version":"1.1.0","uid":"a4cf12ab34cd","boardType":"awtrixng","soc":"esp32","hostname":"pixeluhr","mqtt":{"enabled":true,"state":"connected","host":"broker"}}"#,
            "/api/v1/system": #"{"mqttPrefix":"wohnzimmer/uhr","panelWidth":32,"panels":1,"webPort":80}"#,
            "/api/v1/apps": #"[{"name":"Time","enabled":true,"inLoop":true,"slot":0,"present":true,"origin":"builtin"},{"name":"meldung2","enabled":true,"inLoop":true,"slot":1,"present":true,"origin":"pushed"},{"name":"tempo","enabled":true,"inLoop":false,"slot":null,"present":true,"origin":"script"}]"#,
            // Die Werksfirmware, damit die Erkennung eine Gegenprobe hat.
            "/getBase": #"{"devSn":"TC002-TESTGERAET01","mac":"aabbccdda86b","mcuVer":"V1.0.17","appVer":"1.1.1"}"#,
        ]
        Doppelgaenger.statusCodes = [:]
        Doppelgaenger.gesendeteRuempfe = [:]
        Doppelgaenger.abfragen = [:]
        Doppelgaenger.methoden = [:]
        Doppelgaenger.inhaltstypen = [:]
        Doppelgaenger.pfade = []
    }

    // MARK: - Welche Firmware antwortet da

    /// `GET /api/v1/device` gibt es nur bei NG, und nur dort steht `boardType`
    /// darin.
    func testEineNGAntwortWirdErkannt() throws {
        XCTAssertEqual(try geraet(.tc002).erkannteArt(), .awtrixNG)
    }

    /// Die Werksfirmware kennt den Pfad nicht — was immer sie darauf antwortet,
    /// es ist kein JSON mit `boardType`.
    func testEinVierhundertvierIstDieWerksfirmware() throws {
        Doppelgaenger.statusCodes["/api/v1/device"] = 404
        XCTAssertEqual(try geraet(.tc002).erkannteArt(), .tc002)
    }

    /// Dasselbe fuer die Weboberflaeche statt eines JSON.
    func testEineAntwortOhneBoardTypeIstDieWerksfirmware() throws {
        Doppelgaenger.antworten["/api/v1/device"] = "<html><body>Ulanzi</body></html>"
        XCTAssertEqual(try geraet(.tc002).erkannteArt(), .tc002)
    }

    /// Ein `401` wird nicht geraten: NG kann seine ganze Schnittstelle hinter
    /// eine Anmeldung stellen; dann ist der Typ nicht festzustellen, und
    /// „also eine TC002" waere die falsche Antwort auf eine Frage, die gar
    /// nicht beantwortet wurde.
    func testEineAnmeldepflichtWirdGemeldetUndNichtGeraten() {
        Doppelgaenger.statusCodes["/api/v1/device"] = 401
        XCTAssertThrowsError(try geraet(.tc002).erkannteArt()) { fehler in
            guard case GeraetFehler.anmeldungNoetig = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
        }
    }

    // MARK: - Das Praefix

    /// Die Werksfirmware haengt `_` und die letzten vier MAC-Stellen an; NG
    /// nimmt `mqttPrefix` genau so, wie es dasteht. Bliebe die Formel stehen,
    /// schriebe die App auf ein Thema, das kein Geraet abonniert — und NG
    /// antwortet darauf gar nicht.
    func testDasNGPraefixBekommtKeinenMacAnhang() throws {
        let ergebnis = try geraet().praefixUndBasis()
        XCTAssertEqual(ergebnis.praefix, "wohnzimmer/uhr")
        XCTAssertFalse(ergebnis.praefix.contains("_"), "hier darf nichts angehängt werden")
    }

    /// Das Praefix darf mehrere Themenebenen enthalten — am Geraet so
    /// vorgefunden. Ein Schraegstrich ist kein Sonderfall, sondern der Normalfall.
    func testEinPraefixMitSchraegstrichBleibtStehen() throws {
        Doppelgaenger.antworten["/api/v1/system"] = #"{"mqttPrefix":"haus/flur/awtrix"}"#
        XCTAssertEqual(try geraet().themenPraefix(), "haus/flur/awtrix")
    }

    /// Ist `mqttPrefix` leer, tritt die uid an seine Stelle — die
    /// zwoelfstellige MAC. Anders als bei der Werksfirmware gibt es also
    /// keinen Fall „kein Praefix eingestellt".
    func testOhneEingestelltesPraefixGiltDieUid() throws {
        Doppelgaenger.antworten["/api/v1/system"] = #"{"mqttPrefix":""}"#
        XCTAssertEqual(try geraet().themenPraefix(), "a4cf12ab34cd")
    }

    /// Die MAC kommt aus `uid` und nicht aus `/getBase` — den Pfad gibt es hier
    /// nicht.
    func testDieMacIstDieUid() throws {
        XCTAssertEqual(try geraet().praefixUndBasis().basis.mac, "a4cf12ab34cd")
        XCTAssertFalse(Doppelgaenger.pfade.contains("/getBase"))
    }

    /// Ob NG am Broker haengt, steht in der Geraeteauskunft — einen eigenen
    /// Endpunkt wie `/getMqttStatus` gibt es nicht.
    func testVerbindungsstandKommtAusDerGeraeteauskunft() throws {
        XCTAssertTrue(try geraet().verbunden())
        Doppelgaenger.antworten["/api/v1/device"] = #"{"boardType":"awtrixng","mqtt":{"state":"offline","error":"badCredentials"}}"#
        XCTAssertFalse(try geraet().verbunden())
    }

    // MARK: - Die Masse der Anzeige

    /// Die Breite wird geholt, nicht angenommen: Die Hoehe ist fest 8, die
    /// Breite ist `panelWidth × panels` — eine 64er Kette ist vorgesehen, und
    /// eine App, die 32 einprogrammiert, zeigte dort das falsche Bild.
    func testDieAnzeigenbreiteKommtVomGeraet() throws {
        XCTAssertEqual(try geraet().praefixUndBasis().breite, 32)

        Doppelgaenger.antworten["/api/v1/system"] =
            #"{"mqttPrefix":"p","panelWidth":32,"panels":2}"#
        XCTAssertEqual(try geraet().praefixUndBasis().breite, 64, "panelWidth × panels")
    }

    /// Was ausserhalb von 32…128 steht, ist keine Breite, sondern ein
    /// Missverstaendnis: Das Geraet weist solche Werte selbst mit `422` ab. Als
    /// „nicht beantwortet" gelesen bleibt die zuletzt bekannte Breite stehen,
    /// statt gegen einen Ausreisser getauscht zu werden.
    func testEineUnmoeglicheBreiteGiltAlsNichtBeantwortet() throws {
        Doppelgaenger.antworten["/api/v1/system"] = #"{"mqttPrefix":"p","panelWidth":8,"panels":1}"#
        XCTAssertNil(try geraet().praefixUndBasis().breite)

        Doppelgaenger.antworten["/api/v1/system"] = #"{"mqttPrefix":"p","panelWidth":256,"panels":1}"#
        XCTAssertNil(try geraet().praefixUndBasis().breite)

        Doppelgaenger.antworten["/api/v1/system"] = #"{"mqttPrefix":"p"}"#
        XCTAssertNil(try geraet().praefixUndBasis().breite)
    }

    /// Die Werksfirmware wird danach gar nicht erst gefragt — sie ist fest
    /// 52×16, und `/api/v1/system` gibt es dort nicht.
    func testDieWerksfirmwareWirdNichtNachIhrerBreiteGefragt() throws {
        Doppelgaenger.antworten["/getMqttConfig"] = #"{"isMqtt":true,"mqtt_prefix":"awtrix"}"#
        XCTAssertNil(try Geraet(host: "10.0.0.1", sitzung: sitzung(), typ: .tc002)
            .praefixUndBasis().breite)
        XCTAssertFalse(Doppelgaenger.pfade.contains("/api/v1/system"))
    }

    // MARK: - Die Belegung

    /// `origin` trennt unsere Anzeigen von den eingebauten und von
    /// Berry-Skripten — genauer als `customList` der Werksfirmware; die
    /// eingebauten mitzuzaehlen hiesse, Bloecke als belegt zu zeigen, weil das
    /// Geraet eine Uhrzeit anzeigt.
    func testNurDieSelbstAbgelegtenAnzeigenZaehlen() throws {
        XCTAssertEqual(try geraet().anzeigennamen(), ["meldung2"])
    }

    /// Ein Inventar ohne eigene Anzeigen ist eine Auskunft — „es liegt keine
    /// darauf" —, kein Fehler.
    func testEinInventarOhneEigeneAnzeigenIstLeerUndKeinFehler() throws {
        Doppelgaenger.antworten["/api/v1/apps"] = #"[{"name":"Time","origin":"builtin"}]"#
        XCTAssertEqual(try geraet().anzeigennamen(), [])
    }

    /// Etwas, das kein Inventar ist, darf nicht als „nichts darauf" durchgehen —
    /// das raeumte in `AppZustand` die Belegung ab.
    func testEtwasAnderesAlsEinInventarIstEinFehler() {
        Doppelgaenger.antworten["/api/v1/apps"] = #"{"error":{"code":"notFound"}}"#
        XCTAssertThrowsError(try geraet().anzeigennamen()) { fehler in
            XCTAssertTrue(fehler is GeraetFehler, "war stattdessen \(type(of: fehler))")
        }
    }

    // MARK: - Anlegen, loeschen, umschalten

    /// Der Name steht bei NG im Pfad, nicht in einer Abfrage, und die
    /// Methode ist `PUT`. `Content-Type: application/json` ist dabei Pflicht:
    /// Ohne ihn wird abgewiesen, bevor der Rumpf gelesen wird.
    func testAnlegenGehtPerPutAufDenNamenImPfad() throws {
        try geraet().anzeigeSetzen(#"{"text":"hallo"}"#, name: "meldung1")
        XCTAssertEqual(Doppelgaenger.pfade, ["/api/v1/apps/pushed/meldung1"])
        XCTAssertEqual(Doppelgaenger.methoden["/api/v1/apps/pushed/meldung1"], "PUT")
        XCTAssertEqual(Doppelgaenger.inhaltstypen["/api/v1/apps/pushed/meldung1"], "application/json")
        XCTAssertEqual(Doppelgaenger.gesendeteRuempfe["/api/v1/apps/pushed/meldung1"],
                       #"{"text":"hallo"}"#)
    }

    /// Ueber HTTP loescht bei der Werksfirmware der Rumpf `{}`; bei NG
    /// antwortet genau das `422` und verweist auf eine eigene Route —
    /// `DELETE /api/v1/apps/{name}`, ohne Rumpf.
    func testLoeschenGehtPerDeleteUndOhneRumpf() throws {
        try geraet().anzeigeLoeschen(name: "meldung1")
        XCTAssertEqual(Doppelgaenger.pfade, ["/api/v1/apps/meldung1"])
        XCTAssertEqual(Doppelgaenger.methoden["/api/v1/apps/meldung1"], "DELETE")
        XCTAssertNil(Doppelgaenger.gesendeteRuempfe["/api/v1/apps/meldung1"])
    }

    /// Umschalten ist ein `PUT` auf `/api/v1/apps/active` mit dem Namen im
    /// Rumpf — dieselben Bytes, die ueber MQTT auf `cmd/apps/switch` gingen.
    func testUmschaltenGehtPerPutMitDemNamenImRumpf() throws {
        try geraet().umschalten(auf: "meldung2")
        XCTAssertEqual(Doppelgaenger.pfade, ["/api/v1/apps/active"])
        XCTAssertEqual(Doppelgaenger.methoden["/api/v1/apps/active"], "PUT")
        XCTAssertEqual(Doppelgaenger.gesendeteRuempfe["/api/v1/apps/active"], #"{"name":"meldung2"}"#)
    }

    /// Die Begruendung steht im Rumpf einer Antwort mit Fehlerstatus. Wer den
    /// Status vorher zum Fehler macht, wirft sie weg und meldet „Status 422"
    /// statt „validationFailed im Feld durationMs".
    func testDieBegruendungAusDemFehlerrumpfKommtDurch() {
        Doppelgaenger.statusCodes["/api/v1/apps/pushed/meldung1"] = 422
        Doppelgaenger.antworten["/api/v1/apps/pushed/meldung1"] =
            #"{"error":{"code":"validationFailed","message":"invalid value","field":"durationMs"}}"#

        XCTAssertThrowsError(try geraet().anzeigeSetzen("{}", name: "meldung1")) { fehler in
            guard case GeraetFehler.ngAbgewiesen(let status, let code, let feld) = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
            XCTAssertEqual(status, 422)
            XCTAssertEqual(code, "validationFailed")
            XCTAssertEqual(feld, "durationMs")
        }
    }

    /// Die Gegenprobe, damit die Pruefung oben nicht alles abweist.
    func testEineAngenommeneAnfrageWirftNicht() {
        XCTAssertNoThrow(try geraet().anzeigeSetzen(#"{"text":"x"}"#, name: "meldung1"))
    }

    /// Eine ungueltige Adresse ist kein Befund. Sie stillschweigend zur
    /// Werksfirmware zu erklaeren verdeckte den eigentlichen Fehler — und der
    /// Anwender saehe „ist eine Ulanzi TC002" statt „da steht ein Leerzeichen
    /// in der Adresse".
    func testEineUngueltigeAdresseWirdNichtZurWerksfirmware() {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [Doppelgaenger.self]
        let krumm = Geraet(host: "a b", sitzung: URLSession(configuration: k))
        XCTAssertThrowsError(try krumm.erkannteArt()) { fehler in
            guard case GeraetFehler.ungueltigeAdresse = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
        }
    }

}
