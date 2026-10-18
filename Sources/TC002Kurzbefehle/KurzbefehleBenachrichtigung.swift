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

    /// Ein Satz, der keinem Parameter allein gehört (zwei Angaben, die sich ausschließen).
    init(text: String) {
        self.text = text
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
/// Wie in der App ist es dieselbe Rechnung wie bei „Meldung schicken“ (Format,
/// Icon, Darstellung) mit den Reglern der Nachricht darüber (`Nachrichtwahl`):
/// halten, aufwecken, einreihen oder ersetzen, Durchläufe, Klang. Was beim
/// Format fehlt, kommt aus dem, was zuletzt unter „Senden“ eingestellt war.
struct BenachrichtigungSendenIntent: AppIntent {
    static let title: LocalizedStringResource = "Nachricht senden"
    static let description = IntentDescription(
        "Zeigt eine Nachricht einmalig über der Schleife der Uhr, statt eine Anzeige anzulegen. Schrift, Ausrichtung und Darstellung kommen aus den zuletzt in der App gewählten Einstellungen.")
    static let openAppWhenRun = false

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Uhr", description: "Leer heißt: die in der App gewählten Ziele, sonst alle eingerichteten.")
    var uhr: UhrEntity?

    @Parameter(title: "Icon-Nummer", description: "Nummer oder Name eines vorhandenen Icons.")
    var iconNummer: String?

    @Parameter(title: "Halten", description: "Bleibt stehen, bis sie zurückgezogen wird.", default: false)
    var halten: Bool

    @Parameter(title: "Aufwecken", description: "Erscheint auch bei ausgeschaltetem Panel.", default: true)
    var aufwecken: Bool

    @Parameter(title: "Einreihen", description: "Reiht sich hinter die sichtbare Nachricht ein, statt sie zu ersetzen.", default: false)
    var einreihen: Bool

    @Parameter(title: "Durchläufe", description: "Wie oft laufender Text durchzieht, 1 bis 9.", default: 2, inclusiveRange: (1, 9))
    var durchlaeufe: Int

    @Parameter(title: "Name", description: "Nur unter diesem Namen lässt sie sich später zurückziehen. Buchstaben, Ziffern, „_“ und „-“.")
    var name: String?

    @Parameter(title: "Dauer in Sekunden", inclusiveRange: (1, 86400))
    var dauer: Int?

    @Parameter(title: "Klang", description: "Name einer Melodie oder MP3-Datei auf der Uhr.")
    var klang: String?

    @Parameter(title: "Klang wiederholen", description: "Der Klang wiederholt sich, bis die Nachricht geht.", default: false)
    var klangWiederholen: Bool

    @Parameter(title: "Vorlesen", description: "Die Uhr liest den Text vor, auf Englisch.", default: false)
    var vorlesen: Bool

    // Das Format, wie bei „Meldung schicken“. Alles wahlfrei.

    @Parameter(title: "Weg", description: "„als Pixel“ rastert die App selbst, mit einer ihrer Pixelschriften. „als Text“ überlässt das Setzen der Uhr; deren Schrift kennt Umlaute und Akzente, aber keine Auswahl.")
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

    private var angaben: Formatangaben {
        Formatangaben.kurzbefehl(weg: weg, schriftart: schriftart, groesse: groesse, fett: fett,
                                 grossbuchstaben: grossbuchstaben, farbe: farbe,
                                 waagrecht: waagrecht, senkrecht: senkrecht, rand: rand,
                                 abstand: abstand, tempo: tempo, iconLaeuftMit: iconLaeuftMit)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) als Nachricht an die Uhr senden") {
            \.$uhr
            \.$iconNummer
            \.$halten
            \.$aufwecken
            \.$einreihen
            \.$durchlaeufe
            \.$name
            \.$dauer
            \.$klang
            \.$klangWiederholen
            \.$vorlesen
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
        let ziele = try KurzbefehlFehler.ziele(einstellungen, uhr: uhr)

        let benannt = name?.trimmingCharacters(in: .whitespaces)
        let klangwahl: Klangwahl
        do {
            klangwahl = try Kurzbefehlswerte.klangwahl(name: klang, vorlesen: vorlesen, wiederholen: klangWiederholen)
        } catch {
            throw $vorlesen.needsValueError(IntentDialog(stringLiteral: error.localizedDescription))
        }
        var bo = Nachrichtwahl(halten: halten, aufwecken: aufwecken, ersetzen: !einreihen,
                               durchlaeufe: durchlaeufe, klang: klangwahl)
            .optionen(nachrichtentext: text)
        bo.name = (benannt?.isEmpty ?? true) ? nil : benannt
        if let n = bo.name, !Benachrichtigungsoptionen.nameGueltig(n) {
            throw $name.needsValueError(IntentDialog(stringLiteral: NGFehler.ungueltigerName(n).localizedDescription))
        }

        var optionen: Meldungsoptionen
        do {
            optionen = try angaben.angewendet(auf: Meldungsoptionen.ausAblage(.standard))
        } catch let fehler as Formatangaben.Fehler {
            throw $groesse.needsValueError(IntentDialog(stringLiteral: fehler.localizedDescription))
        }
        optionen.text = text
        if let dauer = Kurzbefehlswerte.dauer(dauer) { optionen.dauer = dauer }
        let gesetzt = optionen
        let icon: Icon?
        do {
            icon = try Kurzbefehlswerte.icon(nummer: iconNummer)
        } catch {
            throw $iconNummer.needsValueError(IntentDialog(stringLiteral: error.localizedDescription))
        }
        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene,
                                    leseordner: [Iconordner.mitgeliefert])
        let ausgeblieben = Ausgebliebene()
        let ohneKlang = Ausgebliebene()
        let nachricht = bo

        let gesendet = try await Task.detached(priority: .userInitiated) { () -> [String] in
            var erledigt: [String] = []
            for ziel in ziele {
                // Derselbe Kanal wie in der App; ueber MQTT wartet die Sendung
                // auf `<Thema>/result` (`Anzeigen.quittierend`).
                guard let anzeigen = Anzeigen.fuer(ziel, brokerzugang: einstellungen.zugang(
                    clientID: MQTTKennung.fuer(.kurzbefehl, uhr: ziel.id)))?
                    .quittierend(beiAusbleiben: { _ in ausgeblieben.merken(ziel.name) }) else { continue }
                // Der Klang geht nur an eine Uhr, die ihn spielt; die Nachricht geht in jedem Fall.
                var eigene = nachricht
                if !nachricht.klang.isEmpty, !ziel.host.isEmpty {
                    let g = Geraet(host: ziel.host)
                    let caps = (try? g.faehigkeiten(fuer: ziel)) ?? nil
                    let listen = (try? g.melodien()).map { Tonlisten(melodien: $0.namen, mp3: (try? g.mp3Dateien())?.namen ?? []) }
                    let verteilung = Klangeignung.verteilen(nachricht.klang, an: [Klangziel(id: ziel.id, name: ziel.name,
                                                                                           faehigkeiten: caps, listen: listen)])
                    eigene.klang = verteilung.klaenge[ziel.id] ?? nachricht.klang
                    if !verteilung.uebersprungen.isEmpty { ohneKlang.merken(ziel.name) }
                }
                do {
                    try anzeigen.benachrichtigen(try Meldungsbau.rahmen(gesetzt, icon: icon, sammlung: sammlung,
                                                                       mass: Anzeigemass.fuer(ziel)), eigene)
                } catch {
                    throw KurzbefehlFehler(uhr: ziel.name, error)
                }
                erledigt.append(ziel.name)
            }
            return erledigt
        }.value

        let kleinereIcons = icon.map {
            Iconbestaende.hinweise(gewaehlt: $0, fuer: ziele.filter { z in gesendet.contains(z.name) })
        } ?? []
        return .result(dialog: IntentDialog(stringLiteral:
            lokf("Nachricht an %@ geschickt.", gesendet.joined(separator: ", ")) + ausgeblieben.hinweis
            + (ohneKlang.uhren.isEmpty ? "" : " " + lokf("%@ zeigt die Nachricht ohne Ton: Diese Uhr kann den Klang nicht abspielen.",
                                                          ohneKlang.uhren.joined(separator: ", ")))
            + kleinereIcons.map { " " + $0 + "." }.joined()))
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
