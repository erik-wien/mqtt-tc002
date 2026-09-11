import SwiftUI
import TC002Core

/// 8×8-Editor fuer eigene Icons. Dasselbe Malprinzip wie der grosse Editor, nur
/// kleiner und mit Ablage: was hier gesichert wird, steht unter „Senden" zur Wahl.
struct IconEditorView: View {
    @Bindable var zustand: AppZustand

    @State private var pixel = [String?](repeating: nil, count: 64)
    @State private var farbe = Color(red: 1, green: 1, blue: 1)
    @State private var radiert = false
    @State private var nummer = ""
    @State private var name = ""
    @State private var vorhandene: [Icon] = []
    @State private var meldung: String?
    @State private var lametricNummer = ""
    @State private var laedt = false

    private let kante: Double = 28

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    private var hexFarbe: String {
        let f = NSColor(farbe).usingColorSpace(.sRGB) ?? .white
        return String(format: "#%02X%02X%02X",
                      Int(f.redComponent * 255), Int(f.greenComponent * 255), Int(f.blueComponent * 255))
    }

    var body: some View {
        HSplitView {
            malflaeche
            seitenleiste
        }
    }

    private var malflaeche: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon malen").font(.headline)

            Canvas { kontext, _ in
                for y in 0..<8 {
                    for x in 0..<8 {
                        let feld = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                          width: kante - 1, height: kante - 1)
                        let p = pixel[y * 8 + x]
                        kontext.fill(Path(feld), with: .color(p.flatMap(Color.init(hex:)) ?? .black))
                    }
                }
            }
            .frame(width: kante * 8, height: kante * 8)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
            .gesture(DragGesture(minimumDistance: 0).onChanged { wert in
                let x = Int(wert.location.x / kante), y = Int(wert.location.y / kante)
                guard (0..<8).contains(x), (0..<8).contains(y) else { return }
                pixel[y * 8 + x] = radiert ? nil : hexFarbe
            })

            HStack {
                ColorPicker("Farbe", selection: $farbe).labelsHidden()
                Toggle("Radieren", isOn: $radiert).toggleStyle(.button)
                Button("Alles löschen") { pixel = [String?](repeating: nil, count: 64) }
                Spacer()
            }

            HStack {
                TextField("Nummer", text: $nummer).frame(width: 110)
                TextField("Name", text: $name).frame(width: 180)
                Button("Sichern") { sichern() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(nummer.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let meldung {
                Text(meldung).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var seitenleiste: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorhandene Icons").font(.headline)
            HStack {
                TextField("LaMetric-Nummer", text: $lametricNummer)
                    .frame(width: 140)
                    .onSubmit { nachladen() }
                Button(laedt ? "Hole…" : "Nachladen") { nachladen() }
                    .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Nummer von developer.lametric.com — das Icon landet bei den eigenen.")
                .font(.caption).foregroundStyle(.secondary)
            List(vorhandene, id: \.nummer) { icon in
                HStack {
                    if let bild = NSImage(contentsOf: icon.datei) {
                        Image(nsImage: bild).interpolation(.none)
                            .resizable().frame(width: 24, height: 24)
                    }
                    VStack(alignment: .leading) {
                        Text(icon.name)
                        Text(icon.nummer).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { oeffnen(icon) }
                .contextMenu {
                    Button("Öffnen") { oeffnen(icon) }
                    Button("Löschen", role: .destructive) { loeschen(icon) }
                }
            }
        }
        .padding()
        .frame(minWidth: 240)
        .onAppear { vorhandene = sammlung.alle() }
    }

    /// Laedt ein Icon zurueck ins Raster. Groesseres wird auf 8×8 gerechnet — die
    /// Uhr zeigt ohnehin nur 8×8.
    private func oeffnen(_ icon: Icon) {
        guard let bild = NSImage(contentsOf: icon.datei),
              let cg = bild.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            meldung = "Dieses Icon lässt sich nicht öffnen."
            return
        }
        var bytes = [UInt8](repeating: 0, count: 64 * 4)
        guard let kontext = CGContext(data: &bytes, width: 8, height: 8, bitsPerComponent: 8,
                                      bytesPerRow: 8 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        kontext.interpolationQuality = .none
        kontext.draw(cg, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        // CGContext hat den Ursprung unten links, das Raster oben links.
        for y in 0..<8 {
            for x in 0..<8 {
                let q = ((7 - y) * 8 + x) * 4
                let hex = String(format: "#%02X%02X%02X", Int(bytes[q]), Int(bytes[q + 1]), Int(bytes[q + 2]))
                pixel[y * 8 + x] = hex == "#000000" ? nil : hex
            }
        }
        nummer = icon.nummer
        name = icon.name
        meldung = "\(icon.name) geöffnet."
    }

    private func sichern() {
        let n = nummer.trimmingCharacters(in: .whitespaces)
        do {
            let icon = try sammlung.sichern(nummer: n, name: name.isEmpty ? n : name, pixel: pixel)
            vorhandene = sammlung.alle()
            meldung = "\(icon.name) gesichert."
            zustand.log("Icon gesichert: \(icon.name)")
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func nachladen() {
        let n = lametricNummer.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        laedt = true
        Task.detached {
            // holen() wartet bis zu zehn Sekunden auf LaMetric — nicht auf dem
            // Hauptthread, sonst steht das Fenster so lange.
            let sammlung = Iconsammlung(schreibordner: Iconordner.eigene,
                                        leseordner: [Iconordner.mitgeliefert])
            do {
                let icon = try sammlung.holen(nummer: n)
                let liste = sammlung.alle()
                await MainActor.run {
                    vorhandene = liste
                    lametricNummer = ""
                    meldung = "\(icon.name) von LaMetric geholt."
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

    private func loeschen(_ icon: Icon) {
        do {
            try sammlung.loeschen(icon)
            vorhandene = sammlung.alle()
            meldung = "\(icon.name) gelöscht."
        } catch {
            meldung = "Mitgelieferte Icons lassen sich nicht löschen."
        }
    }
}
