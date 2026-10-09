import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

private final class Mitschreiber: NachrichtSendend, @unchecked Sendable {
    private let sperre = NSLock()
    private var _gesendet: [(thema: String, nutzlast: Data)] = []
    var gesendet: [(thema: String, nutzlast: Data)] {
        sperre.lock(); defer { sperre.unlock() }
        return _gesendet
    }
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        sperre.lock(); _gesendet.append((thema, nutzlast)); sperre.unlock()
    }
}

/// Benachrichtigungen, Lebensdauer und Schalten im Zustand der App — ohne Broker
/// und ohne Gerät; der HTTP-Weg geht gegen die virtuelle Uhr auf `127.0.0.1`.
@MainActor
final class BenachrichtigungZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn"]
    private var sicherung: [String: Any?] = [:]
    private var server: Uhrenserver?

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        d.set(false, forKey: "verlaufAn")
        Belegungsdoppelgaenger.antwort = "{}"
        Belegungsdoppelgaenger.weitere = [:]
        Belegungsdoppelgaenger.pfade = []
    }

    override func tearDown() {
        server?.beenden()
        server = nil
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private let mqttUhr = Uhr(name: "Küche", host: "", praefix: "kue/uhr", betriebsart: .mqtt)

    private func zustand(_ uhr: Uhr, sender: NachrichtSendend? = nil) throws -> AppZustand {
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        d.set("127.0.0.1", forKey: "brokerHost")
        d.set("1883", forKey: "brokerPort")
        d.set("u", forKey: "benutzer")
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        if let sender { z.mqttSender = sender }
        return z
    }

    nonisolated private func text(_ t: String = "hallo") -> Frame {
        Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: t, weg: .text)))
    }

    private func serverStarten() throws -> (Uhrenserver, UInt16) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()
                server = s
                return (s, port)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    // MARK: - Benachrichtigung

    func testDieAntwortenAufBenachrichtigungenWerdenMitgehoert() {
        XCTAssertEqual(AppZustand.themen(fuer: mqttUhr),
                       ["kue/uhr/availability", "kue/uhr/cmd/apps/pushed/#",
                        "kue/uhr/cmd/notify/#", "kue/uhr/cmd/apps/+/enabled/result"])
    }

    func testBenachrichtigenGehtJeUhrInIhremMassAufCmdNotify() async throws {
        let klein = Uhr(name: "Bad", host: "", praefix: "bad/uhr", betriebsart: .mqtt, panelbreite: 32, panelhoehe: 8)
        d.set(try JSONEncoder().encode([mqttUhr, klein]), forKey: "uhren")
        d.set(mqttUhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([mqttUhr.id, klein.id])), forKey: "zielIDs")
        d.set("127.0.0.1", forKey: "brokerHost"); d.set("1883", forKey: "brokerPort"); d.set("u", forKey: "benutzer")
        let sender = Mitschreiber()
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        z.mqttSender = sender
        let o = Meldungsoptionen(text: "Tür", weg: .pixel)
        let sammlung = Iconsammlung(schreibordner: temp())

        let bilanz = await z.benachrichtigen(rahmenFuer: { try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung, mass: $0) },
                                             .init(name: "tuer", halten: true))

        XCTAssertTrue(bilanz.ganz, z.fehler ?? "")
        XCTAssertEqual(Set(sender.gesendet.map(\.thema)), ["kue/uhr/cmd/notify", "bad/uhr/cmd/notify"])
        for g in sender.gesendet {
            let json = String(decoding: g.nutzlast, as: UTF8.self)
            XCTAssertTrue(json.contains(#""name":"tuer""#) && json.contains(#""hold":true"#), json)
        }
    }

    /// Eine Benachrichtigung ist keine Anzeige: weder Belegung noch Gedächtnis.
    func testEineBenachrichtigungBelegtKeinenPlatz() async throws {
        let z = try zustand(mqttUhr, sender: Mitschreiber())
        await z.benachrichtigen(rahmenFuer: { _ in self.text() })
        XCTAssertTrue(z.belegtePlaetze().isEmpty)
        XCTAssertTrue(z.bekannteAnzeigen[mqttUhr.id, default: []].isEmpty)
        for platz in 1...Meldungsplatz.anzahl {
            XCTAssertNil(Slotgedaechtnis.gemeinsam.gemerkt(fuer: mqttUhr.id, platz: platz))
        }
    }

    func testEineAbweisungDerBenachrichtigungIstSichtbar() async throws {
        let z = try zustand(mqttUhr, sender: Mitschreiber())
        z.horchtGerade[mqttUhr.id] = true
        await z.benachrichtigen(rahmenFuer: { _ in self.text() })
        XCTAssertNil(z.fehler)

        z.gemeldet(thema: "kue/uhr/cmd/notify/result",
                   nutzlast: Data(#"{"ok":false,"error":{"code":"insufficientStorage","message":"queue full"}}"#.utf8),
                   fuer: mqttUhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        let meldung = try XCTUnwrap(z.fehler)
        XCTAssertTrue(meldung.contains("insufficientStorage") && meldung.contains("Küche"), meldung)
    }

    func testBleibtDieAntwortAufEineBenachrichtigungAusGibtEsEineWarnung() async throws {
        let z = try zustand(mqttUhr, sender: Mitschreiber())
        z.horchtGerade[mqttUhr.id] = true
        z.ergebnisFrist = .milliseconds(50)
        await z.benachrichtigen(rahmenFuer: { _ in self.text() })
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(z.teilfehler)
        XCTAssertNil(z.fehler)
    }

    func testZurueckziehenUndSchaltenUndBlaettern() async throws {
        let sender = Mitschreiber()
        let z = try zustand(mqttUhr, sender: sender)
        await z.benachrichtigungZurueckziehen()
        await z.benachrichtigungZurueckziehen(name: "tuer")
        await z.anzeigeSchalten("meldung1", an: false)
        await z.anzeigeBlaettern(vor: true)
        XCTAssertEqual(sender.gesendet.map(\.thema),
                       ["kue/uhr/cmd/notify/dismiss", "kue/uhr/cmd/notify/dismiss/tuer",
                        "kue/uhr/cmd/apps/meldung1/enabled", "kue/uhr/cmd/apps/next"])
        XCTAssertEqual(String(decoding: sender.gesendet[2].nutzlast, as: UTF8.self), "false")
        XCTAssertNil(z.fehler)
    }

    func testDieAntwortAufDasSchaltenWirdZugeordnet() async throws {
        let z = try zustand(mqttUhr, sender: Mitschreiber())
        z.gemeldet(thema: "kue/uhr/cmd/apps/wetter/enabled/result",
                   nutzlast: Data(#"{"ok":false,"error":{"code":"notFound","message":"app not found"}}"#.utf8),
                   fuer: mqttUhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        let meldung = try XCTUnwrap(z.fehler)
        XCTAssertTrue(meldung.contains("wetter") && meldung.contains("notFound"), meldung)
    }

    func testBenachrichtigenUndZurueckziehenUeberHTTPAmPruefstand() async throws {
        let (s, port) = try serverStarten()
        let uhr = Uhr(name: "Virtuell", host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
        let z = try zustand(uhr)

        let bilanz = await z.benachrichtigen(rahmenFuer: { _ in self.text("Post") },
                                             .init(name: "post", einreihen: false, aufwecken: true))
        XCTAssertTrue(bilanz.ganz, z.fehler ?? "")
        XCTAssertEqual(s.zustand.benachrichtigungen.map(\.name), ["post"])
        XCTAssertTrue(s.zustand.benachrichtigungen[0].weckt)

        await z.benachrichtigungZurueckziehen(name: "post")
        XCTAssertTrue(s.zustand.benachrichtigungen.isEmpty)

        await z.benachrichtigungZurueckziehen(name: "nix")
        XCTAssertNotNil(z.fehler, "eine unbekannte Benachrichtigung ist eine Abweisung")
    }

    // MARK: - Lebensdauer und Belegung

    private let stand = Meldungsoptionen(text: "kurz", weg: .text)

    private func belegtMitGedaechtnis(_ g: Slotgedaechtnis, _ z: AppZustand, _ uhr: Uhr) {
        XCTAssertTrue(g.merken(stand, icon: nil, iconKante: 8, fuer: uhr.id, platz: 1))
        z.anzeigeBestaetigt("meldung1", fuer: uhr)
    }

    /// Nannte die Uhr die Anzeige und nennt sie sie nicht mehr, ist sie weg —
    /// samt den gemerkten Reglern.
    func testEineAbgelaufeneAnzeigeIstBeimNaechstenAbgleichFrei() throws {
        let z = try zustand(mqttUhr)
        let g = Slotgedaechtnis(ordner: temp())
        belegtMitGedaechtnis(g, z, mqttUhr)
        z.belegungGemeldet(["meldung1"], fuer: mqttUhr.id, gedaechtnis: g)
        XCTAssertEqual(z.belegtePlaetze(), [1])
        XCTAssertNotNil(g.gemerkt(fuer: mqttUhr.id, platz: 1))

        z.belegungGemeldet([], fuer: mqttUhr.id, gedaechtnis: g)   // Lebensdauer um, `remove`

        XCTAssertTrue(z.belegtePlaetze().isEmpty)
        XCTAssertEqual(z.slotzustand(1, belegt: false, gedaechtnis: g), .frei)
        XCTAssertNil(g.gemerkt(fuer: mqttUhr.id, platz: 1), "die Regler gehören zu nichts mehr")
    }

    /// Mit `mark` bleibt die Anzeige, also bleiben Belegung und Regler.
    func testEineMarkierteAnzeigeBleibtBelegt() throws {
        let z = try zustand(mqttUhr)
        let g = Slotgedaechtnis(ordner: temp())
        belegtMitGedaechtnis(g, z, mqttUhr)
        z.belegungGemeldet(["meldung1"], fuer: mqttUhr.id, gedaechtnis: g)
        z.belegungGemeldet(["meldung1"], fuer: mqttUhr.id, gedaechtnis: g)
        XCTAssertEqual(z.belegtePlaetze(), [1])
        XCTAssertNotNil(g.gemerkt(fuer: mqttUhr.id, platz: 1))
    }

    /// Eben geschickt, von der Uhr noch nicht genannt: eine Meldung ohne den
    /// Namen ist dafür zu früh (Karenz), die zweite gilt.
    func testDieKarenzEinerFrischGesendetenAnzeigeEndetMitDerZweitenMeldung() throws {
        let z = try zustand(mqttUhr)
        let g = Slotgedaechtnis(ordner: temp())
        z.belegungGemeldet([], fuer: mqttUhr.id, gedaechtnis: g)
        belegtMitGedaechtnis(g, z, mqttUhr)

        z.belegungGemeldet([], fuer: mqttUhr.id, gedaechtnis: g)
        XCTAssertEqual(z.belegtePlaetze(), [1], "die erste Meldung kann sie noch nicht kennen")
        XCTAssertNotNil(g.gemerkt(fuer: mqttUhr.id, platz: 1))

        z.belegungGemeldet([], fuer: mqttUhr.id, gedaechtnis: g)
        XCTAssertTrue(z.belegtePlaetze().isEmpty, "die zweite gilt")
        XCTAssertNil(g.gemerkt(fuer: mqttUhr.id, platz: 1))
    }

    /// Die Karenz beginnt mit jeder neuen Sendung von vorn.
    func testEineErneutGesendeteAnzeigeHatWiederKarenz() throws {
        let z = try zustand(mqttUhr)
        let g = Slotgedaechtnis(ordner: temp())
        z.belegungGemeldet([], fuer: mqttUhr.id, gedaechtnis: g)
        belegtMitGedaechtnis(g, z, mqttUhr)
        z.belegungGemeldet([], fuer: mqttUhr.id, gedaechtnis: g)
        z.anzeigeBestaetigt("meldung1", fuer: mqttUhr)
        z.belegungGemeldet([], fuer: mqttUhr.id, gedaechtnis: g)
        XCTAssertEqual(z.belegtePlaetze(), [1])
    }

    /// Der ganze Weg: Lebensdauer in den Reglern → Rahmen → HTTP → virtuelle
    /// Uhr → `GET /api/v1/apps` → Belegung.
    func testDieLebensdauerKommtAnUndDieBelegungFolgtDerUhr() async throws {
        let (s, port) = try serverStarten()
        let uhr = Uhr(name: "Virtuell", host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
        let z = try zustand(uhr)
        defer { _ = Slotgedaechtnis.gemeinsam.vergessen(fuer: uhr.id, platz: 1) }
        var mitLebensdauer = stand
        mitLebensdauer.lebensdauer = Lebensdauer(sekunden: 30)
        let o = mitLebensdauer
        let sammlung = Iconsammlung(schreibordner: temp())

        let bilanz = await z.senden(rahmenFuer: { try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung, mass: $0) },
                                    als: "meldung1", slotOptionen: o, slotPlatz: 1)
        XCTAssertTrue(bilanz.ganz, z.fehler ?? "")
        XCTAssertEqual(s.zustand.apps.first { $0.name == "meldung1" }?.lebensdauerMs, 30_000)

        let geraet = Geraet(host: uhr.host)
        z.belegungGemeldet(try geraet.anzeigennamen(), fuer: uhr.id)
        XCTAssertEqual(z.belegtePlaetze(), [1])

        s.lebensdauerAblaufen("meldung1")
        z.belegungGemeldet(try geraet.anzeigennamen(), fuer: uhr.id)

        XCTAssertTrue(z.belegtePlaetze().isEmpty)
        XCTAssertEqual(z.slotzustand(1, belegt: false), .frei)
        XCTAssertNil(Slotgedaechtnis.gemeinsam.gemerkt(fuer: uhr.id, platz: 1))
    }
}
