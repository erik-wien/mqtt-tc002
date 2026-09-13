import SwiftUI
import TC002Ansichten
import TC002Core

/// Ein 8×8-Icon als Vorschau. Zeigt das erste Einzelbild; animierte Icons
/// laufen hier nicht, das wäre im Raster nur Unruhe.
struct IconbildiOS: View {
    let datei: URL
    var kante: Double = 3

    var body: some View {
        IconRasteriOS(pixel: (try? Bildraster.lesen(datei, breite: 8, hoehe: 8))?.first ?? [], kante: kante)
    }
}

/// Zeichnet ein bereits gelesenes 8×8-Pixelraster — der gemeinsame Kern von
/// `IconbildiOS` (ein stehendes Einzelbild) und der Einzelansicht, die
/// zusätzlich laufende Icons zeigt.
private struct IconRasteriOS: View {
    let pixel: [String?]
    var kante: Double

    var body: some View {
        Canvas { kontext, _ in
            guard pixel.count == 64 else { return }
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let farbe = pixel[y * 8 + x], let c = Color(hex: farbe) else { continue }
                    kontext.fill(Path(CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                             width: kante, height: kante)), with: .color(c))
                }
            }
        }
        .frame(width: 8 * kante, height: 8 * kante)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Meldet die Breite, die dem Raster tatsächlich zur Verfügung steht — damit
/// die Zellengröße nicht geschätzt werden muss, sondern zur Bildschirmbreite
/// passt. Dieselbe Bauart wie die Breitenmessung der Formatpille in
/// SendeniOS.swift.
private struct RasterBreiteKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Blatt zur Icon-Auswahl. Suchen, wählen, abwählen, und über die
/// LaMetric-Nummer nachladen. Malen geht hier nicht — Icons werden am Mac
/// bearbeitet, ein 8×8-Raster mit dem Finger wäre keine Arbeitsfläche.
///
/// Die Icons stehen als Raster zu acht je Zeile, darunter nur die Nummer —
/// der Name würde die Zellen ungleich breit machen. Antippen öffnet die
/// Einzelansicht (`IconEinzelansichtiOS`) mit Namen, großer — bei laufenden
/// Icons auch laufender — Ansicht und der Schaltfläche „Übernehmen“.
struct IconauswahliOS: View {
    @Binding var gewaehlt: Icon?
    @Environment(\.dismiss) private var schliessen

    @State private var vorhandene: [Icon] = []
    @State private var suche = ""
    @State private var lametricNummer = ""
    @State private var laedt = false
    @State private var meldung: String?
    @State private var einzelansicht: Icon?
    @State private var rasterBreite: CGFloat = 340
    /// `.numberPad` hat keine Eingabetaste — ohne Tastaturleiste kaeme man aus
    /// dem Nummernfeld nur durch Tippen daneben heraus.
    @FocusState private var lametricFokus: Bool

    private static let spalten = 8
    private static let zwischenraum = 6.0

    /// Kantenlänge je Punkt, aus der gemessenen Rasterbreite errechnet — so
    /// passen acht Zellen nebeneinander, auf jeder Bildschirmbreite.
    private var kante: Double {
        let zellenbreite = (Double(rasterBreite) - Double(Self.spalten - 1) * Self.zwischenraum) / Double(Self.spalten)
        return max(3, zellenbreite / 8)
    }

    /// Der Grundschatz wird gelesen, Nachgeladenes geschrieben.
    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("LaMetric-Nummer", text: $lametricNummer)
                            .keyboardType(.numberPad)
                            .focused($lametricFokus)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Fertig") { lametricFokus = false }
                                }
                            }
                        Button("Nachladen") { nachladen() }
                            .knopfBefehl()
                            .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let meldung {
                        Text(meldung).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Nummer von developer.lametric.com — das Icon landet bei den eigenen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    // Eine Listenzeile wie „Hilfe" in den Einstellungen, kein
                    // Befehlsknopf — sie steht fuer sich in der Liste und ist
                    // dort schon als antippbar zu erkennen.
                    Button("Kein Icon") { gewaehlt = nil; schliessen() }
                        .buttonStyle(.automatic)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.zwischenraum), count: Self.spalten),
                              spacing: 14) {
                        ForEach(vorhandene.gefiltert(nach: suche), id: \.nummer) { icon in
                            Button {
                                einzelansicht = icon
                            } label: {
                                VStack(spacing: 2) {
                                    IconbildiOS(datei: icon.datei, kante: kante)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.accentColor, lineWidth: gewaehlt?.nummer == icon.nummer ? 2 : 0)
                                        )
                                    Text(icon.nummer).font(.caption).foregroundStyle(.secondary)
                                }
                                // Die Zelle selbst ist bei acht Spalten schmaler als 44pt und
                                // bleibt es, damit alle acht sichtbar nebeneinander passen. Die
                                // Trefferflaeche greift stattdessen in den Zwischenraum zur
                                // naechsten Zelle: nach aussen gepolstert, dann wieder
                                // eingezogen — das Rasterlayout bleibt gleich gross, nur was
                                // trifft, wird groesser.
                                .padding(Self.zwischenraum / 2)
                                .contentShape(Rectangle())
                            }
                            .padding(-Self.zwischenraum / 2)
                            // Rasterkachel, kein Befehlsknopf — das Icon ist
                            // selbst die Flaeche. `.automatic` ausdruecklich,
                            // damit die Entscheidung im Quelltext steht.
                            .buttonStyle(.automatic)
                            .tint(.primary)
                            .accessibilityLabel(Text(icon.name))
                            .accessibilityAddTraits(gewaehlt?.nummer == icon.nummer ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 6)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: RasterBreiteKey.self, value: geo.size.width)
                        }
                    )
                    .onPreferenceChange(RasterBreiteKey.self) { rasterBreite = $0 }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }
            }
            .searchable(text: $suche, prompt: Text("Suchen"))
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { schliessen() }
            } }
            .onAppear { vorhandene = sammlung.alle() }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: Binding(
            get: { einzelansicht != nil },
            set: { if !$0 { einzelansicht = nil } }
        )) {
            if let icon = einzelansicht {
                IconEinzelansichtiOS(icon: icon) {
                    gewaehlt = icon
                    schliessen()
                }
            }
        }
    }

    /// Holt ein Icon über seine Nummer. Blockiert nicht den Hauptthread — der
    /// Abruf geht übers Netz und dauert.
    private func nachladen() {
        let nummer = lametricNummer.trimmingCharacters(in: .whitespaces)
        laedt = true
        meldung = nil
        let quelle = sammlung
        Task.detached {
            do {
                let icon = try quelle.holen(nummer: nummer)
                await MainActor.run {
                    vorhandene = quelle.alle()
                    gewaehlt = icon
                    meldung = lokf("%@ geholt.", icon.name)
                    lametricNummer = ""
                    laedt = false
                }
            } catch {
                await MainActor.run {
                    meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    laedt = false
                }
            }
        }
    }
}

/// Einzelansicht eines Icons: Name als Titel, groß gerastert — bei einem
/// laufenden Icon auch laufend —, darunter „Übernehmen“.
///
/// Bauart wie die Vorschau am Sendebildschirm (`VorschauiOS`): Die
/// Einzelbilder samt Standzeiten werden einmal über `.task(id:)` in
/// `@State` gelesen, nicht bei jedem Neuzeichnen — `TimelineView(.animation)`
/// liefe sonst 60 bis 120 mal je Sekunde auf dem Hauptthread. `TimelineView`
/// wird zudem nur montiert, wenn es tatsächlich mehr als ein Einzelbild gibt.
private struct IconEinzelansichtiOS: View {
    let icon: Icon
    let uebernehmen: () -> Void
    @Environment(\.dismiss) private var schliessen

    @State private var bilder: [Bildraster.Einzelbild] = []

    private static let kante = 20.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if bilder.count > 1 {
                    TimelineView(.animation) { zeit in
                        IconRasteriOS(pixel: Self.einzelbild(aus: bilder, bei: zeit.date)?.pixel ?? bilder[0].pixel,
                                      kante: Self.kante)
                    }
                } else {
                    IconRasteriOS(pixel: bilder.first?.pixel ?? [], kante: Self.kante)
                }
                Spacer()
                Button("Übernehmen", action: uebernehmen)
                    .knopfHaupthandlung()
            }
            .padding()
            .navigationTitle(icon.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { schliessen() }
            } }
        }
        .task(id: icon.datei) {
            bilder = (try? Bildraster.lesenMitZeiten(icon.datei, breite: 8, hoehe: 8)) ?? []
        }
    }

    /// Wählt anhand der verstrichenen Zeit das fällige Einzelbild — dieselbe
    /// Logik wie in `VorschauiOS`, hier dupliziert, weil jene Methode dort
    /// privat ist und diese Aufgabe nur `IconauswahliOS.swift` ändern soll.
    private static func einzelbild(aus liste: [Bildraster.Einzelbild], bei zeitpunkt: Date) -> Bildraster.Einzelbild? {
        guard !liste.isEmpty else { return nil }
        let gesamt = liste.reduce(0) { $0 + $1.dauer }
        guard gesamt > 0 else { return liste.first }
        var rest = zeitpunkt.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: gesamt)
        for bild in liste {
            if rest < bild.dauer { return bild }
            rest -= bild.dauer
        }
        return liste.last
    }
}
