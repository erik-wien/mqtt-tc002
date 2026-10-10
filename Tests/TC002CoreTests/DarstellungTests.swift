import Foundation
import XCTest
@testable import TC002Core

/// Hintergrund, Effekt, Overlay, Palette, Diagramme und Fortschritt
/// (`docs/awtrix-ng-protokoll.md` §5.5): Nutzlast byteweise und Prüfung vor dem
/// Senden. Die Namenslisten sind ein Prüfstand (so wie die Uhr sie meldet), kein
/// Teil der Logik.
final class DarstellungTests: XCTestCase {

    private let uhr = Geraetefaehigkeiten(
        effekte: ["Plasma", "Matrix", "PingPong"], paletteneffekte: ["Plasma"],
        overlays: ["rain", "snow"], paletten: ["Lava", "Ocean"], uebergaenge: ["Slide"])

    private func text(_ d: Darstellung?) -> Frame {
        Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x", weg: .text)), darstellung: d)
    }

    private let pixel = Pixelinhalt(breite: 52, hoehe: 16, bilder: [
        Bildraster.Einzelbild(pixel: [String?](repeating: "#FF0000", count: 832), dauer: 1)])

    // MARK: - Nutzlast

    func testEinTextOhneDarstellungBleibtByteGleich() throws {
        XCTAssertEqual(try Anzeigen.nutzlast(text(nil)), try Anzeigen.nutzlast(text(Darstellung())))
    }

    func testDieFelderStehenInFesterReihenfolge() throws {
        let d = Darstellung(effekt: "plasma", effektTempo: 2.5, overlay: "RAIN",
                            palette: .name("lava"), paletteUeberblenden: false,
                            paletteSpanne: 8, paletteTempo: 0.5)
        let json = try Anzeigen.nutzlast(text(d), faehigkeiten: uhr)
        XCTAssertTrue(json.hasSuffix(
            ##","effect":"Plasma","effectSpeed":2.5,"overlay":"rain","palette":"Lava","paletteBlend":false,"paletteSpan":8,"paletteSpeed":0.5}"##), json)
    }

    func testHintergrundfarbeUndPaletteAlsStuetzstellen() throws {
        let a = try Anzeigen.nutzlast(text(Darstellung(hintergrundfarbe: "#0a0b0c")))
        XCTAssertTrue(a.hasSuffix(##","backgroundColor":"#0A0B0C"}"##), a)
        let farben = try Anzeigen.nutzlast(text(Darstellung(palette: .farben(["#ff0000", "#00ff00"]))))
        XCTAssertTrue(farben.hasSuffix(##","palette":["#FF0000","#00FF00"]}"##), farben)
        let stellen = try Anzeigen.nutzlast(text(Darstellung(
            palette: .stellen([.init(farbe: "#FF0000", pos: 0), .init(farbe: "#0000FF", pos: 100)]))))
        XCTAssertTrue(stellen.hasSuffix(##","palette":[{"color":"#FF0000","pos":0},{"color":"#0000FF","pos":100}]}"##), stellen)
    }

    func testDieTextfarbeAusDerPaletteErsetztDieReglerfarbe() throws {
        let json = try Anzeigen.nutzlast(text(Darstellung(palette: .name("Lava"), textfarbeAusPalette: true)))
        XCTAssertTrue(json.contains(##""textColor":"palette""##), json)
        XCTAssertFalse(json.contains("#00FF66"), json)
    }

    func testEineGrafikIstEineEigeneAnzeigeOhneText() throws {
        let g = Grafikinhalt(diagramm: .balken([1, -2, 3]), diagrammSkalieren: false,
                             diagrammfarbe: .farbe("#ff8800"), fortschritt: 40,
                             fortschrittsfarbe: .palette, fortschrittsgrund: "#222222")
        let d = Darstellung(overlay: "snow", palette: .name("Ocean"))
        let json = try Anzeigen.nutzlast(Frame(dauer: 5, darstellung: d, grafik: g), faehigkeiten: uhr)
        XCTAssertEqual(json,
            ##"{"barChart":[1, -2, 3],"chartAutoscale":false,"chartColor":"#FF8800","progress":40,"progressColor":"palette","progressTrackColor":"#222222","durationMs":5000,"overlay":"snow","palette":"Ocean"}"##)
        XCTAssertFalse(json.contains("text"))
        XCTAssertFalse(json.contains("icon"))
    }

    func testEinLiniendiagrammUndLebensdauer() throws {
        let f = Frame(lebensdauer: Lebensdauer(sekunden: 60),
                      grafik: Grafikinhalt(diagramm: .linie([1, 5])))
        XCTAssertTrue(try Anzeigen.nutzlast(f).hasPrefix(##"{"lineChart":[1, 5]"##))
        XCTAssertTrue(try Anzeigen.nutzlast(f).contains("lifetimeMs"))
    }

    func testEineBenachrichtigungTraegtDieselbenFelder() throws {
        let json = try NGNutzlast.benachrichtigung(
            text(Darstellung(overlay: "rain")), .init(name: "n"), faehigkeiten: uhr)
        XCTAssertTrue(json.contains(##""overlay":"rain""##) && json.contains(##""hold":true"##), json)
    }

    // MARK: - Gerasterter Inhalt

    func testEinBildNimmtEinOverlayAberKeinenHintergrund() throws {
        XCTAssertTrue(try Anzeigen.nutzlast(Frame(pixel: pixel, darstellung: Darstellung(overlay: "snow")))
            .hasSuffix(##","overlay":"snow"}"##))
        XCTAssertThrowsError(try Anzeigen.nutzlast(Frame(pixel: pixel, darstellung: Darstellung(hintergrundfarbe: "#112233")))) {
            XCTAssertEqual($0 as? DarstellungsFehler, .vomBildVerdeckt(feld: "backgroundColor"))
        }
        XCTAssertThrowsError(try Anzeigen.nutzlast(Frame(pixel: pixel, darstellung: Darstellung(effekt: "Plasma")))) {
            XCTAssertEqual($0 as? DarstellungsFehler, .vomBildVerdeckt(feld: "effect"))
        }
        XCTAssertThrowsError(try Anzeigen.nutzlast(Frame(pixel: pixel, darstellung: Darstellung(palette: .name("Lava"), textfarbeAusPalette: true)))) {
            XCTAssertEqual($0 as? DarstellungsFehler, .ohneText)
        }
    }

    func testEineGrafikVertraegtWederBildNochText() {
        let g = Grafikinhalt(fortschritt: 10)
        XCTAssertThrowsError(try Anzeigen.nutzlast(Frame(pixel: pixel, grafik: g))) {
            XCTAssertEqual($0 as? DarstellungsFehler, .grafikMitInhalt)
        }
        XCTAssertThrowsError(try Anzeigen.nutzlast(
            Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x", weg: .text)), grafik: g))) {
            XCTAssertEqual($0 as? DarstellungsFehler, .grafikMitInhalt)
        }
    }

    // MARK: - Prüfung

    func testBereicheUndFormen() {
        func fehler(_ d: Darstellung, _ f: Geraetefaehigkeiten? = nil) -> DarstellungsFehler? {
            do { try d.pruefen(gegen: f); return nil } catch { return error as? DarstellungsFehler }
        }
        XCTAssertNil(fehler(Darstellung(effektTempo: 0.1)))
        XCTAssertNil(fehler(Darstellung(effektTempo: 10)))
        XCTAssertEqual(fehler(Darstellung(effektTempo: 0)), .ausserhalb(feld: "effectSpeed", bereich: "0.1–10"))
        XCTAssertEqual(fehler(Darstellung(effektTempo: 10.5)), .ausserhalb(feld: "effectSpeed", bereich: "0.1–10"))
        XCTAssertNil(fehler(Darstellung(palette: .name("x"), paletteTempo: 0)))
        XCTAssertEqual(fehler(Darstellung(palette: .name("x"), paletteTempo: 11)), .ausserhalb(feld: "paletteSpeed", bereich: "0–10"))
        XCTAssertEqual(fehler(Darstellung(palette: .name("x"), paletteSpanne: -1)), .ausserhalb(feld: "paletteSpan", bereich: "≥ 0"))
        XCTAssertEqual(fehler(Darstellung(hintergrundfarbe: "rot")), .keineFarbe(feld: "backgroundColor", wert: "rot"))
        XCTAssertEqual(fehler(Darstellung(hintergrundfarbe: "#000000", effekt: "Plasma")), .farbeUndEffekt)
        XCTAssertEqual(fehler(Darstellung(paletteSpanne: 3)), .paletteFehlt(feld: "palette"))
        XCTAssertNotNil(fehler(Darstellung(palette: .farben([]))))
        XCTAssertNotNil(fehler(Darstellung(palette: .farben(Array(repeating: "#FFFFFF", count: 17)))))
        XCTAssertNil(fehler(Darstellung(palette: .farben(Array(repeating: "#FFFFFF", count: 16)))))
        XCTAssertNotNil(fehler(Darstellung(palette: .stellen([.init(farbe: "#FFFFFF", pos: 101)]))))
    }

    func testNamenWerdenGegenDieListenDerUhrGeprueft() {
        func fehler(_ d: Darstellung) -> DarstellungsFehler? {
            do { try d.pruefen(gegen: uhr); return nil } catch { return error as? DarstellungsFehler }
        }
        XCTAssertNil(fehler(Darstellung(effekt: "pLASMA", overlay: "Snow", palette: .name("ocean"))))
        XCTAssertEqual(fehler(Darstellung(effekt: "Quatsch")), .unbekannterName(feld: "effect", name: "Quatsch"))
        XCTAssertEqual(fehler(Darstellung(overlay: "hail")), .unbekannterName(feld: "overlay", name: "hail"))
        XCTAssertEqual(fehler(Darstellung(palette: .name("Neon"))), .unbekannterName(feld: "palette", name: "Neon"))
        // Ohne Listen (noch nicht abgefragt) bleiben Namen ungeprüft.
        XCTAssertNoThrow(try Darstellung(effekt: "Quatsch").pruefen())
        // Leer heißt: kein Effekt.
        XCTAssertNil(fehler(Darstellung(effekt: "", overlay: "")))
    }

    func testDieGrafikPruefung() {
        func fehler(_ g: Grafikinhalt, palette: Palette? = nil) -> DarstellungsFehler? {
            do { try g.pruefen(palette: palette); return nil } catch { return error as? DarstellungsFehler }
        }
        XCTAssertEqual(fehler(Grafikinhalt()), .grafikLeer)
        XCTAssertEqual(fehler(Grafikinhalt(diagramm: .linie([1]))), .zuWenigeWerte)
        XCTAssertNil(fehler(Grafikinhalt(diagramm: .balken(Array(repeating: 1, count: 16)))))
        XCTAssertNotNil(fehler(Grafikinhalt(diagramm: .balken(Array(repeating: 1, count: 17)))))
        XCTAssertNil(fehler(Grafikinhalt(fortschritt: 0)))
        XCTAssertNil(fehler(Grafikinhalt(fortschritt: 100)))
        XCTAssertNotNil(fehler(Grafikinhalt(fortschritt: 101)))
        XCTAssertNotNil(fehler(Grafikinhalt(fortschritt: -1)))
        XCTAssertEqual(fehler(Grafikinhalt(fortschritt: 5, fortschrittsfarbe: .palette)), .paletteFehlt(feld: "progressColor"))
        XCTAssertNil(fehler(Grafikinhalt(fortschritt: 5, fortschrittsfarbe: .palette), palette: .name("Lava")))
        XCTAssertEqual(fehler(Grafikinhalt(fortschritt: 5, fortschrittsgrund: "grau")),
                       .keineFarbe(feld: "progressTrackColor", wert: "grau"))
    }

    // MARK: - Fähigkeiten

    func testDieListenKommenAusDerAntwortDerUhr() throws {
        let antwort = try XCTUnwrap(JSONSerialization.jsonObject(with: Data("""
            {"effects":["Plasma","Matrix"],"paletteEffects":["Plasma"],"overlays":["rain"],"palettes":["Lava"],"transitions":["Slide"],"layout":true}
            """.utf8)) as? [String: Any])
        let f = try XCTUnwrap(Geraetefaehigkeiten(antwort: antwort))
        XCTAssertEqual(f.effekte, ["Plasma", "Matrix"])
        XCTAssertTrue(f.nutztPalette(effekt: "plasma"))
        XCTAssertFalse(f.nutztPalette(effekt: "Matrix"))
        XCTAssertNil(Geraetefaehigkeiten(antwort: ["layout": true]), "keine Fähigkeitsauskunft")
    }
}
