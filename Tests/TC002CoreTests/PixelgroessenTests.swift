import XCTest
@testable import TC002Core

/// Die angebotenen Schriftgroessen — eine Entscheidung, kein Rechenergebnis.
///
/// Diese Tests halten fest, was ein Augenpaar beim Durchsehen der Schriftprobe
/// abgesegnet hat (13.09.2026). Sie duerfen sich nur aendern, wenn jemand
/// wieder hinsieht — nicht, weil eine Messung etwas anderes sagt.
final class PixelgroessenTests: XCTestCase {
    func testAbgesegneteListenStehenFest() {
        XCTAssertEqual(Pixelgroessen.abgesegnet["Micro 5"], [10, 14, 16])
        XCTAssertEqual(Pixelgroessen.abgesegnet["Silkscreen"], [7, 8, 9, 10, 12, 14, 16])
        XCTAssertEqual(Pixelgroessen.abgesegnet["Tiny5"], [7, 8, 9, 12, 15, 16])
    }

    /// Der Grund, warum aus dem Schieber eine Liste wurde: Keine der drei
    /// Folgen hat eine gleichbleibende Schrittweite.
    func testAlleDreiListenHabenLuecken() {
        for (schrift, liste) in Pixelgroessen.abgesegnet {
            let schritte = Set(zip(liste, liste.dropFirst()).map { $1 - $0 })
            XCTAssertGreaterThan(schritte.count, 1,
                                 "„\(schrift)“ waere als Folge ausdrueckbar: \(liste)")
        }
    }

    /// Fuer Systemschriften gibt es keine Durchsicht — und deshalb auch keine
    /// erfundene Einschraenkung.
    func testSchriftOhneListeBekommtDenVollenBereich() {
        XCTAssertEqual(Pixelgroessen.angeboten(fuer: "Menlo"), Pixelgroessen.freierBereich)
        XCTAssertEqual(Pixelgroessen.angeboten(fuer: "Helvetica"), Pixelgroessen.freierBereich)
        XCTAssertEqual(Pixelgroessen.freierBereich, [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
    }

    func testSchriftMitListeBekommtNurDiese() {
        XCTAssertEqual(Pixelgroessen.angeboten(fuer: "Tiny5"), [7, 8, 9, 12, 15, 16])
    }

    /// Der eigentliche Auftrag: die naechstgelegene, nicht die kleinste.
    func testSchriftwechselNimmtDieNaechstgelegeneGroesse() {
        // 14 ist bei Micro 5 zu haben und bleibt stehen.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 14, fuer: "Micro 5"), 14)
        // 15 hat Micro 5 nicht; 14 und 16 liegen gleich weit, die kleinere gewinnt.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 15, fuer: "Micro 5"), 14)
        // Tiny5 hat 14 nicht; 15 liegt daneben, 7 waere die kleinste.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 14, fuer: "Tiny5"), 15)
        // Micro 5 faengt erst bei 10 an.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 6, fuer: "Micro 5"), 10)
        // Micro 5 hoert bei 16 auf.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 16, fuer: "Micro 5"), 16)
        // Ohne Liste bleibt jede Groesse des vollen Bereichs stehen.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 11, fuer: "Menlo"), 11)
    }

    /// Bei gleichem Abstand die kleinere: Sie passt in jedem Fall noch in die
    /// sechzehn Zeilen.
    func testGleicherAbstandNimmtDieKleinere() {
        // Silkscreen: 14 und 16 liegen beide einen Pixel von 15 entfernt.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 15, fuer: "Silkscreen"), 14)
        // Micro 5: 10 und 14 liegen beide zwei Pixel von 12 entfernt.
        XCTAssertEqual(Pixelgroessen.naechstgelegene(zu: 12, fuer: "Micro 5"), 10)
    }

    /// Ein Aufklappmenue ohne Eintrag fuer den eigenen Wert zeigte gar nichts
    /// an. Eine eingestellte Groesse abseits der Liste — aus einer aelteren
    /// Fassung oder von einem Meldungsplatz — bleibt deshalb waehlbar.
    func testEingestellteGroesseBleibtImMenue() {
        XCTAssertEqual(Pixelgroessen.auswahl(fuer: "Micro 5", mit: 12), [10, 12, 14, 16])
        XCTAssertEqual(Pixelgroessen.auswahl(fuer: "Micro 5", mit: 14), [10, 14, 16])
        XCTAssertEqual(Pixelgroessen.auswahl(fuer: "Menlo", mit: 11), Pixelgroessen.freierBereich)
    }

    /// Die Schriftprobe zeigt je Groesse „wird angeboten“ oder „wird nicht
    /// angeboten“ — sie zeigt aber nur die Groessen, die sie misst. Steht eine
    /// abgesegnete Groesse nicht darunter, behauptet die Seite stillschweigend,
    /// es gaebe sie nicht.
    func testJedeAbgesegneteGroesseWirdAuchGemessen() {
        for (schrift, liste) in Pixelgroessen.abgesegnet {
            for groesse in liste {
                XCTAssertTrue(Schriftprobe.groessen.contains(groesse),
                              "„\(schrift)“ bietet \(groesse) an, die Schriftprobe misst es nicht")
            }
        }
    }

    /// Die Schriftprobe zeigt genau die drei mitgelieferten Schriften; fuer
    /// jede davon muss es eine Liste geben, sonst stuende dort ueberall „wird
    /// angeboten“, obwohl die Sendeansicht einschraenkt.
    func testJedeMitgelieferteSchriftHatEineListe() {
        for schrift in Schriftprobe.mitgelieferteSchriften {
            XCTAssertNotNil(Pixelgroessen.abgesegnet[schrift], "„\(schrift)“ hat keine Liste")
        }
    }
}
