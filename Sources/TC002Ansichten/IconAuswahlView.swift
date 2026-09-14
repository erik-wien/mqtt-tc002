import SwiftUI
import TC002Core

/// Waehlt ein Icon aus der Sammlung — ohne Auswahl nennt der Knopf die Handlung
/// „Icon wählen…", mit Auswahl zeigt er Vorschau und Namen des gewaehlten Icons
/// und bleibt anklickbar, um ein anderes zu waehlen; ein Druck oeffnet ein Blatt
/// mit Suche und Raster. Baugleich mit `ZielauswahlView`: derselbe Blattkopf,
/// derselbe „Schließen"-Knopf — die Blaetter der App sollen sich gleich anfuehlen.
///
/// Ein Icon gehoert inhaltlich zum Text, nicht zum Versand — der Knopf steht
/// deshalb bei den uebrigen Formatierungsreglern im Inspektor (SendenView.swift),
/// nicht in der Sendezeile.
struct IconAuswahlView: View {
    @Binding var gewaehltesIcon: Icon?
    /// Alle Bestaende, aus denen gewaehlt werden darf — heute die 8×8 und die
    /// 16×16. Sie stehen im selben Raster nebeneinander: Beim Waehlen zaehlt,
    /// wie das Icon aussieht, nicht in welchem Ordner es liegt. Woher es
    /// stammt, weiss es selbst (`Icon.kante`), und das Loeschen fragt danach.
    let sammlungen: [Iconsammlung]

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
        return sammlungen.flatMap { $0.alle() }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .gefiltert(nach: suche)
    }

    var body: some View {
        HStack(spacing: 4) {
            Button { zeigeBlatt = true } label: {
                HStack(spacing: 6) {
                    if let icon = gewaehltesIcon {
                        Rasterbild(datei: icon.datei, breite: icon.kante, hoehe: icon.kante,
                                   kante: 16 / Double(icon.kante))
                        Text(icon.name)
                    } else {
                        Image(systemName: "photo")
                        Text("Icon wählen…")
                    }
                }
            }
            .knopfBefehl()
            if gewaehltesIcon != nil {
                // Entfernt die Wahl, ohne erst das Blatt zu oeffnen — gedaempft,
                // damit der Hauptknopf (Icon wechseln) im Vordergrund bleibt.
                //
                // `.tint(.secondary)` und nicht nur ein graues Symbol: Unter
                // iPadOS faerbt der randlose Stil die Beschriftung in der
                // Akzentfarbe, und ein blaues `x` neben einem blauen Namen
                // las sich als Verweis mit Schliessknopf. Gewaehlt ist aber
                // ein **Wert**, kein Verweis — der Name steht deshalb dunkel
                // im grauen Kaestchen des Knopfes daneben (ein Chip, samt
                // Vorschaubild), und das Entfernen ist das gedaempfte Zeichen
                // dahinter. Zwei Elemente und nicht ein Chip mit `x` darin:
                // Wechseln und Entfernen brauchen je eine eigene
                // Trefferflaeche.
                Button { gewaehltesIcon = nil } label: {
                    Label(lok("Icon entfernen"), systemImage: "xmark.circle.fill")
                }
                .namensichtbarAmIPad()
                .buttonStyle(.borderless)
                .tint(.secondary)
                .help(lok("Icon entfernen"))
            }
        }
        .sheet(isPresented: $zeigeBlatt) { blatt }
    }

    private var blatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon wählen").font(.headline)
            TextField("Suchen", text: $suche)
                .eingabefeld()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    Button { gewaehltesIcon = nil } label: { Text("ohne").font(.caption) }
                        .knopfBefehl()
                    ForEach(gefilterte, id: \.kennung) { icon in
                        ZStack(alignment: .topTrailing) {
                            Button { gewaehltesIcon = icon } label: {
                                VStack(spacing: 2) {
                                    // Beide Groessen gleich gross zeigen: Ein
                                    // 16×16 ist nicht das doppelt so grosse
                                    // Bild, sondern das feinere.
                                    Rasterbild(datei: icon.datei, breite: icon.kante, hoehe: icon.kante,
                                               kante: 36 / Double(icon.kante))
                                    // Dasselbe Zeichen wie in der
                                    // Bestandsliste, nur gibt es hier keine
                                    // Groessenzeile — also neben den Namen.
                                    // **Nicht** ins Bildchen: Bei 36 Punkten
                                    // Kantenlaenge verdeckte es das Motiv.
                                    HStack(spacing: 2) {
                                        if Bildraster.bewegt(icon.datei) {
                                            Image(systemName: "play.fill")
                                                .accessibilityLabel(Text("bewegt"))
                                        }
                                        Text(icon.name).lineLimit(1)
                                    }
                                    .font(.system(size: 9))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                            .background(gewaehltesIcon?.kennung == icon.kennung ? Color.accentColor.opacity(0.25) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            Button { zuLoeschen = icon } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(lokf("„%@“ löschen", icon.name))
                            .offset(x: 2, y: -2)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Schließen") { zeigeBlatt = false }
                    .knopfHaupthandlung()
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
            Text(lokf("Das Icon „%@“ wird endgültig entfernt.", icon.name))
        }
    }

    private func loeschen(_ icon: Icon) {
        // Jede Sammlung raeumt nur ihren eigenen Ordner (`istEigen`) — welche
        // es ist, entscheidet also sie selbst und nicht diese Ansicht.
        guard let heimat = sammlungen.first(where: { $0.istEigen(icon) }),
              (try? heimat.loeschen(icon)) != nil else { return }
        // War das geloeschte Icon gerade gewaehlt, faellt die Wahl auf „ohne"
        // zurueck — es gibt danach schlicht nichts mehr, worauf sie zeigen koennte.
        if gewaehltesIcon?.kennung == icon.kennung { gewaehltesIcon = nil }
        aktualisierung += 1
    }
}
