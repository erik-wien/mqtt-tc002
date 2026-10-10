import SwiftUI
import UniformTypeIdentifiers
import TC002Core
import TC002Modell

/// Die gespeicherten Einstellungen einer Uhr in ihren Gruppen — die Seiten unter
/// Einstellungen › Uhr. Auf allen Oberflächen dieselben; am Schreibtisch und am
/// Telefon führen sie von der Uhrseite aus weiter.
///
/// Nicht hier: `enlargeApps` (die App rechnet alle Bilder für das Anzeigemaß),
/// `blockNavigation` (die Doku sagt nicht, was es bewirkt), TLS ein/aus, WLAN und
/// alles, was die Web-Oberfläche der Uhr einstellt.
public enum Uhrgruppe: String, CaseIterable, Identifiable, Hashable, Sendable {
    case helligkeitFarbe, text, schleife, uhrZeit, klang, verschluesselung

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .helligkeitFarbe: return lok("Helligkeit & Farbe")
        case .text: return lok("Text & Laufschrift")
        case .schleife: return lok("Schleife")
        case .uhrZeit: return lok("Uhr, Zeit & Datum")
        case .klang: return lok("Klang")
        case .verschluesselung: return lok("MQTT-Verschlüsselung")
        }
    }

    public var symbol: String {
        switch self {
        case .helligkeitFarbe: return "sun.max"
        case .text: return "textformat"
        case .schleife: return "arrow.triangle.2.circlepath"
        case .uhrZeit: return "clock"
        case .klang: return "speaker.wave.2"
        case .verschluesselung: return "lock"
        }
    }

    /// Die Abschnitte der Seite, jeder mit den Pfaden seiner Einstellungen
    /// (`scroll.speed` für ein Unterfeld). Leer bei der Verschlüsselung: Sie hat
    /// eine eigene Seite.
    var abschnitte: [(titel: String?, pfade: [String])] {
        switch self {
        case .helligkeitFarbe:
            return [(nil, ["brightness", "saturation", "gamma", "colorCorrection", "colorTint"])]
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
        case .klang:
            return [(lok("Lautstärke"), ["volume", "radioVolume", "appVolume", "alertVolume"]),
                    (nil, ["bootSound", "musicSource"])]
        case .verschluesselung:
            return []
        }
    }

    /// Welche Gruppen diese Uhr zeigt: die Verschlüsselung nur, wenn sie MQTT
    /// über TLS kann (`capabilities.mqttTls`).
    public static func sichtbar(faehigkeiten: Geraetefaehigkeiten?) -> [Uhrgruppe] {
        allCases.filter { $0 != .verschluesselung || faehigkeiten?.mqttTlsUnterstuetzt == true }
    }
}

/// Eine Gruppe einer bestimmten Uhr — das Ziel des Weiterführens.
public struct Uhrgruppenziel: Hashable, Sendable {
    public let uhr: UUID
    public let gruppe: Uhrgruppe
    public init(uhr: UUID, gruppe: Uhrgruppe) { self.uhr = uhr; self.gruppe = gruppe }
}

/// Die Seite einer Gruppe.
public struct Uhrgruppenseite: View {
    @Bindable var zustand: AppZustand
    private let ziel: Uhrgruppenziel
    private let kanon: Formkanon

    public init(zustand: AppZustand, ziel: Uhrgruppenziel, kanon: Formkanon) {
        self.zustand = zustand
        self.ziel = ziel
        self.kanon = kanon
    }

    public var body: some View {
        Group {
            if ziel.gruppe == .verschluesselung {
                Verschluesselungsseite(zustand: zustand, id: ziel.uhr, kanon: kanon)
            } else if zustand.uhreneinstellungen[ziel.uhr] == nil {
                ContentUnavailableView {
                    Label("Noch keine Einstellungen von der Uhr", systemImage: "slider.horizontal.3")
                } actions: {
                    Button("Abfragen") { Task { await zustand.zustandAbfragen(ziel.uhr) } }
                        .knopfBefehl()
                }
            } else {
                Form {
                    ForEach(Array(ziel.gruppe.abschnitte.enumerated()), id: \.offset) { _, abschnitt in
                        Section {
                            ForEach(abschnitt.pfade, id: \.self) { pfad in
                                Einstellungszeile(zustand: zustand, id: ziel.uhr, pfad: pfad)
                            }
                        } header: {
                            if let titel = abschnitt.titel { Text(verbatim: titel) }
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .navigationTitle(ziel.gruppe.titel)
        .task { await zustand.zustandAbfragen(ziel.uhr) }
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
        Task { await zustand.einstellungSetzen(pfad, wert: s, fuer: id) }
    }

    var body: some View {
        if let art {
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
        case "brightness":
            Wertregler(titel: titel, wert: Steuerwerte.helligkeitProzent(roh: n), bereich: 0...100,
                       anzeige: { "\($0) %" }) { setzen(String(Steuerwerte.helligkeitRoh(prozent: $0))) }
        case "saturation", "volume", "radioVolume", "appVolume", "alertVolume":
            Wertregler(titel: titel, wert: n, bereich: bereich, anzeige: { "\($0)" }) { setzen(String($0)) }
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
private struct Verschluesselungsseite: View {
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
