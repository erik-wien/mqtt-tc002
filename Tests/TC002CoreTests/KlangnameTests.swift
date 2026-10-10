import XCTest
@testable import TC002Core

/// Der Name einer MP3-Datei auf der Uhr: Prüfregel und Vorschlag. Die Beispiele
/// sind Dateinamen, an denen das Hochladen gescheitert ist.
final class KlangnameTests: XCTestCase {
    func testPruefregelNachDerMessung() {
        XCTAssertTrue(Klangname.gueltig("abcdefghijklmnopqrstuvwxyz012345"), "32 Zeichen")
        XCTAssertTrue(Klangname.gueltig("Gross_MIX-9"))
        XCTAssertTrue(Klangname.gueltig("star_trek"))
        XCTAssertFalse(Klangname.gueltig("abcdefghijklmnopqrstuvwxyz0123456"), "33 Zeichen")
        XCTAssertFalse(Klangname.gueltig("mit leer"))
        XCTAssertFalse(Klangname.gueltig("umläut"))
        XCTAssertFalse(Klangname.gueltig("punkt.x"))
        XCTAssertFalse(Klangname.gueltig("ding.mp3"))
        XCTAssertFalse(Klangname.gueltig(""))
    }

    func testUngueltigeZeichenOhneWiederholung() {
        XCTAssertEqual(Klangname.ungueltigeZeichen(in: "a b.c ü b"), [" ", ".", "ü"])
        XCTAssertEqual(Klangname.ungueltigeZeichen(in: "gut_9-x"), [])
    }

    func testVorschlagAusErikDateinamen() {
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: "tetris-gb-18-move-piece- 2.mp3"),
                       "tetris-gb-18-move-piece-2")
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: "tetris-gb-28-unknown-maybe-played-during-the-rocket-ending-.mp3"),
                       "tetris-gb-28-unknown-maybe-playe")
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: "Grüße aus Wien.mp3"), "Gruesse-aus-Wien")
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: "star_trek_chime_a.mp3"), "star_trek_chime_a")
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: ".mp3"), "klang")
    }

    func testVorschlagIstImmerGueltig() {
        let proben = ["tetris-gb-18-move-piece- 2.mp3", "Grüße aus Wien.mp3", ".mp3", "   .mp3", "日本語.mp3",
                      "Ärger & Öl (live) [2].MP3", "a.b.c.mp3", "___.mp3", "---x---.mp3", "ohne endung",
                      String(repeating: "ä", count: 40) + ".mp3", "\u{1F600}.mp3"]
        for p in proben {
            let v = Klangname.vorschlag(ausDateiname: p)
            XCTAssertTrue(Klangname.gueltig(v), "\(p) → \(v)")
            XCTAssertFalse(v.hasSuffix("-"), "\(p) → \(v)")
        }
    }

    func testUmlauteGrossUndKlein() {
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: "ÄÖÜ äöü ß.mp3"), "AeOeUe-aeoeue-ss")
    }

    func testZerlegterDateinameAusDemFinder() {
        let zerlegt = "Gru\u{0308}ße.mp3"
        XCTAssertNotEqual(Array(zerlegt.unicodeScalars), Array("Grüße.mp3".unicodeScalars), "wirklich zerlegt")
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: zerlegt), "Gruesse")
    }

    func testUebrigeAkzenteFallenWeg() {
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: "café déjà vu.mp3"), "cafe-deja-vu")
        XCTAssertEqual(Klangname.vorschlag(ausDateiname: "Ñandú.mp3"), "Nandu")
    }

    func testFreierNameGegenVorhandene() {
        XCTAssertEqual(Klangname.freierName("ding", vorhanden: ["gong"]), "ding")
        XCTAssertEqual(Klangname.freierName("ding", vorhanden: ["ding"]), "ding-2")
        XCTAssertEqual(Klangname.freierName("ding", vorhanden: ["ding", "ding-2", "ding-3"]), "ding-4")
        XCTAssertEqual(Klangname.freierName("ding", vorhanden: ["ding-2"]), "ding", "frei bleibt frei")
    }

    func testFreierNameBleibtInDen32Zeichen() {
        let lang = String(repeating: "a", count: 32)
        let frei = Klangname.freierName(lang, vorhanden: [lang])
        XCTAssertEqual(frei, String(repeating: "a", count: 30) + "-2")
        XCTAssertEqual(frei.count, 32)
        let zehn = Klangname.freierName(lang, vorhanden: [lang] + (2...9).map { String(repeating: "a", count: 30) + "-\($0)" })
        XCTAssertEqual(zehn, String(repeating: "a", count: 29) + "-10")
        let mitStrich = String(repeating: "a", count: 29) + "-bb"
        XCTAssertTrue(Klangname.gueltig(Klangname.freierName(mitStrich, vorhanden: [mitStrich])))
    }
}
