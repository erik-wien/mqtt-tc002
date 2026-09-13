import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Der Schluesselbund der Tests. Er merkt sich, wonach gefragt und was
/// geschrieben wurde, und faehrt den echten nie an — der zieht auf dem Rechner
/// eines Menschen einen Dialog auf, und sein Inhalt gehoert nicht in die
/// Fehlerausgabe von XCTest.
final class Schluesselbunddoppelgaenger: Schluesselbundzugriff {
    var eintraege: [String: String]
    /// Gelingt das Schreiben nicht, muss `kennwortSichern()` das melden.
    var gelingt = true
    private(set) var gelesen: [String] = []
    private(set) var geschrieben: [(konto: String, wert: String)] = []

    init(_ eintraege: [String: String] = [:]) { self.eintraege = eintraege }

    func lesen(_ konto: String) -> String? {
        gelesen.append(konto)
        return eintraege[konto]
    }

    func setzen(_ wert: String, fuer konto: String) -> Bool {
        geschrieben.append((konto, wert))
        guard gelingt else { return false }
        eintraege[konto] = wert
        return true
    }
}

/// Die Tests fassen nur die Einstellungs-Schluessel `uhren`, `aktiveID`,
/// `bekannteAnzeigen`, `zielIDs` und `brokerHost` an — nie den Schluesselbund,
/// nie eine echte Uhr oder einen echten Broker. Vor und nach jedem Test wird
/// der Bestand dieser Schluessel im Testprozess gesichert und wiederhergestellt.
@MainActor
final class AppZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer"]
    private var sicherung: [String: Any?] = [:]
    private var schluesselbund = Schluesselbunddoppelgaenger()

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        schluesselbund = Schluesselbunddoppelgaenger()
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

    /// Die alte, uhrenlose Anzeigenliste muss genau einmal auf die aktive Uhr
    /// uebernommen werden. Bliebe der alte Schluessel stehen, wanderte sie bei
    /// jedem Start erneut — und zwar an die dann jeweils aktive Uhr.
    func testAlteAnzeigenlisteWirdNurEinmalUebernommen() throws {
        let id = UUID()
        let uhr = Uhr(id: id, name: "Küche", host: "10.0.0.5")
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(id.uuidString, forKey: "aktiveID")
        d.set(["Alt1", "Alt2"], forKey: "bekannteAnzeigen")

        let zustand = AppZustand(schluesselbund: schluesselbund)

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

        let zustand = AppZustand(schluesselbund: schluesselbund) // darf nicht abstürzen

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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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

        let zustand = AppZustand(schluesselbund: schluesselbund)

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

        let zustand = AppZustand(schluesselbund: schluesselbund)

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

        let zustand = AppZustand(schluesselbund: schluesselbund)
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

        let zustand = AppZustand(schluesselbund: schluesselbund)
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

        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)

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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
        let zustand = AppZustand(schluesselbund: schluesselbund)
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
    /// Woran „noch nichts eingerichtet" haengt: an einer Uhr **und** an einer
    /// eingetragenen Brokeradresse. Seit die Vorgabe leer ist, sagt der Wert
    /// das selbst — eine frische Installation hat keine Adresse, und nur eine
    /// Eingabe macht daraus eine.
    func testEingerichtetVerlangtUhrUndEingetragenenBroker() throws {
        let uhr = Uhr(name: "Küche", host: "10.0.0.5")

        // Frische Installation: keine Uhr, kein abgelegter Broker.
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "brokerHost")
        XCTAssertFalse(AppZustand(schluesselbund: schluesselbund).eingerichtet)

        // Uhr da, Broker nur als Vorgabe — und die ist leer.
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        let nurUhr = AppZustand(schluesselbund: schluesselbund)
        XCTAssertEqual(nurUhr.brokerHost, "",
                       "die Vorgabe darf keine Adresse vortaeuschen")
        XCTAssertFalse(nurUhr.eingerichtet)

        // Broker eingetragen, aber keine Uhr.
        d.removeObject(forKey: "uhren")
        d.set("10.0.0.2", forKey: "brokerHost")
        XCTAssertFalse(AppZustand(schluesselbund: schluesselbund).eingerichtet)

        // Beides.
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        XCTAssertTrue(AppZustand(schluesselbund: schluesselbund).eingerichtet)

        // Wer die Adresse spaeter leert, steht wieder in derselben Sackgasse.
        d.set("", forKey: "brokerHost")
        XCTAssertFalse(AppZustand(schluesselbund: schluesselbund).eingerichtet)
    }

    // MARK: - Betriebsart

    /// **Die Vorgabe steht hier und nirgends sonst.** `Uhr.betriebsart` ist ein
    /// Optional, und `nil` heisst dort `.mqtt` — das darf es, weil jede neu
    /// angelegte Uhr `.http` ausdruecklich mitbekommt. Bliebe es hier weg,
    /// waere `nil` zweideutig: einmal „aus dem Bestand", einmal „eben
    /// angelegt", und dieselbe Lesart traefe beide falsch.
    func testNeueUhrBekommtHttpAusdruecklich() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand(schluesselbund: schluesselbund)

        zustand.uhrHinzufuegen(host: "10.0.0.7", sitzung: Belegungsdoppelgaenger.sitzung())

        XCTAssertEqual(zustand.uhren.first?.betriebsart, .http,
                       "der Schlüssel muss in der Datei stehen, nicht bloß gelten")
        XCTAssertEqual(zustand.uhren.first?.wirksameBetriebsart, .http)
    }

    /// Fuer eine reine HTTP-Einrichtung ist die Brokerbedingung falsch: Dort
    /// gibt es keinen Broker und braucht es keinen. Wer eine MQTT-Uhr dabei
    /// hat, braucht ihn weiterhin — auch wenn daneben HTTP-Uhren stehen.
    func testDerBrokerGehoertNurZuMqttUhrenZurEinrichtung() throws {
        d.removeObject(forKey: "brokerHost")

        let http = Uhr(name: "Küche", host: "10.0.0.5", betriebsart: .http)
        d.set(try JSONEncoder().encode([http]), forKey: "uhren")
        XCTAssertTrue(AppZustand(schluesselbund: schluesselbund).eingerichtet,
                      "eine HTTP-Uhr allein ist eine vollständige Einrichtung")

        let mqtt = Uhr(name: "Bad", host: "10.0.0.6", praefix: "p", betriebsart: .mqtt)
        d.set(try JSONEncoder().encode([mqtt]), forKey: "uhren")
        XCTAssertFalse(AppZustand(schluesselbund: schluesselbund).eingerichtet)

        d.set(try JSONEncoder().encode([http, mqtt]), forKey: "uhren")
        XCTAssertFalse(AppZustand(schluesselbund: schluesselbund).eingerichtet,
                       "eine einzige MQTT-Uhr verlangt den Broker")

        d.set("10.0.0.2", forKey: "brokerHost")
        XCTAssertTrue(AppZustand(schluesselbund: schluesselbund).eingerichtet)
    }

    /// Der Praefix-Filter in `ziele()` war fuer eine HTTP-Uhr falsch: Sie wird
    /// unter ihrer Adresse angesprochen und hat womoeglich nie ein Praefix
    /// gesehen — uebersprungen wuerde sie **stillschweigend**.
    func testHttpUhrOhnePraefixBleibtEinZiel() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        let http = Uhr(name: "Küche", host: "10.0.0.1", betriebsart: .http)
        let mqtt = Uhr(name: "Bad", host: "10.0.0.2", betriebsart: .mqtt)  // nie abgefragt
        zustand.uhren = [http, mqtt]
        zustand.zielIDs = [http.id, mqtt.id]

        XCTAssertEqual(zustand.ziele(), [http],
                       "HTTP braucht kein Präfix, MQTT schon")
    }

    /// Eine HTTP-Uhr scheitert nie am Broker und nie an einem Praefix. Die
    /// Meldung, die sie im Fehlerfall bekommt, darf den Leser deshalb nicht
    /// zu „Abfragen" oder „Sichern und prüfen" schicken.
    func testDieMeldungEinerHttpUhrRedetWederVomBrokerNochVomPraefix() throws {
        d.removeObject(forKey: "uhren")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        let ohneAdresse = Uhr(name: "Küche", host: "", betriebsart: .http)

        let meldung = zustand.zugangsmeldung(ohneAdresse)

        XCTAssertTrue(meldung.contains("Küche"), "war: \(meldung)")
        XCTAssertTrue(meldung.contains("Adresse"), "war: \(meldung)")
        XCTAssertFalse(meldung.contains("Broker"), "war: \(meldung)")
        XCTAssertFalse(meldung.contains("Abfragen"), "war: \(meldung)")
    }

    /// **Was ohne diese Buchung geschaehe:** Ueber MQTT veroeffentlicht die Uhr
    /// nach einer Aenderung ihre `customList` von selbst, die Auskunft kommt
    /// also gleich nach. Ueber HTTP reicht sie nichts nach (gemessen) — ein
    /// eben gefuellter Platz zeigte „frei", solange die alte Auskunft steht.
    /// Gebucht wird nur, was die Uhr mit `code: 200` quittiert hat.
    func testEineBestaetigteHttpSendungErgaenztDieAuskunftDerUhr() throws {
        d.removeObject(forKey: "uhren")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        let http = Uhr(name: "Küche", host: "10.0.0.1", betriebsart: .http)
        let mqtt = Uhr(name: "Bad", host: "10.0.0.2", praefix: "p", betriebsart: .mqtt)
        zustand.uhren = [http, mqtt]
        zustand.belegungGemeldet(["meldung3"], fuer: http.id)
        zustand.belegungGemeldet(["meldung3"], fuer: mqtt.id)

        zustand.anzeigeBestaetigt("meldung1", fuer: http)
        zustand.anzeigeBestaetigt("meldung1", fuer: mqtt)

        XCTAssertEqual(zustand.gemeldeteAnzeigen[http.id], ["meldung3", "meldung1"])
        XCTAssertEqual(zustand.gemeldeteAnzeigen[mqtt.id], ["meldung3"],
                       "über MQTT sagt es die Uhr selbst — hier wäre es eine Behauptung")
        XCTAssertEqual(zustand.bekannteAnzeigen[http.id], ["meldung1"])
        XCTAssertEqual(zustand.bekannteAnzeigen[mqtt.id], ["meldung1"])
    }

    /// Ohne eine Auskunft der Uhr wird auch keine erfunden: Dann gilt die
    /// eigene Buchfuehrung, und die Ansicht sagt das auch.
    func testOhneAuskunftDerUhrWirdKeineAngelegt() throws {
        d.removeObject(forKey: "uhren")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        let http = Uhr(name: "Küche", host: "10.0.0.1", betriebsart: .http)
        zustand.uhren = [http]
        zustand.aktiveID = http.id

        zustand.anzeigeBestaetigt("meldung1", fuer: http)

        XCTAssertNil(zustand.gemeldeteAnzeigen[http.id])
        XCTAssertEqual(zustand.anzeigenDerAktivenMitQuelle().quelle, .app)
    }

    /// Was eine frische Installation in den Feldern stehen hat: nichts. Ein
    /// vorausgefuellter Benutzername oder eine erfundene Brokeradresse sind
    /// schlechter als leere Felder — man sieht ihnen nicht an, ob dort ein
    /// echter Wert steht, und muss ueberschreiben statt einzutragen.
    func testFrischeInstallationHatLeereZugangsfelder() {
        d.removeObject(forKey: "brokerHost")
        d.removeObject(forKey: "benutzer")
        d.removeObject(forKey: "brokerPort")

        let zustand = AppZustand(schluesselbund: schluesselbund)

        XCTAssertEqual(zustand.brokerHost, "", "keine Adresse, die niemand eingetragen hat")
        XCTAssertEqual(zustand.benutzer, "", "kein vorausgefuellter Benutzername")
        XCTAssertEqual(zustand.brokerPort, "1883",
                       "der Standardport von MQTT bleibt — er sagt nichts ueber diese Installation")
    }

    /// Die leere Adresse ist seit der leeren Vorgabe der Zustand jeder frischen
    /// Installation — und damit ein Knopfdruck von „Sichern und pruefen"
    /// entfernt. Ohne eigenen Zweig nennte die Meldung den Port, an dem nichts
    /// falsch ist, und `NWEndpoint.Host("")` waere ein Ziel, das es nicht gibt.
    func testOhneBrokeradresseSagtDiePruefungGenauDas() {
        d.removeObject(forKey: "brokerHost")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        XCTAssertEqual(zustand.brokerHost, "")

        // Der Zugang selbst faellt weg — es gibt kein Ziel, an das gesendet
        // werden koennte, auch nicht fuer eine laengst abgefragte Uhr.
        XCTAssertNil(zustand.anzeigen(fuer: Uhr(name: "Küche", host: "10.0.0.5",
                                                praefix: "awtrix_a86b")),
                     "ohne Adresse darf kein Zugang entstehen")

        zustand.brokerSichernUndPruefen()

        XCTAssertEqual(zustand.brokerStand,
                       .abgelehnt(lok("Es ist keine Brokeradresse eingetragen.")),
                       "die Meldung darf nicht den Port beschuldigen")
    }

    /// Dieselbe Unterscheidung beim Senden: Fehlt die Adresse, ist nicht der
    /// Port schuld. Alle drei Saetze gehen als gewoehnliches `String` weiter und
    /// werden von SwiftUI nie nachgeschlagen — deshalb `lok`/`lokf`.
    func testZugangsmeldungNenntDieFehlendeAdresse() {
        d.removeObject(forKey: "brokerHost")
        let zustand = AppZustand(schluesselbund: schluesselbund)
        let uhr = Uhr(name: "Küche", host: "10.0.0.5", praefix: "awtrix_a86b")

        XCTAssertEqual(zustand.zugangsmeldung(uhr),
                       lok("Es ist keine Brokeradresse eingetragen. Unter „Einstellungen“ eine eintragen und „Sichern und prüfen“ drücken."))

        zustand.brokerHost = "10.0.0.2"
        zustand.brokerPort = "keine Zahl"
        XCTAssertEqual(zustand.zugangsmeldung(uhr),
                       lokf("Der Broker-Port „%@“ ist keine Zahl über 0. Unter „Einstellungen“ richtigstellen und „Sichern und prüfen“ drücken.", "keine Zahl"),
                       "steht eine Adresse, gilt wieder die Portmeldung")

        XCTAssertEqual(zustand.zugangsmeldung(Uhr(name: "Bad", host: "10.0.0.6")),
                       lokf("%@ wurde noch nicht abgefragt. Unter „Einstellungen“ „Abfragen“ drücken.", "Bad"),
                       "das fehlende Präfix schlägt beides")
    }

    // MARK: - Die Uhr nach ihrem Stand fragen

    /// Was die Uhr selbst sagt, schlaegt die eigene Buchfuehrung — auch wenn
    /// darin ein Name steht, den diese App nie vergeben hat. Genau das war
    /// vorher in beide Richtungen falsch: ein fremder Absender erschien als
    /// „frei", eine Loeschung ueber ein anderes Programm als „belegt".
    func testAuskunftDerUhrSchlaegtDieEigeneBuchfuehrung() throws {
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        zustand.anzeigeGemerkt("meldung1", fuer: id)

        zustand.belegungGemeldet(["meldung2", "wetter"], fuer: id)

        XCTAssertEqual(zustand.anzeigenAufUhr(id), ["meldung2", "wetter"])
        let mitQuelle = zustand.anzeigenDerAktivenMitQuelle()
        XCTAssertEqual(mitQuelle.namen, ["meldung2", "wetter"])
        XCTAssertEqual(mitQuelle.quelle, .geraet, "die Uhr hat es gesagt, nicht die App")
    }

    /// Die leere Liste ist eine Auskunft, kein Schweigen: Auf der Uhr steht
    /// nichts. Ohne diesen Unterschied bliebe eine Loeschung ueber ein fremdes
    /// Programm als „belegt" stehen.
    func testLeereAuskunftHeisstFreiUndNichtUnbekannt() throws {
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        zustand.anzeigeGemerkt("meldung1", fuer: id)

        zustand.belegungGemeldet([], fuer: id)

        XCTAssertEqual(zustand.anzeigenAufUhr(id), [])
        XCTAssertEqual(zustand.anzeigenDerAktivenMitQuelle().quelle, .geraet)
    }

    /// Keine Antwort ist keine Auskunft. Dann gibt es keine Tatsache mehr, und
    /// die Ansicht muss sagen, dass sie nur noch die eigene Buchfuehrung zeigt —
    /// eine stehengelassene alte Auskunft saehe genauso aus wie eine frische.
    func testOhneAntwortFaelltEsAufDieBuchfuehrungZurueck() throws {
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        zustand.anzeigeGemerkt("meldung1", fuer: id)
        zustand.belegungGemeldet(["wetter"], fuer: id)

        zustand.belegungGemeldet(nil, fuer: id)

        XCTAssertEqual(zustand.anzeigenAufUhr(id), ["meldung1"])
        XCTAssertEqual(zustand.anzeigenDerAktivenMitQuelle().quelle, .app)
    }

    /// Der ganze Weg ohne Netz: `belegungAbfragen` fragt `GET /api/customList`
    /// und traegt die Antwort als Auskunft der Uhr ein. Der Pfad steht mit im
    /// Test, weil `/customList` ohne `/api` nichts liefert — genau daran lag es.
    func testBelegungWirdUeberDenApiPfadErfragt() throws {
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        Belegungsdoppelgaenger.antwort = #"{"apps":["meldung2","meldung5"],"count":2}"#
        Belegungsdoppelgaenger.pfade = []

        zustand.belegungAbfragen(id, sitzung: Belegungsdoppelgaenger.sitzung())
        warteBis { zustand.gemeldeteAnzeigen[id] != nil }

        XCTAssertEqual(Belegungsdoppelgaenger.pfade, ["/api/customList"])
        XCTAssertEqual(zustand.gemeldeteAnzeigen[id], ["meldung2", "meldung5"])
        XCTAssertEqual(zustand.anzeigenDerAktivenMitQuelle().quelle, .geraet)
    }

    /// Antwortet die Uhr nicht, wird die Auskunft weggeworfen statt alt zu
    /// werden — und es gibt kein Hinweisfenster, sondern eine Protokollzeile:
    /// Beim Start sind Uhren aus oder noch nicht im Netz.
    func testStummeUhrRaeumtDieAuskunftAbUndMeldetNurInsProtokoll() throws {
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        zustand.belegungGemeldet(["wetter"], fuer: id)
        Belegungsdoppelgaenger.antwort = "das ist kein JSON"

        zustand.belegungAbfragen(id, sitzung: Belegungsdoppelgaenger.sitzung())
        warteBis { zustand.gemeldeteAnzeigen[id] == nil }

        XCTAssertNil(zustand.gemeldeteAnzeigen[id])
        XCTAssertNil(zustand.fehler, "kein Hinweisfenster beim Start")
        XCTAssertTrue(zustand.protokoll.contains { $0.contains("sagt nicht, was auf ihr steht") },
                      "der Fehlschlag gehört ins Protokoll")
    }

    /// Eine eingerichtete Uhr ohne Adresse gibt es nicht zu fragen — und der
    /// Abruf darf ihre Auskunft auch nicht abraeumen.
    func testOhneAdresseWirdNichtGefragt() throws {
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        zustand.uhren[0].host = ""
        zustand.belegungGemeldet(["wetter"], fuer: id)
        Belegungsdoppelgaenger.pfade = []

        zustand.belegungAbfragen(id, sitzung: Belegungsdoppelgaenger.sitzung())
        // Lange genug, dass ein losgeloester Abruf hier ankaeme, wenn es einen gaebe.
        warteBis({ !Belegungsdoppelgaenger.pfade.isEmpty }, frist: 0.5)

        XCTAssertEqual(Belegungsdoppelgaenger.pfade, [])
        XCTAssertEqual(zustand.gemeldeteAnzeigen[id], ["wetter"])
    }

    /// Der Fall, um den es geht: Die App startet, ein Broker ist nicht
    /// eingetragen — also kein Abonnement, kein Mitlesen. Trotzdem steht die
    /// Belegung sofort da, weil die Uhr selbst gefragt wird. Vorher zeigte die
    /// App hier ihre eigene Buchfuehrung, und die war in beide Richtungen falsch.
    func testBeimStartOhneBrokerKommtDieBelegungTrotzdemVonDerUhr() throws {
        d.removeObject(forKey: "brokerHost")
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        XCTAssertEqual(zustand.brokerHost, "", "ohne Broker: kein Abonnement, kein Netzverkehr")
        zustand.anzeigeGemerkt("meldung1", fuer: id)
        Belegungsdoppelgaenger.antwort = #"{"apps":["meldung2"],"count":1}"#

        zustand.horchenStarten(sitzung: Belegungsdoppelgaenger.sitzung())
        warteBis { zustand.gemeldeteAnzeigen[id] != nil }

        XCTAssertEqual(zustand.anzeigenAufUhr(id), ["meldung2"])
        XCTAssertEqual(zustand.anzeigenDerAktivenMitQuelle().quelle, .geraet)
    }

    /// Aus dem Hintergrund zurueck: `inDenHintergrund` raeumt das Abonnement und
    /// mit ihm die Auskunft ab, und in der Zwischenzeit kann jemand anderes auf
    /// die Uhr geschrieben haben. Also erneut fragen, statt auf eine Meldung zu
    /// warten, die vielleicht nie kommt.
    func testAusDemHintergrundWirdDieBelegungErneutErfragt() throws {
        d.removeObject(forKey: "brokerHost")
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        zustand.belegungGemeldet(nil, fuer: id)   // wie nach `inDenHintergrund`
        Belegungsdoppelgaenger.antwort = #"{"apps":["meldung5"],"count":1}"#

        zustand.ausDemHintergrund(sitzung: Belegungsdoppelgaenger.sitzung())
        warteBis { zustand.gemeldeteAnzeigen[id] != nil }

        XCTAssertEqual(zustand.gemeldeteAnzeigen[id], ["meldung5"])
    }

    /// „Abfragen" holt seit F nicht mehr nur Praefix und Verbindungsstand,
    /// sondern im selben Zug auch, was auf der Uhr steht.
    func testAbfragenHoltAuchDieBelegung() throws {
        d.removeObject(forKey: "brokerHost")
        let zustand = try zustandMitEinerUhr()
        let id = try XCTUnwrap(zustand.aktiveID)
        zustand.anzeigeGemerkt("meldung1", fuer: id)
        Belegungsdoppelgaenger.vollstaendigeUhr()
        Belegungsdoppelgaenger.antwort = #"{"apps":["meldung3"],"count":1}"#

        zustand.abfragen(id, sitzung: Belegungsdoppelgaenger.sitzung())
        warteBis { zustand.gemeldeteAnzeigen[id] != nil }

        XCTAssertEqual(zustand.uhren[0].praefix, "awtrix_a86b", "das Bisherige muss weiter kommen")
        XCTAssertEqual(zustand.gemeldeteAnzeigen[id], ["meldung3"])
        XCTAssertEqual(zustand.anzeigenDerAktivenMitQuelle().quelle, .geraet)
    }

    private func zustandMitEinerUhr() throws -> AppZustand {
        let uhr = Uhr(name: "Küche", host: "10.0.0.5", praefix: "awtrix_a86b")
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.removeObject(forKey: "bekannteAnzeigen")
        return AppZustand(schluesselbund: schluesselbund)
    }

    /// Laesst den Hauptthread laufen, bis die losgeloeste Abfrage
    /// zurueckgemeldet hat. `MainActor.run` reiht sich in die Hauptwarteschlange
    /// ein — ein blosses `sleep` kaeme dort nie an.
    private func warteBis(_ bedingung: () -> Bool, frist: TimeInterval = 5) {
        let ende = Date().addingTimeInterval(frist)
        while !bedingung(), Date() < ende {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    func testEntfernteUhrVerliertIhreSlotdatei() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let zustand = AppZustand(schluesselbund: schluesselbund)
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

    // MARK: Der Schluesselbund

    /// Der Kern der Naht: Was `AppZustand` beim Erzeugen als Kennwort vorfindet,
    /// kommt aus dem hereingegebenen Schluesselbund — und nur von dort. Wird das
    /// Vorgabeargument wieder gegen `Schluesselbund.lesen` getauscht, bleibt
    /// `gelesen` leer und dieser Test wird rot.
    func testKennwortKommtAusDemHereingegebenenSchluesselbund() {
        let doppel = Schluesselbunddoppelgaenger(["broker": "geheim"])

        let zustand = AppZustand(schluesselbund: doppel)

        XCTAssertEqual(zustand.kennwort, "geheim")
        XCTAssertEqual(doppel.gelesen, ["broker"],
                       "genau einmal gefragt, und nur nach dem Brokerkennwort")
    }

    /// Und zurueck: `kennwortSichern()` schreibt in denselben Doppelgaenger,
    /// nicht in den Schluesselbund des Nutzers. Der zweite Aufruf schreibt nicht
    /// erneut — sonst haenge an jedem Fokuswechsel ein Loeschen und Neuanlegen.
    func testKennwortSichernSchreibtInDenHereingegebenenSchluesselbund() {
        let doppel = Schluesselbunddoppelgaenger(["broker": "alt"])
        let zustand = AppZustand(schluesselbund: doppel)

        zustand.kennwort = "neu"
        zustand.kennwortSichern()
        zustand.kennwortSichern()

        XCTAssertEqual(doppel.eintraege["broker"], "neu")
        XCTAssertEqual(doppel.geschrieben.count, 1, "unveraendert heisst: nicht noch einmal")
        XCTAssertEqual(doppel.geschrieben.first?.konto, "broker")
        XCTAssertNil(zustand.fehler)
    }

    /// Ein gescheitertes Schreiben muss auffallen — sonst ist das Kennwort erst
    /// nach dem Neustart weg, und niemand weiss, warum.
    func testGescheitertesSichernWirdGemeldet() {
        let doppel = Schluesselbunddoppelgaenger()
        doppel.gelingt = false
        let zustand = AppZustand(schluesselbund: doppel)

        zustand.kennwort = "neu"
        zustand.kennwortSichern()

        XCTAssertEqual(zustand.fehler, lok("Das Kennwort ließ sich nicht im Schlüsselbund sichern."))
    }

}

/// Faengt die HTTP-Abfragen an die Uhr ab. Kein Netz, keine Uhr.
final class Belegungsdoppelgaenger: URLProtocol {
    /// Die Antwort auf `/api/customList` — die Frage, um die es hier geht.
    nonisolated(unsafe) static var antwort = "{}"
    /// Die uebrigen Endpunkte, die `abfragen` unterwegs braucht.
    nonisolated(unsafe) static var weitere: [String: String] = [:]
    nonisolated(unsafe) static var pfade: [String] = []

    static func sitzung() -> URLSession {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [Belegungsdoppelgaenger.self]
        return URLSession(configuration: k)
    }

    /// Was eine Uhr antwortet, die Praefix, MAC und Verbindungsstand kennt.
    static func vollstaendigeUhr() {
        weitere = [
            "/getMqttConfig": #"{"isMqtt":true,"mqtt_prefix":"awtrix"}"#,
            "/getBase": #"{"mac":"aabbccdda86b","devSn":"TC002","mcuVer":"V1.0.17","appVer":"1.1.1"}"#,
            "/getMqttStatus": #"{"code":200,"data":{"connected":true}}"#,
        ]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        let pfad = request.url?.path ?? ""
        Self.pfade.append(pfad)
        let text = pfad == "/api/customList" ? Self.antwort : (Self.weitere[pfad] ?? "{}")
        let antwort = HTTPURLResponse(url: request.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: antwort, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
