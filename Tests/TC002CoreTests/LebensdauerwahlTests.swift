import XCTest
@testable import TC002Core

final class LebensdauerwahlTests: XCTestCase {
    func testDieVorgabeIstDreissigMinutenEntfernen() {
        let w = Lebensdauerwahl(nil)
        XCTAssertEqual(w, Lebensdauerwahl())
        XCTAssertFalse(w.behalten)
        XCTAssertEqual(w.lebensdauer, Lebensdauer.vorgabe)
    }

    func testBehaltenIstNullSekundenUndMerktDenRest() {
        var w = Lebensdauerwahl(zahl: 2, einheit: .stunden, ablauf: .markieren)
        w.behalten = true
        XCTAssertEqual(w.lebensdauer, Lebensdauer(sekunden: 0, ablauf: .markieren))
        let zurueck = Lebensdauerwahl(w.lebensdauer)
        XCTAssertTrue(zurueck.behalten)
        XCTAssertEqual(zurueck.ablauf, .markieren)
        XCTAssertTrue(Lebensdauerwahl(.aus).behalten)
    }

    func testStundenUndMinutenRechnenHinUndZurueck() {
        XCTAssertEqual(Lebensdauerwahl(zahl: 3, einheit: .stunden).lebensdauer.sekunden, 10800)
        XCTAssertEqual(Lebensdauerwahl(zahl: 45).lebensdauer.sekunden, 2700)
        let h = Lebensdauerwahl(Lebensdauer(sekunden: 7200))
        XCTAssertEqual(h.einheit, .stunden)
        XCTAssertEqual(h.zahl, 2)
        let m = Lebensdauerwahl(Lebensdauer(sekunden: 5400, ablauf: .markieren))
        XCTAssertEqual(m.einheit, .minuten)
        XCTAssertEqual(m.zahl, 90)
        XCTAssertEqual(m.ablauf, .markieren)
    }

    func testEinZuKurzerOderZuLangerWertWirdBegrenzt() {
        XCTAssertEqual(Lebensdauerwahl(Lebensdauer(sekunden: 5)).lebensdauer.sekunden, 60)
        XCTAssertEqual(Lebensdauerwahl(zahl: 0).lebensdauer.sekunden, 60)
        XCTAssertEqual(Lebensdauerwahl(zahl: 5000).lebensdauer.sekunden, 999 * 60)
    }

    func testDieNachrichtHatDieVorgabenDerApp() {
        let o = Nachrichtwahl().optionen
        XCTAssertFalse(o.halten)
        XCTAssertTrue(o.aufwecken)
        XCTAssertFalse(o.einreihen)
        XCTAssertEqual(o.wiederholungen, 2)
        XCTAssertNil(o.name)
    }

    func testErsetzenAusSchaltetDasEinreihenAn() {
        let o = Nachrichtwahl(halten: true, aufwecken: false, ersetzen: false, durchlaeufe: 0).optionen
        XCTAssertTrue(o.einreihen)
        XCTAssertTrue(o.halten)
        XCTAssertFalse(o.aufwecken)
        XCTAssertEqual(o.wiederholungen, 1)
    }

    /// Der Platz merkt die Lebensdauer als Regler (Entscheidung 5); eine Datei
    /// ohne die Felder liefert die Vorgabe.
    func testDerPlatzMerktDieLebensdauerUndAlteDateienBleibenLesbar() throws {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let g = Slotgedaechtnis(ordner: ordner)
        let uhr = UUID()
        var o = Meldungsoptionen(text: "a")
        o.lebensdauer = Lebensdauerwahl(behalten: false, zahl: 2, einheit: .stunden, ablauf: .markieren).lebensdauer
        XCTAssertTrue(g.merken(o, icon: nil, iconKante: 8, fuer: uhr, platz: 1))
        let w = Lebensdauerwahl(g.gemerkt(fuer: uhr, platz: 1)?.optionen?.lebensdauer)
        XCTAssertEqual(w, Lebensdauerwahl(zahl: 2, einheit: .stunden, ablauf: .markieren))

        o.lebensdauer = Lebensdauerwahl(behalten: true).lebensdauer
        XCTAssertTrue(g.merken(o, icon: nil, iconKante: 8, fuer: uhr, platz: 2))
        XCTAssertTrue(Lebensdauerwahl(g.gemerkt(fuer: uhr, platz: 2)?.optionen?.lebensdauer).behalten)

        let alt = ##"{"platz":1,"text":"a","weg":"pixel","schrift":"Silkscreen","groesse":8,"fett":false,"grossbuchstaben":false,"rand":1,"abstand":1,"waagrecht":"links","senkrecht":"oben","farbe":"#00FF66","tempo":"mittel","iconLaeuftMit":false,"pruefsumme":"x"}"##
        let stand = try JSONDecoder().decode(Slotstand.self, from: Data(alt.utf8))
        XCTAssertEqual(Lebensdauerwahl(stand.optionen?.lebensdauer), Lebensdauerwahl())
    }
}
