import SwiftUI
import UniformTypeIdentifiers
import TC002Core
import TC002Modell

/// Die gespeicherten Einstellungen einer Uhr in ihren Gruppen — „Vorgaben der
/// Uhr“ im Bereich „Uhr“ (`Fernbedienung`). Auf allen Oberflächen dieselben.
///
/// Nicht in den Gruppen: Helligkeit (Abschnitt „Anzeige“) und Lautstärke,
/// Radio und Startklang (Abschnitt „Ton“) stehen als Bedienung im Bereich selbst,
/// damit jede Einstellung genau einmal vorkommt (`bereichspfade`).
///
/// Nicht hier: `enlargeApps` (die App rechnet alle Bilder für das Anzeigemaß),
/// `blockNavigation` (die Doku sagt nicht, was es bewirkt), TLS ein/aus, WLAN und
/// alles, was die Web-Oberfläche der Uhr einstellt.
public enum Uhrgruppe: String, CaseIterable, Identifiable, Hashable, Sendable {
    case helligkeitFarbe, text, schleife, uhrZeit, verschluesselung

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .helligkeitFarbe: return lok("Helligkeit & Farbe")
        case .text: return lok("Text & Laufschrift")
        case .schleife: return lok("Schleife")
        case .uhrZeit: return lok("Uhr, Zeit & Datum")
        case .verschluesselung: return lok("MQTT-Verschlüsselung")
        }
    }

    public var symbol: String {
        switch self {
        case .helligkeitFarbe: return "sun.max"
        case .text: return "textformat"
        case .schleife: return "arrow.triangle.2.circlepath"
        case .uhrZeit: return "clock"
        case .verschluesselung: return "lock"
        }
    }

    /// Die Einstellungen, die nicht in einer Gruppe stehen, weil der Bereich „Uhr“
    /// sie als Bedienung zeigt: Helligkeit im Abschnitt „Anzeige“, `volume` im
    /// Abschnitt „Ton“ (feste Zeile) und dort `tonpfade`.
    static let bereichspfade = ["autoBrightness", "brightness", "volume"] + tonpfade

    /// Die weiteren Zeilen des Abschnitts „Ton“, in dieser Reihenfolge.
    static let tonpfade = ["radioVolume", "appVolume", "alertVolume", "bootSound", "musicSource"]

    /// Die Abschnitte der Gruppe, jeder mit den Pfaden seiner Einstellungen
    /// (`scroll.speed` für ein Unterfeld). Leer bei der Verschlüsselung: Sie hat
    /// eine eigene Seite.
    var abschnitte: [(titel: String?, pfade: [String])] {
        switch self {
        case .helligkeitFarbe:
            return [(nil, ["saturation", "gamma", "colorCorrection", "colorTint"])]
        case .text:
            return [(nil, ["textColor", "uppercase"]),
                    (lok("Laufschrift"), ["scroll.mode", "scroll.direction", "scroll.entry",
                                          "scroll.whenFits", "scroll.speed", "scroll.gap", "scroll.holdMs"])]
        case .schleife:
            return [(nil, ["autoTransition", "appDurationMs", "transitionEffect",
                           "transitionDirection", "transitionDurationMs"])]
        case .uhrZeit:
            return [(lok("Zifferblatt"), ["clockFace", "timeColor", "calendarHeaderColor", "calendarTextColor",
                                          "calendarBodyColor", "calendarAnimation"]),
                    (lok("Uhrzeit"), ["time24h", "timeLeadingZero", "timeShowSeconds", "timeShowAmPm",
                                      "timeSeparatorMode"]),
                    (lok("Datum"), ["dateOrder", "dateSeparator", "dateYearMode", "dateShowWeekday",
                                    "dateMonthNames", "dateColor"]),
                    (lok("Wochentagsleiste"), ["weekdayBar.show", "weekdayBar.startOnMonday",
                                               "weekdayBar.weekendDays", "weekdayBar.activeColor",
                                               "weekdayBar.inactiveColor", "weekdayBar.weekendActiveColor",
                                               "weekdayBar.weekendInactiveColor"])]
        case .verschluesselung:
            return []
        }
    }

    /// Die Abschnitte, die diese Uhr zeigt: nur Zeilen, deren Schlüssel sie
    /// gemeldet hat und die auf ihr wirken; ein Abschnitt ohne Zeile entfällt.
    /// Ohne gelesene Einstellungen (`nil`) ist alles erlaubt.
    func sichtbareAbschnitte(einstellungen: Geraeteeinstellungen?,
                             faehigkeiten: Geraetefaehigkeiten?) -> [(titel: String?, pfade: [String])] {
        guard let einstellungen else { return abschnitte }
        return abschnitte.compactMap { abschnitt in
            let pfade = abschnitt.pfade.filter { pfad in
                guard einstellungen.hat(pfad: pfad) else { return false }
                let kopf = String(pfad.split(separator: ".", maxSplits: 1)[0])
                return Geraeteeinstellung(rawValue: kopf)?.wirkt(faehigkeiten: faehigkeiten) != false
            }
            return pfade.isEmpty ? nil : (abschnitt.titel, pfade)
        }
    }

    /// Die Gruppen unter „Vorgaben der Uhr“: alle sichtbaren außer der
    /// Verschlüsselung, die unter „Gerät“ steht.
    public static func vorgaben(faehigkeiten: Geraetefaehigkeiten?,
                                einstellungen: Geraeteeinstellungen? = nil) -> [Uhrgruppe] {
        sichtbar(faehigkeiten: faehigkeiten, einstellungen: einstellungen).filter { $0 != .verschluesselung }
    }

    /// Welche Gruppen diese Uhr zeigt: die Verschlüsselung nur, wenn sie MQTT
    /// über TLS kann (`capabilities.mqttTls`; die Gruppe erscheint erst nach der
    /// Abfrage, gewollt), die übrigen nur mit mindestens einer Zeile.
    public static func sichtbar(faehigkeiten: Geraetefaehigkeiten?,
                                einstellungen: Geraeteeinstellungen? = nil) -> [Uhrgruppe] {
        allCases.filter { gruppe in
            if gruppe == .verschluesselung { return faehigkeiten?.mqttTlsUnterstuetzt == true }
            return !gruppe.sichtbareAbschnitte(einstellungen: einstellungen, faehigkeiten: faehigkeiten).isEmpty
        }
    }
}

/// Eine Gruppe einer bestimmten Uhr — das Ziel des Weiterführens.
public struct Uhrgruppenziel: Hashable, Sendable {
    public let uhr: UUID
    public let gruppe: Uhrgruppe
    public init(uhr: UUID, gruppe: Uhrgruppe) { self.uhr = uhr; self.gruppe = gruppe }
}

extension Einstellungsziel {
    /// Die Seite, auf der das Ziel heute liegt. Wandert eine Einstellung in einen
    /// anderen Bereich, ändert sich nur diese Zuordnung.
    public var uhrgruppenziel: Uhrgruppenziel {
        switch self {
        case .anzeigedauer(let uhr): return Uhrgruppenziel(uhr: uhr, gruppe: .schleife)
        }
    }
}

/// „Vorgaben der Uhr“: die gespeicherten Einstellungen der Uhr, je Gruppe ein
/// aufklappbarer Block im Bereich „Uhr“. Welche Gruppen und Zeilen da sind,
/// entscheidet die Uhr (`Uhrgruppe.vorgaben`); aufgeklappt wird von Hand oder
/// über `Fernbedienung` („Ändern …“ neben der Anzeigedauer).
struct Vorgabenabschnitt: View {
    @Bindable var zustand: AppZustand
    let id: UUID
    @Binding var offen: Set<Uhrgruppe>

    var body: some View {
        Section {
            if let einstellungen = zustand.uhreneinstellungen[id] {
                ForEach(Uhrgruppe.vorgaben(faehigkeiten: zustand.faehigkeiten[id], einstellungen: einstellungen)) { gruppe in
                    DisclosureGroup(isExpanded: Binding(
                        get: { offen.contains(gruppe) },
                        set: { if $0 { offen.insert(gruppe) } else { offen.remove(gruppe) } })) {
                        gruppeninhalt(gruppe, einstellungen: einstellungen)
                    } label: {
                        Label { Text(verbatim: gruppe.titel) } icon: { Image(systemName: gruppe.symbol) }
                    }
                    .id(gruppe)
                }
            } else {
                LabeledContent {
                    Button("Abfragen") { Task { await zustand.zustandAbfragen(id) } }
                        .knopfBefehl()
                } label: {
                    Text("Noch keine Einstellungen von der Uhr")
                }
            }
        } header: {
            Text("Vorgaben der Uhr")
        } footer: {
            Text("Gilt, wenn eine Anzeige nichts anderes sagt.")
        }
    }

    @ViewBuilder
    private func gruppeninhalt(_ gruppe: Uhrgruppe, einstellungen: Geraeteeinstellungen) -> some View {
        let abschnitte = gruppe.sichtbareAbschnitte(einstellungen: einstellungen, faehigkeiten: zustand.faehigkeiten[id])
        ForEach(Array(abschnitte.enumerated()), id: \.offset) { _, abschnitt in
            if let titel = abschnitt.titel {
                Text(verbatim: titel).font(.subheadline.weight(.semibold))
            }
            ForEach(abschnitt.pfade, id: \.self) { pfad in
                Einstellungszeile(zustand: zustand, id: id, pfad: pfad)
            }
        }
    }
}

/// Eine Einstellung als Zeile: Schalter, Regler, Schrittwahl, Farbe oder Auswahl,
/// je nach Art, die der Kern für den Schlüssel kennt. Gesendet wird beim
/// Ändern; danach liest `AppZustand` den Stand von der Uhr zurück.
struct Einstellungszeile: View {
    @Bindable var zustand: AppZustand
    let id: UUID
    let pfad: String

    private var teile: [String] { pfad.split(separator: ".", maxSplits: 1).map(String.init) }
    private var einstellung: Geraeteeinstellung? { Geraeteeinstellung(rawValue: teile[0]) }
    private var stand: Geraeteeinstellungen? { zustand.uhreneinstellungen[id] }

    private var art: Einstellungsart? {
        guard let e = einstellung else { return nil }
        guard teile.count == 2 else { return e.art }
        if case .objekt(let felder) = e.art { return felder[teile[1]] }
        return nil
    }

    private var wert: JSONWert? {
        guard let e = einstellung, let roh = stand?[e] else { return nil }
        guard teile.count == 2 else { return roh }
        if case .objekt(let o) = roh { return o[teile[1]] }
        return nil
    }

    private var text: String? { if case .text(let t)? = wert { return t } else { return nil } }
    private var ganz: Int? { wert?.ganzzahl }
    private var wahr: Bool { if case .bool(let b)? = wert { return b } else { return false } }
    private var titel: String { Uhrbeschriftung.titel(pfad) }

    private func setzen(_ s: String) {
        Task { await setzenUndWarten(s) }
    }

    @discardableResult
    private func setzenUndWarten(_ s: String) async -> Bool {
        await zustand.einstellungSetzen(pfad, wert: s, fuer: id).ganz
    }

    var body: some View {
        if let art, stand?.hat(pfad: pfad) == true,
           einstellung?.wirkt(faehigkeiten: zustand.faehigkeiten[id]) != false {
            zeile(art)
        }
    }

    @ViewBuilder
    private func zeile(_ art: Einstellungsart) -> some View {
        switch art {
        case .wahrheit:
            Toggle(isOn: Binding(get: { wahr }, set: { setzen($0 ? "ein" : "aus") })) {
                Text(verbatim: titel)
            }
        case .ganzzahl(let bereich):
            ganzzahlzeile(bereich)
        case .zahlUeberNull:
            // Zehntel, damit die Schrittwahl ganzzahlig bleibt.
            Zahlzeile(titel: titel, wert: Int(((wert.flatMap(Self.zahl) ?? 1.9) * 10).rounded()),
                      bereich: 1...100, anzeige: { String(format: "%.1f", Double($0) / 10) }) {
                setzen(String(Double($0) / 10))
            }
        case .farbe:
            Farbzeile(titel: titel, hex: text) { setzen($0) }
        case .farbeOderNull:
            Toggle(isOn: Binding(get: { text != nil }, set: { setzen($0 ? "#FFFFFF" : "aus") })) {
                Text(verbatim: titel)
            }
            if text != nil {
                Farbzeile(titel: lok("Farbe"), hex: text) { setzen($0) }
            }
        case .auswahl(let liste):
            auswahl(liste)
        case .uebergang:
            auswahl(zustand.faehigkeiten[id]?.uebergaenge ?? [])
        case .zifferblatt:
            let namen = zustand.faehigkeiten[id]?.zifferblaetter ?? []
            auswahl(namen.isEmpty ? Einstellungsart.zifferblaetter : namen)
        case .wochentage:
            Wochenendzeile(titel: titel, gewaehlt: wochenende) { tage in
                setzen(tage.isEmpty ? "keine" : tage.joined(separator: ","))
            }
        case .objekt:
            EmptyView()
        }
    }

    private static func zahl(_ w: JSONWert) -> Double? {
        if case .zahl(let d) = w { return d }
        return nil
    }

    private var wochenende: Set<String> {
        guard case .liste(let l)? = wert else { return [] }
        return Set(l.compactMap { if case .text(let t) = $0 { return t } else { return nil } })
    }

    private func auswahl(_ liste: [String]) -> some View {
        // Ein Wert, den die Liste nicht (mehr) kennt, bleibt wählbar: Sonst
        // zeigte das Menü eine leere Wahl.
        let aktuell = text.map { t in Geraetefaehigkeiten.aufgeloest(t, in: liste) ?? t }
        let alle = (aktuell.map { a in liste.contains(a) ? liste : [a] + liste }) ?? liste
        return Picker(selection: Binding(get: { aktuell ?? "" }, set: { setzen($0) })) {
            ForEach(alle, id: \.self) { Text(verbatim: Uhrbeschriftung.wert(pfad, $0)).tag($0) }
        } label: {
            Text(verbatim: titel)
        }
    }

    @ViewBuilder
    private func ganzzahlzeile(_ bereich: ClosedRange<Int>) -> some View {
        let n = ganz ?? bereich.lowerBound
        switch pfad {
        case "saturation", "radioVolume", "appVolume", "alertVolume":
            Wertregler(titel: titel, wert: n, bereich: bereich, anzeige: { "\($0)" }) { await setzenUndWarten(String($0)) }
                .id(id)
        case "appDurationMs", "transitionDurationMs", "scroll.holdMs":
            Zahlzeile(titel: titel, wert: n, bereich: bereich, schritt: pfad == "appDurationMs" ? 500 : 100,
                      anzeige: { lokf("%@ s", (Double($0) / 1000).formatted(.number.precision(.fractionLength(0...1)))) }) {
                setzen(String($0))
            }
        case "scroll.speed":
            Zahlzeile(titel: titel, wert: n, bereich: bereich, schritt: 10, anzeige: { "\($0) %" }) { setzen(String($0)) }
        case "scroll.gap":
            Zahlzeile(titel: titel, wert: n, bereich: bereich, anzeige: { lokf("%d px", $0) }) { setzen(String($0)) }
        default:
            Zahlzeile(titel: titel, wert: n, bereich: bereich, anzeige: { "\($0)" }) { setzen(String($0)) }
        }
    }
}

/// Das Wochenende: sieben Tage, jeder ein Schalter.
private struct Wochenendzeile: View {
    let titel: String
    let gewaehlt: Set<String>
    let setzen: ([String]) -> Void

    var body: some View {
        DisclosureGroup {
            ForEach(Uhrbeschriftung.wochentage, id: \.schluessel) { tag in
                Toggle(isOn: Binding(
                    get: { gewaehlt.contains(tag.schluessel) },
                    set: { an in
                        var neu = gewaehlt
                        if an { neu.insert(tag.schluessel) } else { neu.remove(tag.schluessel) }
                        setzen(Uhrbeschriftung.wochentage.map(\.schluessel).filter(neu.contains))
                    })) {
                    Text(verbatim: tag.name)
                }
            }
        } label: {
            LabeledContent {
                Text(verbatim: Uhrbeschriftung.wochentage.filter { gewaehlt.contains($0.schluessel) }
                        .map { String($0.name.prefix(2)) }.joined(separator: " · "))
            } label: {
                Text(verbatim: titel)
            }
        }
    }
}

/// MQTT-Verschlüsselung: wie die Uhr dem Broker vertraut, die CA laden und
/// entfernen. TLS selbst ein- und auszuschalten bleibt der Web-Oberfläche der
/// Uhr, samt Port und Neustart.
struct Verschluesselungsseite: View {
    @Bindable var zustand: AppZustand
    let id: UUID
    let kanon: Formkanon

    @State private var waehltDatei = false
    @State private var fragtEntfernen = false

    private var uhr: Uhr? { zustand.uhren.first { $0.id == id } }
    private var status: TLSStatus? { zustand.tlsStatus[id] }
    /// Laden und Entfernen laufen nur über HTTP.
    private var adresse: Bool { !(uhr?.host.isEmpty ?? true) }

    var body: some View {
        Form {
            Section {
                LabeledContent("Vertrauen") {
                    Text(verbatim: status.map { $0.oeffentlich ? lok("Öffentliche Zertifizierungsstellen")
                                                               : lok("Eigene CA des Brokers") } ?? "—")
                }
                LabeledContent("Eigene CA") {
                    Text(verbatim: status.map { $0.oeffentlich ? lok("keine") : lok("geladen") } ?? "—")
                }
                if let ausstehend = status?.pending {
                    LabeledContent("Ausstehend") { Text(verbatim: ausstehend) }
                }
            } header: {
                Abschnittskopf("Vertrauen", hilfe: lok("Ob die Uhr TLS überhaupt benutzt, stellt die Web-Oberfläche der Uhr ein, dort samt Port und Neustart. „Zertifikat laden“ nimmt eine PEM-Datei bis 64 KB."))
            }
            Section {
                Button(status?.oeffentlich == false ? lok("Zertifikat ersetzen …") : lok("Zertifikat laden …")) {
                    waehltDatei = true
                }
                .knopfBefehl()
                Button("Entfernen", role: .destructive) { fragtEntfernen = true }
                    .knopfZerstoerend()
                    .disabled(status?.oeffentlich != false)
                if !adresse {
                    Label("nur mit Adresse der Uhr", systemImage: "info.circle")
                        .font(kanon.fussnote).foregroundStyle(.secondary)
                }
            }
            .disabled(!adresse)
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $waehltDatei, allowedContentTypes: [.data]) { ergebnis in
            guard case .success(let url) = ergebnis else { return }
            Task { await zustand.tlsCAHochladen(datei: url, fuer: id) }
        }
        .confirmationDialog(lokf("Eigene CA von „%@“ entfernen?", uhr?.name ?? ""), isPresented: $fragtEntfernen) {
            Button("Entfernen", role: .destructive) { Task { await zustand.tlsCAEntfernen(fuer: id) } }
        } message: {
            Text("Danach vertraut die Uhr dem Broker nur noch über öffentliche Zertifizierungsstellen oder den festgelegten Fingerabdruck. Die Verbindung kann abbrechen.")
        }
        .task { await zustand.zustandAbfragen(id) }
    }
}
