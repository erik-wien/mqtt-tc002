import AppKit
import SwiftUI
import TC002Core

/// Waagrechte Ausrichtung des Textes innerhalb der verfuegbaren Breite (52 Pixel
/// ohne Icon, ab Spalte 10 mit Icon).
enum SendenHAusrichtung: String, CaseIterable, Identifiable {
    case links, mittig, rechts
    var id: String { rawValue }
    var beschriftung: String {
        switch self {
        case .links: return "Links"
        case .mittig: return "Mittig"
        case .rechts: return "Rechts"
        }
    }
}

/// Senkrechte Ausrichtung innerhalb der 16 Zeilen, gerechnet ueber die tatsaechlich
/// gesetzte Hoehe (`Textraster.hoehe`), nicht die Schriftgroesse.
enum SendenVAusrichtung: String, CaseIterable, Identifiable {
    case oben, mittig, unten
    var id: String { rawValue }
    var beschriftung: String {
        switch self {
        case .oben: return "Oben"
        case .mittig: return "Mittig"
        case .unten: return "Unten"
        }
    }
}

struct SendenView: View {
    @Bindable var zustand: AppZustand

    @State private var platz = 1
    @State private var dauerText = ""
    @State private var text = "Hallo"
    @State private var farbe = Color(red: 0, green: 1, blue: 0.4)
    @State private var schrift = "Menlo"
    @State private var groesse = 11.0
    @State private var fett = false
    @State private var horizontal: SendenHAusrichtung = .links
    @State private var vertikal: SendenVAusrichtung = .oben
    @State private var gewaehltesIcon: Icon?
    @State private var laeuft = false
    @State private var anAlle = false
    @State private var suche = ""

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt — bei
    /// „an alle Uhren“ zaehlt jede Zieluhr, sonst nur die aktive.
    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele(alle: anAlle).flatMap { zustand.bekannteAnzeigen[$0.id] ?? [] })
        return Set((1...MeldungsplatzWahl.anzahl).filter { namen.contains(MeldungsplatzWahl.name(fuer: $0)) })
    }

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann in der
    /// Nutzlast wie bisher.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Einmal ermittelt statt bei jedem Neuaufbau — NSFontManager befragt das System.
    private static let schriftarten = NSFontManager.shared.availableFontFamilies.sorted()

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    /// Beginn und Breite der Flaeche, in der der Text ausgerichtet wird: ohne Icon
    /// die volle Displaybreite, mit Icon erst ab der Spalte, an der das Icon endet.
    private var flaecheX: Int { gewaehltesIcon == nil ? 0 : 10 }
    private var flaecheBreite: Int { gewaehltesIcon == nil ? Pixelfeld.breiteStandard : Pixelfeld.breiteStandard - 10 }

    private var textBreite: Int { Textraster.breite(text, schrift: schrift, groesse: groesse, fett: fett) }
    private var textHoehe: Int { Textraster.hoehe(text, schrift: schrift, groesse: groesse, fett: fett) }

    private var textX: Int {
        switch horizontal {
        case .links: return flaecheX
        case .mittig: return flaecheX + max(0, (flaecheBreite - textBreite) / 2)
        case .rechts: return flaecheX + max(0, flaecheBreite - textBreite)
        }
    }

    private var textY: Int {
        switch vertikal {
        case .oben: return 0
        case .mittig: return max(0, (Pixelfeld.hoeheStandard - textHoehe) / 2)
        case .unten: return max(0, Pixelfeld.hoeheStandard - textHoehe)
        }
    }

    /// Vorschau und Sendung entstehen aus demselben Feld.
    private var feld: Pixelfeld {
        var f = Pixelfeld()
        Textraster.rastern(text, schrift: schrift, groesse: groesse,
                           farbe: farbe.hexWert, x: textX, y: textY, feld: &f, fett: fett)
        return f
    }

    private var passt: Bool { textBreite <= flaecheBreite }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Text", text: $text)
                ColorPicker("Farbe", selection: $farbe)
            }

            HStack(alignment: .bottom, spacing: 16) {
                MeldungsplatzWahl(platz: $platz, belegtePlaetze: belegtePlaetze)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dauer (Sek.)").font(.caption).foregroundStyle(.secondary)
                    TextField("Uhr entscheidet", text: $dauerText).frame(width: 100)
                }
                Spacer()
            }
            Label("Blättert nur zwischen belegten Plätzen, wenn der Seitenwechsel unter „Verbindung“ nicht auf „kein Wechsel“ steht.",
                  systemImage: "arrow.left.arrow.right")
                .font(.footnote).foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schriftart").font(.caption).foregroundStyle(.secondary)
                    Picker("Schriftart", selection: $schrift) {
                        ForEach(Self.schriftarten, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().frame(width: 170)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Größe").font(.caption).foregroundStyle(.secondary)
                    Stepper("\(Int(groesse))", value: $groesse, in: 6...16).frame(width: 90)
                }
                Toggle("Fett", isOn: $fett).toggleStyle(.button)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Waagrecht").font(.caption).foregroundStyle(.secondary)
                    Picker("Waagrecht", selection: $horizontal) {
                        ForEach(SendenHAusrichtung.allCases) { Text($0.beschriftung).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Senkrecht").font(.caption).foregroundStyle(.secondary)
                    Picker("Senkrecht", selection: $vertikal) {
                        ForEach(SendenVAusrichtung.allCases) { Text($0.beschriftung).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
                Spacer()
            }
            Text("Bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")
                .font(.footnote).foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading) {
                    VorschauView(feld: feld, icon: gewaehltesIcon?.datei)
                    if !passt {
                        Label("Der Text ist breiter als das Display und wird abgeschnitten.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                iconAuswahl
            }
            .frame(maxHeight: .infinity)

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
        }
        .padding()
    }

    private var gefilterte: [Icon] { sammlung.alle().gefiltert(nach: suche) }

    private var iconAuswahl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Icon").font(.headline)
            TextField("Suchen", text: $suche)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 6) {
                    Button { gewaehltesIcon = nil } label: { Text("ohne").font(.caption) }
                        .buttonStyle(.bordered)
                    ForEach(gefilterte, id: \.nummer) { icon in
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
        }
        .frame(minWidth: 220, maxWidth: 220, maxHeight: .infinity, alignment: .top)
    }

    private func senden() {
        laeuft = true
        var frame = Frame(draw: feld.alsDrawBefehle(), dauer: dauer)
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
        let anzeigenName = MeldungsplatzWahl.name(fuer: platz)
        Task { await zustand.senden(frame, als: anzeigenName, anAlle: anAlle); laeuft = false }
    }
}
