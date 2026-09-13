import Foundation
import TC002Core

// Das Kommandozeilenwerkzeug zur App. Es richtet nichts ein: Broker, Kennwort
// und Uhren kommen aus der Einrichtung der App (`Einstellungen`), damit es nur
// eine Wahrheit gibt und nicht zwei, die auseinanderlaufen.
//
// Gebaut wird es mit in das App-Buendel (`Contents/MacOS/mqtttc002`), damit es
// die mitgelieferten Schriften und die Uebersetzungen findet.

let hilfetext = """
mqtttc002 — Meldungen an eine Ulanzi TC002 schicken.

Benutzt die Einrichtung der App MQTT-TC002: Broker, Kennwort und Uhren
werden von dort gelesen. Eingerichtet wird ausschliesslich in der App.

Jede Uhr wird auf dem Weg beschickt, der in der App fuer sie eingestellt
ist — HTTP oder MQTT. "mqtttc002 uhren" zeigt ihn an.

AUFRUF
  mqtttc002 [senden] <Text>        Text an die Uhren schicken
  mqtttc002 loeschen <Anzeige>     eine benannte Anzeige entfernen
  mqtttc002 umschalten <Anzeige>   zu einer Anzeige wechseln
  mqtttc002 uhren                  die eingerichteten Uhren auflisten
  mqtttc002 icons                  die vorhandenen Icons auflisten
  mqtttc002 hilfe                  diesen Text

OPTIONEN FUER „senden"
  --an <Uhr>          Name oder Adresse; mehrfach moeglich.
                      Ohne Angabe die Auswahl, die in der App gilt.
  --name <Anzeige>    Name der Anzeige auf der Uhr (Vorgabe: cli)
  --farbe #RRGGBB     Vorgabe: #00FF66
  --icon <Nummer>     ein 8x8-Icon links daneben
  --schrift <Name>    Vorgabe: Silkscreen
  --groesse <Zahl>    Vorgabe: 8
  --fett              fetter Schnitt, wenn die Schrift einen hat
  --gross             alles in Grossbuchstaben
  --oben|--mitte|--unten        senkrechte Ausrichtung (Vorgabe: mitte)
  --links|--zentriert|--rechts  waagrechte Ausrichtung (Vorgabe: links)
  --rand <Zahl>       Abstand zum Rand bei oben/unten (Vorgabe: 1)
  --abstand <Zahl>    leere Spalten zwischen den Zeichen (Vorgabe: 1)
  --dauer <Sekunden>  wie lange die Uhr die Anzeige zeigt
  --tempo langsam|mittel|schnell   nur fuer durchlaufenden Text
  --geraeteschrift    die eingebaute Schrift der Uhr benutzen, statt
                      selbst zu rastern. Kennt keine Umlaute.
  --trocken           nur zeigen, was gesendet wuerde

BEISPIELE
  mqtttc002 "Kaffee fertig"
  mqtttc002 senden "Post da" --icon 1673 --farbe "#FFAA00"
  mqtttc002 senden Achtung --an Kueche --dauer 10 --zentriert
  mqtttc002 loeschen cli

Zu lange Texte laufen von selbst durch; das macht die App genauso.
"""

/// Das Icon, das gemeint ist — oder eine Meldung, warum es das nicht gibt.
///
/// Gesucht wird in **beiden** Bestaenden (`Iconbestaende`); bis heute sah das
/// Werkzeug nur die 8×8 und meldete „Kein Icon", obwohl es das Icon gab. Ein
/// 16×16 hat keine LaMetric-Nummer — dort ist der Dateiname der Schluessel,
/// und darum spricht die Meldung von „Nummer oder Name".
func iconSuchen(_ nummer: String?, in bestaende: [Iconsammlung]) throws -> Icon? {
    guard let nummer else { return nil }
    guard let icon = Iconbestaende.suchen(nummer, in: bestaende) else {
        throw Abbruch(lokf("Kein Icon mit der Nummer oder dem Namen „%@“. „mqtttc002 icons“ zeigt alle.", nummer))
    }
    return icon
}

/// Ein Abbruch mit Meldung — alles, was das Werkzeug an Fehlern kennt, laeuft
/// hierher zusammen, damit die Ausgabe an einer Stelle entsteht.
struct Abbruch: Error, LocalizedError {
    let text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}

func lauf() throws {
    let optionen = try Optionen.zerlegt(Array(CommandLine.arguments.dropFirst()))

    switch optionen.befehl {
    case .hilfe:
        print(lok("cli.hilfe", vorgabe: hilfetext))
        return
    case .fassung:
        let fassung = Programmbuendel.eigenes.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let commit = Programmbuendel.eigenes.object(forInfoDictionaryKey: "TC002Commit") as? String
        print("mqtttc002 \(fassung ?? "?")\(commit.map { " (\($0))" } ?? "")")
        return
    default:
        break
    }

    // Die Schriften der App registrieren, sonst faellt CoreText stumm auf
    // Helvetica zurueck und die Ausgabe saehe anders aus als in der Vorschau.
    Schriften.registrieren()

    let einstellungen = Einstellungen.gelesen()

    if case .icons = optionen.befehl {
        let alle = Iconbestaende.alle().flatMap { $0.alle() }
            .sorted { $0.nummer.localizedStandardCompare($1.nummer) == .orderedAscending }
        guard !alle.isEmpty else {
            print(lok("Keine Icons. Die App legt beim ersten Start einen Grundschatz an."))
            return
        }
        // Dritte Spalte, weil die Liste jetzt zwei Bestaende zeigt: Ohne sie
        // waere nicht zu sehen, welches der Eintraege ein LaMetric-Icon mit
        // Nummer ist und welcher ein eigenes 16×16 mit Dateinamen. Angehaengt,
        // nicht dazwischengeschoben — wer bisher Spalte 1 und 2 auswertet,
        // liest weiter dasselbe.
        for icon in alle { print("\(icon.nummer)\t\(icon.name)\t\(icon.kante)×\(icon.kante)") }
        return
    }

    if case .uhren = optionen.befehl {
        guard !einstellungen.uhren.isEmpty else {
            throw Abbruch(lok("Keine Uhr eingerichtet. In der App unter „Einstellungen“ eine anlegen."))
        }
        let ziele = Set(einstellungen.ziele.map(\.id))
        for uhr in einstellungen.uhren {
            let marke = ziele.contains(uhr.id) ? "*" : " "
            // Das Praefix gehoert zum MQTT-Betrieb. Bei einer HTTP-Uhr stuende
            // dort „noch nicht abgefragt" und schickte jemanden hinter etwas
            // her, das diese Uhr gar nicht braucht.
            let dritte: String
            switch uhr.wirksameBetriebsart {
            case .http: dritte = "HTTP"
            case .mqtt: dritte = "MQTT " + (uhr.praefix.isEmpty ? lok("noch nicht abgefragt") : uhr.praefix)
            }
            print("\(marke) \(uhr.name)\t\(uhr.host)\t\(dritte)")
        }
        print("")
        print(lok("* geht ohne „--an“ eine Sendung zu."))
        return
    }

    let gewaehlte: [Uhr]
    if optionen.ziele.isEmpty {
        gewaehlte = einstellungen.ziele
    } else {
        gewaehlte = try optionen.ziele.map { name in
            guard let uhr = einstellungen.uhr(benannt: name) else {
                throw Abbruch(lokf("Keine Uhr namens „%@“. „mqtttc002 uhren“ zeigt alle.", name))
            }
            return uhr
        }
    }
    guard !gewaehlte.isEmpty else {
        throw Abbruch(lok("Keine Uhr eingerichtet. In der App unter „Einstellungen“ eine anlegen."))
    }

    // Erst jetzt, wo die Ziele feststehen: Ein Broker ist nur noetig, wenn
    // wenigstens eine dieser Uhren ueber ihn geht. Wer ausschliesslich ueber
    // HTTP sendet, soll hier nicht an einer Bedingung scheitern, die seine
    // Einrichtung gar nicht kennt.
    if Einstellungen.brokerNoetig(fuer: gewaehlte), !einstellungen.brokerEingerichtet {
        throw Abbruch(lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Sichern und prüfen“ drücken."))
    }

    // Woran eine Uhr fehlt, haengt an ihrer Betriebsart: Die MQTT-Uhr braucht
    // ein abgefragtes Praefix, die HTTP-Uhr eine Adresse.
    let ohnePraefix = gewaehlte.filter { $0.wirksameBetriebsart == .mqtt && !$0.beschickbar }
    if !ohnePraefix.isEmpty {
        throw Abbruch(lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ „Abfragen“ drücken — ohne Präfix gibt es kein Thema, an das sich senden liesse.", ohnePraefix.map(\.name).joined(separator: ", ")))
    }
    let ohneAdresse = gewaehlte.filter { $0.wirksameBetriebsart == .http && !$0.beschickbar }
    if !ohneAdresse.isEmpty {
        throw Abbruch(lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", ohneAdresse.map(\.name).joined(separator: ", ")))
    }

    let sammlung = Iconsammlung(schreibordner: Iconordner.eigene)
    let icon = try iconSuchen(optionen.iconNummer, in: Iconbestaende.alle())

    /// Fuehrt eine Sendung an jede gewaehlte Uhr aus und zaehlt, was schiefging.
    func anAlle(_ was: String, _ tun: (Anzeigen, Uhr) throws -> Void) throws {
        var fehler: [String] = []
        for uhr in gewaehlte {
            // Derselbe Kanal, den auch die App und die Kurzbefehle benutzen —
            // ein Werkzeug, das anders sendet als die App, waere eine Falle.
            guard let anzeigen = Anzeigen.fuer(uhr, brokerzugang: einstellungen.zugang(
                clientID: "tc002-cli-" + uhr.id.uuidString.prefix(8).lowercased())) else { continue }
            do {
                try tun(anzeigen, uhr)
                print(lokf("%@: %@", uhr.name, was))
            } catch {
                fehler.append("\(uhr.name): \((error as? LocalizedError)?.errorDescription ?? "\(error)")")
            }
        }
        guard fehler.isEmpty else { throw Abbruch(fehler.joined(separator: "\n")) }
    }

    switch optionen.befehl {
    case .senden(let text):
        var m = optionen.meldung
        m.text = text
        let rahmen = try Meldungsbau.rahmen(m, icon: icon, sammlung: sammlung)
        let json = rahmen.alsJSON()
        if optionen.trocken {
            // Der Trockenlauf ist auch die Auskunft darueber, womit gesendet
            // wuerde: Ein fehlendes Kennwort faellt sonst nirgends auf — MQTT
            // 3.1.1 hat keinen Rueckkanal fuer eine abgelehnte Sendung.
            //
            // Nur wenn ueberhaupt eine MQTT-Uhr dabei ist: `einstellungen.kennwort`
            // greift in den Schluesselbund und zieht dabei einen Dialog auf.
            // Fuer eine reine HTTP-Sendung waere das eine Frage nach etwas,
            // das nirgends gebraucht wird.
            if Einstellungen.brokerNoetig(fuer: gewaehlte) {
                print(lokf("Broker %@:%d, Konto %@, Kennwort %@", einstellungen.brokerHost, Int(einstellungen.brokerPort),
                             einstellungen.benutzer ?? "—",
                             einstellungen.kennwort == nil ? lok("fehlt") : lok("vorhanden")))
            }
            for uhr in gewaehlte {
                switch uhr.wirksameBetriebsart {
                case .http: print("POST http://\(uhr.host)/api/custom?name=\(optionen.anzeigename)")
                case .mqtt: print("\(uhr.praefix)/custom/\(optionen.anzeigename)")
                }
            }
            print(json)
            print(lokf("%d Byte Nutzlast, nichts gesendet (--trocken).", json.utf8.count))
            return
        }
        try anAlle(lokf("gesendet an „%@“ (%d Byte)", optionen.anzeigename, json.utf8.count)) { anzeigen, uhr in
            try anzeigen.zeigen(rahmen, auf: optionen.anzeigename)
            // Nur wenn der Anzeigenname einem der fuenf festen Plaetze
            // entspricht, gibt es einen Platz, den sich das Slotgedaechtnis
            // merken koennte — bei einem frei gewaehlten Namen (Vorgabe
            // „cli") gibt es keinen. Schlaegt das Schreiben fehl, bleibt die
            // Sendung trotzdem erfolgreich; eine Zeile auf der Fehlerausgabe
            // haelt es trotzdem fest — das Werkzeug hat kein Protokoll wie
            // die App, aber stderr verunreinigt die eigentliche Ausgabe nicht.
            if let platz = Meldungsplatz.platz(fuerName: optionen.anzeigename) {
                let gemerkt = Slotgedaechtnis.gemeinsam.merken(m, icon: icon?.nummer,
                                                              iconKante: icon?.kante ?? 8,
                                                              fuer: uhr.id, platz: platz)
                if !gemerkt {
                    fehlerAusgeben(lokf("%@: Regler für Slot %d nicht gemerkt", uhr.name, platz))
                }
            }
        }

    case .loeschen(let name):
        if optionen.trocken {
            print(lokf("Würde „%@“ löschen.", name)); return
        }
        try anAlle(lokf("„%@“ gelöscht", name)) { anzeigen, _ in
            try anzeigen.loeschen(name)
        }

    case .umschalten(let name):
        if optionen.trocken {
            print(lokf("Würde auf „%@“ umschalten.", name)); return
        }
        try anAlle(lokf("auf „%@“ umgeschaltet", name)) { anzeigen, _ in
            try anzeigen.umschalten(auf: name)
        }

    case .uhren, .icons, .hilfe, .fassung:
        break                                    // oben schon abgehandelt
    }
}

do {
    try lauf()
} catch {
    fehlerAusgeben((error as? LocalizedError)?.errorDescription ?? "\(error)")
    exit(1)
}
