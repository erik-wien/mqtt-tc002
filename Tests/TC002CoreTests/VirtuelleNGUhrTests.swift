import XCTest
@testable import TC002Core

/// Die virtuelle NG-Uhr als reine Funktion. Erwartungen aus der Herstellerdoku
/// (HTTP-Referenz, Fehlerliste) und einer Messung an NG 1.2.2 auf der TC002.
final class VirtuelleNGUhrTests: XCTestCase {
    private let json = ["content-type": "application/json"]

    private struct Ergebnis {
        var status: Int
        var typ: String
        var wert: JSONWert
        var objekt: [String: JSONWert] {
            if case .objekt(let o) = wert { return o }
            return [:]
        }
        var fehler: [String: JSONWert] {
            if case .objekt(let o)? = objekt["error"] { return o }
            return [:]
        }
    }

    private func senden(_ methode: String, _ pfad: String, _ z: inout NGUhrzustand) -> Ergebnis {
        senden(methode, pfad, "", &z)
    }

    private func senden(_ methode: String, _ pfad: String, _ rumpf: String,
                        kopf: [String: String]? = nil, _ z: inout NGUhrzustand) -> Ergebnis {
        let a = Virtuelleuhr.Anfrage(methode, "/api/v1" + pfad, koerper: Data(rumpf.utf8),
                                     kopf: kopf ?? json)
        let r = VirtuelleNGUhr.beantworten(a, &z)
        return Ergebnis(status: r.status, typ: r.inhaltstyp,
                        wert: JSONWert.lesen(r.koerper) ?? .null)
    }

    private func pruefeFehler(_ e: Ergebnis, _ status: Int, _ code: String,
                              meldung: String? = nil, feld: String? = nil,
                              datei: StaticString = #filePath, zeile: UInt = #line) {
        XCTAssertEqual(e.status, status, file: datei, line: zeile)
        XCTAssertEqual(e.fehler["code"], .text(code), file: datei, line: zeile)
        if let meldung { XCTAssertEqual(e.fehler["message"], .text(meldung), file: datei, line: zeile) }
        XCTAssertEqual(e.fehler["field"], feld.map { .text($0) }, file: datei, line: zeile)
    }

    private func pruefeOK(_ e: Ergebnis, datei: StaticString = #filePath, zeile: UInt = #line) {
        XCTAssertEqual(e.status, 200, file: datei, line: zeile)
        XCTAssertEqual(e.wert, .objekt(["ok": .bool(true)]), file: datei, line: zeile)
    }

    // MARK: Lesen

    func testGeraetNenntFassungPlatineUndZustand() {
        var z = NGUhrzustand()
        let e = senden("GET", "/device", &z)
        XCTAssertEqual(e.status, 200)
        XCTAssertEqual(e.typ, "application/json")
        XCTAssertEqual(e.objekt["version"], .text("1.2.2"))
        XCTAssertEqual(e.objekt["boardType"], .text("tc002"))
        XCTAssertEqual(e.objekt["currentApp"], .text("Time"))
        XCTAssertEqual(e.objekt["brightness"], .zahl(128))
        XCTAssertEqual(e.objekt["messageCount"], .zahl(0))
        guard case .liste(let ind)? = e.objekt["indicators"] else { return XCTFail() }
        XCTAssertEqual(ind.count, 3)
    }

    func testVersion() {
        var z = NGUhrzustand()
        XCTAssertEqual(senden("GET", "/version", &z).wert, .objekt(["version": .text("1.2.2")]))
    }

    func testEinstellungenHabenDieGemesseneVorgabe() {
        var z = NGUhrzustand()
        let e = senden("GET", "/settings", &z)
        XCTAssertEqual(e.objekt["brightness"], .zahl(128))
        XCTAssertEqual(e.objekt["transitionEffect"], .text("Rain"))
        XCTAssertEqual(e.objekt["timeColor"], .null)
        XCTAssertEqual(e.objekt.count, 46)
    }

    func testAnzeigeVorgabe() {
        var z = NGUhrzustand()
        let e = senden("GET", "/display", &z)
        XCTAssertEqual(e.objekt["power"], .bool(true))
        XCTAssertEqual(e.objekt["overlay"], .null)
        XCTAssertEqual(e.objekt["moodlight"], .null)
    }

    func testBildschirmIstSchwarzUndHat832Punkte() {
        var z = NGUhrzustand()
        let e = senden("GET", "/display/screen", &z)
        XCTAssertEqual(e.objekt["width"], .zahl(52))
        XCTAssertEqual(e.objekt["height"], .zahl(16))
        guard case .liste(let p)? = e.objekt["pixels"] else { return XCTFail() }
        XCTAssertEqual(p.count, 832)
        XCTAssertTrue(p.allSatisfy { $0 == .zahl(0) })
    }

    func testAppsFaehigkeitenUndTon() {
        var z = NGUhrzustand()
        guard case .liste(let apps) = senden("GET", "/apps", &z).wert else { return XCTFail() }
        XCTAssertEqual(apps.count, 2)
        guard case .objekt(let erste) = apps[0] else { return XCTFail() }
        XCTAssertEqual(erste["name"], .text("Time"))
        XCTAssertEqual(erste["origin"], .text("builtin"))
        XCTAssertEqual(erste["config"], .bool(true))

        let f = senden("GET", "/capabilities", &z)
        guard case .objekt(let d)? = f.objekt["display"] else { return XCTFail() }
        XCTAssertEqual(d["maxPixels"], .zahl(832))
        XCTAssertNotNil(senden("GET", "/audio", &z).objekt["radio"])
    }

    // MARK: Einstellungen

    func testPatchEinstellungenSchreibtUndGibtAlleZurueck() {
        var z = NGUhrzustand()
        let e = senden("PATCH", "/settings", ##"{"brightness":80,"timeColor":"#00FF00"}"##, &z)
        XCTAssertEqual(e.status, 200)
        XCTAssertEqual(e.objekt["brightness"], .zahl(80))
        XCTAssertEqual(e.objekt.count, 46)
        XCTAssertEqual(z.einstellungen["timeColor"], .text("#00FF00"))
        XCTAssertEqual(senden("GET", "/device", &z).objekt["brightness"], .zahl(80))
    }

    func testPatchEinstellungenPruefterstUndSchreibtDannNichtsBeiFehler() {
        var z = NGUhrzustand()
        let vorher = z
        pruefeFehler(senden("PATCH", "/settings", #"{"uppercase":false,"brightness":300}"#, &z),
                     422, "validationFailed", meldung: "out of range", feld: "brightness")
        pruefeFehler(senden("PATCH", "/settings", #"{"uppercase":false,"gibtsNicht":1}"#, &z),
                     422, "validationFailed", meldung: "unknown field", feld: "gibtsNicht")
        pruefeFehler(senden("PATCH", "/settings", #"{"uppercase":"ja"}"#, &z),
                     422, "validationFailed", feld: "uppercase")
        pruefeFehler(senden("PATCH", "/settings", #"{"brightness":-1}"#, &z),
                     422, "validationFailed", feld: "brightness")
        XCTAssertEqual(z, vorher)
    }

    func testPatchEinstellungenGrenzenUndKaputtesJSON() {
        var z = NGUhrzustand()
        pruefeFehler(senden("PATCH", "/settings", "{", &z), 400, "invalidJson")
        pruefeFehler(senden("PATCH", "/settings", "[]", &z), 422, "validationFailed", meldung: "body required")
        XCTAssertEqual(senden("PATCH", "/settings", #"{"brightness":0}"#, &z).status, 200)
        XCTAssertEqual(senden("PATCH", "/settings", #"{"brightness":255}"#, &z).status, 200)
    }

    // MARK: Anzeige

    func testPatchAnzeige() {
        var z = NGUhrzustand()
        pruefeOK(senden("PATCH", "/display", #"{"power":false,"overlay":"rain"}"#, &z))
        XCTAssertFalse(z.power)
        XCTAssertEqual(z.overlay, "rain")
        XCTAssertEqual(senden("GET", "/display", &z).objekt["overlay"], .text("rain"))
        pruefeOK(senden("PATCH", "/display", #"{"overlay":""}"#, &z))
        XCTAssertNil(z.overlay)
        XCTAssertEqual(senden("GET", "/device", &z).objekt["matrixPower"], .bool(false))
    }

    func testPatchAnzeigeFehlerAendernNichts() {
        var z = NGUhrzustand()
        let vorher = z
        pruefeFehler(senden("PATCH", "/display", #"{"power":"an"}"#, &z),
                     422, "validationFailed", meldung: "must be a boolean", feld: "power")
        pruefeFehler(senden("PATCH", "/display", #"{"power":false,"overlay":"hagel"}"#, &z),
                     422, "validationFailed", meldung: "unknown overlay", feld: "overlay")
        pruefeFehler(senden("PATCH", "/display", #"{"overlay":3}"#, &z),
                     422, "validationFailed", feld: "overlay")
        pruefeFehler(senden("PATCH", "/display", #"{"overlaySettings":{"palette":"Nix"}}"#, &z),
                     422, "validationFailed", feld: "overlaySettings.palette")
        pruefeFehler(senden("PATCH", "/display", #"{"overlaySettings":1}"#, &z),
                     422, "validationFailed", feld: "overlaySettings")
        XCTAssertEqual(z, vorher)
    }

    // MARK: Apps

    func testAppSendenListetLoeschtUndNameWirdGeprueft() {
        var z = NGUhrzustand()
        pruefeOK(senden("PUT", "/apps/pushed/wetter", #"{"text":"hi"}"#, &z))
        XCTAssertEqual(z.apps.map(\.name), ["Time", "Status", "wetter"])
        XCTAssertEqual(z.apps.last?.eingebaut, false)
        pruefeOK(senden("PUT", "/apps/pushed/wetter", #"{"text":"neu"}"#, &z))
        XCTAssertEqual(z.apps.count, 3)

        pruefeFehler(senden("PUT", "/apps/pushed/a%20b", #"{"text":"x"}"#, &z), 400, "invalidName", feld: "name")
        pruefeFehler(senden("PUT", "/apps/pushed/\(String(repeating: "a", count: 33))", #"{"text":"x"}"#, &z),
                     400, "invalidName", feld: "name")
        pruefeFehler(senden("PUT", "/apps/pushed/ok", "{", &z), 400, "invalidJson")
        pruefeFehler(senden("PUT", "/apps/pushed/ok", "", &z), 422, "validationFailed", meldung: "body required")
        pruefeFehler(senden("PUT", "/apps/pushed/ok", "{}", &z), 422, "validationFailed", meldung: "body required")
        XCTAssertEqual(z.apps.count, 3)

        pruefeOK(senden("DELETE", "/apps/wetter", &z))
        XCTAssertEqual(z.apps.map(\.name), ["Time", "Status"])
        pruefeOK(senden("DELETE", "/apps/gibtsnicht", &z))
        pruefeFehler(senden("DELETE", "/apps/a%20b", &z), 400, "invalidName", feld: "name")
    }

    func testEinFeldMachtNummerierteApps() {
        var z = NGUhrzustand()
        pruefeOK(senden("PUT", "/apps/pushed/reihe", #"[{"text":"a"},{"text":"b"}]"#, &z))
        XCTAssertEqual(z.apps.map(\.name), ["Time", "Status", "reihe0", "reihe1"])
        pruefeOK(senden("DELETE", "/apps/reihe", &z))
        XCTAssertEqual(z.apps.map(\.name), ["Time", "Status"])
    }

    func testDieGrenzeVonFuenfzigPushApps() {
        var z = NGUhrzustand()
        for i in 0..<50 { pruefeOK(senden("PUT", "/apps/pushed/a\(i)", #"{"text":"x"}"#, &z)) }
        pruefeFehler(senden("PUT", "/apps/pushed/zuviel", #"{"text":"x"}"#, &z), 507, "insufficientStorage")
        XCTAssertEqual(z.apps.count, 52)
    }

    func testAktiveAppWechselnUndBlaettern() {
        var z = NGUhrzustand()
        _ = senden("PUT", "/apps/pushed/eins", #"{"text":"x"}"#, &z)
        pruefeOK(senden("PUT", "/apps/active", #"{"name":"eins","fast":true}"#, &z))
        XCTAssertEqual(z.aktiveApp, "eins")
        pruefeOK(senden("PUT", "/apps/active", "Status", kopf: [:], &z))
        XCTAssertEqual(z.aktiveApp, "Status")
        pruefeFehler(senden("PUT", "/apps/active", #"{"name":"nix"}"#, &z), 404, "notFound", meldung: "app not found")
        pruefeFehler(senden("PUT", "/apps/active", "{kaputt", &z), 404, "notFound")

        pruefeOK(senden("POST", "/apps/next", &z))
        XCTAssertEqual(z.aktiveApp, "eins")
        pruefeOK(senden("POST", "/apps/next", &z))
        XCTAssertEqual(z.aktiveApp, "Time")
        pruefeOK(senden("POST", "/apps/previous", &z))
        XCTAssertEqual(z.aktiveApp, "eins")
    }

    func testAppFreigabe() {
        var z = NGUhrzustand()
        pruefeOK(senden("PUT", "/apps/Status/enabled", "false", kopf: [:], &z))
        XCTAssertEqual(z.apps[1].aktiv, false)
        pruefeOK(senden("POST", "/apps/next", &z))
        XCTAssertEqual(z.aktiveApp, "Time")
        pruefeOK(senden("POST", "/apps/next", &z))
        XCTAssertEqual(z.aktiveApp, "Time", "Eine abgeschaltete App kommt nicht mehr dran.")
        pruefeOK(senden("PUT", "/apps/Status/enabled", "true", kopf: [:], &z))
        pruefeFehler(senden("PUT", "/apps/Status/enabled", "vielleicht", &z),
                     422, "validationFailed", meldung: "must be true or false")
        pruefeFehler(senden("PUT", "/apps/a%20b/enabled", "true", &z), 400, "invalidName", feld: "name")
        // Gemessen 09.10.2026: ein unbekannter Name ist ok und legt nichts an.
        let vorher = z.apps
        pruefeOK(senden("PUT", "/apps/nix/enabled", "true", kopf: [:], &z))
        XCTAssertEqual(z.apps, vorher)
    }

    /// Gemessen 09.10.2026 (NG 1.2.2, TC002): `enabled:false` bleibt beim
    /// Ersetzen und beim Löschen; das Inventar behält einen Geistereintrag
    /// (`present:false`), den `enabled true` wegräumt.
    func testAusgeschalteteAnzeigeBleibtBeiErsetzenUndLoeschenAusgeschaltet() {
        var z = NGUhrzustand()
        pruefeOK(senden("PUT", "/apps/pushed/eins", #"{"text":"a"}"#, &z))
        pruefeOK(senden("PUT", "/apps/eins/enabled", "false", kopf: [:], &z))
        func eintrag() -> [String: JSONWert]? {
            guard case .liste(let l) = senden("GET", "/apps", &z).wert else { return nil }
            for case .objekt(let o) in l where o["name"] == .text("eins") { return o }
            return nil
        }
        XCTAssertEqual(eintrag()?["enabled"], .bool(false))
        XCTAssertEqual(eintrag()?["inLoop"], .bool(false))
        XCTAssertEqual(eintrag()?["present"], .bool(true))

        pruefeOK(senden("PUT", "/apps/pushed/eins", #"{"text":"b"}"#, &z))
        XCTAssertEqual(eintrag()?["enabled"], .bool(false), "ersetzt wird der Inhalt, nicht der Schalter")

        pruefeOK(senden("DELETE", "/apps/eins", &z))
        XCTAssertEqual(eintrag()?["enabled"], .bool(false))
        XCTAssertEqual(eintrag()?["present"], .bool(false), "Geistereintrag")
        XCTAssertEqual(eintrag()?["inLoop"], .bool(false))

        pruefeOK(senden("PUT", "/apps/pushed/eins", #"{"text":"c"}"#, &z))
        XCTAssertEqual(eintrag()?["present"], .bool(true))
        XCTAssertEqual(eintrag()?["enabled"], .bool(false), "eine neue Sendung unter dem Namen bleibt unsichtbar")

        pruefeOK(senden("DELETE", "/apps/eins", &z))
        pruefeOK(senden("PUT", "/apps/eins/enabled", "true", kopf: [:], &z))
        XCTAssertNil(eintrag(), "enabled true räumt den Geistereintrag weg")
    }

    func testEineEingeschalteteAnzeigeVerschwindetBeimLoeschenGanz() {
        var z = NGUhrzustand()
        pruefeOK(senden("PUT", "/apps/pushed/eins", #"{"text":"a"}"#, &z))
        pruefeOK(senden("DELETE", "/apps/eins", &z))
        XCTAssertNil(z.apps.first { $0.name == "eins" })
    }

    // MARK: Benachrichtigungen

    func testBenachrichtigungenKommenUndGehen() {
        var z = NGUhrzustand()
        pruefeOK(senden("POST", "/notifications", #"{"text":"a","name":"eins"}"#, &z))
        pruefeOK(senden("POST", "/notifications", #"[{"text":"b"}]"#, &z))
        XCTAssertEqual(z.benachrichtigungen.count, 2)
        XCTAssertEqual(senden("GET", "/device", &z).objekt["messageCount"], .zahl(2))

        pruefeOK(senden("DELETE", "/notifications/active", &z))
        XCTAssertEqual(z.benachrichtigungen.count, 1)
        pruefeOK(senden("DELETE", "/notifications/active", &z))
        pruefeOK(senden("DELETE", "/notifications/active", &z))
        XCTAssertTrue(z.benachrichtigungen.isEmpty)

        _ = senden("POST", "/notifications", #"{"text":"a","name":"eins"}"#, &z)
        pruefeFehler(senden("DELETE", "/notifications/zwei", &z), 404, "notFound")
        pruefeOK(senden("DELETE", "/notifications/eins", &z))
        XCTAssertTrue(z.benachrichtigungen.isEmpty)
    }

    func testBenachrichtigungFehler() {
        var z = NGUhrzustand()
        pruefeFehler(senden("POST", "/notifications", "nix", &z), 400, "invalidJson")
        pruefeFehler(senden("POST", "/notifications", #"[{"text":"a"},{"text":"b"}]"#, &z),
                     422, "validationFailed", meldung: "one notification per request")
        pruefeFehler(senden("POST", "/notifications", #"{"name":5}"#, &z), 422, "validationFailed", feld: "name")
    }

    func testWarteschlangeFasst32UndStackFalseErsetztDieAngezeigte() {
        var z = NGUhrzustand()
        for i in 0..<32 { pruefeOK(senden("POST", "/notifications", "{\"name\":\"n\(i)\"}", &z)) }
        pruefeFehler(senden("POST", "/notifications", #"{"text":"x"}"#, &z), 507, "insufficientStorage")
        pruefeFehler(senden("POST", "/notifications", #"{"text":"x","stack":true}"#, &z), 507, "insufficientStorage")
        pruefeFehler(senden("POST", "/notifications", #"{"stack":"nein"}"#, &z), 422, "validationFailed", feld: "stack")
        pruefeOK(senden("POST", "/notifications", #"{"name":"neu","stack":false}"#, &z))
        XCTAssertEqual(z.benachrichtigungen.count, 32)
        XCTAssertEqual(z.benachrichtigungen[0].name, "neu")
        XCTAssertEqual(z.benachrichtigungen[1].name, "n1")
        var leer = NGUhrzustand()
        pruefeOK(senden("POST", "/notifications", #"{"stack":false}"#, &leer))
        XCTAssertEqual(leer.benachrichtigungen.count, 1)
    }

    func testFarbformen() {
        let f = VirtuelleNGUhr.farbe
        XCTAssertEqual(f(.text("FF8800")), "#FF8800")
        XCTAssertEqual(f(.text("#ff8800")), "#FF8800")
        XCTAssertEqual(f(.text("F80")), "#FF8800")
        XCTAssertEqual(f(.text("#f80")), "#FF8800")
        XCTAssertNil(f(.text("F8")))
        XCTAssertNil(f(.text("GG0000")))
        XCTAssertEqual(f(.zahl(16746496)), "#FF8800")
        XCTAssertNil(f(.zahl(0x1000000)))
        XCTAssertNil(f(.zahl(1.5)))
        XCTAssertEqual(f(.liste([.zahl(255), .zahl(136), .zahl(0)])), "#FF8800")
        // Begrenzt, nicht abgewiesen.
        XCTAssertEqual(f(.liste([.zahl(300), .zahl(-5), .zahl(0)])), "#FF0000")
        XCTAssertNil(f(.liste([.zahl(1.5), .zahl(0), .zahl(0)])))
        XCTAssertNil(f(.liste([.zahl(1), .zahl(0)])))
        XCTAssertEqual(f(.liste([.text("HSV"), .zahl(0), .zahl(100), .zahl(100)])), "#FF0000")
        XCTAssertEqual(f(.liste([.text("HSV"), .zahl(120), .zahl(100), .zahl(100)])), "#00FF00")
        XCTAssertEqual(f(.liste([.text("HSV"), .zahl(240), .zahl(100), .zahl(50)])), "#000080")
        // h wird umgebrochen, s und v begrenzt.
        XCTAssertEqual(f(.liste([.text("HSV"), .zahl(480), .zahl(100), .zahl(100)])), "#00FF00")
        XCTAssertEqual(f(.liste([.text("HSV"), .zahl(-120), .zahl(500), .zahl(100)])), "#0000FF")
        XCTAssertEqual(f(.liste([.text("HSV"), .zahl(0), .zahl(-1), .zahl(100)])), "#FFFFFF")
        XCTAssertNil(f(.liste([.text("HSV"), .zahl(0.5), .zahl(100), .zahl(100)])))
        XCTAssertNil(f(.bool(true)))
    }

    func testIndikatorNimmtAlleFarbformen() {
        var z = NGUhrzustand()
        pruefeOK(senden("PUT", "/indicators/1", #"{"color":"F80"}"#, &z))
        XCTAssertEqual(z.indikatoren[0].farbe, "#FF8800")
        pruefeOK(senden("PUT", "/indicators/1", #"{"color":["HSV",240,100,100]}"#, &z))
        XCTAssertEqual(z.indikatoren[0].farbe, "#0000FF")
        pruefeOK(senden("PUT", "/indicators/1", #"{"color":[999,0,0]}"#, &z))
        XCTAssertEqual(z.indikatoren[0].farbe, "#FF0000")
        pruefeFehler(senden("PUT", "/indicators/1", #"{"color":[1.5,0,0]}"#, &z), 422, "validationFailed", feld: "color")
        pruefeOK(senden("PUT", "/indicators/1", #"{"color":null}"#, &z))
        XCTAssertFalse(z.indikatoren[0].an)
    }

    // MARK: Indikatoren

    func testIndikatorSetzenAusschaltenUndZuruecksetzen() {
        var z = NGUhrzustand()
        pruefeOK(senden("PUT", "/indicators/2", ##"{"color":"#ff0000","blinkMs":500}"##, &z))
        XCTAssertEqual(z.indikatoren[1], NGIndikator(an: true, farbe: "#FF0000", blinkMs: 500, fadeMs: 0))
        guard case .liste(let ind)? = senden("GET", "/device", &z).objekt["indicators"],
              case .objekt(let i2) = ind[1] else { return XCTFail() }
        XCTAssertEqual(i2["on"], .bool(true))

        pruefeOK(senden("PUT", "/indicators/2", #"{"color":0}"#, &z))
        XCTAssertFalse(z.indikatoren[1].an)
        XCTAssertEqual(z.indikatoren[1].farbe, "#FF0000", "Die Farbe bleibt beim Ausschalten stehen.")

        pruefeOK(senden("PUT", "/indicators/3", #"{"color":[0,255,0]}"#, &z))
        XCTAssertEqual(z.indikatoren[2].farbe, "#00FF00")
        pruefeOK(senden("DELETE", "/indicators/3", &z))
        XCTAssertEqual(z.indikatoren[2], NGIndikator())
    }

    func testIndikatorFehler() {
        var z = NGUhrzustand()
        for id in ["0", "4", "x"] {
            pruefeFehler(senden("PUT", "/indicators/\(id)", ##"{"color":"#FF0000"}"##, &z),
                         404, "notFound", meldung: "indicator id must be 1..3")
            pruefeFehler(senden("DELETE", "/indicators/\(id)", &z),
                         404, "notFound", meldung: "indicator id must be 1..3")
        }
        pruefeFehler(senden("PUT", "/indicators/1", #"{"color":"rot"}"#, &z),
                     422, "validationFailed", feld: "color")
        pruefeFehler(senden("PUT", "/indicators/1", "", &z), 422, "validationFailed", meldung: "body required")
        pruefeFehler(senden("PUT", "/indicators/1", "{", &z), 400, "invalidJson")
        pruefeFehler(senden("GET", "/indicators", &z), 404, "notFound", meldung: "unknown route")
    }

    // MARK: Allgemeine Fehler

    func testUnbekannteRoute() {
        var z = NGUhrzustand()
        pruefeFehler(senden("GET", "/nix", &z), 404, "notFound", meldung: "unknown route")
        var a = Virtuelleuhr.Anfrage("GET", "/getBase")
        let r = VirtuelleNGUhr.beantworten(a, &z)
        XCTAssertEqual(r.status, 404)
        a.pfad = "/api/v1"
        XCTAssertEqual(VirtuelleNGUhr.beantworten(a, &z).status, 404)
    }

    func testFalscheMethodeNenntDieErlaubten() {
        var z = NGUhrzustand()
        pruefeFehler(senden("POST", "/settings", "{}", &z), 405, "methodNotAllowed", meldung: "allowed: GET, PATCH")
        pruefeFehler(senden("GET", "/apps/pushed/x", &z), 405, "methodNotAllowed", meldung: "allowed: PUT")
        pruefeFehler(senden("GET", "/indicators/1", &z), 405, "methodNotAllowed", meldung: "allowed: PUT, DELETE")
        pruefeFehler(senden("GET", "/notifications", &z), 405, "methodNotAllowed", meldung: "allowed: POST")
        pruefeFehler(senden("PUT", "/device", "{}", &z), 405, "methodNotAllowed", meldung: "allowed: GET")
        pruefeFehler(senden("DELETE", "/apps/active", &z), 405, "methodNotAllowed", meldung: "allowed: PUT")
    }

    func testPutUndPatchBrauchenJSONContentType() {
        var z = NGUhrzustand()
        let vorher = z
        pruefeFehler(senden("PATCH", "/settings", #"{"brightness":5}"#, kopf: [:], &z),
                     415, "unsupportedMediaType", meldung: "expected application/json")
        pruefeFehler(senden("PATCH", "/display", "{}", kopf: ["content-type": "text/plain"], &z),
                     415, "unsupportedMediaType")
        pruefeFehler(senden("PUT", "/apps/pushed/x", #"{"a":1}"#, kopf: [:], &z), 415, "unsupportedMediaType")
        pruefeFehler(senden("PUT", "/indicators/1", ##"{"color":"#FF0000"}"##, kopf: [:], &z),
                     415, "unsupportedMediaType")
        XCTAssertEqual(z, vorher)
        pruefeOK(senden("PATCH", "/display", "{}", kopf: ["content-type": "application/json; charset=utf-8"], &z))
    }

    func testZuGrosserRumpf() {
        var z = NGUhrzustand()
        let gross = #"{"text":""# + String(repeating: "a", count: 2 * 1024 * 1024) + #""}"#
        pruefeFehler(senden("PUT", "/apps/pushed/x", gross, &z), 413, "payloadTooLarge")
        XCTAssertEqual(z.apps.count, 2)
    }
}

/// Der ganze Weg über einen echten Port, auf `127.0.0.1`. Es geht kein Byte
/// ins Hausnetz.
final class VirtuelleNGUhrAmDrahtTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet() throws -> (Uhrenserver, UInt16) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()
                Thread.sleep(forTimeInterval: 0.05)
                server = s
                return (s, port)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func anfrage(_ port: UInt16, _ methode: String, _ pfad: String, _ rumpf: String? = nil,
                         json: Bool = true) throws -> (Int, [String: Any]) {
        var r = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(pfad)")!)
        r.httpMethod = methode
        if let rumpf {
            r.httpBody = Data(rumpf.utf8)
            if json { r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        }
        let erwartung = expectation(description: "Antwort")
        nonisolated(unsafe) var ergebnis: (Int, [String: Any])?
        URLSession.shared.dataTask(with: r) { daten, antwort, _ in
            let o = daten.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            ergebnis = ((antwort as? HTTPURLResponse)?.statusCode ?? -1, o ?? [:])
            erwartung.fulfill()
        }.resume()
        wait(for: [erwartung], timeout: 5)
        return try XCTUnwrap(ergebnis)
    }

    func testDieNGUhrAntwortetUeberHTTPUndHaeltDenZustand() throws {
        let (server, port) = try gestartet()

        let (s1, d) = try anfrage(port, "GET", "/api/v1/device")
        XCTAssertEqual(s1, 200)
        XCTAssertEqual(d["version"] as? String, "1.2.2")

        let (s2, _) = try anfrage(port, "PATCH", "/api/v1/settings", #"{"brightness":42}"#)
        XCTAssertEqual(s2, 200)
        XCTAssertEqual(server.zustand.helligkeit, 42)

        let (s3, _) = try anfrage(port, "PUT", "/api/v1/apps/pushed/wetter", #"{"text":"hi"}"#)
        XCTAssertEqual(s3, 200)
        XCTAssertEqual(server.zustand.apps.map(\.name), ["Time", "Status", "wetter"])

        let (s4, e4) = try anfrage(port, "PATCH", "/api/v1/settings", #"{"brightness":999}"#)
        XCTAssertEqual(s4, 422)
        XCTAssertEqual((e4["error"] as? [String: Any])?["field"] as? String, "brightness")
        XCTAssertEqual(server.zustand.helligkeit, 42)

        let (s5, e5) = try anfrage(port, "PUT", "/api/v1/apps/pushed/x", #"{"text":"hi"}"#, json: false)
        XCTAssertEqual(s5, 415)
        XCTAssertEqual((e5["error"] as? [String: Any])?["code"] as? String, "unsupportedMediaType")

        let (s6, _) = try anfrage(port, "GET", "/api/v1/gibtsnicht")
        XCTAssertEqual(s6, 404)
    }

}
