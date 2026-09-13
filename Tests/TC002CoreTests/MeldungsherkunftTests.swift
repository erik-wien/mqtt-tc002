import Foundation
import XCTest
@testable import TC002Core

/// Dass jeder gebaute Rahmen seine Herkunft mitfuehrt — und was daran haengt.
///
/// Ohne sie kann eine AWTRIX NG mit einer Sendung nichts anfangen: Sie setzt
/// den Text selbst und braucht die Regler, nicht die Pixel. **Genau daran
/// erkennt `Anzeigen` auch den Gegenfall** — ein gemaltes Bild kommt nicht
/// durch `Meldungsbau.rahmen` und hat deshalb keine.
final class MeldungsherkunftTests: XCTestCase {

    /// Ein leerer Iconordner: Hier zaehlt die Buchfuehrung, nicht der Inhalt
    /// eines Icons.
    private func leereSammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    /// Der stehende Fall: Der Text passt, der Rahmen traegt Zeichenbefehle.
    func testEinStehenderRahmenTraegtSeineRegler() throws {
        var o = Meldungsoptionen(text: "hi")
        o.farbe = "#FF0000"
        let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        XCTAssertEqual(rahmen.herkunft?.optionen, o)
    }

    /// **Der laufende Fall ist der wichtigere.** Dort ist der Rahmen ein
    /// einziges GIF, aus dem sich nichts mehr herausloesen liesse — ohne die
    /// Herkunft waere eine lange Meldung auf einer AWTRIX gar nicht zu
    /// schicken.
    func testAuchEinLaufenderRahmenTraegtSeineRegler() throws {
        let o = Meldungsoptionen(text: "ein ziemlich langer Text, der bestimmt nicht mehr hineinpasst")
        let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        XCTAssertTrue(rahmen.draw.isEmpty, "dieser Fall muss der laufende sein")
        XCTAssertFalse(rahmen.bilder.isEmpty)
        XCTAssertEqual(rahmen.herkunft?.optionen.text, o.text)
    }

    /// Die Herkunft gehoert **nicht** zur Nutzlast. Stuende sie im JSON, waere
    /// jede Sendung an die Werksfirmware unnoetig groesser — und truege Felder,
    /// ueber die das Geraet stolpert.
    func testDieHerkunftStehtNichtInDerNutzlast() throws {
        let rahmen = try Meldungsbau.rahmen(Meldungsoptionen(text: "hi"), icon: nil,
                                            sammlung: leereSammlung())
        XCTAssertFalse(rahmen.alsJSON().contains("herkunft"))
        XCTAssertFalse(rahmen.alsJSON().contains("optionen"))
    }

    /// Ein von Hand gebauter Rahmen — gemalt, aus der Bildersammlung — hat
    /// keine. Das ist kein Versaeumnis, sondern die Auskunft.
    func testEinSelbstGebauterRahmenHatKeineHerkunft() {
        XCTAssertNil(Frame(draw: [DrawBefehl(x: 0, y: 0, breite: 1, hoehe: 1, farbe: "#FFFFFF")]).herkunft)
    }
}

/// Die Lesart von `Uhr.typ` — dieselbe Bauart wie `wirksameBetriebsart`.
final class UhrGattungTests: XCTestCase {

    /// **`nil` heisst TC002, nicht „unbekannt".** Jede Einrichtung, die vor
    /// dieser Fassung entstanden ist, ist eine.
    func testOhneEingetrageneArtGiltDieWerksfirmware() {
        XCTAssertEqual(Uhr(name: "a", host: "h").gattung, .tc002)
        XCTAssertEqual(Uhr(name: "a", host: "h", typ: .tc002).gattung, .tc002)
        XCTAssertEqual(Uhr(name: "a", host: "h", typ: .awtrixNG).gattung, .awtrixNG)
    }

    /// Die Masse haengen an der Gattung: 52×16 gegen 32×8 — ein anderes
    /// Seitenverhaeltnis, nicht bloss andere Zahlen. Und die Breite von NG
    /// kommt vom Geraet, sobald sie geholt wurde.
    func testDieAnzeigemasseHaengenAnDerGattung() {
        let alt = Uhr(name: "a", host: "h")
        XCTAssertEqual(alt.anzeigemass.breite, 52)
        XCTAssertEqual(alt.anzeigemass.hoehe, 16)

        let ng = Uhr(name: "b", host: "h", typ: .awtrixNG)
        XCTAssertEqual(ng.anzeigemass.breite, 32, "die dokumentierte Vorgabe, bis gefragt wurde")
        XCTAssertEqual(ng.anzeigemass.hoehe, 8, "bei NG fest und nicht einstellbar")

        let breit = Uhr(name: "c", host: "h", typ: .awtrixNG, panelbreite: 64)
        XCTAssertEqual(breit.anzeigemass.breite, 64)
        XCTAssertEqual(breit.anzeigemass.hoehe, 8)
    }

    /// Ein 16×16-Icon hat auf acht Zeilen keinen Platz. Das ist eine
    /// Eigenschaft des Geraets und kein Fehler, den man glattbuegelt.
    func testNurDieWerksfirmwareNimmtSechzehnerIcons() {
        XCTAssertEqual(Geraetetyp.tc002.iconKanten, [8, 16])
        XCTAssertEqual(Geraetetyp.awtrixNG.iconKanten, [8])
    }

    /// Die Gegenprobe zu `EinstellungenTests.testUhrBleibtLesbar`: Eine Zeile
    /// ohne `typ` ergibt **eine** Uhr mit `nil`, nicht null Uhren.
    func testEineAlteZeileOhneTypErgibtEineUhrUndKeineLeereListe() throws {
        let alt = #"[{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","name":"Küche","host":"10.0.0.1","praefix":"awtrix_a86b","mac":"aabbccdda86b"}]"#
        let uhren = try JSONDecoder().decode([Uhr].self, from: Data(alt.utf8))
        XCTAssertEqual(uhren.count, 1)
        XCTAssertNil(uhren[0].typ)
        XCTAssertEqual(uhren[0].gattung, .tc002)
    }

    /// Und der Weg zurueck: Solange `typ` `nil` ist, faellt der Schluessel beim
    /// Schreiben weg — eine aeltere Fassung liest die Datei weiterhin.
    func testOhneArtStehtDerSchluesselNichtInDerDatei() throws {
        let daten = try JSONEncoder().encode([Uhr(name: "a", host: "h")])
        XCTAssertFalse(String(data: daten, encoding: .utf8)!.contains("typ"))
    }
}
