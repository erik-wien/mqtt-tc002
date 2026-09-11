import SwiftUI
import TC002Core

struct SendenView: View {
    @Bindable var zustand: AppZustand

    @State private var name = "notiz"
    @State private var text = "Hallo"
    @State private var farbe = "#00FF66"
    @State private var schrift = "Menlo"
    @State private var groesse = 11.0
    @State private var gewaehltesIcon: Icon?
    @State private var laeuft = false
    @State private var anAlle = false

    private let farben = ["#FFFFFF", "#00FF66", "#FFCC00", "#FF3030", "#4285F4", "#FF6400", "#00E5FF", "#FF6FB5"]

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    /// Vorschau und Sendung entstehen aus demselben Feld.
    private var feld: Pixelfeld {
        var f = Pixelfeld()
        let textX = gewaehltesIcon == nil ? 1 : 10
        Textraster.rastern(text, schrift: schrift, groesse: groesse,
                           farbe: farbe, x: textX, y: 3, feld: &f)
        return f
    }

    /// Gerastert wird ohne Icon ab x: 1, mit Icon ab x: 10 — die Grenze ist also die
    /// Displaybreite minus dem linken Rand, nicht die Displaybreite selbst.
    private var passt: Bool {
        Textraster.breite(text, schrift: schrift, groesse: groesse) <= (gewaehltesIcon == nil ? 51 : 42)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Name der Anzeige", text: $name).frame(width: 160)
                TextField("Text", text: $text)
                Picker("", selection: $farbe) {
                    ForEach(farben, id: \.self) { f in
                        Text(f).tag(f).foregroundStyle(Color(hex: f) ?? .primary)
                    }
                }
                .labelsHidden().frame(width: 120)
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading) {
                    VorschauView(feld: feld)
                    if !passt {
                        Label("Der Text ist breiter als das Display und wird abgeschnitten.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                iconAuswahl
            }

            HStack {
                Toggle("an alle Uhren", isOn: $anAlle)
                    .disabled(zustand.uhren.count < 2)
                Button(laeuft ? "Sende…" : "Senden") { senden() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(laeuft || zustand.ziele(alle: anAlle).isEmpty)
                if zustand.ziele(alle: anAlle).isEmpty {
                    Text("Erst unter „Verbindung“ eine Uhr eintragen und abfragen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Spacer()
        }
        .padding()
    }

    private var iconAuswahl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Icon").font(.headline)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 6) {
                    Button { gewaehltesIcon = nil } label: { Text("ohne").font(.caption) }
                        .buttonStyle(.bordered)
                    ForEach(sammlung.alle(), id: \.nummer) { icon in
                        Button { gewaehltesIcon = icon } label: {
                            VStack(spacing: 2) {
                                if let bild = NSImage(contentsOf: icon.datei) {
                                    Image(nsImage: bild).interpolation(.none)
                                        .resizable().frame(width: 32, height: 32)
                                }
                                Text(icon.name).font(.system(size: 9)).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(3)
                        .background(gewaehltesIcon?.nummer == icon.nummer ? Color.accentColor.opacity(0.25) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .frame(width: 220, height: 160)
        }
    }

    private func senden() {
        laeuft = true
        var frame = Frame(draw: feld.alsDrawBefehle())
        if let icon = gewaehltesIcon {
            // Ohne Meldung ginge die Anzeige bei unlesbarer Icondatei kommentarlos
            // ohne das gewaehlte Icon hinaus.
            do {
                frame.bilder = [Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4)]
            } catch {
                zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                laeuft = false
                return
            }
        }
        let anzeigenName = name
        Task { await zustand.senden(frame, als: anzeigenName, anAlle: anAlle); laeuft = false }
    }
}
