import AppIntents
import Foundation
import TC002Core

/// Ein Fehler, den die Kurzbefehle-App anzeigt. Ein gewöhnlicher `LocalizedError`
/// käme dort als „Die Aktion konnte nicht ausgeführt werden" an; dieser trägt
/// den übersetzten Satz.
struct KurzbefehlFehler: Error, CustomLocalizedStringResourceConvertible {
    let text: String

    /// Mit dem Namen der Uhr davor: Sendet der Kurzbefehl an mehrere, sagt erst
    /// das, welche abgewiesen hat.
    init(uhr: String, _ fehler: Error) {
        let grund = (fehler as? LocalizedError)?.errorDescription ?? "\(fehler)"
        text = lokf("%@: %@", uhr, grund)
    }

    var localizedStringResource: LocalizedStringResource { LocalizedStringResource(stringLiteral: text) }
}

/// Sammelt, welche Uhren auf ein Kommando nicht geantwortet haben. Die Sendung
/// läuft losgelöst vom Hauptthread, die Meldung kommt von dort.
final class Ausgebliebene: @unchecked Sendable {
    private let sperre = NSLock()
    private var _uhren: [String] = []

    func merken(_ uhr: String) {
        sperre.lock(); _uhren.append(uhr); sperre.unlock()
    }
    var uhren: [String] { sperre.lock(); defer { sperre.unlock() }; return _uhren }

    /// Ein Satz für den Dialog, oder nichts. Keine Antwort ist eine Warnung und
    /// kein Fehler (`Anzeigen.quittierend`).
    var hinweis: String {
        uhren.isEmpty ? "" : " " + lokf("Keine Antwort von %@ — Thema und Präfix prüfen.", uhren.joined(separator: ", "))
    }
}

/// Die gemeinten Uhren für die Kurzbefehle zur Benachrichtigung — dieselben
/// Prüfungen wie bei den übrigen, nur einmal geschrieben. Der Fehler sagt, an
/// welchem Feld die Rückfrage hängt.
enum Kurzbefehlsziele {
    struct Hinweis: Error {
        let amUhrfeld: Bool
        let text: String
    }

    static func bestimmen(_ e: Einstellungen, uhr: String?) throws -> [Uhr] {
        guard !e.uhren.isEmpty else {
            throw Hinweis(amUhrfeld: false, text: lok("Noch keine Uhr eingerichtet. Das geht in der App unter „Einstellungen“."))
        }
        let gewaehlt: [Uhr]
        if let name = uhr?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            guard let gefunden = e.uhr(benannt: name) else {
                throw Hinweis(amUhrfeld: true, text: lokf("Keine Uhr namens %@.", name))
            }
            gewaehlt = [gefunden]
        } else {
            gewaehlt = e.ziele
        }
        // Erst jetzt, wo die Ziele feststehen: Ein Broker ist nur noetig, wenn
        // wenigstens eine dieser Uhren ueber ihn geht.
        if Einstellungen.brokerNoetig(fuer: gewaehlt), !e.brokerEingerichtet {
            throw Hinweis(amUhrfeld: false, text: lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Sichern und prüfen“ drücken."))
        }
        let ohnePraefix = gewaehlt.filter { $0.wirksameBetriebsart == .mqtt && !$0.beschickbar }
        guard ohnePraefix.isEmpty else {
            throw Hinweis(amUhrfeld: true, text: lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ auf „Abfragen“ tippen.", ohnePraefix.map(\.name).joined(separator: ", ")))
        }
        let ohneAdresse = gewaehlt.filter { $0.wirksameBetriebsart == .http && !$0.beschickbar }
        guard ohneAdresse.isEmpty else {
            throw Hinweis(amUhrfeld: true, text: lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", ohneAdresse.map(\.name).joined(separator: ", ")))
        }
        return gewaehlt
    }
}

/// Zeigt einmalig einen Text über der Schleife der Uhr — keine Anzeige, kein
/// Platz, kein Eintrag im Slotgedächtnis.
///
/// Format wie bei „Meldung schicken": was fehlt, kommt aus dem, was zuletzt unter
/// „Senden" eingestellt war.
struct BenachrichtigungSendenIntent: AppIntent {
    static let title: LocalizedStringResource = "Nachricht senden"
    static let description = IntentDescription(
        "Zeigt eine Nachricht einmalig über der Schleife der Uhr, statt eine Anzeige anzulegen. Schrift und Ausrichtung kommen aus den zuletzt in der App gewählten Einstellungen.")
    static let openAppWhenRun = false

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Uhr", description: "Name oder Adresse. Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: String?

    @Parameter(title: "Halten", description: "Bleibt stehen, bis sie zurückgezogen wird.", default: false)
    var halten: Bool

    @Parameter(title: "Aufwecken", description: "Erscheint auch bei ausgeschaltetem Panel.", default: true)
    var aufwecken: Bool

    @Parameter(title: "Name", description: "Nur unter diesem Namen lässt sie sich später zurückziehen. Buchstaben, Ziffern, „_“ und „-“.")
    var name: String?

    @Parameter(title: "Dauer in Sekunden")
    var dauer: Int?

    @Parameter(title: "Klang", description: "Name einer Melodie oder MP3-Datei auf der Uhr.")
    var klang: String?

    @Parameter(title: "Vorlesen", description: "Die Uhr liest den Text vor, auf Englisch.", default: false)
    var vorlesen: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) als Nachricht an die Uhr senden") {
            \.$uhr
            \.$halten
            \.$aufwecken
            \.$name
            \.$dauer
            \.$klang
            \.$vorlesen
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let einstellungen = Einstellungen.gelesen()
        let ziele: [Uhr]
        do {
            ziele = try Kurzbefehlsziele.bestimmen(einstellungen, uhr: uhr)
        } catch let h as Kurzbefehlsziele.Hinweis {
            throw h.amUhrfeld ? $uhr.needsValueError(IntentDialog(stringLiteral: h.text))
                              : $text.needsValueError(IntentDialog(stringLiteral: h.text))
        }

        let benannt = name?.trimmingCharacters(in: .whitespaces)
        let klangname = klang?.trimmingCharacters(in: .whitespaces) ?? ""
        if vorlesen && !klangname.isEmpty {
            throw $vorlesen.needsValueError(IntentDialog(stringLiteral: lok("Entweder ein Klang oder Vorlesen, nicht beides.")))
        }
        let klangwahl = vorlesen ? Klangwahl(art: .vorlesen)
            : (klangname.isEmpty ? Klangwahl() : Klangwahl(art: .uhr, name: klangname))
        let bo = Benachrichtigungsoptionen(name: (benannt?.isEmpty ?? true) ? nil : benannt,
                                           halten: halten, aufwecken: aufwecken,
                                           klang: klangwahl.klaenge(nachrichtentext: text))
        if let n = bo.name, !Benachrichtigungsoptionen.nameGueltig(n) {
            throw $name.needsValueError(IntentDialog(stringLiteral: NGFehler.ungueltigerName(n).localizedDescription))
        }

        var optionen = Meldungsoptionen.ausAblage(.standard)
        optionen.text = text
        if let dauer, dauer > 0 { optionen.dauer = dauer }
        let gesetzt = optionen
        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene,
                                    leseordner: [Iconordner.mitgeliefert])
        let ausgeblieben = Ausgebliebene()
        let ohneKlang = Ausgebliebene()

        let gesendet = try await Task.detached(priority: .userInitiated) { () -> [String] in
            var erledigt: [String] = []
            for ziel in ziele {
                // Derselbe Kanal wie in der App; ueber MQTT wartet die Sendung
                // auf `<Thema>/result` (`Anzeigen.quittierend`).
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: einstellungen.zugang(
                    clientID: MQTTKennung.fuer(.kurzbefehl, uhr: ziel.id)))?
                    .quittierend(beiAusbleiben: { _ in ausgeblieben.merken(ziel.name) }) else { continue }
                // Der Klang geht nur an eine Uhr, die ihn spielt; die Nachricht geht in jedem Fall.
                var eigene = bo
                if !bo.klang.isEmpty, !ziel.host.isEmpty {
                    let g = Geraet(host: ziel.host)
                    let caps = (try? g.faehigkeiten()) ?? nil
                    let listen = (try? g.melodien()).map { Tonlisten(melodien: $0.namen, mp3: (try? g.mp3Dateien())?.namen ?? []) }
                    let verteilung = Klangeignung.verteilen(bo.klang, an: [Klangziel(id: ziel.id, name: ziel.name,
                                                                                    faehigkeiten: caps, listen: listen)])
                    eigene.klang = verteilung.klaenge[ziel.id] ?? bo.klang
                    if !verteilung.uebersprungen.isEmpty { ohneKlang.merken(ziel.name) }
                }
                do {
                    try anzeigen.benachrichtigen(try Meldungsbau.rahmen(gesetzt, icon: nil, sammlung: sammlung,
                                                                       mass: Anzeigemass.fuer(ziel)), eigene)
                } catch {
                    throw KurzbefehlFehler(uhr: ziel.name, error)
                }
                erledigt.append(ziel.name)
            }
            return erledigt
        }.value

        return .result(dialog: IntentDialog(stringLiteral:
            lokf("Nachricht an %@ geschickt.", gesendet.joined(separator: ", ")) + ausgeblieben.hinweis
            + (ohneKlang.uhren.isEmpty ? "" : " " + lokf("Ohne Klang an %@: Die Uhr kann ihn nicht spielen.",
                                                          ohneKlang.uhren.joined(separator: ", ")))))
    }
}

/// Nimmt die sichtbare Benachrichtigung weg — oder, mit Namen, die benannte,
/// auch eine wartende.
struct BenachrichtigungZurueckziehenIntent: AppIntent {
    static let title: LocalizedStringResource = "Nachricht zurückziehen"
    static let description = IntentDescription(
        "Nimmt die sichtbare Nachricht weg, oder mit Namen die benannte.")
    static let openAppWhenRun = false

    @Parameter(title: "Name", description: "Leer heißt: die gerade sichtbare.")
    var name: String?

    @Parameter(title: "Uhr", description: "Name oder Adresse. Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Nachricht \(\.$name) zurückziehen") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let einstellungen = Einstellungen.gelesen()
        let ziele: [Uhr]
        do {
            ziele = try Kurzbefehlsziele.bestimmen(einstellungen, uhr: uhr)
        } catch let h as Kurzbefehlsziele.Hinweis {
            throw h.amUhrfeld ? $uhr.needsValueError(IntentDialog(stringLiteral: h.text))
                              : $name.needsValueError(IntentDialog(stringLiteral: h.text))
        }
        let benannt = name?.trimmingCharacters(in: .whitespaces)
        let ziel = (benannt?.isEmpty ?? true) ? nil : benannt
        if let n = ziel, !Benachrichtigungsoptionen.nameGueltig(n) {
            throw $name.needsValueError(IntentDialog(stringLiteral: NGFehler.ungueltigerName(n).localizedDescription))
        }
        let ausgeblieben = Ausgebliebene()

        try await Task.detached(priority: .userInitiated) {
            for uhrziel in ziele {
                guard let anzeigen = Anzeigen.fuer(uhrziel, brokerzugang: einstellungen.zugang(
                    clientID: MQTTKennung.fuer(.kurzbefehl, uhr: uhrziel.id)))?
                    .quittierend(beiAusbleiben: { _ in ausgeblieben.merken(uhrziel.name) }) else { continue }
                do {
                    try anzeigen.benachrichtigungZurueckziehen(name: ziel)
                } catch {
                    throw KurzbefehlFehler(uhr: uhrziel.name, error)
                }
            }
        }.value

        let satz = ziel.map { lokf("Nachricht %@ entfernt.", $0) } ?? lok("Sichtbare Nachricht entfernt.")
        return .result(dialog: IntentDialog(stringLiteral: satz + ausgeblieben.hinweis))
    }
}
