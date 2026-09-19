import XCTest
@testable import TC002Core

/// Der Weg von einer Datei des Bilderbestands zu dem, was hinausgeht.
final class BildsendungTests: XCTestCase {
    private func temp() -> URL {
        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("bildsendung-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner
    }

    private func feld(punkt: (x: Int, y: Int), farbe: String) -> Pixelfeld {
        var f = Pixelfeld()
        f.setzen(x: punkt.x, y: punkt.y, farbe: farbe)
        return f
    }

    /// Ein Einzelbild geht als `draw` — Rechtecke, klein und exakt.
    func testEinStehendesBildGehtAlsRechtecke() throws {
        let sammlung = Bildersammlung(ordner: temp())
        let gemaltes = try sammlung.sichern(name: "Einer", feld: feld(punkt: (3, 2), farbe: "#FF8800"))

        let rahmen = try Bildsendung.rahmen(aus: gemaltes.datei)
        XCTAssertEqual(rahmen.draw.count, 1)
        XCTAssertTrue(rahmen.bilder.isEmpty, "ein stehendes Bild braucht kein GIF")
        XCTAssertNil(rahmen.dauer)
    }

    /// Mehrere gehen als GIF — Rechtecke kennen keine Zeit.
    func testMehrereEinzelbilderGehenAlsGif() throws {
        let sammlung = Bildersammlung(ordner: temp())
        var eins = [String?](repeating: nil, count: 52 * 16); eins[0] = "#FF0000"
        var zwei = [String?](repeating: nil, count: 52 * 16); zwei[51] = "#00FF66"
        let gemaltes = try sammlung.sichern(name: "Laeufer", bilder: [eins, zwei], verzoegerung: 0.2)

        let rahmen = try Bildsendung.rahmen(aus: gemaltes.datei, dauer: 7)
        XCTAssertTrue(rahmen.draw.isEmpty)
        XCTAssertEqual(rahmen.bilder.count, 1)
        XCTAssertTrue(rahmen.bilder[0].datenURI.hasPrefix("data:image/gif;base64,"))
        XCTAssertEqual(rahmen.dauer, 7)
    }

    /// Eine Datei, die kein Bild ist, wird nicht zu einem leeren Rahmen — sie
    /// wirft. Ein leerer Rahmen loeschte beim Senden die Anzeige.
    func testEineUnlesbareDateiWirft() throws {
        let ordner = temp()
        let datei = ordner.appendingPathComponent("kaputt.gif")
        try Data("kein Bild".utf8).write(to: datei)
        XCTAssertThrowsError(try Bildsendung.rahmen(aus: datei))
    }
}

/// Beide Wege müssen dasselbe ergeben — der Editor reicht Einzelbilder aus
/// dem Speicher, das Telefon eine Datei. Liefen sie auseinander, sähe dieselbe
/// Anzeige auf der Uhr verschieden aus, je nachdem, von wo sie geschickt wurde.
final class BildsendungBeideWegeTests: XCTestCase {
    func testDateiUndSpeicherErgebenDenselbenRahmen() throws {
        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("bildsendung-gleich-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: ordner) }
        let sammlung = Bildersammlung(ordner: ordner)

        var punkte = [String?](repeating: nil, count: 52 * 16)
        punkte[5] = "#FF8800"
        guard let feld = Pixelfeld(punkte: punkte) else { return XCTFail("Feld") }
        let gemaltes = try sammlung.sichern(name: "Gleich", feld: feld)

        let ausDatei = try Bildsendung.rahmen(aus: gemaltes.datei)
        let ausSpeicher = try Bildsendung.rahmen(aus: [punkte], verzoegerung: 0.2)
        XCTAssertEqual(ausDatei.draw, ausSpeicher.draw)
        XCTAssertTrue(ausDatei.bilder.isEmpty && ausSpeicher.bilder.isEmpty)
    }
}

extension BildsendungTests {
    /// Ein gemaltes Icon geht auch an eine AWTRIX NG — als GIF, nicht als
    /// Pixelfeld. Ohne die Herkunft am Rahmen wies `Anzeigen.nutzlast` es als
    /// „gemaltes Bild“ ab und begründete das mit 52 × 16, obwohl auf 8 × 8
    /// gemalt worden war.
    func testEinGemaltesIconTraegtSeineHerkunftUndGehtAnEineNG() throws {
        let bilder: [[String?]] = [Array(repeating: "#FF0000", count: 64),
                                   Array(repeating: "#00FF00", count: 64)]
        let rahmen = try Bildsendung.rahmen(aus: bilder, breite: 8, hoehe: 8, verzoegerung: 0.1)
        let herkunft = try XCTUnwrap(rahmen.herkunft, "dem Icon fehlt die Herkunft")
        XCTAssertEqual(herkunft.iconKante, 8)
        XCTAssertTrue(herkunft.iconDatenURI?.hasPrefix("data:image/gif;base64,") == true,
                      "das Icon reist nicht als GIF mit")

        let nutzlast = try NGNutzlast.anzeige(herkunft.optionen,
                                              iconDatenURI: herkunft.iconDatenURI,
                                              iconKante: herkunft.iconKante)
        XCTAssertTrue(nutzlast.contains("\"icon\""), "die NG-Nutzlast trägt kein Icon")
    }

    /// Eine ganze Anzeige bleibt, was sie war: Sie hat sechzehn Zeilen und
    /// bekommt keine Herkunft — eine AWTRIX mit acht Zeilen nimmt sie nicht.
    func testEineGanzeAnzeigeBekommtKeineHerkunft() throws {
        let bild: [[String?]] = [Array(repeating: "#FFFFFF", count: 52 * 16)]
        let rahmen = try Bildsendung.rahmen(aus: bild, verzoegerung: 0.1)
        XCTAssertNil(rahmen.herkunft, "eine ganze Anzeige gibt sich als Icon aus")
    }

    /// Ein 16×16 trägt seine Herkunft, wird von NG aber mit dem richtigen
    /// Grund abgewiesen: zu hoch für acht Zeilen — nicht „kein Pixelweg“.
    func testEinSechzehnerIconWirdMitDemRichtigenGrundAbgewiesen() throws {
        let bild: [[String?]] = [Array(repeating: "#FFFFFF", count: 256)]
        let rahmen = try Bildsendung.rahmen(aus: bild, breite: 16, hoehe: 16, verzoegerung: 0.1)
        let herkunft = try XCTUnwrap(rahmen.herkunft)
        XCTAssertThrowsError(try NGNutzlast.anzeige(herkunft.optionen,
                                                    iconDatenURI: herkunft.iconDatenURI,
                                                    iconKante: herkunft.iconKante)) { fehler in
            guard case NGFehler.iconZuHoch(let kante) = fehler else {
                return XCTFail("falscher Grund: \(fehler)")
            }
            XCTAssertEqual(kante, 16)
        }
    }
}

extension BildsendungTests {
    /// Was auf die Anzeige passt, wird aufgenommen und mittig eingepasst —
    /// ein Banner von 52 × 11 etwa. Gerechnet wird dabei nichts: Die Ränder
    /// bleiben leer, die Zeichnung bleibt Pixel für Pixel dieselbe.
    func testEinKleineresBildWirdMittigEingepasst() throws {
        let breit = 52, hoch = 11
        var pixel = [String?](repeating: nil, count: breit * hoch)
        pixel[0] = "#FF0000"                       // links oben in der Quelle
        pixel[breit * hoch - 1] = "#00FF00"        // rechts unten
        let uri = try Bildraster.alsDatenURI([pixel], breite: breit, hoehe: hoch, verzoegerung: 0.1)
        let roh = try XCTUnwrap(Data(base64Encoded: String(uri.split(separator: ",").last!)))

        let eingepasst = try Bildraster.eingepasst(roh, breite: 52, hoehe: 16)
        let masse = try XCTUnwrap(Bildraster.groesse(eingepasst))
        XCTAssertEqual(masse.breite, 52)
        XCTAssertEqual(masse.hoehe, 16)

        let bilder = try Bildraster.lesenMitZeiten(eingepasst, breite: 52, hoehe: 16)
        let feld = try XCTUnwrap(bilder.first).pixel
        // (16 − 11) / 2 = 2 Zeilen Rand oben.
        XCTAssertEqual(feld[2 * 52 + 0], "#FF0000", "die Zeichnung sitzt nicht zwei Zeilen tiefer")
        XCTAssertNil(feld[0], "die Randzeile ist nicht leer geblieben")
    }

    /// Passt es genau, kommen die Bytes unveraendert zurueck — kein
    /// Neuschreiben, kein Qualitaetsverlust.
    func testEinPassendesBildBleibtUnveraendert() throws {
        let pixel = [String?](repeating: "#FFFFFF", count: 52 * 16)
        let uri = try Bildraster.alsDatenURI([pixel], breite: 52, hoehe: 16, verzoegerung: 0.1)
        let roh = try XCTUnwrap(Data(base64Encoded: String(uri.split(separator: ",").last!)))
        XCTAssertEqual(try Bildraster.eingepasst(roh, breite: 52, hoehe: 16), roh)
    }
}
