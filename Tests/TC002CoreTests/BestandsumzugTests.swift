import XCTest
@testable import TC002Core

/// Der Umzug in den iCloud-Behaelter und zurueck. Alles laeuft gegen
/// Wegwerfverzeichnisse — nie gegen `Application Support` und nie gegen einen
/// echten Behaelter.
final class BestandsumzugTests: XCTestCase {
    private var wurzel = URL(fileURLWithPath: "/")

    override func setUp() {
        super.setUp()
        wurzel = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("umzug-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: wurzel, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: wurzel)
        super.tearDown()
    }

    private func ort(gewuenscht: Bool = true, mitBehaelter: Bool = true) -> Ablageort {
        Ablageort(oertlicheWurzel: wurzel.appendingPathComponent("oertlich"),
                  ferneWurzel: mitBehaelter ? wurzel.appendingPathComponent("wolke") : nil,
                  gewuenscht: gewuenscht).angelegt()
    }

    private func schreiben(_ inhalt: String, _ ordner: URL, _ name: String) {
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? Data(inhalt.utf8).write(to: ordner.appendingPathComponent(name))
    }

    private func inhalt(_ ordner: URL, _ name: String) -> String? {
        (try? Data(contentsOf: ordner.appendingPathComponent(name))).map {
            String(decoding: $0, as: UTF8.self)
        }
    }

    // MARK: Hinweg

    /// **Der Kern des Rueckwegs liegt im Hinweg.** Kopiert wird, nicht
    /// verschoben: Nach dem Einschalten liegt der oertliche Bestand
    /// unveraendert da, wo er lag.
    func testHinwegKopiertUndLaesstDenOertlichenBestandStehen() {
        let o = ort()
        schreiben("BUS", o.oertlicherOrdner(.icons8), "1673.gif")
        let bilanz = Bestandsumzug.hinweg(o)
        XCTAssertEqual(bilanz.kopiert, 1)
        XCTAssertEqual(inhalt(o.fernerOrdner(.icons8)!, "1673.gif"), "BUS")
        XCTAssertEqual(inhalt(o.oertlicherOrdner(.icons8), "1673.gif"), "BUS",
                       "der oertliche Bestand bleibt — er ist der Rueckweg")
    }

    /// Im Behaelter kann schon der Bestand des **anderen** Geraets liegen. Ihn
    /// zu ueberschreiben waere das Gegenteil eines Abgleichs.
    func testHinwegLaesstDenBehaelterInRuhe() {
        let o = ort()
        schreiben("hier", o.oertlicherOrdner(.icons8), "1673.gif")
        schreiben("vom anderen Geraet", o.fernerOrdner(.icons8)!, "1673.gif")
        let bilanz = Bestandsumzug.hinweg(o)
        XCTAssertEqual(bilanz.uebersprungen, 1)
        XCTAssertEqual(bilanz.kopiert, 0)
        XCTAssertEqual(inhalt(o.fernerOrdner(.icons8)!, "1673.gif"), "vom anderen Geraet")
    }

    /// Alle vier, nicht drei. Ein vergessener Bestand faellt erst dem Anwender
    /// auf — und dann als verschwundene Sammlung.
    func testAlleVierBestaendeZiehenMit() {
        let o = ort()
        schreiben("a", o.oertlicherOrdner(.icons8), "1.gif")
        schreiben("b", o.oertlicherOrdner(.icons16), "2.gif")
        schreiben("c", o.oertlicherOrdner(.bilder), "3.gif")
        schreiben("d", o.oertlicherOrdner(.slots), "4.json")
        XCTAssertEqual(Bestandsumzug.hinweg(o).kopiert, 4)
        XCTAssertEqual(inhalt(o.fernerOrdner(.icons8)!, "1.gif"), "a")
        XCTAssertEqual(inhalt(o.fernerOrdner(.icons16)!, "2.gif"), "b")
        XCTAssertEqual(inhalt(o.fernerOrdner(.bilder)!, "3.gif"), "c")
        XCTAssertEqual(inhalt(o.fernerOrdner(.slots)!, "4.json"), "d")
    }

    // MARK: Rueckweg

    /// Abschalten holt zurueck, was im Behaelter steht — oertlich liegt nur
    /// noch die Momentaufnahme vom Tag des Einschaltens.
    func testRueckwegHoltDenBehaelterZurueck() {
        let o = ort()
        schreiben("alt", o.oertlicherOrdner(.bilder), "nacht.gif")
        schreiben("seither bearbeitet", o.fernerOrdner(.bilder)!, "nacht.gif")
        XCTAssertEqual(Bestandsumzug.rueckweg(o).kopiert, 1)
        XCTAssertEqual(inhalt(o.oertlicherOrdner(.bilder), "nacht.gif"), "seither bearbeitet")
    }

    /// Abschalten nimmt nie etwas weg. Was nur oertlich liegt, bleibt liegen.
    func testRueckwegNimmtNichtsWeg() {
        let o = ort()
        schreiben("nur hier", o.oertlicherOrdner(.bilder), "eigen.gif")
        schreiben("aus der Wolke", o.fernerOrdner(.bilder)!, "fremd.gif")
        Bestandsumzug.rueckweg(o)
        XCTAssertEqual(inhalt(o.oertlicherOrdner(.bilder), "eigen.gif"), "nur hier")
        XCTAssertEqual(inhalt(o.oertlicherOrdner(.bilder), "fremd.gif"), "aus der Wolke")
    }

    // MARK: names.json

    /// `names.json` ist keine gewoehnliche Datei. Sie zu ueberschreiben hiesse,
    /// den Namen jedes Icons zu verlieren, das nur die andere Seite kennt — die
    /// Datei waere da, im Bestand stuende die nackte Nummer.
    func testNamenWerdenZusammengefuehrtStattUeberschrieben() throws {
        let o = ort()
        schreiben(#"[{"nummer":"1","name":"Bus","kategorie":""}]"#,
                  o.oertlicherOrdner(.icons8), "names.json")
        schreiben(#"[{"nummer":"2","name":"Zug","kategorie":""}]"#,
                  o.fernerOrdner(.icons8)!, "names.json")
        Bestandsumzug.hinweg(o)
        let liste = Namensliste.gelesen(o.fernerOrdner(.icons8)!
            .appendingPathComponent("names.json"))
        XCTAssertEqual(Set(liste.compactMap { $0["name"] }), ["Bus", "Zug"])
    }

    /// Bei gleicher Nummer fuehrt der Behaelter — dieselbe Regel, nach der
    /// auch seine Dateien gewinnen.
    func testBeiGleicherNummerGewinntDerBehaelter() {
        let o = ort()
        schreiben(#"[{"nummer":"1","name":"alt"}]"#, o.oertlicherOrdner(.icons8), "names.json")
        schreiben(#"[{"nummer":"1","name":"neu"}]"#, o.fernerOrdner(.icons8)!, "names.json")
        Bestandsumzug.hinweg(o)
        let liste = Namensliste.gelesen(o.fernerOrdner(.icons8)!
            .appendingPathComponent("names.json"))
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?["name"], "neu")
    }

    /// **Auch der Rueckweg fuehrt zusammen.** Er ueberschreibt Dateien, und
    /// waere `names.json` eine davon, ginge dabei jeder Name verloren, den nur
    /// der oertliche Bestand kennt — ausgerechnet beim Abschalten, dem
    /// Vorgang, der nichts wegnehmen darf.
    func testAuchDerRueckwegVerliertKeinenNamen() {
        let o = ort()
        schreiben(#"[{"nummer":"1","name":"nur oertlich"}]"#,
                  o.oertlicherOrdner(.icons8), "names.json")
        schreiben(#"[{"nummer":"2","name":"aus der Wolke"}]"#,
                  o.fernerOrdner(.icons8)!, "names.json")
        Bestandsumzug.rueckweg(o)
        let liste = Namensliste.gelesen(o.oertlicherOrdner(.icons8)
            .appendingPathComponent("names.json"))
        XCTAssertEqual(Set(liste.compactMap { $0["name"] }), ["nur oertlich", "aus der Wolke"])
    }

    /// Bilder schluesseln ueber `datei`, Icons ueber `nummer` — eine Regel
    /// muss beide treffen, sonst zieht die Bildersammlung ihre Namen nicht mit.
    func testDieBilderlisteSchluesseltUeberDenDateinamen() {
        let o = ort()
        schreiben(#"[{"datei":"nacht","name":"Nachtbild"}]"#,
                  o.oertlicherOrdner(.bilder), "names.json")
        Bestandsumzug.hinweg(o)
        let liste = Namensliste.gelesen(o.fernerOrdner(.bilder)!
            .appendingPathComponent("names.json"))
        XCTAssertEqual(liste.first?["name"], "Nachtbild")
    }

    // MARK: Ohne Behaelter

    /// Ohne Behaelter gibt es nichts umzuziehen — und es entsteht auch nichts.
    func testOhneBehaelterGeschiehtNichts() {
        let o = ort(mitBehaelter: false)
        schreiben("a", o.oertlicherOrdner(.icons8), "1.gif")
        XCTAssertEqual(Bestandsumzug.hinweg(o), Bestandsumzug.Bilanz())
        XCTAssertEqual(Bestandsumzug.rueckweg(o), Bestandsumzug.Bilanz())
        XCTAssertEqual(inhalt(o.oertlicherOrdner(.icons8), "1.gif"), "a")
    }
}

/// Das Umschalten selbst — gegen Wegwerfverzeichnisse und eine Wegwerf-Ablage,
/// nie gegen den echten Behaelter und nie gegen die echten Einstellungen.
final class UmschaltenTests: XCTestCase {
    private var wurzel = URL(fileURLWithPath: "/")
    private var bereich = ""

    override func setUp() {
        super.setUp()
        wurzel = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("umschalten-\(UUID().uuidString)")
        bereich = "cloud.eriks.mqtt-tc002.test.\(UUID().uuidString)"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: wurzel)
        UserDefaults().removePersistentDomain(forName: bereich)
        super.tearDown()
    }

    private var oertlich: URL { wurzel.appendingPathComponent("oertlich") }
    private var wolke: URL { wurzel.appendingPathComponent("wolke") }

    private func schreiben(_ inhalt: String, _ ordner: URL, _ name: String) {
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? Data(inhalt.utf8).write(to: ordner.appendingPathComponent(name))
    }

    private func inhalt(_ ordner: URL, _ name: String) -> String? {
        (try? Data(contentsOf: ordner.appendingPathComponent(name))).map {
            String(decoding: $0, as: UTF8.self)
        }
    }

    private func umschalten(_ an: Bool, behaelter: URL?) -> Umschaltergebnis {
        Ablageort.umschalten(an, bereich: bereich, oertlicheWurzel: oertlich,
                             behaelter: { behaelter })
    }

    /// Einschalten: kopiert hinauf und merkt sich die Wahl dort, wo auch das
    /// Werkzeug sie findet.
    func testEinschaltenZiehtUmUndMerktSichDieWahl() {
        schreiben("BUS", oertlich.appendingPathComponent("Icons"), "1673.gif")
        let ergebnis = umschalten(true, behaelter: wolke)
        XCTAssertEqual(ergebnis, Umschaltergebnis(gewaehlt: true, bereit: true,
                                                  bilanz: .init(kopiert: 1)))
        XCTAssertTrue(Ablageort.gewaehlt(bereich: bereich))
        XCTAssertEqual(inhalt(wolke.appendingPathComponent("Icons"), "1673.gif"), "BUS")
    }

    /// **Der Normalfall ohne Berechtigung.** Kein Behaelter: Die Wahl bleibt
    /// aus, statt auf „an" zu stehen und nichts zu tun — und kopiert wird
    /// nichts.
    func testOhneBehaelterBleibtDieWahlAus() {
        schreiben("BUS", oertlich.appendingPathComponent("Icons"), "1673.gif")
        let ergebnis = umschalten(true, behaelter: nil)
        XCTAssertEqual(ergebnis, Umschaltergebnis(gewaehlt: false, bereit: false, bilanz: .init()))
        XCTAssertFalse(Ablageort.gewaehlt(bereich: bereich))
        XCTAssertEqual(inhalt(oertlich.appendingPathComponent("Icons"), "1673.gif"), "BUS")
    }

    /// **Der Rueckweg.** Wer abschaltet, behaelt seine Sachen — auch die, die
    /// erst nach dem Einschalten dazugekommen sind.
    func testAbschaltenBringtAllesZurueck() {
        schreiben("alt", oertlich.appendingPathComponent("Bilder"), "nacht.gif")
        umschalten(true, behaelter: wolke)
        // Seither in der Wolke gearbeitet: eines geaendert, eines dazu.
        schreiben("seither bearbeitet", wolke.appendingPathComponent("Bilder"), "nacht.gif")
        schreiben("am Telefon gemalt", wolke.appendingPathComponent("Bilder"), "tag.gif")

        let ergebnis = umschalten(false, behaelter: wolke)
        XCTAssertFalse(ergebnis.gewaehlt)
        XCTAssertFalse(Ablageort.gewaehlt(bereich: bereich))
        XCTAssertEqual(inhalt(oertlich.appendingPathComponent("Bilder"), "nacht.gif"),
                       "seither bearbeitet")
        XCTAssertEqual(inhalt(oertlich.appendingPathComponent("Bilder"), "tag.gif"),
                       "am Telefon gemalt")
    }

    /// Auch das Slotgedaechtnis kommt zurueck — sonst wuesste das Geraet nach
    /// dem Abschalten nicht mehr, was es selbst zuletzt geschickt hat.
    func testAuchDasSlotgedaechtnisKommtZurueck() {
        umschalten(true, behaelter: wolke)
        schreiben("[]", wolke.appendingPathComponent("Slots"), "abc.json")
        umschalten(false, behaelter: wolke)
        XCTAssertEqual(inhalt(oertlich.appendingPathComponent("Slots"), "abc.json"), "[]")
    }
}
