import XCTest
@testable import TC002Core

/// Was zwei Geraete miteinander aus ihrer Einrichtung machen. Reine Rechnung —
/// kein Netz, keine Wolke, keine Ablage.
final class EinrichtungsstandTests: XCTestCase {

    private func uhr(_ name: String, _ host: String, id: UUID = UUID(),
                     betriebsart: Betriebsart? = nil) -> Uhr {
        Uhr(id: id, name: name, host: host, betriebsart: betriebsart)
    }

    // MARK: Uhren

    // MARK: Dieselbe Uhr auf zwei Geraeten

    /// **Der Fehler vom 14.09.2026, als Zusicherung.** Dieselbe Uhr, auf zwei
    /// Geraeten eingetragen, hat zwei Kennungen — sie entstehen beim Anlegen.
    /// Zusammengefuehrt wurde ueber genau diese Kennung, also hielt der
    /// Abgleich sie fuer zwei Uhren und hing sie aneinander. Nach zwanzig
    /// Minuten standen drei Eintraege derselben Uhr in der Liste, und
    /// „Entfernen" half nicht: Beim naechsten Abgleich kamen sie zurueck.
    func testDieselbeAdresseAufZweiGeraetenIstEineUhr() {
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [uhr("Küche", "10.0.0.1")]),
            fern: Einrichtungsstand(uhren: [uhr("Küche", "10.0.0.1")]))
        XCTAssertEqual(ergebnis.uhren.count, 1,
                       "zwei Eintraege derselben Adresse sind eine Uhr, keine zwei")
    }

    /// Und dieselbe MAC, auch wenn die Adresse inzwischen eine andere ist —
    /// die MAC ist das Bestaendigere von beidem.
    func testDieselbeMacIstEineUhr() {
        var hier = uhr("Küche", "10.0.0.1"); hier.mac = "AA:BB:CC:DD:A8:6B"
        var dort = uhr("Küche", "10.0.0.77"); dort.mac = "aabbccdda86b"
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [hier]),
            fern: Einrichtungsstand(uhren: [dort]))
        XCTAssertEqual(ergebnis.uhren.count, 1, "Schreibweise und Adresse duerfen nichts daran aendern")
        XCTAssertEqual(ergebnis.uhren.first?.host, "10.0.0.77", "die Wolke gewinnt bei den Feldern")
    }

    /// **Ueber Ecken.** A und B teilen die Adresse, B und C die MAC — dann
    /// gehoeren alle drei zusammen, obwohl A und C nichts unmittelbar
    /// gemeinsam haben. Ein Woerterbuch ueber einen einzigen Schluessel kaeme
    /// hier auf zwei Uhren.
    func testUeberEckenZusammengefuehrt() {
        let a = uhr("A", "10.0.0.1")
        var b = uhr("B", "10.0.0.1"); b.mac = "aabbccddeeff"
        var c = uhr("C", "10.0.0.2"); c.mac = "AABBCCDDEEFF"
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [a]),
            fern: Einrichtungsstand(uhren: [b, c]))
        XCTAssertEqual(ergebnis.uhren.count, 1)
    }

    /// Die Heilung des Bestands: Drei Eintraege derselben Uhr — der Zustand,
    /// in dem die Liste am Morgen des 14.09. war — fallen beim naechsten
    /// Abgleich zu einem zusammen, ohne dass jemand etwas von Hand loeschen
    /// muss.
    func testDreiEintraegeDerselbenUhrFallenZusammen() {
        let drei = [uhr("awtrix_a86b", "10.0.0.1"),
                    uhr("awtrix_a86b", "10.0.0.1"),
                    uhr("awtrix_a86b", "10.0.0.1")]
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: drei),
            fern: Einrichtungsstand(uhren: []))
        XCTAssertEqual(ergebnis.uhren.count, 1)
    }

    /// **Beide Geraete muessen auf dieselbe Kennung kommen**, sonst schriebe
    /// jedes seine eigene in die Wolke und sie wechselten einander ab — ein
    /// Abgleich, der nie zur Ruhe kaeme. Deshalb gewinnt die kleinere, eine
    /// Regel ohne Absprache.
    func testBeideSeitenWaehlenDieselbeKennung() {
        let eine = uhr("Küche", "10.0.0.1"), andere = uhr("Küche", "10.0.0.1")
        let so = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [eine]), fern: Einrichtungsstand(uhren: [andere]))
        let andersherum = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [andere]), fern: Einrichtungsstand(uhren: [eine]))
        XCTAssertEqual(so.uhren.first?.id, andersherum.uhren.first?.id)
        XCTAssertEqual(so.uhren.first?.id, min(eine.id.uuidString, andere.id.uuidString) == eine.id.uuidString ? eine.id : andere.id)
    }

    /// Faellt eine Kennung weg, muss die Buchfuehrung mitwandern — sonst
    /// haengen die bekannten Anzeigen an einer Uhr, die es nicht mehr gibt,
    /// und die fuenf Bloecke waeren leer.
    func testBekannteAnzeigenWandernAufDieBleibendeKennung() {
        let hier = uhr("Küche", "10.0.0.1"), dort = uhr("Küche", "10.0.0.1")
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [hier],
                                        bekannteAnzeigen: [hier.id.uuidString: ["meldung1"]]),
            fern: Einrichtungsstand(uhren: [dort],
                                    bekannteAnzeigen: [dort.id.uuidString: ["meldung2"]]))
        let bleibt = try? XCTUnwrap(ergebnis.uhren.first?.id.uuidString)
        XCTAssertEqual(ergebnis.bekannteAnzeigen.count, 1, "zwei Buchfuehrungen fuer eine Uhr")
        XCTAssertEqual(ergebnis.bekannteAnzeigen[bleibt ?? ""].map(Set.init), Set(["meldung1", "meldung2"]),
                       "und beide Namen muessen ueberleben")
    }

    /// Dasselbe fuer die Auswahl: Eine Zieluhr aus der Wolke, deren Kennung
    /// zusammengefallen ist, darf nicht herausfallen — sonst gaelte
    /// stillschweigend „alle Uhren".
    func testDieAuswahlWandertMit() {
        let hier = uhr("Küche", "10.0.0.1"), dort = uhr("Küche", "10.0.0.1")
        let extra = uhr("Bad", "10.0.0.2")
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [hier, extra]),
            fern: Einrichtungsstand(uhren: [dort, extra], zielIDs: [dort.id]))
        XCTAssertEqual(ergebnis.zielIDs.count, 1, "war: \(ergebnis.zielIDs)")
        XCTAssertEqual(ergebnis.zielIDs.first, ergebnis.uhren.first?.id)
    }


    /// Der Fall, um dessentwillen ueberhaupt zusammengefuehrt wird: Am Mac
    /// kommt eine Uhr dazu, am Telefon wird eine andere umgestellt. „Letzter
    /// gewinnt" verloere eine der beiden Aenderungen wortlos.
    func testBeideAenderungenUeberleben() {
        let alt = uhr("Küche", "10.0.0.1", betriebsart: .mqtt)
        let neu = uhr("Bad", "10.0.0.2")
        let oertlich = Einrichtungsstand(uhren: [alt, neu])
        var umgestellt = alt
        umgestellt.betriebsart = .http
        let fern = Einrichtungsstand(uhren: [umgestellt])

        let ergebnis = Einrichtungsstand.zusammengefuehrt(oertlich: oertlich, fern: fern)
        XCTAssertEqual(ergebnis.uhren.count, 2)
        XCTAssertEqual(ergebnis.uhren.first(where: { $0.id == alt.id })?.wirksameBetriebsart, .http,
                       "die Aenderung aus der Wolke gilt")
        XCTAssertNotNil(ergebnis.uhren.first(where: { $0.id == neu.id }),
                        "die eben eingetragene Uhr bleibt")
    }

    /// Eine Uhr, die nur die Wolke kennt, kommt dazu — hinten, damit der
    /// eigene Bestand seine Reihenfolge behaelt.
    func testFremdeUhrKommtHintenDazu() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2"), c = uhr("Flur", "10.0.0.3")
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [a, b]),
            fern: Einrichtungsstand(uhren: [c]))
        XCTAssertEqual(ergebnis.uhren.map(\.name), ["Küche", "Bad", "Flur"])
    }

    /// Der Widerspruch, der bleibt: Aendern beide dieselbe Uhr, gewinnt die
    /// Wolke. Eine Konfliktkopie waere eine zweite Uhr mit derselben Adresse.
    func testBeiDerselbenUhrGewinntDieWolke() {
        let id = UUID()
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [uhr("hier", "10.0.0.1", id: id)]),
            fern: Einrichtungsstand(uhren: [uhr("dort", "10.0.0.9", id: id)]))
        XCTAssertEqual(ergebnis.uhren.count, 1)
        XCTAssertEqual(ergebnis.uhren.first?.name, "dort")
        XCTAssertEqual(ergebnis.uhren.first?.host, "10.0.0.9")
    }

    // MARK: Auswahl

    func testAuswahlKommtAusDerWolke() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [a, b], zielIDs: [a.id]),
            fern: Einrichtungsstand(uhren: [a, b], zielIDs: [b.id]))
        XCTAssertEqual(ergebnis.zielIDs, [b.id])
    }

    /// Eine Auswahl, die nur auf Uhren zeigt, die es hier nicht gibt, darf
    /// nicht als Auswahl stehenbleiben — sonst traefe „Senden" gar nichts.
    /// Leer heisst alle, dieselbe Lesart wie in `AppZustand.init`.
    func testVerwaisteAuswahlWirdZuAllen() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(uhren: [a, b], zielIDs: [a.id]),
            fern: Einrichtungsstand(uhren: [], zielIDs: [UUID()]))
        XCTAssertEqual(Set(ergebnis.zielIDs), [a.id, b.id])
    }

    // MARK: Broker

    /// Ein Geraet, auf dem nie ein Broker eingetragen wurde, darf dem anderen
    /// seinen nicht wegraeumen.
    func testEinLeererBrokerLoeschtNichts() {
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(brokerHost: "10.0.0.20", brokerPort: "1883", benutzer: "pix"),
            fern: Einrichtungsstand(brokerHost: "", brokerPort: "", benutzer: ""))
        XCTAssertEqual(ergebnis.brokerHost, "10.0.0.20")
        XCTAssertEqual(ergebnis.brokerPort, "1883")
        XCTAssertEqual(ergebnis.benutzer, "pix")
    }

    func testEinGefuellterBrokerAusDerWolkeGewinnt() {
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(brokerHost: "10.0.0.20", brokerPort: "1883", benutzer: "alt"),
            fern: Einrichtungsstand(brokerHost: "10.0.0.30", brokerPort: "8883", benutzer: "neu"))
        XCTAssertEqual(ergebnis.brokerHost, "10.0.0.30")
        XCTAssertEqual(ergebnis.brokerPort, "8883")
        XCTAssertEqual(ergebnis.benutzer, "neu")
    }

    // MARK: Bekannte Anzeigen

    /// Faellt ein Name aus dieser Buchfuehrung, bleibt die Anzeige auf der Uhr
    /// stehen, ohne dass es noch einen Weg gaebe, sie zu loeschen. Also
    /// vereinigen, nicht ersetzen.
    func testBekannteAnzeigenWerdenVereinigt() {
        let id = UUID().uuidString
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(bekannteAnzeigen: [id: ["meldung1", "meldung2"]]),
            fern: Einrichtungsstand(bekannteAnzeigen: [id: ["meldung2", "meldung5"]]))
        XCTAssertEqual(ergebnis.bekannteAnzeigen[id], ["meldung1", "meldung2", "meldung5"])
    }

    func testAnzeigenEinerNurDortBekanntenUhrKommenDazu() {
        let hier = UUID().uuidString, dort = UUID().uuidString
        let ergebnis = Einrichtungsstand.zusammengefuehrt(
            oertlich: Einrichtungsstand(bekannteAnzeigen: [hier: ["a"]]),
            fern: Einrichtungsstand(bekannteAnzeigen: [dort: ["b"]]))
        XCTAssertEqual(ergebnis.bekannteAnzeigen[hier], ["a"])
        XCTAssertEqual(ergebnis.bekannteAnzeigen[dort], ["b"])
    }

    // MARK: Das Mass

    /// `NSUbiquitousKeyValueStore` traegt 1 MB. Eine reichlich bemessene
    /// Einrichtung — zwanzig Uhren mit je vierzig gemerkten Anzeigennamen —
    /// bleibt weit darunter.
    func testEineGrosszuegigeEinrichtungPasstBequem() throws {
        var uhren: [Uhr] = []
        var anzeigen: [String: [String]] = [:]
        for i in 0..<20 {
            let u = uhr("Uhr mit einem langen Namen \(i)", "192.168.178.\(i)")
            uhren.append(u)
            anzeigen[u.id.uuidString] = (0..<40).map { "meldung-mit-langem-namen-\($0)" }
        }
        let stand = Einrichtungsstand(uhren: uhren, zielIDs: uhren.map(\.id),
                                      brokerHost: "192.168.178.20", brokerPort: "1883",
                                      benutzer: "pixdeck", bekannteAnzeigen: anzeigen)
        let daten = try XCTUnwrap(stand.alsDaten)
        XCTAssertTrue(stand.passtInDieWolke)
        XCTAssertLessThan(daten.count, Einrichtungsstand.hoechstmass / 8,
                          "\(daten.count) Bytes — noch nicht einmal ein Achtel der Grenze")
    }

    /// Und die Grenze gilt wirklich: Was nicht hineinpasst, sagt das auch.
    func testWasNichtHineinpasstSagtEs() {
        let riesig = Einrichtungsstand(bekannteAnzeigen:
            [UUID().uuidString: (0..<200_000).map { "anzeige-\($0)" }])
        XCTAssertFalse(riesig.passtInDieWolke)
    }

    /// Die abgelegte Form ist ein Dateiformat wie die von `Uhr`: Ein Geraet
    /// mit einer aelteren Fassung liest, was ein neueres geschrieben hat.
    /// Feldnamen aendern macht den Abgleich zwischen zwei Fassungen stumm.
    func testDieAbgelegteFormBleibtLesbar() throws {
        let json = """
        {"uhren":[],"zielIDs":[],"brokerHost":"10.0.0.20","brokerPort":"1883",\
        "benutzer":"pixdeck","bekannteAnzeigen":{"A":["meldung1"]}}
        """
        let stand = try JSONDecoder().decode(Einrichtungsstand.self, from: Data(json.utf8))
        XCTAssertEqual(stand.brokerHost, "10.0.0.20")
        XCTAssertEqual(stand.brokerPort, "1883")
        XCTAssertEqual(stand.benutzer, "pixdeck")
        XCTAssertEqual(stand.bekannteAnzeigen["A"], ["meldung1"])
    }
}
