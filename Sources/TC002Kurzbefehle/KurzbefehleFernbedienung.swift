import AppIntents
import Foundation
import TC002Core

// Die Fernbedienung als Kurzbefehle: was die Seite „Uhr“ der App (Fernbedienung)
// schaltet — Display, Helligkeit, Overlay, Moodlight, Anzeiger, Blättern,
// Neustart. Wie die Meldungen benutzen sie nur den Kern (`Anzeigen`), nicht
// `AppZustand`; Grenzen und Verbote stehen in `Kurzbefehlswerte` und im Kern.
//
// Eine Uhr, die einen Befehl nie kann (Helligkeitsautomatik ohne Lichtsensor,
// ein Overlay, das sie nicht kennt), bekommt ihn nicht: Der Kern wirft einen
// Fehler, und der Kurzbefehl zeigt ihn mit dem Namen der Uhr, statt still nichts
// zu tun (`docs/funktionen-je-uhr.md`).

/// Schickt einen Steuerbefehl an die gemeinten Uhren.
enum Fernbedienungslauf {
    /// Was die Uhr kann, soweit sie es sagt (`capabilities`); `nil` ohne Adresse
    /// oder ohne Antwort — dann entscheidet der Kern ohne diese Auskunft.
    static func faehigkeiten(_ ziel: Uhr) -> Geraetefaehigkeiten? {
        ziel.host.isEmpty ? nil : ((try? Geraet(host: ziel.host).faehigkeiten(fuer: ziel)) ?? nil)
    }

    /// - Returns: die Namen der Uhren, bei denen der Befehl angekommen ist.
    static func ausfuehren(_ einstellungen: Einstellungen, ziele: [Uhr],
                           _ tat: @escaping @Sendable (Anzeigen, Uhr) throws -> Void) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) { () -> [String] in
            var erledigt: [String] = []
            for ziel in ziele {
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: einstellungen.zugang(
                    clientID: MQTTKennung.fuer(.kurzbefehl, uhr: ziel.id))) else { continue }
                do {
                    try tat(anzeigen, ziel)
                } catch {
                    throw KurzbefehlFehler(uhr: ziel.name, error)
                }
                erledigt.append(ziel.name)
            }
            return erledigt
        }.value
    }
}

enum AnAusAuswahl: String, AppEnum {
    case an, aus

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Zustand")
    }
    static var caseDisplayRepresentations: [AnAusAuswahl: DisplayRepresentation] = [
        .an: DisplayRepresentation(title: "An"),
        .aus: DisplayRepresentation(title: "Aus"),
    ]

    var istAn: Bool { self == .an }
}

enum BlaetternAuswahl: String, AppEnum {
    case naechste, vorherige

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Richtung")
    }
    static var caseDisplayRepresentations: [BlaetternAuswahl: DisplayRepresentation] = [
        .naechste: DisplayRepresentation(title: "Nächste Anzeige"),
        .vorherige: DisplayRepresentation(title: "Vorherige Anzeige"),
    ]
}

/// Schaltet das Panel ein oder aus (`power`); die Uhr läuft weiter.
struct DisplaySchaltenIntent: AppIntent {
    static let title: LocalizedStringResource = "Display der Uhr schalten"
    static let description = IntentDescription(
        "Schaltet das Display der Uhr ein oder aus. Aus ist das Panel dunkel; die Uhr läuft weiter.")
    static let openAppWhenRun = false

    @Parameter(title: "Zustand", default: .an)
    var zustand: AnAusAuswahl

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Display der Uhr: \(\.$zustand)") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr)
        let an = zustand.istAn
        let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, _ in
            try anzeigen.anzeigeStrom(an)
        }
        let satz = an ? lokf("Display von %@ eingeschaltet.", erreicht.joined(separator: ", "))
                      : lokf("Display von %@ ausgeschaltet.", erreicht.joined(separator: ", "))
        return .result(dialog: IntentDialog(stringLiteral: satz))
    }
}

/// Helligkeit in Prozent (wie der Regler der App) oder die Regelung durch den
/// Lichtsensor — nur auf Uhren, die einen haben.
struct HelligkeitSetzenIntent: AppIntent {
    static let title: LocalizedStringResource = "Helligkeit der Uhr einstellen"
    static let description = IntentDescription(
        "Stellt die Helligkeit des Displays ein, in Prozent, oder schaltet die Regelung durch den Lichtsensor ein oder aus. Die Automatik gibt es nur bei Uhren mit Lichtsensor; eine andere weist sie ab.")
    static let openAppWhenRun = false

    @Parameter(title: "Helligkeit in Prozent", description: "0 bis 100. Solange der Lichtsensor regelt, gilt der Wert erst, wenn die Automatik aus ist.",
               inclusiveRange: (0, 100))
    var prozent: Int?

    @Parameter(title: "Automatisch", description: "An: der Lichtsensor regelt die Helligkeit. Aus: der Wert gilt. Nicht zusammen mit einem Wert und nur bei Uhren mit Lichtsensor.")
    var automatisch: Bool?

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Helligkeit der Uhr einstellen") {
            \.$prozent
            \.$automatisch
            \.$uhr
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let wunsch = Helligkeitswunsch(prozent: prozent, automatisch: automatisch)
        do {
            try wunsch.pruefen()
        } catch Helligkeitswunsch.Fehler.nichtsAngegeben {
            throw $prozent.needsValueError(IntentDialog(stringLiteral: Helligkeitswunsch.Fehler.nichtsAngegeben.localizedDescription))
        } catch {
            throw KurzbefehlFehler(text: error.localizedDescription)
        }
        let e = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr)
        // Der Sensor uebergeht einen festen Wert, solange die Automatik an ist,
        // und die Uhr meldet das nicht: Der Dialog sagt es.
        let vomSensor = Ausgebliebene()
        let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, ziel in
            let caps = (wunsch.automatisch != nil) ? Fernbedienungslauf.faehigkeiten(ziel) : nil
            try wunsch.anwenden(auf: anzeigen, faehigkeiten: caps)
            if wunsch.prozent != nil, wunsch.automatisch == nil, !ziel.host.isEmpty,
               let einst = try? Geraet(host: ziel.host).einstellungen(),
               einst.sensorRegeltHelligkeit(faehigkeiten: Fernbedienungslauf.faehigkeiten(ziel)) {
                vomSensor.merken(ziel.name)
            }
        }
        var satz = lokf("Helligkeit von %@ eingestellt.", erreicht.joined(separator: ", "))
        if !vomSensor.uhren.isEmpty {
            satz += " " + lokf("%@ regelt die Helligkeit mit dem Lichtsensor; der Wert gilt erst, wenn die Automatik aus ist.",
                               vomSensor.uhren.joined(separator: ", "))
        }
        return .result(dialog: IntentDialog(stringLiteral: satz))
    }
}

/// Wetter-Overlay über allem; ohne Namen nimmt es sie weg.
struct OverlaySetzenIntent: AppIntent {
    static let title: LocalizedStringResource = "Overlay der Uhr setzen"
    static let description = IntentDescription(
        "Legt ein Wetter-Overlay über alle Anzeigen der Uhr, oder nimmt es weg. Welche Namen es gibt, sagt die Uhr (in der App unter „Anzeige“ › „Overlay“).")
    static let openAppWhenRun = false

    @Parameter(title: "Overlay", description: "Name des Overlays, wie ihn die Uhr anbietet. Leer nimmt es weg.")
    var overlay: String?

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Overlay der Uhr auf \(\.$overlay) setzen") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr)
        let name = overlay?.trimmingCharacters(in: .whitespaces)
        let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, ziel in
            try anzeigen.overlay(name, faehigkeiten: Fernbedienungslauf.faehigkeiten(ziel))
        }
        let satz = (name?.isEmpty ?? true)
            ? lokf("Overlay von %@ entfernt.", erreicht.joined(separator: ", "))
            : lokf("Overlay von %@ gesetzt.", erreicht.joined(separator: ", "))
        return .result(dialog: IntentDialog(stringLiteral: satz))
    }
}

/// Flutet das Panel einfarbig, oder schaltet es aus.
struct MoodlightSetzenIntent: AppIntent {
    static let title: LocalizedStringResource = "Moodlight der Uhr einstellen"
    static let description = IntentDescription(
        "Schaltet das Moodlight ein, mit einer Farbe oder einem Weißton, oder aus. Ohne Angabe leuchtet es weiß.")
    static let openAppWhenRun = false

    @Parameter(title: "Zustand", default: .an)
    var zustand: AnAusAuswahl

    @Parameter(title: "Farbe", description: "Nicht zusammen mit einem Weißton.")
    var farbe: FarbAuswahl?

    @Parameter(title: "Weißton in Kelvin", description: "1000 bis 40000. Nicht zusammen mit einer Farbe.",
               inclusiveRange: (1000, 40000))
    var weisston: Int?

    @Parameter(title: "Helligkeit in Prozent", description: "0 bis 100. Ohne Angabe bleibt die Helligkeit, wie die Uhr sie hat.",
               inclusiveRange: (0, 100))
    var prozent: Int?

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Moodlight der Uhr: \(\.$zustand)") {
            \.$farbe
            \.$weisston
            \.$prozent
            \.$uhr
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr)
        if zustand == .aus {
            let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, _ in
                try anzeigen.moodlightAus()
            }
            return .result(dialog: IntentDialog(stringLiteral:
                lokf("Moodlight von %@ ausgeschaltet.", erreicht.joined(separator: ", "))))
        }
        let licht: Moodlight
        do {
            licht = try Kurzbefehlswerte.moodlight(farbe: farbe?.kern, kelvin: weisston, prozent: prozent)
        } catch {
            throw KurzbefehlFehler(text: error.localizedDescription)
        }
        let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, _ in
            try anzeigen.moodlight(licht)
        }
        return .result(dialog: IntentDialog(stringLiteral:
            lokf("Moodlight von %@ eingeschaltet.", erreicht.joined(separator: ", "))))
    }
}

/// Einer der drei Anzeiger am Rand: Farbe, Blinken, Blenden — oder aus.
struct AnzeigerSetzenIntent: AppIntent {
    static let title: LocalizedStringResource = "Anzeiger der Uhr einstellen"
    static let description = IntentDescription(
        "Schaltet einen der drei Anzeiger am Rand der Uhr ein, mit Farbe, Blinken und Blenden, oder aus. Anzeiger 1 ist oben, 3 unten.")
    static let openAppWhenRun = false

    @Parameter(title: "Anzeiger", description: "1 (oben) bis 3 (unten).", default: 1, inclusiveRange: (1, 3))
    var nummer: Int

    @Parameter(title: "Zustand", default: .an)
    var zustand: AnAusAuswahl

    @Parameter(title: "Farbe", default: .weiss)
    var farbe: FarbAuswahl

    @Parameter(title: "Blinken in Millisekunden", description: "0 bis 65535. Ohne Angabe: kein Blinken.",
               inclusiveRange: (0, 65535))
    var blinken: Int?

    @Parameter(title: "Blenden in Millisekunden", description: "0 bis 65535. Ohne Angabe: kein Überblenden.",
               inclusiveRange: (0, 65535))
    var blenden: Int?

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Anzeiger \(\.$nummer) der Uhr: \(\.$zustand)") {
            \.$farbe
            \.$blinken
            \.$blenden
            \.$uhr
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr)
        let nummer = nummer
        if zustand == .aus {
            let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, _ in
                try anzeigen.indikatorAus(nummer)
            }
            return .result(dialog: IntentDialog(stringLiteral:
                lokf("Anzeiger %d von %@ ausgeschaltet.", nummer, erreicht.joined(separator: ", "))))
        }
        // Die Uhr nimmt Blinken und Blenden mit jeder Anfrage neu: Was fehlt, ist 0.
        let stand = Indikator(nummer: nummer, farbe: farbe.kern, blinkMs: blinken ?? 0, fadeMs: blenden ?? 0)
        let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, _ in
            try anzeigen.indikator(stand)
        }
        return .result(dialog: IntentDialog(stringLiteral:
            lokf("Anzeiger %d von %@ eingeschaltet.", nummer, erreicht.joined(separator: ", "))))
    }
}

/// Eine Anzeige vor oder zurück.
struct AnzeigeBlaetternIntent: AppIntent {
    static let title: LocalizedStringResource = "Anzeige der Uhr wechseln"
    static let description = IntentDescription(
        "Schaltet die Uhr zur nächsten oder vorherigen Anzeige ihrer Schleife.")
    static let openAppWhenRun = false

    @Parameter(title: "Richtung", default: .naechste)
    var richtung: BlaetternAuswahl

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Anzeige der Uhr wechseln: \(\.$richtung)") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr)
        let vor = richtung == .naechste
        let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, _ in
            try anzeigen.blaettern(vor: vor)
        }
        let satz = vor ? lokf("%@ zeigt die nächste Anzeige.", erreicht.joined(separator: ", "))
                       : lokf("%@ zeigt die vorherige Anzeige.", erreicht.joined(separator: ", "))
        return .result(dialog: IntentDialog(stringLiteral: satz))
    }
}

/// Startet die Uhr neu. Die Uhr ist danach kurz nicht erreichbar; darum fragt
/// der Kurzbefehl vorher nach, wie die App.
struct UhrNeustartenIntent: AppIntent {
    static let title: LocalizedStringResource = "Uhr neu starten"
    static let description = IntentDescription(
        "Startet die Uhr neu. Sie ist danach kurz nicht erreichbar.")
    static let openAppWhenRun = false

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Uhr neu starten") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let e = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(e, uhr: uhr)
        if #available(iOS 18.0, macOS 15.0, *) {
            try await requestConfirmation(
                actionName: .do,
                dialog: IntentDialog(stringLiteral: lokf("%@ neu starten?", ziele.map(\.name).joined(separator: ", "))))
        } else {
            try await requestConfirmation()
        }
        let erreicht = try await Fernbedienungslauf.ausfuehren(e, ziele: ziele) { anzeigen, _ in
            try anzeigen.neustarten()
        }
        return .result(dialog: IntentDialog(stringLiteral:
            lokf("%@ wird neu gestartet.", erreicht.joined(separator: ", "))))
    }
}
