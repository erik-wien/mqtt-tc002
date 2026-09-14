import SwiftUI
import TC002Ansichten
import TC002Core

/// Ein Icon als stehende Vorschau. Zeigt das erste Einzelbild; animierte Icons
/// laufen hier nicht, das wäre im Raster nur Unruhe.
///
/// **Nimmt die Fläche, die es bekommt, und rechnet die Punktgröße daraus** —
/// wie `Slotraster` es im Block tut. Bis zum 14.09.2026 bekam es die Kante je
/// Bildpunkt von außen gereicht, und die stammte aus einer gemessenen
/// Rasterbreite; wo die Messung zu klein ausfiel, standen die Icons in
/// Originalauflösung da, also stecknadelkopfgroß. Eine Ansicht, deren Größe
/// von einer Messung abhängt, die ihrerseits von der Größe abhängt, ist eine
/// Falle — der Aufrufer setzt jetzt einen Rahmen, und das Bild füllt ihn.
struct IconbildiOS: View {
    let datei: URL
    /// **Die Kantenlaenge des Icons in Pixeln — 8 oder 16.**
    ///
    /// Bis zum 14.09.2026 stand hier ueberall die 8 fest. Das ging, solange
    /// das Telefon nur den 8×8-Bestand kannte; seit die eigenen 16×16 ueber
    /// iCloud auch dort ankommen, zeigte es sie gar nicht erst an.
    var pixelkante: Int = 8

    var body: some View {
        IconRasteriOS(pixel: (try? Bildraster.lesen(datei, breite: pixelkante, hoehe: pixelkante))?.first ?? [],
                      pixelkante: pixelkante)
    }
}

/// Zeichnet ein bereits gelesenes Pixelraster in die verfügbare Fläche — der
/// gemeinsame Kern von `IconbildiOS` (ein stehendes Einzelbild) und der
/// Einzelansicht, die zusätzlich laufende Icons zeigt. Quadratisch, weil ein
/// Icon quadratisch ist; beide Größen werden damit gleich groß gezeigt, das
/// 16×16 ist nicht das doppelt so große Bild, sondern das feinere.
private struct IconRasteriOS: View {
    let pixel: [String?]
    /// 8 oder 16 — siehe `IconbildiOS.pixelkante`.
    var pixelkante: Int = 8

    var body: some View {
        Canvas { kontext, groesse in
            guard pixel.count == pixelkante * pixelkante else { return }
            let kante = groesse.width / Double(pixelkante)
            for y in 0..<pixelkante {
                for x in 0..<pixelkante {
                    guard let farbe = pixel[y * pixelkante + x], let c = Color(hex: farbe) else { continue }
                    kontext.fill(Path(CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                             width: kante, height: kante)), with: .color(c))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Blatt zur Icon-Auswahl. Suchen, wählen, abwählen, umbenennen, löschen, und
/// über die LaMetric-Nummer nachladen. Malen geht hier nicht — Icons werden am
/// Mac bearbeitet, ein 8×8-Raster mit dem Finger wäre keine Arbeitsfläche.
///
/// Die Icons stehen als Raster zu fünf je Zeile, darunter der Name. Bis zum
/// 14.09.2026 waren es acht — dort war unter der Kachel nur Platz für die
/// Nummer, und die sagt bei einem eigenen Icon nichts. Antippen öffnet die
/// Einzelansicht (`IconEinzelansichtiOS`) mit Namen, großer — bei laufenden
/// Icons auch laufender — Ansicht, „Übernehmen“ und dem Menü zum Umbenennen
/// und Löschen.
struct IconauswahliOS: View {
    @Binding var gewaehlt: Icon?
    @Environment(\.dismiss) private var schliessen

    @State private var vorhandene: [Icon] = []
    @State private var suche = ""
    @State private var lametricNummer = ""
    @State private var laedt = false
    @State private var meldung: String?
    @State private var einzelansicht: Icon?
    /// Die Filterleiste: Größe und Bewegung.
    @State private var filterkante: Int?
    @State private var nurBewegte = false
    /// **Einmal gelesen, nicht bei jedem Tastendruck.** Welche Icons sich
    /// bewegen, steht in den Dateien; `bewegteKennungen()` fragt sie beim
    /// Laden des Bestands, danach ist es ein Nachschlagen.
    @State private var bewegte: Set<String> = []
    /// `.numberPad` hat keine Eingabetaste — ohne Tastaturleiste kaeme man aus
    /// dem Nummernfeld nur durch Tippen daneben heraus.
    @FocusState private var lametricFokus: Bool

    private static let spalten = 5
    private static let zwischenraum = 10.0

    /// Der Grundschatz wird gelesen, Nachgeladenes geschrieben.
    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    /// **Beide Bestaende**, wie am Schreibtisch und wie im Werkzeug seit
    /// `224ad3f`. Ein eigenes 16×16 entsteht zwar nur im Editor am Mac — ueber
    /// den iCloud-Abgleich liegt es danach aber auch hier, und bis zum
    /// 14.09.2026 zeigte das Telefon es gar nicht erst an.
    ///
    /// `sammlung` behaelt dabei ihren zusaetzlichen Leseordner
    /// (`Iconordner.mitgeliefert`); den Unterschied zum Schreibtisch taste ich
    /// hier nicht an, er gehoert nicht zu dieser Aenderung.
    private var bestaende: [Iconsammlung] {
        [sammlung, Iconsammlung(schreibordner: Iconordner.eigene16, kante: 16)]
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
                    Filterleiste(wert: $filterkante,
                         angebot: [(Leinwandgroesse.icon8.beschriftung, 8),
                                   (Leinwandgroesse.icon16.beschriftung, 16)],
                         nurBewegte: $nurBewegte)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.zwischenraum), count: Self.spalten),
                              spacing: 14) {
                        // **Die Kennung, nicht die Nummer.** Beide Bestaende
                        // zaehlen ihre Nummern getrennt; ein 8×8 und ein 16×16
                        // duerfen „82" heissen. Mit `nummer` als Kennung
                        // standen im Raster doppelte Kennungen, und SwiftUI
                        // beantwortet das nicht mit einem Fehler, sondern mit
                        // der falschen Kachel: Jedes Tippen oeffnete dasselbe
                        // Icon.
                        ForEach(vorhandene.gefiltert(Iconfilter(suche: suche, kante: filterkante,
                                                                nurBewegte: nurBewegte),
                                                     bewegt: { bewegte.contains($0.kennung) }),
                                id: \.kennung) { icon in
                            Button {
                                einzelansicht = icon
                            } label: {
                                VStack(spacing: 3) {
                                    IconbildiOS(datei: icon.datei, pixelkante: icon.kante)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.accentColor, lineWidth: gewaehlt?.kennung == icon.kennung ? 2 : 0)
                                        )
                                    // **Das Abspielzeichen neben den Namen,
                                    // nicht ins Bild** — dieselbe Entscheidung
                                    // wie in den Listen am Schreibtisch.
                                    // LaMetric und AWTRIX legen es
                                    // durchscheinend ueber das Vorschaubildchen
                                    // und verdecken damit gerade das Motiv, das
                                    // man erkennen soll. Hier ist die
                                    // Namenszeile ohnehin da.
                                    HStack(spacing: 2) {
                                        if bewegte.contains(icon.kennung) {
                                            Image(systemName: "play.fill")
                                                .accessibilityHidden(true)
                                        }
                                        Text(icon.name).lineLimit(1)
                                    }
                                    .font(.caption2).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            // **`.plain`, und daran haengt, ob ueberhaupt das
                            // getroffene Icon aufgeht.** Eine Listenzeile ist
                            // selbst ein Bedienelement: Knoepfe mit dem
                            // vorgegebenen Stil darin teilen sich ihre Flaeche,
                            // und ein Tipp landet beim ersten. Vierzig Kacheln
                            // in einer Zeile hiessen also vierzigmal dasselbe
                            // Icon. Derselbe Fallstrick wie im Editor bei
                            // „Sichern"/„Neu" und in der Blockreihe.
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(bewegte.contains(icon.kennung)
                                                     ? lokf("%@, bewegt", icon.name) : icon.name))
                            .accessibilityAddTraits(gewaehlt?.kennung == icon.kennung ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }
            }
            .searchable(text: $suche, prompt: Text("Suchen"))
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { schliessen() }
            } }
            .onAppear { neuLesen() }
        }
        .presentationDragIndicator(.visible)
        // **`item:` und nicht `isPresented:`.** Ein Blatt, das ueber einen
        // Merker aufgeht und seinen Inhalt aus einem zweiten Zustand liest,
        // baut ihn in dem Augenblick, in dem SwiftUI den Merker sieht — und
        // das war hier einmal zu frueh: Es zeigte das zuvor angetippte Icon.
        // Mit `item:` kommt das Icon als Wert herein, den es zeigen soll.
        .sheet(item: $einzelansicht) { icon in
            IconEinzelansichtiOS(
                icon: icon,
                // Eigen heisst: Es liegt in einem Schreibordner dieser App.
                // Der Grundschatz im Buendel liegt das nicht und laesst sich
                // deshalb weder umbenennen noch loeschen.
                darfAendern: heimat(von: icon) != nil,
                uebernehmen: { gewaehlt = $0; schliessen() },
                umbenennen: { umbenennen($0, auf: $1) },
                loeschen: { loeschen($0) })
        }
    }

    private func neuLesen() {
        vorhandene = bestaende.flatMap { $0.alle() }
        bewegte = vorhandene.bewegteKennungen()
    }

    /// Die Sammlung, in deren Schreibordner dieses Icon liegt — allein sie
    /// darf es ändern. Welche das ist, entscheidet sie selbst (`istEigen`) und
    /// nicht diese Ansicht.
    private func heimat(von icon: Icon) -> Iconsammlung? {
        bestaende.first { $0.istEigen(icon) }
    }

    /// Gibt dem Icon einen neuen Namen. **Die Nummer bleibt** — sie ist der
    /// Dateiname und das, worauf sich ein Kurzbefehl oder das
    /// Kommandozeilenwerkzeug beruft. Zurück kommt das umbenannte Icon, damit
    /// die Einzelansicht ihren Titel nachziehen kann.
    private func umbenennen(_ icon: Icon, auf name: String) -> Icon? {
        guard let heimat = heimat(von: icon),
              let neu = try? heimat.umbenennen(icon, nummer: icon.nummer, name: name) else { return nil }
        if gewaehlt?.kennung == icon.kennung { gewaehlt = neu }
        neuLesen()
        return neu
    }

    /// Entfernt das Icon endgültig. War es gerade gewählt, fällt die Wahl auf
    /// „Kein Icon" zurück — es gibt danach nichts mehr, worauf sie zeigen
    /// könnte. Dieselbe Entscheidung wie im Auswahlblatt am Schreibtisch.
    private func loeschen(_ icon: Icon) {
        guard let heimat = heimat(von: icon), (try? heimat.loeschen(icon)) != nil else { return }
        if gewaehlt?.kennung == icon.kennung { gewaehlt = nil }
        neuLesen()
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
                    // Beide Bestaende: Geholt wird zwar nur ein 8×8 von
                    // LaMetric, die Liste zeigt aber beide.
                    neuLesen()
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
/// laufenden Icon auch laufend —, darunter „Übernehmen“. Im Menü rechts oben
/// stehen „Umbenennen“ und „Löschen“; sie sind hier und nicht in der Kachel,
/// weil erst hier der Name dabeisteht, den die Rückfrage nennt.
///
/// Bauart wie die Vorschau am Sendebildschirm (`VorschauiOS`): Die
/// Einzelbilder samt Standzeiten werden einmal über `.task(id:)` in
/// `@State` gelesen, nicht bei jedem Neuzeichnen — `TimelineView(.animation)`
/// liefe sonst 60 bis 120 mal je Sekunde auf dem Hauptthread. `TimelineView`
/// wird zudem nur montiert, wenn es tatsächlich mehr als ein Einzelbild gibt.
private struct IconEinzelansichtiOS: View {
    let darfAendern: Bool
    let uebernehmen: (Icon) -> Void
    let umbenennen: (Icon, String) -> Icon?
    let loeschen: (Icon) -> Void
    @Environment(\.dismiss) private var schliessen

    /// Das Icon liegt hier als Zustand und nicht als Übergabewert: Nach dem
    /// Umbenennen soll der Titel der neue sein, ohne dass das Blatt zugeht.
    @State private var icon: Icon
    @State private var bilder: [Bildraster.Einzelbild] = []
    @State private var neuerName = ""
    @State private var fragtUmbenennen = false
    @State private var fragtLoeschen = false

    /// Kantenlaenge der grossen Ansicht in Punkten — nicht je Bildpunkt.
    private static let kante = 220.0

    init(icon: Icon, darfAendern: Bool,
         uebernehmen: @escaping (Icon) -> Void,
         umbenennen: @escaping (Icon, String) -> Icon?,
         loeschen: @escaping (Icon) -> Void) {
        _icon = State(initialValue: icon)
        self.darfAendern = darfAendern
        self.uebernehmen = uebernehmen
        self.umbenennen = umbenennen
        self.loeschen = loeschen
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if bilder.count > 1 {
                    TimelineView(.animation) { zeit in
                        IconRasteriOS(pixel: Self.einzelbild(aus: bilder, bei: zeit.date)?.pixel ?? bilder[0].pixel,
                                      pixelkante: icon.kante)
                            .frame(width: Self.kante, height: Self.kante)
                    }
                } else {
                    IconRasteriOS(pixel: bilder.first?.pixel ?? [],
                                  pixelkante: icon.kante)
                        .frame(width: Self.kante, height: Self.kante)
                }
                Spacer()
                Button("Übernehmen") { uebernehmen(icon) }
                    .knopfHaupthandlung()
            }
            .padding()
            .navigationTitle(icon.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                if darfAendern {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Umbenennen") {
                                neuerName = icon.name
                                fragtUmbenennen = true
                            }
                            Button("Löschen", role: .destructive) { fragtLoeschen = true }
                        } label: {
                            Label("Mehr", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Umbenennen", isPresented: $fragtUmbenennen) {
                TextField("Name", text: $neuerName)
                Button("Abbrechen", role: .cancel) {}
                Button("Sichern") {
                    if let neu = umbenennen(icon, neuerName) { icon = neu }
                }
            } message: {
                Text("Die Nummer bleibt, wie sie ist — Kurzbefehle finden das Icon weiterhin.")
            }
            .confirmationDialog(Text(lokf("„%@“ löschen?", icon.name)),
                                isPresented: $fragtLoeschen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    loeschen(icon)
                    schliessen()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text(lokf("Das Icon „%@“ wird endgültig entfernt.", icon.name))
            }
        }
        .task(id: icon.datei) {
            bilder = (try? Bildraster.lesenMitZeiten(icon.datei, breite: icon.kante, hoehe: icon.kante)) ?? []
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
