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

/// Der Weg, auf dem der Text zur Uhr kommt. Drei Wege mit je eigener Luecke:
/// eigenes Raster kann Umlaute und jede Schriftart, aber nicht scrollen; der
/// Geraeteweg scrollt, kennt aber nur die Gerätschrift ohne Umlaute; die
/// Laufschrift schafft beides zugleich, indem sie den scrollenden Lauf selbst
/// als animiertes GIF rastert (siehe `docs/tc002-protokoll.md` §4.2a).
enum SendeWeg: String, CaseIterable, Identifiable {
    case pixel, geraet, laufschrift
    var id: String { rawValue }
}

struct SendenView: View {
    @Bindable var zustand: AppZustand

    /// Ueberlebt den Neustart — Einstellungen dieser einen Ansicht, kein
    /// geteilter Zustand, deshalb @AppStorage statt des Umwegs ueber AppZustand.
    @AppStorage("senden.meldungsplatz") private var platz = 1
    @AppStorage("senden.dauer") private var dauerText = ""
    @AppStorage("senden.text") private var text = "Hallo"
    /// Als "#RRGGBB": @AppStorage kennt keine Color. `farbe` unten wandelt fuer
    /// den ColorPicker um, `Textraster.rastern` nimmt den Hex-Wert ohnehin direkt.
    @AppStorage("senden.farbe") private var farbeHex = "#00FF66"
    @AppStorage("senden.schriftart") private var schrift = "Menlo"
    @AppStorage("senden.groesse") private var groesse = 11.0
    @AppStorage("senden.fett") private var fett = false
    @AppStorage("senden.horizontal") private var horizontal: SendenHAusrichtung = .links
    @AppStorage("senden.vertikal") private var vertikal: SendenVAusrichtung = .oben
    @AppStorage("senden.weg") private var weg: SendeWeg = .pixel
    /// Nur fuer den Weg „als Laufschrift": Pixel Versatz je Einzelbild und
    /// Standzeit je Einzelbild in Sekunden.
    @AppStorage("senden.laufschrittweite") private var laufschriftSchritt = 1
    @AppStorage("senden.laufdauer") private var laufschriftDauer = 0.08
    /// Nur die Nummer wird gesichert, kein Pfad — der bricht, sobald ein Icon
    /// zwischen mitgeliefert und eigenen wandert. `gewaehltesIcon` wird daraus
    /// einmalig beim Start nachgeschlagen; eine verschwundene Nummer ergibt
    /// kommentarlos „kein Icon“.
    @AppStorage("senden.icon") private var iconNummer = ""
    @State private var gewaehltesIcon: Icon?
    @State private var laeuft = false
    /// Die Einzelbilder der Laufschrift — einmal je Aenderung an Text oder
    /// Formatierung berechnet (`.task(id:)`), nicht bei jedem Neuzeichnen der
    /// mit `TimelineView` laufenden Vorschau. Fuellt zugleich die Groessenanzeige.
    @State private var laufschriftFrames: [Bildraster.Einzelbild] = []

    init(zustand: AppZustand) {
        self.zustand = zustand
        let nummer = UserDefaults.standard.string(forKey: "senden.icon") ?? ""
        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
        _gewaehltesIcon = State(initialValue: nummer.isEmpty ? nil : sammlung.alle().first { $0.nummer == nummer })
    }

    /// Fuer den ColorPicker: liest/schreibt `farbeHex` als `Color`.
    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

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
                           farbe: farbeHex, x: textX, y: textY, feld: &f, fett: fett)
        return f
    }

    private var passt: Bool { textBreite <= flaecheBreite }

    /// `align`/`valign` fuer den Geraeteweg — dieselbe Wahl aus der Formatleiste,
    /// nur in den Namen, die das Geraet fuer `text` erwartet (§4.3).
    private var geraeteAusrichtung: String {
        switch horizontal { case .links: "left"; case .mittig: "center"; case .rechts: "right" }
    }
    private var geraeteVertikal: String {
        switch vertikal { case .oben: "top"; case .mittig: "middle"; case .unten: "bottom" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Weg", selection: $weg) {
                Text("als Pixel (Umlaute, scrollt nicht)").tag(SendeWeg.pixel)
                Text("vom Gerät setzen (scrollt, keine Umlaute)").tag(SendeWeg.geraet)
                Text("als Laufschrift (scrollt, mit Umlauten)").tag(SendeWeg.laufschrift)
            }
            .pickerStyle(.segmented).labelsHidden()

            if weg == .laufschrift {
                HStack(spacing: 16) {
                    Stepper("Schrittweite: \(laufschriftSchritt)", value: $laufschriftSchritt, in: 1...3)
                        .help("Pixel Versatz je Einzelbild — mehr ist gröber, aber ein kürzeres GIF.")
                    Stepper("Bilddauer: \(String(format: "%.2f", laufschriftDauer)) s",
                           value: $laufschriftDauer, in: 0.02...0.5, step: 0.01)
                        .help("Standzeit je Einzelbild")
                }
            }

            formatleiste
            HStack {
                TextField("Text", text: $text)
                IconAuswahlView(gewaehltesIcon: $gewaehltesIcon, sammlung: sammlung)
            }

            VStack(alignment: .leading, spacing: 4) {
                VorschauView(feld: feld, kantenlaenge: 12, icon: gewaehltesIcon?.datei,
                            laufschriftBilder: weg == .laufschrift ? laufschriftFrames : nil)
                switch weg {
                case .pixel:
                    if !passt {
                        Label("Der Text ist breiter als das Display und wird abgeschnitten.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                case .geraet:
                    // Wir rastern hier weiterhin selbst — die Vorschau kann also nur eine
                    // Annaeherung sein, nicht das, was am Geraet tatsaechlich erscheint:
                    // die Uhr setzt diesen Text mit ihrer eigenen Schrift und ohne Umlaute.
                    Label("Nur eine Annäherung — die Uhr setzt diesen Text selbst und zeigt ihn anders, vor allem fehlen Umlaute. Langer Text läuft durch; das Tempo bestimmt „Scrolltempo“ unter „Verbindung“.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                case .laufschrift:
                    // Zu langer Text ist hier kein Fehler, sondern der Sinn der Sache —
                    // stattdessen zeigen, worauf man sich einlaesst: niemand weiss, wo
                    // die Uhr bei der Nutzlastgroesse aussteigt (§4.2a).
                    Label("\(laufschriftFrames.count) Einzelbilder, \(text.count) Zeichen — wo die Größengrenze der Uhr liegt, ist offen (Gerätereferenz, §4.2a).",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                    if text.count > 100_000 {
                        Label("Sehr langer Text — das ergibt eine sehr große Nutzlast, an der die Uhr möglicherweise stumm bleibt.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
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
        .onChange(of: gewaehltesIcon) { _, neu in iconNummer = neu?.nummer ?? "" }
        .task(id: laufschriftSchluessel) {
            guard weg == .laufschrift else { return }
            laufschriftFrames = Textraster.laufschriftEinzelbilder(
                text, schrift: schrift, groesse: groesse, fett: fett, farbe: farbeHex,
                schrittweite: laufschriftSchritt, bilddauer: laufschriftDauer)
        }
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhaengt — als `.task(id:)`-
    /// Schluessel, damit die (nicht ganz billige) Berechnung nur bei einer
    /// tatsaechlichen Aenderung neu laeuft, nicht bei jedem Bild der laufenden
    /// Vorschau.
    private var laufschriftSchluessel: String {
        "\(weg)|\(text)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(laufschriftSchritt)|\(laufschriftDauer)"
    }

    /// Alles, was den Text betrifft, in einer eigenen Leiste ueber dem Eingabefeld
    /// — wie in einem Textprogramm gewohnt, statt zwischen den Sendeoptionen
    /// verstreut. Systemmaterial statt fest eingetragener Farben, damit die
    /// Leiste in hell und dunkel gleich stimmig aussieht.
    private var formatleiste: some View {
        HStack(spacing: 10) {
            Picker("Schriftart", selection: $schrift) {
                ForEach(Self.schriftarten, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden().frame(width: 150)
            .disabled(weg == .geraet)
            .help(weg == .geraet ? "Gilt nur beim eigenen Raster — die Uhr setzt ihren Text in ihrer eigenen Schrift."
                                 : "Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")

            Stepper("\(Int(groesse))", value: $groesse, in: 6...16).frame(width: 80)
                .help("Schriftgröße")

            formatKnopf(icon: "bold", hilfe: weg == .geraet ? "Gilt nur beim eigenen Raster" : "Fett",
                       aktiv: fett, gesperrt: weg == .geraet) { fett.toggle() }

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

            ColorPicker("Farbe", selection: farbe).labelsHidden()
                .help("Farbe")

            Spacer()
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Ein einzelner Umschaltknopf einer Ausrichtungsgruppe — Symbol statt Wort,
    /// mit Einblendtext. Als eigene Buttons statt eines segmentierten Pickers,
    /// damit jeder Knopf sein eigenes `.help(...)` tragen kann.
    private func ausrichtungsKnopf<T: Equatable>(_ wert: T, aktuell: Binding<T>, icon: String, hilfe: String) -> some View {
        formatKnopf(icon: icon, hilfe: hilfe, aktiv: aktuell.wrappedValue == wert) { aktuell.wrappedValue = wert }
    }

    private func formatKnopf(icon: String, hilfe: String, aktiv: Bool, gesperrt: Bool = false,
                             aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: icon).frame(width: 22, height: 20)
        }
        .buttonStyle(.borderless)
        .disabled(gesperrt)
        .background(aktiv ? Color.accentColor.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(hilfe)
    }

    /// Baut den Textblock fuer den Geraeteweg: Farbe und Ausrichtung aus der
    /// Formatleiste, Groesse aus dem Groesse-Stepper — Schriftart und Fett
    /// gelten hier nicht, die Uhr setzt ihre eigene Schrift.
    private var textblock: Textblock {
        var t = Textblock(inhalt: text)
        t.schrifthoehe = Int(groesse)
        t.x = flaecheX
        t.y = 0
        t.farbe = farbeHex
        t.ausrichtung = geraeteAusrichtung
        t.vertikal = geraeteVertikal
        t.flaeche = [flaecheX, 0, flaecheBreite, Pixelfeld.hoeheStandard]
        return t
    }

    private func senden() {
        laeuft = true
        var frame: Frame
        switch weg {
        case .pixel:
            frame = Frame(draw: feld.alsDrawBefehle(), dauer: dauer)
        case .geraet:
            frame = Frame(texte: [textblock], dauer: dauer)
        case .laufschrift:
            do {
                let uri = try Textraster.laufschrift(text, schrift: schrift, groesse: groesse, fett: fett,
                                                     farbe: farbeHex, schrittweite: laufschriftSchritt,
                                                     bilddauer: laufschriftDauer)
                frame = Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: dauer)
            } catch {
                zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                laeuft = false
                return
            }
        }
        if let icon = gewaehltesIcon {
            // Ohne Meldung ginge die Anzeige bei unlesbarer Icondatei kommentarlos
            // ohne das gewaehlte Icon hinaus. Angehaengt statt ersetzt, damit ein
            // schon gesetztes Laufschrift-Bild erhalten bleibt.
            do {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4))
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
