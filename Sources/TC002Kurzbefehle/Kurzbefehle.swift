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
    static let title: LocalizedStringResource = "Anzeige an die Uhr schicken"
    static let description = IntentDescription(
        "Schickt einen Text an eine eingerichtete Uhr. Schrift und Ausrichtung kommen aus den zuletzt in der App gewählten Einstellungen; Hintergrund, Effekt, Overlay und Palette gibt es hier nicht.")
    /// Kein Aufmachen der App: Das Senden dauert Bruchteile einer Sekunde, und
    /// wer aus einer Automation heraus schickt, will kein Fenster.
    static let openAppWhenRun = false

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Empfänger, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    @Parameter(title: "Icon", description: "Ein Icon aus den Beständen der App, 8 × 8 oder 16 × 16.")
    var iconauswahl: IconEntity?

    @Parameter(title: "Dauer in Sekunden", inclusiveRange: (1, 86400))
    var dauer: Int?

    @Parameter(title: "Platz", description: "Platz 1 bis 5 auf der Uhr.",
               inclusiveRange: (1, 5))
    var platz: Int?

    // Ab hier das Format. Alles wahlfrei: Ein Kurzbefehl, der keine dieser
    // Angaben setzt, sendet genau wie bisher.

    @Parameter(title: "Weg", description: "„als Pixel“ rastert die App selbst, mit einer ihrer Pixelschriften. „als Text“ überlässt das Setzen der Uhr; deren Schrift kennt Umlaute und Akzente, aber keine Auswahl.")
    var weg: WegAuswahl?

    @Parameter(title: "Schriftart", description: "Gilt nur auf dem Weg „als Pixel“.")
    var schriftart: SchriftAuswahl?

    @Parameter(title: "Größe in Pixeln", description: "Nur die Größen, die die App zu dieser Schriftart anbietet. Eine andere wird abgewiesen; der Hinweis nennt die möglichen.")
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

    @Parameter(title: "Icon mitscrollen", description: "Fest, einmal mitscrollen oder mitscrollen. Gilt nur, wenn der Text nicht ins Display passt. „Einmal mitscrollen“ gibt es nur mit „Schrift der Uhr“, sonst läuft das Icon mit.")
    var iconmodus: IconmodusAuswahl?

    /// Der frühere Schalter. Er steht nicht mehr in der Zusammenfassung, wird aber
    /// weiter gelesen: Ein bestehender Kurzbefehl behält seine Wirkung. Die neue
    /// Auswahl gewinnt, wenn beide gesetzt sind.
    @Parameter(title: "Icon mitscrollen (früher)", description: "Ersetzt durch die Auswahl „Icon mitscrollen“.")
    var iconLaeuftMit: Bool?

    @Parameter(title: "Lebensdauer in Minuten", description: "Nach dieser Zeit verschwindet die Anzeige von selbst. Ohne Angabe: 30 Minuten.", inclusiveRange: (1, 1440))
    var lebensdauer: Int?

    @Parameter(title: "Nach Ablauf", description: "Was nach der Lebensdauer geschieht: die Anzeige entfernen oder mit einem dunkelroten Rahmen markieren. Ohne Angabe: entfernen.")
    var ablauf: AblaufAuswahl?

    @Parameter(title: "Behalten", description: "Die Anzeige verschwindet nicht von selbst, sondern bleibt, bis sie ersetzt oder entfernt wird.", default: false)
    var behalten: Bool

    /// Die Formatangaben als das, was der Kern versteht. Die Regeln — was eine
    /// nicht angebotene Größe bedeutet, was ein Schriftwechsel mit ihr macht —
    /// stehen in `Formatangaben`, nicht hier: Sie sind eine Rechnung über
    /// `Meldungsoptionen` und werden dort geprüft.
    private var angaben: Formatangaben {
        Formatangaben.kurzbefehl(weg: weg, schriftart: schriftart, groesse: groesse, fett: fett,
                                 grossbuchstaben: grossbuchstaben, farbe: farbe,
                                 waagrecht: waagrecht, senkrecht: senkrecht, rand: rand,
                                 abstand: abstand, tempo: tempo, iconLaeuftMit: iconLaeuftMit, iconmodus: iconmodus)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) an die Uhr schicken") {
            \.$uhr
            \.$iconauswahl
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
            \.$iconmodus
            \.$lebensdauer
            \.$ablauf
            \.$behalten
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let einstellungen = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(einstellungen, uhr: uhr)

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
        if let dauer = Kurzbefehlswerte.dauer(dauer) { optionen.dauer = dauer }
        // Ohne Angabe bleibt `nil`, und das heisst: die Vorgabe (30 Minuten).
        if let wahl = Kurzbefehlswerte.lebensdauer(minuten: lebensdauer, behalten: behalten,
                                                   ablauf: ablauf?.kern) {
            optionen.lebensdauer = wahl
        }

        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene,
                                    leseordner: [Iconordner.mitgeliefert])
        // Beide Bestaende: Die App durchsucht die kanonischen 8×8 und die
        // eigenen 16×16 (`SendenView.sammlungen`). Fuer `Meldungsbau.rahmen`
        // bleibt `sammlung` die richtige: Der liest daraus nur die Daten-URI
        // der Datei, und die haengt am Icon (`Icon.datei`, `Icon.kante`),
        // nicht am Ordner.
        let icon: Icon?
        do {
            icon = try iconauswahl.map { try Kurzbefehlswerte.icon(kennung: $0.id) }
        } catch {
            throw $iconauswahl.needsValueError(IntentDialog(stringLiteral: error.localizedDescription))
        }

        let slotPlatz = platz ?? 1
        let name = Meldungsplatz.name(fuer: slotPlatz)
        // Momentaufnahme fuer das Slotgedaechtnis (siehe unten): `optionen`
        // ist ab hier nicht mehr veraendert.
        let slotOptionen = optionen

        // Blockierende Netzarbeit gehört nicht auf den Hauptthread, auch nicht
        // im Intent — dort wartet sonst das System auf uns.
        let ausgeblieben = Ausgebliebene()
        let gesendet = try await Task.detached(priority: .userInitiated) { () -> [String] in
            var erledigt: [String] = []
            for ziel in ziele {
                // Derselbe Kanal wie in der App: Der Kurzbefehl folgt der
                // Betriebsart, die fuer diese Uhr eingestellt ist. Ueber MQTT
                // wartet die Sendung auf `<Thema>/result`: Weist die Uhr ab,
                // zeigt die Kurzbefehle-App den Grund; bleibt die Antwort aus,
                // steht ein Hinweis im Dialog.
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: einstellungen.zugang(
                    clientID: MQTTKennung.fuer(.kurzbefehl, uhr: ziel.id)))?
                    .quittierend(beiAusbleiben: { _ in ausgeblieben.merken(ziel.name) }) else { continue }
                // Je Uhr in deren Anzeigemass gerastert.
                do {
                    try anzeigen.zeigen(try Meldungsbau.rahmen(optionen, icon: icon, sammlung: sammlung,
                                                               uhr: ziel),
                                        auf: name)
                } catch {
                    throw KurzbefehlFehler(uhr: ziel.name, error)
                }
                erledigt.append(ziel.name)
                // Erfolgreich gesendet: das Gedaechtnis merkt sich die Regler
                // fuer diesen Platz auf dieser Uhr. Schlaegt das Schreiben
                // fehl, bleibt die Sendung trotzdem erfolgreich — Kurzbefehle
                // haben kein Protokoll, in das eine Zeile koennte.
                Slotgedaechtnis.gemeinsam.merken(slotOptionen, icon: icon,
                                                 iconAbstand: ziel.wirksamerIconAbstand,
                                                 fuer: ziel.id, platz: slotPlatz,
                                                 mass: Anzeigemass.fuer(ziel))
            }
            return erledigt
        }.value

        // Eine Uhr mit acht Zeilen bekommt statt eines gewaehlten 16×16 dessen
        // 8×8-Fassung; die Vorschau der App nennt das, der Dialog auch.
        let kleinereIcons = icon.map {
            Iconbestaende.hinweise(gewaehlt: $0, fuer: ziele.filter { z in gesendet.contains(z.name) })
        } ?? []
        return .result(dialog: IntentDialog(stringLiteral:
            lokf("An %@ geschickt.", gesendet.joined(separator: ", ")) + ausgeblieben.hinweis
            + kleinereIcons.map { " " + $0 + "." }.joined()))
    }
}

/// Nimmt eine Meldung wieder von der Uhr — auf dem Weg, der für sie
/// eingestellt ist: über MQTT mit leerer Nutzlast (Gerätereferenz §3.2), über
/// HTTP mit dem Rumpf `{}` (§5.6). Die beiden meinen mit „leer" genau das
/// Gegenteil voneinander; `Anzeigen` hält das auseinander.
struct MeldungLoeschenIntent: AppIntent {
    static let title: LocalizedStringResource = "Anzeige von der Uhr löschen"
    static let description = IntentDescription(
        "Entfernt eine der fünf Anzeigen wieder von der Uhr.")
    static let openAppWhenRun = false

    @Parameter(title: "Platz", description: "Platz 1 bis 5 auf der Uhr.",
               inclusiveRange: (1, 5))
    var platz: Int

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Empfänger, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Platz \(\.$platz) von der Uhr löschen") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let abgefragt = try KurzbefehlFehler.ziele(e, uhr: uhr, nurBeschickbare: true)
        // Erst nach der Pruefung der Ziele, damit die Rueckfrage nur kommt,
        // wenn auch wirklich geloescht wuerde. Die Variante mit Text gibt es
        // ab iOS 18; davor fragt das System mit seinem Standardtext.
        if #available(iOS 18.0, macOS 15.0, *) {
            try await requestConfirmation(
                actionName: .do,
                dialog: IntentDialog(stringLiteral: lokf("Platz %d von der Uhr löschen?", platz)))
        } else {
            try await requestConfirmation()
        }
        let name = Meldungsplatz.name(fuer: platz)
        try await Task.detached(priority: .userInitiated) {
            for ziel in abgefragt {
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: e.zugang(
                    clientID: MQTTKennung.fuer(.kurzbefehl, uhr: ziel.id))) else { continue }
                try anzeigen.loeschen(name)
                // Erst nach der Sendung und je Uhr: Wer einen Platz raeumt,
                // wirft die Erinnerung an ihn weg — sonst rechnete ein Block
                // in der App daraus weiter den Text, der hier gerade von der
                // Uhr genommen wurde. Kein Protokoll hier; der Kurzbefehl hat
                // keines, und ein Fehlschlag darf die Loeschung nicht kippen.
                Slotgedaechtnis.gemeinsam.vergessen(fuer: ziel.id, platz: platz)
            }
        }.value
        return .result(dialog: IntentDialog(stringLiteral: lokf("Platz %d entfernt.", platz)))
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
        "Schickt eine fertige 52 × 16-Anzeige aus dem Bestand an eine eingerichtete Ulanzi TC002. Sie füllt das Display und ersetzt Text und Icon. Eine Uhr mit kleinerem Display weist sie ab.")
    static let openAppWhenRun = false

    @Parameter(title: "Bild", description: "Das Bild, wie es im Editor gesichert wurde.")
    var bild: BildEntity

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Empfänger, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    @Parameter(title: "Platz", description: "Platz 1 bis 5 auf der Uhr.",
               inclusiveRange: (1, 5))
    var platz: Int?

    @Parameter(title: "Dauer in Sekunden", inclusiveRange: (1, 86400))
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
        let name = bild.id
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

        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr, nurBeschickbare: true)
        // Dieselbe Entscheidung wie in App und Werkzeug: ein Einzelbild als
        // Standbild, mehrere als GIF (`Bildsendung.rahmen`).
        let rahmen = try Bildsendung.rahmen(aus: gefunden.datei, dauer: Kurzbefehlswerte.dauer(dauer))
        let anzeigenname = Meldungsplatz.name(fuer: platz ?? 1)
        try await Task.detached(priority: .userInitiated) {
            for ziel in ziele {
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: e.zugang(
                    clientID: MQTTKennung.fuer(.kurzbefehl, uhr: ziel.id))) else { continue }
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
}

/// Der Einstieg für die Mac-App. Die Intents stehen in einem Bibliotheksziel,
/// und der Linker nimmt aus einer Bibliothek nur mit, worauf etwas verweist;
/// dieser Verweis hält das Modul — samt allen Kurzbefehlen — im Programm.
public enum Kurzbefehle {
    public static func einbinden() {
        _ = Kurzbefehlsanbieter.self
    }
}

/// Damit sie ohne Zutun in Siri und in der Suche auftauchen. Ohne diesen
/// Anbieter müsste man sie erst von Hand in einen Kurzbefehl einbauen.
struct Kurzbefehlsanbieter: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MeldungSendenIntent(),
                    phrases: ["Schicke eine Anzeige mit \(.applicationName)",
                              "Show on the clock with \(.applicationName)"],
                    shortTitle: "Anzeige schicken",
                    systemImageName: "paperplane")
        AppShortcut(intent: BildSendenIntent(),
                    phrases: ["Schicke ein Bild mit \(.applicationName)",
                              "Send an image with \(.applicationName)"],
                    shortTitle: "Bild schicken",
                    systemImageName: "photo")
        AppShortcut(intent: BenachrichtigungSendenIntent(),
                    phrases: ["Schicke eine Nachricht mit \(.applicationName)",
                              "Send a message with \(.applicationName)"],
                    shortTitle: "Nachricht senden",
                    systemImageName: "bell")
        AppShortcut(intent: BenachrichtigungZurueckziehenIntent(),
                    phrases: ["Ziehe eine Nachricht zurück mit \(.applicationName)",
                              "Dismiss a message with \(.applicationName)"],
                    shortTitle: "Nachricht zurückziehen",
                    systemImageName: "bell.slash")
        AppShortcut(intent: MeldungLoeschenIntent(),
                    phrases: ["Lösche die Anzeige von der Uhr mit \(.applicationName)",
                              "Remove from the clock with \(.applicationName)"],
                    shortTitle: "Anzeige löschen",
                    systemImageName: "trash")
        // Die Fernbedienung. Apple lässt höchstens zehn solche Einträge zu; die
        // übrigen Aktionen (Overlay, Anzeiger, Neustart) stehen trotzdem in der
        // Kurzbefehle-App und lassen sich dort zu einem Kurzbefehl zusammensetzen.
        AppShortcut(intent: DisplaySchaltenIntent(),
                    phrases: ["Schalte das Display der Uhr mit \(.applicationName)",
                              "Switch the clock display with \(.applicationName)"],
                    shortTitle: "Display schalten",
                    systemImageName: "power")
        AppShortcut(intent: HelligkeitSetzenIntent(),
                    phrases: ["Stelle die Helligkeit der Uhr ein mit \(.applicationName)",
                              "Set the clock brightness with \(.applicationName)"],
                    shortTitle: "Helligkeit einstellen",
                    systemImageName: "sun.max")
        AppShortcut(intent: MoodlightSetzenIntent(),
                    phrases: ["Schalte das Moodlight der Uhr mit \(.applicationName)",
                              "Set the clock moodlight with \(.applicationName)"],
                    shortTitle: "Moodlight",
                    systemImageName: "lightbulb")
        AppShortcut(intent: AnzeigeBlaetternIntent(),
                    phrases: ["Wechsle die Anzeige der Uhr mit \(.applicationName)",
                              "Change the clock display with \(.applicationName)"],
                    shortTitle: "Anzeige wechseln",
                    systemImageName: "forward")
    }
}
