import XCTest
@testable import TC002Core

/// Die drei Bestaende unter einem Dach — und die Frage, die dabei allein
/// zaehlt: Wohin gehoert etwas? Die Groesse entscheidet.
///
/// Geschrieben wird ausschliesslich in ein Wegwerfverzeichnis; die wirklichen
/// Ordner unter `Application Support` fasst kein Test an.
final class EditorbestandTests: XCTestCase {
    private var wurzel: URL!
    private var bestand: Editorbestand!

    override func setUpWithError() throws {
        wurzel = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Editorbestand-\(UUID().uuidString)")
        for teil in ["Icons", "Icons16", "Bilder"] {
            try FileManager.default.createDirectory(
                at: wurzel.appendingPathComponent(teil), withIntermediateDirectories: true)
        }
        bestand = Editorbestand(
            icons8: Iconsammlung(schreibordner: wurzel.appendingPathComponent("Icons")),
            icons16: Iconsammlung(schreibordner: wurzel.appendingPathComponent("Icons16"), kante: 16),
            bilder: Bildersammlung(ordner: wurzel.appendingPathComponent("Bilder")))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: wurzel)
    }

    private func gemalt(_ groesse: Leinwandgroesse, _ farbe: String = "#FF00AA") -> Leinwand {
        var l = groesse.leereLeinwand
        l.setzen(x: 1, y: 1, farbe: farbe)
        return l
    }

    /// Der Kern der Sache: Dieselbe Handlung, drei Ziele — und die Groesse
    /// allein entscheidet welches. Nachgewiesen am Ordner, in dem die Datei
    /// landet, nicht an dem, was der Rueckgabewert behauptet.
    func testDieGroesseEntscheidetInWelchenBestand() throws {
        try bestand.sichern(gemalt(.icon8), name: "Acht", nummer: "4711")
        try bestand.sichern(gemalt(.icon16), name: "Sechzehn", nummer: "wird ignoriert")
        try bestand.sichern(gemalt(.anzeige), name: "Ganze Anzeige", nummer: "")

        func dateien(_ teil: String) -> [String] {
            ((try? FileManager.default.contentsOfDirectory(
                atPath: wurzel.appendingPathComponent(teil).path)) ?? [])
                .filter { $0.hasSuffix(".gif") }.sorted()
        }
        XCTAssertEqual(dateien("Icons"), ["4711.gif"])
        XCTAssertEqual(dateien("Icons16"), ["Sechzehn.gif"],
                       "bei 16×16 ist der Name der Dateiname, nicht die Nummer")
        XCTAssertEqual(dateien("Bilder"), ["Ganze Anzeige.gif"])
    }

    /// Eine Liste, die Groesse am Eintrag — und die Nummer nur dort, wo es
    /// eine gibt.
    func testAlleStehenInEinerListeMitIhrerGroesse() throws {
        try bestand.sichern(gemalt(.anzeige), name: "Zebra", nummer: "")
        try bestand.sichern(gemalt(.icon16), name: "Anton", nummer: "")
        try bestand.sichern(gemalt(.icon8), name: "Berta", nummer: "12")

        let alle = bestand.alle()
        XCTAssertEqual(alle.map(\.groesse), [.icon8, .icon16, .anzeige],
                       "nach Größe sortiert, sonst ist das Merkmal am Eintrag eine Suchaufgabe")
        XCTAssertEqual(alle.map(\.name), ["Berta", "Anton", "Zebra"])
        XCTAssertEqual(alle.map(\.nummer), ["12", nil, nil],
                       "eine Nummer gibt es nur beim kanonischen 8×8")
    }

    /// Ein 8×8 und ein 16×16 duerfen denselben Namen tragen, ohne sich in die
    /// Quere zu kommen — das war schon vorher so und bleibt es.
    func testGleicherNameInZweiBestaendenBleibtZweiEintraege() throws {
        try bestand.sichern(gemalt(.icon8), name: "Herz", nummer: "Herz")
        try bestand.sichern(gemalt(.icon16), name: "Herz", nummer: "")
        let treffer = bestand.alle().filter { $0.name == "Herz" }
        XCTAssertEqual(treffer.count, 2)
        XCTAssertEqual(Set(treffer.map(\.id)).count, 2, "die beiden dürfen nicht denselben Schlüssel haben")
    }

    func testGesuchtWirdUeberAlleBestaendeHinweg() throws {
        try bestand.sichern(gemalt(.icon8), name: "Sonne", nummer: "900")
        try bestand.sichern(gemalt(.anzeige), name: "Sonnenaufgang", nummer: "")
        try bestand.sichern(gemalt(.icon16), name: "Mond", nummer: "")

        XCTAssertEqual(bestand.gefiltert(nach: "sonne").map(\.name), ["Sonne", "Sonnenaufgang"])
        XCTAssertEqual(bestand.gefiltert(nach: "900").map(\.name), ["Sonne"],
                       "die Nummer gehört mit in die Suche")
        XCTAssertEqual(bestand.gefiltert(nach: "  ").count, 3, "leere Suche lässt die Liste stehen")
    }

    /// Zurueck auf die Leinwand: alle Einzelbilder, in der richtigen Groesse,
    /// mit der Standzeit aus der Datei.
    func testEinEintragKommtVollstaendigZurueck() throws {
        var leinwand = Leinwandgroesse.anzeige.leereLeinwand
        leinwand.verzoegerung = 0.35
        leinwand.setzen(x: 0, y: 0, farbe: "#FF0000")
        leinwand.anhaengen()
        leinwand.setzen(x: 51, y: 15, farbe: "#00FF00")
        let eintrag = try bestand.sichern(leinwand, name: "Zwei Bilder", nummer: "")

        let zurueck = try bestand.oeffnen(eintrag)
        XCTAssertEqual(Leinwandgroesse.fuer(zurueck), .anzeige)
        XCTAssertEqual(zurueck.bilder.count, 2, "das zweite Einzelbild darf nicht verloren gehen")
        XCTAssertEqual(zurueck.verzoegerung, 0.35, accuracy: 0.01,
                       "die Standzeit kommt aus der Datei, nicht vom Anfangswert")
        XCTAssertEqual(zurueck.bilder[0][0], "#FF0000")
        XCTAssertEqual(zurueck.bilder[1][15 * 52 + 51], "#00FF00")
    }

    func testLoeschenTrifftDenRichtigenBestand() throws {
        try bestand.sichern(gemalt(.icon8), name: "Weg", nummer: "1")
        try bestand.sichern(gemalt(.icon16), name: "Weg", nummer: "")
        let achter = try XCTUnwrap(bestand.alle().first { $0.groesse == .icon8 })
        try bestand.loeschen(achter)
        XCTAssertEqual(bestand.alle().map(\.groesse), [.icon16],
                       "gelöscht wurde im falschen Bestand")
    }

    /// Ohne Namen wird nichts abgelegt — sonst entstuende eine Datei, die
    /// niemand wiederfindet.
    func testOhneNamenWirdNichtsGesichert() {
        XCTAssertThrowsError(try bestand.sichern(gemalt(.anzeige), name: "   ", nummer: ""))
        XCTAssertThrowsError(try bestand.sichern(gemalt(.icon8), name: "Da", nummer: " "))
        XCTAssertTrue(bestand.alle().isEmpty)
    }

    /// Eine Leinwand, die keine der drei Groessen hat, wird abgelehnt statt
    /// stillschweigend im naechstbesten Ordner zu landen.
    func testEineFremdeGroesseWirdAbgelehnt() {
        XCTAssertThrowsError(try bestand.sichern(Leinwand(breite: 32, hoehe: 32),
                                                 name: "Fremd", nummer: "1"))
    }
}
