import XCTest
@testable import TC002Core

/// Hält den Kern an die verbindliche Funktionsliste je Uhr (`docs/funktionen-je-uhr.md`,
/// englisch `docs/en/features-per-clock.md`). Tabelle und Test gehören
/// zusammen: Wer eine Zeile der Tabelle ändert, ändert hier die Erwartung, und
/// umgekehrt. Geprüft werden nur die Zeilen, die der Kern aus den Fähigkeiten
/// der Uhr entscheidet; was die Oberfläche daraus macht, steht in der Tabelle
/// unter „Abweichungen“.
///
/// Die Auskünfte sind die gemessenen (10. Oktober 2026, NG 1.2.2).
final class FunktionslisteTests: XCTestCase {
    private static let tc002Antwort = """
    {"effects":["Fade"],"platform":{"id":"tc002"},"sensors":{"light":false},
     "display":{"width":52,"height":16,"maxPixels":832},"layout":true,"mqttTls":true,
     "clockFaces":["sheet","ring","flap","month","big"],
     "audio":{"mp3":true,"rtttl":true,"song":true,"speech":true,"track":false,
              "radio":true,"url":true,"effect":true,"clip":true}}
    """

    private static let tc001Antwort = """
    {"effects":["Fade"],"platform":{"id":"esp32"},"sensors":{"light":true},
     "microphone":false,"scriptUpdates":true,
     "display":{"width":32,"height":8,"configurable":true,"minWidth":32,"maxWidth":128,"minHeight":8,"maxHeight":8},
     "audio":{"mp3":false,"rtttl":true,"song":false,"speech":false,"track":false,
              "radio":false,"url":false,"effect":false,"clip":false}}
    """

    private static func lesen(_ text: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    private func faehigkeiten(_ text: String) throws -> Geraetefaehigkeiten {
        try XCTUnwrap(Geraetefaehigkeiten(antwort: Self.lesen(text)))
    }

    private func mass(_ text: String) throws -> Anzeigemass {
        let anzeige = try XCTUnwrap(Self.lesen(text)["display"] as? [String: Any])
        let m = try XCTUnwrap(AwtrixNG.plausiblesMass(breite: anzeige["width"] as! Int,
                                                     hoehe: anzeige["height"] as! Int,
                                                     maxPixel: anzeige["maxPixels"] as? Int))
        return Anzeigemass.fuer(Uhr(name: "x", host: "h", panelbreite: m.breite, panelhoehe: m.hoehe))
    }

    /// Eine Zeile der Tabelle: die Antwort für TC002 und TC001.
    private struct Zeile {
        let name: String
        let tc002: Bool
        let tc001: Bool
        let wert: (Geraetefaehigkeiten) -> Bool
    }

    private let zeilen: [Zeile] = [
        // Klang, Tabelle „Klang“: Klangart → audio.<Schalter>
        Zeile(name: "Melodie (audio.rtttl)", tc002: true, tc001: true) { $0.kann(.melodie) },
        Zeile(name: "RTTTL-Text (audio.rtttl)", tc002: true, tc001: true) { $0.kann(.rtttl) },
        Zeile(name: "MP3 spielen (audio.mp3)", tc002: true, tc001: false) { $0.kann(.mp3) },
        Zeile(name: "MP3 hochladen", tc002: true, tc001: false) { Klangeignung.mp3Hochladbar($0) },
        Zeile(name: "Lied (audio.song)", tc002: true, tc001: false) { $0.kann(.lied) },
        Zeile(name: "Vorlesen (audio.speech)", tc002: true, tc001: false) { $0.kann(.sprache) },
        Zeile(name: "Radio (audio.radio)", tc002: true, tc001: false) { $0.kann(.radio) },
        Zeile(name: "MP3 von Adresse (audio.url)", tc002: true, tc001: false) { $0.kann(.adresse) },
        Zeile(name: "audio.clip", tc002: true, tc001: false) { $0.ton?.clip == true },
        Zeile(name: "audio.effect", tc002: true, tc001: false) { $0.ton?.effect == true },
        Zeile(name: "audio.track", tc002: false, tc001: false) { $0.ton?.track == true },
        // Die Wahl der Oberfläche „Von der Uhr“ ohne Namen: MP3 oder Melodie genügt.
        Zeile(name: "Klangwahl Von der Uhr", tc002: true, tc001: true) {
            Klangwahl(art: .uhr).gekonnt(von: $0)
        },
        Zeile(name: "Klangwahl Vorlesen", tc002: true, tc001: false) {
            Klangwahl(art: .vorlesen).gekonnt(von: $0)
        },
        Zeile(name: "Klang Datei MP3 laut Liste", tc002: true, tc001: false) {
            Klang(.datei("gong")).gekonnt(von: $0, listen: Tonlisten(melodien: ["ping"], mp3: ["gong"]))
        },
        Zeile(name: "Klang Datei Melodie laut Liste", tc002: true, tc001: true) {
            Klang(.datei("ping")).gekonnt(von: $0, listen: Tonlisten(melodien: ["ping"], mp3: ["gong"]))
        },
        // Fernbedienung: Lichtsensor und Automatik
        Zeile(name: "Lichtsensor (sensors.light)", tc002: false, tc001: true) { $0.lichtsensor },
        Zeile(name: "autoBrightness wirkt", tc002: false, tc001: true) {
            Geraeteeinstellung.autoBrightness.wirkt(faehigkeiten: $0)
        },
        // Layouts
        Zeile(name: "Layouts (layout)", tc002: true, tc001: false) { $0.layoutUnterstuetzt == true },
        Zeile(name: "Kastenlayout wird nicht als nichtUnterstuetzt abgewiesen", tc002: true, tc001: false) {
            do { try Kastenlayout(regionen: []).pruefen(faehigkeiten: $0) }
            catch LayoutFehler.nichtUnterstuetzt { return false }
            catch { return true }
            return true
        },
        // Verschlüsselung (nur TC002 gemessen; die TC001-Antwort trägt das Feld nicht)
        // Der Schlüssel fehlt bei der TC001 (gemessen 10.10.2026): Die App entscheidet „nein“.
        Zeile(name: "MQTT über TLS (mqttTls)", tc002: true, tc001: false) { $0.mqttTlsUnterstuetzt == true },
        Zeile(name: "Zifferblätter (clockFaces)", tc002: true, tc001: false) { !$0.zifferblaetter.isEmpty },
        // Drehknopf: die TC001 hat drei Tasten und keinen (ESP32-Zweig der Herstellerdoku).
        Zeile(name: "Drehknopf (platform.id)", tc002: true, tc001: false) { $0.hatDrehknopf },
    ]

    func testJedeZeileDerTabelleStimmtFuerBeideModelle() throws {
        let tc002 = try faehigkeiten(Self.tc002Antwort)
        let tc001 = try faehigkeiten(Self.tc001Antwort)
        for z in zeilen {
            XCTAssertEqual(z.wert(tc002), z.tc002, "TC002: \(z.name)")
            XCTAssertEqual(z.wert(tc001), z.tc001, "TC001: \(z.name)")
        }
    }

    func testKlangartenSindAlleInDerTabelle() {
        // Eine neue Klangart braucht eine Zeile in der Tabelle und hier.
        XCTAssertEqual(Set(Klangart.allCases.map(\.rawValue)),
                       ["mp3", "melodie", "rtttl", "lied", "sprache", "radio", "adresse"])
    }

    func testAnzeigemassJeModell() throws {
        XCTAssertEqual(try mass(Self.tc002Antwort), Anzeigemass(breite: 52, hoehe: 16))
        XCTAssertEqual(try mass(Self.tc001Antwort), Anzeigemass(breite: 32, hoehe: 8))
        // Ohne Auskunft gilt die Vorgabe der TC002.
        XCTAssertEqual(Anzeigemass.fuer(Uhr(name: "x", host: "h")), Anzeigemass(breite: 52, hoehe: 16))
    }

    func testMP3ZeigenNurWennEinZielSieKann() throws {
        let a = Klangziel(id: UUID(), name: "A", faehigkeiten: try faehigkeiten(Self.tc002Antwort))
        let b = Klangziel(id: UUID(), name: "B", faehigkeiten: try faehigkeiten(Self.tc001Antwort))
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: [a]))
        XCTAssertFalse(Klangeignung.mp3Zeigen(in: [b]))
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: [a, b]))
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: []))
        // Nur ein Teil kann „Vorlesen“: Die Nachricht geht an beide, der Klang nur an A.
        let klang = Klang(.sprache("Hallo"))
        let verteilung = Klangeignung.verteilen([klang], an: [a, b])
        XCTAssertEqual(verteilung.klaenge[a.id], [klang])
        XCTAssertEqual(verteilung.klaenge[b.id], [])
        XCTAssertEqual(verteilung.uebersprungeneNamen, ["B"])
    }

    func testUnbekanntIstErlaubt() {
        let unbekannt: Geraetefaehigkeiten? = nil
        XCTAssertTrue(Klangeignung.mp3Hochladbar(unbekannt))
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: [Klangziel(id: UUID(), name: "A")]))
        let ohneAudio = Geraetefaehigkeiten()
        for art in Klangart.allCases { XCTAssertTrue(ohneAudio.kann(art), "\(art)") }
        XCTAssertTrue(ohneAudio.hatDrehknopf)
        // Ausnahmen, gewollt (siehe „Abweichungen“): kein Sensor, kein Layout-Urteil ohne Auskunft.
        XCTAssertFalse(ohneAudio.lichtsensor)
        XCTAssertFalse(Geraeteeinstellung.autoBrightness.wirkt(faehigkeiten: nil))
        XCTAssertNil(ohneAudio.layoutUnterstuetzt)
    }

    func testVirtuelleUhrIstImTC001ModusDieTC001() throws {
        var z = NGUhrzustand()
        z.ton.faehigkeiten = NGTon.tc001
        z.lichtsensor = true
        let wert = VirtuelleNGUhr.faehigkeitenantwort(z)
        guard case .objekt(let o) = wert else { return XCTFail("keine Auskunft") }
        XCTAssertEqual(o["platform"], .objekt(["id": .text("esp32")]))
        XCTAssertEqual(o["sensors"], .objekt(["light": .bool(true)]))

        // Dieselben Schalter wie in der gemessenen Antwort der echten TC001.
        let gemessen = try faehigkeiten(Self.tc001Antwort)
        let audio = try XCTUnwrap(try Self.lesen(Self.tc001Antwort)["audio"] as? [String: Bool])
        XCTAssertEqual(NGTon.tc001, audio)
        let daten = try JSONEncoder().encode(wert)
        let virtuell = try XCTUnwrap(Geraetefaehigkeiten(antwort: Self.lesen(
            String(decoding: daten, as: UTF8.self))))
        XCTAssertEqual(virtuell.ton, gemessen.ton)
        XCTAssertEqual(virtuell.lichtsensor, gemessen.lichtsensor)
        // Der gemessene Schlüsselsatz der TC001: weder Layouts noch TLS, Zifferblätter,
        // Startklang oder `enlargeApps`; Anzeige 32 × 8.
        for schluessel in ["layout", "layouts", "mqttTls", "clockFaces", "bootSound", "enlargeApps"] {
            XCTAssertNil(o[schluessel], schluessel)
        }
        XCTAssertEqual(virtuell.layoutUnterstuetzt, false)
        XCTAssertEqual(virtuell.mqttTlsUnterstuetzt, false)
        XCTAssertTrue(virtuell.zifferblaetter.isEmpty)
        XCTAssertFalse(virtuell.hatDrehknopf)
        XCTAssertEqual(virtuell.plattform, "esp32")
        XCTAssertEqual(try mass(String(decoding: daten, as: UTF8.self)), Anzeigemass(breite: 32, hoehe: 8))
        // Auch die Einstellungen tragen die drei Schlüssel nicht.
        let einstellungen = VirtuelleNGUhr.einstellungenantwort(z)
        for schluessel in ["clockFace", "bootSound", "enlargeApps"] { XCTAssertNil(einstellungen[schluessel], schluessel) }
        XCTAssertNotNil(einstellungen["volume"])
    }
}
