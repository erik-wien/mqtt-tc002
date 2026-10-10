import Foundation
import ImageIO
import XCTest
import TC002Core
@testable import TC002Modell

/// Zeichnet auf, was ueber MQTT hinausginge. Kein Broker.
private final class MQTTDoppelgaenger: NachrichtSendend, @unchecked Sendable {
    private let sperre = NSLock()
    private var _gesendet: [(thema: String, nutzlast: Data)] = []
    /// Je Thema eine kuenstliche Wartezeit, wie eine Uhr, die der Broker nicht erreicht.
    var verzoegerung: [String: TimeInterval] = [:]
    /// Wird gerufen, sobald ein Thema hinausgegangen ist (zum Einspielen einer Antwort).
    var danach: ((String) -> Void)?

    var gesendet: [(thema: String, nutzlast: Data)] {
        sperre.lock(); defer { sperre.unlock() }
        return _gesendet
    }

    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        if let pause = verzoegerung.first(where: { thema.hasPrefix($0.key) })?.value {
            Thread.sleep(forTimeInterval: pause)
        }
        sperre.lock(); _gesendet.append((thema, nutzlast)); sperre.unlock()
        danach?(thema)
    }
}

/// Der Sendeweg im Zustand: je Uhr ein Bild in ihrem Mass, die Antwort der Uhr
/// auf `<Thema>/result` und das Ausbleiben dieser Antwort.
@MainActor
final class SendewegTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn", "grabsteine"]
    private var sicherung: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        d.set(false, forKey: "verlaufAn")
        Belegungsdoppelgaenger.antwort = "{}"
        Belegungsdoppelgaenger.weitere = [:]
        Belegungsdoppelgaenger.pfade = []
    }

    override func tearDown() {
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private let tc002 = Uhr(name: "Wohnzimmer", host: "", praefix: "wz/uhr", betriebsart: .mqtt)
    private let tc001 = Uhr(name: "Küche", host: "", praefix: "kue/uhr", betriebsart: .mqtt,
                            panelbreite: 32, panelhoehe: 8)

    private func zustand(_ uhren: [Uhr], sender: MQTTDoppelgaenger) throws -> AppZustand {
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(uhren[0].id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set(uhren.map(\.id))), forKey: "zielIDs")
        d.set("127.0.0.1", forKey: "brokerHost")
        d.set("1883", forKey: "brokerPort")
        d.set("u", forKey: "benutzer")
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        z.mqttSender = sender
        z.netzsitzung = Belegungsdoppelgaenger.sitzung()
        return z
    }

    private func sammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: FileManager.default.temporaryDirectory
            .appendingPathComponent("sendeweg-" + UUID().uuidString))
    }

    private func gifMass(_ nutzlast: Data) throws -> (Int, Int) {
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: nutzlast) as? [String: Any])
        let uri = try XCTUnwrap(o["icon"] as? String)
        let gif = try XCTUnwrap(Data(base64Encoded: String(uri.dropFirst("data:image/gif;base64,".count))))
        let quelle = try XCTUnwrap(CGImageSourceCreateWithData(gif as CFData, nil))
        let e = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any])
        return (e[kCGImagePropertyPixelWidth] as? Int ?? 0, e[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    private let ablehnung = Data(#"{"ok":false,"error":{"code":"validationFailed","message":"unknown field","field":"layout"}}"#.utf8)

    // MARK: - Je Uhr ein Bild in ihrem Mass

    /// „An alle" mit einer TC002 und einer TC001: Text wird je Uhr in deren Mass
    /// gerastert, nicht einmal fuer die angesehene.
    func testGemischteGruppeBekommtJeUhrEinBildInIhremMass() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc002, tc001], sender: sender)
        let sammlung = sammlung()
        let o = Meldungsoptionen(text: "Grüß", weg: .pixel, schrift: "Silkscreen", groesse: 8)

        let bilanz = await z.senden(rahmenFuer: { mass in
            try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung, mass: mass)
        }, als: "meldung1")

        XCTAssertTrue(bilanz.ganz, z.fehler ?? "")
        let gross = try XCTUnwrap(sender.gesendet.first { $0.thema.hasPrefix("wz/uhr") })
        let klein = try XCTUnwrap(sender.gesendet.first { $0.thema.hasPrefix("kue/uhr") })
        let a = try gifMass(gross.nutzlast), b = try gifMass(klein.nutzlast)
        XCTAssertEqual([a.0, a.1, b.0, b.1], [52, 16, 32, 8])
    }

    /// Ein fertiges Bild (Editor, Sammlung) in einem anderen Mass geht an die
    /// Uhr nicht hinaus; die uebrigen bekommen es, und die Meldung nennt die Uhr.
    func testFertigesBildInFalschemMassWirdFuerDieseUhrAbgewiesen() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc002, tc001], sender: sender)
        let bild = Pixelinhalt(breite: 52, hoehe: 16, bilder: [
            Bildraster.Einzelbild(pixel: [String?](repeating: nil, count: 52 * 16), dauer: 1)])

        let bilanz = await z.senden(Frame(pixel: bild), als: "meldung2")

        XCTAssertTrue(bilanz.teilweise)
        XCTAssertEqual(sender.gesendet.map(\.thema), ["wz/uhr/cmd/apps/pushed/meldung2"])
        let meldung = try XCTUnwrap(z.teilfehler)
        XCTAssertTrue(meldung.contains("Küche"), meldung)
        XCTAssertTrue(meldung.contains("52 × 16") && meldung.contains("32 × 8"), meldung)
    }

    func testBildInFalschemMassKostetNurDieseSendung() throws {
        let anzeigen = Anzeigen(sender: MQTTDoppelgaenger(),
                                zugang: MQTTZugang(host: "127.0.0.1", benutzer: nil, kennwort: nil),
                                praefix: "kue/uhr", anzeigemass: Anzeigemass(breite: 32, hoehe: 8))
        let bild = Pixelinhalt(breite: 52, hoehe: 16, bilder: [
            Bildraster.Einzelbild(pixel: [String?](repeating: nil, count: 52 * 16), dauer: 1)])
        XCTAssertThrowsError(try anzeigen.zeigen(Frame(pixel: bild), auf: "meldung1")) { fehler in
            guard case NGFehler.massPasstNicht = fehler else { return XCTFail("war \(fehler)") }
        }
    }

    // MARK: - Layouts

    private let layout = Kastenlayout(regionen: [
        Layoutregion(kennung: "balken", kasten: Kasten(x: 0, y: 8, breite: 26, hoehe: 4), inhalt: .fortschritt(50))])

    /// Ein Layout geht an die Uhr, die es kann; die Uhr, die es nicht meldet
    /// (TC001/ESP32), bekommt es nicht, und die Meldung nennt sie.
    func testEinLayoutGehtNurAnUhrenMitLayouts() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc002, tc001], sender: sender)
        z.faehigkeiten[tc002.id] = Geraetefaehigkeiten(layoutUnterstuetzt: true)
        z.faehigkeiten[tc001.id] = Geraetefaehigkeiten(layoutUnterstuetzt: false)

        let bilanz = await z.senden(Frame(dauer: 5, layout: layout), als: "meldung3")

        XCTAssertTrue(bilanz.teilweise)
        XCTAssertEqual(sender.gesendet.map(\.thema), ["wz/uhr/cmd/apps/pushed/meldung3"])
        XCTAssertEqual(String(decoding: sender.gesendet[0].nutzlast, as: UTF8.self),
                       #"{"layout":{"version":1,"regions":[{"id":"balken","box":[0,8,26,4],"progress":50}]},"durationMs":5000}"#)
        let meldung = try XCTUnwrap(z.teilfehler)
        XCTAssertTrue(meldung.contains("Küche") && meldung.contains(lok("Diese Uhr kann keine Layouts. Sie meldet keine Layouts unter ihren Fähigkeiten (die TC001 hat keine).")), meldung)
    }

    func testEinLayoutAlsBenachrichtigung() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc002], sender: sender)
        let bilanz = await z.benachrichtigen(rahmenFuer: { _ in Frame(layout: self.layout) })
        XCTAssertTrue(bilanz.ganz, z.fehler ?? "")
        XCTAssertEqual(sender.gesendet.map(\.thema), ["wz/uhr/cmd/notify"])
        XCTAssertTrue(String(decoding: sender.gesendet[0].nutzlast, as: UTF8.self).hasPrefix(#"{"layout":"#))
    }

    // MARK: - Die Antwort auf /result

    private func ergebnisThema(_ uhr: Uhr, _ name: String = "meldung1") -> String {
        "\(uhr.praefix)/cmd/apps/pushed/\(name)/result"
    }

    /// `ok:false` nach der Sendung wird zur Fehlermeldung — mit Code und Feld.
    func testEineAbweisungNachDemSendenIstSichtbar() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc001], sender: sender)
        z.horchtGerade[tc001.id] = true
        await z.senden(Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x"))), als: "meldung1")
        XCTAssertNil(z.fehler)

        z.gemeldet(thema: ergebnisThema(tc001), nutzlast: ablehnung, fuer: tc001.id,
                   gedaechtnis: Slotgedaechtnis(ordner: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)))

        let meldung = try XCTUnwrap(z.fehler)
        XCTAssertTrue(meldung.contains("validationFailed") && meldung.contains("layout")
                      && meldung.contains("Küche"), meldung)
        XCTAssertTrue(meldung.contains(lok("Ungültiger Wert")), "der Code in Worten: \(meldung)")
    }

    /// Die Ursache, die das Ergebnis unsichtbar machte: `anZiele` wartet auf die
    /// langsamste Uhr und setzte danach `fehler` neu. Die Abweisung der
    /// schnellen Uhr, die in der Zwischenzeit eintraf, war weg.
    func testEineAbweisungWaehrendDesSendensWirdNichtUeberschrieben() async throws {
        let sender = MQTTDoppelgaenger()
        sender.verzoegerung = ["wz/uhr": 0.4]
        let z = try zustand([tc002, tc001], sender: sender)
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let kueche = tc001
        sender.danach = { thema in
            guard thema.hasPrefix("kue/uhr") else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    z.gemeldet(thema: "kue/uhr/cmd/apps/pushed/meldung1/result", nutzlast: self.ablehnung,
                               fuer: kueche.id, gedaechtnis: Slotgedaechtnis(ordner: ordner))
                }
            }
        }

        await z.senden(Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x"))), als: "meldung1")

        let meldung = try XCTUnwrap(z.fehler, "die Abweisung muss stehen bleiben")
        XCTAssertTrue(meldung.contains("validationFailed"), meldung)
        XCTAssertNil(z.teilfehler, "eine Abweisung ist kein Teilfehler")
    }

    func testBleibtDieAntwortAusGibtEsEineWarnung() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc001], sender: sender)
        z.horchtGerade[tc001.id] = true
        z.ergebnisFrist = .milliseconds(50)

        await z.senden(Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x"))), als: "meldung1")
        XCTAssertNil(z.teilfehler, "gleich nach dem Senden ist es noch zu frueh")
        try await Task.sleep(for: .milliseconds(300))

        let warnung = try XCTUnwrap(z.teilfehler)
        XCTAssertTrue(warnung.contains("Küche") && warnung.contains("meldung1"), warnung)
        XCTAssertNil(z.fehler, "eine Warnung, kein harter Fehler")
    }

    func testEineAntwortInnerhalbDerFristBeruhigt() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc001], sender: sender)
        z.horchtGerade[tc001.id] = true
        z.ergebnisFrist = .milliseconds(100)
        await z.senden(Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x"))), als: "meldung1")

        z.gemeldet(thema: ergebnisThema(tc001), nutzlast: Data(#"{"ok":true}"#.utf8), fuer: tc001.id,
                   gedaechtnis: Slotgedaechtnis(ordner: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)))
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertNil(z.teilfehler)
        XCTAssertNil(z.fehler)
    }

    /// Ohne Mitlesen beweist das Schweigen nichts.
    func testOhneMitlesenKeineWarnung() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc001], sender: sender)
        z.ergebnisFrist = .milliseconds(50)
        await z.senden(Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x"))), als: "meldung1")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(z.teilfehler)
    }

    /// Reisst das Mitlesen ab, entfaellt die Warnung.
    func testRissDasMitlesenAbBleibtDieWarnungAus() async throws {
        let sender = MQTTDoppelgaenger()
        let z = try zustand([tc001], sender: sender)
        z.horchtGerade[tc001.id] = true
        z.ergebnisFrist = .milliseconds(100)
        await z.senden(Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x"))), als: "meldung1")
        z.horchzustand(false, "Verbindung weg", fuer: tc001.id)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(z.teilfehler)
    }

    /// Was ueber HTTP an die Uhr ging, antwortet nicht auf MQTT.
    func testEinHTTPWegWartetNichtAufEineMQTTAntwort() async throws {
        var uhr = tc002
        uhr.host = "uhr.example"
        let sender = MQTTDoppelgaenger()
        let z = try zustand([uhr], sender: sender)
        z.horchtGerade[uhr.id] = true
        z.ergebnisFrist = .milliseconds(50)
        let o = Meldungsoptionen(text: "Grüße aus Wien", weg: .pixel, schrift: "Silkscreen", groesse: 8)
        let sammlung = sammlung()

        let bilanz = await z.senden(rahmenFuer: { try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung, mass: $0) },
                                    als: "meldung1")
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(bilanz.ganz, z.fehler ?? "")
        XCTAssertTrue(sender.gesendet.isEmpty, "zu gross fuer MQTT")
        XCTAssertNil(z.teilfehler)
    }
}
