import XCTest
@testable import TC002Core

/// Der Verlauf ist das Dritte neben Protokoll und Slotgedaechtnis.
///
/// Das Protokoll ist technisch und fluechtig, das Gedaechtnis haelt einen
/// Stand je Platz. Der Verlauf haelt die Sendungen — mit allen Reglern, damit
/// ein Druck darauf dieselbe Meldung wiederherstellt und nicht nur ihren Text.
final class SendeverlaufTests: XCTestCase {
    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private func eintrag(_ text: String, platz: Int? = 1, uhr: String = "Küche",
                         zeit: Date = Date()) -> Verlaufseintrag {
        Verlaufseintrag(zeit: zeit, platz: platz, uhr: uhr,
                        optionen: Meldungsoptionen(text: text), iconNummer: nil, iconKante: 8)
    }

    func testGemerktesKommtZurueck() {
        let verlauf = Sendeverlauf(ordner: temp(), kennung: "A")
        verlauf.merken(eintrag("Kaffee"))
        let alle = verlauf.alle()
        XCTAssertEqual(alle.count, 1)
        XCTAssertEqual(alle.first?.optionen.text, "Kaffee")
        XCTAssertEqual(alle.first?.platz, 1)
    }

    /// Das Juengste zuerst — gelesen wird von oben nach unten.
    func testDasJuengsteStehtOben() {
        let verlauf = Sendeverlauf(ordner: temp(), kennung: "A")
        let frueher = Date(timeIntervalSinceNow: -60)
        verlauf.merken(eintrag("alt", zeit: frueher))
        verlauf.merken(eintrag("neu"))
        XCTAssertEqual(verlauf.alle().map(\.optionen.text), ["neu", "alt"])
    }

    /// Wer dreimal dasselbe schickt, will keine drei Zeilen lesen. Zwei
    /// gleiche hintereinander werden zu einer — die Zeit ist die der
    /// letzten Sendung.
    func testZweiGleicheHintereinanderStehenNurEinmalDa() {
        let verlauf = Sendeverlauf(ordner: temp(), kennung: "A")
        verlauf.merken(eintrag("Kaffee", zeit: Date(timeIntervalSinceNow: -60)))
        verlauf.merken(eintrag("Kaffee"))
        XCTAssertEqual(verlauf.alle().count, 1)
    }

    /// Dasselbe mit etwas dazwischen bleibt zweimal stehen: Der Verlauf
    /// erzaehlt, was geschah, und dazu gehoert die Wiederholung.
    func testMitEtwasDazwischenStehtEsZweimalDa() {
        let verlauf = Sendeverlauf(ordner: temp(), kennung: "A")
        verlauf.merken(eintrag("Kaffee", zeit: Date(timeIntervalSinceNow: -120)))
        verlauf.merken(eintrag("Bus", zeit: Date(timeIntervalSinceNow: -60)))
        verlauf.merken(eintrag("Kaffee"))
        XCTAssertEqual(verlauf.alle().map(\.optionen.text), ["Kaffee", "Bus", "Kaffee"])
    }

    /// Zwei Installationen, zwei Dateien, eine Liste: Genau dafuer ist je
    /// Installation eine eigene Datei da. Eine gemeinsame haette der zuletzt
    /// schreibende ueberbuegelt.
    func testZweiGeraeteWerdenZusammengefuehrt() {
        let ordner = temp()
        let mac = Sendeverlauf(ordner: ordner, kennung: "Mac")
        let telefon = Sendeverlauf(ordner: ordner, kennung: "Telefon")
        mac.merken(eintrag("vom Mac", zeit: Date(timeIntervalSinceNow: -60)))
        telefon.merken(eintrag("vom Telefon"))

        XCTAssertEqual(mac.alle().map(\.optionen.text), ["vom Telefon", "vom Mac"],
                       "Beide Dateien gehoeren in eine Liste, das Juengste zuerst.")
    }

    /// Ein einzelner Eintrag laesst sich nur aus der eigenen Datei
    /// nehmen — die des anderen Geraets gehoert ihm.
    func testEinzelnesVergessenGiltNurFuerDieEigeneDatei() {
        let ordner = temp()
        let mac = Sendeverlauf(ordner: ordner, kennung: "Mac")
        let telefon = Sendeverlauf(ordner: ordner, kennung: "Telefon")
        let fremd = eintrag("vom Telefon")
        telefon.merken(fremd)
        mac.merken(eintrag("vom Mac"))

        XCTAssertFalse(mac.vergessen(fremd.id), "Fremde Eintraege ruehrt diese Installation nicht an.")
        XCTAssertEqual(mac.alle().count, 2)
    }

    /// Leeren meint alles — auch die Dateien der anderen Geraete.
    func testLeerenNimmtAllesMit() {
        let ordner = temp()
        Sendeverlauf(ordner: ordner, kennung: "Telefon").merken(eintrag("weg"))
        let mac = Sendeverlauf(ordner: ordner, kennung: "Mac")
        mac.merken(eintrag("auch weg"))
        XCTAssertTrue(mac.leeren())
        XCTAssertTrue(mac.alle().isEmpty)
    }

    /// Dieselbe Sendung an dieselben Uhren ergibt eine Zeile, gleich in
    /// welcher Reihenfolge die Uhren geantwortet haben.
    ///
    /// `AppZustand.verlaufEintragen` baut das Feld `uhr` aus einer Menge; ohne
    /// Sortierung stand dieselbe Sendung zweimal im Verlauf, einmal als
    /// „A, B" und einmal als „B, A". Sortiert wird an der Quelle
    /// (`Verlaufseintrag.uhrenfeld`), weil `gleichtInhaltlich` genau diese
    /// Zeichenkette vergleicht.
    func testDieUhrenStehenSortiertUndMachenGleicheSendungenGleich() {
        XCTAssertEqual(Verlaufseintrag.uhrenfeld(["Werkstatt", "Küche"]), "Küche, Werkstatt")
        let eins = eintrag("Kaffee", uhr: Verlaufseintrag.uhrenfeld(["Küche", "Werkstatt"]))
        let zwei = eintrag("Kaffee", uhr: Verlaufseintrag.uhrenfeld(["Werkstatt", "Küche"]))
        XCTAssertTrue(eins.gleichtInhaltlich(zwei),
                      "Zwei gleiche Sendungen gelten wieder als verschieden, nur weil die Uhren in "
                      + "anderer Reihenfolge geantwortet haben.")
    }

    /// Und die Ablage macht daraus wirklich eine Zeile.
    func testZweiGleicheSendungenStehenNurEinmalDa() {
        let verlauf = Sendeverlauf(ordner: temp(), kennung: "A")
        verlauf.merken(eintrag("Kaffee", uhr: Verlaufseintrag.uhrenfeld(["Küche", "Werkstatt"])))
        verlauf.merken(eintrag("Kaffee", uhr: Verlaufseintrag.uhrenfeld(["Werkstatt", "Küche"])))
        XCTAssertEqual(verlauf.alle().count, 1)
    }

    /// Die Obergrenze gilt je Installation — ein Verlauf ist eine
    /// Erinnerungsstuetze, kein Archiv.
    func testUeberDerObergrenzeFaelltDasAeltesteWeg() {
        let verlauf = Sendeverlauf(ordner: temp(), kennung: "A")
        for i in 0...Sendeverlauf.obergrenze {
            verlauf.merken(eintrag("Nr \(i)", zeit: Date(timeIntervalSinceNow: Double(i))))
        }
        let alle = verlauf.alle()
        XCTAssertEqual(alle.count, Sendeverlauf.obergrenze)
        XCTAssertFalse(alle.contains { $0.optionen.text == "Nr 0" })
    }
}
