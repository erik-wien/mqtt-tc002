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
func iconSuchen(_ nummer: String?, in sammlung: Iconsammlung) throws -> Icon? {
    guard let nummer else { return nil }
    guard let icon = sammlung.alle().first(where: { $0.nummer == nummer }) else {
        throw Abbruch(lokf("Kein Icon mit der Nummer „%@“. „mqtttc002 icons“ zeigt alle.", nummer))
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
        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene)
        let alle = sammlung.alle().sorted { $0.nummer.localizedStandardCompare($1.nummer) == .orderedAscending }
        guard !alle.isEmpty else {
            print(lok("Keine Icons. Die App legt beim ersten Start einen Grundschatz an."))
            return
        }
        for icon in alle { print("\(icon.nummer)\t\(icon.name)") }
        return
    }

    if case .uhren = optionen.befehl {
        guard !einstellungen.uhren.isEmpty else {
            throw Abbruch(lok("Keine Uhr eingerichtet. In der App unter „Verbindung“ eine anlegen."))
        }
        let ziele = Set(einstellungen.ziele.map(\.id))
        for uhr in einstellungen.uhren {
            let marke = ziele.contains(uhr.id) ? "*" : " "
            let praefix = uhr.praefix.isEmpty ? lok("noch nicht abgefragt") : uhr.praefix
            print("\(marke) \(uhr.name)\t\(uhr.host)\t\(praefix)")
        }
        print("")
        print(lok("* geht ohne „--an“ eine Sendung zu."))
        return
    }

    // Ab hier wird gesendet, also braucht es einen Broker.
    guard einstellungen.zugang(clientID: "x") != nil else {
        throw Abbruch(lok("Kein Broker eingerichtet. In der App unter „Verbindung“ Adresse und Port eintragen und „Sichern und prüfen“ drücken."))
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
        throw Abbruch(lok("Keine Uhr eingerichtet. In der App unter „Verbindung“ eine anlegen."))
    }

    let ohnePraefix = gewaehlte.filter { $0.praefix.isEmpty }
    if !ohnePraefix.isEmpty {
        throw Abbruch(lokf("Noch nicht abgefragt: %@. In der App unter „Verbindung“ „Abfragen“ drücken — ohne Präfix gibt es kein Thema, an das sich senden liesse.", ohnePraefix.map(\.name).joined(separator: ", ")))
    }

    let sammlung = Iconsammlung(schreibordner: Iconordner.eigene)
    let icon = try iconSuchen(optionen.iconNummer, in: sammlung)

    /// Fuehrt eine Sendung an jede gewaehlte Uhr aus und zaehlt, was schiefging.
    func anAlle(_ was: String, _ tun: (Anzeigen, Uhr) throws -> Void) throws {
        var fehler: [String] = []
        for uhr in gewaehlte {
            guard let zugang = einstellungen.zugang(
                clientID: "tc002-cli-" + uhr.id.uuidString.prefix(8).lowercased()) else { continue }
            let anzeigen = Anzeigen(sender: MQTTSender(), zugang: zugang, praefix: uhr.praefix)
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
            print(lokf("Broker %@:%d, Konto %@, Kennwort %@", einstellungen.brokerHost, Int(einstellungen.brokerPort),
                         einstellungen.benutzer ?? "—",
                         einstellungen.kennwort == nil ? lok("fehlt") : lok("vorhanden")))
            for uhr in gewaehlte {
                print("\(uhr.praefix)/custom/\(optionen.anzeigename)")
            }
            print(json)
            print(lokf("%d Byte Nutzlast, nichts gesendet (--trocken).", json.utf8.count))
            return
        }
        try anAlle(lokf("gesendet an „%@“ (%d Byte)", optionen.anzeigename, json.utf8.count)) { anzeigen, _ in
            try anzeigen.zeigen(rahmen, auf: optionen.anzeigename)
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
