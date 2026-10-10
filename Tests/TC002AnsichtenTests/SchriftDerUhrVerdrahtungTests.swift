import XCTest

/// Der Schalter „Schrift der Uhr" ist nur dann auf allen Oberflaechen derselbe,
/// wenn jede ihn an die gleichen Stellen haengt: gemerkt unter `senden.weg`,
/// in die Optionen der Sendung aufgenommen, beim Wiederherstellen eines
/// Platzes zurueckgesetzt, in der Vorschau beachtet. Eine Stelle, die ihn
/// vergisst, faellt erst am Geraet auf — der Schalter stuende dann an, und
/// gesendet wuerde ein Bild.
///
/// Geprueft am Quelltext, Kommentare weg (wie `ReglersperreTests`).
final class SchriftDerUhrVerdrahtungTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelltext(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile -> String in
                guard let strich = zeile.range(of: "//") else { return String(zeile) }
                return String(zeile[zeile.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    private let sendeansichten = ["Sources/TC002Ansichten/SendenView.swift",
                                  "Sources/TC002iOS/SendeniOS.swift"]

    func testBeideSendeansichtenMerkenDenWegUnterDemSchluesselDesKurzbefehls() throws {
        for pfad in sendeansichten {
            let q = try quelltext(pfad)
            XCTAssertTrue(q.contains(#"@AppStorage("senden.weg") private var weg: SendeWeg = .pixel"#),
                          "\(pfad): Der Schalter wird nicht unter „senden.weg“ gemerkt, Vorgabe aus")
        }
    }

    func testBeideSendeansichtenReichenDenWegInDieOptionen() throws {
        for pfad in sendeansichten {
            let q = try quelltext(pfad)
            XCTAssertTrue(q.contains("Meldungsoptionen(text: text, weg: weg,"),
                          "\(pfad): Der Schalter kommt nicht in `optionen` an — gesendet wuerde immer ein Bild")
        }
    }

    func testBeideSendeansichtenStellenDenWegMitDemPlatzWiederHer() throws {
        for pfad in sendeansichten {
            let q = try quelltext(pfad)
            XCTAssertTrue(q.contains("weg = o.weg"),
                          "\(pfad): `reglerUebernehmen` setzt den Schalter nicht zurueck")
        }
    }

    func testBeideSendeansichtenPruefenAusrichtungUndRaster() throws {
        for pfad in sendeansichten {
            let q = try quelltext(pfad)
            XCTAssertTrue(q.contains(".task(id: weg) { ausrichtungPruefen() }"),
                          "\(pfad): Beim Umschalten bliebe „rechtsbuendig“ stehen, das die Uhr nicht kennt")
            XCTAssertTrue(q.contains("weg.rawValue"),
                          "\(pfad): Die Laufschrift rechnet bei Wegwechsel nicht neu")
            XCTAssertTrue(q.contains("AwtrixNG.grossbuchstabenWirken(weg: weg"),
                          "\(pfad): „Großbuchstaben“ bliebe bei der Schrift der Uhr gesperrt")
        }
    }

    /// Mac und iPhone zeigen denselben Baustein, jede an ihrem Ort: der Mac im
    /// Reiter „Format“ des Inspektors, das iPhone im Formatblatt.
    func testDerSchalterStehtAufMacUndIPhone() throws {
        let mac = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(mac.contains("SchriftDerUhrSchalter(weg: $weg)"))
        let telefon = try quelltext("Sources/TC002iOS/FormatblattiOS.swift")
        XCTAssertTrue(telefon.contains("SchriftDerUhrSchalter(weg: $weg)"))
    }

    /// Die Fussnote sagt, was ausgegraut ist, und zwar nur, solange der
    /// Schalter an ist; der Satz steht einmal, im Kern.
    func testDieFussnoteStehtNurBeiEingeschaltetemSchalter() throws {
        for pfad in ["Sources/TC002Ansichten/SendenView.swift",
                     "Sources/TC002iOS/FormatblattiOS.swift"] {
            let q = try quelltext(pfad)
            XCTAssertTrue(q.contains("if weg.schriftDerUhr { Text(AwtrixNG.schriftDerUhrFussnote) }"), pfad)
        }
    }

    /// Die alten Saetze, die nur Kurzbefehl und Werkzeug als Weg zur
    /// Geraetschrift nannten, sind aus Hilfe und Fussnoten verschwunden.
    func testKeineFussnoteNenntNurKurzbefehlUndWerkzeug() throws {
        for pfad in ["Sources/TC002Ansichten/Darstellungsabschnitte.swift",
                     "Sources/TC002Ansichten/HilfeInhalt.swift"] {
            let q = try quelltext(pfad)
            XCTAssertFalse(q.contains("Gerätschrift (Kurzbefehl, Werkzeug)"), pfad)
            XCTAssertFalse(q.contains("so schickt ihn die App"), pfad)
        }
    }
}
