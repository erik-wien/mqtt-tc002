import XCTest
@testable import TC002Core

final class SlotgedaechtnisTests: XCTestCase {
    /// Ein frischer, noch nicht angelegter Ordnerpfad unter dem temporaeren
    /// Verzeichnis — nie unter „Application Support/MQTT-TC002": dort liegen
    /// die echten Slotdateien einer Installation.
    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    // MARK: Schritt 1 — Format

    /// Die Codable-Form von `Slotstand` ist ein Dateiformat: App, Werkzeug und
    /// Kurzbefehle schreiben dieselbe Datei. Wer hier ein Feld umbenennt,
    /// macht die Ablage einer laufenden Installation unlesbar.
    func testSlotstandBleibtLesbar() throws {
        let json = """
        {"platz":3,"text":"Bus kommt","weg":"pixel","schrift":"Silkscreen",\
        "groesse":8,"fett":false,"grossbuchstaben":false,"rand":1,"abstand":1,\
        "waagrecht":"links","senkrecht":"oben","farbe":"#00FF66","tempo":"mittel",\
        "iconLaeuftMit":false,"icon":"1673","dauer":10,"pruefsumme":"abcd1234"}
        """
        let stand = try JSONDecoder().decode(Slotstand.self, from: Data(json.utf8))
        XCTAssertEqual(stand.platz, 3)
        XCTAssertEqual(stand.text, "Bus kommt")
        XCTAssertEqual(stand.weg, "pixel")
        XCTAssertEqual(stand.schrift, "Silkscreen")
        XCTAssertEqual(stand.groesse, 8)
        XCTAssertEqual(stand.fett, false)
        XCTAssertEqual(stand.grossbuchstaben, false)
        XCTAssertEqual(stand.rand, 1)
        XCTAssertEqual(stand.abstand, 1)
        XCTAssertEqual(stand.waagrecht, "links")
        XCTAssertEqual(stand.senkrecht, "oben")
        XCTAssertEqual(stand.farbe, "#00FF66")
        XCTAssertEqual(stand.tempo, "mittel")
        XCTAssertEqual(stand.iconLaeuftMit, false)
        XCTAssertEqual(stand.icon, "1673")
        XCTAssertEqual(stand.dauer, 10)
        XCTAssertEqual(stand.pruefsumme, "abcd1234")
    }

    /// Ein Slot ohne Icon und ohne Dauer — beide optional, muessen also auch
    /// ohne im JSON auftauchen lesbar bleiben.
    func testSlotstandOhneIconUndDauerBleibtLesbar() throws {
        let json = """
        {"platz":1,"text":"x","weg":"text","schrift":"Silkscreen","groesse":8,\
        "fett":true,"grossbuchstaben":true,"rand":0,"abstand":2,"waagrecht":"mittig",\
        "senkrecht":"unten","farbe":"#FFFFFF","tempo":"schnell","iconLaeuftMit":true,\
        "pruefsumme":"deadbeef"}
        """
        let stand = try JSONDecoder().decode(Slotstand.self, from: Data(json.utf8))
        XCTAssertNil(stand.icon)
        XCTAssertNil(stand.dauer)
    }

    /// Schreiben und Lesen ueber `Slotgedaechtnis` muss dieselben Regler
    /// liefern, mit denen gesendet wurde — inklusive des Texts, den die
    /// Ergaenzung aus Aufgabe 1 verlangt.
    func testMerkenUndGemerkt() throws {
        let ordner = temp()
        let gedaechtnis = Slotgedaechtnis(ordner: ordner)
        let uhr = UUID()
        var optionen = Meldungsoptionen(text: "Bus kommt")
        optionen.schrift = "Silkscreen"
        optionen.farbe = "#00FF66"
        optionen.fett = true
        optionen.rand = 2
        // Die Dauer kommt aus den Optionen, nicht aus einem Parameter daneben —
        // ein zweiter Wert koennte von den gesendeten Reglern abweichen, ohne
        // dass es je auffiele (die Pruefsumme deckt nur die Pixel ab).
        optionen.dauer = 15

        gedaechtnis.merken(optionen, icon: "1673", iconKante: 8, fuer: uhr, platz: 2)
        let stand = try XCTUnwrap(gedaechtnis.gemerkt(fuer: uhr, platz: 2))

        XCTAssertEqual(stand.platz, 2)
        XCTAssertEqual(stand.text, "Bus kommt")
        XCTAssertEqual(stand.schrift, "Silkscreen")
        XCTAssertEqual(stand.farbe, "#00FF66")
        XCTAssertTrue(stand.fett)
        XCTAssertEqual(stand.rand, 2)
        XCTAssertEqual(stand.dauer, 15)
        XCTAssertEqual(stand.icon, "1673")
        XCTAssertFalse(stand.pruefsumme.isEmpty)
    }

    func testGemerktOhneEintragIstNil() {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        XCTAssertNil(gedaechtnis.gemerkt(fuer: UUID(), platz: 1))
    }

    /// Zwei verschiedene Texte ergeben unterschiedliche Pruefsummen — sonst
    /// waere sie kein Fingerabdruck, sondern eine Konstante.
    func testPruefsummeUnterscheidetInhalt() throws {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "eins"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "zwei"), icon: nil, iconKante: 8, fuer: uhr, platz: 2)
        let eins = try XCTUnwrap(gedaechtnis.gemerkt(fuer: uhr, platz: 1))
        let zwei = try XCTUnwrap(gedaechtnis.gemerkt(fuer: uhr, platz: 2))
        XCTAssertNotEqual(eins.pruefsumme, zwei.pruefsumme)
    }

    /// Dieselben Regler ergeben dieselbe Pruefsumme — der Fingerabdruck der
    /// Pixel, nicht ein Zufallswert je Aufruf.
    func testPruefsummeIstDeterministisch() {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        let optionen = Meldungsoptionen(text: "Bus kommt")
        gedaechtnis.merken(optionen, icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        let erste = gedaechtnis.gemerkt(fuer: uhr, platz: 1)?.pruefsumme
        gedaechtnis.merken(optionen, icon: nil, iconKante: 8, fuer: uhr, platz: 2)
        let zweite = gedaechtnis.gemerkt(fuer: uhr, platz: 2)?.pruefsumme
        XCTAssertEqual(erste, zweite)
    }

    // MARK: Schritt 2 — zwei Schreiber, eine Datei je Uhr

    /// Zwei Uhren teilen sich keinen Zustand — je eine eigene Datei.
    func testZweiUhrenBleibenGetrennt() {
        let ordner = temp()
        let gedaechtnis = Slotgedaechtnis(ordner: ordner)
        let a = UUID(), b = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "A"), icon: nil, iconKante: 8, fuer: a, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "B"), icon: nil, iconKante: 8, fuer: b, platz: 1)
        XCTAssertEqual(gedaechtnis.gemerkt(fuer: a, platz: 1)?.text, "A")
        XCTAssertEqual(gedaechtnis.gemerkt(fuer: b, platz: 1)?.text, "B")
    }

    /// Ein zweiter Schreiber auf einen anderen Platz derselben Uhr darf den
    /// ersten nicht loeschen — sonst waere die Ablage bei fuenf Slots ein
    /// Wettlauf um dieselbe Datei.
    func testMerkenAufAnderemPlatzLoeschtNichtDenErsten() {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "eins"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "zwei"), icon: nil, iconKante: 8, fuer: uhr, platz: 2)
        XCTAssertEqual(gedaechtnis.gemerkt(fuer: uhr, platz: 1)?.text, "eins")
        XCTAssertEqual(gedaechtnis.gemerkt(fuer: uhr, platz: 2)?.text, "zwei")
    }

    /// Ein zweites Merken desselben Platzes ersetzt ihn, statt einen zweiten
    /// Eintrag anzuhaengen.
    func testMerkenDesselbenPlatzesErsetzt() {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "alt"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "neu"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        XCTAssertEqual(gedaechtnis.gemerkt(fuer: uhr, platz: 1)?.text, "neu")
    }

    /// Eine unlesbare Datei (von Hand verbogen, aus einer aelteren Version,
    /// oder mitten in einem fremden Schreibvorgang erwischt) zaehlt als leer
    /// statt die App abstuerzen zu lassen.
    func testUnlesbareDateiZaehltAlsLeerStattAbzustuerzen() throws {
        let ordner = temp()
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let uhr = UUID()
        try Data("das ist kein JSON".utf8).write(to: ordner.appendingPathComponent("\(uhr.uuidString).json"))

        let gedaechtnis = Slotgedaechtnis(ordner: ordner)
        XCTAssertNil(gedaechtnis.gemerkt(fuer: uhr, platz: 1))

        // Und ein Schreibvorgang danach funktioniert normal weiter, statt an
        // der verbogenen Datei haengenzubleiben.
        gedaechtnis.merken(Meldungsoptionen(text: "neu"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        XCTAssertEqual(gedaechtnis.gemerkt(fuer: uhr, platz: 1)?.text, "neu")
    }

    // MARK: Schritt 3 — Ruckgabewert (Aufgabe 6)

    /// Erfolgreiches Schreiben meldet sich als `true` — die Absender (App,
    /// Werkzeug, Kurzbefehle) muessen das nicht extra pruefen, um es zu
    /// wissen.
    func testMerkenMeldetErfolgAlsRueckgabewert() {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        XCTAssertTrue(gedaechtnis.merken(Meldungsoptionen(text: "x"), icon: nil, iconKante: 8,
                                         fuer: UUID(), platz: 1))
    }

    /// Ein unbeschreibbarer Ordner (hier: eine Datei an der Stelle, an der ein
    /// Ordner erwartet wird) darf nicht abstuerzen, sondern muss sich als
    /// `false` melden — der Aufrufer entscheidet dann, was das bedeutet
    /// (`AppZustand.senden`: eine Protokollzeile, keine gescheiterte Sendung).
    func testMerkenMeldetFehlschlagAlsRueckgabewert() throws {
        let datei = temp()
        try Data().write(to: datei)
        let gedaechtnis = Slotgedaechtnis(ordner: datei.appendingPathComponent("Slots"))
        XCTAssertFalse(gedaechtnis.merken(Meldungsoptionen(text: "x"), icon: nil, iconKante: 8,
                                          fuer: UUID(), platz: 1))
    }

    /// Die Datei heisst nach der Uhr-ID und liegt allein im Ordner — kein
    /// Zwischenname bleibt liegen, und ein zweiter Name waere eine zweite
    /// Ablage. Der Dateiname ist Dateiformat: Danach sucht `gemerkt(fuer:)`
    /// und `vergessen(fuer:)`.
    ///
    /// Was dieser Test nicht haelt: dass `.atomic` gesetzt ist. Ein
    /// Einzelprozess-Test kann das nicht ehrlich beweisen — er bliebe auch
    /// mit `options: []` gruen. Ein Test, der in beiden Faellen gruen ist,
    /// waere schlimmer als keiner; deshalb steht die Zusicherung, die er
    /// wirklich haelt, in seinem Namen.
    func testMerkenLegtDateiUnterUhrIDAn() throws {
        let ordner = temp()
        let gedaechtnis = Slotgedaechtnis(ordner: ordner)
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "x"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        let inhalt = try FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil)
        XCTAssertEqual(inhalt.map(\.lastPathComponent), ["\(uhr.uuidString).json"])
    }

    // MARK: Vergessen je Platz

    /// Wer einen Platz mit etwas Unmerkbarem ueberschreibt — ein gemaltes Bild
    /// hat keine Regler —, muss die alte Erinnerung an diesen Platz wegwerfen.
    /// Bliebe sie liegen, rechnete `AppZustand.slotzustand` daraus beim
    /// naechsten Start ohne Broker wieder den Text, der vor dem Malen dort
    /// stand. Die andern vier Plaetze gehen dabei nichts an.
    func testVergessenJePlatzLaesstDieAndernStehen() {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "eins"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "drei"), icon: nil, iconKante: 8, fuer: uhr, platz: 3)

        XCTAssertTrue(gedaechtnis.vergessen(fuer: uhr, platz: 3))

        XCTAssertNil(gedaechtnis.gemerkt(fuer: uhr, platz: 3))
        XCTAssertEqual(gedaechtnis.gemerkt(fuer: uhr, platz: 1)?.text, "eins")
    }

    /// War zu diesem Platz nichts gemerkt, ist nichts zu tun — und kein
    /// Fehler: Auf einen Platz, der noch nie eine Textsendung getragen hat,
    /// darf ein gemaltes Bild ebenso gehen wie auf jeden anderen.
    func testVergessenOhneEintragIstKeinFehler() {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "eins"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)

        XCTAssertTrue(gedaechtnis.vergessen(fuer: uhr, platz: 4))
        XCTAssertTrue(gedaechtnis.vergessen(fuer: UUID(), platz: 1))

        XCTAssertEqual(gedaechtnis.gemerkt(fuer: uhr, platz: 1)?.text, "eins")
    }

    /// War es der letzte gemerkte Platz, geht die Datei ganz — ein Ordner voll
    /// leerer Listen waere nur Altbestand, den niemand mehr liest.
    func testVergessenDesLetztenPlatzesNimmtDieDatei() throws {
        let ordner = temp()
        let gedaechtnis = Slotgedaechtnis(ordner: ordner)
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "eins"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)

        XCTAssertTrue(gedaechtnis.vergessen(fuer: uhr, platz: 1))

        let inhalt = try FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil)
        XCTAssertEqual(inhalt, [])
    }

    // MARK: - Die Kante des Icons

    /// `merken` rechnete die Pruefsumme mit `Meldungsbau.feld(_:mitIcon:)` —
    /// und dessen Vorgabe fuer
    /// `iconKante` ist 8. Wer ein 16×16 sendete, bekam eine Pruefsumme ueber
    /// ein Bild, das so nie auf der Uhr stand; beim naechsten Tippen auf den
    /// Block verwarf `slotWaehlen` den Stand als „da hat jemand anderer
    /// geschrieben", und die Regler kamen nie zurueck.
    ///
    /// Geprueft wird deshalb genau die Gleichheit, auf die sich `slotWaehlen`
    /// stuetzt: die gemerkte Pruefsumme gegen die Pixel, die wirklich gesendet
    /// wurden.
    func testPruefsummeEinesSechzehnerIconsPasstZumGesendetenBild() throws {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        let optionen = Meldungsoptionen(text: "Post")

        gedaechtnis.merken(optionen, icon: "Sonne", iconKante: 16, fuer: uhr, platz: 1)
        let stand = try XCTUnwrap(gedaechtnis.gemerkt(fuer: uhr, platz: 1))

        let wirklichGesendet = Meldungsbau.feld(optionen, mitIcon: true, iconKante: 16).punkteRoh
        XCTAssertEqual(stand.pruefsumme, Slotgedaechtnis.pruefsumme(pixel: wirklichGesendet),
                       "die gemerkte Pruefsumme gehoert zu einem anderen Bild als dem gesendeten — "
                       + "genau daran scheiterte das Uebernehmen der Regler")
    }

    /// Und dass die beiden Kanten ueberhaupt verschiedene Bilder ergeben —
    /// sonst prueft der Test oben eine Gleichheit, die immer gilt.
    func testAchtUndSechzehnErgebenVerschiedeneBilder() {
        let optionen = Meldungsoptionen(text: "Post")
        let acht = Meldungsbau.feld(optionen, mitIcon: true, iconKante: 8).punkteRoh
        let sechzehn = Meldungsbau.feld(optionen, mitIcon: true, iconKante: 16).punkteRoh
        XCTAssertNotEqual(Slotgedaechtnis.pruefsumme(pixel: acht),
                          Slotgedaechtnis.pruefsumme(pixel: sechzehn))
    }

    /// Die Kante steht im Stand, damit `AppZustand.gerastert` das Bild eines
    /// Blocks mit derselben Zahl neu rechnet, mit der es gesendet wurde.
    func testDieKanteWirdGemerktUndOhneIconNicht() throws {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "a"), icon: "Sonne", iconKante: 16, fuer: uhr, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "b"), icon: nil, iconKante: 16, fuer: uhr, platz: 2)

        XCTAssertEqual(try XCTUnwrap(gedaechtnis.gemerkt(fuer: uhr, platz: 1)).iconKante, 16)
        XCTAssertNil(try XCTUnwrap(gedaechtnis.gemerkt(fuer: uhr, platz: 2)).iconKante,
                     "ohne Icon gibt es keine Kante zu merken")
    }

    /// Ein Stand aus einer Fassung vor dieser hat den Schluessel gar nicht —
    /// er muss lesbar bleiben und als 8 gelten. Ein Pflichtfeld wuerde hier
    /// `keyNotFound` werfen; gelesen wird mit `try?`, die Folge waere also ein
    /// leeres Gedaechtnis statt einer Meldung. Diese Datei kann zudem in einem
    /// iCloud-Behaelter liegen, den auch eine aeltere Fassung auf einem
    /// anderen Geraet liest.
    func testEinStandOhneKanteBleibtLesbarUndGiltAlsAcht() throws {
        let ordner = temp()
        let gedaechtnis = Slotgedaechtnis(ordner: ordner)
        let uhr = UUID()
        gedaechtnis.merken(Meldungsoptionen(text: "alt"), icon: "1673", iconKante: 8, fuer: uhr, platz: 1)

        // Den Schluessel aus der Datei nehmen, als haette ihn nie jemand
        // geschrieben — naeher an einer alten Datei als jede Nachbildung.
        let datei = ordner.appendingPathComponent("\(uhr.uuidString).json")
        let roh = try String(contentsOf: datei, encoding: .utf8)
        XCTAssertFalse(roh.contains("iconKante"), "8 ist die Vorgabe und gehoert nicht in die Datei")

        let stand = try XCTUnwrap(gedaechtnis.gemerkt(fuer: uhr, platz: 1))
        XCTAssertNil(stand.iconKante)
        XCTAssertEqual(stand.iconKanteOderAcht, 8)
    }

}
