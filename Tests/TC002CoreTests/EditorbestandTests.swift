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

    /// Der Weg fuer ein eben geholtes Icon, das auf die Leinwand soll: Die
    /// Groesse kommt aus der **Kante des Icons**. Ein LaMetric-Icon ist zwar
    /// immer 8×8, aber dieselbe Annahme hat den Import bis zum 13.09.2026 auf
    /// die eingestellte Leinwandgroesse heruntergerechnet — sie steht hier
    /// nirgends mehr.
    ///
    /// Mutation: in `eintrag(fuer:)` die Groesse fest auf `.icon8` setzen —
    /// dann landet ein 16×16 als 8×8 auf der Leinwand und traegt eine Nummer,
    /// die es bei dieser Groesse gar nicht gibt.
    func testDerEintragZuEinemIconNimmtDieGroesseAusDerKante() throws {
        let acht = Icon(nummer: "4711", name: "Acht", kategorie: "",
                        datei: wurzel.appendingPathComponent("Icons/4711.gif"), kante: 8)
        let sechzehn = Icon(nummer: "egal", name: "Sechzehn", kategorie: "",
                            datei: wurzel.appendingPathComponent("Icons16/Sechzehn.gif"), kante: 16)

        let a = try XCTUnwrap(Editorbestand.eintrag(fuer: acht))
        XCTAssertEqual(a.groesse, .icon8)
        XCTAssertEqual(a.nummer, "4711")
        XCTAssertEqual(a.datei, acht.datei)

        let s = try XCTUnwrap(Editorbestand.eintrag(fuer: sechzehn))
        XCTAssertEqual(s.groesse, .icon16)
        XCTAssertNil(s.nummer, "bei 16×16 gibt es keine Nummer")

        XCTAssertNil(Editorbestand.eintrag(fuer: Icon(nummer: "1", name: "Fremd", kategorie: "",
                                                      datei: wurzel, kante: 12)),
                     "eine fremde Kante ist keine der drei Groessen")
    }

    /// **Ulanzi vergibt auch fuer 16×52 Nummern** — eine Anzeige hat also eine,
    /// *heisst* aber weiter nach ihrem Namen. Die Nummer steht daneben in
    /// `names.json`; der Dateiname bleibt unberuehrt, sonst laege jede
    /// bestehende Bildersammlung unter neuen Schluesseln.
    ///
    /// Mutation: in `Editorbestand.sichern` die Nummer nicht mehr an
    /// `bilder.sichern` durchreichen — dann ist die Werknummer nach dem
    /// naechsten Sichern weg, ohne dass jemand sie geloescht haette.
    /// (Dass der **Dateiname** von der Nummer unberuehrt bleibt, haelt
    /// `BildersammlungTests.testDieWerknummerAendertDenDateinamenNicht` fest,
    /// und dass `schluessel` weiter den Namen liefert,
    /// `LeinwandgroesseTests.testNurDasAchtmalAchtHeisstNachSeinerNummer`.)
    func testDieAnzeigeHatEineNummerHeisstAberNachIhremNamen() throws {
        let eintrag = try bestand.sichern(gemalt(.anzeige), name: "Mario", nummer: "318")
        XCTAssertEqual(eintrag.datei.lastPathComponent, "Mario.gif",
                       "die Anzeige liegt unter ihrer Nummer statt unter ihrem Namen")
        XCTAssertEqual(eintrag.nummer, "318")

        let gelesen = try XCTUnwrap(bestand.alle().first { $0.groesse == .anzeige })
        XCTAssertEqual(gelesen.name, "Mario")
        XCTAssertEqual(gelesen.nummer, "318", "die Werknummer überlebt das Zurücklesen nicht")
    }

    /// Die Nummer ist bei 16×52 **wahlfrei**: Ohne sie laesst sich sichern,
    /// und dann steht auch keine da — nicht eine leere.
    ///
    /// Mutation: in `Bildersammlung.sichern` die Nummer ungeprueft
    /// weiterreichen (`namenErgaenzen(… nummer: nummer)`) — dann traegt jedes
    /// ohne Nummer gesicherte Bild eine leere, und `nummer` ist „" statt nil.
    func testOhneWerknummerLaesstSichEineAnzeigeSichern() throws {
        let eintrag = try bestand.sichern(gemalt(.anzeige), name: "Ohne", nummer: "  ")
        XCTAssertNil(eintrag.nummer)
        XCTAssertNil(try XCTUnwrap(bestand.alle().first { $0.groesse == .anzeige }).nummer)
    }

    /// Eine Leinwand, die keine der drei Groessen hat, wird abgelehnt statt
    /// stillschweigend im naechstbesten Ordner zu landen.
    func testEineFremdeGroesseWirdAbgelehnt() {
        XCTAssertThrowsError(try bestand.sichern(Leinwand(breite: 32, hoehe: 32),
                                                 name: "Fremd", nummer: "1"))
    }
}
