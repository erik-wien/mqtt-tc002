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

Benutzt die Einrichtung der App Pixel Clock Messenger: Broker, Kennwort und
Uhren werden von dort gelesen. Eingerichtet wird ausschliesslich in der App.

Jede Uhr wird auf dem Weg beschickt, der in der App fuer sie eingestellt
ist — HTTP oder MQTT. "mqtttc002 uhren" zeigt ihn an.

AUFRUF
  mqtttc002 [senden] <Text>        Text an die Uhren schicken
  mqtttc002 nachricht <Text>       eine einmalige Nachricht ueber der Schleife
  mqtttc002 zurueckziehen [<Name>] die sichtbare Nachricht wegnehmen,
                                   mit Namen die benannte
  mqtttc002 loeschen <Anzeige>     eine benannte Anzeige entfernen
  mqtttc002 umschalten <Anzeige>   zu einer Anzeige wechseln
  mqtttc002 bild <Name>            ein fertiges Bild aus dem Bestand schicken
  mqtttc002 layout <Datei.json>    ein Layout (Kaesten mit Inhalt) aus einer Datei schicken
  mqtttc002 bildschirm             das Display der Uhr lesen und als Text ausgeben
  mqtttc002 uhren                  die eingerichteten Uhren auflisten
  mqtttc002 icons                  die vorhandenen Icons auflisten
  mqtttc002 bilder                 die vorhandenen 16x52-Bilder auflisten
  mqtttc002 effekte                Effekte, Overlays und Paletten der Uhr auflisten
  mqtttc002 hilfe                  diesen Text

Ein Bild ist eine ganze Anzeige (16x52) aus dem Editor der App und ersetzt
Text und Icon. Von „senden" gelten dafuer nur --an, --name und --dauer; alles
Uebrige formatiert Text, den es dort nicht gibt. Ein Einzelbild geht pixelgenau
als Standbild an die Uhr, mehrere als animiertes GIF.

Ein Layout teilt das volle Display in Kaesten, jeder mit genau einem Inhalt (Text,
Icon, Diagramm, Fortschritt, Zeichnung); die Datei traegt genau die Schluessel der
Geraetereferenz, entweder den Block "layout" oder die ganze Nutzlast
{"layout":{...},"durationMs":10000}. Von „senden" gelten dafuer --an, --name, --dauer,
--lebensdauer, --behalten, --ablauf und --trocken. Die TC001 kann keine Layouts; das
Werkzeug fragt die Uhr danach und meldet es vor dem Senden. Mit --name wird das Layout
unter einem der Plaetze (meldung1 bis meldung5) abgelegt.

„bildschirm" liest das Display ueber HTTP bzw. MQTT (cmd/screen/get -> state/screen)
und zeichnet es als Text: je Pixel ein Zeichen, "." ist schwarz, "#" die erste
andere Farbe in Leserichtung, dann A, B, ...; darunter die Farben als #RRGGBB.

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
  --lebensdauer <Sekunden>   nach dieser Zeit verfaellt die Anzeige von selbst
                      (nur senden; Vorgabe: 1800, also 30 Minuten)
  --behalten          die Anzeige verfaellt nicht, sie bleibt bis zum Loeschen
  --ablauf entfernen|markieren   was dann geschieht: loeschen oder mit rotem
                      Rahmen stehen lassen (Vorgabe: entfernen)
                      Die Lebensdauer wird mit dem Platz gemerkt.
  --tempo langsam|mittel|schnell   nur fuer durchlaufenden Text
  --trocken           nur zeigen, was gesendet wuerde

DARSTELLUNG (fuer „senden" und „nachricht")
  Namen fragt das Werkzeug bei der Uhr ab ("mqtttc002 effekte" zeigt sie) und
  prueft sie, bevor etwas gesendet wird. Ein Text, den die App selbst rastert
  (Vorgabe), deckt den Hintergrund ganz zu: --hintergrund und --effekt gehen
  dann nicht, ein --overlay schon.
  --hintergrund #RRGGBB   einfarbiger Hintergrund (nicht mit --effekt)
  --effekt <Name>     bewegter Hintergrund; --effekt-tempo <0.1-10>
  --overlay <Name>    Wetter ueber allem: rain, snow, drizzle, storm, thunder, frost
  --palette <Name>|#RRGGBB,#RRGGBB|#RRGGBB@0,#RRGGBB@100
                      Name aus der Uhr, 1-16 Farben oder Farben mit Lage 0-100
  --palette-hart      harte Baender statt Uebergang
  --palette-spanne <Pixel>, --palette-tempo <0-10>   nur fuer Text aus der Palette
  --text-palette      Text von der Uhr aus der Palette malen

DIAGRAMM UND FORTSCHRITT (statt Text; fuer „senden" und „nachricht")
  --balken 1,2,3 | --linie 1,2,3   bis 16 ganze Zahlen; eine Linie braucht zwei
  --feste-skala       Skala fest 0-8 statt selbst angepasst
  --diagrammfarbe #RRGGBB|palette
  --fortschritt <0-100>   Balken in der untersten Zeile
  --fortschrittsfarbe #RRGGBB|palette, --fortschrittsgrund #RRGGBB

OPTIONEN FUER „nachricht"
  Text und Format wie bei „senden"; --name ist hier der Name der Nachricht
  (nur darueber laesst sie sich zurueckziehen), --dauer wie lange sie steht.
  Vorgabe: Die Nachricht bleibt stehen, weckt das Panel und laeuft zweimal durch.
  --nicht-halten      steht nur --dauer lang, statt bis zum Zurueckziehen
  --nicht-wecken      erscheint nicht bei ausgeschaltetem Panel
  --ersetzen          ersetzt die sichtbare, statt sich hinten anzustellen
  --wiederholungen <Zahl>   wie oft laufender Text durchlaeuft (Vorgabe: 2)

Ueber MQTT wartet das Werkzeug auf die Antwort der Uhr (<Thema>/result): Weist die
Uhr ab, steht Code und Feld auf der Fehlerausgabe und der Aufruf endet mit 1.
Kommt keine Antwort, gibt es nur eine Warnung — gleiche Bedeutung wie in der App.

BEISPIELE
  mqtttc002 "Kaffee fertig"
  mqtttc002 senden "Post da" --icon post --farbe "#FFAA00"
  mqtttc002 senden Achtung --an Kueche --dauer 10 --zentriert
  mqtttc002 senden Wetter --lebensdauer 600 --ablauf markieren
  mqtttc002 senden Dauerhaft --behalten
  mqtttc002 senden Regen --text-palette --palette Ocean --overlay rain
  mqtttc002 senden --linie 3,5,2,8 --diagrammfarbe "#00FF66" --fortschritt 40
  mqtttc002 nachricht "Tuer offen" --name tuer
  mqtttc002 zurueckziehen tuer
  mqtttc002 loeschen cli
  mqtttc002 layout drei-felder.json --name meldung2 --trocken
  mqtttc002 bildschirm --an Kueche

Zu lange Texte laufen von selbst durch; das macht die App genauso.
"""

/// Das Icon, das gemeint ist — oder eine Meldung, warum es das nicht gibt.
///
/// Gesucht wird in beiden Bestaenden (`Iconbestaende`): Ein 16×16 hat keine
/// LaMetric-Nummer — dort ist der Dateiname der Schluessel, und darum spricht
/// die Meldung von „Nummer oder Name".
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

    if case .bilder = optionen.befehl {
        let alle = Bildersammlung(ordner: Bilderordner.eigene).alle()
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !alle.isEmpty else {
            print(lok("Keine Bilder. Sie entstehen im Editor der App."))
            return
        }
        // Dieselbe Form wie bei `icons`: Name, dann was die Zeile sonst noch
        // unterscheidet. Eine Werknummer hat nicht jedes Bild.
        for bild in alle {
            print("\(bild.name)\t\(Leinwandgroesse.anzeige.beschriftung)\t\(bild.nummer ?? "")")
        }
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

    if case .effekte = optionen.befehl {
        // Allein ueber HTTP, auch fuer MQTT-Uhren: `capabilities` gibt es nur dort.
        var gelesen = 0
        for uhr in gewaehlte {
            guard !uhr.host.isEmpty else {
                fehlerAusgeben(lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", uhr.name))
                continue
            }
            do {
                guard let f = try Geraet(host: uhr.host).faehigkeiten() else {
                    fehlerAusgeben(lokf("%@ nennt keine Effekte.", uhr.name)); continue
                }
                if gewaehlte.count > 1 { print("# \(uhr.name)") }
                // Spalte 1 ist die Art, Spalte 2 der Name, so wie ihn `--effekt`,
                // `--overlay` und `--palette` annehmen; Spalte 3 nur bei Effekten:
                // ob sie die Palette nutzen.
                for e in f.effekte {
                    print("effekt\t\(e)\t\(f.nutztPalette(effekt: e) ? "palette" : "")")
                }
                for o in f.overlays { print("overlay\t\(o)") }
                for p in f.paletten { print("palette\t\(p)") }
                gelesen += 1
            } catch {
                fehlerAusgeben("\(uhr.name): \((error as? LocalizedError)?.errorDescription ?? "\(error)")")
            }
        }
        if gelesen == 0 { throw Abbruch(lok("Keine Uhr hat geantwortet.")) }
        return
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

    /// Die Namenslisten der Uhr, nur wenn die Darstellung Namen benutzt und die
    /// Uhr eine Adresse hat: Eine Sendung ohne Namen soll keine zusaetzliche
    /// Anfrage kosten. Antwortet die Uhr nicht, bleiben die Namen ungeprueft —
    /// die Uhr weist einen falschen selbst ab (`422`).
    func faehigkeiten(_ uhr: Uhr) -> Geraetefaehigkeiten? {
        let d = optionen.darstellung
        var nennt = (d.effekt?.isEmpty == false) || (d.overlay?.isEmpty == false)
            || { if case .name? = d.palette { return true }; return false }()
        // Ob die Uhr Layouts kann, steht nur in ihrer Auskunft.
        if case .layout = optionen.befehl { nennt = true }
        guard nennt, !uhr.host.isEmpty else { return nil }
        return (try? Geraet(host: uhr.host).faehigkeiten()) ?? nil
    }

    /// Fuehrt eine Sendung an jede gewaehlte Uhr aus und zaehlt, was schiefging.
    func anAlle(_ was: String, _ tun: (Anzeigen, Uhr) throws -> Void) throws {
        var fehler: [String] = []
        for uhr in gewaehlte {
            // Derselbe Kanal, den auch die App und die Kurzbefehle benutzen —
            // ein Werkzeug, das anders sendet als die App, waere eine Falle.
            let uhrname = uhr.name
            // Ueber MQTT wartet jede Sendung auf `<Thema>/result` (§3.4): Eine
            // Abweisung wirft und endet mit Exit-Code 1, das Ausbleiben der
            // Antwort ist nur eine Warnung — sie kann auch am Mitlesen liegen.
            guard let anzeigen = Anzeigen.fuer(uhr, brokerzugang: einstellungen.zugang(
                clientID: "tc002-cli-" + uhr.id.uuidString.prefix(8).lowercased()))?
                .quittierend(beiAusbleiben: { thema in
                    fehlerAusgeben(lokf("Warnung: %@ hat nicht auf %@ geantwortet — Thema und Präfix prüfen.",
                                        uhrname, thema))
                }) else { continue }
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
        /// Je Uhr: deren Mass fuer den Text, deren Namenslisten fuer die Darstellung.
        func rahmen(mass: Anzeigemass? = nil) throws -> Frame {
            if optionen.grafikGesetzt { return optionen.grafikrahmen }
            return optionen.mitDarstellung(try Meldungsbau.rahmen(m, icon: icon, sammlung: sammlung,
                                                                  mass: mass ?? .vorgabe))
        }
        let json = try Anzeigen.nutzlast(try rahmen())
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
                case .http: print("PUT http://\(uhr.host)/api/v1/apps/pushed/\(optionen.anzeigename)")
                case .mqtt: print(NGThema.anzeige(praefix: uhr.praefix, name: optionen.anzeigename))
                }
            }
            print(json)
            print(lokf("%d Byte Nutzlast, nichts gesendet (--trocken).", json.utf8.count))
            return
        }
        try anAlle(lokf("gesendet an „%@“ (%d Byte)", optionen.anzeigename, json.utf8.count)) { anzeigen, uhr in
            // Je Uhr in deren Anzeigemass gerastert; `rahmen` oben dient dem
            // Trockenlauf und der Byte-Angabe.
            try anzeigen.zeigen(try rahmen(mass: Anzeigemass.fuer(uhr)), auf: optionen.anzeigename,
                                faehigkeiten: faehigkeiten(uhr))
            // Nur wenn der Anzeigenname einem der fuenf festen Plaetze
            // entspricht, gibt es einen Platz, den sich das Slotgedaechtnis
            // merken koennte — bei einem frei gewaehlten Namen (Vorgabe
            // „cli") gibt es keinen. Schlaegt das Schreiben fehl, bleibt die
            // Sendung trotzdem erfolgreich; eine Zeile auf der Fehlerausgabe
            // haelt es trotzdem fest — das Werkzeug hat kein Protokoll wie
            // die App, aber stderr verunreinigt die eigentliche Ausgabe nicht.
            if let platz = Meldungsplatz.platz(fuerName: optionen.anzeigename) {
                // Eine Grafik hat keine Regler, die sich merken liessen.
                if optionen.grafikGesetzt {
                    _ = Slotgedaechtnis.gemeinsam.vergessen(fuer: uhr.id, platz: platz)
                    return
                }
                let gemerkt = Slotgedaechtnis.gemeinsam.merken(m, icon: icon?.nummer,
                                                              iconKante: icon?.kante ?? 8,
                                                              fuer: uhr.id, platz: platz)
                if !gemerkt {
                    fehlerAusgeben(lokf("%@: Regler für Slot %d nicht gemerkt", uhr.name, platz))
                }
            }
        }

    case .nachricht(let text):
        var m = optionen.meldung
        m.text = text
        let bo = optionen.benachrichtigung
        func rahmen(mass: Anzeigemass? = nil) throws -> Frame {
            if optionen.grafikGesetzt { return optionen.grafikrahmen }
            return optionen.mitDarstellung(try Meldungsbau.rahmen(m, icon: icon, sammlung: sammlung,
                                                                  mass: mass ?? .vorgabe))
        }
        let json = try NGNutzlast.benachrichtigung(try rahmen(), bo)
        if optionen.trocken {
            if Einstellungen.brokerNoetig(fuer: gewaehlte) {
                print(lokf("Broker %@:%d, Konto %@, Kennwort %@", einstellungen.brokerHost, Int(einstellungen.brokerPort),
                             einstellungen.benutzer ?? "—",
                             einstellungen.kennwort == nil ? lok("fehlt") : lok("vorhanden")))
            }
            for uhr in gewaehlte {
                switch uhr.wirksameBetriebsart {
                case .http: print("POST http://\(uhr.host)/api/v1/notifications")
                case .mqtt: print(NGThema.benachrichtigung(praefix: uhr.praefix))
                }
            }
            print(json)
            print(lokf("%d Byte Nutzlast, nichts gesendet (--trocken).", json.utf8.count))
            return
        }
        // Eine Benachrichtigung ist keine Anzeige: kein Platz, also auch nichts
        // fuers Slotgedaechtnis.
        try anAlle(lokf("Nachricht gesendet (%d Byte)", json.utf8.count)) { anzeigen, uhr in
            try anzeigen.benachrichtigen(try rahmen(mass: Anzeigemass.fuer(uhr)), bo,
                                         faehigkeiten: faehigkeiten(uhr))
        }

    case .layout(let pfad):
        let datei = try Layoutdatei.lesen(datei: URL(fileURLWithPath: (pfad as NSString).expandingTildeInPath))
        let frame = Frame(dauer: optionen.dauer ?? datei.dauer, lebensdauer: optionen.meldung.wirksameLebensdauer,
                          layout: datei.layout)
        // Der Trockenlauf fragt niemanden; geprueft wird gegen das Mass jeder Uhr.
        let json = try Anzeigen.nutzlast(frame, mass: gewaehlte.first.map(Anzeigemass.fuer))
        if optionen.trocken {
            for uhr in gewaehlte {
                _ = try Anzeigen.nutzlast(frame, mass: Anzeigemass.fuer(uhr))
                switch uhr.wirksameBetriebsart {
                case .http: print("PUT http://\(uhr.host)/api/v1/apps/pushed/\(optionen.anzeigename)")
                case .mqtt: print(NGThema.anzeige(praefix: uhr.praefix, name: optionen.anzeigename))
                }
            }
            print(json)
            print(lokf("%d Byte Nutzlast, nichts gesendet (--trocken).", json.utf8.count))
            return
        }
        try anAlle(lokf("Layout gesendet an „%@“ (%d Byte)", optionen.anzeigename, json.utf8.count)) { anzeigen, uhr in
            try anzeigen.zeigen(frame, auf: optionen.anzeigename, faehigkeiten: faehigkeiten(uhr))
            // Wie ein gemaltes Bild: ein Layout hat keine Regler, die sich merken liessen.
            if let platz = Meldungsplatz.platz(fuerName: optionen.anzeigename) {
                _ = Slotgedaechtnis.gemeinsam.vergessen(fuer: uhr.id, platz: platz)
            }
        }

    case .bildschirm:
        var gelesen = 0
        var fehler: [String] = []
        for uhr in gewaehlte {
            guard let anzeigen = Anzeigen.fuer(uhr, brokerzugang: einstellungen.zugang(
                clientID: "tc002-cli-" + uhr.id.uuidString.prefix(8).lowercased())) else { continue }
            do {
                let auszug = try anzeigen.bildschirmLesen()
                if gewaehlte.count > 1 { print("# \(uhr.name)") }
                print(auszug.ascii())
                gelesen += 1
            } catch {
                fehler.append("\(uhr.name): \((error as? LocalizedError)?.errorDescription ?? "\(error)")")
            }
        }
        guard fehler.isEmpty, gelesen > 0 else {
            throw Abbruch(fehler.isEmpty ? lok("Keine Uhr hat geantwortet.") : fehler.joined(separator: "\n"))
        }

    case .zurueckziehen(let name):
        if optionen.trocken {
            print(name.map { lokf("Würde die Nachricht „%@“ zurückziehen.", $0) }
                  ?? lok("Würde die sichtbare Nachricht zurückziehen."))
            return
        }
        try anAlle(name.map { lokf("Nachricht „%@“ zurückgezogen", $0) }
                   ?? lok("sichtbare Nachricht zurückgezogen")) { anzeigen, _ in
            try anzeigen.benachrichtigungZurueckziehen(name: name)
        }

    case .bild(let name):
        // Gesucht wird ueber den Namen, nicht ueber den Dateinamen. Beides
        // ist bei diesem Bestand dasselbe, aber der Name ist das, was in der
        // App steht und was `mqtttc002 bilder` ausgibt.
        let bestand = Bildersammlung(ordner: Bilderordner.eigene)
        guard let bild = bestand.alle().first(where: { $0.name == name }) else {
            throw Abbruch(lokf("Kein Bild namens „%@“. „mqtttc002 bilder“ zeigt alle.", name))
        }
        // Dieselbe Entscheidung wie in der App (`Bildsendung.rahmen`).
        let rahmen = try Bildsendung.rahmen(aus: bild.datei, dauer: optionen.dauer)
        let json = try Anzeigen.nutzlast(rahmen)
        if optionen.trocken {
            for uhr in gewaehlte {
                switch uhr.wirksameBetriebsart {
                case .http: print("PUT http://\(uhr.host)/api/v1/apps/pushed/\(optionen.anzeigename)")
                case .mqtt: print(NGThema.anzeige(praefix: uhr.praefix, name: optionen.anzeigename))
                }
            }
            print(lokf("%d Byte Nutzlast, nichts gesendet (--trocken).", json.utf8.count))
            return
        }
        try anAlle(lokf("„%@“ gesendet an „%@“ (%d Byte)", bild.name, optionen.anzeigename,
                        json.utf8.count)) { anzeigen, uhr in
            try anzeigen.zeigen(rahmen, auf: optionen.anzeigename)
            // Vergessen, nicht merken: Ein Bild hat keine Regler, die sich
            // merken liessen; stand auf dem Platz vorher eine Textsendung,
            // rechnete der Block daraus sonst beim naechsten Start ohne Broker
            // weiter den alten Text. Dieselbe Entscheidung wie bei einem
            // gemalten Bild in der App (siehe `AppZustand.senden`).
            if let platz = Meldungsplatz.platz(fuerName: optionen.anzeigename) {
                _ = Slotgedaechtnis.gemeinsam.vergessen(fuer: uhr.id, platz: platz)
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

    case .uhren, .icons, .bilder, .effekte, .hilfe, .fassung:
        break                                    // oben schon abgehandelt
    }
}

do {
    try lauf()
} catch {
    fehlerAusgeben((error as? LocalizedError)?.errorDescription ?? "\(error)")
    exit(1)
}
