import XCTest
@testable import TC002Core

/// Aus der Groesse folgt alles Weitere. Diese Tests halten fest, dass es
/// wirklich abgeleitet bleibt und nicht doch wieder als Sonderfall in der
/// Oberflaeche steht.
final class LeinwandgroesseTests: XCTestCase {

    func testDieDreiGroessen() {
        XCTAssertEqual(Leinwandgroesse.allCases.map { [$0.breite, $0.hoehe] },
                       [[8, 8], [16, 16], [52, 16]])
    }

    /// Ein 8×8 ist fuer sich keine Anzeige — die Sendezeile gibt es nur bei
    /// 16×52.
    func testNurDieGanzeAnzeigeLaesstSichSenden() {
        XCTAssertFalse(Leinwandgroesse.icon8.sendbar)
        XCTAssertFalse(Leinwandgroesse.icon16.sendbar)
        XCTAssertTrue(Leinwandgroesse.anzeige.sendbar)
    }

    /// Eine Nummer gibt es beim 8×8 (LaMetric) **und** beim 16×52 (Ulanzi
    /// vergibt sie fuer seine „Pixel Art 16×52"), nicht aber beim 16×16 —
    /// diese Groesse ist nicht kanonisch, sie stammt von uns.
    ///
    /// Mutation: `mitNummer` zurueck auf `breite == 8 && hoehe == 8` — dann
    /// gibt es fuer eine Anzeige nirgends ein Nummernfeld.
    func testNummerGibtEsBeimAchterUndBeiDerAnzeige() {
        XCTAssertTrue(Leinwandgroesse.icon8.mitNummer)
        XCTAssertFalse(Leinwandgroesse.icon16.mitNummer)
        XCTAssertTrue(Leinwandgroesse.anzeige.mitNummer)
    }

    /// **Eine Nummer haben und nach ihr heissen ist zweierlei.** Nur das 8×8
    /// liegt unter seiner Nummer; die Anzeige heisst weiter nach ihrem Namen,
    /// sonst waere jede bestehende Bildersammlung unlesbar.
    ///
    /// Mutation: `nummerIstDateiname` gleich `mitNummer` setzen — dann sucht
    /// der Bestand ein 16×52 unter seiner Nummer, und ohne Nummer laesst es
    /// sich gar nicht mehr sichern.
    func testNurDasAchtmalAchtHeisstNachSeinerNummer() {
        XCTAssertTrue(Leinwandgroesse.icon8.nummerIstDateiname)
        XCTAssertFalse(Leinwandgroesse.icon16.nummerIstDateiname)
        XCTAssertFalse(Leinwandgroesse.anzeige.nummerIstDateiname)

        XCTAssertEqual(Editorbestand.schluessel(groesse: .anzeige, nummer: "318", name: "Mario"),
                       "Mario", "die Anzeige liegt wieder unter ihrer Nummer")
        XCTAssertEqual(Editorbestand.schluessel(groesse: .icon8, nummer: "4711", name: "Wetter"),
                       "4711")
    }

    func testEineLeinwandFindetIhreGroesse() {
        XCTAssertEqual(Leinwandgroesse.fuer(Leinwand(breite: 8, hoehe: 8)), .icon8)
        XCTAssertEqual(Leinwandgroesse.fuer(Leinwand(breite: 16, hoehe: 16)), .icon16)
        XCTAssertEqual(Leinwandgroesse.fuer(Leinwand(breite: 52, hoehe: 16)), .anzeige)
        // 16×52 statt 52×16: keine der drei. Lieber nichts als das Falsche.
        XCTAssertNil(Leinwandgroesse.fuer(breite: 16, hoehe: 52))
        XCTAssertNil(Leinwandgroesse.fuer(breite: 32, hoehe: 32))
    }

    /// Die leere Leinwand hat die Masse ihrer Groesse — sonst legte ein
    /// Groessenwechsel die falsche an.
    func testDieLeereLeinwandPasstZurGroesse() {
        for groesse in Leinwandgroesse.allCases {
            let leer = groesse.leereLeinwand
            XCTAssertEqual(Leinwandgroesse.fuer(leer), groesse)
            XCTAssertTrue(leer.istLeer)
        }
    }

    /// **C2.** Eingesetzt wird nur, was **kleiner oder gleich gross** ist.
    /// Der umgekehrte Weg ist ausdruecklich nicht gemeint: Verkleinern
    /// zerstoert, und genau das war der Mangel, den C1 und C2 beheben.
    func testNurKleineresLaesstSichEinsetzen() {
        XCTAssertEqual(Leinwandgroesse.icon8.aufnehmbar, [],
                       "8×8 ist die kleinste — dort gibt es nichts einzusetzen")
        XCTAssertEqual(Leinwandgroesse.icon16.aufnehmbar, [.icon8])
        XCTAssertEqual(Leinwandgroesse.anzeige.aufnehmbar, [.icon8, .icon16])

        XCTAssertFalse(Leinwandgroesse.icon8.iconEinfuegbar,
                       "bei 8×8 darf „Icon einfügen“ nicht dastehen")
        XCTAssertTrue(Leinwandgroesse.icon16.iconEinfuegbar,
                      "bei 16×16 fehlt „Icon einfügen“ — dort gehört das Verdoppeln hin")
        XCTAssertTrue(Leinwandgroesse.anzeige.iconEinfuegbar)

        XCTAssertNil(Leinwandgroesse.anzeige.einsatz(in: .icon8), "verkleinern kommt nicht vor")
        XCTAssertNil(Leinwandgroesse.icon16.einsatz(in: .icon8), "verkleinern kommt nicht vor")
        XCTAssertNil(Leinwandgroesse.icon8.einsatz(in: .icon8), "in sich selbst auch nicht")
    }

    /// Hochgerechnet wird **nur in ein Icon**. In die Anzeige geht ein Icon in
    /// seiner Groesse, an genau der Stelle, an der es auch unter „Senden"
    /// laege — dieselbe Rechnung wie `Meldungsbau.iconY`, und nicht daneben
    /// noch einmal hingeschrieben.
    func testDerEinsatzVerdoppeltNurInEinIconUndTrifftSonstDieSendestelle() {
        guard let inIcon = Leinwandgroesse.icon8.einsatz(in: .icon16) else {
            return XCTFail("8×8 lässt sich nicht in ein 16×16 setzen")
        }
        XCTAssertEqual(inIcon.faktor, 2, "8×8 wird in einem 16×16 nicht verdoppelt")
        XCTAssertEqual([inIcon.x, inIcon.y], [0, 0], "verdoppelt füllt es die ganze Fläche")

        for quelle in [Leinwandgroesse.icon8, .icon16] {
            guard let inAnzeige = quelle.einsatz(in: .anzeige) else {
                return XCTFail("\(quelle.beschriftung) lässt sich nicht in die Anzeige setzen")
            }
            XCTAssertEqual(inAnzeige.faktor, 1,
                           "in der Anzeige behält ein Icon seine Größe — sonst frisst es die Breite")
            XCTAssertEqual(inAnzeige.x, 0)
            XCTAssertEqual(inAnzeige.y, Meldungsbau.iconY(kante: quelle.hoehe),
                           "das Icon sitzt nicht dort, wo es beim Senden läge")
        }
    }

    /// Die drei Beschriftungen werden ueber eine Variable nachgeschlagen und
    /// stehen darum von Hand in `scripts/texte-sammeln.py`. Aendert sie
    /// jemand hier, faellt die Uebersetzung still aus — dieser Test nennt den
    /// Ort, an dem es mitzuziehen ist.
    func testDieBeschriftungenStehenAuchImSammler() throws {
        let skript = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/texte-sammeln.py")
        let inhalt = try String(contentsOf: skript, encoding: .utf8)
        for groesse in Leinwandgroesse.allCases {
            XCTAssertTrue(inhalt.contains("\"\(groesse.beschriftung)\""),
                          "„\(groesse.beschriftung)“ fehlt in DYNAMISCH — die Übersetzung fällt still aus")
        }
    }
}
