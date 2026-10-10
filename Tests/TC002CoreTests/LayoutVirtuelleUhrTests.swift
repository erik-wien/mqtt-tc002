import XCTest
@testable import TC002Core

/// Die virtuelle Uhr nimmt Layouts wie die Firmware: prüft sie, zeichnet sie
/// und liefert das Display zurück — und weist unbekannte oberste Schlüssel ab.
final class LayoutVirtuelleUhrTests: XCTestCase {
    private let json = ["content-type": "application/json"]

    private func push(_ koerper: String, _ z: inout NGUhrzustand, name: String = "l") -> VirtuelleNGUhr.Antwort {
        VirtuelleNGUhr.beantworten(.init("PUT", "/api/v1/apps/pushed/\(name)", koerper: Data(koerper.utf8), kopf: json), &z)
    }

    private func feld(_ a: VirtuelleNGUhr.Antwort) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: a.koerper) as? [String: Any],
              let e = o["error"] as? [String: Any] else { return nil }
        return e["field"] as? String
    }

    private func layout(_ regionen: String, neben: String = "") -> String {
        #"{"layout":{"version":1,"regions":[\#(regionen)]}\#(neben)}"#
    }

    // MARK: - Oberste Schluessel

    func testEinUnbekannterSchluesselIstEinFehlerMitFeld() {
        var z = NGUhrzustand()
        let a = push(#"{"text":"x","bogus":1}"#, &z)
        XCTAssertEqual(a.status, 422)
        XCTAssertEqual(feld(a), "bogus")
        XCTAssertTrue(z.apps.allSatisfy(\.eingebaut), "nichts angelegt")
        let m = VirtuelleNGUhr.beantworten(.init("POST", "/api/v1/notifications", koerper: Data(#"{"text":"x","duration":5}"#.utf8), kopf: json), &z)
        XCTAssertEqual(m.status, 422)
        XCTAssertEqual(feld(m), "duration")
    }

    /// Gemessen am 09.10.2026: `textCenter` nimmt NG 1.2.2 weiter an.
    func testTextCenterWirdWeiterAngenommen() {
        var z = NGUhrzustand()
        XCTAssertEqual(push(#"{"text":"x","textCenter":true}"#, &z).status, 200)
    }

    /// Alles, was die App selbst sendet, ist ein bekannter Schlüssel.
    func testDieNutzlastenDerAppSindBekannteSchluessel() throws {
        var z = NGUhrzustand()
        let o = Meldungsoptionen(text: "Hallo", weg: .text, dauer: 5)
        let nutzlast = try Anzeigen.nutzlast(Frame(dauer: 5, herkunft: Meldungsherkunft(optionen: o, iconDatenURI: nil),
                                                   lebensdauer: Lebensdauer(sekunden: 60)))
        XCTAssertEqual(push(nutzlast, &z).status, 200, nutzlast)
        let grafik = try Anzeigen.nutzlast(Frame(darstellung: Darstellung(overlay: "rain"),
                                                 grafik: Grafikinhalt(diagramm: .linie([1, 2, 3]), fortschritt: 40)))
        XCTAssertEqual(push(grafik, &z, name: "g").status, 200, grafik)
    }

    func testZeichenbefehleWerdenWieBeiDerUhrGeprueft() {
        var z = NGUhrzustand()
        XCTAssertEqual(feld(push(#"{"draw":[["pixel",0,0],["blob",1]]}"#, &z)), "draw[1]")
        XCTAssertEqual(feld(push(#"{"draw":[["pixel","a",0]]}"#, &z)), "draw[0]")
        XCTAssertEqual(feld(push(#"{"draw":[["pixels",null,1,2,3]]}"#, &z)), "draw[0]")
        XCTAssertEqual(push(#"{"draw":[["pixels",null,1,2],["line",0,0,1,1],["circle",3,3,2],["bitmap",0,0,1,1,"AAAA"]]}"#, &z).status, 200)
    }

    // MARK: - Layout pruefen

    func testEinGutesLayoutWirdAngenommen() {
        var z = NGUhrzustand()
        let a = push(layout(#"{"id":"a","box":[0,0,52,16],"progress":10}"#, neben: #","durationMs":5000,"lifetimeMs":60000"#), &z)
        XCTAssertEqual(a.status, 200)
    }

    func testNebenDemLayoutDuerfenKeineZeichenschluesselStehen() {
        var z = NGUhrzustand()
        for schluessel in ["text", "icon", "draw", "effect", "scroll", "backgroundColor", "progress", "textCenter"] {
            let wert = schluessel == "draw" ? "[]" : (schluessel == "progress" ? "5" : "\"x\"")
            let a = push(layout(#"{"id":"a","box":[0,0,4,4],"progress":1}"#, neben: #","\#(schluessel)":\#(wert)"#), &z)
            XCTAssertEqual(a.status, 422, schluessel)
            XCTAssertEqual(feld(a), schluessel)
        }
    }

    func testDieFeldnamenFolgenDerMessung() {
        var z = NGUhrzustand()
        XCTAssertEqual(feld(push(layout(#"{"id":"a","box":[40,0,13,8],"progress":1}"#), &z)), "layout.regions[0].box")
        XCTAssertEqual(feld(push(layout(#"{"id":"a","box":[0,0,4,4],"progress":1},{"id":"a","box":[0,0,4,4],"progress":1}"#), &z)),
                       "layout.regions[1].id")
        XCTAssertEqual(feld(push(layout(#"{"id":"a","box":[0,0,4,4]}"#), &z)), "layout.regions[0]")
        XCTAssertEqual(feld(push(layout(#"{"id":"a","box":[0,0,4,4],"progress":1,"x":1}"#), &z)), "layout.regions[0].x")
        XCTAssertEqual(feld(push(layout(#"{"id":"a","box":[0,0,4,4],"icon":"data:image/png;base64,AA"}"#), &z)),
                       "layout.regions[0].icon")
        XCTAssertEqual(feld(push(#"{"layout":{"version":1,"regions":[],"oops":1}}"#, &z)), "layout.oops")
        XCTAssertEqual(feld(push(#"{"layout":{"version":1,"regions":[],"effect":"Nope"}}"#, &z)), "layout.effect")
        XCTAssertEqual(feld(push(##"{"layout":{"version":1,"regions":[],"effect":"Plasma","backgroundColor":"#000000"}}"##, &z)),
                       "layout.effect")
    }

    func testDieGrenzenAusCapabilities() {
        var z = NGUhrzustand()
        let viele = (0..<17).map { #"{"id":"r\#($0)","box":[\#($0),0,1,1],"progress":1}"# }.joined(separator: ",")
        XCTAssertEqual(feld(push(layout(viele), &z)), "layout.regions")
        let laufend = (0..<9).map { #"{"id":"r\#($0)","box":[\#($0),0,1,8],"text":"a"}"# }.joined(separator: ",")
        XCTAssertEqual(push(layout(laufend), &z).status, 422, "neun laufende Texte")
        let ruhend = (0..<9).map { #"{"id":"r\#($0)","box":[\#($0),0,1,8],"text":"a","scroll":"static"}"# }.joined(separator: ",")
        XCTAssertEqual(push(layout(ruhend), &z).status, 200)
        let icons = (0..<5).map { #"{"id":"r\#($0)","box":[\#($0 * 8),0,8,8],"icon":"sun"}"# }.joined(separator: ",")
        XCTAssertEqual(push(layout(icons), &z).status, 422)
        let werte = Array(repeating: "1", count: 129).joined(separator: ",")
        XCTAssertEqual(feld(push(layout(#"{"id":"c","box":[0,0,52,16],"chart":{"values":[\#(werte)],"type":"bar"}}"#), &z)),
                       "layout.regions[0].chart.values")
    }

    // MARK: - Zeichnen

    private func zeigen(_ l: Kastenlayout) throws -> (zustand: NGUhrzustand, pixel: [Int]) {
        var z = NGUhrzustand()
        let a = push(try Anzeigen.nutzlast(Frame(layout: l)), &z, name: "l")
        XCTAssertEqual(a.status, 200, String(decoding: a.koerper, as: UTF8.self))
        _ = VirtuelleNGUhr.beantworten(.init("PUT", "/api/v1/apps/active", koerper: Data("l".utf8)), &z)
        return (z, VirtuelleNGUhr.bildschirm(z))
    }

    private func punkt(_ p: [Int], _ x: Int, _ y: Int) -> Int { p[y * 52 + x] }

    func testDreiRegionenLandenAufDemRaster() throws {
        let (_, p) = try zeigen(KastenlayoutTests.dreiRegionen)
        // Fortschritt 50 % von 26 Spalten: 13 gefüllt, der Rest die Spur.
        for y in 8..<12 {
            XCTAssertEqual(punkt(p, 0, y), 0x00FF00); XCTAssertEqual(punkt(p, 12, y), 0x00FF00)
            XCTAssertEqual(punkt(p, 13, y), 0x202020); XCTAssertEqual(punkt(p, 25, y), 0x202020)
            XCTAssertEqual(punkt(p, 26, y), 0)
        }
        XCTAssertEqual(punkt(p, 0, 12), 0)
        // Zeichnung relativ zur Ecke des Kastens.
        XCTAssertEqual(punkt(p, 30, 8), 0x0000FF)
        XCTAssertEqual(punkt(p, 31, 8), 0xFF0000)
        XCTAssertEqual(punkt(p, 51, 15), 0xFF0000)
        XCTAssertEqual(punkt(p, 29, 8), 0)
        // Text: nur im Kasten, nur in seiner Farbe.
        var gesetzt = 0
        for y in 0..<16 { for x in 0..<52 where y < 8 && punkt(p, x, y) != 0 {
            gesetzt += 1
            XCTAssertEqual(punkt(p, x, y), 0x00AAFF)
        } }
        XCTAssertGreaterThan(gesetzt, 10)
    }

    func testSpaetereRegionenDeckenFruehere() throws {
        let l = Kastenlayout(regionen: [
            Layoutregion(kennung: "a", kasten: Kasten(x: 0, y: 0, breite: 4, hoehe: 4),
                         inhalt: .zeichnung([.flaeche(x: 0, y: 0, breite: 4, hoehe: 4, farbe: "#FF0000")])),
            Layoutregion(kennung: "b", kasten: Kasten(x: 2, y: 2, breite: 4, hoehe: 4),
                         inhalt: .zeichnung([.flaeche(x: 0, y: 0, breite: 4, hoehe: 4, farbe: "#00FF00")])),
        ], darstellung: Darstellung(hintergrundfarbe: "#000080"))
        let (_, p) = try zeigen(l)
        XCTAssertEqual(punkt(p, 1, 1), 0xFF0000)
        XCTAssertEqual(punkt(p, 2, 2), 0x00FF00)
        XCTAssertEqual(punkt(p, 7, 7), 0x000080, "Hintergrund füllt das Display zuerst")
    }

    func testDiagrammFuelltDenKasten() throws {
        let l = Kastenlayout(regionen: [
            Layoutregion(kennung: "d", kasten: Kasten(x: 0, y: 0, breite: 8, hoehe: 8),
                         inhalt: .diagramm(Layoutdiagramm(art: .balken, werte: [0, 8], untergrenze: 0, obergrenze: 8))),
        ])
        let (_, p) = try zeigen(l)
        XCTAssertEqual((0..<8).filter { punkt(p, 5, $0) != 0 }.count, 8, "voller Balken: ganze Spalte")
        XCTAssertEqual((0..<8).filter { punkt(p, 0, $0) != 0 }.count, 1, "Wert 0: nur die Nulllinie")
    }

    func testKreiseUndLinienSindGezeichnet() throws {
        let l = Kastenlayout(regionen: [
            Layoutregion(kennung: "z", kasten: Kasten(x: 0, y: 0, breite: 16, hoehe: 16), inhalt: .zeichnung([
                .kreisflaeche(x: 5, y: 5, radius: 2, farbe: "#FFFFFF"), .kreis(x: 12, y: 12, radius: 2, farbe: "#FF0000")])),
        ])
        let (_, p) = try zeigen(l)
        XCTAssertEqual(punkt(p, 5, 5), 0xFFFFFF)
        XCTAssertEqual(punkt(p, 7, 5), 0xFFFFFF)
        XCTAssertEqual(punkt(p, 12, 12), 0, "ein Umriss ist innen leer")
        XCTAssertEqual(punkt(p, 14, 12), 0xFF0000)
    }

    func testDasDisplayKommtAlsAntwortVonScreen() throws {
        let ergebnis = try zeigen(KastenlayoutTests.dreiRegionen)
        var z = ergebnis.zustand
        let p = ergebnis.pixel
        let a = VirtuelleNGUhr.beantworten(.init("GET", "/api/v1/display/screen"), &z)
        XCTAssertEqual(a.status, 200)
        let auszug = try Bildschirmauszug(daten: a.koerper)
        XCTAssertEqual(auszug.pixel, p)
        XCTAssertEqual(auszug.breite, 52)
        XCTAssertEqual(auszug.hoehe, 16)
    }

    // MARK: - MQTT

    func testMQTTVerwirftWasSamtThemaUeber8192ByteIst() throws {
        var z = NGUhrzustand()
        let befehle = (0..<400).map { "[\"pixel\",\($0 % 50),\($0 % 14),\"#FF0000\"]" }.joined(separator: ",")
        let gross = layout(#"{"id":"z","box":[0,0,52,16],"draw":[\#(befehle)]}"#)
        XCTAssertGreaterThan(gross.utf8.count, 8192)
        XCTAssertTrue(VirtuelleNGUhr.nachricht(thema: "p/cmd/apps/pushed/l", nutzlast: Data(gross.utf8), praefix: "p", &z).isEmpty,
                      "keine Antwort, auch kein /result")
        XCTAssertTrue(z.apps.allSatisfy(\.eingebaut))
    }

    func testMQTTAntwortetAufResultUndScreen() {
        var z = NGUhrzustand()
        let gut = VirtuelleNGUhr.nachricht(thema: "p/cmd/apps/pushed/l", praefix: "p", z: &z,
                                           layout(#"{"id":"a","box":[0,0,4,4],"progress":1}"#))
        XCTAssertEqual(gut.map(\.thema), ["p/cmd/apps/pushed/l/result"])
        XCTAssertEqual(String(decoding: gut[0].nutzlast, as: UTF8.self), #"{"ok":true}"#)
        let schlecht = VirtuelleNGUhr.nachricht(thema: "p/cmd/apps/pushed/l", praefix: "p", z: &z,
                                                layout(#"{"id":"a","box":[0,0,99,4],"progress":1}"#))
        let o = try? JSONSerialization.jsonObject(with: schlecht[0].nutzlast) as? [String: Any]
        XCTAssertEqual(o?["ok"] as? Bool, false)
        XCTAssertEqual((o?["error"] as? [String: Any])?["field"] as? String, "layout.regions[0].box")
        let bild = VirtuelleNGUhr.nachricht(thema: "p/cmd/screen/get", nutzlast: Data(), praefix: "p", &z)
        XCTAssertEqual(bild.map(\.thema), ["p/state/screen"])
    }
}

extension VirtuelleNGUhr {
    /// Für die Tests: die Nutzlast als Text.
    fileprivate static func nachricht(thema: String, praefix: String, z: inout NGUhrzustand,
                                      _ nutzlast: String) -> [(thema: String, nutzlast: Data)] {
        nachricht(thema: thema, nutzlast: Data(nutzlast.utf8), praefix: praefix, &z)
    }
}

/// Eine virtuelle Uhr am „Broker": nimmt MQTT-Nachrichten, beantwortet sie wie
/// die Firmware und hält fest, was sie veröffentlicht hat. Kein Netz.
final class MQTTUhrDoppelgaenger: @unchecked Sendable {
    private let sperre = NSLock()
    private var _zustand = NGUhrzustand()
    private var _ausgang: [(thema: String, nutzlast: Data)] = []
    private var _eingang: [(thema: String, nutzlast: Data)] = []
    let praefix: String

    init(praefix: String = "wz/uhr", zustand: NGUhrzustand = NGUhrzustand()) {
        self.praefix = praefix
        _zustand = zustand
    }

    var zustand: NGUhrzustand { sperre.lock(); defer { sperre.unlock() }; return _zustand }
    var eingang: [(thema: String, nutzlast: Data)] { sperre.lock(); defer { sperre.unlock() }; return _eingang }

    fileprivate func annehmen(_ nutzlast: Data, an thema: String) {
        sperre.lock(); defer { sperre.unlock() }
        _eingang.append((thema, nutzlast))
        _ausgang += VirtuelleNGUhr.nachricht(thema: thema, nutzlast: nutzlast, praefix: praefix, &_zustand)
    }

    fileprivate func letzte(auf thema: String) -> Data? {
        sperre.lock(); defer { sperre.unlock() }
        guard let i = _ausgang.lastIndex(where: { $0.thema == thema }) else { return nil }
        return _ausgang.remove(at: i).nutzlast
    }
}

extension MQTTUhrDoppelgaenger: NachrichtSendend {
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws { annehmen(nutzlast, an: thema) }
}

/// Wartet auf `<Thema>/result`, wie der Lauscher des Werkzeugs.
struct ErgebnisAmDoppelgaenger: ErgebnisLauschend {
    let uhr: MQTTUhrDoppelgaenger
    func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                  waehrend tat: () throws -> Void) throws -> Data? {
        try tat()
        return uhr.letzte(auf: thema + "/result")
    }
}

/// Wartet auf ein beliebiges Thema, etwa `state/screen`.
struct ThemaAmDoppelgaenger: ThemaLauschend {
    let uhr: MQTTUhrDoppelgaenger
    func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                  waehrend tat: () throws -> Void) throws -> Data? {
        try tat()
        return uhr.letzte(auf: thema)
    }
}
