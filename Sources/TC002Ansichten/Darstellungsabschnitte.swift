import SwiftUI
import TC002Core
import TC002Modell

/// Der Reiter „Darstellung": Hintergrund, Effekt, Overlay, Palette und das
/// Malen des Textes aus der Palette. Von Inspektor (Mac, iPad) und Formatblatt
/// (iPhone) gemeinsam benutzt.
///
/// Was bei welchem Weg gilt, steht nicht hier, sondern in `Darstellungsregeln`
/// im Kern; die Ansicht sperrt, was dort gesperrt ist, und lässt es stehen
/// (gesperrt, nicht versteckt), damit der Reiter nicht springt. Eine Fußnote
/// sagt, warum.
///
/// Die Namen von Effekt, Overlay und Palette kommen aus `capabilities` der
/// angesehenen Uhr (`AppZustand.faehigkeiten`) und stehen erst nach der ersten
/// Abfrage da; davor zeigt jedes Menü nur seinen Nullwert, einen Hinweis und
/// „Uhr abfragen …".
public struct Darstellungsabschnitte: View {
    @Bindable var zustand: AppZustand
    @Binding var wahl: Darstellungswahl
    let weg: SendeWeg

    @State private var zeigePalette = false

    public init(zustand: AppZustand, wahl: Binding<Darstellungswahl>, weg: SendeWeg) {
        self.zustand = zustand
        self._wahl = wahl
        self.weg = weg
    }

    private var regeln: Darstellungsregeln { Darstellungsregeln(weg: weg, wahl: wahl) }

    private var faehigkeiten: Geraetefaehigkeiten? {
        zustand.referenzUhr.flatMap { zustand.faehigkeiten[$0.id] }
    }

    private var hintergrund: Binding<Color> {
        Binding(get: { Color(hex: wahl.hintergrundfarbe) ?? .black },
                set: { wahl.hintergrundfarbe = $0.hexWert })
    }

    public var body: some View {
        Section {
            LabeledContent("Farbe") {
                Farbkreis(farbe: hintergrund)
            }
            .disabled(regeln.farbeGesperrt)
            .opacity(regeln.farbeGesperrt ? 0.35 : 1)
            .allowsHitTesting(!regeln.farbeGesperrt)
            namenmenue("Effekt", nullwert: lok("Keiner"), auswahl: $wahl.effekt,
                       namen: faehigkeiten?.effekte ?? [])
                .disabled(regeln.effektGesperrt)
        } header: {
            Text("Hintergrund")
        } footer: {
            if regeln.textAlsBild {
                Text("Der Text geht als Bild an die Uhr, und ein Bild deckt Farbe und Effekt zu. Mit „Schrift der Uhr“ im Format geht beides.")
            } else if regeln.farbeDurchEffekt {
                Text("Ein Effekt ersetzt die Hintergrundfarbe.")
            }
        }

        Section("Overlay") {
            namenmenue("Overlay", nullwert: lok("Keines"), auswahl: $wahl.overlay,
                       namen: faehigkeiten?.overlays ?? [])
            LabeledContent("Tempo") {
                HStack(spacing: 8) {
                    Slider(value: $wahl.tempo, in: Darstellungswahl.tempobereich, step: 0.1)
                    Text(verbatim: zahl(wahl.tempo)).monospacedDigit()
                        .frame(minWidth: 30, alignment: .trailing)
                }
            }
            .disabled(regeln.tempoGesperrt)
        }

        Section {
            palettenzeile
                .disabled(regeln.paletteGesperrt)
            Toggle("Überblenden", isOn: $wahl.ueberblenden)
                .disabled(wahl.palette == .keine || regeln.paletteGesperrt)
        } header: {
            Text("Palette")
        } footer: {
            if regeln.paletteGesperrt {
                Text("Als Bild färbt die Palette nur ein Overlay — wähle eins oder schalte „Schrift der Uhr“ ein.")
            } else if wahl.palette != .keine, !regeln.paletteWirkt(faehigkeiten: faehigkeiten) {
                Text("Die Palette färbt nichts, solange weder Effekt noch Overlay noch „Text aus Palette“ sie nutzt.")
            }
        }

        Section {
            Toggle("Text aus Palette", isOn: $wahl.textAusPalette)
                .disabled(regeln.textMalenGesperrt)
            Stepper(value: $wahl.spanne, in: 0...Darstellungswahl.hoechstspanne) {
                HStack(spacing: 6) {
                    Text("Spanne").fixedSize()
                    Spacer(minLength: 0)
                    Text(verbatim: "\(wahl.spanne)").monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .gesperrterStepper(regeln.spanneLaufGesperrt)
            LabeledContent("Lauf") {
                HStack(spacing: 8) {
                    Slider(value: $wahl.lauf, in: Darstellungswahl.laufbereich, step: 0.1)
                    Text(verbatim: zahl(wahl.lauf)).monospacedDigit()
                        .frame(minWidth: 30, alignment: .trailing)
                }
            }
            .disabled(regeln.spanneLaufGesperrt)
        } header: {
            Text("Text malen")
        } footer: {
            if regeln.textMalenGesperrt {
                Text("Nur mit „Schrift der Uhr“: Dann malt die Uhr den Text selbst.")
            }
        }
    }

    private func zahl(_ wert: Double) -> String {
        wert.formatted(.number.precision(.fractionLength(1)))
    }

    private func abfragen() {
        guard let uhr = zustand.referenzUhr else { return }
        zustand.abfragen(uhr.id)
    }

    /// Ein Menü mit den Namen der Uhr. Ein `Picker` allein kann „Uhr abfragen …"
    /// nicht tragen; im `Menu` steht der Wähler eingebettet und die Handlung
    /// daneben. Ein gewählter Name, den die Liste nicht (mehr) kennt, bleibt
    /// stehen und wählbar — er stammt von einer anderen Uhr oder aus dem Platz.
    private func namenmenue(_ titel: LocalizedStringKey, nullwert: String,
                            auswahl: Binding<String?>, namen: [String]) -> some View {
        let angezeigt = namen + (auswahl.wrappedValue.map { $0.isEmpty || namen.contains($0) ? [] : [$0] } ?? [])
        return LabeledContent(titel) {
            Menu {
                Picker(titel, selection: auswahl) {
                    Text(verbatim: nullwert).tag(String?.none)
                    ForEach(angezeigt, id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
                }
                .pickerStyle(.inline)
                if namen.isEmpty {
                    Divider()
                    Button(lok("Noch nicht abgefragt. Die Namen kommen von der Uhr.")) {}
                        .disabled(true)
                    Button(lok("Uhr abfragen …")) { abfragen() }
                        .disabled(zustand.referenzUhr == nil)
                }
            } label: {
                menuewert(auswahl.wrappedValue ?? nullwert)
            }
        }
    }

    private func menuewert(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: text)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
        }
    }

    private var palettenname: String {
        switch wahl.palette {
        case .keine: return lok("Keine")
        case .name(let n): return n
        case .eigene: return lok("Eigene")
        }
    }

    private var palettenzeile: some View {
        let namen = faehigkeiten?.paletten ?? []
        let eigenerName: [String] = {
            guard case .name(let n) = wahl.palette, !n.isEmpty, !namen.contains(n) else { return [] }
            return [n]
        }()
        return LabeledContent("Palette") {
            Menu {
                Picker("Palette", selection: $wahl.palette) {
                    Text(verbatim: lok("Keine")).tag(Palettenwahl.keine)
                    ForEach(namen + eigenerName, id: \.self) {
                        Text(verbatim: $0).tag(Palettenwahl.name($0))
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button {
                    wahl.palette = .eigene
                    zeigePalette = true
                } label: {
                    if wahl.palette == .eigene {
                        Label(lok("Eigene …"), systemImage: "checkmark")
                    } else {
                        Text(verbatim: lok("Eigene …"))
                    }
                }
                if namen.isEmpty {
                    Divider()
                    Button(lok("Noch nicht abgefragt. Die Namen kommen von der Uhr.")) {}
                        .disabled(true)
                    Button(lok("Uhr abfragen …")) { abfragen() }
                        .disabled(zustand.referenzUhr == nil)
                }
            } label: {
                menuewert(palettenname)
            }
        }
        // Am Mac und am iPad ein Popover am Menü, am iPhone ein Blatt
        // (`presentationCompactAdaptation`): Dasselbe Bauteil, die Größe der
        // Umgebung entscheidet.
        .popover(isPresented: $zeigePalette) {
            Palettenwerkstatt(palette: $wahl.eigenePalette, ueberblenden: wahl.ueberblenden)
                .presentationCompactAdaptation(.sheet)
        }
    }
}

/// Der Editor der eigenen Palette: 1 bis 16 Farben, gleichmäßig verteilt oder
/// mit einer Lage 0–100 je Stütze. Gemischt geht nicht — die Uhr nimmt eine
/// Liste von Farben oder eine von Stützen —, darum ein Schalter für die ganze
/// Palette.
struct Palettenwerkstatt: View {
    @Binding var palette: Eigenepalette
    let ueberblenden: Bool
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Eigene Palette").font(.headline)
                Spacer()
                Button("Fertig") { schliessen() }
                    .keyboardShortcut(.defaultAction)
                    .knopfHaupthandlung()
            }
            Picker("Verteilung", selection: lagenwahl) {
                Text("Gleichmäßig").tag(false)
                Text("Mit Position").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            vorschau
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(palette.stellen.indices, id: \.self) { i in
                        zeile(i)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 280)
            HStack {
                Text("Stützen")
                Spacer()
                Text(verbatim: lokf("%d von %d", palette.stellen.count, Eigenepalette.hoechstzahl))
                    .monospacedDigit().foregroundStyle(.secondary)
                Stepper("Stützen", onIncrement: {
                    palette.hinzufuegen()
                    if !palette.mitPosition { palette.gleichmaessigVerteilen() }
                }, onDecrement: {
                    palette.entfernen()
                    if !palette.mitPosition { palette.gleichmaessigVerteilen() }
                })
                .labelsHidden()
            }
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 340)
        // Als Blatt (iPhone) von oben nach unten gefüllt statt mittig mit Luft
        // darüber; im Popover bleibt es bei der Höhe des Inhalts.
        .frame(maxHeight: schmal ? .infinity : nil, alignment: .top)
        .presentationDetents([.medium, .large])
    }

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    private var lagenwahl: Binding<Bool> {
        Binding(get: { palette.mitPosition },
                set: {
                    palette.mitPosition = $0
                    if !$0 { palette.gleichmaessigVerteilen() }
                })
    }

    /// Die Palette als Streifen: überblendet oder in harten Bändern, wie die
    /// Uhr es mit dem Schalter „Überblenden" malt.
    private var vorschau: some View {
        let stellen = palette.stellen.enumerated().map { i, s -> (Color, Double) in
            let lage = palette.mitPosition ? Double(s.pos) / 100
                : Double(Eigenepalette.gleichmaessigeLagen(palette.stellen.count)[i]) / 100
            return (Color(hex: s.farbe) ?? .black, lage)
        }.sorted { $0.1 < $1.1 }
        return RoundedRectangle(cornerRadius: 6)
            .fill(LinearGradient(stops: gradientstellen(stellen), startPoint: .leading, endPoint: .trailing))
            .frame(height: 22)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
            .accessibilityHidden(true)
    }

    private func gradientstellen(_ stellen: [(Color, Double)]) -> [Gradient.Stop] {
        guard ueberblenden else {
            var harte: [Gradient.Stop] = []
            for (i, s) in stellen.enumerated() {
                let von = i == 0 ? 0 : s.1
                let bis = i + 1 < stellen.count ? stellen[i + 1].1 : 1
                harte.append(.init(color: s.0, location: von))
                harte.append(.init(color: s.0, location: bis))
            }
            return harte
        }
        return stellen.map { .init(color: $0.0, location: $0.1) }
    }

    private func zeile(_ i: Int) -> some View {
        HStack(spacing: 10) {
            Farbkreis(farbe: Binding(
                get: { Color(hex: palette.stellen[i].farbe) ?? .black },
                set: { palette.stellen[i].farbe = $0.hexWert }))
            if palette.mitPosition {
                Slider(value: Binding(get: { Double(palette.stellen[i].pos) },
                                      set: { palette.stellen[i].pos = Int($0.rounded()) }),
                       in: 0...100, step: 1)
                Text(verbatim: lokf("%d %%", palette.stellen[i].pos))
                    .monospacedDigit()
                    .frame(minWidth: 44, alignment: .trailing)
            } else {
                Spacer()
            }
        }
    }
}
