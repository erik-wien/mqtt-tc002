import SwiftUI
import TC002Core
import TC002Modell

/// Die Fernbedienung der angesehenen Uhr: Zustand, Live-Bild, Display,
/// Helligkeit, Overlay, Moodlight, Anzeiger, Tasten und Neustart.
///
/// Eine Ansicht für alle Oberflächen: Am Schreibtisch ist sie der Bereich „Uhr",
/// am Telefon das Blatt „Steuerung". Die Schalter gelten genau der angesehenen
/// Uhr — nur „Display aller gewählten Uhren" geht an mehrere. Gesendet wird
/// beim Schalten, danach liest `AppZustand` den Stand von der Uhr zurück; die
/// Ansicht rechnet nichts.
///
/// Das Bild und der Zustand laufen als `.task` an der Seite: Verlässt man sie,
/// enden beide Schleifen mit ihr.
public struct Fernbedienung: View {
    @Bindable var zustand: AppZustand
    private let kanon: Formkanon

    public init(zustand: AppZustand, kanon: Formkanon) {
        self.zustand = zustand
        self.kanon = kanon
    }

    public var body: some View {
        if let uhr = zustand.referenzUhr {
            Steuerseite(zustand: zustand, uhr: uhr, kanon: kanon)
                // Eine andere Uhr, ein anderer Satz lokaler Eingaben.
                .id(uhr.id)
        } else {
            ContentUnavailableView("Keine Uhr eingerichtet", systemImage: "clock")
        }
    }
}

private struct Steuerseite: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let kanon: Formkanon

    @State private var fragtNeustart = false
    /// Was die Seite zuletzt gewählt hat, solange die Uhr es nicht zurückmeldet
    /// (eine MQTT-Uhr ohne Adresse liefert keinen Anzeigestand).
    @State private var overlay: String?
    @State private var moodlightAn = false
    @State private var moodlightHelligkeit = 120

    private var id: UUID { uhr.id }
    private var geraet: Geraetezustand? { zustand.geraetezustand[id] }
    private var anzeige: Anzeigestand? { zustand.anzeigestand[id] }
    private var panelAn: Bool { anzeige?.an ?? geraet?.panelAn ?? true }
    /// `nil`, solange von dieser Uhr nichts gelesen ist: Dann ist der Regler gesperrt.
    private var helligkeitRoh: Int? { zustand.panelhelligkeit(fuer: id) }
    private var hatLichtsensor: Bool { zustand.faehigkeiten[id]?.lichtsensor == true }
    private var sensorRegelt: Bool { zustand.helligkeitAutomatisch(fuer: id) }
    private var overlayNamen: [String] { zustand.faehigkeiten[id]?.overlays ?? [] }

    var body: some View {
        Form {
            if zustand.uhren.count > 1 { uhrwahl }
            livebild
            zustandsabschnitt
            anzeigeabschnitt
            Moodlightabschnitt(zustand: zustand, uhr: uhr, an: $moodlightAn, helligkeit: $moodlightHelligkeit)
            indikatorabschnitt
            Tonabschnitt(zustand: zustand, uhr: uhr, kanon: kanon)
            tastenabschnitt
            Section {
                Button("Uhr neu starten …", role: .destructive) { fragtNeustart = true }
                    .knopfZerstoerend()
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(lokf("%@ neu starten?", uhr.name), isPresented: $fragtNeustart) {
            Button("Neu starten", role: .destructive) { Task { await zustand.neustarten(fuer: id) } }
        } message: {
            Text("Die Uhr ist danach kurz nicht erreichbar.")
        }
        // Zustand und Bild, solange die Seite offen ist. `.task(id:)` beendet
        // beide Schleifen mit der Seite und beim Wechsel der Uhr.
        .task(id: id) { await zustand.zustandFolgen(id) }
        .task(id: id) { await zustand.bildschirmFolgen(id) }
        .onAppear { uebernehmen() }
        .onChange(of: anzeige?.overlay) { _, _ in uebernehmen() }
        .onChange(of: anzeige?.moodlight) { _, _ in uebernehmen() }
    }

    /// Die Auskunft der Uhr hat Vorrang vor dem, was die Seite zuletzt gewählt hat.
    private func uebernehmen() {
        guard let anzeige else { return }
        overlay = anzeige.overlay
        moodlightAn = anzeige.moodlight != nil
        if let h = anzeige.moodlight?.helligkeit { moodlightHelligkeit = h }
    }

    // MARK: - Abschnitte

    private var uhrwahl: some View {
        Section {
            Picker("Uhr", selection: Binding(
                get: { zustand.aktiveID },
                set: { if let neu = $0 { zustand.uhrAnsehen(neu) } })) {
                ForEach(zustand.uhren) { u in Text(verbatim: u.name).tag(Optional(u.id)) }
            }
        }
    }

    private var livebild: some View {
        Section {
            VStack(spacing: 6) {
                Group {
                    if let stand = zustand.bildschirm[id] {
                        Pixelraster(punkte: stand.bild.punktfeld,
                                    mass: Anzeigemass(breite: stand.bild.breite, hoehe: stand.bild.hoehe))
                    } else {
                        Rectangle().fill(.clear)
                            .aspectRatio(Double(Anzeigemass.vorgabe.breite) / Double(Anzeigemass.vorgabe.hoehe),
                                         contentMode: .fit)
                    }
                }
                .padding(6)
                .background(.black, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 520)
                alter
            }
            .frame(maxWidth: .infinity)
        } header: {
            Abschnittskopf("Live", hilfe: lok("Das Bild zeigt die Farben der Anzeigen; Helligkeit und Farbkorrektur der Uhr sind nicht eingerechnet. Es wird alle zwei Sekunden neu geholt, solange diese Seite offen ist."))
        }
    }

    /// „Live · vor 1 s“ — oder die Auskunft, dass noch nichts da ist.
    private var alter: some View {
        TimelineView(.periodic(from: .now, by: 1)) { zeit in
            Group {
                if let abgerufen = zustand.bildschirm[id]?.abgerufen {
                    Text(lokf("Live · vor %d s", max(0, Int(zeit.date.timeIntervalSince(abgerufen)))))
                } else {
                    Text("Noch kein Bild von der Uhr")
                }
            }
            .font(kanon.fussnote)
            .foregroundStyle(.secondary)
        }
    }

    private var zustandsabschnitt: some View {
        Section {
            LabeledContent("Gerät") { Text(verbatim: geraetetext) }
            LabeledContent("Aktive Anzeige") {
                HStack(spacing: 10) {
                    Text(verbatim: zustand.aktiveAnzeige[id] ?? "—")
                    Button { Task { await zustand.anzeigeBlaettern(vor: false, fuer: id) } } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Vorherige Anzeige"))
                    Button { Task { await zustand.anzeigeBlaettern(vor: true, fuer: id) } } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Nächste Anzeige"))
                }
            }
            LabeledContent("Erreichbar") { Text(verbatim: erreichbarkeit) }
            LabeledContent("WLAN") { Text(verbatim: geraet?.wlanSignal.map { "\($0) dBm" } ?? "—") }
            LabeledContent("Laufzeit") {
                Text(verbatim: geraet?.laufzeitSekunden.map { Steuerwerte.laufzeit(sekunden: $0) } ?? "—")
            }
            if let batterie = geraet?.batterieProzent {
                LabeledContent("Batterie") {
                    Text(verbatim: "\(batterie) %" + (geraet?.batterieSchwach == true ? " (!)" : ""))
                }
            }
        } header: {
            Text(verbatim: uhr.name)
        }
    }

    private var geraetetext: String {
        let teile = [geraet?.platine, geraet?.fassung.map { "NG " + $0 }].compactMap { $0 }
        return teile.isEmpty ? "—" : teile.joined(separator: " · ")
    }

    private var erreichbarkeit: String {
        switch zustand.erreichbar[id] {
        case true?: return lok("erreichbar")
        case false?: return lok("nicht erreichbar")
        case nil: return "—"
        }
    }

    private var anzeigeabschnitt: some View {
        Section {
            Toggle("Display", isOn: Binding(
                get: { panelAn },
                set: { neu in Task { await zustand.panelSchalten(an: neu, fuer: id) } }))
            if zustand.ziele().count > 1 {
                LabeledContent("Alle gewählten Uhren") {
                    HStack(spacing: 8) {
                        Button("Aus") { Task { await zustand.panelSchalten(an: false) } }
                            .knopfBefehl()
                        Button("An") { Task { await zustand.panelSchalten(an: true) } }
                            .knopfBefehl()
                    }
                }
            }
            if hatLichtsensor {
                Toggle("Automatisch", isOn: Binding(
                    get: { sensorRegelt },
                    set: { neu in Task { await zustand.helligkeitAutomatikSetzen(neu, fuer: id) } }))
            }
            Wertregler(titel: lok("Helligkeit"),
                       wert: Steuerwerte.helligkeitProzent(roh: helligkeitRoh ?? 0), bereich: 0...100,
                       anzeige: { helligkeitRoh == nil ? "—" : "\($0) %" },
                       gesperrt: sensorRegelt || helligkeitRoh == nil,
                       setzen: { p in Task { await zustand.helligkeitSetzen(Steuerwerte.helligkeitRoh(prozent: p), fuer: id) } })
            if !overlayNamen.isEmpty {
                Picker("Overlay", selection: Binding(
                    get: { overlay.flatMap { Geraetefaehigkeiten.aufgeloest($0, in: overlayNamen) } },
                    set: { neu in
                        overlay = neu
                        Task { await zustand.overlaySetzen(neu, fuer: id) }
                    })) {
                    Text("Keines").tag(String?.none)
                    ForEach(overlayNamen, id: \.self) { Text(verbatim: $0).tag(Optional($0)) }
                }
            }
        } header: {
            Text("Anzeige")
        } footer: {
            if sensorRegelt { Text("Der Lichtsensor der Uhr regelt die Helligkeit.") }
        }
    }

    private var indikatorabschnitt: some View {
        Section {
            ForEach(Indikator.nummern, id: \.self) { n in
                Indikatorzeile(zustand: zustand, uhr: uhr, nummer: n,
                               stand: geraet?.indikatoren.indices.contains(n - 1) == true
                                   ? geraet?.indikatoren[n - 1] : nil)
            }
        } header: {
            Text("Anzeiger")
        }
    }

    // MARK: - Tasten

    private var nurMQTT: Bool { uhr.wirksameBetriebsart != .mqtt }

    private var tastenabschnitt: some View {
        Section {
            LabeledContent("Tasten") {
                HStack(spacing: 14) {
                    ForEach(Taste.allCases, id: \.self) { taste in
                        let gedrueckt = zustand.tasten[id]?[taste] == true
                        Image(systemName: Self.symbol(taste, gedrueckt: gedrueckt))
                            .foregroundStyle(gedrueckt ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                            .accessibilityLabel(Text(verbatim: Self.name(taste)))
                            .accessibilityValue(Text(verbatim: gedrueckt ? lok("gedrückt") : lok("losgelassen")))
                    }
                }
            }
            LabeledContent("Drehknopf") {
                Text(verbatim: drehknopftext)
            }
            if nurMQTT {
                Label("nur im MQTT-Betrieb", systemImage: "info.circle")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            } else if let f = zustand.uhrenfehler[id] {
                LabeledContent("Letzte Abweisung") { Text(verbatim: f.fehler).lineLimit(2) }
            }
        } header: {
            Abschnittskopf("Tasten", hilfe: lok("Tasten und Drehknopf sieht die App nur beim Mitlesen über MQTT; über HTTP meldet die Uhr sie nicht."))
        }
        // Grau, solange nichts gelesen werden kann: Die Zeilen zeigen dann nur,
        // was es gäbe.
        .opacity(nurMQTT ? 0.55 : 1)
    }

    private var drehknopftext: String {
        guard !nurMQTT, let d = zustand.drehknopf[id] else { return "—" }
        return lokf("zuletzt %@ · gesamt %@", String(format: "%+d", d.letzteRasten), String(format: "%+d", d.summe))
    }

    private static func symbol(_ taste: Taste, gedrueckt: Bool) -> String {
        switch taste {
        case .links: return gedrueckt ? "chevron.left.circle.fill" : "chevron.left.circle"
        case .mitte: return gedrueckt ? "circle.inset.filled" : "circle"
        case .rechts: return gedrueckt ? "chevron.right.circle.fill" : "chevron.right.circle"
        case .knopf: return gedrueckt ? "dial.medium.fill" : "dial.medium"
        }
    }

    private static func name(_ taste: Taste) -> String {
        switch taste {
        case .links: return lok("Linke Taste")
        case .mitte: return lok("Mittlere Taste")
        case .rechts: return lok("Rechte Taste")
        case .knopf: return lok("Drehknopf drücken")
        }
    }
}

/// Moodlight: der Schalter und, solange es leuchtet, Farbe oder Weißton und
/// Helligkeit. Es gibt keine Vorschau des Lichts; das Live-Bild darüber zeigt
/// die Apps, nicht das Moodlight.
private struct Moodlightabschnitt: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    @Binding var an: Bool
    @Binding var helligkeit: Int

    private enum Modus: Hashable { case farbe, weiss }
    @State private var modus: Modus = .farbe
    @State private var kelvin = 3200

    private var stand: Moodlightstand? { zustand.anzeigestand[uhr.id]?.moodlight }

    var body: some View {
        Section {
            Toggle("Moodlight", isOn: Binding(
                get: { an },
                set: { neu in
                    an = neu
                    Task {
                        if neu { await zustand.moodlightSetzen(licht(), fuer: uhr.id) }
                        else { await zustand.moodlightAusschalten(fuer: uhr.id) }
                    }
                }))
            if an {
                Picker("Licht", selection: $modus) {
                    Text("Farbe").tag(Modus.farbe)
                    Text("Weißton").tag(Modus.weiss)
                }
                .pickerStyle(.segmented)
                .onChange(of: modus) { _, _ in senden() }
                if modus == .farbe {
                    Farbzeile(titel: lok("Farbe"), hex: farbe) { hex in
                        farbe = hex
                        senden()
                    }
                } else {
                    Zahlzeile(titel: lok("Weißton"), wert: kelvin, bereich: Moodlight.kelvinBereich,
                              schritt: 100, anzeige: { "\($0) K" }) { neu in
                        kelvin = neu
                        senden()
                    }
                }
                Wertregler(titel: lok("Helligkeit"),
                           wert: Steuerwerte.helligkeitProzent(roh: helligkeit), bereich: 0...100,
                           anzeige: { "\($0) %" }) { p in
                    helligkeit = Steuerwerte.helligkeitRoh(prozent: p)
                    senden()
                }
            }
        } header: {
            Text("Moodlight")
        }
        .onAppear { if let f = stand?.farbe { farbe = f } }
        .onChange(of: stand?.farbe) { _, neu in if let neu { farbe = neu } }
    }

    @State private var farbe = "#FFFFFF"

    /// Farbe **oder** Kelvin, nie beides (die Uhr nähme Kelvin und überliest die Farbe).
    private func licht() -> Moodlight {
        modus == .farbe
            ? Moodlight(farbe: farbe, helligkeit: helligkeit)
            : Moodlight(kelvin: kelvin, helligkeit: helligkeit)
    }

    private func senden() {
        Task { await zustand.moodlightSetzen(licht(), fuer: uhr.id) }
    }
}

/// Einer der drei Anzeiger am Rand: Schalter, und solange er leuchtet Farbe,
/// Blinken und Blenden. Die Uhr nimmt Blinken und Blenden mit jeder Anfrage neu,
/// darum geht beim Ändern eines Werts immer der ganze Stand hinaus.
private struct Indikatorzeile: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let nummer: Int
    let stand: Indikatorstand?

    @State private var an = false
    @State private var farbe = "#FFFFFF"
    @State private var blinkMs = 0
    @State private var fadeMs = 0

    var body: some View {
        Group {
            Toggle(isOn: Binding(get: { an }, set: { schalten($0) })) {
                Text(verbatim: titel)
            }
            if an {
                Farbzeile(titel: lok("Farbe"), hex: farbe) { hex in
                    farbe = hex
                    senden()
                }
                Zahlzeile(titel: lok("Blinken"), wert: blinkMs, bereich: Indikator.zeitbereich,
                          schritt: 100, anzeige: { "\($0) ms" }) { blinkMs = $0; senden() }
                Zahlzeile(titel: lok("Blenden"), wert: fadeMs, bereich: Indikator.zeitbereich,
                          schritt: 100, anzeige: { "\($0) ms" }) { fadeMs = $0; senden() }
            }
        }
        .onAppear { uebernehmen() }
        .onChange(of: stand) { _, _ in uebernehmen() }
    }

    private var titel: String {
        switch nummer {
        case 1: return lok("Anzeiger 1 (oben)")
        case 3: return lok("Anzeiger 3 (unten)")
        default: return lokf("Anzeiger %d", nummer)
        }
    }

    private func uebernehmen() {
        guard let stand else { return }
        an = stand.an
        if stand.an { farbe = stand.farbe; blinkMs = stand.blinkMs; fadeMs = stand.fadeMs }
    }

    private func schalten(_ neu: Bool) {
        an = neu
        Task {
            if neu { await zustand.indikatorSetzen(aktuell(), fuer: uhr.id) }
            else { await zustand.indikatorAusschalten(nummer, fuer: uhr.id) }
        }
    }

    private func aktuell() -> Indikator {
        Indikator(nummer: nummer, farbe: farbe, blinkMs: blinkMs, fadeMs: fadeMs)
    }

    private func senden() {
        Task { await zustand.indikatorSetzen(aktuell(), fuer: uhr.id) }
    }
}
