import XCTest
@testable import TC002Core

/// Die HTTP-Seite einer AWTRIX NG — gegen den `URLProtocol`-Doppelgaenger aus
/// `GeraetTests`. Kein Netz, kein Geraet.
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

    private func geraet() -> Geraet {
        Geraet(host: "10.0.0.9", sitzung: sitzung())
    }

    override func setUp() {
        Doppelgaenger.antworten = [
            "/api/v1/device": #"{"version":"1.1.0","uid":"a4cf12ab34cd","boardType":"awtrixng","soc":"esp32","hostname":"pixeluhr","mqtt":{"enabled":true,"state":"connected","host":"broker"}}"#,
            "/api/v1/system": #"{"mqttPrefix":"wohnzimmer/uhr","webPort":80}"#,
            "/api/v1/apps": #"[{"name":"Time","enabled":true,"inLoop":true,"slot":0,"present":true,"origin":"builtin"},{"name":"meldung2","enabled":true,"inLoop":true,"slot":1,"present":true,"origin":"pushed"},{"name":"tempo","enabled":true,"inLoop":false,"slot":null,"present":true,"origin":"script"}]"#,
            "/api/v1/capabilities": #"{"display":{"width":52,"height":16}}"#,
        ]
        Doppelgaenger.statusCodes = [:]
        Doppelgaenger.gesendeteRuempfe = [:]
        Doppelgaenger.abfragen = [:]
        Doppelgaenger.methoden = [:]
        Doppelgaenger.inhaltstypen = [:]
        Doppelgaenger.pfade = []
    }

    // MARK: - Das Praefix

    /// NG nimmt `mqttPrefix` genau so, wie es dasteht. Haengte die App etwas
    /// an, schriebe sie auf ein Thema, das kein Geraet abonniert — und NG
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
    /// zwoelfstellige MAC. Es gibt also keinen Fall „kein Praefix
    /// eingestellt".
    func testOhneEingestelltesPraefixGiltDieUid() throws {
        Doppelgaenger.antworten["/api/v1/system"] = #"{"mqttPrefix":""}"#
        XCTAssertEqual(try geraet().themenPraefix(), "a4cf12ab34cd")
    }

    /// Die MAC kommt aus `uid`.
    func testDieMacIstDieUid() throws {
        XCTAssertEqual(try geraet().praefixUndBasis().mac, "a4cf12ab34cd")
    }

    /// Ob NG am Broker haengt, steht in der Geraeteauskunft — einen eigenen
    /// Endpunkt wie `/getMqttStatus` gibt es nicht.
    func testVerbindungsstandKommtAusDerGeraeteauskunft() throws {
        XCTAssertTrue(try geraet().verbunden())
        Doppelgaenger.antworten["/api/v1/device"] = #"{"boardType":"awtrixng","mqtt":{"state":"offline","error":"badCredentials"}}"#
        XCTAssertFalse(try geraet().verbunden())
    }

    // MARK: - Die Masse der Anzeige

    /// Das Mass wird geholt, nicht angenommen: `display.width` und
    /// `display.height` aus `/api/v1/capabilities`. Eine App, die 52 × 16
    /// einprogrammiert, zeigte auf einer anderen Anzeige das falsche Bild.
    func testDasMassKommtAusDenCapabilities() throws {
        XCTAssertTrue(try geraet().praefixUndBasis().mass! == (52, 16))

        Doppelgaenger.antworten["/api/v1/capabilities"] = #"{"display":{"width":64,"height":8}}"#
        XCTAssertTrue(try geraet().anzeigemass()! == (64, 8))
    }

    /// Was keine brauchbare Zahl ist, gilt als nicht beantwortet: Es bleibt
    /// die Vorgabe, statt gegen einen Ausreisser getauscht zu werden.
    func testEinUnbrauchbaresMassGiltAlsNichtBeantwortet() throws {
        for antwort in [#"{"display":{"width":0,"height":16}}"#,
                        #"{"display":{"width":52}}"#,
                        #"{}"#] {
            Doppelgaenger.antworten["/api/v1/capabilities"] = antwort
            XCTAssertNil(try geraet().anzeigemass(), antwort)
        }
    }

    /// Zahlen aus der Geraeteantwort bestimmen Pixelfelder: Ausserhalb dessen,
    /// was NG-Geraete haben, gilt die Antwort als nicht gegeben.
    func testExtremeMasseWerdenVerworfen() throws {
        let faelle = [
            #"{"display":{"width":2000000000,"height":16}}"#,
            #"{"display":{"width":52,"height":1000}}"#,
            #"{"display":{"width":-52,"height":16}}"#,
            #"{"display":{"width":52,"height":-1}}"#,
            #"{"display":{"width":0,"height":0}}"#,
            #"{"display":{"width":52.5,"height":16}}"#,
            #"{"display":{"width":"52","height":16}}"#,
            #"{"display":{"width":128,"height":16,"maxPixels":832}}"#,
            #"{"display":{"width":9223372036854775807,"height":9223372036854775807}}"#,
        ]
        for antwort in faelle {
            Doppelgaenger.antworten["/api/v1/capabilities"] = antwort
            XCTAssertNil(try geraet().anzeigemass(), antwort)
        }
        Doppelgaenger.antworten["/api/v1/capabilities"] = #"{"display":{"width":128,"height":16,"maxPixels":2000000000}}"#
        XCTAssertTrue(try geraet().anzeigemass()! == (128, 16))
    }

    /// Eine alte oder beschaedigte Einstellungsdatei darf die Vorgabe nicht
    /// aushebeln.
    func testEinUnplausiblesGespeichertesMassFaelltAufDieVorgabe() {
        let uhr = Uhr(name: "x", host: "h", panelbreite: 2_000_000_000, panelhoehe: 16)
        XCTAssertTrue(uhr.anzeigemass == (52, 16))
    }

    // MARK: - Die Belegung

    /// `origin` trennt unsere Anzeigen von den eingebauten und von
    /// Berry-Skripten; die
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

    /// `{}` auf `PUT` loescht nicht, sondern antwortet `422` und verweist auf
    /// eine eigene Route — `DELETE /api/v1/apps/{name}`, ohne Rumpf.
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

}
