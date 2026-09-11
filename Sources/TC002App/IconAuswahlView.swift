import AppKit
import SwiftUI
import TC002Core

/// Waehlt ein Icon aus der Sammlung — ein Knopf zeigt Vorschau und Namen des
/// gewaehlten Icons (oder „kein Icon"), ein Druck oeffnet ein Blatt mit Suche
/// und Raster. Baugleich mit `ZielauswahlView`: derselbe Blattkopf, derselbe
/// „Schließen"-Knopf — die Blaetter der App sollen sich gleich anfuehlen.
///
/// Ein Icon gehoert inhaltlich zum Text, nicht zum Versand — der Knopf steht
/// deshalb bei Text und Vorschau, nicht in der Sendezeile.
struct IconAuswahlView: View {
    @Binding var gewaehltesIcon: Icon?
    let sammlung: Iconsammlung

    @State private var zeigeBlatt = false
    @State private var suche = ""

    private var gefilterte: [Icon] { sammlung.alle().gefiltert(nach: suche) }

    var body: some View {
        Button { zeigeBlatt = true } label: {
            HStack(spacing: 6) {
                if let icon = gewaehltesIcon, let bild = NSImage(contentsOf: icon.datei) {
                    Image(nsImage: bild).interpolation(.none)
                        .resizable().frame(width: 16, height: 16)
                    Text(icon.name)
                } else {
                    Image(systemName: "square.dashed")
                    Text("kein Icon")
                }
            }
        }
        .sheet(isPresented: $zeigeBlatt) { blatt }
    }

    private var blatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon wählen").font(.headline)
            TextField("Suchen", text: $suche)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    Button { gewaehltesIcon = nil } label: { Text("ohne").font(.caption) }
                        .buttonStyle(.bordered)
                    ForEach(gefilterte, id: \.nummer) { icon in
                        Button { gewaehltesIcon = icon } label: {
                            VStack(spacing: 2) {
                                if let bild = NSImage(contentsOf: icon.datei) {
                                    Image(nsImage: bild).interpolation(.none)
                                        .resizable().frame(width: 36, height: 36)
                                }
                                Text(icon.name).font(.system(size: 9)).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .background(gewaehltesIcon?.nummer == icon.nummer ? Color.accentColor.opacity(0.25) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            HStack {
                Spacer()
                Button("Schließen") { zeigeBlatt = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 360)
    }
}
