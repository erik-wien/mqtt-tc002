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
/// Schrift, Größe, Ausrichtung und Rand kommen aus dem, was zuletzt unter
/// „Senden" eingestellt war. Ein Kurzbefehl, der zwölf Fragen stellt, benutzt
/// niemand.
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

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) an die Uhr schicken") {
            \.$uhr
            \.$iconNummer
            \.$dauer
            \.$platz
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let einstellungen = Einstellungen.gelesen()
        let ziele = try zieleBestimmen(einstellungen)

        var optionen = Meldungsoptionen.ausAblage(.standard)
        optionen.text = text
        if let dauer, dauer > 0 { optionen.dauer = dauer }

        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene,
                                    leseordner: [Iconordner.mitgeliefert])
        var icon: Icon?
        if let nummer = iconNummer?.trimmingCharacters(in: .whitespaces), !nummer.isEmpty {
            guard let gefunden = sammlung.alle().first(where: { $0.nummer == nummer }) else {
                throw $iconNummer.needsValueError(IntentDialog(stringLiteral: lokf("Kein Icon mit der Nummer %@. In der App unter „Icon“ nachsehen.", nummer)))
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

        // Blockierende Netzarbeit gehört nicht auf den Hauptthread, auch nicht
        // im Intent — dort wartet sonst das System auf uns.
        let gesendet = try await Task.detached(priority: .userInitiated) { () -> [String] in
            var erledigt: [String] = []
            for ziel in ziele {
                guard let zugang = einstellungen.zugang(
                    clientID: "tc002-kurz-" + ziel.id.uuidString.prefix(8).lowercased()) else { continue }
                try Anzeigen(sender: MQTTSender(), zugang: zugang, praefix: ziel.praefix)
                    .zeigen(rahmen, auf: name)
                erledigt.append(ziel.name)
                // Erfolgreich gesendet: das Gedaechtnis merkt sich die Regler
                // fuer diesen Platz auf dieser Uhr. Schlaegt das Schreiben
                // fehl, bleibt die Sendung trotzdem erfolgreich — Kurzbefehle
                // haben kein Protokoll, in das eine Zeile koennte.
                Slotgedaechtnis.gemeinsam.merken(slotOptionen, icon: slotIcon,
                                                 fuer: ziel.id, platz: slotPlatz)
            }
            return erledigt
        }.value

        return .result(dialog: IntentDialog(stringLiteral: lokf("An %@ geschickt.", gesendet.joined(separator: ", "))))
    }

    /// Die gemeinten Uhren, oder ein Fehler, der sagt was fehlt.
    private func zieleBestimmen(_ e: Einstellungen) throws -> [Uhr] {
        guard e.brokerEingerichtet else {
            throw $text.needsValueError(IntentDialog(stringLiteral: lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Sichern und prüfen“ drücken.")))
        }
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
        let ohnePraefix = gewaehlt.filter { $0.praefix.isEmpty }
        guard ohnePraefix.isEmpty else {
            throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ auf „Abfragen“ tippen.", ohnePraefix.map(\.name).joined(separator: ", "))))
        }
        return gewaehlt
    }
}

/// Nimmt eine Meldung wieder von der Uhr. Über HTTP ginge das nicht — nur die
/// leere MQTT-Nutzlast löscht wirklich (Gerätereferenz §3.2 und §5.6).
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
        guard e.brokerEingerichtet else {
            throw $platz.needsValueError(IntentDialog(stringLiteral: lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Sichern und prüfen“ drücken.")))
        }
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
        let abgefragt = ziele.filter { !$0.praefix.isEmpty }
        guard !abgefragt.isEmpty else {
            throw $uhr.needsValueError(IntentDialog(stringLiteral: lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ auf „Abfragen“ tippen.", ziele.map(\.name).joined(separator: ", "))))
        }
        let name = Meldungsplatz.name(fuer: platz)
        try await Task.detached(priority: .userInitiated) {
            for ziel in abgefragt {
                guard let zugang = e.zugang(
                    clientID: "tc002-kurz-" + ziel.id.uuidString.prefix(8).lowercased()) else { continue }
                try Anzeigen(sender: MQTTSender(), zugang: zugang, praefix: ziel.praefix)
                    .loeschen(name)
            }
        }.value
        return .result(dialog: IntentDialog(stringLiteral: lokf("Slot %d entfernt.", platz)))
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
        AppShortcut(intent: MeldungLoeschenIntent(),
                    phrases: ["Nimm die Meldung von der Uhr mit \(.applicationName)",
                              "Clear a message with \(.applicationName)"],
                    shortTitle: "Meldung nehmen",
                    systemImageName: "trash")
    }
}
