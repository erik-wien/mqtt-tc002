import SwiftUI
import TC002Core

struct MalenView: View {
    @Bindable var zustand: AppZustand

    @State private var feld = Pixelfeld()
    @State private var farbe = "#00FF66"
    @State private var radierer = false
    @State private var name = "bild"
    @State private var laeuft = false
    @State private var anAlle = false

    private let kante: Double = 14
    private let farben = ["#FFFFFF", "#00FF66", "#FFCC00", "#FF3030", "#4285F4", "#FF6400", "#00E5FF", "#FF6FB5"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ForEach(farben, id: \.self) { f in
                    Button { farbe = f; radierer = false } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: f) ?? .gray)
                            .frame(width: 22, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .stroke(farbe == f && !radierer ? Color.primary : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
                Toggle("Radierer", isOn: $radierer).toggleStyle(.button)
                Button("Leeren") { feld.alleLoeschen() }
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
            if radierer { feld.loeschen(x: x, y: y) } else { feld.setzen(x: x, y: y, farbe: farbe) }
        })
    }

    private func senden() {
        laeuft = true
        let frame = Frame(draw: feld.alsDrawBefehle())
        let anzeigenName = name
        Task { await zustand.senden(frame, als: anzeigenName, anAlle: anAlle); laeuft = false }
    }
}
