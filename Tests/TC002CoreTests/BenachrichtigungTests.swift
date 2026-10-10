import XCTest
import Network
@testable import TC002Core

private final class Mitschreiber: NachrichtSendend, @unchecked Sendable {
    var gesendet: [(thema: String, nutzlast: String)] = []
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        gesendet.append((thema, String(data: nutzlast, encoding: .utf8) ?? ""))
    }
}

/// Antwortet auf jedes Hören mit dem, was der Test vorgibt.
private struct FesteAntwort: ErgebnisLauschend {
    let antwort: Data?
    func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                  waehrend tat: () throws -> Void) throws -> Data? {
        try tat()
        return antwort
    }
}

/// Benachrichtigungen, Lebensdauer, Schalten — Themen und Nutzlasten gegen die
/// Gerätereferenz (§3.2, §5.4, §5.6), ohne Broker.
final class BenachrichtigungTests: XCTestCase {
    private let zugang = MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p")
    private let praefix = "wohnzimmer/uhr"

    private func textrahmen(_ text: String = "hallo", dauer: Int? = nil,
                            lebensdauer: Lebensdauer? = nil) -> Frame {
        Frame(dauer: dauer,
              herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: text, weg: .text, dauer: dauer)),
              lebensdauer: lebensdauer)
    }

    private func kanal(_ sender: NachrichtSendend) -> Anzeigen {
        Anzeigen(sender: sender, zugang: zugang, praefix: praefix)
    }

    // MARK: - Nutzlast

    /// Die Vorgaben der Uhr gehen nicht mit: `stack:true`, `hold:false`,
    /// `wakeup:false` sind dort ohnehin gültig, und die MQTT-Grenze ist knapp.
    func testEineSchlichteBenachrichtigungTraegtNurDieAnzeige() throws {
        let json = try NGNutzlast.benachrichtigung(
            textrahmen(), .init(halten: false, einreihen: true, aufwecken: false, wiederholungen: nil))
        XCTAssertEqual(json, try Anzeigen.nutzlast(textrahmen()))
    }

    /// Die Vorgaben der App: bleibt nicht stehen, ersetzt die sichtbare, weckt, läuft zweimal.
    func testDieVorgabenEinerNachricht() throws {
        let json = try NGNutzlast.benachrichtigung(textrahmen(), .init())
        XCTAssertTrue(json.hasSuffix(#","stack":false,"wakeup":true,"repeat":2}"#), json)
        XCTAssertFalse(json.contains("hold"), "Nicht halten ist auch die Vorgabe der Uhr")
    }

    func testDieFelderDerBenachrichtigungStehenHinterDerAnzeige() throws {
        let o = Benachrichtigungsoptionen(name: "tuer", halten: true, einreihen: false,
                                          aufwecken: true, wiederholungen: 2)
        let json = try NGNutzlast.benachrichtigung(textrahmen(), o)
        XCTAssertTrue(json.hasSuffix(#","name":"tuer","hold":true,"stack":false,"wakeup":true,"repeat":2}"#), json)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testEineBenachrichtigungTraegtKeineLebensdauer() throws {
        let rahmen = textrahmen(lebensdauer: Lebensdauer(sekunden: 30))
        let json = try NGNutzlast.benachrichtigung(rahmen, .init())
        XCTAssertFalse(json.contains("lifetime"), json)
    }

    func testDieDauerGehtAlsMillisekundenMit() throws {
        let json = try NGNutzlast.benachrichtigung(textrahmen(dauer: 4), .init())
        XCTAssertTrue(json.contains(#""durationMs":4000"#), json)
    }

    func testEinUnzulaessigerNameWirdNichtGesendet() {
        let sender = Mitschreiber()
        for name in ["", "active", "mit Leerzeichen", "a/b", "a#", String(repeating: "x", count: 33)] {
            XCTAssertThrowsError(try kanal(sender).benachrichtigen(textrahmen(), .init(name: name)), name) { f in
                guard case NGFehler.ungueltigerName = f else { return XCTFail("war \(f)") }
            }
            XCTAssertThrowsError(try kanal(sender).benachrichtigungZurueckziehen(name: name), name)
        }
        XCTAssertTrue(sender.gesendet.isEmpty)
    }

    // MARK: - Themen

    func testBenachrichtigenGehtAufCmdNotify() throws {
        let sender = Mitschreiber()
        let weg = try kanal(sender).benachrichtigen(textrahmen(), .init(halten: true))
        XCTAssertEqual(weg, .mqtt)
        XCTAssertEqual(sender.gesendet.first?.thema, "wohnzimmer/uhr/cmd/notify")
        XCTAssertTrue(sender.gesendet.first?.nutzlast.contains(#""hold":true"#) == true)
    }

    func testZurueckziehenSichtbareUndNachName() throws {
        let sender = Mitschreiber()
        try kanal(sender).benachrichtigungZurueckziehen()
        try kanal(sender).benachrichtigungZurueckziehen(name: "tuer")
        XCTAssertEqual(sender.gesendet.map(\.thema),
                       ["wohnzimmer/uhr/cmd/notify/dismiss", "wohnzimmer/uhr/cmd/notify/dismiss/tuer"])
        XCTAssertEqual(sender.gesendet.map(\.nutzlast), ["", ""])
    }

    func testSchaltenIstTrueOderFalseAufDemFreigabeThema() throws {
        let sender = Mitschreiber()
        try kanal(sender).schalten("meldung1", an: false)
        try kanal(sender).schalten("meldung1", an: true)
        XCTAssertEqual(sender.gesendet.map(\.thema),
                       Array(repeating: "wohnzimmer/uhr/cmd/apps/meldung1/enabled", count: 2))
        XCTAssertEqual(sender.gesendet.map(\.nutzlast), ["false", "true"])
        XCTAssertThrowsError(try kanal(sender).schalten("a/b", an: true))
        XCTAssertEqual(sender.gesendet.count, 2)
    }

    func testBlaetternGehtAufNextUndPrevious() throws {
        let sender = Mitschreiber()
        try kanal(sender).blaettern(vor: true)
        try kanal(sender).blaettern(vor: false)
        XCTAssertEqual(sender.gesendet.map(\.thema),
                       ["wohnzimmer/uhr/cmd/apps/next", "wohnzimmer/uhr/cmd/apps/previous"])
    }

    func testEineZuGrosseBenachrichtigungOhneAdresseWirdNichtGesendet() {
        // Ein Pixelbild in Anzeigegröße mit vielen Bildern sprengt die 8192 Byte.
        // Zufallsähnliche Farben, sonst schrumpft das GIF unter die Grenze.
        var zahl: UInt32 = 12345
        let bilder = (0..<40).map { _ in
            Bildraster.Einzelbild(pixel: (0..<832).map { _ -> String? in
                zahl = zahl &* 1_664_525 &+ 1_013_904_223
                return String(format: "#%06X", zahl >> 8)
            }, dauer: 1)
        }
        let rahmen = Frame(pixel: Pixelinhalt(breite: 52, hoehe: 16, bilder: bilder))
        let sender = Mitschreiber()
        XCTAssertThrowsError(try kanal(sender).benachrichtigen(rahmen)) { f in
            guard case NGFehler.keineAdresseFuerGrosse = f else { return XCTFail("war \(f)") }
        }
        XCTAssertTrue(sender.gesendet.isEmpty)
    }

    // MARK: - Lebensdauer

    func testDieLebensdauerStehtHinterDerAnzeige() throws {
        let rahmen = textrahmen(lebensdauer: Lebensdauer(sekunden: 90, ablauf: .markieren))
        let json = try Anzeigen.nutzlast(rahmen)
        XCTAssertTrue(json.hasSuffix(#","lifetimeMs":90000,"lifetimeExpiry":"mark"}"#), json)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testDieLebensdauerGehtAuchBeimPixelwegMit() throws {
        let inhalt = Pixelinhalt(breite: 52, hoehe: 16,
                                 bilder: [Bildraster.Einzelbild(pixel: [String?](repeating: "#FF0000", count: 832), dauer: 1)])
        let json = try Anzeigen.nutzlast(Frame(pixel: inhalt, lebensdauer: Lebensdauer(sekunden: 5)))
        XCTAssertTrue(json.hasSuffix(#","lifetimeMs":5000,"lifetimeExpiry":"remove"}"#), json)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testEinRahmenOhneLebensdauerTraegtKeineUndBleibtWieBisher() throws {
        XCTAssertFalse(try Anzeigen.nutzlast(textrahmen()).contains("lifetime"))
    }

    /// Ohne Angabe verschwindet eine neue Anzeige nach 30 Minuten; ausgeschaltet
    /// (`Lebensdauer.aus`) trägt sie nichts.
    func testDerRahmenbauSetztDieVorgabeUndDasAusschalten() throws {
        let sammlung = Iconsammlung(schreibordner: FileManager.default.temporaryDirectory)
        for weg in [SendeWeg.text, .pixel] {
            let vorgabe = try Meldungsbau.rahmen(Meldungsoptionen(text: "x", weg: weg), icon: nil, sammlung: sammlung)
            XCTAssertEqual(vorgabe.lebensdauer, Lebensdauer(sekunden: 1800, ablauf: .entfernen), "\(weg)")
            XCTAssertTrue(try Anzeigen.nutzlast(vorgabe).hasSuffix(#","lifetimeMs":1800000,"lifetimeExpiry":"remove"}"#))
            let aus = try Meldungsbau.rahmen(Meldungsoptionen(text: "x", weg: weg, lebensdauer: .aus),
                                             icon: nil, sammlung: sammlung)
            XCTAssertNil(aus.lebensdauer, "\(weg)")
            XCTAssertFalse(try Anzeigen.nutzlast(aus).contains("lifetime"))
        }
    }

    func testDerRahmenbauReichtDieLebensdauerDurch() throws {
        let l = Lebensdauer(sekunden: 12, ablauf: .markieren)
        let sammlung = Iconsammlung(schreibordner: FileManager.default.temporaryDirectory)
        for weg in [SendeWeg.text, .pixel] {
            let rahmen = try Meldungsbau.rahmen(Meldungsoptionen(text: "x", weg: weg, lebensdauer: l),
                                                icon: nil, sammlung: sammlung)
            XCTAssertEqual(rahmen.lebensdauer, l, "\(weg)")
        }
    }

    /// Eine Verlaufsdatei aus der Zeit vor der Lebensdauer muss lesbar bleiben.
    func testAlteOptionenOhneLebensdauerSindLesbar() throws {
        let neu = Meldungsoptionen(text: "x")
        var objekt = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(neu)) as? [String: Any])
        objekt["lebensdauer"] = nil
        let alt = try JSONSerialization.data(withJSONObject: objekt)
        XCTAssertEqual(try JSONDecoder().decode(Meldungsoptionen.self, from: alt), neu)
        let mit = Meldungsoptionen(text: "x", lebensdauer: Lebensdauer(sekunden: 3, ablauf: .markieren))
        XCTAssertEqual(try JSONDecoder().decode(Meldungsoptionen.self, from: JSONEncoder().encode(mit)), mit)
    }

    // MARK: - Antwort der Uhr (/result)

    func testEineAbweisungWirdZumFehler() {
        let sender = Mitschreiber()
        let antwort = Data(#"{"ok":false,"error":{"code":"validationFailed","message":"x","field":"hold"}}"#.utf8)
        let a = kanal(sender).quittierend(lauscher: FesteAntwort(antwort: antwort)) { _ in
            XCTFail("es kam eine Antwort")
        }
        XCTAssertThrowsError(try a.benachrichtigen(textrahmen(), .init())) { f in
            guard case NGFehler.abgewiesen(let grund) = f else { return XCTFail("war \(f)") }
            XCTAssertTrue(grund.contains("validationFailed"), grund)
            XCTAssertTrue(grund.contains("hold"), grund)
            XCTAssertTrue(f.localizedDescription.contains(grund))
        }
        XCTAssertEqual(sender.gesendet.count, 1, "gesendet wurde trotzdem")
    }

    func testEineGelungeneAntwortIstStill() throws {
        let a = kanal(Mitschreiber()).quittierend(lauscher: FesteAntwort(antwort: Data(#"{"ok":true}"#.utf8))) { _ in
            XCTFail("es kam eine Antwort")
        }
        try a.zeigen(textrahmen(), auf: "meldung1")
        try a.loeschen("meldung1")
        try a.umschalten(auf: "meldung1")
        try a.schalten("meldung1", an: true)
        try a.benachrichtigungZurueckziehen()
    }

    /// Keine Antwort ist eine Warnung mit dem Thema, kein Fehler.
    func testEineAusbleibendeAntwortWirdGemeldetAberNichtGeworfen() throws {
        nonisolated(unsafe) var themen: [String] = []
        let a = kanal(Mitschreiber()).quittierend(lauscher: FesteAntwort(antwort: nil)) { themen.append($0) }
        try a.benachrichtigen(textrahmen(), .init())
        try a.zeigen(textrahmen(), auf: "meldung2")
        XCTAssertEqual(themen, ["wohnzimmer/uhr/cmd/notify", "wohnzimmer/uhr/cmd/apps/pushed/meldung2"])
    }

    func testOhneQuittierenWirdNichtGehoert() throws {
        // Der Standardfall (die App): kein Lauscher, kein Warten.
        let sender = Mitschreiber()
        try kanal(sender).zeigen(textrahmen(), auf: "meldung1")
        XCTAssertEqual(sender.gesendet.count, 1)
    }

    // MARK: - Themen der Antworten

    func testDieBezeichnungDerAntwort() {
        let p = praefix
        func b(_ t: String) -> String? { NGThema.ergebnisBezeichnung(thema: t, praefix: p) }
        XCTAssertEqual(b("\(p)/cmd/apps/pushed/meldung1/result"), "meldung1")
        XCTAssertNotNil(b("\(p)/cmd/notify/result"))
        XCTAssertNotNil(b("\(p)/cmd/notify/dismiss/result"))
        XCTAssertTrue(b("\(p)/cmd/notify/dismiss/tuer/result")?.contains("tuer") == true)
        XCTAssertTrue(b("\(p)/cmd/apps/wetter/enabled/result")?.contains("wetter") == true)
        XCTAssertNil(b("\(p)/cmd/notify"), "das Kommando selbst ist keine Antwort")
        XCTAssertNil(b("\(p)/cmd/settings/result"))
        XCTAssertNil(b("anders/cmd/notify/result"))
    }

    func testDieMusterDerAntworten() {
        XCTAssertEqual(NGThema.benachrichtigungenMuster(praefix: "p"), "p/cmd/notify/#")
        XCTAssertEqual(NGThema.freigabeErgebnisse(praefix: "p"), "p/cmd/apps/+/enabled/result")
    }
}

// MARK: - Der wirkliche Lauscher gegen einen Broker auf Loopback

/// Ein Broker, der gerade genug kann: CONNECT, SUBSCRIBE, PUBLISH. Veröffentlicht
/// jemand auf `T`, schickt er an alle Abonnenten von `T/result` die vorgegebene
/// Antwort — so, wie die Uhr es tut.
private final class AntwortBroker: @unchecked Sendable {
    private let listener: NWListener
    private let sperre = NSLock()
    private var abonnenten: [(NWConnection, String)] = []
    private var _veroeffentlicht: [String] = []
    private let antwort: Data?
    private(set) var port: UInt16 = 0

    var veroeffentlicht: [String] { sperre.lock(); defer { sperre.unlock() }; return _veroeffentlicht }

    init(antwort: Data?) throws {
        self.antwort = antwort
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [weak self] v in
            v.start(queue: .global())
            self?.lies(v, strom: Paketstrom())
        }
        let bereit = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { if case .ready = $0 { bereit.signal() } }
        listener.start(queue: .global())
        guard bereit.wait(timeout: .now() + 5) == .success, let p = listener.port?.rawValue else {
            throw MQTTFehler.zeitueberschreitung
        }
        port = p
    }

    func stoppen() { listener.cancel() }

    private func lies(_ v: NWConnection, strom: Paketstrom) {
        var strom = strom
        v.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] daten, _, beendet, fehler in
            guard let self else { return }
            if let daten, !daten.isEmpty {
                for paket in strom.aufnehmen(daten) { self.beantworte(paket, auf: v) }
            }
            guard fehler == nil, !beendet else { return }
            self.lies(v, strom: strom)
        }
    }

    private func beantworte(_ paket: Data, auf v: NWConnection) {
        let b = [UInt8](paket)
        switch b.first.map({ $0 & 0xF0 }) {
        case 0x10:
            v.send(content: Data([0x20, 0x02, 0x00, 0x00]), completion: .idempotent)
        case 0x80:
            let laenge = Int(b[4]) << 8 | Int(b[5])
            let thema = String(decoding: b[6..<(6 + laenge)], as: UTF8.self)
            sperre.lock(); abonnenten.append((v, thema)); sperre.unlock()
            v.send(content: Data([0x90, 0x03, b[2], b[3], 0x00]), completion: .idempotent)
        case 0x30:
            guard let (thema, _) = MQTTPaket.publishGelesen(paket) else { return }
            sperre.lock()
            _veroeffentlicht.append(thema)
            let ziele = abonnenten.filter { $0.1 == thema + "/result" }.map(\.0)
            sperre.unlock()
            if let antwort {
                for z in ziele {
                    z.send(content: MQTTPaket.publish(thema: thema + "/result", nutzlast: antwort),
                           completion: .idempotent)
                }
            }
        default:
            break
        }
    }
}

final class ErgebnislauscherTests: XCTestCase {
    private func anzeigen(_ broker: AntwortBroker, frist: TimeInterval = 5,
                          beiAusbleiben: @escaping @Sendable (String) -> Void) -> Anzeigen {
        let zugang = MQTTZugang(host: "127.0.0.1", port: broker.port, benutzer: "u", kennwort: "p",
                                clientID: "tc002-test")
        return Anzeigen(sender: MQTTSender(frist: 3), zugang: zugang, praefix: "uhr")
            .quittierend(frist: frist, lauscher: MQTTErgebnislauscher(abonnierfrist: 3),
                         beiAusbleiben: beiAusbleiben)
    }

    private let rahmen = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "hi", weg: .text)))

    func testDieAntwortDerUhrWirdGelesen() throws {
        let broker = try AntwortBroker(antwort: Data(#"{"ok":false,"error":{"code":"insufficientStorage","message":"queue full"}}"#.utf8))
        defer { broker.stoppen() }
        let a = anzeigen(broker) { XCTFail("es kam eine Antwort: \($0)") }
        XCTAssertThrowsError(try a.benachrichtigen(rahmen, .init())) { f in
            guard case NGFehler.abgewiesen(let grund) = f else { return XCTFail("war \(f)") }
            XCTAssertTrue(grund.contains("insufficientStorage"), grund)
        }
        XCTAssertEqual(broker.veroeffentlicht, ["uhr/cmd/notify"])
    }

    func testEineGelungeneAntwortLaesstDieSendungDurch() throws {
        let broker = try AntwortBroker(antwort: Data(#"{"ok":true}"#.utf8))
        defer { broker.stoppen() }
        let a = anzeigen(broker) { XCTFail("es kam eine Antwort: \($0)") }
        XCTAssertNoThrow(try a.zeigen(rahmen, auf: "meldung1"))
        XCTAssertEqual(broker.veroeffentlicht, ["uhr/cmd/apps/pushed/meldung1"])
    }

    func testKeineAntwortBisZurFristIstEineWarnung() throws {
        let broker = try AntwortBroker(antwort: nil)
        defer { broker.stoppen() }
        nonisolated(unsafe) var themen: [String] = []
        let a = anzeigen(broker, frist: 0.5) { themen.append($0) }
        XCTAssertNoThrow(try a.benachrichtigungZurueckziehen(name: "tuer"))
        XCTAssertEqual(themen, ["uhr/cmd/notify/dismiss/tuer"])
    }
}

/// Die Lebensdauer wird mit dem Platz gemerkt (`Slotstand`) — ein Dateiformat mit
/// mehreren Schreibern.
final class LebensdauerImSlotgedaechtnisTests: XCTestCase {
    private let uhr = UUID()
    private func gedaechtnis() -> Slotgedaechtnis {
        Slotgedaechtnis(ordner: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
    }

    func testDieLebensdauerKommtMitDenReglernZurueck() throws {
        let g = gedaechtnis()
        for ablauf in Lebensablauf.allCases {
            let o = Meldungsoptionen(text: "x", lebensdauer: Lebensdauer(sekunden: 600, ablauf: ablauf))
            XCTAssertTrue(g.merken(o, icon: nil, iconKante: 8, fuer: uhr, platz: 2))
            XCTAssertEqual(g.gemerkt(fuer: uhr, platz: 2)?.optionen?.lebensdauer,
                           Lebensdauer(sekunden: 600, ablauf: ablauf))
        }
    }

    /// Neu beschickt mit anderen Werten: die neuen gelten; ohne Angabe: die Vorgabe.
    func testNeuBeschicktUeberschreibtDieLebensdauer() throws {
        let g = gedaechtnis()
        _ = g.merken(Meldungsoptionen(text: "x", lebensdauer: Lebensdauer(sekunden: 60)),
                     icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        _ = g.merken(Meldungsoptionen(text: "x"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        let o = try XCTUnwrap(g.gemerkt(fuer: uhr, platz: 1)?.optionen)
        XCTAssertNil(o.lebensdauer)
        XCTAssertEqual(o.wirksameLebensdauer, .vorgabe)
    }

    /// Ausgeschaltet ist eine Angabe wie jede andere und kommt zurück.
    func testBehaltenWirdGemerkt() throws {
        let g = gedaechtnis()
        _ = g.merken(Meldungsoptionen(text: "x", lebensdauer: .aus), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
        let o = try XCTUnwrap(g.gemerkt(fuer: uhr, platz: 1)?.optionen)
        XCTAssertEqual(o.lebensdauer, .aus)
        XCTAssertNil(o.wirksameLebensdauer)
    }

    func testOhneLebensdauerBleibtDieDateiWieBisher() throws {
        let stand = try XCTUnwrap({ () -> Slotstand? in
            let g = gedaechtnis()
            _ = g.merken(Meldungsoptionen(text: "x"), icon: nil, iconKante: 8, fuer: uhr, platz: 1)
            return g.gemerkt(fuer: uhr, platz: 1)
        }())
        let json = String(decoding: try JSONEncoder().encode(stand), as: UTF8.self)
        XCTAssertFalse(json.contains("lebens"), json)
        let mit = Slotstand(platz: 1, text: "x", weg: "pixel", schrift: "S", groesse: 8, fett: false,
                            grossbuchstaben: false, rand: 1, abstand: 1, waagrecht: "links", senkrecht: "oben",
                            farbe: "#000000", tempo: "mittel", iconLaeuftMit: false, icon: nil, dauer: nil,
                            lebensdauer: 90, lebensablauf: "markieren", pruefsumme: "p")
        let wieder = try JSONDecoder().decode(Slotstand.self, from: JSONEncoder().encode(mit))
        XCTAssertEqual(wieder, mit)
    }

    /// Eine Datei aus der Zeit vor der Lebensdauer — von einer älteren Fassung
    /// geschrieben — bleibt lesbar.
    func testAlteDateiOhneLebensdauerIstLesbar() throws {
        let json = """
        {"platz":3,"text":"Bus","weg":"pixel","schrift":"Silkscreen","groesse":8,"fett":false,\
        "grossbuchstaben":false,"rand":1,"abstand":1,"waagrecht":"links","senkrecht":"oben",\
        "farbe":"#00FF66","tempo":"mittel","iconLaeuftMit":false,"dauer":10,"pruefsumme":"abcd"}
        """
        let stand = try JSONDecoder().decode(Slotstand.self, from: Data(json.utf8))
        XCTAssertNil(stand.lebensdauer)
        XCTAssertNil(stand.optionen?.lebensdauer)
        XCTAssertEqual(stand.optionen?.wirksameLebensdauer, .vorgabe, "ohne Angabe gilt die Vorgabe")
        XCTAssertEqual(stand.optionen?.dauer, 10)
    }
}
