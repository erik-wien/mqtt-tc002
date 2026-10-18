import XCTest
@testable import TC002Core

final class NachrichtdauerTests: XCTestCase {
    private func json(_ w: Nachrichtwahl) throws -> String {
        let o = Meldungsoptionen(text: "hallo", weg: .text, dauer: w.dauerSekunden)
        let rahmen = Frame(dauer: w.dauerSekunden, herkunft: Meldungsherkunft(optionen: o))
        return try NGNutzlast.benachrichtigung(rahmen, w.optionen)
    }

    func testBisZurueckgezogenSendetNurHold() throws {
        let j = try json(Nachrichtwahl(steht: Nachrichtdauerwahl(art: .bisZurueckgezogen)))
        XCTAssertTrue(j.hasSuffix(#","hold":true,"stack":false,"wakeup":true}"#), j)
        XCTAssertFalse(j.contains("durationMs"), j)
        XCTAssertFalse(j.contains("repeat"), j)
    }

    func testSekundenSendenNurDurationMs() throws {
        let j = try json(Nachrichtwahl(steht: Nachrichtdauerwahl(art: .sekunden, sekunden: 7)))
        XCTAssertTrue(j.contains(#""durationMs":7000"#), j)
        XCTAssertTrue(j.hasSuffix(#","stack":false,"wakeup":true}"#), j)
        XCTAssertFalse(j.contains("hold"), j)
        XCTAssertFalse(j.contains("repeat"), j)
    }

    func testDurchlaeufeSendenNurRepeat() throws {
        let j = try json(Nachrichtwahl(steht: Nachrichtdauerwahl(art: .durchlaeufe, durchlaeufe: 3)))
        XCTAssertTrue(j.hasSuffix(#","stack":false,"wakeup":true,"repeat":3}"#), j)
        XCTAssertFalse(j.contains("hold"), j)
        XCTAssertFalse(j.contains("durationMs"), j)
    }

    func testZahlenWerdenGeklemmt() {
        XCTAssertEqual(Nachrichtdauer.sekunden(0).dauerSekunden, 1)
        XCTAssertEqual(Nachrichtdauer.sekunden(999_999).dauerSekunden, 86_400)
        XCTAssertEqual(Nachrichtdauer.durchlaeufe(50).wiederholungen, 9)
        XCTAssertNil(Nachrichtdauer.durchlaeufe(2).dauerSekunden)
        XCTAssertNil(Nachrichtdauer.sekunden(2).wiederholungen)
    }

    func testDieVorgabeIstBisZurueckgezogen() {
        XCTAssertEqual(Nachrichtdauerwahl().dauer, .bisZurueckgezogen)
        XCTAssertEqual(Kurzbefehlswerte.nachrichtdauer(.bisZurueckgezogen, anzahl: nil).dauer, .bisZurueckgezogen)
        XCTAssertFalse(Nachrichtwahl().klang.wiederholen, "Klang: 1× ist die Vorgabe")
    }

    func testKurzbefehlAnzahl() {
        XCTAssertEqual(Kurzbefehlswerte.nachrichtdauer(.sekunden, anzahl: 30).dauer, .sekunden(30))
        XCTAssertEqual(Kurzbefehlswerte.nachrichtdauer(.sekunden, anzahl: nil).dauer, .sekunden(10))
        XCTAssertEqual(Kurzbefehlswerte.nachrichtdauer(.durchlaeufe, anzahl: nil).dauer, .durchlaeufe(2))
        XCTAssertEqual(Kurzbefehlswerte.nachrichtdauer(.durchlaeufe, anzahl: 99).dauer, .durchlaeufe(9))
        XCTAssertEqual(Kurzbefehlswerte.nachrichtdauer(.bisZurueckgezogen, anzahl: 5).dauer, .bisZurueckgezogen)
    }

    // MARK: Übernahme der alten Regler

    func testUebernahmeGehaltenGewinnt() {
        XCTAssertEqual(Nachrichtdauerwahl.uebernommen(halten: true, dauerText: "30", durchlaeufe: 4).art, .bisZurueckgezogen)
    }

    func testUebernahmeDauerWirdSekunden() {
        let w = Nachrichtdauerwahl.uebernommen(halten: false, dauerText: " 12 ", durchlaeufe: 4)
        XCTAssertEqual(w.dauer, .sekunden(12))
        XCTAssertEqual(w.durchlaeufe, 4)
    }

    func testUebernahmeOhneDauerWirdDurchlaeufeMitAltemWert() {
        XCTAssertEqual(Nachrichtdauerwahl.uebernommen(halten: false, dauerText: "", durchlaeufe: 5).dauer, .durchlaeufe(5))
        XCTAssertEqual(Nachrichtdauerwahl.uebernommen(halten: false, dauerText: "0", durchlaeufe: nil).dauer, .durchlaeufe(2))
    }

    private func ablage() -> UserDefaults {
        let n = "nachrichtdauer-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: n)!
        d.removePersistentDomain(forName: n)
        return d
    }

    func testUebernehmenSchreibtEinmalUndLaesstSpaeteresStehen() {
        let d = ablage()
        d.set(true, forKey: "senden.nachricht.halten")
        d.set("20", forKey: "senden.dauer")
        d.set(3, forKey: Nachrichtdauerwahl.durchlaeufeSchluessel)
        Nachrichtdauerwahl.uebernehmen(in: d)
        XCTAssertEqual(d.string(forKey: Nachrichtdauerwahl.schluessel), "bisZurueckgezogen")
        XCTAssertEqual(d.integer(forKey: Nachrichtdauerwahl.sekundenSchluessel), 20)
        XCTAssertEqual(d.integer(forKey: Nachrichtdauerwahl.durchlaeufeSchluessel), 3)
        XCTAssertNil(d.object(forKey: "senden.nachricht.halten"))
        XCTAssertEqual(d.string(forKey: "senden.dauer"), "20", "die Anzeigedauer bleibt")

        d.set("sekunden", forKey: Nachrichtdauerwahl.schluessel)
        Nachrichtdauerwahl.uebernehmen(in: d)
        XCTAssertEqual(d.string(forKey: Nachrichtdauerwahl.schluessel), "sekunden")
    }

    func testBenutzteAppOhneAlteReglerBehaeltDasAlteVerhalten() {
        let d = ablage()
        d.set("Hallo", forKey: "senden.text")
        Nachrichtdauerwahl.uebernehmen(in: d)
        XCTAssertEqual(d.string(forKey: Nachrichtdauerwahl.schluessel), "durchlaeufe")
    }

    func testFrischeInstallationBekommtDieVorgabe() {
        let d = ablage()
        Nachrichtdauerwahl.uebernehmen(in: d)
        XCTAssertNil(d.object(forKey: Nachrichtdauerwahl.schluessel))
    }

    // MARK: Durchläufe nur bei laufendem Text

    func testDurchlaeufeNurWennEinTextDurchlaeuft() {
        let kurz = Meldungsoptionen(text: "Hi")
        let lang = Meldungsoptionen(text: String(repeating: "Langer Text ", count: 8))
        XCTAssertFalse(Meldungsbau.laeuftDurch(kurz, ziele: [(.vorgabe, nil)]))
        XCTAssertTrue(Meldungsbau.laeuftDurch(lang, ziele: [(.vorgabe, nil)]))
        XCTAssertFalse(Meldungsbau.laeuftDurch(lang, ziele: []))
        XCTAssertTrue(Nachrichtdauerwahl(art: .durchlaeufe).faelltAufAnzeigedauer(textLaeuft: false))
        XCTAssertFalse(Nachrichtdauerwahl(art: .durchlaeufe).faelltAufAnzeigedauer(textLaeuft: true))
        XCTAssertFalse(Nachrichtdauerwahl(art: .sekunden).faelltAufAnzeigedauer(textLaeuft: false))
    }
}
