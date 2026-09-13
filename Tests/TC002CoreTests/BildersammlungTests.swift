import XCTest
@testable import TC002Core

final class BildersammlungTests: XCTestCase {
    /// Ein frischer, noch nicht angelegter Ordnerpfad unter dem temporaeren
    /// Verzeichnis — anlegen bleibt Sache des Aufrufers bzw. von `sichern`.
    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    func testRundlaufUeberDieSammlung() throws {
        let ordner = temp()
        let sammlung = Bildersammlung(ordner: ordner)
        var feld = Pixelfeld()
        feld.setzen(x: 0, y: 0, farbe: "#FF0000")
        feld.setzen(x: 51, y: 15, farbe: "#00FF66")

        let eintrag = try sammlung.sichern(name: "Testbild", feld: feld)
        XCTAssertEqual(eintrag.name, "Testbild")
        XCTAssertEqual(sammlung.alle().map(\.name), ["Testbild"])

        let zurueck = try sammlung.laden(eintrag)
        XCTAssertEqual(zurueck.farbe(x: 0, y: 0), "#FF0000", "oben links bleibt oben links")
        XCTAssertEqual(zurueck.farbe(x: 51, y: 15), "#00FF66", "unten rechts bleibt unten rechts")
        XCTAssertNil(zurueck.farbe(x: 25, y: 8))

        try sammlung.loeschen(eintrag)
        XCTAssertTrue(sammlung.alle().isEmpty)
    }

    func testGleicherNameErsetzt() throws {
        let sammlung = Bildersammlung(ordner: temp())
        var a = Pixelfeld(); a.setzen(x: 1, y: 1, farbe: "#FFFFFF")
        var b = Pixelfeld(); b.setzen(x: 2, y: 2, farbe: "#FFFFFF")
        _ = try sammlung.sichern(name: "gleich", feld: a)
        let zweit = try sammlung.sichern(name: "gleich", feld: b)
        XCTAssertEqual(sammlung.alle().count, 1, "ersetzen, nicht verdoppeln")
        XCTAssertNil(try sammlung.laden(zweit).farbe(x: 1, y: 1))
    }

    func testLeererNameWirdAbgelehnt() {
        let sammlung = Bildersammlung(ordner: temp())
        XCTAssertThrowsError(try sammlung.sichern(name: "  ", feld: Pixelfeld()))
    }

    /// Rundlauf ueber `einfuegen`: eine bereits gesicherte Datei wird unter
    /// einem neuen Namen als eigener Eintrag aufgenommen.
    func testEingefuegteDateiStehtInDerSammlung() throws {
        let sammlung = Bildersammlung(ordner: temp())
        var feld = Pixelfeld()
        feld.setzen(x: 0, y: 0, farbe: "#FF0000")
        let quelle = try sammlung.sichern(name: "Quelle", feld: feld).datei

        let neu = try sammlung.einfuegen(datei: quelle, name: "Kopie")
        XCTAssertEqual(neu.name, "Kopie")
        XCTAssertEqual(try sammlung.laden(neu).farbe(x: 0, y: 0), "#FF0000")
        XCTAssertTrue(sammlung.alle().contains { $0.name == "Kopie" })
    }

    func testEingefuegteNichtBilddateiWirdAbgelehnt() throws {
        let sammlung = Bildersammlung(ordner: temp())
        let kaputt = temp().appendingPathExtension("png")
        try Data("kein Bild".utf8).write(to: kaputt)
        XCTAssertThrowsError(try sammlung.einfuegen(datei: kaputt, name: "x"))
    }

    /// Ein Laufbild behaelt beim Rundlauf durch die Sammlung alle seine
    /// Einzelbilder und ihre Standzeit — sonst waere aus der Animation beim
    /// Sichern ein Standbild geworden.
    func testLaufbildBehaeltSeineEinzelbilder() throws {
        let sammlung = Bildersammlung(ordner: temp())
        let leer = [String?](repeating: nil, count: Pixelfeld.breiteStandard * Pixelfeld.hoeheStandard)
        var erstes = leer, zweites = leer
        erstes[0] = "#FF0000"
        zweites[Pixelfeld.breiteStandard * Pixelfeld.hoeheStandard - 1] = "#00FF66"

        let eintrag = try sammlung.sichern(name: "Lauf", bilder: [erstes, zweites], verzoegerung: 0.4)
        let zurueck = try sammlung.einzelbilder(eintrag)
        // Erst die Zahl, dann erst zugreifen: Bei einem Rueckfall auf ein
        // einzelnes Bild soll der Test melden, nicht abstuerzen.
        guard zurueck.count == 2 else {
            return XCTFail("erwartet: zwei Einzelbilder, bekommen: \(zurueck.count)")
        }
        XCTAssertEqual(zurueck[0].pixel[0], "#FF0000")
        XCTAssertEqual(zurueck[1].pixel.last ?? nil, "#00FF66")
        XCTAssertEqual(zurueck[0].dauer, 0.4, accuracy: 0.001)
    }

    /// Ein eingelesenes animiertes GIF kommt vollstaendig in die Sammlung,
    /// nicht nur mit seinem ersten Einzelbild.
    func testEingelesenesLaufbildBehaeltAlleEinzelbilder() throws {
        let sammlung = Bildersammlung(ordner: temp())
        let leer = [String?](repeating: nil, count: Pixelfeld.breiteStandard * Pixelfeld.hoeheStandard)
        var a = leer, b = leer
        a[0] = "#FF0000"
        b[1] = "#00FF66"
        let quelle = try sammlung.sichern(name: "Quelle", bilder: [a, b], verzoegerung: 0.3).datei

        let kopie = try sammlung.einfuegen(datei: quelle, name: "Kopie")
        XCTAssertEqual(try sammlung.einzelbilder(kopie).count, 2)
    }

    /// Ein einzelnes Bild kommt weiterhin als eines zurueck — die Dateien
    /// frueherer Fassungen bleiben lesbar.
    func testEinzelbildBleibtEinzelbild() throws {
        let sammlung = Bildersammlung(ordner: temp())
        var feld = Pixelfeld()
        feld.setzen(x: 3, y: 4, farbe: "#123456")
        let eintrag = try sammlung.sichern(name: "Einzeln", feld: feld)
        XCTAssertEqual(try sammlung.einzelbilder(eintrag).count, 1)
        XCTAssertEqual(try sammlung.laden(eintrag).farbe(x: 3, y: 4), "#123456")
    }


    /// **Eine `names.json` ohne Nummernfeld bleibt lesbar** — so sieht jede
    /// Sammlung aus, die vor dem 14.09.2026 gesichert wurde. Der Name kommt
    /// weiter von dort, die Nummer gibt es eben nicht.
    ///
    /// In diesem Projekt hat ein Formatwechsel schon einmal beinahe alle
    /// Einstellungen unlesbar gemacht; dies ist derselbe Fall im Kleinen.
    ///
    /// Mutation: in `geladeneNamen` die Nummer verlangen
    /// (`let schluessel = e["datei"], let nummer = e["nummer"]`) — dann faellt
    /// der Name auf den Dateinamen zurueck, und „Mario/Luigi" heisst wieder
    /// „Mario-Luigi".
    func testEineAlteNamensdateiOhneNummerBleibtLesbar() throws {
        let ordner = temp()
        let sammlung = Bildersammlung(ordner: ordner)
        // Ein Name, den der Dateiname **nicht** hergibt: „/" wird zu „-".
        // Nur so haengt der Name wirklich an der Namensdatei und nicht am
        // Dateinamen — sonst ginge dieser Test auch ohne sie durch.
        _ = try sammlung.sichern(name: "Mario/Luigi", feld: Pixelfeld())

        // Die Namensdatei auf den Stand vor der Werknummer zuruecksetzen.
        let alt = [["datei": "Mario-Luigi", "name": "Mario/Luigi"]]
        try JSONSerialization.data(withJSONObject: alt)
            .write(to: ordner.appendingPathComponent("names.json"))

        let gelesen = try XCTUnwrap(sammlung.alle().first)
        XCTAssertEqual(gelesen.name, "Mario/Luigi")
        XCTAssertNil(gelesen.nummer)
    }

    /// Die Werknummer steht **neben** dem Namen, nicht an seiner Stelle: Die
    /// Datei heisst weiter nach dem Namen.
    ///
    /// Mutation: in `sichern` `ordner.appendingPathComponent("\(nummer).gif")`
    /// — dann ersetzt die Nummer den Dateinamen, und wer sie aendert,
    /// verliert das Bild.
    func testDieWerknummerAendertDenDateinamenNicht() throws {
        let sammlung = Bildersammlung(ordner: temp())
        let eintrag = try sammlung.sichern(name: "Mario", bilder: [Pixelfeld().punkteRoh],
                                           verzoegerung: 0.2, nummer: "318")
        XCTAssertEqual(eintrag.datei.lastPathComponent, "Mario.gif")
        XCTAssertEqual(sammlung.alle().first?.nummer, "318")
    }
}
