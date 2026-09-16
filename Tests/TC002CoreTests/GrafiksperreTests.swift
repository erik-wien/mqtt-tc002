import XCTest
@testable import TC002Core

/// **Was zu hoch für die Anzeige ist, gehört gar nicht erst zur Wahl
/// gestellt.**
///
/// Eine TC001 unter AWTRIX NG hat acht Zeilen. Ein 16 × 16-Icon ist dort nicht
/// bloß zu groß — ein GIF, dessen erstes Bild höher ist als die Leinwand,
/// spielt **überhaupt nicht** (§8 der NG-Referenz), ohne Meldung. Bis hierher
/// fiel das erst beim Senden auf (`NGFehler.iconZuHoch`), und eine 16 × 52er
/// Anzeige fiel am Telefon gar nicht auf: Die Fußnote sagte, NG nehme sie
/// nicht, der Knopf schickte sie trotzdem.
///
/// Die Auskunft liegt im Kern, damit Mac, iPad und Telefon dieselbe geben.
final class GrafiksperreTests: XCTestCase {
    func testDieWerksfirmwareNimmtBeideHoehen() {
        XCTAssertNil(Geraetetyp.tc002.grafikSperre(hoehe: 8))
        XCTAssertNil(Geraetetyp.tc002.grafikSperre(hoehe: 16))
    }

    func testNGNimmtNurAchtZeilen() {
        XCTAssertNil(Geraetetyp.awtrixNG.grafikSperre(hoehe: 8))
        XCTAssertNotNil(Geraetetyp.awtrixNG.grafikSperre(hoehe: 16))
    }

    /// Der Grund ist ein Satz für die Oberfläche, kein Merkzettel: Er muss
    /// dastehen und etwas sagen.
    func testDerGrundIstEinSatz() throws {
        let grund = try XCTUnwrap(Geraetetyp.awtrixNG.grafikSperre(hoehe: 16))
        XCTAssertFalse(grund.isEmpty)
        XCTAssertTrue(grund.contains("acht"), "Der Grund nennt nicht, woran es liegt: \(grund)")
    }

    /// **Eine Tatsache, nicht zwei.** `iconKanten` sagt seit je, welche
    /// Icongrößen eine Gattung hergibt. Stünde daneben eine zweite Liste für
    /// die Höhe, liefen die beiden früher oder später auseinander — und die
    /// abweichende wäre die falsche (`Geraetetyp.swift` hält fest, dass das in
    /// diesem Projekt schon dreimal vorgekommen ist). Die Kanten leiten sich
    /// deshalb aus derselben Höhe ab, die auch die Sperre kennt.
    func testDieIconkantenFolgenDerselbenAuskunft() {
        for gattung in [Geraetetyp.tc002, .awtrixNG] {
            XCTAssertEqual(gattung.iconKanten,
                           [8, 16].filter { gattung.grafikSperre(hoehe: $0) == nil },
                           "\(gattung): Iconkanten und Grafiksperre sagen Verschiedenes.")
        }
    }

    /// Und die bekannten Werte stehen weiter da — die Ableitung darf nichts
    /// verschoben haben.
    func testDieBekanntenKantenBleiben() {
        XCTAssertEqual(Geraetetyp.tc002.iconKanten, [8, 16])
        XCTAssertEqual(Geraetetyp.awtrixNG.iconKanten, [8])
    }

    /// Die ganze Anzeige (16 × 52) ist für NG dieselbe Frage wie ein 16er
    /// Icon: zu hoch. `nimmtGemaltes` beantwortet sie seit je für das Malen —
    /// beide müssen dasselbe sagen.
    func testDieGanzeAnzeigeUndDasGemalteSagenDasselbe() {
        for gattung in [Geraetetyp.tc002, .awtrixNG] {
            let passt = gattung.grafikSperre(hoehe: Pixelfeld.hoeheStandard) == nil
            XCTAssertEqual(passt, gattung.nimmtGemaltes,
                           "\(gattung): „nimmt Gemaltes“ und die Sperre für 16 Zeilen widersprechen sich.")
        }
    }
}
