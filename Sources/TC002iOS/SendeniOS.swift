import SwiftUI
import TC002Core
import TC002Modell

// Melden die Geometrie der schiebbaren Formatpille (Inhaltsbreite, sichtbare
// Breite, Schiebeversatz) von innerhalb der ScrollView nach aussen — daraus
// entscheidet `SendeniOS.zeigtPfeil`, ob rechts noch etwas liegt.
private struct PilleInhaltsbreiteKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct PilleSichtbarKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct PilleVersatzKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Der Kern der App, aufgebaut wie ein Nachrichtenfenster: die Vorschau oben
/// und sichtbar bleibend, Eingabe und Sendeknopf unten über der Tastatur. Wer
/// tippt, will sehen, was herauskommt — stünde die Vorschau unten, verdeckte
/// die Tastatur sie genau dann, wenn man sie braucht.
struct SendeniOS: View {
    @Bindable var zustand: AppZustand

    // Dieselben Schlüssel wie auf dem Mac. Wer sie ändert, verliert die
    // Einstellungen einer laufenden Installation.
    @AppStorage("senden.text") private var text = "Hallo"
    @AppStorage("senden.farbe") private var farbeHex = "#00FF66"
    @AppStorage("senden.schriftart") private var schrift = "Silkscreen"
    @AppStorage("senden.groesse") private var groesse = 8.0
    @AppStorage("senden.fett") private var fett = false
    @AppStorage("senden.luecke") private var luecke = 1
    @AppStorage("senden.grossbuchstaben") private var grossbuchstaben = false
    @AppStorage("senden.horizontal") private var horizontal: SendenHAusrichtung = .links
    @AppStorage("senden.vertikal") private var vertikal: SendenVAusrichtung = .oben
    @AppStorage("senden.rand") private var rand = 1
    @AppStorage("senden.weg") private var weg: SendeWeg = .pixel
    @AppStorage("senden.tempo") private var tempo: Lauftempo = .mittel
    @AppStorage("senden.iconmitlaufend") private var iconLaeuftMit = false
    @AppStorage("senden.icon") private var iconNummer = ""
    @AppStorage("senden.meldungsplatz") private var platz = 1
    @AppStorage("senden.dauer") private var dauerText = ""

    @State private var gewaehltesIcon: Icon?
    @State private var laufschriftFrames: [Bildraster.Einzelbild] = []
    @State private var laufschriftURI = ""
    @State private var laeuft = false
    @State private var zeigeFormat = false
    @State private var zeigeIcons = false
    @State private var zeigeZiele = false
    @State private var zeigeEinstellungen = false
    @State private var zeigeVerlauf = false

    // Misst die schiebbare Formatpille, um den Pfeil nur zu zeigen, solange
    // rechts wirklich noch etwas liegt (siehe `zeigtPfeil` unten).
    @State private var pilleInhaltsbreite: CGFloat = 0
    @State private var pilleSichtbareBreite: CGFloat = 0
    @State private var pilleVersatz: CGFloat = 0

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    /// Dieselbe Auswahl wie auf dem Mac (`geeigneteSchriften` in
    /// SendenView.swift) — geprueft bei sechzehn Pixeln Hoehe. Eine Liste statt
    /// zweier: Frueher stand dieselben acht Namen zusätzlich in
    /// FormatblattiOS, seit die Schriftart in die Formatpille gewandert ist,
    /// steht sie nur noch hier.
    private static let schriften = ["Micro 5", "Silkscreen", "Tiny5", "Geneva",
                                    "Monaco", "Andale Mono", "Menlo", "PT Mono"]

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann im Rahmen.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Die einzige Stelle, an der aus Ansichtszustand ein Auftrag wird.
    private var optionen: Meldungsoptionen {
        Meldungsoptionen(text: text, weg: weg, schrift: schrift, groesse: groesse,
                         fett: fett, farbe: farbeHex, grossbuchstaben: grossbuchstaben,
                         waagrecht: horizontal, senkrecht: vertikal, rand: rand,
                         abstand: luecke, tempo: tempo, iconLaeuftMit: iconLaeuftMit,
                         dauer: dauer)
    }

    private var mitIcon: Bool { gewaehltesIcon != nil }
    private var passt: Bool { Meldungsbau.passt(optionen, mitIcon: mitIcon) }

    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                ScrollView {
                    VStack(spacing: 14) {
                        VorschauiOS(feld: Meldungsbau.feld(optionen, mitIcon: mitIcon),
                                    icon: (weg == .text || passt) ? gewaehltesIcon?.datei : nil,
                                    laufschriftBilder: (weg == .pixel && !passt) ? laufschriftFrames : nil)
                        if weg == .pixel && !passt {
                            Text(lokf("Läuft durch: %d Einzelbilder", laufschriftFrames.count))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        platzUndDauer
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                formatleiste
                eingabe
            }
            .navigationTitle(zustand.uhren.count > 1 ? zielName : lok("Senden"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if zustand.uhren.count > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Ziel") { zeigeZiele = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        zeigeVerlauf = true
                    } label: {
                        Label("Verlauf", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        zeigeEinstellungen = true
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeFormat) {
            FormatblattiOS(weg: $weg, groesse: $groesse, fett: $fett,
                           grossbuchstaben: $grossbuchstaben, tempo: $tempo,
                           iconLaeuftMit: $iconLaeuftMit)
        }
        .sheet(isPresented: $zeigeIcons) {
            IconauswahliOS(gewaehlt: $gewaehltesIcon)
        }
        .sheet(isPresented: $zeigeZiele) {
            ZielauswahliOS(zustand: zustand)
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            VerbindungiOS(zustand: zustand)
        }
        .sheet(isPresented: $zeigeVerlauf) {
            AnzeigeniOS(zustand: zustand)
        }
        .onAppear {
            if gewaehltesIcon == nil, !iconNummer.isEmpty {
                gewaehltesIcon = sammlung.alle().first { $0.nummer == iconNummer }
            }
        }
        .onChange(of: gewaehltesIcon?.nummer) { _, neu in iconNummer = neu ?? "" }
        .task(id: laufschriftSchluessel) { await laufschriftRechnen() }
    }

    private var zielName: String {
        let ziele = zustand.ziele()
        if ziele.count == 1 { return ziele[0].name }
        return lokf("an %d Uhren", ziele.count)
    }

    private var platzUndDauer: some View {
        HStack(spacing: 12) {
            Picker("Meldung", selection: $platz) {
                ForEach(1...Meldungsplatz.anzahl, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            HStack(spacing: 4) {
                Text("Dauer")
                // Ohne feste Breite: Bei "Uhr entscheidet" als Platzhalter
                // schnitt 64pt auf dem Telefon den Text ab (auf dem breiteren
                // Mac-Fenster passte dieselbe Breite noch).
                TextField("Uhr entscheidet", text: $dauerText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                Text("s")
            }
            .font(.callout)
        }
        .padding(.horizontal)
    }

    /// Symbol fuer den Stand der waagrechten Ausrichtung — kein Ternaer, sonst
    /// greift die nicht uebersetzende Overload von `Image(systemName:)`.
    private var horizontalSymbol: String {
        switch horizontal {
        case .links: return "text.alignleft"
        case .mittig: return "text.aligncenter"
        case .rechts: return "text.alignright"
        }
    }

    /// Dieselben Symbole wie am Mac (`ausrichtungsKnopf` in SendenView.swift).
    private var vertikalSymbol: String {
        switch vertikal {
        case .oben: return "align.vertical.top"
        case .mittig: return "align.vertical.center"
        case .unten: return "align.vertical.bottom"
        }
    }

    /// Der Pfeil am rechten Rand der Pille zeigt nur an, solange dort
    /// wirklich noch etwas liegt, und verschwindet, sobald ganz durchgeschoben
    /// ist — sonst verspraeche er etwas, das nicht mehr da ist. 1pt Toleranz
    /// gegen Rundung der gemeldeten Groessen.
    private var zeigtPfeil: Bool {
        let rest = pilleInhaltsbreite - pilleSichtbareBreite - pilleVersatz
        return pilleInhaltsbreite > pilleSichtbareBreite + 1 && rest > 1
    }

    /// Was man ständig ändert, direkt erreichbar. Alles Übrige hinter dem
    /// Pinsel. Eine Pille wie in Pages: gleichwertige, einfarbige Symbole
    /// nebeneinander. Acht Stueck passen nicht immer nebeneinander auf ein
    /// Telefon, deshalb schiebbar — die ersten fuenf (Icon, waagrecht,
    /// senkrecht, Farbe, Pinsel) muessen dafuer ohne Schieben sichtbar
    /// bleiben, siehe Bericht zur Breitenrechnung. Farbe steht bewusst nicht
    /// neben Icon: beide sind bunt und rund, nebeneinander leicht verwechselt;
    /// mit dem Pinsel dazwischen nicht mehr.
    private var formatleiste: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { zeigeIcons = true } label: {
                        if let icon = gewaehltesIcon {
                            IconbildiOS(datei: icon.datei, kante: 2.5)
                        } else {
                            Image(systemName: "face.smiling")
                        }
                    }
                    .frame(width: 44, height: 44)
                    Menu {
                        Button { horizontal = .links } label: {
                            Label("Linksbündig", systemImage: "text.alignleft")
                        }
                        Button { horizontal = .mittig } label: {
                            Label("Zentriert", systemImage: "text.aligncenter")
                        }
                        Button { horizontal = .rechts } label: {
                            Label("Rechtsbündig", systemImage: "text.alignright")
                        }
                    } label: {
                        Image(systemName: horizontalSymbol)
                    }
                    .frame(width: 44, height: 44)
                    Menu {
                        Button { vertikal = .oben } label: {
                            Label("Oben", systemImage: "align.vertical.top")
                        }
                        Button { vertikal = .mittig } label: {
                            Label("Mittig", systemImage: "align.vertical.center")
                        }
                        Button { vertikal = .unten } label: {
                            Label("Unten", systemImage: "align.vertical.bottom")
                        }
                    } label: {
                        Image(systemName: vertikalSymbol)
                    }
                    .frame(width: 44, height: 44)
                    ColorPicker("Farbe", selection: farbe, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44, height: 44)
                    Button { zeigeFormat = true } label: {
                        Image(systemName: "paintbrush")
                    }
                    .frame(width: 44, height: 44)
                    Menu {
                        Picker("Schriftart", selection: $schrift) {
                            ForEach(Self.schriften, id: \.self) { Text($0).tag($0) }
                        }
                    } label: {
                        Text(schrift)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    Menu {
                        Picker("Rand", selection: $rand) {
                            ForEach(0...3, id: \.self) { n in Text(String(n)).tag(n) }
                        }
                    } label: {
                        Label { Text(String(rand)) } icon: { Image(systemName: "arrow.up.and.down") }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text(lokf("Rand %d", rand)))
                    Menu {
                        Picker("Abstand", selection: $luecke) {
                            ForEach(0...3, id: \.self) { n in Text(String(n)).tag(n) }
                        }
                    } label: {
                        Label { Text(String(luecke)) } icon: { Image(systemName: "arrow.left.and.right") }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text(lokf("Abstand %d", luecke)))
                }
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: PilleInhaltsbreiteKey.self, value: geo.size.width)
                            .preference(key: PilleVersatzKey.self,
                                        value: -geo.frame(in: .named("pilleRaum")).minX)
                    }
                )
            }
            .coordinateSpace(.named("pilleRaum"))
            .frame(height: 60)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PilleSichtbarKey.self, value: geo.size.width)
                }
            )
            .background(.thinMaterial)
            .clipShape(Capsule())
            .onPreferenceChange(PilleInhaltsbreiteKey.self) { pilleInhaltsbreite = $0 }
            .onPreferenceChange(PilleVersatzKey.self) { pilleVersatz = $0 }
            .onPreferenceChange(PilleSichtbarKey.self) { pilleSichtbareBreite = $0 }

            if zeigtPfeil {
                Image(systemName: "chevron.compact.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Weitere Bedienelemente")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var eingabe: some View {
        HStack(spacing: 8) {
            TextField("Text", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await senden() }
            } label: {
                if laeuft {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
            }
            .disabled(laeuft || text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhängt — damit die (nicht
    /// ganz billige) Berechnung nur bei einer tatsächlichen Änderung neu läuft.
    private var laufschriftSchluessel: String {
        "\(weg)|\(passt)|\(optionen.gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(rand)|\(iconNummer)|\(iconLaeuftMit)|\(luecke)"
    }

    /// Mehrere hundert Einzelbilder rastern, als GIF kodieren, Base64 darüber —
    /// bei jedem Tastendruck. Das gehört nicht auf den Hauptthread, sonst
    /// stockt das Eingabefeld.
    private func laufschriftRechnen() async {
        guard weg == .pixel, !passt else {
            laufschriftFrames = []; laufschriftURI = ""; return
        }
        let o = optionen
        let iconBilder = gewaehltesIcon.flatMap { i -> [[String?]]? in
            try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
        } ?? []
        let (frames, uri) = await Task.detached(priority: .userInitiated) {
            let frames = Meldungsbau.laufschriftBilder(o, iconBilder: iconBilder)
            let uri = (try? Bildraster.alsDatenURI(
                frames.map(\.pixel), breite: Pixelfeld.breiteStandard,
                hoehe: Pixelfeld.hoeheStandard, verzoegerung: o.tempo.bilddauer)) ?? ""
            return (frames, uri)
        }.value
        guard !Task.isCancelled else { return }
        laufschriftFrames = frames
        laufschriftURI = uri
    }

    private func senden() async {
        laeuft = true
        defer { laeuft = false }
        do {
            let rahmen = try Meldungsbau.rahmen(optionen, icon: gewaehltesIcon,
                                                sammlung: sammlung, vorberechnet: laufschriftURI)
            await zustand.senden(rahmen, als: Meldungsplatz.name(fuer: platz))
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
