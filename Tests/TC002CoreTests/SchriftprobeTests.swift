import XCTest
@testable import TC002Core

/// Die Versuchsreihe: fuer jede mitgelieferte Schrift und jede Groesse, die der
/// Schieber zulaesst, was dagegen spricht.
///
/// Der Schnappschuss haelt fest, **was heute gilt** — und ist damit zugleich
/// der Waechter: Aendert sich eine Schriftdatei oder die Rasterung, faellt es
/// hier auf, nicht erst am Geraet.
final class SchriftprobeTests: XCTestCase {
    /// Was der Schieber in `SendenView` zulaesst: `Stepper(… in: 6...16)`, ein
    /// Pixel Schrittweite. Silkscreen ist dort zusaetzlich auf 8 und 16
    /// eingeengt (`sauberePixelgroessen`) — hier trotzdem durchgehend gemessen,
    /// denn genau diese Einengung soll die Messung beantworten.
    static let groessen = Array(stride(from: 6.0, through: 16.0, by: 1.0))

    override func setUp() {
        super.setUp()
        Schriftbuendel.anmelden()
    }

    /// Ohne die mitgelieferten Schriften misst CoreText klaglos eine
    /// Ersatzschrift — die ganze Tabelle waere dann etwas anderes als
    /// behauptet. Deshalb zuerst diese Frage.
    func testDieMitgeliefertenSchriftenSindDa() {
        for schrift in Schriftbuendel.schriften {
            XCTAssertTrue(Schriftbuendel.vorhanden(schrift), "Schrift „\(schrift)“ fehlt")
        }
    }

    func testTabelleFuerAlleSchriftenUndGroessen() throws {
        var zeilen: [String] = [
            "# Ausschlussgruende je Schrift und Groesse",
            "#",
            "# Erzeugt von SchriftprobeTests.testTabelleFuerAlleSchriftenUndGroessen.",
            "# Leer heisst „nicht ausgeschlossen“, nicht „brauchbar“ — darueber",
            "# urteilt nur ein Augenpaar (erzeugt/schriftprobe.html).",
            "",
        ]
        for schrift in Schriftbuendel.schriften {
            for groesse in Self.groessen {
                let gruende = Schriftprobe.ausschlussgruende(schrift: schrift, groesse: groesse)
                zeilen.append("\(schrift) \(Int(groesse)) px")
                if gruende.isEmpty {
                    zeilen.append("  nicht ausgeschlossen")
                } else {
                    zeilen.append(contentsOf: gruende.map { "  " + $0.beschreibung })
                }
            }
        }
        try vergleiche(zeilen.joined(separator: "\n") + "\n", mit: "schriftprobe.txt")
    }

    // MARK: - Dass die Pruefung ueberhaupt etwas prueft

    /// Der wichtigste Fall: Bei fuenf Pixeln verliert Micro 5 seine Umlaute —
    /// „Grüße“ waere dort „Gruse“. Und zwar als **eigener**, schwerer wiegender
    /// Grund, nicht in der allgemeinen Liste untergegangen.
    func testUmlautverlustWirdEigensGemeldet() {
        let gruende = Schriftprobe.ausschlussgruende(schrift: "Micro 5", groesse: 5)
        guard case .umlautVerloren(let paare)? = gruende.first else {
            return XCTFail("Umlautverlust muss zuerst stehen, gefunden: \(gruende)")
        }
        XCTAssertTrue(paare.contains(Schriftprobe.Zeichenpaar("ä", "a")), "„ä“ fällt bei 5 px mit „a“ zusammen")
        XCTAssertTrue(paare.contains(Schriftprobe.Zeichenpaar("Ö", "O")))
    }

    /// Und die Gegenprobe: In den Groessen, die der Schieber anbietet, ist
    /// **kein** Umlaut seines Grundbuchstabens verlustig gegangen. Faellt das
    /// eines Tages, ist es das Erste, was man wissen will.
    func testInDenAngebotenenGroessenBleibenDieUmlauteErhalten() {
        for schrift in Schriftbuendel.schriften {
            for groesse in Self.groessen {
                for grund in Schriftprobe.ausschlussgruende(schrift: schrift, groesse: groesse) {
                    if case .umlautVerloren(let paare) = grund {
                        XCTFail("\(schrift) \(Int(groesse)) px verliert \(paare)")
                    }
                }
            }
        }
    }

    /// Ein Zeichen ohne einen einzigen gesetzten Pixel fehlt ersatzlos. Micro 5
    /// bei drei Pixeln zeigt sechs Zeichen des Vorrats gar nicht.
    func testUnsichtbareZeichenWerdenGenannt() {
        let gruende = Schriftprobe.ausschlussgruende(schrift: "Micro 5", groesse: 3)
        let unsichtbare = gruende.compactMap { grund -> [Character]? in
            if case .unsichtbar(let z) = grund { return z }
            return nil
        }.first
        XCTAssertEqual(unsichtbare, ["4", "F", "L", "P", "f", "r"])
    }

    /// Der Ausschnitt ist sechzehn Zeilen hoch — was darunter liegt, ist weg.
    /// Micro 5 bei 16 Pixeln verliert die unterste Zeile des „ß“.
    func testAbgeschnitteneTinteWirdGemeldet() {
        let gruende = Schriftprobe.ausschlussgruende(schrift: "Micro 5", groesse: 16)
        XCTAssertTrue(gruende.contains(.zuHoch(text: Schriftprobe.musterwort, obenFehlt: 0, untenFehlt: 1)),
                      "gefunden: \(gruende)")
        // Und in den Groessen darunter passt es — sonst pruefte das nichts.
        XCTAssertFalse(Schriftprobe.ausschlussgruende(schrift: "Micro 5", groesse: 12).contains {
            if case .zuHoch = $0 { return true }
            return false
        })
    }

    /// Abstand 0 laesst die Zeichen aneinanderstossen, Abstand 1 trennt sie —
    /// genau das ist die Zusage von `Textraster.rasterPuffer`. Bricht sie, steht
    /// es hier.
    func testOhneAbstandLaufenDieZeichenZusammen() {
        func gelaufen(_ abstand: Int) -> [Schriftprobe.Zeichenpaar] {
            Schriftprobe.ausschlussgruende(schrift: "Tiny5", groesse: 8, abstand: abstand)
                .compactMap { if case .zusammengelaufen(let p) = $0 { return p } else { return nil } }
                .first ?? []
        }
        XCTAssertEqual(gelaufen(0).count, Schriftprobe.musterwort.count - 1,
                       "ohne Abstand trennt keine einzige Spalte")
        XCTAssertTrue(gelaufen(1).isEmpty, "eine Spalte Abstand muss reichen")
    }

    /// Der Vorrat ist der, den die App schickt — nicht einer, der beim
    /// Schreiben dieses Tests hübsch aussah.
    func testVorratEnthaeltUmlauteZiffernUndDieVierSatzzeichen() {
        let vorrat = Set(Schriftprobe.vorrat)
        XCTAssertEqual(vorrat.count, Schriftprobe.vorrat.count, "kein Zeichen doppelt")
        for zeichen in "äöüÄÖÜß0123456789%.-:aAzZ" {
            XCTAssertTrue(vorrat.contains(zeichen), "„\(zeichen)“ fehlt im Vorrat")
        }
        XCTAssertFalse(vorrat.contains(" "), "das Leerzeichen hat keine Tinte und gehört nicht hinein")
    }

    // MARK: - Schnappschuss

    private var ordner: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Schnappschuesse")
    }

    /// Wie in `MeldungsbauTests`: Fehlt die abgelegte Fassung, wird sie
    /// geschrieben und der Test schlaegt einmal fehl — damit niemand einen
    /// Schnappschuss einfuehrt, ohne ihn angesehen zu haben.
    private func vergleiche(_ text: String, mit name: String,
                            datei: StaticString = #filePath, zeile: UInt = #line) throws {
        let pfad = ordner.appendingPathComponent(name)
        guard let erwartet = try? String(contentsOf: pfad, encoding: .utf8) else {
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try text.write(to: pfad, atomically: true, encoding: .utf8)
            XCTFail("Schnappschuss \(name) neu angelegt — bitte ansehen und einchecken.",
                    file: datei, line: zeile)
            return
        }
        XCTAssertEqual(text, erwartet, "Schnappschuss \(name) weicht ab", file: datei, line: zeile)
    }
}
