import XCTest
@testable import TC002Core

/// Die Rechnung hinter den Kurzbefehlen: Grenzen, Vorgaben, Verbote.
final class KurzbefehlswerteTests: XCTestCase {

    // MARK: - Dauer

    func testDauerOhneAngabeOderNullIstKeine() {
        XCTAssertNil(Kurzbefehlswerte.dauer(nil))
        XCTAssertNil(Kurzbefehlswerte.dauer(0))
        XCTAssertNil(Kurzbefehlswerte.dauer(-5))
    }

    func testDauerWirdAufDieObergrenzeGebracht() {
        XCTAssertEqual(Kurzbefehlswerte.dauer(7), 7)
        XCTAssertEqual(Kurzbefehlswerte.dauer(86_400), 86_400)
        XCTAssertEqual(Kurzbefehlswerte.dauer(Int.max), 86_400)
    }

    // MARK: - Lebensdauer

    func testOhneAngabenGiltDieVorgabeDerApp() {
        XCTAssertNil(Kurzbefehlswerte.lebensdauer(minuten: nil, behalten: false, ablauf: nil))
    }

    func testBehaltenSchaltetAb() {
        XCTAssertEqual(Kurzbefehlswerte.lebensdauer(minuten: 10, behalten: true, ablauf: .markieren), .aus)
    }

    func testMinutenWerdenZuSekunden() {
        XCTAssertEqual(Kurzbefehlswerte.lebensdauer(minuten: 5, behalten: false, ablauf: nil),
                       Lebensdauer(sekunden: 300, ablauf: .entfernen))
    }

    func testMinutenWerdenGeklemmt() {
        XCTAssertEqual(Kurzbefehlswerte.lebensdauer(minuten: 0, behalten: false, ablauf: nil)?.sekunden, 60)
        XCTAssertEqual(Kurzbefehlswerte.lebensdauer(minuten: 99_999, behalten: false, ablauf: nil)?.sekunden, 86_400)
    }

    /// Nur den Ablauf zu waehlen aendert nicht die Zeit.
    func testNurDerAblaufBehaeltDieVorgabezeit() {
        XCTAssertEqual(Kurzbefehlswerte.lebensdauer(minuten: nil, behalten: false, ablauf: .markieren),
                       Lebensdauer(sekunden: Lebensdauer.vorgabe.sekunden, ablauf: .markieren))
    }

    func testAblaufKommtInDerWirksamenLebensdauerAn() {
        let o = Meldungsoptionen(text: "x", lebensdauer: Kurzbefehlswerte.lebensdauer(
            minuten: 2, behalten: false, ablauf: .markieren))
        XCTAssertEqual(o.wirksameLebensdauer, Lebensdauer(sekunden: 120, ablauf: .markieren))
    }

    // MARK: - Klang

    func testKlangOhneAngabeIstStumm() throws {
        XCTAssertEqual(try Kurzbefehlswerte.klangwahl(name: nil, vorlesen: false, wiederholen: false), Klangwahl())
        XCTAssertEqual(try Kurzbefehlswerte.klangwahl(name: "  ", vorlesen: false, wiederholen: false).art, .keiner)
    }

    func testKlangMitNamenUndWiederholen() throws {
        let k = try Kurzbefehlswerte.klangwahl(name: " alarm ", vorlesen: false, wiederholen: true)
        XCTAssertEqual(k, Klangwahl(art: .uhr, name: "alarm", wiederholen: true))
        let klaenge = k.klaenge(nachrichtentext: "x")
        XCTAssertFalse(klaenge.isEmpty)
        XCTAssertTrue(klaenge.allSatisfy(\.wiederholen))
    }

    func testVorlesenUndKlangSchliessenSichAus() throws {
        XCTAssertThrowsError(try Kurzbefehlswerte.klangwahl(name: "alarm", vorlesen: true, wiederholen: false)) {
            XCTAssertEqual($0 as? Kurzbefehlswerte.Fehler, .klangUndVorlesen)
        }
        XCTAssertEqual(try Kurzbefehlswerte.klangwahl(name: nil, vorlesen: true, wiederholen: false).art, .vorlesen)
    }

    // MARK: - Nachricht

    /// Die Vorgaben des Kurzbefehls sind die der App: zwei Durchlaeufe, ersetzen.
    func testNachrichtVorgabenSindDieDerApp() {
        let o = Nachrichtwahl().optionen
        XCTAssertEqual(o.wiederholungen, 2)
        XCTAssertFalse(o.einreihen)
    }

    func testEinreihenIstDasGegenteilVonErsetzen() {
        XCTAssertTrue(Nachrichtwahl(ersetzen: false).optionen.einreihen)
    }

    func testDurchlaeufeWerdenGeklemmt() {
        XCTAssertEqual(Nachrichtwahl(durchlaeufe: 99).optionen.wiederholungen, Nachrichtwahl.hoechstdurchlaeufe)
        XCTAssertEqual(Nachrichtwahl(durchlaeufe: 0).optionen.wiederholungen, 1)
    }

    // MARK: - Icon

    private func sammlung(_ dateiname: String, kante: Int = 8) throws -> Iconsammlung {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]).write(to: ordner.appendingPathComponent(dateiname))
        return Iconsammlung(ordner: ordner, kante: kante)
    }

    func testIconOhneNummerIstKeines() throws {
        XCTAssertNil(try Kurzbefehlswerte.icon(nummer: nil, bestaende: []))
        XCTAssertNil(try Kurzbefehlswerte.icon(nummer: "  ", bestaende: []))
    }

    func testIconWirdUeberBeideBestaendeGefunden() throws {
        let b = [try sammlung("1673.gif"), try sammlung("haus-16.gif", kante: 16)]
        XCTAssertEqual(try Kurzbefehlswerte.icon(nummer: " 1673 ", bestaende: b)?.kante, 8)
        XCTAssertEqual(try Kurzbefehlswerte.icon(nummer: "haus-16", bestaende: b)?.kante, 16)
    }

    func testUnbekanntesIconIstEinFehler() throws {
        let b = [try sammlung("1673.gif")]
        XCTAssertThrowsError(try Kurzbefehlswerte.icon(nummer: "4711", bestaende: b)) {
            XCTAssertEqual($0 as? Kurzbefehlswerte.Fehler, .iconUnbekannt("4711"))
        }
    }

    // MARK: - Hinweis im Ergebnisdialog

    /// Eine Uhr mit acht Zeilen bekommt die 8×8-Fassung eines gewaehlten
    /// 16×16; der Dialog nennt sie. Die Uhr mit 16 Zeilen taucht nicht auf.
    func testHinweisNenntNurUhrenMitKleinerFassung() throws {
        let achter = try sammlung("haus.gif")
        let sechzehner = Icon(nummer: "haus-16", name: "haus-16", kategorie: "",
                              datei: URL(fileURLWithPath: "/tmp/haus-16.gif"), kante: 16)
        let kleineUhr = Uhr(name: "Kueche", host: "", panelbreite: 32, panelhoehe: 8, modell: .tc001)
        let grosseUhr = Uhr(name: "Flur", host: "", modell: .tc002)

        let hinweise = Iconbestaende.hinweise(gewaehlt: sechzehner, fuer: [kleineUhr, grosseUhr],
                                              bestaende: { [achter] })
        XCTAssertEqual(hinweise, [Iconbestaende.hinweis(
            gewaehlt: sechzehner, tatsaechlich: try XCTUnwrap(achter.alle().first), uhr: "Kueche")].compactMap { $0 })
        XCTAssertEqual(hinweise.count, 1)
    }

    func testKeinHinweisOhneKleinereFassung() throws {
        let leer = try sammlung("anderes.gif")
        let sechzehner = Icon(nummer: "haus-16", name: "haus-16", kategorie: "",
                              datei: URL(fileURLWithPath: "/tmp/haus-16.gif"), kante: 16)
        let kleineUhr = Uhr(name: "Kueche", host: "", panelbreite: 32, panelhoehe: 8, modell: .tc001)
        XCTAssertTrue(Iconbestaende.hinweise(gewaehlt: sechzehner, fuer: [kleineUhr], bestaende: { [leer] }).isEmpty)
    }

    // MARK: - Helligkeit

    func testHelligkeitBrauchtEtwas() {
        XCTAssertThrowsError(try Helligkeitswunsch().pruefen()) {
            XCTAssertEqual($0 as? Helligkeitswunsch.Fehler, .nichtsAngegeben)
        }
    }

    func testAutomatikUndFesterWertSchliessenSichAus() {
        XCTAssertThrowsError(try Helligkeitswunsch(prozent: 50, automatisch: true).pruefen()) {
            XCTAssertEqual($0 as? Helligkeitswunsch.Fehler, .automatikUndWert)
        }
        XCTAssertNoThrow(try Helligkeitswunsch(prozent: 50, automatisch: false).pruefen())
        XCTAssertNoThrow(try Helligkeitswunsch(automatisch: true).pruefen())
        XCTAssertNoThrow(try Helligkeitswunsch(prozent: 0).pruefen())
    }

    // MARK: - Moodlight

    func testMoodlightOhneAngabeLeuchtetWeiss() throws {
        let l = try Kurzbefehlswerte.moodlight(farbe: nil, kelvin: nil, prozent: nil)
        XCTAssertEqual(l, Moodlight(farbe: "#FFFFFF"))
    }

    func testMoodlightHelligkeitKommtInProzentAn() throws {
        let l = try Kurzbefehlswerte.moodlight(farbe: "#FF0000", kelvin: nil, prozent: 50)
        XCTAssertEqual(l.helligkeit, 128)
        XCTAssertEqual(l.farbe, "#FF0000")
    }

    func testMoodlightNurHelligkeitLaesstDieFarbeStehen() throws {
        let l = try Kurzbefehlswerte.moodlight(farbe: nil, kelvin: nil, prozent: 100)
        XCTAssertNil(l.farbe, "nur die Helligkeit aendert die Farbe der Uhr nicht")
        XCTAssertEqual(l.helligkeit, 255)
    }

    func testMoodlightFarbeUndKelvinSchliessenSichAus() {
        XCTAssertThrowsError(try Kurzbefehlswerte.moodlight(farbe: "#FF0000", kelvin: 2700, prozent: nil)) {
            XCTAssertEqual($0 as? SteuerungsFehler, .farbeUndKelvin)
        }
    }

    func testMoodlightKelvinWirdGeprueft() {
        XCTAssertThrowsError(try Kurzbefehlswerte.moodlight(farbe: nil, kelvin: 500, prozent: nil))
        XCTAssertNoThrow(try Kurzbefehlswerte.moodlight(farbe: nil, kelvin: 2700, prozent: nil))
    }
}
