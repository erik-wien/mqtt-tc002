import AppIntents
import Foundation
import TC002Core

/// Schickt eine Meldung an die Uhr — aus der Kurzbefehle-App, per Siri, aus
/// einer Automation oder von einem Knopf auf dem Sperrbildschirm.
///
/// Benutzt bewusst nicht `AppZustand`, sondern nur den Kern: Einstellungen
/// lesen, Rahmen bauen, senden. Dadurch braucht der Intent keine laufende
/// Oberfläche — und derselbe Weg trägt auf der Apple Watch, wo Kurzbefehle
/// ohne eigene App laufen.
///
/// Jede Formatangabe ist wahlfrei, und was fehlt, kommt aus dem, was zuletzt
/// unter „Senden" eingestellt war (`Meldungsoptionen.ausAblage`) — nicht aus
/// einer hier erfundenen Vorgabe. Ein Kurzbefehl, der zwölf Fragen stellt,
/// benutzt niemand; einer, der zwölf Fragen stellen *darf*, wenn man sie
/// braucht, schon. In der Kurzbefehle-App steht deshalb nur `text` im Satz,
/// alles Weitere unter „Details anzeigen".
struct MeldungSendenIntent: AppIntent {
    static let title: LocalizedStringResource = "Meldung an die Uhr schicken"
    static let description = IntentDescription(
        "Schickt einen Text an eine eingerichtete Ulanzi TC002. Schrift und Ausrichtung kommen aus den zuletzt in der App gewählten Einstellungen.")
    /// Kein Aufmachen der App: Das Senden dauert Bruchteile einer Sekunde, und
    /// wer aus einer Automation heraus schickt, will kein Fenster.
    static let openAppWhenRun = false

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Uhr", description: "Name oder Adresse. Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: String?

    @Parameter(title: "Icon-Nummer", description: "Nummer eines vorhandenen Icons.")
    var iconNummer: String?

    @Parameter(title: "Dauer in Sekunden")
    var dauer: Int?

    @Parameter(title: "Slot", description: "Platz 1 bis 5 auf der Uhr.",
               inclusiveRange: (1, 5))
    var platz: Int?

    // Ab hier das Format. Alles wahlfrei: Ein Kurzbefehl, der keine dieser
    // Angaben setzt, sendet genau wie bisher.

    @Parameter(title: "Weg", description: "„als Pixel“ rastert die App selbst und kann Umlaute. „als Text“ überlässt das Setzen der Uhr; deren Schrift kennt weder Umlaute noch eine Auswahl.")
    var weg: WegAuswahl?

    @Parameter(title: "Schriftart", description: "Gilt nur auf dem Weg „als Pixel“.")
    var schriftart: SchriftAuswahl?

    @Parameter(title: "Größe in Pixeln", description: "Nur die Größen, die die App zu dieser Schriftart anbietet. Eine andere wird abgewiesen; die Meldung nennt die möglichen.")
    var groesse: Int?

    @Parameter(title: "Fett", description: "Nicht jede Schrift hat bei jeder Größe einen fetten Schnitt; wo keiner ist, bleibt es ohne Wirkung.")
    var fett: Bool?

    @Parameter(title: "Großbuchstaben", description: "Wandelt den Text vor dem Senden um; aus „ß“ wird dabei „SS“.")
    var grossbuchstaben: Bool?

    @Parameter(title: "Farbe")
    var farbe: FarbAuswahl?

    @Parameter(title: "Ausrichtung waagrecht")
    var waagrecht: WaagrechtAuswahl?

    @Parameter(title: "Ausrichtung senkrecht")
    var senkrecht: SenkrechtAuswahl?

    @Parameter(title: "Rand", description: "Zeilen, die bei „oben“ und „unten“ frei bleiben, 0 bis 3. Bei „mittig“ ohne Wirkung.", inclusiveRange: (0, 3))
    var rand: Int?

    @Parameter(title: "Abstand", description: "Leere Spalten zwischen den Zeichen, 0 bis 3 — nur auf dem Weg „als Pixel“.", inclusiveRange: (0, 3))
    var abstand: Int?

    @Parameter(title: "Tempo", description: "Gilt nur, wenn der Text nicht ins Display passt.")
    var tempo: TempoAuswahl?

    @Parameter(title: "Icon mitscrollen", description: "Gilt nur, wenn der Text nicht ins Display passt.")
    var iconLaeuftMit: Bool?

    /// Die Formatangaben als das, was der Kern versteht. Die Regeln — was eine
    /// nicht angebotene Größe bedeutet, was ein Schriftwechsel mit ihr macht —
    /// stehen in `Formatangaben`, nicht hier: Sie sind eine Rechnung über
    /// `Meldungsoptionen` und werden dort geprüft.
    private var angaben: Formatangaben {
        Formatangaben(weg: weg?.kern, schrift: schriftart?.kern,
                      groesse: groesse.map(Double.init), fett: fett,
                      grossbuchstaben: grossbuchstaben, farbe: farbe?.kern,
                      waagrecht: waagrecht?.kern, senkrecht: senkrecht?.kern,
                      rand: rand, abstand: abstand, tempo: tempo?.kern,
                      iconLaeuftMit: iconLaeuftMit)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) an die Uhr schicken") {
            \.$uhr
            \.$iconNummer
            \.$dauer
            \.$platz
            \.$weg
            \.$schriftart
            \.$groesse
            \.$fett
            \.$grossbuchstaben
            \.$farbe
            \.$waagrecht
            \.$senkrecht
            \.$rand
            \.$abstand
            \.$tempo
            \.$iconLaeuftMit
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let einstellungen = Einstellungen.gelesen()
        let ziele = try zieleBestimmen(einstellungen)

        // Die Formatangaben legen sich über das, was zuletzt unter „Senden“
        // eingestellt war. Eine verlangte Größe, die es zu dieser Schrift nicht
        // gibt, kommt hier als Fehler zurück — und wird zur Rückfrage an genau
        // dem Feld, das sie ausgelöst hat, statt zu einem abgebrochenen
        // Kurzbefehl ohne Hinweis, woran es lag.
        var optionen: Meldungsoptionen
        do {
            optionen = try angaben.angewendet(auf: Meldungsoptionen.ausAblage(.standard))
        } catch let fehler as Formatangaben.Fehler {
            throw $groesse.needsValueError(IntentDialog(stringLiteral: fehler.localizedDescription))
        }
        optionen.text = text
        if let dauer, dauer > 0 { optionen.dauer = dauer }

        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene,
                                    leseordner: [Iconordner.mitgeliefert])
        // Beide Bestaende: Die App durchsucht die kanonischen 8×8 und die
        // eigenen 16×16 (`SendenView.sammlungen`). Fuer `Meldungsbau.rahmen`
        // bleibt `sammlung` die richtige: Der liest daraus nur die Daten-URI
        // der Datei, und die haengt am Icon (`Icon.datei`, `Icon.kante`),
        // nicht am Ordner.
        var icon: Icon?
        if let nummer = iconNummer?.trimmingCharacters(in: .whitespaces), !nummer.isEmpty {
            // Ein 16×16 hat keine LaMetric-Nummer; dort ist der Dateiname der
            // Schluessel. Darum sucht beides ueber dasselbe Feld, und die
            // Rueckfrage spricht von „Nummer oder Name".
            // `sammlung` statt `Iconbestaende.alle()`: Der Kurzbefehl liest
            // zusaetzlich `Iconordner.mitgeliefert` mit, die App tut das nicht.
            // Der Unterschied wird hier nicht angetastet — er gehoert nicht zu
            // dieser Aenderung, und ihn beilaeufig einzuebnen hiesse, ueber
            // geloeschte Grundschatz-Icons zu entscheiden, ohne gefragt zu sein.
            guard let gefunden = Iconbestaende.suchen(
                nummer, in: [sammlung, Iconsammlung(schreibordner: Iconordner.eigene16, kante: 16)]
            ) else {
                throw $iconNummer.needsValueError(IntentDialog(stringLiteral: lokf("Kein Icon mit der Nummer oder dem Namen %@. In der App unter „Icon“ nachsehen.", nummer)))
            }
            icon = gefunden
        }

        let slotPlatz = platz ?? 1
        let name = Meldungsplatz.name(fuer: slotPlatz)
        let rahmen = try Meldungsbau.rahmen(optionen, icon: icon, sammlung: sammlung)
        // Momentaufnahme fuer das Slotgedaechtnis (siehe unten): `optionen`
        // ist ab hier nicht mehr veraendert.
        let slotOptionen = optionen
        let slotIcon = icon?.nummer
        // Die Kante muss mit: Ohne sie rechnete das Gedaechtnis die Pruefsumme
        // mit 8, waehrend ein 16×16 gesendet wurde — und die Regler kaemen nie
        // zurueck (`Slotstand.iconKante`).
        let slotIconKante = icon?.kante ?? 8

        // Blockierende Netzarbeit gehört nicht auf den Hauptthread, auch nicht
        // im Intent — dort wartet sonst das System auf uns.
        let gesendet = try await Task.detached(priority: .userInitiated) { () -> [String] in
            var erledigt: [String] = []
            for ziel in ziele {
                // Derselbe Kanal wie in der App: Der Kurzbefehl folgt der
                // Betriebsart, die fuer diese Uhr eingestellt ist.
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: einstellungen.zugang(
                    clientID: "tc002-kurz-" + ziel.id.uuidString.prefix(8).lowercased())) else { continue }
                try anzeigen.zeigen(rahmen, auf: name)
                erledigt.append(ziel.name)
                // Erfolgreich gesendet: das Gedaechtnis merkt sich die Regler
                // fuer diesen Platz auf dieser Uhr. Schlaegt das Schreiben
                // fehl, bleibt die Sendung trotzdem erfolgreich — Kurzbefehle
                // haben kein Protokoll, in das eine Zeile koennte.
                Slotgedaechtnis.gemeinsam.merken(slotOptionen, icon: slotIcon,
                                                 iconKante: slotIconKante,
                                                 fuer: ziel.id, platz: slotPlatz)
            }
            return erledigt
        }.value

        return .result(dialog: IntentDialog(stringLiteral: lokf("An %@ geschickt.", gesendet.joined(separator: ", "))))
    }

    /// Die gemeinten Uhren, oder ein Fehler, der sagt was fehlt.
    private func zieleBestimmen(_ e: Einstellungen) throws -> [Uhr] {
        guard !e.uhren.isEmpty else {
            throw $text.needsValueError(IntentDialog(stringLiteral: lok("Noch keine Uhr eingerichtet. Das geht in der App unter „Einstellungen“.")))
        }
        let gewaehlt: [Uhr]
        if let name = uhr?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            guard let gefunden = e.uhr(benannt: name) else {
                throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Keine Uhr namens %@.", name)))
            }
            gewaehlt = [gefunden]
        } else {
            gewaehlt = e.ziele
        }
        // Erst jetzt, wo die Ziele feststehen: Ein Broker ist nur noetig, wenn
        // wenigstens eine dieser Uhren ueber ihn geht — sonst scheiterte ein
        // Kurzbefehl an einer Uhr aus einer Einrichtung, die er nicht benutzt.
        if Einstellungen.brokerNoetig(fuer: gewaehlt), !e.brokerEingerichtet {
            throw $text.needsValueError(IntentDialog(stringLiteral: lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Sichern und prüfen“ drücken.")))
        }
        let ohnePraefix = gewaehlt.filter { $0.wirksameBetriebsart == .mqtt && !$0.beschickbar }
        guard ohnePraefix.isEmpty else {
            throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ auf „Abfragen“ tippen.", ohnePraefix.map(\.name).joined(separator: ", "))))
        }
        let ohneAdresse = gewaehlt.filter { $0.wirksameBetriebsart == .http && !$0.beschickbar }
        guard ohneAdresse.isEmpty else {
            throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", ohneAdresse.map(\.name).joined(separator: ", "))))
        }
        return gewaehlt
    }
}

/// Nimmt eine Meldung wieder von der Uhr — auf dem Weg, der für sie
/// eingestellt ist: über MQTT mit leerer Nutzlast (Gerätereferenz §3.2), über
/// HTTP mit dem Rumpf `{}` (§5.6). Die beiden meinen mit „leer" genau das
/// Gegenteil voneinander; `Anzeigen` hält das auseinander.
struct MeldungLoeschenIntent: AppIntent {
    static let title: LocalizedStringResource = "Meldung von der Uhr nehmen"
    static let description = IntentDescription(
        "Entfernt eine der fünf Meldungen wieder von der Uhr.")
    static let openAppWhenRun = false

    @Parameter(title: "Slot", description: "Platz 1 bis 5 auf der Uhr.",
               inclusiveRange: (1, 5))
    var platz: Int

    @Parameter(title: "Uhr", description: "Name oder Adresse. Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Slot \(\.$platz) von der Uhr nehmen") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        guard !e.uhren.isEmpty else {
            throw $platz.needsValueError(IntentDialog(stringLiteral: lok("Noch keine Uhr eingerichtet. Das geht in der App unter „Einstellungen“.")))
        }
        let ziele: [Uhr]
        if let name = uhr?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            guard let gefunden = e.uhr(benannt: name) else {
                throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Keine Uhr namens %@.", name)))
            }
            ziele = [gefunden]
        } else {
            ziele = e.ziele
        }
        let abgefragt = ziele.filter(\.beschickbar)
        guard !abgefragt.isEmpty else {
            throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ auf „Abfragen“ tippen.", ziele.map(\.name).joined(separator: ", "))))
        }
        if Einstellungen.brokerNoetig(fuer: abgefragt), !e.brokerEingerichtet {
            throw $platz.needsValueError(IntentDialog(stringLiteral: lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Sichern und prüfen“ drücken.")))
        }
        let name = Meldungsplatz.name(fuer: platz)
        try await Task.detached(priority: .userInitiated) {
            for ziel in abgefragt {
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: e.zugang(
                    clientID: "tc002-kurz-" + ziel.id.uuidString.prefix(8).lowercased())) else { continue }
                try anzeigen.loeschen(name)
                // Erst nach der Sendung und je Uhr: Wer einen Platz raeumt,
                // wirft die Erinnerung an ihn weg — sonst rechnete ein Block
                // in der App daraus weiter den Text, der hier gerade von der
                // Uhr genommen wurde. Kein Protokoll hier; der Kurzbefehl hat
                // keines, und ein Fehlschlag darf die Loeschung nicht kippen.
                Slotgedaechtnis.gemeinsam.vergessen(fuer: ziel.id, platz: platz)
            }
        }.value
        return .result(dialog: IntentDialog(stringLiteral: lokf("Slot %d entfernt.", platz)))
    }
}

/// Ein fertiges Bild aus dem Bestand schicken.
///
/// Eigener Kurzbefehl und nicht eine Angabe an „Meldung schicken": Eine
/// 52 × 16-Anzeige ist das ganze Display und ersetzt Text und Icon. Von
/// den Angaben dort gelten hier nur die, die sagen *wohin* und *wie lange* —
/// alles Übrige formatiert Text, den es hier nicht gibt.
///
/// Die Bilder entstehen im Editor am Mac und am iPad und kommen über iCloud
/// hierher; gemalt wird am Telefon nicht.
struct BildSendenIntent: AppIntent {
    static let title: LocalizedStringResource = "Bild an die Uhr schicken"
    static let description = IntentDescription(
        "Schickt eine fertige 52 × 16-Anzeige aus dem Bestand an eine eingerichtete Ulanzi TC002. Sie füllt das Display und ersetzt Text und Icon.")
    static let openAppWhenRun = false

    @Parameter(title: "Bild", description: "Der Name, unter dem es im Editor gesichert wurde.")
    var bild: String

    @Parameter(title: "Uhr", description: "Name oder Adresse. Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: String?

    @Parameter(title: "Slot", description: "Platz 1 bis 5 auf der Uhr.",
               inclusiveRange: (1, 5))
    var platz: Int?

    @Parameter(title: "Dauer in Sekunden")
    var dauer: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Bild \(\.$bild) an die Uhr schicken") {
            \.$uhr
            \.$platz
            \.$dauer
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let name = bild.trimmingCharacters(in: .whitespaces)
        let bestand = Bildersammlung(ordner: Bilderordner.eigene)
        guard let gefunden = bestand.alle().first(where: { $0.name == name }) else {
            // Die Meldung nennt, was es gibt — ein Kurzbefehl hat keine Liste
            // zum Nachsehen, und der Name kommt womoeglich aus einer
            // Automation, die ihn nie gesehen hat.
            let alle = bestand.alle().map(\.name).sorted().joined(separator: ", ")
            throw $bild.needsValueError(IntentDialog(stringLiteral: alle.isEmpty
                ? lok("Noch keine Bilder. Sie entstehen im Editor am Mac und am iPad.")
                : lokf("Kein Bild namens %@. Vorhanden: %@", name, alle)))
        }

        let ziele = try zieleBestimmenFuerBild(e)
        // Dieselbe Entscheidung wie in App und Werkzeug: ein Einzelbild als
        // Rechtecke, mehrere als GIF (`Bildsendung.rahmen`).
        let rahmen = try Bildsendung.rahmen(aus: gefunden.datei, dauer: (dauer ?? 0) > 0 ? dauer : nil)
        let anzeigenname = Meldungsplatz.name(fuer: platz ?? 1)
        try await Task.detached(priority: .userInitiated) {
            for ziel in ziele {
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: e.zugang(
                    clientID: "tc002-kurz-" + ziel.id.uuidString.prefix(8).lowercased())) else { continue }
                try anzeigen.zeigen(rahmen, auf: anzeigenname)
                // Vergessen, nicht merken: Ein Bild hat keine Regler, die
                // sich merken liessen. Bliebe die Erinnerung an eine fruehere
                // Textsendung liegen, zeigte der Block in der App nach dem
                // naechsten Start ohne Broker wieder den alten Text.
                if let p = Meldungsplatz.platz(fuerName: anzeigenname) {
                    Slotgedaechtnis.gemeinsam.vergessen(fuer: ziel.id, platz: p)
                }
            }
        }.value
        return .result(dialog: IntentDialog(stringLiteral: lokf("%@ geschickt.", gefunden.name)))
    }

    /// Dieselbe Reihe von Pruefungen wie bei den beiden anderen Kurzbefehlen —
    /// eingerichtet, abgefragt, Broker vorhanden —, nur an den Feldern dieses
    /// Kurzbefehls aufgehaengt, damit die Rueckfrage dort landet, wo sie
    /// hingehoert.
    private func zieleBestimmenFuerBild(_ e: Einstellungen) throws -> [Uhr] {
        guard !e.uhren.isEmpty else {
            throw $bild.needsValueError(IntentDialog(stringLiteral: lok("Noch keine Uhr eingerichtet. Das geht in der App unter „Einstellungen“.")))
        }
        let gewaehlt: [Uhr]
        if let name = uhr?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            guard let ziel = e.uhr(benannt: name) else {
                throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Keine Uhr namens %@.", name)))
            }
            gewaehlt = [ziel]
        } else {
            gewaehlt = e.ziele
        }
        let abgefragt = gewaehlt.filter(\.beschickbar)
        guard !abgefragt.isEmpty else {
            throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ auf „Abfragen“ tippen.", gewaehlt.map(\.name).joined(separator: ", "))))
        }
        if Einstellungen.brokerNoetig(fuer: abgefragt), !e.brokerEingerichtet {
            throw $bild.needsValueError(IntentDialog(stringLiteral: lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Sichern und prüfen“ drücken.")))
        }
        return abgefragt
    }
}

/// Damit die beiden ohne Zutun in Siri und in der Suche auftauchen. Ohne diesen
/// Anbieter müsste man sie erst von Hand in einen Kurzbefehl einbauen.
struct TC002Kurzbefehle: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MeldungSendenIntent(),
                    phrases: ["Schicke eine Meldung mit \(.applicationName)",
                              "Send a message with \(.applicationName)"],
                    shortTitle: "Meldung schicken",
                    systemImageName: "paperplane")
        AppShortcut(intent: BildSendenIntent(),
                    phrases: ["Schicke ein Bild mit \(.applicationName)",
                              "Send an image with \(.applicationName)"],
                    shortTitle: "Bild schicken",
                    systemImageName: "photo")
        AppShortcut(intent: MeldungLoeschenIntent(),
                    phrases: ["Nimm die Meldung von der Uhr mit \(.applicationName)",
                              "Clear a message with \(.applicationName)"],
                    shortTitle: "Meldung nehmen",
                    systemImageName: "trash")
    }
}
