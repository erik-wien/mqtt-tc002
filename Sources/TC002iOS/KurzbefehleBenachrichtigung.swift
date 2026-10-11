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

    /// Ein Mangel der Einrichtung, ohne Uhrennamen davor.
    init(_ fehler: Kurzbefehlsziele.Fehler) {
        text = fehler.errorDescription ?? "\(fehler)"
    }

    var localizedStringResource: LocalizedStringResource { LocalizedStringResource(stringLiteral: text) }

    /// Die gemeinten Uhren. Ein Mangel der Einrichtung wird zu einem Fehler mit
    /// eigenem Text und nicht zu `needsValueError`: Das Kurzbefehle-App fragte
    /// sonst nach einem neuen Wert für ein Feld, dem nichts fehlt.
    static func ziele(_ e: Einstellungen, uhr: UhrEntity?,
                      nurBeschickbare: Bool = false) throws -> [Uhr] {
        do {
            return try Kurzbefehlsziele.bestimmen(e, uhr: uhr?.id, nurBeschickbare: nurBeschickbare)
        } catch let fehler as Kurzbefehlsziele.Fehler {
            throw KurzbefehlFehler(fehler)
        }
    }
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

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

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
        let ziele = try KurzbefehlFehler.ziele(einstellungen, uhr: uhr)

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
                    let caps = (try? g.faehigkeiten(fuer: ziel)) ?? nil
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
            + (ohneKlang.uhren.isEmpty ? "" : " " + lokf("%@ zeigt die Nachricht ohne Ton: Diese Uhr kann den Klang nicht abspielen.",
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

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Nachricht \(\.$name) zurückziehen") { \.$uhr }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let einstellungen = Einstellungen.gelesen()
        let ziele = try KurzbefehlFehler.ziele(einstellungen, uhr: uhr)
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
