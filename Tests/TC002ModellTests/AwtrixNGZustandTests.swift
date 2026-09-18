import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Was der Zustand der App anders macht, sobald eine Uhr eine AWTRIX NG ist.
///
/// Kein Broker, kein Geraet: `gemeldet` wird von Hand aufgerufen — dieselbe
/// Naht, die `AppZustandTests` fuer den Rueckkanal der Werksfirmware benutzt —
/// und `themen(fuer:)` ist ausdruecklich `static`, damit sich die Abonnements
/// nachrechnen lassen, ohne eines aufzubauen.
///
/// Der Schluesselbund wird nie angefasst (`Schluesselbunddoppelgaenger` aus
/// `AppZustandTests`), die Slotdateien liegen in einem Wegwerfordner.
@MainActor
final class AwtrixNGZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer",
                              // Zwei Schalter, die Tests umlegen — und die sonst
                              // in den naechsten Test hinueberleckten: Der
                              // abgeschaltete Verlauf liess dort jede
                              // Aufzeichnung ausfallen, und es sah aus, als
                              // zeichne er gar nicht auf.
                              "protokollAn", "verlaufAn"]
    private var sicherung: [String: Any?] = [:]
    private var schluesselbund = Schluesselbunddoppelgaenger()

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        schluesselbund = Schluesselbunddoppelgaenger()
        // Nichts von hier geht je ins Netz: `Belegungsdoppelgaenger` faengt
        // jede Anfrage ab (dieselbe Naht wie in `AppZustandTests`).
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

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private func mitUhr(_ uhr: Uhr) throws -> AppZustand {
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        return AppZustand(schluesselbund: schluesselbund)
    }

    private func ngUhr(praefix: String = "wohnzimmer/uhr") -> Uhr {
        Uhr(name: "Wohnzimmer", host: "10.0.0.9", praefix: praefix,
            typ: .awtrixNG, betriebsart: .mqtt)
    }

    private func mitUhren(_ uhren: [Uhr]) throws -> AppZustand {
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(uhren[0].id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set(uhren.map(\.id))), forKey: "zielIDs")
        return AppZustand(schluesselbund: schluesselbund)
    }

    private func werksUhr() -> Uhr {
        Uhr(name: "Kueche", host: "werk.example", praefix: "kueche/uhr",
            typ: .tc002, betriebsart: .mqtt)
    }

    // MARK: - Was zu hoch fuer die Zieluhren ist

    /// Gefragt wird die Zielmenge, nicht die angesehene Uhr — gesendet
    /// wird ja an sie. Und gesperrt wird nur, wenn keine davon es nimmt:
    /// Dieselbe Entscheidung, die der Editor fuer ein gemaltes Bild schon
    /// trifft — sonst verbaete eine einzelne NG unter fuenf Uhren allen
    /// anderen das 16er Icon.
    func testEineNGAlleinSperrtDasSechzehnerIcon() throws {
        let zustand = try mitUhr(ngUhr())
        XCTAssertNotNil(zustand.grafikSperre(hoehe: 16))
        XCTAssertNil(zustand.grafikSperre(hoehe: 8))
    }

    func testDieWerksfirmwareSperrtNichts() throws {
        let zustand = try mitUhr(werksUhr())
        XCTAssertNil(zustand.grafikSperre(hoehe: 16))
        XCTAssertNil(zustand.grafikSperre(hoehe: 8))
    }

    /// Eine NG neben einer Werksfirmware sperrt nichts: Die Sendung geht
    /// an die uebrige, und die eine meldet sich selbst.
    func testEineNGNebenEinerWerksfirmwareSperrtNichts() throws {
        let zustand = try mitUhren([werksUhr(), ngUhr()])
        XCTAssertNil(zustand.grafikSperre(hoehe: 16))
    }

    /// Ohne Ziel gibt es nichts zu sperren — was gesperrt waere, weiss man
    /// erst, wenn feststeht, wohin es geht.
    func testOhneZielWirdNichtsGesperrt() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        XCTAssertNil(zustand.grafikSperre(hoehe: 16))
    }

    // MARK: - Worauf gehorcht wird

    /// Die Werksfirmware veroeffentlicht ihre Anzeigenliste, NG nicht:
    /// „Eine Liste aller Anzeigen gibt es ueber MQTT nicht" — sie kommt dort
    /// allein ueber HTTP. Ein Abonnement auf `customList` liefe bei NG ins
    /// Leere, und `custom/#` ebenso.
    func testDieAbonnierteThemenHaengenAnDerGattung() {
        XCTAssertEqual(AppZustand.themen(fuer: Uhr(name: "a", host: "h", praefix: "awtrix_a86b")),
                       ["awtrix_a86b/customList", "awtrix_a86b/status", "awtrix_a86b/custom/#"])
        XCTAssertEqual(AppZustand.themen(fuer: ngUhr()),
                       ["wohnzimmer/uhr/availability", "wohnzimmer/uhr/cmd/apps/pushed/#"])
    }

    // MARK: - Was hereinkommt

    /// NG meldet sich unter `availability` und nicht unter `status` — und mit
    /// zwei Woertern statt einem, weil `offline` als Last Will beim Broker
    /// hinterlegt ist.
    func testErreichbarkeitKommtVonAvailability() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)

        zustand.gemeldet(thema: "wohnzimmer/uhr/availability", nutzlast: Data("online".utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        XCTAssertEqual(zustand.geraetOnline[uhr.id], true)

        zustand.gemeldet(thema: "wohnzimmer/uhr/availability", nutzlast: Data("offline".utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        XCTAssertEqual(zustand.geraetOnline[uhr.id], false)
    }

    /// Der einzige Ort, an dem eine abgewiesene Sendung ueberhaupt auftaucht.
    /// Auf der MQTT-Ebene war alles in Ordnung: Der Broker hat die
    /// Veroeffentlichung angenommen, das Protokoll sagt „gesendet". Ohne
    /// diese Zeile bliebe es dabei, und nur die Uhr waere dunkel.
    func testEineAbweisungAufResultWirdSichtbar() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)

        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung1/result",
                         nutzlast: Data(#"{"ok":false,"error":{"code":"validationFailed","field":"durationMs"}}"#.utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        let meldung = try XCTUnwrap(zustand.fehler)
        XCTAssertTrue(meldung.contains("validationFailed"), "war stattdessen: \(meldung)")
        XCTAssertTrue(meldung.contains("meldung1"))
    }

    /// Und Erfolg bleibt still. Eine Fehlerzeile bei jeder geglueckten Sendung
    /// waere schlimmer als keine.
    func testEineGeglueckteSendungMeldetNichts() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung1/result",
                         nutzlast: Data(#"{"ok":true}"#.utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))
        XCTAssertNil(zustand.fehler)
    }

    /// Genau null Bytes loeschen die Anzeige — bei NG wie bei der
    /// Werksfirmware, gleich von wem geschickt. Der Platz zaehlt danach wieder
    /// als frei.
    func testEineLeereNutzlastRaeumtDenPlatz() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        zustand.anzeigeGemerkt("meldung1", fuer: uhr.id)

        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung1", nutzlast: Data(),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        XCTAssertFalse(zustand.anzeigenAufUhr(uhr.id).contains("meldung1"))
    }

    /// Eine mitgelesene fremde Sendung belegt den Platz. Bei NG kommt die
    /// Belegung sonst nur aus einem HTTP-Abruf von vorhin — sie kaeme also erst
    /// bei der naechsten Abfrage nach.
    func testEineMitgeleseneSendungBelegtDenPlatz() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        zustand.gemeldeteAnzeigen[uhr.id] = []

        zustand.gemeldet(thema: "wohnzimmer/uhr/cmd/apps/pushed/meldung3",
                         nutzlast: Data(#"{"text":"von wem anders"}"#.utf8),
                         fuer: uhr.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        XCTAssertEqual(zustand.anzeigenAufUhr(uhr.id), ["meldung3"])
    }

    // MARK: - Was ein Block zeigen darf

    /// Ein NG-Block zeigt ein Bild, weil `Anzeigemass` auf die 32×8 der Uhr
    /// rastert und `Meldungsoptionen.naeherung` dieselbe Naeherungsschrift
    /// setzt, die die Vorschau ohnehin zeigt — dasselbe Bild mit derselben
    /// Einschraenkung wie bei der Werksfirmware. Nichts zu zeigen waere die
    /// staerkere Behauptung: „wir wissen es nicht", obwohl wir es selbst
    /// geschickt haben.
    func testEinNGBlockZeigtDasBildAufIhremEigenenMass() throws {
        let uhr = ngUhr()
        let zustand = try mitUhr(uhr)
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        gedaechtnis.merken(Meldungsoptionen(text: "Bus kommt"), icon: nil, iconKante: 8, fuer: uhr.id, platz: 2)

        guard case let .bekannt(pixel) = zustand.slotzustand(2, belegt: true, gedaechtnis: gedaechtnis) else {
            return XCTFail("Der Block zeigt nichts, obwohl der Stand gemerkt ist.")
        }
        XCTAssertEqual(pixel.count, 32 * 8,
                       "Auf einer NG gehoert das Bild auf ihre 32×8, nicht auf die 52×16 der Werksfirmware.")
        XCTAssertTrue(pixel.contains { $0 != nil }, "Vom Text ist nichts uebriggeblieben.")
    }

    /// Und die Gegenprobe zur Gegenprobe: Derselbe gemerkte Stand ergibt auf
    /// den beiden Gattungen verschieden viele Punkte. Ohne diese Zusicherung
    /// ginge der Test oben auch dann durch, wenn das Mass gar nicht ankaeme.
    func testDerselbeStandErgibtAufBeidenGattungenVerschiedeneBilder() throws {
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let ng = ngUhr()
        let ngZustand = try mitUhr(ng)
        gedaechtnis.merken(Meldungsoptionen(text: "Bus"), icon: nil, iconKante: 8, fuer: ng.id, platz: 2)
        guard case let .bekannt(ngPixel) = ngZustand.slotzustand(2, belegt: true, gedaechtnis: gedaechtnis) else {
            return XCTFail("NG zeigt nichts")
        }

        let werk = Uhr(name: "Küche", host: "werk.example", praefix: "awtrix_a86b")
        let werkZustand = try mitUhr(werk)
        gedaechtnis.merken(Meldungsoptionen(text: "Bus"), icon: nil, iconKante: 8, fuer: werk.id, platz: 2)
        guard case let .bekannt(werkPixel) = werkZustand.slotzustand(2, belegt: true, gedaechtnis: gedaechtnis) else {
            return XCTFail("Werksfirmware zeigt nichts")
        }

        XCTAssertEqual(ngPixel.count, 32 * 8)
        XCTAssertEqual(werkPixel.count, 52 * 16)
    }

    /// Die Gegenprobe mit demselben Gedaechtnisstand: Auf der
    /// Werksfirmware ist genau dieses Bild richtig, und der Riegel darf es
    /// nicht mitnehmen.
    func testDerselbeStandZeigtAufDerWerksfirmwareSehrWohlEinBild() throws {
        let uhr = Uhr(name: "Küche", host: "10.0.0.1", praefix: "awtrix_a86b")
        let zustand = try mitUhr(uhr)
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let optionen = Meldungsoptionen(text: "Bus kommt")
        gedaechtnis.merken(optionen, icon: nil, iconKante: 8, fuer: uhr.id, platz: 2)

        XCTAssertEqual(zustand.slotzustand(2, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(Meldungsbau.feld(optionen, mitIcon: false).punkteRoh))
    }

    // MARK: - Die Geraeteart von Hand

    /// Praefix und MAC gehoeren nach einem Wechsel der anderen Firmware: Die
    /// Werksfirmware haengt die letzten vier MAC-Stellen an, NG nicht. Blieben
    /// sie stehen, ginge die naechste Sendung auf ein Thema, auf dem kein
    /// Geraet hoert — und beide Gattungen schweigen dazu.
    func testEinWechselDerGeraeteartWirftDasPraefixWeg() throws {
        var uhr = Uhr(name: "Küche", host: "10.0.0.1", praefix: "awtrix_a86b",
                      mac: "aabbccdda86b", betriebsart: .mqtt)
        let zustand = try mitUhr(uhr)
        zustand.verbunden[uhr.id] = true

        uhr.typ = .awtrixNG
        zustand.uhren[0].typ = .awtrixNG
        zustand.geraeteartGeaendert(uhr.id, sitzung: Belegungsdoppelgaenger.sitzung())

        XCTAssertEqual(zustand.uhren[0].praefix, "")
        XCTAssertEqual(zustand.uhren[0].mac, "")
        XCTAssertNil(zustand.verbunden[uhr.id] ?? nil)
    }
}
