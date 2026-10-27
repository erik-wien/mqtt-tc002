import XCTest
@testable import TC002Core

final class SendeauftragTests: XCTestCase {
    private var namen: [String] = []

    private func ablage() -> UserDefaults {
        let name = "SendeauftragTests-\(UUID().uuidString)"
        namen.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        namen.forEach { UserDefaults().removePersistentDomain(forName: $0) }
        namen = []
        super.tearDown()
    }

    private func auftrag(nachricht: Nachrichtwahl? = nil) -> Sendeauftrag {
        var dar = Darstellungswahl()
        dar.hintergrundfarbe = "#112233"
        dar.effekt = "Fade"
        let o = Meldungsoptionen(
            text: "Telco läuft", weg: .text, schrift: "Menlo", groesse: 12, fett: true, farbe: "#FF0000",
            grossbuchstaben: true, waagrecht: .mittig, senkrecht: .oben, rand: 2, abstand: 2, tempo: .schnell,
            dauer: 600, lebensdauer: Lebensdauer(sekunden: 7200, ablauf: .markieren), darstellung: dar,
            iconmodus: .einmal, zusatzicons: [Zusatzicon(nummer: "55", x: 3, y: 4)])
        return Sendeauftrag(optionen: o, iconNummer: "1234", iconKante: 16, platz: 3, nachricht: nachricht,
                            zielIDs: [UUID(), UUID()])
    }

    func testRundreiseAnzeige() {
        let d = ablage()
        let a = auftrag()
        a.schreiben(in: d)
        XCTAssertEqual(Sendeauftrag.aus(d, zielIDs: a.zielIDs), a)
    }

    func testRundreiseNachricht() {
        let d = ablage()
        let n = Nachrichtwahl(steht: Nachrichtdauerwahl(art: .sekunden, sekunden: 25),
                              aufwecken: false, ersetzen: false,
                              klang: Klangwahl(art: .uhr, name: "Ping"))
        let a = auftrag(nachricht: n)
        a.schreiben(in: d)
        XCTAssertEqual(Sendeauftrag.aus(d, zielIDs: a.zielIDs), a)
    }

    func testAnzeigeLaesstNachrichtschluesselStehen() {
        let d = ablage()
        d.set(42, forKey: Nachrichtdauerwahl.sekundenSchluessel)
        auftrag().schreiben(in: d)
        XCTAssertEqual(d.integer(forKey: Nachrichtdauerwahl.sekundenSchluessel), 42)
        XCTAssertEqual(d.string(forKey: "senden.art"), "anzeige")
    }

    func testLeereAblageGibtVorgaben() {
        let a = Sendeauftrag.aus(ablage(), zielIDs: [])
        XCTAssertEqual(a.optionen, Meldungsoptionen(text: "Hallo"))
        XCTAssertEqual(a.optionen.farbe, "#00FF66")
        XCTAssertEqual(a.platz, 1)
        XCTAssertNil(a.iconNummer)
        XCTAssertEqual(a.iconKante, 8)
        XCTAssertNil(a.nachricht)
    }

    func testCodableToleriertFehlendeSchluessel() throws {
        let a = try JSONDecoder().decode(Sendeauftrag.self, from: Data(#"{"optionen":{"text":"x"}}"#.utf8))
        XCTAssertEqual(a.optionen, Meldungsoptionen(text: "x"))
        XCTAssertEqual(a.iconKante, 8)
        XCTAssertEqual(a.platz, 1)
        XCTAssertEqual(a.zielIDs, [])
    }

    func testCodableRundreise() throws {
        let a = auftrag(nachricht: Nachrichtwahl())
        let b = try JSONDecoder().decode(Sendeauftrag.self, from: JSONEncoder().encode(a))
        XCTAssertEqual(a, b)
    }
}
