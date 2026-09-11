import AppKit
import SwiftUI
import TC002Core

/// Waehlt ein Icon aus der Sammlung — ohne Auswahl nennt der Knopf die Handlung
/// „Icon wählen…", mit Auswahl zeigt er Vorschau und Namen des gewaehlten Icons
/// und bleibt anklickbar, um ein anderes zu waehlen; ein Druck oeffnet ein Blatt
/// mit Suche und Raster. Baugleich mit `ZielauswahlView`: derselbe Blattkopf,
/// derselbe „Schließen"-Knopf — die Blaetter der App sollen sich gleich anfuehlen.
///
/// Ein Icon gehoert inhaltlich zum Text, nicht zum Versand — der Knopf steht
/// deshalb bei Text und Vorschau, nicht in der Sendezeile.
struct IconAuswahlView: View {
    @Binding var gewaehltesIcon: Icon?
    let sammlung: Iconsammlung

    @State private var zeigeBlatt = false
    @State private var suche = ""
    /// Das Icon, fuer das gerade die Loesch-Rueckfrage steht — `nil` heisst
    /// keine.
    @State private var zuLoeschen: Icon?
    /// Erzwingt das Neulesen von `sammlung.alle()`, das sonst niemand anstoesst:
    /// die Liste wird bei jedem Zugriff frisch von der Platte gelesen, aber
    /// SwiftUI zeichnet nur neu, wenn sich ein beobachteter Zustand aendert.
    @State private var aktualisierung = 0

    private var gefilterte: [Icon] {
        _ = aktualisierung
        return sammlung.alle().gefiltert(nach: suche)
    }

    var body: some View {
        HStack(spacing: 4) {
            Button { zeigeBlatt = true } label: {
                HStack(spacing: 6) {
                    if let icon = gewaehltesIcon, let bild = NSImage(contentsOf: icon.datei) {
                        Image(nsImage: bild).interpolation(.none)
                            .resizable().frame(width: 16, height: 16)
                        Text(icon.name)
                    } else {
                        Image(systemName: "photo")
                        Text("Icon wählen…")
                    }
                }
            }
            if gewaehltesIcon != nil {
                // Entfernt die Wahl, ohne erst das Blatt zu oeffnen — gedaempft,
                // damit der Hauptknopf (Icon wechseln) im Vordergrund bleibt.
                Button { gewaehltesIcon = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Icon entfernen")
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
                        ZStack(alignment: .topTrailing) {
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

                            // Nur eigene Icons duerfen geloescht werden — mitgelieferte
                            // liegen im App-Bundle, ein Versuch schluege ohnehin fehl.
                            if sammlung.istEigen(icon) {
                                Button { zuLoeschen = icon } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("„\(icon.name)“ löschen")
                                .offset(x: 2, y: -2)
                            }
                        }
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
        .confirmationDialog(
            "„\(zuLoeschen?.name ?? "")“ löschen?",
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            presenting: zuLoeschen
        ) { icon in
            Button("Löschen", role: .destructive) { loeschen(icon) }
        } message: { icon in
            Text("Das Icon „\(icon.name)“ wird endgültig entfernt.")
        }
    }

    private func loeschen(_ icon: Icon) {
        guard (try? sammlung.loeschen(icon)) != nil else { return }
        // War das geloeschte Icon gerade gewaehlt, faellt die Wahl auf „ohne"
        // zurueck — es gibt danach schlicht nichts mehr, worauf sie zeigen koennte.
        if gewaehltesIcon?.nummer == icon.nummer { gewaehltesIcon = nil }
        aktualisierung += 1
    }
}
