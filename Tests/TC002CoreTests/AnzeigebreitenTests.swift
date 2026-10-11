import XCTest
@testable import TC002Core

private final class BreitenMitschreiber: NachrichtSendend {
    var gesendet: [(thema: String, nutzlast: Data)] = []
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        gesendet.append((thema, nutzlast))
    }
}

/// Die selbstgebaute ESP32-Uhr hat 32 bis 128 Spalten bei 8 Zeilen
/// (`capabilities.display`: `minWidth` 32, `maxWidth` 128). Die Rasterung, der
/// Pixelweg und die Prüfung gegen das Anzeigemaß müssen für jede dieser Breiten
/// gelten, nicht nur für 32 und 52.
final class AnzeigebreitenTests: XCTestCase {
    private let breiten = [64, 128]
    /// Länger als die Anzeige, damit etwas läuft, aber kurz genug für das
    /// Limit von 56 KiB: Je breiter die Anzeige, desto mehr Bilder braucht ein
    /// Durchlauf und desto größer wird das GIF. Die Schriften werden bewusst nicht
    /// angemeldet (wie in `PixelwegTests`): Eine angemeldete Schrift ändert die
    /// Maße für alle Tests danach im selben Prozess; die Grenzen hier halten
    /// mit und ohne.
    private static func text(fuer breite: Int) -> String {
        String("Grüße aus Wien, hier läuft ein recht langer Text über die ganze Anzeige".prefix(breite == 64 ? 60 : 40))
    }

    private func sammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: FileManager.default.temporaryDirectory
            .appendingPathComponent("breiten-" + UUID().uuidString))
    }

    private func gifBilder(_ json: String, breite: Int) throws -> [Bildraster.Einzelbild] {
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let uri = try XCTUnwrap(o["icon"] as? String)
        let daten = try XCTUnwrap(Data(base64Encoded: String(uri.dropFirst("data:image/gif;base64,".count))))
        XCTAssertLessThanOrEqual(daten.count, Pixelweg.hoechsteGIFBytes)
        return try Bildraster.lesenMitZeiten(daten, breite: breite, hoehe: 8)
    }

    // MARK: - Rastern

    func testStandbildHatDasMassDerAnzeigeUndPasstInEineMQTTNachricht() throws {
        for breite in breiten {
            let mass = Anzeigemass(breite: breite, hoehe: 8)
            let o = Meldungsoptionen(text: "Grüß", weg: .pixel, schrift: "Silkscreen", groesse: 8)
            let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung(), mass: mass)
            let pixel = try XCTUnwrap(rahmen.pixel)
            XCTAssertEqual(pixel.breite, breite)
            XCTAssertEqual(pixel.hoehe, 8)
            XCTAssertEqual(pixel.bilder.count, 1)
            XCTAssertEqual(pixel.bilder[0].pixel.count, breite * 8)
            XCTAssertTrue(pixel.bilder[0].pixel.contains { $0 != nil }, "der Text ist zu sehen")
            let json = try Anzeigen.nutzlast(rahmen, mass: mass)
            print("MESSUNG Standbild „Grüß“ \(breite)x8: \(json.utf8.count) Byte")
            XCTAssertLessThan(json.utf8.count, Pixelweg.mqttGrenze - 100)
            let bilder = try gifBilder(json, breite: breite)
            XCTAssertEqual(bilder.count, 1)
            XCTAssertEqual(bilder[0].pixel.map { $0 == "#000000" ? nil : $0 }, pixel.bilder[0].pixel, "pixelgenau")
        }
    }

    func testLaufschriftBilderHabenDasMassDerAnzeigeUndDasGIFBleibtImLimit() throws {
        for breite in breiten {
            let mass = Anzeigemass(breite: breite, hoehe: 8)
            let o = Meldungsoptionen(text: Self.text(fuer: breite), schrift: "Silkscreen", groesse: 8, tempo: .mittel)
            let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung(), mass: mass)
            let pixel = try XCTUnwrap(rahmen.pixel)
            XCTAssertTrue(pixel.istBewegt)
            XCTAssertLessThanOrEqual(pixel.bilder.count, Pixelweg.hoechsteBildzahl)
            XCTAssertTrue(pixel.bilder.allSatisfy { $0.pixel.count == breite * 8 })
            let json = try Anzeigen.nutzlast(rahmen, mass: mass)
            print("MESSUNG Laufschrift „Grüße aus Wien“ \(breite)x8: \(pixel.bilder.count) Bilder, \(json.utf8.count) Byte")
        }
    }

    /// Ein sehr langer Text auf einer breiten Anzeige braucht mehr Bilder, als
    /// die App je Anzeige schickt; sie meldet das vor dem Senden mit einem
    /// verständlichen Satz (früher: „nichtLesbar“).
    func testZuLangeLaufschriftAufBreiterAnzeigeWirdVorDemSendenGemeldet() throws {
        let mass = Anzeigemass(breite: 128, hoehe: 8)
        let o = Meldungsoptionen(text: String(repeating: "Grüße aus Wien, ", count: 8),
                                 schrift: "Silkscreen", groesse: 8, tempo: .mittel)
        XCTAssertThrowsError(try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung(), mass: mass)) { fehler in
            guard case NGFehler.laufschriftZuVieleBilder = fehler else { return XCTFail("war \(fehler)") }
            XCTAssertFalse((fehler as? LocalizedError)?.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - Zustellweg

    func testGrosseNutzlastGehtUeberHTTPDieselbeUhr() throws {
        // Über 8192 Byte samt Thema verwirft die Uhr die MQTT-Nachricht ohne Antwort.
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: 8000, themaBytes: 60, betriebsart: .mqtt), .mqtt)
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: 8150, themaBytes: 60, betriebsart: .mqtt), .http)
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: 20_000, themaBytes: 0, betriebsart: .http), .http)
        for breite in breiten {
            let mass = Anzeigemass(breite: breite, hoehe: 8)
            let o = Meldungsoptionen(text: Self.text(fuer: breite), schrift: "Silkscreen",
                                     groesse: 8, tempo: .mittel)
            let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung(), mass: mass)
            let sender = BreitenMitschreiber()
            let anzeigen = Anzeigen(sender: sender,
                                    zugang: MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p"),
                                    praefix: "bastel/uhr", anzeigemass: mass)
            let groesse = try Anzeigen.nutzlast(rahmen, mass: mass).utf8.count
            if groesse + "bastel/uhr/cmd/apps/pushed/meldung1".utf8.count > Pixelweg.mqttGrenze {
                // Ohne Adresse meldet die App es vor dem Senden.
                XCTAssertThrowsError(try anzeigen.zeigen(rahmen, auf: "meldung1")) { fehler in
                    guard case NGFehler.keineAdresseFuerGrosse = fehler else { return XCTFail("war \(fehler)") }
                }
                XCTAssertTrue(sender.gesendet.isEmpty)
            } else {
                XCTAssertEqual(try anzeigen.zeigen(rahmen, auf: "meldung1"), .mqtt)
            }
        }
    }

    // MARK: - Maß der Zieluhr

    func testEinFertigesBildInFalschemMassWirdFuerDieseUhrAbgewiesen() throws {
        let sender = BreitenMitschreiber()
        let anzeigen = Anzeigen(sender: sender,
                                zugang: MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p"),
                                praefix: "bastel/uhr", anzeigemass: Anzeigemass(breite: 64, hoehe: 8))
        let falsch = Frame(pixel: Pixelinhalt(breite: 32, hoehe: 8, bilder: [
            Bildraster.Einzelbild(pixel: [String?](repeating: nil, count: 32 * 8), dauer: 1)]))
        XCTAssertThrowsError(try anzeigen.zeigen(falsch, auf: "meldung1")) { fehler in
            guard case NGFehler.massPasstNicht(let b, let h, let ab, let ah) = fehler else {
                return XCTFail("war \(fehler)")
            }
            XCTAssertEqual([b, h, ab, ah], [32, 8, 64, 8])
        }
        let passt = Frame(pixel: Pixelinhalt(breite: 64, hoehe: 8, bilder: [
            Bildraster.Einzelbild(pixel: [String?](repeating: nil, count: 64 * 8), dauer: 1)]))
        XCTAssertNoThrow(try anzeigen.zeigen(passt, auf: "meldung1"))
    }

    func testAnzeigemassFolgtDerGemeldetenBreite() {
        for breite in [32, 64, 96, 128] {
            let uhr = Uhr(name: "x", host: "h", panelbreite: breite, panelhoehe: 8, modell: .esp32DIY)
            XCTAssertEqual(Anzeigemass.fuer(uhr), Anzeigemass(breite: breite, hoehe: 8))
        }
        // Über der Grenze der Uhr (`maxWidth` 128) gilt die Vorgabe.
        XCTAssertEqual(Anzeigemass.fuer(Uhr(name: "x", host: "h", panelbreite: 192, panelhoehe: 8)), .vorgabe)
    }

    // MARK: - Der ganze Weg über die virtuelle Uhr

    private func serverStarten(breite: Int) throws -> (Uhrenserver, UInt16) {
        var zustand = NGUhrzustand()
        zustand.anzeigebreite = breite
        zustand.anzeigehoehe = 8
        // Der Satz der ESP32-Uhr: keine Vergrößerung der Anzeige, kein Layout.
        zustand.ton.faehigkeiten = NGTon.tc001
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: zustand)
            do {
                try s.starten()
                Thread.sleep(forTimeInterval: 0.05)
                return (s, port)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    func testStandbildKommtBeiJederBreitePixelgenauAn() throws {
        for breite in breiten {
            let (server, port) = try serverStarten(breite: breite)
            defer { server.beenden() }
            let geraet = Geraet(host: "127.0.0.1:\(port)")

            // Die Uhr meldet ihre Größe; die App übernimmt sie in `Uhr.anzeigemass`.
            let mass = try XCTUnwrap(try geraet.anzeigemass())
            XCTAssertEqual(mass.breite, breite)
            XCTAssertEqual(mass.hoehe, 8)
            let uhr = Uhr(name: "x", host: "h", panelbreite: mass.breite, panelhoehe: mass.hoehe)

            var p = [String?](repeating: nil, count: breite * 8)
            p[0] = "#FF0000"; p[breite * 8 - 1] = "#0000FF"; p[40 + breite * 3] = "#00FF00"
            let rahmen = Frame(pixel: Pixelinhalt(breite: breite, hoehe: 8,
                                                  bilder: [Bildraster.Einzelbild(pixel: p, dauer: 1)]))
            let anzeigen = Anzeigen(geraet: geraet, anzeigemass: Anzeigemass.fuer(uhr))
            try anzeigen.zeigen(rahmen, auf: "meldung1")
            try anzeigen.umschalten(auf: "meldung1")

            var auszug: Bildschirmauszug?
            for _ in 0..<50 {
                auszug = try? geraet.bildschirm()
                if auszug?.pixel.contains(0xFF0000) == true { break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            let bild = try XCTUnwrap(auszug)
            XCTAssertEqual(bild.breite, breite)
            XCTAssertEqual(bild.hoehe, 8)
            XCTAssertEqual(bild.farbe(x: 0, y: 0), 0xFF0000)
            XCTAssertEqual(bild.farbe(x: breite - 1, y: 7), 0x0000FF)
            XCTAssertEqual(bild.farbe(x: 40, y: 3), 0x00FF00)
            XCTAssertEqual(bild.pixel.filter { $0 != 0 }.count, 3)
        }
    }
}
