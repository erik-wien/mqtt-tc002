import XCTest
import TC002Core
@testable import TC002Ansichten

/// Der Geraeterahmen ist eine Zeichnung, und eine Zeichnung sieht man sich an.
/// Was ein Blick aufs Bild aber nicht sieht, ist eine um zwei Prozent
/// falsche Feldbreite: Die Pixel stehen dann nicht mehr quadratisch im Feld
/// oder werden am Rand angeschnitten, und beides faellt erst auf, wenn jemand
/// die Vorschau mit dem Geraet vergleicht. Deshalb stehen die Masse hier in
/// Zusicherungen.
final class GeraeterahmenTests: XCTestCase {

    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Das Raster, das der Rahmen zeigt: die 52×16 der TC002.
    private static let arten: [(spalten: Int, zeilen: Int)] = [
        (Pixelfeld.breiteStandard, Pixelfeld.hoeheStandard),
    ]

    /// Der Kern der Sache: Der Rahmen skaliert seine Zeichnung an die
    /// Hoehe des Inhalts — den Inhalt selbst skaliert er nie. Ein Pixel ist
    /// darum so breit wie hoch, an jeder Kantenlaenge und bei jeder Geraeteart.
    func testFeldNimmtDenInhaltQuadratischUndUnverzerrtAuf() {
        for art in Self.arten {
            let z = Geraetezeichnung.tc002
            for kante in [4.0, 6, 8, 11, 14] {
                let inhaltBreite = Double(art.spalten) * kante
                let inhaltHoehe = Double(art.zeilen) * kante
                let m = z.masse(inhaltHoehe: inhaltHoehe)
                let wo = "bei Kante \(kante)"

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
                //    muss unter einer Pixelbreite liegen, sonst bliebe
                //    rechts im Feld ein schwarzer Streifen, den kein Inhalt
                //    je erreicht.
                XCTAssertLessThan(m.feldBreite - inhaltBreite, kante,
                                  "schwarzer Rest im Feld breiter als ein Pixel — \(wo)")

                // 5. Der Inhalt sitzt oben und links buendig — wie auf dem
                //    Geraet selbst, das eine Anzeige immer bei Spalte 0 beginnt.
                //    Nicht zentriert: Bleibt doch einmal etwas uebrig, gehoert
                //    der Rest nach rechts und nicht je zur Haelfte auf beide
                //    Seiten (siehe `inhaltEcke`).
                let ecke = z.inhaltEcke(inhaltHoehe: inhaltHoehe)
                XCTAssertEqual(ecke.y, m.feldY, accuracy: 0.0001, "Inhalt nicht oben buendig — \(wo)")
                XCTAssertEqual(ecke.x, m.feldX, accuracy: 0.0001, "Inhalt nicht links buendig — \(wo)")
            }
        }
    }

    /// Was die App wirklich rastert, gegen das, was die Zeichnung dafuer
    /// vorsieht.
    func testDasGerasterteFeldFuelltDasDisplayfeldWirklichAus() {
        let z = Geraetezeichnung.tc002
        let mass = Anzeigemass.fuer(Uhr(name: "NG", host: "b.example"))
        let feld = Meldungsbau.feld(Meldungsoptionen(text: "Hallo"), mitIcon: false, mass: mass)
        for kante in [4.0, 8, 14] {
            let m = z.masse(inhaltHoehe: Double(feld.hoehe) * kante)
            let rest = m.feldBreite - Double(feld.breite) * kante
            XCTAssertGreaterThanOrEqual(rest, -0.0001, "das Raster ragt aus dem Displayfeld — Kante \(kante)")
            XCTAssertLessThan(rest, kante, "\(rest / kante) Spalten des Displayfeldes bleiben leer — Kante \(kante)")
        }
    }

    /// Das gezeichnete Feld muss das
    /// Seitenverhaeltnis des Rasters haben, das darin gezeigt wird. 52×16 ist
    /// 3,25.
    func testFeldhatDasSeitenverhaeltnisSeinesRasters() {
        for art in Self.arten {
            let z = Geraetezeichnung.tc002
            let rasterVerhaeltnis = Double(art.spalten) / Double(art.zeilen)
            let feldVerhaeltnis = z.feld.breite / z.feld.hoehe
            XCTAssertEqual(feldVerhaeltnis, rasterVerhaeltnis, accuracy: rasterVerhaeltnis * 0.03,
                           "Feld \(feldVerhaeltnis) passt nicht zu \(art.spalten)×\(art.zeilen)")
        }
    }

    /// Der Punkt sitzt mittig in seiner Zelle, nicht links oben angeschlagen:
    /// Läge die ganze Luecke rechts und unten, saesse das Raster um einen
    /// halben Punkt schief im Feld.
    func testPunkteSitzenMittigInIhrerZelle() {
        for z in [Geraetezeichnung.tc002, .tc001] {
            for zelle in [4.0, 8, 14] {
                let kasten = z.pixelstil.kaestchen(spalte: 3, zeile: 2, zelle: zelle)
                XCTAssertEqual(kasten.midX, 3.5 * zelle, accuracy: 0.0001)
                XCTAssertEqual(kasten.midY, 2.5 * zelle, accuracy: 0.0001)
            }
        }
    }

    /// Der Aufdruck sitzt unten links, unter dem Display und noch im Gehaeuse.
    /// Ein Schriftzug, der aus dem Geraet herausragt oder ins Display
    /// hineinragt, uebersieht man auf einem kleinen Bild leicht.
    func testAufdruckSitztUnterDemDisplayImGehaeuse() {
        for z in [Geraetezeichnung.tc002, .tc001] {
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
        for z in [Geraetezeichnung.tc002, .tc001] {
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

    /// Der Aufdruck auf dem Geraet ist eine Zeichnung, kein Text der
    /// Oberflaeche: Aufgedruckte Buchstaben uebersetzt niemand. Als
    /// `LocalizedStringKey` gesetzt, legte er einen Uebersetzungsschluessel an,
    /// den nie jemand fuellt.
    func testAufdruckIstZeichnungUndWirdNichtUebersetzt() throws {
        let quelle = try String(contentsOf: Self.wurzel
            .appendingPathComponent("Sources/TC002Ansichten/GeraeteRahmen.swift"), encoding: .utf8)
        XCTAssertTrue(quelle.contains("Text(verbatim: wortlaut)"))
    }

    /// Die Zeichnung folgt dem Anzeigemass der Uhr.
    func testZeichnungWirdNachDemAnzeigemassGewaehlt() {
        XCTAssertEqual(Geraetezeichnung.fuer(Anzeigemass(breite: 32, hoehe: 8)), .tc001)
        XCTAssertEqual(Geraetezeichnung.fuer(Anzeigemass(breite: 52, hoehe: 16)), .tc002)
        XCTAssertEqual(Geraetezeichnung.fuer(Anzeigemass(breite: 64, hoehe: 8)), .tc002)
    }

    /// Das Raster ragt bei keinem Mass und keiner Kante aus dem Feld, und bei
    /// den beiden Geraeten fuellt es es auch aus.
    func testRasterPasstInsFeldDerGewaehltenZeichnung() {
        for (breite, hoehe, fuellt) in [(32, 8, true), (52, 16, true), (64, 8, false), (40, 16, false)] {
            let mass = Anzeigemass(breite: breite, hoehe: hoehe)
            let z = Geraetezeichnung.fuer(mass)
            for kante in [4.0, 6, 12] {
                let m = z.masse(fuer: mass, kante: kante)
                let wo = "\(breite)×\(hoehe), Kante \(kante)"
                XCTAssertGreaterThanOrEqual(m.feldBreite, Double(breite) * kante - 0.0001, "ragt rechts heraus — \(wo)")
                XCTAssertGreaterThanOrEqual(m.feldHoehe, Double(hoehe) * kante - 0.0001, "ragt unten heraus — \(wo)")
                if fuellt {
                    XCTAssertLessThan(m.feldBreite - Double(breite) * kante, kante, "Rest breiter als ein Pixel — \(wo)")
                }
            }
        }
    }

    /// Das Feld der TC001 hat genau das Verhaeltnis 32:8.
    func testFeldDerTC001IstGenau32Zu8() {
        let z = Geraetezeichnung.tc001
        XCTAssertEqual(z.feld.breite / z.feld.hoehe, 4, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(z.feld.x, z.gehaeuse.x)
        XCTAssertLessThanOrEqual(z.feld.rechts, z.gehaeuse.rechts)
        for teil in z.teile {
            guard case let .flaeche(r, _, _) = teil else { continue }
            XCTAssertGreaterThanOrEqual(r.x, 0); XCTAssertGreaterThanOrEqual(r.y, 0)
            XCTAssertLessThanOrEqual(r.rechts, z.breite); XCTAssertLessThanOrEqual(r.unten, z.hoehe)
        }
    }
}
