import XCTest
@testable import TC002Core

/// Die Formatangaben eines Kurzbefehls. Zwei Dinge muessen stimmen: Was nicht
/// angegeben ist, bleibt bei der Vorgabe aus den Einstellungen — und die
/// Groesse kommt an derselben abgesegneten Liste nicht vorbei, an der auch die
/// Sendeansicht haengt.
final class FormatangabenTests: XCTestCase {

    /// Eine Vorgabe, die sich von den eingebauten Werten unterscheidet — sonst
    /// saehe man nicht, ob etwas uebernommen oder nur nicht veraendert wurde.
    private func vorgabe() -> Meldungsoptionen {
        Meldungsoptionen(text: "Hallo", weg: .text, schrift: "Tiny5", groesse: 12,
                         fett: true, farbe: "#123456", grossbuchstaben: true,
                         waagrecht: .rechts, senkrecht: .unten, rand: 2, abstand: 3,
                         tempo: .schnell, iconLaeuftMit: true, dauer: 7)
    }

    /// Der bestehende Kurzbefehl gibt keine einzige Formatangabe mit. Er muss
    /// unveraendert weiterlaufen.
    func testOhneAngabenBleibtAllesWieEingestellt() throws {
        let v = vorgabe()
        let o = try Formatangaben().angewendet(auf: v)
        XCTAssertEqual(o.weg, v.weg)
        XCTAssertEqual(o.schrift, v.schrift)
        XCTAssertEqual(o.groesse, v.groesse)
        XCTAssertEqual(o.fett, v.fett)
        XCTAssertEqual(o.grossbuchstaben, v.grossbuchstaben)
        XCTAssertEqual(o.farbe, v.farbe)
        XCTAssertEqual(o.waagrecht, v.waagrecht)
        XCTAssertEqual(o.senkrecht, v.senkrecht)
        XCTAssertEqual(o.rand, v.rand)
        XCTAssertEqual(o.abstand, v.abstand)
        XCTAssertEqual(o.tempo, v.tempo)
        XCTAssertEqual(o.iconLaeuftMit, v.iconLaeuftMit)
        // Text und Dauer gehen die Formatangaben nichts an.
        XCTAssertEqual(o.text, "Hallo")
        XCTAssertEqual(o.dauer, 7)
    }

    /// Jede einzelne Angabe muss auch wirklich ankommen — eine, die im
    /// Kurzbefehl steht und nichts bewirkt, ist der Anlass dieser Aufgabe.
    func testJedeAngabeKommtAn() throws {
        let angaben = Formatangaben(weg: .pixel, schrift: "Micro 5", groesse: 14,
                                    fett: false, grossbuchstaben: false, farbe: "#00FF66",
                                    waagrecht: .mittig, senkrecht: .oben, rand: 0,
                                    abstand: 1, tempo: .langsam, iconLaeuftMit: false)
        let o = try angaben.angewendet(auf: vorgabe())
        XCTAssertEqual(o.weg, .pixel)
        XCTAssertEqual(o.schrift, "Micro 5")
        XCTAssertEqual(o.groesse, 14)
        XCTAssertFalse(o.fett)
        XCTAssertFalse(o.grossbuchstaben)
        XCTAssertEqual(o.farbe, "#00FF66")
        XCTAssertEqual(o.waagrecht, .mittig)
        XCTAssertEqual(o.senkrecht, .oben)
        XCTAssertEqual(o.rand, 0)
        XCTAssertEqual(o.abstand, 1)
        XCTAssertEqual(o.tempo, .langsam)
        XCTAssertFalse(o.iconLaeuftMit)
    }

    /// Eine abgesegnete Groesse geht durch, unveraendert.
    func testAbgesegneteGroesseWirdUebernommen() throws {
        let o = try Formatangaben(groesse: 9).angewendet(auf: vorgabe())
        XCTAssertEqual(o.groesse, 9)   // Tiny5: 7, 8, 9, 10, 12, 14, 16
    }

    /// Der Kern der zweiten Bedingung: Eine Groesse, die ein Augenpaar nicht
    /// abgesegnet hat, geht nicht durch — und die Absage nennt die, die es
    /// gibt.
    func testNichtAbgesegneteGroesseWirdAbgewiesen() {
        XCTAssertThrowsError(try Formatangaben(groesse: 11).angewendet(auf: vorgabe())) { fehler in
            XCTAssertEqual(fehler as? Formatangaben.Fehler,
                           .groesseNichtAngeboten(groesse: 11, schrift: "Tiny5",
                                                  angeboten: [7, 8, 9, 10, 12, 14, 16]))
            let text = (fehler as? Formatangaben.Fehler)?.errorDescription ?? ""
            XCTAssertTrue(text.contains("Tiny5"), text)
            XCTAssertTrue(text.contains("7, 8, 9, 10, 12, 14, 16"), text)
        }
    }

    /// Geprueft wird gegen die Schrift, die nachher gilt: Acht Pixel gibt es
    /// bei Tiny5, bei Micro 5 nicht. Wer beides zusammen angibt, bekommt den
    /// Fehler — sonst schickte der Kurzbefehl eine Groesse, die Micro 5 nie
    /// angeboten hat.
    func testGroesseWirdGegenDieNeueSchriftGeprueft() {
        let angaben = Formatangaben(schrift: "Micro 5", groesse: 8)
        XCTAssertThrowsError(try angaben.angewendet(auf: vorgabe())) { fehler in
            XCTAssertEqual(fehler as? Formatangaben.Fehler,
                           .groesseNichtAngeboten(groesse: 8, schrift: "Micro 5",
                                                  angeboten: [10, 14, 16]))
        }
    }

    /// Nur die Schrift gewechselt, keine Groesse verlangt: Dann faellt die
    /// geerbte Groesse auf die naechstgelegene der neuen Liste — dieselbe
    /// Regel wie beim Schriftwechsel in der Sendeansicht. Abgewiesen wird hier
    /// nichts, denn niemand hat eine Groesse verlangt.
    func testSchriftwechselZiehtDieGeerbteGroesseNach() throws {
        // Vorgabe ist 12; Micro 5 hat 10, 14, 16 — 10 und 14 liegen gleich
        // weit, die kleinere gewinnt.
        let o = try Formatangaben(schrift: "Micro 5").angewendet(auf: vorgabe())
        XCTAssertEqual(o.schrift, "Micro 5")
        XCTAssertEqual(o.groesse, 10)
    }

    /// Eine Systemschrift hat keine durchgesehene Liste und bekommt den vollen
    /// Bereich — aber auch der hat Grenzen.
    func testSchriftOhneListeNimmtDenVollenBereich() throws {
        let o = try Formatangaben(schrift: "Menlo", groesse: 11).angewendet(auf: vorgabe())
        XCTAssertEqual(o.groesse, 11)
        XCTAssertThrowsError(try Formatangaben(schrift: "Menlo", groesse: 17)
            .angewendet(auf: vorgabe()))
    }

    /// Rand und Abstand kommen aus einem Feld mit Bereichsangabe; eine
    /// Variable kann das umgehen. Geklemmt wie der Stepper, nicht abgewiesen.
    func testRandUndAbstandWerdenGeklemmt() throws {
        let o = try Formatangaben(rand: 9, abstand: -4).angewendet(auf: vorgabe())
        XCTAssertEqual(o.rand, 3)
        XCTAssertEqual(o.abstand, 0)
    }
}
