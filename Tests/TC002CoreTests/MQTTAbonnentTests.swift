import XCTest
import Network
@testable import TC002Core

final class MQTTAbonnentTests: XCTestCase {

    // MARK: - Der Zerleger

    /// Der Kern der Sache: TCP liefert einen Strom, keine Pakete. Hier kommt die
    /// erste Nachricht mitten im Thema geteilt an, die zweite haengt am selben
    /// Stueck mit dran.
    func testZerlegerHaeltNachrichtenZusammen() {
        let eins = MQTTPaket.publish(thema: "awtrix_a86b/status", nutzlast: Data("online".utf8))
        let zwei = MQTTPaket.publish(thema: "awtrix_a86b/customList",
                                     nutzlast: Data(#"{"apps":[],"count":0}"#.utf8))
        let strom = eins + zwei
        let schnitt = 9                                   // mitten im ersten Thema

        var zerleger = Paketstrom()
        XCTAssertTrue(zerleger.aufnehmen(strom.prefix(schnitt)).isEmpty,
                      "ein halbes Paket darf noch nichts ergeben")

        let pakete = zerleger.aufnehmen(strom.dropFirst(schnitt))
        XCTAssertEqual(pakete.count, 2, "beide Nachrichten aus einem Lesevorgang")
        XCTAssertEqual(MQTTPaket.publishGelesen(pakete[0])?.thema, "awtrix_a86b/status")
        XCTAssertEqual(MQTTPaket.publishGelesen(pakete[0])?.nutzlast, Data("online".utf8))
        XCTAssertEqual(MQTTPaket.publishGelesen(pakete[1])?.thema, "awtrix_a86b/customList")
    }

    /// Eine Nutzlast von 40 KB kommt nie in einem Stueck — und ihre Restlaenge
    /// steht in drei Bytes, die selbst geteilt ankommen koennen.
    func testZerlegerWartetAufLangeNutzlast() {
        let nutzlast = Data(repeating: 0x2E, count: 40_000)
        let paket = MQTTPaket.publish(thema: "awtrix_a86b/customList", nutzlast: nutzlast)

        var zerleger = Paketstrom()
        var fertige: [Data] = []
        var versatz = 0
        while versatz < paket.count {
            let ende = min(versatz + 2, paket.count)      // haeppchenweise, auch die Laenge
            fertige += zerleger.aufnehmen(paket[versatz..<ende])
            versatz = ende
            if versatz < paket.count { XCTAssertTrue(fertige.isEmpty) }
        }
        XCTAssertEqual(fertige.count, 1)
        XCTAssertEqual(MQTTPaket.publishGelesen(fertige[0])?.nutzlast, nutzlast)
    }

    /// Ein kaputter Strom darf den Puffer nicht unbegrenzt wachsen lassen.
    func testZerlegerVerwirftUnlesbareLaenge() {
        var zerleger = Paketstrom()
        XCTAssertTrue(zerleger.aufnehmen(Data([0x30, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])).isEmpty)
        // Danach faengt er wieder sauber an.
        let paket = MQTTPaket.publish(thema: "a/b", nutzlast: Data("x".utf8))
        XCTAssertEqual(zerleger.aufnehmen(paket).count, 1)
    }

    // MARK: - Der Abonnent am Doppelgaenger

    func testAbonniertUndEmpfaengt() throws {
        let broker = try Brokerdoppel()
        defer { broker.stoppen() }

        let abonnent = MQTTAbonnent(zugang: broker.zugang, themen: ["awtrix_a86b/customList",
                                                                   "awtrix_a86b/status"])
        defer { abonnent.beenden() }

        let steht = expectation(description: "verbunden")
        abonnent.beiZustand = { verbunden, _ in if verbunden { steht.fulfill() } }
        let angekommen = expectation(description: "Nachricht")
        let fach = NachrichtenFach()
        abonnent.beiNachricht = { thema, nutzlast in
            fach.merken(thema, nutzlast)
            angekommen.fulfill()
        }
        abonnent.starten()

        wait(for: [steht], timeout: 5)
        // Der Abonnent meldet sich, sobald er die SUBSCRIBE abgeschickt hat —
        // beim Doppelgaenger sind sie deshalb noch nicht zwingend angekommen.
        XCTAssertTrue(broker.wartetAufAbo() && broker.wartetAufAbo(), "beide Abonnements kamen an")
        XCTAssertEqual(broker.abonnierteThemen, ["awtrix_a86b/customList", "awtrix_a86b/status"])

        broker.veroeffentliche(thema: "awtrix_a86b/customList",
                               nutzlast: Data(#"{"apps":[{"appName":"scrolltest"}],"count":1}"#.utf8))
        wait(for: [angekommen], timeout: 5)
        XCTAssertEqual(fach.thema, "awtrix_a86b/customList")
        XCTAssertEqual(fach.text, #"{"apps":[{"appName":"scrolltest"}],"count":1}"#)
    }

    /// Faellt die Verbindung weg, meldet der Abonnent das und versucht es von
    /// selbst erneut — sonst merkt die App nur, dass nichts mehr kommt.
    func testVerbindetNachAbrissErneut() throws {
        let broker = try Brokerdoppel()
        defer { broker.stoppen() }

        let abonnent = MQTTAbonnent(zugang: broker.zugang, themen: ["awtrix_a86b/status"])
        defer { abonnent.beenden() }

        let erstens = expectation(description: "zuerst verbunden")
        let abriss = expectation(description: "Abriss gemeldet")
        let zweitens = expectation(description: "wieder verbunden")
        var zaehler = 0
        abonnent.beiZustand = { verbunden, _ in
            if verbunden {
                zaehler += 1
                if zaehler == 1 { erstens.fulfill() } else if zaehler == 2 { zweitens.fulfill() }
            } else {
                abriss.fulfill()
            }
        }
        abonnent.starten()

        wait(for: [erstens], timeout: 5)
        broker.verbindungTrennen()
        wait(for: [abriss], timeout: 5)
        wait(for: [zweitens], timeout: 15)          // erster Abstand: zwei Sekunden
        XCTAssertGreaterThanOrEqual(broker.verbindungen, 2)
    }

    func testAbgelehnteAnmeldungWirdGemeldet() throws {
        let broker = try Brokerdoppel(connackCode: 4)
        defer { broker.stoppen() }

        let abonnent = MQTTAbonnent(zugang: broker.zugang, themen: ["awtrix_a86b/status"])
        defer { abonnent.beenden() }

        let gemeldet = expectation(description: "abgelehnt")
        let fach = NachrichtenFach()
        abonnent.beiZustand = { verbunden, grund in
            guard !verbunden, let grund else { return }
            fach.merken(grund, Data())
            gemeldet.fulfill()
        }
        abonnent.starten()

        wait(for: [gemeldet], timeout: 5)
        XCTAssertTrue(fach.thema?.contains("Kennwort") == true, "nennt den Grund: \(fach.thema ?? "—")")
    }
}

/// Traegt das, was auf der Warteschlange des Abonnenten ankommt, unter Schloss
/// zum Test hinueber.
private final class NachrichtenFach: @unchecked Sendable {
    private let sperre = NSLock()
    private var _thema: String?
    private var _nutzlast = Data()

    func merken(_ thema: String, _ nutzlast: Data) {
        sperre.lock(); defer { sperre.unlock() }
        _thema = thema; _nutzlast = nutzlast
    }
    var thema: String? { sperre.lock(); defer { sperre.unlock() }; return _thema }
    var text: String? { sperre.lock(); defer { sperre.unlock() }; return String(data: _nutzlast, encoding: .utf8) }
}

/// Ein Broker auf Loopback: nimmt an, beantwortet CONNECT, SUBSCRIBE und
/// PINGREQ und kann von sich aus veroeffentlichen. Das echte Geraet und der
/// echte Broker im Haus bleiben in Tests unberuehrt.
private final class Brokerdoppel: @unchecked Sendable {
    private let listener: NWListener
    private let connackCode: UInt8
    private let sperre = NSLock()
    private var _abos: [String] = []
    private var _verbindungen = 0
    private var aktuelle: NWConnection?
    private var port: UInt16 = 0
    private let aboGesehen = DispatchSemaphore(value: 0)

    var zugang: MQTTZugang {
        MQTTZugang(host: "127.0.0.1", port: port, benutzer: "pixdeck",
                   kennwort: "geheim", clientID: "tc002-app-horch")
    }
    var abonnierteThemen: [String] { sperre.lock(); defer { sperre.unlock() }; return _abos }
    var verbindungen: Int { sperre.lock(); defer { sperre.unlock() }; return _verbindungen }

    init(connackCode: UInt8 = 0) throws {
        self.connackCode = connackCode
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [weak self] verbindung in
            guard let self else { return }
            self.sperre.lock(); self._verbindungen += 1; self.aktuelle = verbindung; self.sperre.unlock()
            verbindung.start(queue: .global())
            self.lies(verbindung, strom: Paketstrom())
        }
        let bereit = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { if case .ready = $0 { bereit.signal() } }
        listener.start(queue: .global())
        guard bereit.wait(timeout: .now() + 5) == .success, let p = listener.port?.rawValue else {
            throw MQTTFehler.zeitueberschreitung
        }
        port = p
    }

    /// Wartet auf je ein eingetroffenes SUBSCRIBE.
    func wartetAufAbo(frist: TimeInterval = 5) -> Bool {
        aboGesehen.wait(timeout: .now() + frist) == .success
    }

    func stoppen() {
        listener.cancel()
        sperre.lock(); let v = aktuelle; aktuelle = nil; sperre.unlock()
        v?.cancel()
    }

    func verbindungTrennen() {
        sperre.lock(); let v = aktuelle; aktuelle = nil; sperre.unlock()
        v?.cancel()
    }

    func veroeffentliche(thema: String, nutzlast: Data) {
        sperre.lock(); let v = aktuelle; sperre.unlock()
        v?.send(content: MQTTPaket.publish(thema: thema, nutzlast: nutzlast), completion: .idempotent)
    }

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
        switch paket.first {
        case 0x10:
            v.send(content: Data([0x20, 0x02, 0x00, connackCode]), completion: .idempotent)
        case 0x82:
            guard let (thema, paketID) = Self.subscribeGelesen(paket) else { return }
            sperre.lock(); _abos.append(thema); sperre.unlock()
            aboGesehen.signal()
            v.send(content: Data([0x90, 0x03, UInt8(paketID >> 8), UInt8(paketID & 0xFF), 0x00]),
                   completion: .idempotent)
        case 0xC0:
            v.send(content: Data([0xD0, 0x00]), completion: .idempotent)
        default:
            break
        }
    }

    /// Die Gegenrichtung zu `MQTTPaket.subscribe` — nur fuer den Doppelgaenger,
    /// und absichtlich von Hand, damit der Test nicht dieselbe Funktion prueft,
    /// die er benutzt.
    private static func subscribeGelesen(_ paket: Data) -> (thema: String, paketID: UInt16)? {
        let b = [UInt8](paket)
        guard b.count > 6, b[0] == 0x82 else { return nil }
        let paketID = UInt16(b[2]) << 8 | UInt16(b[3])
        let laenge = Int(b[4]) << 8 | Int(b[5])
        guard b.count >= 6 + laenge,
              let thema = String(bytes: b[6..<(6 + laenge)], encoding: .utf8) else { return nil }
        return (thema, paketID)
    }
}
