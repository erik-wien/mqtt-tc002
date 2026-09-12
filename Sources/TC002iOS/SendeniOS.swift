import SwiftUI
import TC002Core
import TC002Modell

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

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

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
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            zeigeVerlauf = true
                        } label: {
                            Label("Verlauf", systemImage: "clock.arrow.circlepath")
                        }
                        Button {
                            zeigeEinstellungen = true
                        } label: {
                            Label("Einstellungen", systemImage: "gearshape")
                        }
                    } label: {
                        Label("Menü", systemImage: "line.3.horizontal")
                    }
                }
                if zustand.uhren.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Ziel") { zeigeZiele = true }
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeFormat) {
            FormatblattiOS(weg: $weg, schrift: $schrift, groesse: $groesse, fett: $fett,
                           grossbuchstaben: $grossbuchstaben, rand: $rand, abstand: $luecke,
                           senkrecht: $vertikal, tempo: $tempo, iconLaeuftMit: $iconLaeuftMit)
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
                TextField("Uhr entscheidet", text: $dauerText)
                    .keyboardType(.numberPad)
                    .frame(width: 64)
                    .multilineTextAlignment(.trailing)
                Text("s")
            }
            .font(.callout)
        }
        .padding(.horizontal)
    }

    /// Was man ständig ändert, direkt erreichbar. Alles Übrige hinter „Format".
    private var formatleiste: some View {
        HStack(spacing: 14) {
            ColorPicker("Farbe", selection: farbe, supportsOpacity: false)
                .labelsHidden()
            Button { zeigeIcons = true } label: {
                if let icon = gewaehltesIcon {
                    IconbildiOS(datei: icon.datei, kante: 2.5)
                } else {
                    Image(systemName: "face.smiling")
                }
            }
            Picker("Ausrichtung", selection: $horizontal) {
                Image(systemName: "text.alignleft").tag(SendenHAusrichtung.links)
                Image(systemName: "text.aligncenter").tag(SendenHAusrichtung.mittig)
                Image(systemName: "text.alignright").tag(SendenHAusrichtung.rechts)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 150)
            Spacer()
            Button("Format") { zeigeFormat = true }
                .font(.callout)
        }
        .padding(.horizontal)
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
