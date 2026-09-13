import SwiftUI
import TC002Core
import TC002Modell
import UniformTypeIdentifiers

/// Der Bereich „Editor": Pixel malen.
///
/// **Ein Bereich statt zweier.** Bis zum 13.09.2026 gab es „Icons" (8×8, 16×16)
/// und „Bilder" (52×16) nebeneinander. Der Auftraggeber hat beim Testen gesagt,
/// er verstehe den Unterschied zwischen Malen und Icons nicht — und hatte
/// recht: Es ist eine Taetigkeit. Was dabei herauskommt, entscheidet allein die
/// Leinwandgroesse, und was daraus folgt, steht abgeleitet in
/// `Leinwandgroesse`, nicht als Fallunterscheidung hier.
///
/// **Aufbau nach dem Muster von Pages:** Seitenleiste — Leinwand — Inspektor.
/// Der Inspektor hat drei Modi (Malen, Animation, Sichern), umgeschaltet ueber
/// die Symbole rechts oben ueber ihm. Unter der Leinwand steht die Sendezeile —
/// **nur bei 16×52**, denn ein Icon ist fuer sich keine Anzeige.
///
/// Eine Ansicht mit Unterschieden, nicht zwei mit Aehnlichkeiten: In diesem
/// Projekt ist genau daraus schon ein Fehler entstanden (`slotzustand` gab es
/// dreimal, und die abweichende Fassung war die falsche).
public struct EditorBereichView: View {
    @Bindable var zustand: AppZustand

    /// Der Arbeitsstand ueberlebt den Neustart.
    ///
    /// Derselbe Schluessel wie bisher (`bilder.arbeitsstand`) — er ist ein
    /// Dateiformat, und `Leinwand` traegt ihre Groesse selbst mit. Wer die App
    /// mit einem gemalten 52×16 verlaesst, findet es wieder; nur heisst der
    /// Bereich jetzt anders. Der noch aeltere Schluessel `malen.feld` (ein
    /// einzelnes Raster) wird weiter als Rueckfall gelesen.
    @State private var leinwand: Leinwand
    /// Rueckgaengig und Wiederherstellen. `@State`, nicht gesichert: Der Stapel
    /// ueberlebt den Programmlauf nicht.
    @State private var verlauf = Leinwandverlauf()

    /// Als "#RRGGBB" gesichert: @AppStorage kennt keine Color. Die Schluessel
    /// heissen weiter `malen.*` — sie sind ein Dateiformat, und wer sie
    /// umbenennt, wirft bei jeder laufenden Installation Farbe, Platzwahl und
    /// Dauer weg.
    @AppStorage("malen.farbe") private var farbeHex = "#00FF66"
    @AppStorage("malen.meldungsplatz") private var platz = 1
    @AppStorage("malen.dauer") private var dauerText = ""

    @State private var modus = Inspektormodus.malen
    @State private var zeigeInspektor = true
    @State private var radiert = false
    @State private var spielAb = false
    @State private var spielTask: Task<Void, Never>?
    @State private var laeuft = false
    @Environment(\.scenePhase) private var phase

    // Sichern und Bestand.
    @State private var name = ""
    @State private var nummer = ""
    @State private var suche = ""
    @State private var vorhandene: [Editoreintrag] = []
    @State private var meldung: String?
    @State private var lametricNummer = ""
    @State private var laedt = false

    // Rueckfragen.
    @State private var zuWechseln: Leinwandgroesse?
    @State private var zuLaden: Editoreintrag?
    @State private var zuLoeschen: Editoreintrag?
    @State private var zeigeNeuBestaetigung = false

    /// „Datei einlesen…": erst die Dateiauswahl, danach ein Blatt fuer Nummer
    /// und Namen mit dem Dateinamen als Vorschlag.
    @State private var zeigeDateiImport = false
    @State private var zeigeImportBlatt = false
    @State private var importDatei: URL?
    @State private var importNummer = ""
    @State private var importName = ""
    @State private var importGroesse: (breite: Int, hoehe: Int)?

    static let arbeitsstandSchluessel = "bilder.arbeitsstand"

    public init(zustand: AppZustand) {
        self.zustand = zustand
        _leinwand = State(initialValue: Self.gelesenerArbeitsstand())
    }

    /// Was der Inspektor zeigt.
    enum Inspektormodus: String, CaseIterable, Identifiable {
        case malen, animation, sichern
        var id: String { rawValue }
    }

    // MARK: - Arbeitsstand

    /// Der gemerkte Arbeitsstand: erst der Schluessel mit der ganzen Leinwand,
    /// ersatzweise das einzelne Raster der Fassungen bis 13.09.2026, sonst
    /// eine leere Anzeige.
    private static func gelesenerArbeitsstand() -> Leinwand {
        let ablage = UserDefaults.standard
        if let daten = ablage.data(forKey: arbeitsstandSchluessel),
           let gelesen = try? JSONDecoder().decode(Leinwand.self, from: daten),
           Leinwandgroesse.fuer(gelesen) != nil {
            return gelesen
        }
        if let daten = ablage.data(forKey: "malen.feld"),
           let punkte = try? JSONDecoder().decode([String?].self, from: daten),
           let alt = Leinwand(breite: Pixelfeld.breiteStandard, hoehe: Pixelfeld.hoeheStandard,
                              bilder: [punkte]) {
            return alt
        }
        return Leinwandgroesse.anzeige.leereLeinwand
    }

    /// Nicht bei jedem einzelnen Pixel waehrend des Ziehens — das waeren
    /// hunderte Schreibvorgaenge je Strich —, sondern beim Loslassen, beim
    /// Verlassen der Ansicht und beim Beenden des Programms.
    private func arbeitsstandSichern() {
        guard let daten = try? JSONEncoder().encode(leinwand) else { return }
        UserDefaults.standard.set(daten, forKey: Self.arbeitsstandSchluessel)
    }

    // MARK: - Abgeleitetes

    /// Die Groesse kommt von der Leinwand, nicht aus einem zweiten Gedaechtnis
    /// daneben — zwei Quellen fuer dieselbe Angabe koennten auseinanderlaufen.
    private var groesse: Leinwandgroesse { Leinwandgroesse.fuer(leinwand) ?? .anzeige }

    private var bestand: Editorbestand { .eigene }

    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    /// Unter welchem Schluessel gesichert wird — bei 8×8 die Nummer, sonst der
    /// Name. Leer heisst: „Sichern" bleibt gesperrt.
    private var schluessel: String {
        groesse.mitNummer ? nummer.trimmingCharacters(in: .whitespaces)
                          : name.trimmingCharacters(in: .whitespaces)
    }

    /// Ob der Editor gerade leer ist. „Neu" und ein Groessenwechsel fragen nur
    /// nach, wenn hier tatsaechlich etwas stuende, das verloren ginge.
    private var istLeer: Bool {
        nummer.trimmingCharacters(in: .whitespaces).isEmpty
            && name.trimmingCharacters(in: .whitespaces).isEmpty
            && leinwand.istLeer
    }

    /// Das gerade bearbeitete Bild als Pixelfeld — fuer die Rechteckzahl und
    /// fuer die Sendung eines unbewegten Bildes.
    private var feld: Pixelfeld {
        Pixelfeld(breite: leinwand.breite, hoehe: leinwand.hoehe, punkte: leinwand.bild)
            ?? Pixelfeld()
    }

    private var iconsammlung: Iconsammlung { Iconsammlung(schreibordner: Iconordner.eigene) }

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt.
    /// Dieselbe Grundlage wie unter „Senden" und „Verlauf": was die Uhr
    /// meldet, sonst was die App sich gemerkt hat.
    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele().flatMap { zustand.anzeigenAufUhr($0.id) })
        return Set((1...Meldungsplatz.anzahl).filter { namen.contains(Meldungsplatz.name(fuer: $0)) })
    }

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann in der
    /// Nutzlast.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    // MARK: - Aufbau

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Malflaeche(leinwand: $leinwand, farbe: farbe.wrappedValue, radiert: radiert,
                       vorStrich: { verlauf.merken(leinwand) },
                       nachStrich: arbeitsstandSichern)
            fusszeile
            if groesse.sendbar { sendezeile }
        }
        .padding()
        .toolbar { werkzeugleiste }
        .inspector(isPresented: $zeigeInspektor) { inspektor }
        .onAppear { vorhandene = bestand.alle() }
        .onDisappear { stoppeAbspielen(); arbeitsstandSichern() }
        // ⌘Q verlaesst diese Ansicht nicht — ohne dieses Netz ginge ein eben
        // erst gemalter, noch ungesicherter Strich verloren. `scenePhase` statt
        // `willTerminate`: Auf dem iPad gibt es dazu nichts Gleichwertiges.
        .onChange(of: phase) { _, neu in
            if neu != .active { arbeitsstandSichern() }
        }
        .sheet(isPresented: $zeigeImportBlatt) { importBlatt }
        .alert("Neu anfangen?", isPresented: $zeigeNeuBestaetigung) {
            Button("Abbrechen", role: .cancel) {}
            Button("Neu anfangen", role: .destructive) { neu() }
        } message: {
            Text("Das Gemalte ist nicht gesichert und geht dabei verloren.")
        }
        .alert("Größe wechseln?",
               isPresented: Binding(get: { zuWechseln != nil }, set: { if !$0 { zuWechseln = nil } })) {
            Button("Abbrechen", role: .cancel) { zuWechseln = nil }
            Button("Wechseln", role: .destructive) {
                if let neue = zuWechseln { groesseSetzen(neue) }
                zuWechseln = nil
            }
        } message: {
            Text("Zwischen den Größen wird nichts umgerechnet — das Gemalte geht dabei verloren. „Rückgängig“ holt es zurück.")
        }
        .alert("Gemaltes ersetzen?",
               isPresented: Binding(get: { zuLaden != nil }, set: { if !$0 { zuLaden = nil } })) {
            Button("Abbrechen", role: .cancel) { zuLaden = nil }
            Button("Öffnen", role: .destructive) {
                if let eintrag = zuLaden { oeffnen(eintrag) }
                zuLaden = nil
            }
        } message: {
            Text("Das Gemalte ist nicht leer und geht dabei verloren.")
        }
        // `Text(lokf(...))` statt eines eingesetzten Wertes im Schluessel: Eine
        // `LocalizedStringKey` mit Interpolation traegt zur Laufzeit den
        // Schluessel „%@ löschen?", im Quelltext steht aber der interpolierte
        // Ausdruck — `scripts/texte-sammeln.py` sieht ihn nicht, und der
        // Titel bliebe still deutsch. (So war es in beiden Vorgaengerbereichen.)
        .confirmationDialog(
            Text(lokf("„%@“ löschen?", zuLoeschen?.name ?? "")),
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            presenting: zuLoeschen
        ) { eintrag in
            Button("Löschen", role: .destructive) { loeschen(eintrag) }
        } message: { eintrag in
            Text(lokf("„%@“ wird endgültig entfernt.", eintrag.name))
        }
    }

    /// Was unter der Leinwand steht: die Rechteckzahl (nur da, wo sie etwas
    /// besagt — sie zaehlt die Befehle der naechsten Sendung) und die Meldung
    /// der letzten Handlung.
    @ViewBuilder
    private var fusszeile: some View {
        if groesse.sendbar {
            Text(lokf("%d Rechtecke — waagrechte Läufe gleicher Farbe werden zusammengefasst.",
                      feld.alsDrawBefehle().count))
                .font(.footnote).foregroundStyle(.secondary)
        }
        if let meldung {
            Text(meldung).font(.callout).foregroundStyle(.secondary)
        }
    }

    // MARK: - Werkzeugleiste

    /// Rueckgaengig, Wiederherstellen, die drei Modussymbole und der Schalter
    /// fuer den Inspektor — rechts oben ueber ihm, wie bei Pages.
    @ToolbarContentBuilder
    private var werkzeugleiste: some ToolbarContent {
        ToolbarItemGroup {
            Button { rueckgaengig() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!verlauf.kannZurueck)
                .help("Rückgängig")
                .accessibilityLabel("Rückgängig")
            Button { wiederherstellen() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!verlauf.kannVor)
                .help("Wiederherstellen")
                .accessibilityLabel("Wiederherstellen")

            Picker("Inspektor", selection: $modus) {
                Image(systemName: "paintbrush").tag(Inspektormodus.malen)
                    .accessibilityLabel("Malen")
                Image(systemName: "film").tag(Inspektormodus.animation)
                    .accessibilityLabel("Animation")
                Image(systemName: "tray.and.arrow.down").tag(Inspektormodus.sichern)
                    .accessibilityLabel("Sichern")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help("Was der Inspektor zeigt: Malen, Animation oder Sichern.")

            Button { zeigeInspektor.toggle() } label: { Image(systemName: "sidebar.trailing") }
                .help("Inspektor ein- oder ausblenden")
                .accessibilityLabel("Inspektor ein- oder ausblenden")
        }
    }

    // MARK: - Inspektor

    /// `Form` mit `.formStyle(.grouped)` — dieselbe Bauart wie der
    /// Formatinspektor unter „Senden": abgesetzte Karten mit kleiner, grauer
    /// Ueberschrift, Ausrichtung und Zeilenabstand von selbst, und Rollen bei
    /// Bedarf ebenso.
    private var inspektor: some View {
        Form {
            switch modus {
            case .malen: malenAbschnitte
            case .animation: animationAbschnitte
            case .sichern: sichernAbschnitte
            }
        }
        .formStyle(.grouped)
        // Wie unter „Senden": feste Breite am Mac, nachgebend auf dem iPad —
        // dort bleiben im ungünstigsten Fall 678 Punkte für Mitte und
        // Inspektor zusammen.
        #if os(macOS)
        .inspectorColumnWidth(330)
        #else
        .inspectorColumnWidth(min: 240, ideal: 330, max: 400)
        #endif
    }

    @ViewBuilder
    private var malenAbschnitte: some View {
        Section("Größe") {
            Picker("Größe", selection: Binding(get: { groesse }, set: { groesseWechseln($0) })) {
                Text("8 × 8").tag(Leinwandgroesse.icon8)
                Text("16 × 16").tag(Leinwandgroesse.icon16)
                Text("16 × 52").tag(Leinwandgroesse.anzeige)
            }
            .pickerStyle(.segmented).labelsHidden()
            .help("8×8 ist ein LaMetric-Icon mit Nummer, 16×16 ein Icon ohne, 16×52 die ganze Anzeige — nur sie lässt sich senden.")
        }

        Section("Werkzeug") {
            ColorPicker("Farbe", selection: farbe)
            LabeledContent("Stift") {
                Picker("Stift", selection: $radiert) {
                    Image(systemName: "paintbrush.pointed").tag(false)
                        .accessibilityLabel("Malen")
                    Image(systemName: "eraser").tag(true)
                        .accessibilityLabel("Radieren")
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            Button("Alles löschen") { schritt(); leinwand.bildLeeren(); arbeitsstandSichern() }
                .help("Leert das gerade bearbeitete Einzelbild.")
        }

        Section {
            LabeledContent("Verschieben") { pfeilkreuz }
        } footer: {
            Text("Was am Rand hinausgeschoben wird, kommt gegenüber wieder herein.")
        }

        if groesse.iconEinfuegbar {
            Section("Icon einfügen") {
                Menu("Icon wählen…") {
                    ForEach(iconsammlung.alle(), id: \.nummer) { icon in
                        Button(icon.name) { iconEinfuegen(icon) }
                    }
                }
                .disabled(iconsammlung.alle().isEmpty)
                .help("Setzt ein vorhandenes 8×8-Icon senkrecht mittig ins Feld — an derselben Stelle, an der es auch unter „Senden“ läge.")
            }
        }
    }

    @ViewBuilder
    private var animationAbschnitte: some View {
        Section("Einzelbilder") {
            einzelbildstreifen
            Button("Bild anhängen") { schritt(); leinwand.anhaengen(); arbeitsstandSichern() }
                .help("Hängt ein leeres Einzelbild an und schaltet darauf um.")
        }

        Section {
            LabeledContent("Verzögerung") {
                HStack(spacing: 4) {
                    TextField("", value: $leinwand.verzoegerung, format: .number)
                        .frame(width: 60)
                    Text("s").foregroundStyle(.secondary)
                }
            }
            Button(spielAb ? lok("Stopp") : lok("Abspielen")) { abspielenUmschalten() }
                .disabled(leinwand.bilder.count < 2)
        } header: {
            Text("Abspielen")
        } footer: {
            Text("Mehrere Einzelbilder ergeben beim Sichern ein animiertes GIF.")
        }
    }

    @ViewBuilder
    private var sichernAbschnitte: some View {
        Section {
            LabeledContent("Name") { TextField("Name", text: $name).labelsHidden() }
            if groesse.mitNummer {
                LabeledContent("Nummer") { TextField("Nummer", text: $nummer).labelsHidden() }
            }
            HStack {
                Button("Sichern") { sichern() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(schluessel.isEmpty)
                Button("Neu") { neuAnfragen() }
                    .help("Beginnt von vorn: Leinwand, Einzelbilder, Name und Nummer werden geleert.")
            }
        } header: {
            Text("Dieses Bild")
        } footer: {
            Text(groesse.mitNummer
                 ? lok("Die Nummer ist der Dateiname und zugleich die LaMetric-Nummer — sie muss eindeutig sein.")
                 : lok("Der Name ist zugleich der Dateiname — derselbe Name ersetzt das Vorhandene."))
        }

        Section("Hinzufügen") {
            if groesse.mitNummer {
                LabeledContent("LaMetric-Nummer") {
                    HStack(spacing: 4) {
                        TextField("Nummer", text: $lametricNummer)
                            .labelsHidden()
                            .frame(width: 90)
                            .onSubmit { nachladen() }
                        Button(laedt ? lok("Hole…") : lok("Nachladen")) { nachladen() }
                            .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Link("LaMetric Icon Gallery", destination: URL(string: "https://developer.lametric.com/icons")!)
                    .font(.caption)
            }
            Button("Datei einlesen…") { zeigeDateiImport = true }
                .fileImporter(isPresented: $zeigeDateiImport,
                              allowedContentTypes: [.gif, .png, .jpeg]) { ergebnis in
                    guard case .success(let url) = ergebnis else { return }
                    importDatei = url
                    let basis = url.deletingPathExtension().lastPathComponent
                    importNummer = basis
                    importName = basis
                    importGroesse = Bildraster.groesse(url)
                    zeigeImportBlatt = true
                }
            if groesse.mitNummer {
                Button("Grundschatz wiederherstellen") { grundschatzWiederherstellen() }
                    .help("Holt gelöschte Icons des Grundschatzes zurück — Vorhandenes bleibt unangetastet.")
            }
        }

        Section("Vorhandene") {
            TextField("Suchen", text: $suche)
            // Gesucht wird in der schon gelesenen Liste (`vorhandene`), nicht
            // bei jedem Tastendruck neu im Dateisystem.
            ForEach(vorhandene.gefiltert(nach: suche)) { eintrag in
                bestandszeile(eintrag)
            }
        }
    }

    /// Vier Pfeile um einen Mittelpunkt — schiebt die ganze Grafik um ein
    /// Pixel. Ein Kreuz und keine vier Knoepfe in einer Reihe: Richtung ist
    /// raeumlich, und in einer Reihe muesste man jedes Symbol einzeln lesen.
    private var pfeilkreuz: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.up", dx: 0, dy: -1).accessibilityLabel("Nach oben schieben")
                Color.clear.frame(width: 1, height: 1)
            }
            GridRow {
                pfeil("arrow.left", dx: -1, dy: 0).accessibilityLabel("Nach links schieben")
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.right", dx: 1, dy: 0).accessibilityLabel("Nach rechts schieben")
            }
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.down", dx: 0, dy: 1).accessibilityLabel("Nach unten schieben")
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .help("Schiebt die ganze Grafik pixelweise. Was am Rand hinausgeschoben wird, kommt gegenüber wieder herein.")
    }

    /// Die Beschriftung fuer VoiceOver setzt der Aufrufer, nicht diese
    /// Funktion: Ein Text, der als Argument durchgereicht wird, steht fuer
    /// `scripts/texte-sammeln.py` nicht mehr an einer Stelle, die es kennt.
    private func pfeil(_ symbol: String, dx: Int, dy: Int) -> some View {
        Button {
            schritt()
            leinwand.verschieben(dx: dx, dy: dy)
            arbeitsstandSichern()
        } label: {
            Image(systemName: symbol).frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
    }

    /// Die Leiste der Einzelbilder. „Verdoppeln" und „Entfernen" stehen **am
    /// Bild, auf das sie wirken** — beim gewaehlten unter seinem Vorschaubild
    /// und bei jedem im Kontextmenue; in einer gemeinsamen Zeile darunter war
    /// nicht zu sehen, welches Bild gemeint ist.
    private var einzelbildstreifen: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(leinwand.bilder.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        bildVorschau(i)
                        if leinwand.aktuell == i {
                            HStack(spacing: 2) {
                                Button {
                                    schritt(); leinwand.verdoppeln(); arbeitsstandSichern()
                                } label: {
                                    Image(systemName: "plus.square.on.square")
                                }
                                .help("Dieses Einzelbild verdoppeln")
                                .accessibilityLabel("Verdoppeln")
                                Button(role: .destructive) {
                                    schritt(); leinwand.entfernen(); arbeitsstandSichern()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .disabled(leinwand.bilder.count <= 1)
                                .help("Dieses Einzelbild entfernen")
                                .accessibilityLabel("Entfernen")
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    .contextMenu {
                        Button("Verdoppeln") { schritt(); leinwand.waehlen(i); leinwand.verdoppeln(); arbeitsstandSichern() }
                        Button("Entfernen", role: .destructive) { schritt(); leinwand.waehlen(i); leinwand.entfernen(); arbeitsstandSichern() }
                            .disabled(leinwand.bilder.count <= 1)
                        Divider()
                        // Die Reihenfolge aendert die Animation und ist deshalb
                        // ein Schritt wie Anhaengen und Entfernen.
                        Button("Nach vorn") { schritt(); leinwand.waehlen(i); leinwand.tauschen(um: -1); arbeitsstandSichern() }
                            .disabled(i == 0)
                        Button("Nach hinten") { schritt(); leinwand.waehlen(i); leinwand.tauschen(um: 1); arbeitsstandSichern() }
                            .disabled(i == leinwand.bilder.count - 1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func bildVorschau(_ i: Int) -> some View {
        Canvas { kontext, groesse in
            let kante = groesse.width / Double(leinwand.breite)
            for y in 0..<leinwand.hoehe {
                for x in 0..<leinwand.breite {
                    let feld = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                      width: kante, height: kante)
                    let p = leinwand.bilder[i][y * leinwand.breite + x]
                    kontext.fill(Path(feld), with: .color(p.flatMap(Color.init(hex:)) ?? .black))
                }
            }
        }
        // Die Vorschau behaelt das Seitenverhaeltnis der Leinwand: bei 52×16
        // ist ein Quadrat nicht dasselbe Bild, sondern ein anderes.
        .frame(width: 34, height: 34 * Double(leinwand.hoehe) / Double(leinwand.breite))
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3)
            .stroke(leinwand.aktuell == i ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: leinwand.aktuell == i ? 2 : 1))
        // Ein Bild zu waehlen aendert nichts an der Zeichnung und ist deshalb
        // kein Schritt fuer „Rueckgaengig".
        .onTapGesture { stoppeAbspielen(); leinwand.waehlen(i) }
    }

    /// Eine Zeile der Liste der Vorhandenen — mit der Groesse als Merkmal, weil
    /// alle drei Bestaende in derselben Liste stehen.
    private func bestandszeile(_ eintrag: Editoreintrag) -> some View {
        HStack {
            // Alle drei Groessen in dasselbe Kaestchen von 44 × 24 Punkten
            // eingepasst — ohne Fallunterscheidung, damit eine vierte Groesse
            // hier nichts zu aendern haette. Ein 52×16 wird dabei breit und
            // flach, ein Quadrat quadratisch: Das ist das Bild, nicht ein
            // Fehler.
            Rasterbild(datei: eintrag.datei,
                       breite: eintrag.groesse.breite, hoehe: eintrag.groesse.hoehe,
                       kante: min(44 / Double(eintrag.groesse.breite),
                                  24 / Double(eintrag.groesse.hoehe)))
                .background(Color.black)
            VStack(alignment: .leading, spacing: 1) {
                Text(eintrag.name).lineLimit(1)
                Text(lok(eintrag.groesse.beschriftung) + (eintrag.nummer.map { " · \($0)" } ?? ""))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { zuLoeschen = eintrag } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(lokf("„%@“ löschen", eintrag.name))
                .accessibilityLabel(Text(lokf("„%@“ löschen", eintrag.name)))
        }
        .contentShape(Rectangle())
        .onTapGesture { anklicken(eintrag) }
        .contextMenu {
            Button("Öffnen") { anklicken(eintrag) }
            Button("Löschen", role: .destructive) { zuLoeschen = eintrag }
        }
    }

    // MARK: - Sendezeile

    /// Nur bei 16×52 — ein Icon ist fuer sich keine Anzeige.
    private var sendezeile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            // Breit: Bloecke und Dauer nebeneinander. Schmal: die Dauer rueckt
            // darunter, statt dass die Zeile rechts abgeschnitten wird.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 16) { sendeteile }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) { slotBloecke }
                    HStack(spacing: 16) { dauerFeld; Spacer(); ZielauswahlView(zustand: zustand); sendeKnopf }
                }
            }
            if zustand.ziele().isEmpty {
                Text("Erst unter „Einstellungen“ eine Uhr eintragen und abfragen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var sendeteile: some View {
        HStack(spacing: 6) { slotBloecke }
        dauerFeld
        Spacer()
        ZielauswahlView(zustand: zustand)
        sendeKnopf
    }

    /// Dieselben Bloecke wie unter „Senden", aus derselben Rechnung
    /// (`AppZustand.slotzustand`) — derselbe Platz derselben Uhr soll hier
    /// nicht etwas anderes zeigen. Antippen waehlt hier nur den Platz: Regler,
    /// die sich wiederherstellen liessen, gibt es beim Malen nicht.
    @ViewBuilder
    private var slotBloecke: some View {
        ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
            Button { platz = i } label: {
                Slotblock(platz: i,
                          zustand: zustand.slotzustand(i, belegt: belegtePlaetze.contains(i)),
                          gewaehlt: platz == i)
            }
            .buttonStyle(.plain)
        }
        MeldungLoeschenKnopf(zustand: zustand, platz: platz,
                             belegt: belegtePlaetze.contains(platz))
    }

    private var dauerFeld: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Dauer (Sek.)").font(.caption).foregroundStyle(.secondary)
            TextField("Uhr entscheidet", text: $dauerText).frame(width: 100)
        }
    }

    private var sendeKnopf: some View {
        // `lok` in beiden Zweigen: Ein Ternaer mit einem `String`-Zweig zwingt
        // SwiftUI in die `StringProtocol`-Ueberladung, und die schlaegt nichts
        // nach — der Eintrag staende in `en.lproj` und wuerde nie gefunden.
        Button(laeuft ? lok("Sende…") : lok("Senden")) { senden() }
            .keyboardShortcut(.defaultAction)
            .disabled(laeuft || zustand.ziele().isEmpty)
    }

    // MARK: - Blatt „Datei einlesen"

    private var importBlatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datei einlesen").font(.headline)
            if groesse.mitNummer {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nummer").font(.caption).foregroundStyle(.secondary)
                    TextField("Nummer", text: $importNummer)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Name", text: $importName)
            }
            HStack {
                Spacer()
                Button("Abbrechen") { zeigeImportBlatt = false }
                Button("Einlesen") { einlesen() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(importSchluessel.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }

    private var importSchluessel: String {
        groesse.mitNummer ? importNummer.trimmingCharacters(in: .whitespaces)
                          : importName.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Rueckgaengig

    /// Vor jeder Aenderung, die ein Schritt ist. Ein Strich ruft es ueber
    /// `Malflaeche.vorStrich` einmal je Strich, nicht je Pixel.
    private func schritt() { verlauf.merken(leinwand) }

    private func rueckgaengig() {
        guard let vorheriger = verlauf.zurueck(von: leinwand) else { return }
        stoppeAbspielen()
        leinwand = vorheriger
        arbeitsstandSichern()
    }

    private func wiederherstellen() {
        guard let naechster = verlauf.vor(von: leinwand) else { return }
        stoppeAbspielen()
        leinwand = naechster
        arbeitsstandSichern()
    }

    // MARK: - Handlungen

    private func groesseWechseln(_ neue: Leinwandgroesse) {
        guard neue != groesse else { return }
        if istLeer { groesseSetzen(neue) } else { zuWechseln = neue }
    }

    /// Umgerechnet wird zwischen den Groessen **nichts**. Der Wechsel ist ein
    /// Schritt — „Rueckgaengig" holt die verworfene Leinwand samt ihrer Groesse
    /// zurueck, weil `Leinwand` sie selbst traegt.
    private func groesseSetzen(_ neue: Leinwandgroesse) {
        schritt()
        stoppeAbspielen()
        leinwand = neue.leereLeinwand
        nummer = ""
        name = ""
        meldung = nil
        arbeitsstandSichern()
    }

    private func neuAnfragen() {
        if istLeer { neu() } else { zeigeNeuBestaetigung = true }
    }

    /// Von vorn — Leinwand, Einzelbilder, Verzoegerung, Name und Nummer. Der
    /// Verlauf faellt dabei weg: Von einem leeren Blatt aus fuehrt kein Weg
    /// zurueck zu dem, was nicht mehr da ist.
    private func neu() {
        stoppeAbspielen()
        verlauf.leeren()
        leinwand = groesse.leereLeinwand
        nummer = ""
        name = ""
        meldung = nil
        arbeitsstandSichern()
    }

    private func anklicken(_ eintrag: Editoreintrag) {
        if leinwand.istLeer { oeffnen(eintrag) } else { zuLaden = eintrag }
    }

    private func oeffnen(_ eintrag: Editoreintrag) {
        do {
            // Schwarz bleibt Schwarz: Beim Sichern wird „aus“ zu Schwarz, weil
            // GIF hier keine Durchsichtigkeit traegt — nach einem Rundlauf sind
            // beide dasselbe und nicht mehr auseinanderzuhalten.
            let neue = try bestand.oeffnen(eintrag)
            stoppeAbspielen()
            verlauf.leeren()
            leinwand = neue
            nummer = eintrag.nummer ?? ""
            name = eintrag.name
            arbeitsstandSichern()
            meldung = neue.bilder.count > 1
                ? lokf("%@ geöffnet (%d Bilder).", eintrag.name, neue.bilder.count)
                : lokf("%@ geöffnet.", eintrag.name)
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func sichern() {
        do {
            let eintrag = try bestand.sichern(leinwand, name: name, nummer: nummer)
            vorhandene = bestand.alle()
            name = eintrag.name
            meldung = lokf("%@ gesichert.", eintrag.name)
            zustand.log("Gesichert: \(eintrag.name)")
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func loeschen(_ eintrag: Editoreintrag) {
        do {
            try bestand.loeschen(eintrag)
            vorhandene = bestand.alle()
            // War das Geloeschte gerade geoeffnet, bleibt das Bild stehen, aber
            // Name und Nummer werden geleert — sonst legt ein erneutes
            // „Sichern" es unter demselben Namen wieder an.
            if eintrag.groesse == groesse
                && ((eintrag.nummer.map { $0 == nummer } ?? false) || eintrag.name == name) {
                nummer = ""
                name = ""
            }
            meldung = lokf("%@ gelöscht.", eintrag.name)
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
            let sammlung = Iconsammlung(schreibordner: Iconordner.eigene)
            do {
                let icon = try sammlung.holen(nummer: n)
                await MainActor.run {
                    vorhandene = bestand.alle()
                    lametricNummer = ""
                    meldung = lokf("%@ von LaMetric geholt.", icon.name)
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

    /// Liest die zuvor gewaehlte Datei in den Bestand der aktuellen Groesse.
    /// Der Hinweis auf eine Umrechnung nennt die Originalgroesse nur, wenn
    /// tatsaechlich gerechnet wurde.
    private func einlesen() {
        guard let datei = importDatei else { return }
        do {
            let eintrag = try bestand.einlesen(datei: datei, groesse: groesse,
                                               nummer: importNummer, name: importName)
            vorhandene = bestand.alle()
            zeigeImportBlatt = false
            if let masse = importGroesse, masse != (groesse.breite, groesse.hoehe) {
                meldung = lokf("%@ eingelesen. Das Bild wurde von %d×%d auf %d×%d gerechnet.",
                               eintrag.name, masse.breite, masse.hoehe,
                               groesse.breite, groesse.hoehe)
            } else {
                meldung = lokf("%@ eingelesen.", eintrag.name)
            }
            zustand.log("Eingelesen: \(eintrag.name)")
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Holt mitgelieferte Icons zurueck, die im Schreibordner fehlen. Vorhandene
    /// Dateien bleiben unberuehrt; die Meldung nennt die Anzahl, damit „nichts
    /// passiert" nicht wie ein Fehlschlag wirkt.
    private func grundschatzWiederherstellen() {
        let quelle = Iconsammlung(schreibordner: Iconordner.eigene,
                                  leseordner: [Iconordner.mitgeliefert])
        let anzahl = quelle.mitgelieferteUebernehmen()
        vorhandene = bestand.alle()
        meldung = anzahl > 0
            ? lokf("%d Icons aus dem Grundschatz wiederhergestellt.", anzahl)
            : lok("Nichts zu holen — der Grundschatz ist vollständig da.")
    }

    /// Setzt ein 8×8-Icon als Ausgangspunkt ins Feld — senkrecht mittig wie
    /// beim Senden (x: 0, y: 4). Durchsichtige Stellen im Icon lassen das Feld
    /// dort unberuehrt, statt ein schwarzes Rechteck hineinzuradieren.
    private func iconEinfuegen(_ icon: Icon) {
        do {
            let pixel = try iconsammlung.pixel(fuer: icon)
            schritt()
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let farbe = pixel[y * 8 + x] else { continue }
                    leinwand.setzen(x: x, y: 4 + y, farbe: farbe)
                }
            }
            arbeitsstandSichern()
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Laeuft die Einzelbilder in Schleife durch, solange „Abspielen" gedrueckt
    /// ist — nur zur Ansicht, ohne dass vorher gesichert werden muss.
    private func abspielenUmschalten() {
        guard !spielAb else { stoppeAbspielen(); return }
        spielAb = true
        spielTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(max(0.05, leinwand.verzoegerung)))
                guard !Task.isCancelled, leinwand.bilder.count > 1 else { continue }
                await MainActor.run { leinwand.waehlen((leinwand.aktuell + 1) % leinwand.bilder.count) }
            }
        }
    }

    private func stoppeAbspielen() {
        spielAb = false
        spielTask?.cancel()
        spielTask = nil
    }

    /// `slotPlatz` ohne `slotOptionen`: Ein gemaltes Bild hat keine Regler, es
    /// gibt hier nichts zu merken — wohl aber etwas zu vergessen. Stand auf dem
    /// Platz vorher eine Textsendung, liegt dazu ein gemerkter Stand, und der
    /// Block rechnete daraus beim naechsten Start ohne Broker weiter den alten
    /// Text. `AppZustand.senden` wirft ihn deshalb je erreichter Uhr weg.
    ///
    /// Ein einzelnes Bild geht als `draw` hinaus — klein und exakt. Mehrere
    /// gehen als ein animiertes GIF: Rechtecke kennen keine Zeit.
    private func senden() {
        let frame: Frame
        if leinwand.bilder.count > 1 {
            do {
                let uri = try Bildraster.alsDatenURI(leinwand.bilder,
                                                     breite: leinwand.breite, hoehe: leinwand.hoehe,
                                                     verzoegerung: leinwand.verzoegerung)
                frame = Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: dauer)
            } catch {
                zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                return
            }
        } else {
            frame = Frame(draw: feld.alsDrawBefehle(), dauer: dauer)
        }
        laeuft = true
        let anzeigenName = Meldungsplatz.name(fuer: platz)
        // Momentaufnahme wie in `SendenView.senden`: der Task soll den Platz
        // von jetzt sehen, nicht den beim spaeteren Ausfuehren.
        let slotPlatz = platz
        Task {
            await zustand.senden(frame, als: anzeigenName, slotPlatz: slotPlatz)
            laeuft = false
        }
    }
}
