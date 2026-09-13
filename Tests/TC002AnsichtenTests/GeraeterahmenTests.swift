import XCTest
import TC002Core
@testable import TC002Ansichten

/// Der Geraeterahmen ist eine Zeichnung, und eine Zeichnung sieht man sich an.
/// Was ein Blick aufs Bild aber **nicht** sieht, ist eine um zwei Prozent
/// falsche Feldbreite: Die Pixel stehen dann nicht mehr quadratisch im Feld
/// oder werden am Rand angeschnitten, und beides faellt erst auf, wenn jemand
/// die Vorschau mit dem Geraet vergleicht. Deshalb stehen die Masse hier in
/// Zusicherungen.
final class GeraeterahmenTests: XCTestCase {

    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Geraeteart und das Raster, das sie zeigt. `Geraetetyp` ist nicht
    /// `CaseIterable` — es ist ein Dateiformat im Kern, an dem hier nichts
    /// haengen soll —, deshalb die Liste von Hand. Dass sie vollstaendig
    /// bleibt, sichert das `switch` in `Geraetezeichnung.fuer(_:)`: Eine
    /// dritte Art laesst dort den Uebersetzer stehen.
    private static let arten: [(typ: Geraetetyp, spalten: Int, zeilen: Int)] = [
        (.tc002, Pixelfeld.breiteStandard, Pixelfeld.hoeheStandard),   // 52×16
        (.awtrixNG, 32, 8),                                            // docs/awtrix-ng-protokoll.md §1
    ]

    /// Der Kern der Sache: Der Rahmen skaliert seine **Zeichnung** an die
    /// Hoehe des Inhalts — den Inhalt selbst skaliert er nie. Ein Pixel ist
    /// darum so breit wie hoch, an jeder Kantenlaenge und bei jeder Geraeteart.
    func testFeldNimmtDenInhaltQuadratischUndUnverzerrtAuf() {
        for art in Self.arten {
            let z = Geraetezeichnung.fuer(art.typ)
            for kante in [4.0, 6, 8, 11, 14] {
                let inhaltBreite = Double(art.spalten) * kante
                let inhaltHoehe = Double(art.zeilen) * kante
                let m = z.masse(inhaltHoehe: inhaltHoehe)
                let wo = "\(art.typ) bei Kante \(kante)"

                // 1. Das Feld ist genau so hoch wie der Inhalt. Waere es
                //    niedriger, muesste der Inhalt gestaucht werden; waere es
                //    hoeher, saesse er nicht mehr im Feld.
                XCTAssertEqual(m.feldHoehe, inhaltHoehe, accuracy: 0.0001,
                               "Feldhoehe passt nicht zum Inhalt — \(wo)")

                // 2. Ein einziger Massstab fuer beide Achsen: nichts verzerrt.
                XCTAssertEqual(m.rahmenBreite / m.rahmenHoehe, z.breite / z.hoehe,
                               accuracy: 0.0001, "Rahmen verzerrt — \(wo)")
                XCTAssertEqual(m.feldBreite / m.feldHoehe, z.feld.breite / z.feld.hoehe,
                               accuracy: 0.0001, "Feld verzerrt — \(wo)")

                // 3. Das Feld ist nie schmaler als der Inhalt — sonst stuenden
                //    die aeussersten Pixelspalten ueber der Blende.
                XCTAssertGreaterThanOrEqual(m.feldBreite, inhaltBreite - 0.0001,
                                            "Inhalt ragt aus dem Feld — \(wo)")

                // 4. …und auch nicht nennenswert breiter: Was uebrig bleibt,
                //    muss unter **einer** Pixelbreite liegen, sonst sieht man
                //    links und rechts einen schwarzen Streifen im Feld.
                XCTAssertLessThan(m.feldBreite - inhaltBreite, kante,
                                  "schwarzer Rest im Feld breiter als ein Pixel — \(wo)")

                // 5. Der Inhalt sitzt oben buendig und waagrecht mittig.
                let ecke = z.inhaltEcke(inhaltBreite: inhaltBreite, inhaltHoehe: inhaltHoehe)
                XCTAssertEqual(ecke.y, m.feldY, accuracy: 0.0001, "Inhalt nicht oben buendig — \(wo)")
                XCTAssertEqual(ecke.x - m.feldX, m.feldX + m.feldBreite - (ecke.x + inhaltBreite),
                               accuracy: 0.0001, "Inhalt nicht zentriert — \(wo)")
            }
        }
    }

    /// Dieselbe Aussage von der anderen Seite: Das gezeichnete Feld muss das
    /// Seitenverhaeltnis des Rasters haben, das darin gezeigt wird. 52×16 ist
    /// 3,25, 32×8 ist 4,0 — ein Feld mit 3,3 geht gerade noch (Punkt 4 oben
    /// misst nach, wieviel „gerade noch" ist), ein Feld mit 4,0 unter der
    /// Werksfirmware waere ein grober Fehler.
    func testFeldhatDasSeitenverhaeltnisSeinesRasters() {
        for art in Self.arten {
            let z = Geraetezeichnung.fuer(art.typ)
            let rasterVerhaeltnis = Double(art.spalten) / Double(art.zeilen)
            let feldVerhaeltnis = z.feld.breite / z.feld.hoehe
            XCTAssertEqual(feldVerhaeltnis, rasterVerhaeltnis, accuracy: rasterVerhaeltnis * 0.03,
                           "\(art.typ): Feld \(feldVerhaeltnis) passt nicht zu \(art.spalten)×\(art.zeilen)")
        }
    }

    /// `nil` heisst `.tc002` — dieselbe Lesart wie bei `Uhr.typ`. Ohne diese
    /// Zusicherung koennte eine Uhr aus einer aelteren Einstellungsdatei
    /// stillschweigend die falsche Front bekommen.
    func testOhneAngabeGiltDieWerksfirmware() {
        XCTAssertEqual(Geraetezeichnung.fuer(nil), Geraetezeichnung.tc002)
        XCTAssertEqual(Geraetezeichnung.fuer(.tc002), Geraetezeichnung.tc002)
        XCTAssertEqual(Geraetezeichnung.fuer(.awtrixNG), Geraetezeichnung.awtrixNG)
        XCTAssertNotEqual(Geraetezeichnung.awtrixNG, Geraetezeichnung.tc002)
    }

    /// „Rundere Ecken und keine Tasten oben" — beides gemessen, nicht als
    /// Merkzettel im Kommentar.
    ///
    /// „Keine Tasten oben" heisst: Bei der AWTRIX-Front liegt **nichts** ueber
    /// der Oberkante des Gehaeuses. Bei der TC002 liegt sehr wohl etwas
    /// darueber (Drehknopf und Abdeckplatte) — und das steht hier mit, weil
    /// der Test sonst auch dann durchginge, wenn die TC002 ihren Knopf
    /// verloere.
    func testAwtrixIstRunderUndHatNichtsUeberDemGehaeuse() {
        let tc = Geraetezeichnung.tc002
        let ng = Geraetezeichnung.awtrixNG

        func hoechsterTeil(_ z: Geraetezeichnung) -> Double {
            z.teile.compactMap { teil -> Double? in
                if case let .flaeche(r, _, _) = teil { return r.y }
                return nil
            }.min() ?? z.gehaeuse.y
        }

        XCTAssertGreaterThanOrEqual(hoechsterTeil(ng), ng.gehaeuse.y,
                                    "die AWTRIX-Front hat etwas ueber dem Gehaeuse — Tasten oben?")
        XCTAssertLessThan(hoechsterTeil(tc), tc.gehaeuse.y,
                          "die TC002 hat ihren Drehknopf ueber dem Gehaeuse verloren")

        // Rundheit ist ein Verhaeltnis, keine Zahl: Radius 28 auf einem
        // niedrigeren Gehaeuse ist etwas anderes als Radius 28 auf einem hohen.
        XCTAssertGreaterThan(ng.gehaeuseRadius / ng.gehaeuse.hoehe,
                             tc.gehaeuseRadius / tc.gehaeuse.hoehe,
                             "die AWTRIX-Front hat keine runderen Ecken als die TC002")
    }

    /// „Die Pixel sind auch groesser und eckiger." Beides als Anteil der
    /// Zellenkante, damit es an jeder Kantenlaenge gilt.
    func testAwtrixZeichnetGroessereUndEckigerePunkte() {
        let tc = Geraetezeichnung.tc002.pixelstil
        let ng = Geraetezeichnung.awtrixNG.pixelstil

        XCTAssertGreaterThan(ng.punktKante(zelle: 8), tc.punktKante(zelle: 8),
                             "die AWTRIX-Punkte sind nicht groesser")
        XCTAssertLessThan(ng.punktRadius(zelle: 8), tc.punktRadius(zelle: 8),
                          "die AWTRIX-Punkte sind nicht eckiger")
        XCTAssertEqual(ng.punktRadius(zelle: 8), 0, accuracy: 0.0001,
                       "eckig heisst Radius null")

        // Der Punkt sitzt mittig in seiner Zelle, nicht links oben
        // angeschlagen — sonst liegt die ganze Luecke rechts und unten und das
        // Raster sitzt schief im Feld.
        for stil in [tc, ng] {
            let kasten = stil.kaestchen(spalte: 3, zeile: 2, zelle: 8)
            XCTAssertEqual(kasten.midX, 3.5 * 8, accuracy: 0.0001)
            XCTAssertEqual(kasten.midY, 2.5 * 8, accuracy: 0.0001)
        }

        // Bei Kante 8 zeichnet die TC002 genau den einen Punkt Abstand, den
        // beide Vorschauen bisher hatten — die Ablösung der SVG aendert am
        // Raster nichts.
        XCTAssertEqual(tc.punktKante(zelle: 8), 7, accuracy: 0.0001)
    }

    /// Der Aufdruck auf dem Geraet ist eine **Zeichnung**, kein Text der
    /// Oberflaeche: Auf dem echten Geraet steht „Ulanzi TC001" aufgedruckt,
    /// und aufgedruckte Buchstaben uebersetzt niemand. Wuerde er als
    /// `LocalizedStringKey` gesetzt, legte das einen Uebersetzungsschluessel
    /// an, den nie jemand fuellt — und `texte-sammeln.py --pruefen` meldete
    /// ihn von da an als fehlend.
    func testAufdruckIstZeichnungUndWirdNichtUebersetzt() throws {
        let aufdrucke = Geraetezeichnung.awtrixNG.teile.compactMap { teil -> String? in
            if case let .schrift(wortlaut, _, _, _, _, _) = teil { return wortlaut }
            return nil
        }
        XCTAssertEqual(aufdrucke, ["Ulanzi TC001"])

        let quelle = try String(contentsOf: Self.wurzel
            .appendingPathComponent("Sources/TC002Ansichten/GeraeteRahmen.swift"), encoding: .utf8)
        XCTAssertTrue(quelle.contains("Text(verbatim: wortlaut)"),
                      "der Aufdruck wird nicht mehr als verbatim gesetzt — er landet damit in der Uebersetzung")
    }

    /// Der Aufdruck sitzt unten links, unter dem Display und noch im Gehaeuse.
    /// Ein Schriftzug, der aus dem Geraet herausragt oder ins Display
    /// hineinragt, uebersieht man auf einem kleinen Bild leicht.
    func testAufdruckSitztUnterDemDisplayImGehaeuse() {
        for z in [Geraetezeichnung.tc002, Geraetezeichnung.awtrixNG] {
            for teil in z.teile {
                guard case let .schrift(wortlaut, x, grundlinie, _, _, _) = teil else { continue }
                XCTAssertGreaterThan(grundlinie, z.feld.unten, "\(wortlaut) ragt ins Display")
                XCTAssertLessThanOrEqual(grundlinie, z.gehaeuse.unten, "\(wortlaut) ragt aus dem Gehaeuse")
                XCTAssertGreaterThanOrEqual(x, z.gehaeuse.x, "\(wortlaut) beginnt links vor dem Gehaeuse")
                XCTAssertLessThanOrEqual(x, z.gehaeuse.rechts, "\(wortlaut) beginnt rechts vom Gehaeuse")
            }
        }
    }

    /// Jede gezeichnete Flaeche liegt im Zeichenraum. Ein Teil ausserhalb wird
    /// von `Canvas` stillschweigend abgeschnitten — am Bild sieht man dann
    /// nur, dass etwas fehlt, nicht warum.
    func testAlleTeileLiegenImZeichenraum() {
        for z in [Geraetezeichnung.tc002, Geraetezeichnung.awtrixNG] {
            for teil in z.teile {
                guard case let .flaeche(r, _, _) = teil else { continue }
                XCTAssertGreaterThanOrEqual(r.x, 0)
                XCTAssertGreaterThanOrEqual(r.y, 0)
                XCTAssertLessThanOrEqual(r.rechts, z.breite)
                XCTAssertLessThanOrEqual(r.unten, z.hoehe)
            }
            // Und das Feld liegt im Gehaeuse, nicht daneben.
            XCTAssertGreaterThanOrEqual(z.feld.x, z.gehaeuse.x)
            XCTAssertGreaterThanOrEqual(z.feld.y, z.gehaeuse.y)
            XCTAssertLessThanOrEqual(z.feld.rechts, z.gehaeuse.rechts)
            XCTAssertLessThanOrEqual(z.feld.unten, z.gehaeuse.unten)
        }
    }
}
