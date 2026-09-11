import AppKit
import SwiftUI
import TC002Core

/// Waagrechte Ausrichtung des Textes innerhalb der verfuegbaren Breite (52 Pixel
/// ohne Icon, ab Spalte 10 mit Icon).
enum SendenHAusrichtung: String, CaseIterable, Identifiable {
    case links, mittig, rechts
    var id: String { rawValue }
}

/// Senkrechte Ausrichtung innerhalb der 16 Zeilen, gerechnet ueber die tatsaechlich
/// gesetzte Hoehe (`Textraster.hoehe`), nicht die Schriftgroesse.
enum SendenVAusrichtung: String, CaseIterable, Identifiable {
    case oben, mittig, unten
    var id: String { rawValue }
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

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt — bei
    /// mehreren Zieluhren zaehlt jede davon.
    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele().flatMap { zustand.bekannteAnzeigen[$0.id] ?? [] })
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
            formatleiste
            HStack {
                TextField("Text", text: $text)
                IconAuswahlView(gewaehltesIcon: $gewaehltesIcon, sammlung: sammlung)
            }

            VStack(alignment: .leading) {
                VorschauView(feld: feld, kantenlaenge: 12, icon: gewaehltesIcon?.datei)
                if !passt {
                    Label("Der Text ist breiter als das Display und wird abgeschnitten.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack(alignment: .bottom, spacing: 16) {
                MeldungsplatzWahl(platz: $platz, belegtePlaetze: belegtePlaetze)
                    .help("Blättert nur zwischen belegten Plätzen, wenn der Seitenwechsel unter „Verbindung“ nicht auf „kein Wechsel“ steht.")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dauer (Sek.)").font(.caption).foregroundStyle(.secondary)
                    TextField("Uhr entscheidet", text: $dauerText).frame(width: 100)
                }
                Spacer()
                ZielauswahlView(zustand: zustand)
                Button(laeuft ? "Sende…" : "Senden") { senden() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(laeuft || zustand.ziele().isEmpty)
            }
            if zustand.ziele().isEmpty {
                Text("Erst unter „Verbindung“ eine Uhr eintragen und abfragen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    /// Alles, was den Text betrifft, in einer Zeile ueber dem Eingabefeld — wie in
    /// einem Textprogramm gewohnt, statt zwischen den Sendeoptionen verstreut.
    private var formatleiste: some View {
        HStack(spacing: 10) {
            Picker("Schriftart", selection: $schrift) {
                ForEach(Self.schriftarten, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden().frame(width: 150)
            .help("Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")

            Stepper("\(Int(groesse))", value: $groesse, in: 6...16).frame(width: 80)
                .help("Schriftgröße")

            Divider().frame(height: 18)

            formatKnopf(icon: "bold", hilfe: "Fett", aktiv: fett) { fett.toggle() }

            Divider().frame(height: 18)

            HStack(spacing: 2) {
                ausrichtungsKnopf(.links, aktuell: $horizontal, icon: "text.alignleft", hilfe: "Links ausrichten")
                ausrichtungsKnopf(.mittig, aktuell: $horizontal, icon: "text.aligncenter", hilfe: "Mittig ausrichten")
                ausrichtungsKnopf(.rechts, aktuell: $horizontal, icon: "text.alignright", hilfe: "Rechts ausrichten")
            }
            HStack(spacing: 2) {
                ausrichtungsKnopf(.oben, aktuell: $vertikal, icon: "align.vertical.top", hilfe: "Oben ausrichten")
                ausrichtungsKnopf(.mittig, aktuell: $vertikal, icon: "align.vertical.center", hilfe: "Mittig ausrichten")
                ausrichtungsKnopf(.unten, aktuell: $vertikal, icon: "align.vertical.bottom", hilfe: "Unten ausrichten")
            }

            Divider().frame(height: 18)

            ColorPicker("Farbe", selection: $farbe).labelsHidden()
                .help("Farbe")

            Spacer()
        }
    }

    /// Ein einzelner Umschaltknopf einer Ausrichtungsgruppe — Symbol statt Wort,
    /// mit Einblendtext. Als eigene Buttons statt eines segmentierten Pickers,
    /// damit jeder Knopf sein eigenes `.help(...)` tragen kann.
    private func ausrichtungsKnopf<T: Equatable>(_ wert: T, aktuell: Binding<T>, icon: String, hilfe: String) -> some View {
        formatKnopf(icon: icon, hilfe: hilfe, aktiv: aktuell.wrappedValue == wert) { aktuell.wrappedValue = wert }
    }

    private func formatKnopf(icon: String, hilfe: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: icon).frame(width: 22, height: 20)
        }
        .buttonStyle(.borderless)
        .background(aktiv ? Color.accentColor.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(hilfe)
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
        Task { await zustand.senden(frame, als: anzeigenName); laeuft = false }
    }
}
