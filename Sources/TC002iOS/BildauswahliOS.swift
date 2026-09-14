import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// **Ein fertiges 52×16-Bild aus dem Bestand schicken** — der einzige Weg, auf
/// dem die Anzeigen aus dem Editor am Telefon ankommen.
///
/// Sie liegen längst hier: `Bilderordner.eigene` ist derselbe iCloud-Ordner,
/// aus dem auch die Icons kommen. Was fehlte, war die Tür — gemalt wird am
/// Telefon weiterhin nicht, ein Raster mit dem Finger wäre keine
/// Arbeitsfläche. **Schicken ist etwas anderes als malen.**
///
/// Ein Bild ist dabei kein Icon: Ein Icon steht *neben* dem Text, eine
/// 52×16-Anzeige ist das **ganze** Display und ersetzt Text und Icon. Deshalb
/// geht sie auch nicht durch die Formatpille, sondern hat ihren eigenen
/// Knopf — und schickt sofort, statt sich in den Sendebildschirm zu setzen.
struct BildauswahliOS: View {
    let platz: Int
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen

    @State private var vorhandene: [Gemaltes] = []
    @State private var gewaehlt: Gemaltes?
    @State private var laeuft = false
    @State private var meldung: String?

    private var sammlung: Bildersammlung { Bildersammlung(ordner: Bilderordner.eigene) }

    var body: some View {
        NavigationStack {
            List {
                if vorhandene.isEmpty {
                    Text("Noch keine Bilder. Sie entstehen im Editor am Mac und am iPad und kommen über iCloud hierher.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(vorhandene, id: \.datei) { bild in
                            zeile(bild)
                        }
                    } footer: {
                        Text("Eine 16 × 52-Anzeige füllt das Display und ersetzt Text und Icon. Eine AWTRIX NG nimmt sie nicht — ihre Anzeige ist 32 × 8.")
                    }
                }
                if let meldung {
                    Text(meldung).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(lokf("An Platz %d senden", platz))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") { senden() }
                        .disabled(gewaehlt == nil || laeuft)
                }
            }
            .onAppear { vorhandene = sammlung.alle() }
        }
        .presentationDragIndicator(.visible)
    }

    private func zeile(_ bild: Gemaltes) -> some View {
        Button {
            gewaehlt = bild
        } label: {
            HStack(spacing: 10) {
                Rasterbild(datei: bild.datei,
                           breite: Pixelfeld.breiteStandard, hoehe: Pixelfeld.hoeheStandard,
                           kante: 2)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(bild.name).lineLimit(1)
                    // Dasselbe Zeichen wie bei den Icons: neben der Angabe,
                    // nicht ins Bild.
                    HStack(spacing: 4) {
                        Text(lok(Leinwandgroesse.anzeige.beschriftung))
                        if Bildraster.bewegt(bild.datei) {
                            Image(systemName: "play.fill").accessibilityLabel(Text("bewegt"))
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if gewaehlt?.datei == bild.datei {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(gewaehlt?.datei == bild.datei ? [.isSelected] : [])
    }

    /// **Der Rahmen wird im Kern gebaut** (`Bildsendung.rahmen`) — ein
    /// Einzelbild als Rechtecke, mehrere als GIF. Dieselbe Entscheidung wie im
    /// Editor am Schreibtisch, an einer Stelle.
    private func senden() {
        guard let bild = gewaehlt else { return }
        laeuft = true
        meldung = nil
        do {
            let rahmen = try Bildsendung.rahmen(aus: bild.datei)
            let name = Meldungsplatz.name(fuer: platz)
            Task {
                await zustand.senden(rahmen, als: name, slotPlatz: platz)
                laeuft = false
                schliessen()
            }
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            laeuft = false
        }
    }
}
