import SwiftUI
import TC002Core

struct MalenView: View {
    @Bindable var zustand: AppZustand

    @State private var feld = Pixelfeld()
    @State private var farbe = Color(red: 0, green: 1, blue: 0.4)
    @State private var radierer = false
    @State private var name = "bild"
    @State private var laeuft = false
    @State private var anAlle = false
    /// Die verfuegbare Breite der Malflaeche, von einem GeometryReader in ihrem
    /// Hintergrund gemessen — daraus ergibt sich die Kantenlaenge. Ohne das liefe die
    /// Flaeche bei ihrer festen Breite in einem schmalen Fenster rechts aus dem Bild.
    @State private var flaechenBreite: Double = Double(Pixelfeld.breiteStandard) * 14

    private var kante: Double {
        min(14, max(6, flaechenBreite / Double(feld.breite)))
    }

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ColorPicker("Farbe", selection: $farbe)
                Toggle("Radierer", isOn: $radierer).toggleStyle(.button)
                Button("Leeren") { feld.alleLoeschen() }
                Menu("Icon einfügen") {
                    ForEach(sammlung.alle(), id: \.nummer) { icon in
                        Button(icon.name) { iconEinfuegen(icon) }
                    }
                }
                .disabled(sammlung.alle().isEmpty)
                Spacer()
                TextField("Name", text: $name).frame(width: 120)
                Toggle("an alle", isOn: $anAlle).disabled(zustand.uhren.count < 2)
                Button(laeuft ? "Sende…" : "Senden") { senden() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(laeuft || zustand.ziele(alle: anAlle).isEmpty)
            }
            if zustand.ziele(alle: anAlle).isEmpty {
                Text("Erst unter „Verbindung“ eine Uhr eintragen und abfragen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            malflaeche

            Text("\(feld.alsDrawBefehle().count) Rechtecke — waagrechte Läufe gleicher Farbe werden zusammengefasst.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private var malflaeche: some View {
        Canvas { kontext, _ in
            for y in 0..<feld.hoehe {
                for x in 0..<feld.breite {
                    let r = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                   width: kante - 1, height: kante - 1)
                    let f = feld.farbe(x: x, y: y).flatMap(Color.init(hex:)) ?? Color(white: 0.12)
                    kontext.fill(Path(r), with: .color(f))
                }
            }
        }
        .frame(width: Double(feld.breite) * kante, height: Double(feld.hoehe) * kante)
        .background(Color.black)
        .gesture(DragGesture(minimumDistance: 0).onChanged { wert in
            let x = Int(wert.location.x / kante), y = Int(wert.location.y / kante)
            if radierer { feld.loeschen(x: x, y: y) } else { feld.setzen(x: x, y: y, farbe: farbe.hexWert) }
        })
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { flaechenBreite = geo.size.width }
                    .onChange(of: geo.size.width) { _, neu in flaechenBreite = neu }
            }
        )
    }

    /// Setzt ein 8×8-Icon als Ausgangspunkt ins Feld — senkrecht mittig wie beim
    /// Senden (x: 0, y: 4). Durchsichtige Stellen im Icon lassen das Feld dort
    /// unberuehrt, statt ein schwarzes Rechteck hineinzuradieren.
    private func iconEinfuegen(_ icon: Icon) {
        do {
            let pixel = try sammlung.pixel(fuer: icon)
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let farbe = pixel[y * 8 + x] else { continue }
                    feld.setzen(x: x, y: 4 + y, farbe: farbe)
                }
            }
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func senden() {
        laeuft = true
        let frame = Frame(draw: feld.alsDrawBefehle())
        let anzeigenName = name
        Task { await zustand.senden(frame, als: anzeigenName, anAlle: anAlle); laeuft = false }
    }
}
