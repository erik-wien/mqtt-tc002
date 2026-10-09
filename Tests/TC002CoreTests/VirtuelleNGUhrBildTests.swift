import XCTest
@testable import TC002Core

/// Was die virtuelle NG-Uhr von der aktiven Anzeige in ihren Bildspeicher
/// zeichnet. Die Rasterregeln sind am Gerät gemessen (NG 1.2.2, TC002,
/// 09.10.2026, `docs/awtrix-ng-protokoll.md` §1.1): `draw` einer Anzeige
/// rechnet bei `enlargeApps: true` auf 26 × 8 und verdoppelt, `draw` in einem
/// `layout` rechnet pixelgenau auf 52 × 16 relativ zur Box.
final class VirtuelleNGUhrBildTests: XCTestCase {
    private let breite = VirtuelleNGUhr.breite
    private let rot = 0xFF0000

    /// Legt `nutzlast` als aktive App ab und liefert den Bildspeicher.
    private func bild(_ nutzlast: String, vergroessert: Bool = true) throws -> [Int] {
        var z = NGUhrzustand()
        if !vergroessert { z.einstellungen["enlargeApps"] = .bool(false) }
        let wert = try XCTUnwrap(JSONWert.lesen(Data(nutzlast.utf8)))
        z.apps.append(NGApp(name: "x", aktiv: true, eingebaut: false, nutzlast: wert))
        z.aktiveApp = "x"
        return VirtuelleNGUhr.bildschirm(z)
    }

    private func belegt(_ b: [Int]) -> Set<[Int]> {
        var menge = Set<[Int]>()
        for (i, f) in b.enumerated() where f != 0 { menge.insert([i % breite, i / breite]) }
        return menge
    }

    func testOhneNutzlastIstDasBildSchwarz() {
        let b = VirtuelleNGUhr.bildschirm(NGUhrzustand())
        XCTAssertEqual(b.count, 52 * 16)
        XCTAssertTrue(b.allSatisfy { $0 == 0 })
    }

    // MARK: Anzeige auf dem 26×8-Raster

    func testEinPixelBelegtInDerAnzeigeVierPunkte() throws {
        let b = try bild(#"{"draw":[["pixel",0,0,"FF0000"]]}"#)
        XCTAssertEqual(belegt(b), [[0, 0], [1, 0], [0, 1], [1, 1]])
        XCTAssertEqual(b[0], rot)
    }

    func testDasPixelAmRandDesVollenRastersFaelltInDerAnzeigeWeg() throws {
        let b = try bild(#"{"draw":[["pixel",51,15,"FF0000"]]}"#)
        XCTAssertTrue(belegt(b).isEmpty)
        let ecke = try bild(#"{"draw":[["pixel",25,7,"FF0000"]]}"#)
        XCTAssertEqual(belegt(ecke), [[50, 14], [51, 14], [50, 15], [51, 15]])
    }

    func testOhneVergroesserungRechnetDieAnzeigeAufDemVollenRaster() throws {
        let b = try bild(#"{"draw":[["pixel",51,15,"FF0000"]]}"#, vergroessert: false)
        XCTAssertEqual(belegt(b), [[51, 15]])
    }

    func testRectFillUndRectInDerAnzeige() throws {
        let gefuellt = try bild(#"{"draw":[["rectFill",1,1,2,2,"FF0000"]]}"#)
        XCTAssertEqual(belegt(gefuellt).count, 16)
        XCTAssertEqual(gefuellt[2 * breite + 2], rot)
        XCTAssertEqual(gefuellt[5 * breite + 5], rot)
        XCTAssertEqual(gefuellt[6 * breite + 6], 0)
        // Umriss 3 × 3: der Mittelpunkt (2,2) bleibt frei, also (4…5, 4…5).
        let umriss = try bild(#"{"draw":[["rect",1,1,3,3,"FF0000"]]}"#)
        XCTAssertEqual(belegt(umriss).count, 8 * 4)
        XCTAssertEqual(umriss[4 * breite + 4], 0)
        XCTAssertEqual(umriss[2 * breite + 2], rot)
    }

    func testLineMitBeidenEndpunkten() throws {
        let b = try bild(#"{"draw":[["line",0,0,3,0,"00FF00"]]}"#)
        XCTAssertEqual(belegt(b).count, 4 * 2 * 2)
        XCTAssertEqual(b[0], 0x00FF00)
        XCTAssertEqual(b[7], 0x00FF00)
        XCTAssertEqual(b[8], 0)
    }

    func testPixelsTragenDieFarbeZuerst() throws {
        let b = try bild(#"{"draw":[["pixels","0000FF",0,0,2,0]]}"#)
        XCTAssertEqual(belegt(b).count, 8)
        XCTAssertEqual(b[0], 0x0000FF)
        XCTAssertEqual(b[4], 0x0000FF)
    }

    func testOhneFarbeGiltDieTextfarbeDerAnzeige() throws {
        let b = try bild(#"{"textColor":"112233","draw":[["pixel",0,0]]}"#)
        XCTAssertEqual(b[0], 0x112233)
        let global = try bild(#"{"draw":[["pixel",0,0]]}"#)
        XCTAssertEqual(global[0], 0xFFFFFF)
    }

    func testBitmapAlsFarbfeldUndAlsBase64() throws {
        let feld = try bild(#"{"draw":[["bitmap",0,0,2,1,["FF0000","00FF00"]]]}"#)
        XCTAssertEqual(feld[0], 0xFF0000)
        XCTAssertEqual(feld[2], 0x00FF00)
        XCTAssertEqual(feld[3], 0x00FF00)
        XCTAssertEqual(feld[breite + 2], 0x00FF00)
        // FF0000 00FF00 als RGB888, Base64
        let roh = Data([0xFF, 0, 0, 0, 0xFF, 0]).base64EncodedString()
        let b64 = try bild(#"{"draw":[["bitmap",0,0,2,1,""# + roh + #""]]}"#)
        XCTAssertEqual(b64, feld)
    }

    func testEinZuKurzesBitmapLaesstDenRestUngezeichnet() throws {
        let roh = Data([0xFF, 0, 0]).base64EncodedString()
        let b = try bild(#"{"draw":[["bitmap",0,0,2,1,""# + roh + #""]]}"#)
        XCTAssertEqual(b[0], 0xFF0000)
        XCTAssertEqual(b[2], 0)
    }

    func testSchwarzAlsFarbeUeberzeichnetDenHintergrund() throws {
        let b = try bild(#"{"backgroundColor":"FF0000","draw":[["pixel",0,0,"000000"]]}"#)
        XCTAssertEqual(b[0], 0)
        XCTAssertEqual(b[4], rot)
    }

    // MARK: Layout auf dem 52×16-Raster

    func testImLayoutLandetEinPixelGenauRelativZurBox() throws {
        let b = try bild(#"{"layout":{"version":1,"regions":[{"id":"a","box":[10,4,8,6],"draw":[["pixel",0,0,"FF0000"],["pixel",7,5,"FF0000"]]}]}}"#)
        XCTAssertEqual(belegt(b), [[10, 4], [17, 9]])
    }

    func testImLayoutWirdAnDerBoxAbgeschnitten() throws {
        let b = try bild(#"{"layout":{"version":1,"regions":[{"id":"a","box":[0,0,4,4],"draw":[["rectFill",0,0,10,10,"FF0000"]]}]}}"#)
        XCTAssertEqual(belegt(b).count, 16)
    }

    func testImLayoutBitmapAlsBase64Pixelgenau() throws {
        let roh = Data([0xFF, 0, 0, 0, 0xFF, 0]).base64EncodedString()
        let b = try bild(#"{"layout":{"version":1,"regions":[{"id":"a","box":[0,0,52,16],"draw":[["bitmap",50,15,2,1,""# + roh + #""]]}]}}"#)
        XCTAssertEqual(belegt(b), [[50, 15], [51, 15]])
        XCTAssertEqual(b[15 * breite + 50], 0xFF0000)
        XCTAssertEqual(b[15 * breite + 51], 0x00FF00)
    }

    func testDieRegionsfarbeGiltFuerBefehleOhneFarbe() throws {
        let b = try bild(#"{"layout":{"version":1,"regions":[{"id":"a","box":[0,0,52,16],"color":"00FF00","draw":[["pixel",3,3]]}]}}"#)
        XCTAssertEqual(b[3 * breite + 3], 0x00FF00)
    }

    // MARK: Auskunft über HTTP

    func testDisplayScreenLiefertDasGezeichneteBild() throws {
        var z = NGUhrzustand()
        let put = Virtuelleuhr.Anfrage("PUT", "/api/v1/apps/pushed/x",
                                       koerper: Data(#"{"draw":[["pixel",0,0,"FF0000"]]}"#.utf8),
                                       kopf: ["content-type": "application/json"])
        XCTAssertEqual(VirtuelleNGUhr.beantworten(put, &z).status, 200)
        let aktiv = Virtuelleuhr.Anfrage("PUT", "/api/v1/apps/active", koerper: Data("x".utf8))
        XCTAssertEqual(VirtuelleNGUhr.beantworten(aktiv, &z).status, 200)

        let r = VirtuelleNGUhr.beantworten(Virtuelleuhr.Anfrage("GET", "/api/v1/display/screen"), &z)
        let o = try XCTUnwrap(try JSONSerialization.jsonObject(with: r.koerper) as? [String: Any])
        XCTAssertEqual(o["width"] as? Int, 52)
        XCTAssertEqual(o["height"] as? Int, 16)
        let pixel = try XCTUnwrap(o["pixels"] as? [Int])
        XCTAssertEqual(pixel.count, 832)
        XCTAssertEqual(pixel[0], 0xFF0000)
        XCTAssertEqual(pixel[1], 0xFF0000)
        XCTAssertEqual(pixel[52], 0xFF0000)
        XCTAssertEqual(pixel[2], 0)
    }
}
