import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Die Tests fassen nur die Einstellungs-Schluessel `uhren`, `aktiveID`,
/// `bekannteAnzeigen` und `zielIDs` an — nie den Schluesselbund, nie eine echte
/// Uhr oder einen echten Broker. Vor und nach jedem Test wird der Bestand
/// dieser Schluessel im Testprozess gesichert und wiederhergestellt.
@MainActor
final class AppZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs"]
    private var sicherung: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    /// Die alte, uhrenlose Anzeigenliste muss genau einmal auf die aktive Uhr
    /// uebernommen werden. Bliebe der alte Schluessel stehen, wanderte sie bei
    /// jedem Start erneut — und zwar an die dann jeweils aktive Uhr.
    func testAlteAnzeigenlisteWirdNurEinmalUebernommen() throws {
        let id = UUID()
        let uhr = Uhr(id: id, name: "Küche", host: "10.0.0.5")
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(id.uuidString, forKey: "aktiveID")
        d.set(["Alt1", "Alt2"], forKey: "bekannteAnzeigen")

        let zustand = AppZustand()

        XCTAssertEqual(zustand.bekannteAnzeigen[id], ["Alt1", "Alt2"])
        XCTAssertNil(d.stringArray(forKey: "bekannteAnzeigen"),
                      "Der alte Schlüssel muss nach der Übernahme verschwinden, sonst wandert die Liste bei jedem Start erneut.")
    }

    /// UUID(uuidString:) ist gegenueber Gross-/Kleinschreibung nachsichtig: zwei von
    /// Hand verbogene Schluessel in unterschiedlicher Schreibweise ergeben dieselbe
    /// UUID. Das darf die App beim Start nicht zum Absturz bringen.
    func testDoppelteUuidUnterschiedlicherSchreibweiseStuerztNichtAb() throws {
        let text = "3F2504E0-4F89-11D3-9A0C-0305E82C3301"
        let flach = [text: ["A"], text.lowercased(): ["B"]]
        d.set(try JSONEncoder().encode(flach), forKey: "bekannteAnzeigen")
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")

        let zustand = AppZustand() // darf nicht abstürzen

        let id = try XCTUnwrap(UUID(uuidString: text))
        XCTAssertEqual(zustand.bekannteAnzeigen.count, 1)
        let liste = try XCTUnwrap(zustand.bekannteAnzeigen[id])
        XCTAssertTrue(liste == ["A"] || liste == ["B"])
    }

    /// Leere Auswahl heisst: gesendet wird an die aktive Uhr — sonst liefe ein
    /// Sendeversuch ohne jede Wahl stillschweigend ins Leere.
    func testLeereAuswahlFaelltAufAktiveUhrZurueck() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.aktiveID = b.id

        XCTAssertTrue(zustand.zielIDs.isEmpty)
        XCTAssertEqual(zustand.ziele(), [b])
    }

    /// Eine entfernte Uhr darf in der Auswahl nicht als Geist weiterleben.
    func testEntfernteUhrVerschwindetAusDerAuswahl() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.zielIDs = [a.id, b.id]

        zustand.uhrEntfernen(a.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        XCTAssertFalse(zustand.zielIDs.contains(a.id))
        XCTAssertEqual(zustand.ziele(), [b])
    }

    /// Eine gewaehlte Uhr ohne Praefix darf nicht als Sendeziel auftauchen — sie
    /// kann noch gar nichts empfangen, weil sie nie abgefragt wurde.
    func testUhrenOhnePraefixWerdenUebersprungen() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1") // kein Präfix — nie abgefragt
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.zielIDs = [a.id, b.id]

        XCTAssertEqual(zustand.ziele(), [b])
    }

    /// Wird die einzige gewaehlte Uhr entfernt, muss zielIDs sofort wieder
    /// alle verbleibenden Uhren waehlen — sonst zaehlte die Menge als "keine
    /// Auswahl", und Einstellungen.ziele() (alle) und ziele() (die aktive Uhr)
    /// zeigten wieder auf verschiedene Ziele.
    func testEntfernenDerEinzigenAuswahlWaehltAlleVerbleibenden() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.zielIDs = [a.id]

        zustand.uhrEntfernen(a.id, gedaechtnis: Slotgedaechtnis(ordner: temp()))

        XCTAssertFalse(zustand.zielIDs.isEmpty)
        XCTAssertEqual(zustand.zielIDs, [b.id])
        XCTAssertEqual(zustand.ziele(), [b])
    }

    /// Eine Installation von vor dem Zielmenue hat Uhren, aber nie eine
    /// ausdrueckliche Auswahl geschrieben — zielIDs steht leer in den
    /// Einstellungen. Der Start muss das auf "alle" aufloesen, sonst zeigte
    /// die App fortan nur die aktive Uhr, waehrend Werkzeug und Kurzbefehle
    /// weiter alle ansprechen.
    func testAlteInstallationOhneAuswahlBekommtAlleUhrenBeimStart() throws {
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        d.set(try JSONEncoder().encode([a, b]), forKey: "uhren")
        d.set(a.id.uuidString, forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")

        let zustand = AppZustand()

        XCTAssertEqual(zustand.zielIDs, Set([a.id, b.id]))
        XCTAssertEqual(zustand.ziele(), [a, b])
    }

    // MARK: Slot-Blöcke

    /// Ein frischer, noch nicht angelegter Ordnerpfad unter dem temporaeren
    /// Verzeichnis — nie unter „Application Support/MQTT-TC002": dort liegen
    /// die echten Slotdateien einer Installation.
    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    /// Ein belegter Platz ohne mitgelesene Pixel zeigt trotzdem etwas, sobald
    /// das Gedaechtnis einen Stand dafuer hat — neu gerechnet ueber
    /// `Meldungsbau`, nicht aus der Nutzlast zurueckgewonnen. Ohne diesen
    /// Rueckfall saehe ein gerade selbst gefuellter Platz nach einem Neustart
    /// „unbekannt" aus.
    func testSlotzustandFaelltAufDasGedaechtnisZurueck() throws {
        let uhr = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let optionen = Meldungsoptionen(text: "Bus kommt")
        gedaechtnis.merken(optionen, icon: nil, fuer: uhr.id, platz: 2)

        let zustand = AppZustand()

        XCTAssertEqual(zustand.slotzustand(2, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(Meldungsbau.feld(optionen, mitIcon: false).punkteRoh))
        XCTAssertEqual(zustand.slotzustand(3, belegt: true, gedaechtnis: gedaechtnis), .unbekannt)
        XCTAssertEqual(zustand.slotzustand(2, belegt: false, gedaechtnis: gedaechtnis), .frei)
    }

    /// Die Bloecke richten sich nach der **aktiven** Uhr, nicht nach der
    /// ersten Zieluhr: Bei mehreren Zieluhren waere „die erste" willkuerlich,
    /// und zwei Ansichten derselben Sitzung zeigten verschiedene Bilder.
    func testSlotzustandRichtetSichNachDerAktivenUhr() throws {
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Büro", host: "10.0.0.2", praefix: "pb")
        d.set(try JSONEncoder().encode([a, b]), forKey: "uhren")
        d.set(b.id.uuidString, forKey: "aktiveID")
        // Ausdruecklich, nicht dem Rueckfall in `init` ueberlassen: Laege im
        // Testprozess ein abweichendes `zielIDs`, haenge das Ergebnis daran
        // statt an der Regression, um die es hier geht.
        d.set(try JSONEncoder().encode(Set([a.id, b.id])), forKey: "zielIDs")
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let pixel = Meldungsbau.feld(Meldungsoptionen(text: "nur auf a"), mitIcon: false).punkteRoh

        let zustand = AppZustand()
        zustand.slotInhalt[a.id] = [1: Slotbild(pixel: pixel)]

        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis), .unbekannt,
                       "Das Bild der ersten Uhr darf nicht für die aktive Uhr einstehen.")
    }

    /// Der eine Griff des iPhone-Titelmenues: Umschalten wechselt die
    /// angesehene Uhr **und** das Sendeziel. Setzte es nur `zielIDs` — so war
    /// es —, zeigten die fuenf Bloecke weiter den Stand der vorigen Uhr,
    /// waehrend an die neue gesendet wird.
    func testUmschaltenNimmtBloeckeUndZielMit() throws {
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Büro", host: "10.0.0.2", praefix: "pb")
        d.set(try JSONEncoder().encode([a, b]), forKey: "uhren")
        d.set(a.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([a.id])), forKey: "zielIDs")
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let aufA = Meldungsbau.feld(Meldungsoptionen(text: "auf a"), mitIcon: false).punkteRoh
        let aufB = Meldungsbau.feld(Meldungsoptionen(text: "auf b"), mitIcon: false).punkteRoh
        XCTAssertNotEqual(aufA, aufB, "Sonst könnte der Test gar nicht unterscheiden.")

        let zustand = AppZustand()
        zustand.slotInhalt[a.id] = [1: Slotbild(pixel: aufA)]
        zustand.slotInhalt[b.id] = [1: Slotbild(pixel: aufB)]
        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis), .bekannt(aufA))

        zustand.uhrAnsehen(b.id)

        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis), .bekannt(aufB),
                       "Die Blöcke müssen der angesehenen Uhr folgen, nicht der vorher angesehenen.")
        XCTAssertEqual(zustand.ziele(), [b],
                       "Wer am Telefon umschaltet, sendet auch dorthin.")
    }

    /// Beim Senden an mehrere Uhren laesst das Umschalten die Zielmenge
    /// stehen — sonst schruempfte „an alle“ beim blossen Nachsehen unbemerkt
    /// auf eine Uhr zusammen. Angesehen wird trotzdem die neue, und das
    /// Abschalten faellt auf genau sie zurueck, nie auf eine leere Menge.
    func testUmschaltenLaesstMehrereZieleStehen() throws {
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Büro", host: "10.0.0.2", praefix: "pb")
        d.set(try JSONEncoder().encode([a, b]), forKey: "uhren")
        d.set(a.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([a.id])), forKey: "zielIDs")

        let zustand = AppZustand()
        XCTAssertFalse(zustand.anMehrereUhren)
        zustand.anMehrereUhren = true
        XCTAssertEqual(zustand.zielIDs, Set([a.id, b.id]))

        zustand.uhrAnsehen(b.id)

        XCTAssertEqual(zustand.aktiveID, b.id)
        XCTAssertEqual(zustand.zielIDs, Set([a.id, b.id]),
                       "Nachsehen darf die Zielmenge nicht zusammenstreichen.")

        zustand.anMehrereUhren = false
        XCTAssertEqual(zustand.zielIDs, [b.id],
                       "Abschalten fällt auf die angesehene Uhr zurück, nicht auf die vorige.")
    }

    /// Eine Uhr, eine Zieluhr, sie selbst aktiv — die uebliche Buehne fuer die
    /// Bloecke. Sie steht in den Einstellungen des Testprozesses, weil
    /// `AppZustand.init` von dort liest; `zielIDs` ausdruecklich, damit kein
    /// Rueckfall die Buehne baut.
    private func buehne(praefix: String = "pa") throws -> Uhr {
        let uhr = Uhr(name: "Küche", host: "10.0.0.1", praefix: praefix)
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        return uhr
    }

    /// Eine Nutzlast, die sich nicht in Pixel zerlegen laesst — ein Lauf-GIF
    /// oder der Weg „als Text" —, sagt zweierlei: Auf dem Platz liegt etwas
    /// Neues, und wir kennen es nicht. Bliebe der alte Eintrag stehen, zeigte
    /// der Block weiter das vorige Bild, obwohl auf der Uhr nachweislich etwas
    /// anderes steht, und nichts meldete es.
    func testUnzerlegbareNutzlastLoeschtDenAltenSlotinhalt() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let zustand = AppZustand()

        let hallo = Data("{\"draw\":[{\"df\":[0,0,2,2,\"#00FF66\"]}]}".utf8)
        zustand.gemeldet(thema: "pa/custom/meldung1", nutzlast: hallo, fuer: uhr.id)
        XCTAssertNotNil(zustand.slotInhalt[uhr.id]?[1], "Der Pixel-Weg muss ankommen.")

        let laufschrift = Data("{\"image\":\"data:image/gif;base64,R0lGODlh\"}".utf8)
        zustand.gemeldet(thema: "pa/custom/meldung1", nutzlast: laufschrift, fuer: uhr.id)

        XCTAssertNil(zustand.slotInhalt[uhr.id]?[1],
                     "Was nicht zerlegbar ist, darf den alten Eintrag nicht stehenlassen.")
        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis), .unbekannt,
                       "Ohne gemerkten Stand bleibt nur „belegt, Inhalt unbekannt“.")
    }

    // MARK: Löschen wirft die Erinnerung weg

    /// Wer einen Platz raeumt, wirft die Erinnerung an ihn weg. Ohne das laege
    /// nach dem Loeschen weiter der Stand der letzten eigenen Textsendung da,
    /// und `slotzustand` rechnete daraus wieder ein Bild — den Text, der seit
    /// dem Loeschen nicht mehr auf dem Platz steht.
    func testLoeschenWirftDieErinnerungAnDenPlatzWeg() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        gedaechtnis.merken(Meldungsoptionen(text: "alter Text"), icon: nil, fuer: uhr.id, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "bleibt"), icon: nil, fuer: uhr.id, platz: 2)
        let zustand = AppZustand()
        zustand.bekannteAnzeigen[uhr.id] = ["meldung1", "meldung2"]

        zustand.anzeigeGeloescht("meldung1", fuer: uhr, gedaechtnis: gedaechtnis)

        XCTAssertNil(gedaechtnis.gemerkt(fuer: uhr.id, platz: 1),
                     "Ein geräumter Platz darf keine Erinnerung zurücklassen.")
        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis), .unbekannt,
                       "Wird der Platz später von fremder Hand belegt, bleibt nur „Inhalt unbekannt“.")
        XCTAssertNotNil(gedaechtnis.gemerkt(fuer: uhr.id, platz: 2),
                        "Nur der gelöschte Platz verliert seine Erinnerung.")
        XCTAssertEqual(zustand.anzeigenAufUhr(uhr.id), ["meldung2"])
    }

    /// Nur die fuenf Meldungsplaetze haben ueberhaupt eine Erinnerung. Ein frei
    /// gewaehlter Anzeigename — die Vorgabe des Werkzeugs ist „cli" — ist kein
    /// Platz; eine Loeschung unter diesem Namen darf die Erinnerung an Platz 1
    /// nicht mitreissen.
    func testLoeschenEinesFremdenNamensRuehrtDieErinnerungNichtAn() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        gedaechtnis.merken(Meldungsoptionen(text: "Platz 1"), icon: nil, fuer: uhr.id, platz: 1)
        let zustand = AppZustand()
        zustand.bekannteAnzeigen[uhr.id] = ["cli", "meldung1"]

        zustand.anzeigeGeloescht("cli", fuer: uhr, gedaechtnis: gedaechtnis)

        XCTAssertNotNil(gedaechtnis.gemerkt(fuer: uhr.id, platz: 1),
                        "„cli“ ist kein Platz — es gibt dort nichts zu vergessen.")
        XCTAssertEqual(zustand.anzeigenAufUhr(uhr.id), ["meldung1"])
    }

    /// Eine leere Nutzlast ist die unmittelbare Auskunft der Uhr, dass die
    /// Anzeige entfernt wurde — gleich von wem. Bliebe der Name in der
    /// Belegung stehen, zeigte der Block die Erinnerung an einen leeren Platz.
    func testLeereNutzlastGibtDenPlatzFreiUndVergisstIhn() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        gedaechtnis.merken(Meldungsoptionen(text: "stand mal da"), icon: nil, fuer: uhr.id, platz: 1)
        let zustand = AppZustand()
        zustand.bekannteAnzeigen[uhr.id] = ["meldung1"]
        zustand.gemeldeteAnzeigen[uhr.id] = ["meldung1"]
        let gemalt = Data("{\"draw\":[{\"df\":[0,0,2,2,\"#00FF66\"]}]}".utf8)
        zustand.gemeldet(thema: "pa/custom/meldung1", nutzlast: gemalt, fuer: uhr.id,
                         gedaechtnis: gedaechtnis)

        // Was `Anzeigen.loeschen` schickt: genau null Bytes (§3.2).
        zustand.gemeldet(thema: "pa/custom/meldung1", nutzlast: Data(), fuer: uhr.id,
                         gedaechtnis: gedaechtnis)

        XCTAssertEqual(zustand.anzeigenAufUhr(uhr.id), [],
                       "Die leere Nutzlast sagt: der Platz ist wieder leer.")
        XCTAssertEqual(zustand.bekannteAnzeigen[uhr.id], [],
                       "Auch die eigene Buchführung, sonst käme der Name nach dem Abriss zurück.")
        XCTAssertNil(zustand.slotInhalt[uhr.id]?[1])
        XCTAssertNil(gedaechtnis.gemerkt(fuer: uhr.id, platz: 1),
                     "Ein geräumter Platz darf keine Erinnerung zurücklassen.")
    }

    /// Die Gegenprobe zur leeren Nutzlast: Eine nicht zerlegbare sagt nur, dass
    /// dort etwas Unlesbares liegt — der Platz bleibt belegt, und die
    /// Erinnerung bleibt stehen. Wer beide Faelle in einen Zweig faltet,
    /// meldete hier einen freien Platz, obwohl ein Lauf-GIF darauf laeuft.
    func testUnzerlegbareNutzlastLaesstBelegungUndErinnerungStehen() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        gedaechtnis.merken(Meldungsoptionen(text: "stand mal da"), icon: nil, fuer: uhr.id, platz: 1)
        let zustand = AppZustand()
        zustand.bekannteAnzeigen[uhr.id] = ["meldung1"]

        let laufschrift = Data("{\"image\":\"data:image/gif;base64,R0lGODlh\"}".utf8)
        zustand.gemeldet(thema: "pa/custom/meldung1", nutzlast: laufschrift, fuer: uhr.id,
                         gedaechtnis: gedaechtnis)

        XCTAssertEqual(zustand.anzeigenAufUhr(uhr.id), ["meldung1"],
                       "Auf dem Platz liegt etwas — er ist nicht frei.")
        XCTAssertNotNil(gedaechtnis.gemerkt(fuer: uhr.id, platz: 1),
                        "Nur ein geräumter Platz verliert seine Erinnerung, kein überschriebener.")
    }

    // MARK: Zwischenspeicher der gerechneten Pixel

    /// Nach einer eigenen Sendung: `senden` merkt den neuen Stand, und der
    /// Block muss ihn zeigen. Ein Zwischenspeicher ueber (Uhr, Platz) statt
    /// ueber den gemerkten Stand selbst liesse hier das alte Bild stehen.
    func testGerechnetePixelVerfallenNachEigenerSendung() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let alt = Meldungsoptionen(text: "alt")
        let neu = Meldungsoptionen(text: "ganz neu")
        gedaechtnis.merken(alt, icon: nil, fuer: uhr.id, platz: 1)
        let zustand = AppZustand()
        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(Meldungsbau.feld(alt, mitIcon: false).punkteRoh))

        gedaechtnis.merken(neu, icon: nil, fuer: uhr.id, platz: 1)

        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(Meldungsbau.feld(neu, mitIcon: false).punkteRoh),
                       "Nach dem Merken neuer Regler darf nicht das alte Bild stehenbleiben.")
    }

    /// Nach einer eingetroffenen Nachricht: Mitgelesene Pixel schlagen das
    /// Gedaechtnis. Ein Zwischenspeicher, der das ganze Ergebnis je (Uhr,
    /// Platz) haelt, zeigte hier weiter die Erinnerung.
    func testGerechnetePixelVerfallenNachEingetroffenerNachricht() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let gemerkt = Meldungsoptionen(text: "gemerkt")
        gedaechtnis.merken(gemerkt, icon: nil, fuer: uhr.id, platz: 1)
        let zustand = AppZustand()
        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(Meldungsbau.feld(gemerkt, mitIcon: false).punkteRoh))

        let fremd = Data("{\"draw\":[{\"df\":[0,0,2,2,\"#00FF66\"]}]}".utf8)
        zustand.gemeldet(thema: "pa/custom/meldung1", nutzlast: fremd, fuer: uhr.id)

        let mitgelesen = try XCTUnwrap(zustand.slotInhalt[uhr.id]?[1]).pixel
        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(mitgelesen),
                       "Mitgelesene Pixel schlagen die Erinnerung — auch beim zweiten Blick.")
    }

    /// Nach einem Verbindungsabriss: `slotInhalt` faellt weg, und der Block
    /// muss wieder auf die Erinnerung zurueckfallen statt die letzten
    /// mitgelesenen Pixel festzuhalten, die nun niemand mehr bestaetigt.
    func testGerechnetePixelVerfallenNachVerbindungsabriss() throws {
        let uhr = try buehne()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let gemerkt = Meldungsoptionen(text: "gemerkt")
        gedaechtnis.merken(gemerkt, icon: nil, fuer: uhr.id, platz: 1)
        let zustand = AppZustand()
        let fremd = Data("{\"draw\":[{\"df\":[0,0,2,2,\"#00FF66\"]}]}".utf8)
        zustand.gemeldet(thema: "pa/custom/meldung1", nutzlast: fremd, fuer: uhr.id)
        let mitgelesen = try XCTUnwrap(zustand.slotInhalt[uhr.id]?[1]).pixel
        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(mitgelesen))

        // Was `horchzustand` beim Abriss tut (`slotInhalt[id] = nil`).
        zustand.slotInhalt[uhr.id] = nil

        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(Meldungsbau.feld(gemerkt, mitIcon: false).punkteRoh),
                       "Ohne Verbindung gilt wieder die Erinnerung, nicht der letzte Mitschnitt.")
    }

    /// Mit der Uhr geht auch ihre Slotdatei. Die Kennung einer entfernten Uhr
    /// kommt nicht zurueck — die Datei laege sonst fuer immer unter
    /// Application Support, ohne dass sie noch jemand liest.
    func testEntfernteUhrVerliertIhreSlotdatei() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        gedaechtnis.merken(Meldungsoptionen(text: "A"), icon: nil, fuer: a.id, platz: 1)
        gedaechtnis.merken(Meldungsoptionen(text: "B"), icon: nil, fuer: b.id, platz: 1)

        zustand.uhrEntfernen(a.id, gedaechtnis: gedaechtnis)

        XCTAssertNil(gedaechtnis.gemerkt(fuer: a.id, platz: 1))
        XCTAssertNotNil(gedaechtnis.gemerkt(fuer: b.id, platz: 1),
                        "Nur die Datei der entfernten Uhr darf verschwinden.")
    }
}
