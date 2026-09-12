import SwiftUI
import TC002Core

/// Ein 8×8-Icon als Vorschau. Zeigt das erste Einzelbild; animierte Icons
/// laufen hier nicht, das wäre in einer Liste nur Unruhe.
struct IconbildiOS: View {
    let datei: URL
    var kante: Double = 3

    var body: some View {
        Canvas { kontext, _ in
            guard let bilder = try? Bildraster.lesen(datei, breite: 8, hoehe: 8),
                  let erstes = bilder.first else { return }
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let farbe = erstes[y * 8 + x], let c = Color(hex: farbe) else { continue }
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

/// Blatt zur Icon-Auswahl. Suchen, wählen, abwählen, und über die
/// LaMetric-Nummer nachladen. Malen geht hier nicht — Icons werden am Mac
/// bearbeitet, ein 8×8-Raster mit dem Finger wäre keine Arbeitsfläche.
struct IconauswahliOS: View {
    @Binding var gewaehlt: Icon?
    @Environment(\.dismiss) private var schliessen

    @State private var vorhandene: [Icon] = []
    @State private var suche = ""
    @State private var lametricNummer = ""
    @State private var laedt = false
    @State private var meldung: String?

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
                        Button("Nachladen") { nachladen() }
                            .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let meldung {
                        Text(meldung).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Nummer von developer.lametric.com — das Icon landet bei den eigenen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Kein Icon") { gewaehlt = nil; schliessen() }
                    ForEach(vorhandene.gefiltert(nach: suche), id: \.nummer) { icon in
                        Button {
                            gewaehlt = icon
                            schliessen()
                        } label: {
                            HStack {
                                IconbildiOS(datei: icon.datei)
                                VStack(alignment: .leading) {
                                    Text(icon.name)
                                    Text(icon.nummer).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if gewaehlt?.nummer == icon.nummer {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                    }
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
