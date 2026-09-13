import SwiftUI
import TC002Core
import TC002Modell
import UniformTypeIdentifiers

/// Der Bereich „Bilder": ein frei gezeichnetes 52×16-Bild malen, sichern und
/// an die Uhr schicken.
///
/// **Aufbau wie im Icon-Bereich** — Editor links, die Sammlung als Liste
/// rechts. Bis 13.09.2026 hiess der Bereich „Malen" und versteckte seine
/// Sammlung hinter einem Knopf „Bilder", der ein eigenes Blatt aufzog; wer die
/// App zum ersten Mal sah, hielt „Malen" und „Icons" fuer zwei Ausgaben
/// derselben Sache und fand die Sammlung gar nicht erst.
///
/// Eigenstaendig bleibt der Bereich trotzdem: Was hier entsteht, ist eine ganze
/// Anzeige und bekommt keine LaMetric-Nummer — es geht von hier unmittelbar auf
/// einen der fuenf Plaetze, waehrend ein Icon unter „Senden" neben einem Text
/// steht.
public struct BilderBereichView: View {
    @Bindable var zustand: AppZustand

    /// Das zuletzt gemalte Feld ueberlebt den Neustart — der Arbeitsstand.
    /// `pixelfeldSichern()` schreibt es weg. Die Sammlung mehrerer benannter
    /// Bilder steht daneben in der rechten Spalte.
    @State private var feld = Pixelfeld()
    /// Als "#RRGGBB" gesichert wie in SendenView: @AppStorage kennt keine Color.
    ///
    /// Die Schluessel heissen weiter `malen.*`, obwohl der Bereich jetzt
    /// „Bilder" heisst: Sie sind ein Dateiformat. Wer sie umbenennt, wirft bei
    /// jeder laufenden Installation Farbe, Platzwahl, Dauer und das zuletzt
    /// gemalte Bild weg.
    @AppStorage("malen.farbe") private var farbeHex = "#00FF66"
    @State private var radierer = false
    @AppStorage("malen.meldungsplatz") private var platz = 1
    @AppStorage("malen.dauer") private var dauerText = ""
    @State private var laeuft = false
    @Environment(\.scenePhase) private var phase

    // Die Sammlung rechts.
    @State private var bilder: [Gemaltes] = []
    @State private var name = ""
    @State private var zuLaden: Gemaltes?
    @State private var zuLoeschen: Gemaltes?
    @State private var meldung: String?

    /// Zustand fuer „Datei einlesen…": erst die Dateiauswahl, danach ein Blatt
    /// fuer den Namen mit dem Dateinamen als Vorschlag.
    @State private var zeigeDateiImport = false
    @State private var zeigeImportBlatt = false
    @State private var importDatei: URL?
    @State private var importName = ""
    @State private var importGroesse: (breite: Int, hoehe: Int)?

    public init(zustand: AppZustand) {
        self.zustand = zustand
        let punkte = try? JSONDecoder().decode([String?].self,
                        from: UserDefaults.standard.data(forKey: "malen.feld") ?? Data())
        _feld = State(initialValue: punkte.flatMap { Pixelfeld(punkte: $0) } ?? Pixelfeld())
    }

    /// Nicht bei jedem einzelnen Pixel waehrend des Ziehens — das waeren hunderte
    /// Schreibvorgaenge je Strich —, sondern beim Loslassen, beim Verlassen der
    /// Ansicht und beim Beenden des Programms.
    private func pixelfeldSichern() {
        guard let daten = try? JSONEncoder().encode(feld.punkteRoh) else { return }
        UserDefaults.standard.set(daten, forKey: "malen.feld")
    }

    /// Fuer den ColorPicker: liest/schreibt `farbeHex` als `Color`.
    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt — bei
    /// mehreren Zieluhren zaehlt jede davon. Dieselbe Grundlage wie die Liste
    /// unter „Verlauf": was die Uhr meldet, sonst was die App sich gemerkt hat.
    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele().flatMap { zustand.anzeigenAufUhr($0.id) })
        return Set((1...Meldungsplatz.anzahl).filter { namen.contains(Meldungsplatz.name(fuer: $0)) })
    }

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann in der
    /// Nutzlast wie bisher.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Die verfuegbare Breite der Malflaeche, von einem GeometryReader in ihrem
    /// Hintergrund gemessen — daraus ergibt sich die Kantenlaenge. Ohne das liefe die
    /// Flaeche bei ihrer festen Breite in einem schmalen Fenster rechts aus dem Bild.
    @State private var flaechenBreite: Double = Double(Pixelfeld.breiteStandard) * 14

    private var kante: Double {
        min(14, max(6, flaechenBreite / Double(feld.breite)))
    }

    private var iconsammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene)
    }

    private var sammlung: Bildersammlung {
        Bildersammlung(ordner: Bilderordner.eigene)
    }

    private var feldIstLeer: Bool {
        feld.punkteRoh.allSatisfy { $0 == nil }
    }

    public var body: some View {
        // `HSplitView` — die vom Nutzer verschiebbare Trennlinie — gibt es nur
        // am Mac. Unter iPadOS bleibt die Aufteilung dieselbe, nur ohne Griff.
        // Wortgleich zu `IconEditorView`: Beide Bereiche sollen sich gleich
        // anfuehlen, das ist der ganze Sinn dieses Umbaus.
        Group {
            #if os(macOS)
            HSplitView {
                editor
                sammlungsspalte
            }
            #else
            HStack(spacing: 0) {
                editor
                sammlungsspalte
            }
            #endif
        }
        .onDisappear { pixelfeldSichern() }
        // ⌘Q verlaesst diese Ansicht nicht — ohne dieses Netz ginge ein eben erst
        // gemalter, noch ungesicherter Strich verloren, wenn beim Beenden gerade
        // diese Ansicht offen ist. Denselben Kniff nutzt App.swift fuer das Kennwort.
        //
        // `scenePhase` statt `willTerminate`: Auf dem iPad gibt es dazu keine
        // gleichwertige Benachrichtigung. Beim harten Abschuss feuert sie gar
        // nicht — deshalb sichert jede Aenderung ohnehin schon fuer sich
        // (Strichende, Leeren, Icon einfuegen, geladenes Bild), und diese Zeile
        // ist nur noch das Netz darunter.
        .onChange(of: phase) { _, neu in
            if neu != .active { pixelfeldSichern() }
        }
        .sheet(isPresented: $zeigeImportBlatt) { importBlatt }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bild malen").font(.headline)

            HStack {
                ColorPicker("Farbe", selection: farbe)
                Toggle("Radierer", isOn: $radierer).toggleStyle(.button)
                Button("Leeren") { feld.alleLoeschen(); pixelfeldSichern() }
                Menu("Icon einfügen") {
                    ForEach(iconsammlung.alle(), id: \.nummer) { icon in
                        Button(icon.name) { iconEinfuegen(icon) }
                    }
                }
                .disabled(iconsammlung.alle().isEmpty)
                Spacer()
            }

            malflaeche

            Text(lokf("%d Rechtecke — waagrechte Läufe gleicher Farbe werden zusammengefasst.", feld.alsDrawBefehle().count))
                .font(.footnote).foregroundStyle(.secondary)

            if let meldung {
                Text(meldung).font(.callout).foregroundStyle(.secondary)
            }

            Divider()

            sendezeile

            if zustand.ziele().isEmpty {
                Text("Erst unter „Einstellungen“ eine Uhr eintragen und abfragen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var sendezeile: some View {
        HStack(alignment: .bottom, spacing: 16) {
            HStack(spacing: 6) {
                // Dieselben Bloecke wie unter „Senden", aus derselben
                // Rechnung (`AppZustand.slotzustand`) — derselbe Platz
                // derselben Uhr soll hier nicht etwas anderes zeigen.
                // Antippen waehlt hier nur den Platz: Regler, die sich
                // wiederherstellen liessen, gibt es beim Malen nicht —
                // und eine Sendung von hier wirft die zum Platz gemerkten
                // weg, statt sie ueberleben zu lassen (siehe `senden`).
                ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
                    Button { platz = i } label: {
                        Slotblock(platz: i,
                                  zustand: zustand.slotzustand(i, belegt: belegtePlaetze.contains(i)),
                                  gewaehlt: platz == i)
                    }
                    .buttonStyle(.plain)
                }
            }
            MeldungLoeschenKnopf(zustand: zustand, platz: platz,
                                 belegt: belegtePlaetze.contains(platz))
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
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { wert in
                let x = Int(wert.location.x / kante), y = Int(wert.location.y / kante)
                if radierer { feld.loeschen(x: x, y: y) } else { feld.setzen(x: x, y: y, farbe: farbeHex) }
            }
            .onEnded { _ in pixelfeldSichern() })
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { flaechenBreite = geo.size.width }
                    .onChange(of: geo.size.width) { _, neu in flaechenBreite = neu }
            }
        )
    }

    // MARK: - Sammlung

    private var sammlungsspalte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gesicherte Bilder").font(.headline)

            HStack {
                TextField("Name", text: $name)
                Button("Sichern") { sichern() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Der Name ist zugleich der Dateiname — derselbe Name ersetzt das vorhandene Bild.")
                .font(.caption2).foregroundStyle(.secondary)

            Button("Datei einlesen…") { zeigeDateiImport = true }
                .fileImporter(isPresented: $zeigeDateiImport,
                              allowedContentTypes: [.gif, .png, .jpeg]) { ergebnis in
                    guard case .success(let url) = ergebnis else { return }
                    importDatei = url
                    importName = url.deletingPathExtension().lastPathComponent
                    importGroesse = Bildraster.groesse(url)
                    zeigeImportBlatt = true
                }

            if bilder.isEmpty {
                Text("Noch keine gesicherten Bilder.").font(.callout).foregroundStyle(.secondary)
            }
            List(bilder, id: \.datei) { bild in
                HStack {
                    Rasterbild(datei: bild.datei,
                               breite: Pixelfeld.breiteStandard,
                               hoehe: Pixelfeld.hoeheStandard,
                               kante: 2)
                        .background(Color.black)
                    Text(bild.name).lineLimit(1)
                    Spacer()
                    Button { zuLoeschen = bild } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(lokf("„%@“ löschen", bild.name))
                }
                .contentShape(Rectangle())
                .onTapGesture { anklicken(bild) }
                .contextMenu {
                    Button("Öffnen") { anklicken(bild) }
                    Button("Löschen", role: .destructive) { zuLoeschen = bild }
                }
            }
        }
        .padding()
        .frame(minWidth: 240)
        .onAppear { bilder = sammlung.alle() }
        .alert("Aktuelles Bild ersetzen?",
               isPresented: Binding(get: { zuLaden != nil }, set: { if !$0 { zuLaden = nil } })) {
            Button("Abbrechen", role: .cancel) { zuLaden = nil }
            Button("Laden", role: .destructive) {
                if let bild = zuLaden { laden(bild) }
                zuLaden = nil
            }
        } message: {
            Text("Das gemalte Bild ist nicht leer und geht dabei verloren.")
        }
        .confirmationDialog(
            "„\(zuLoeschen?.name ?? "")“ löschen?",
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            presenting: zuLoeschen
        ) { bild in
            Button("Löschen", role: .destructive) { loeschen(bild) }
        } message: { bild in
            Text(lokf("Das Bild „%@“ wird endgültig entfernt.", bild.name))
        }
    }

    private var importBlatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datei einlesen").font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Name", text: $importName)
            }
            HStack {
                Spacer()
                Button("Abbrechen") { zeigeImportBlatt = false }
                Button("Einlesen") { einlesen() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(importName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }

    // MARK: - Handlungen

    private func anklicken(_ bild: Gemaltes) {
        if feldIstLeer { laden(bild) } else { zuLaden = bild }
    }

    private func laden(_ bild: Gemaltes) {
        do {
            feld = try sammlung.laden(bild)
            pixelfeldSichern()
            meldung = lokf("%@ geöffnet.", bild.name)
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func sichern() {
        let n = name.trimmingCharacters(in: .whitespaces)
        do {
            let eintrag = try sammlung.sichern(name: n, feld: feld)
            bilder = sammlung.alle()
            name = ""
            meldung = lokf("%@ gesichert.", eintrag.name)
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Liest die zuvor per „Datei einlesen…" gewaehlte Datei unter dem im
    /// Blatt eingetragenen Namen ein. Der Hinweis auf eine Umrechnung nennt
    /// die Originalgroesse nur, wenn tatsaechlich gerechnet wurde.
    private func einlesen() {
        guard let datei = importDatei else { return }
        let n = importName.trimmingCharacters(in: .whitespaces)
        do {
            let eintrag = try sammlung.einfuegen(datei: datei, name: n)
            bilder = sammlung.alle()
            zeigeImportBlatt = false
            if let groesse = importGroesse, groesse != (Pixelfeld.breiteStandard, Pixelfeld.hoeheStandard) {
                meldung = lokf("%@ eingelesen. Das Bild wurde von %d×%d auf %d×%d gerechnet.", eintrag.name, groesse.breite, groesse.hoehe, Pixelfeld.breiteStandard, Pixelfeld.hoeheStandard)
            } else {
                meldung = lokf("%@ eingelesen.", eintrag.name)
            }
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func loeschen(_ bild: Gemaltes) {
        do {
            try sammlung.loeschen(bild)
            bilder = sammlung.alle()
            meldung = lokf("%@ gelöscht.", bild.name)
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Setzt ein 8×8-Icon als Ausgangspunkt ins Feld — senkrecht mittig wie beim
    /// Senden (x: 0, y: 4). Durchsichtige Stellen im Icon lassen das Feld dort
    /// unberuehrt, statt ein schwarzes Rechteck hineinzuradieren.
    private func iconEinfuegen(_ icon: Icon) {
        do {
            let pixel = try iconsammlung.pixel(fuer: icon)
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let farbe = pixel[y * 8 + x] else { continue }
                    feld.setzen(x: x, y: 4 + y, farbe: farbe)
                }
            }
            pixelfeldSichern()
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// `slotPlatz` ohne `slotOptionen`: Ein gemaltes Bild hat keine Regler, es
    /// gibt hier nichts zu merken — wohl aber etwas zu vergessen. Stand auf dem
    /// Platz vorher eine Textsendung, liegt dazu ein gemerkter Stand, und der
    /// Block rechnete daraus beim naechsten Start ohne Broker weiter den alten
    /// Text. `AppZustand.senden` wirft ihn deshalb je erreichter Uhr weg.
    private func senden() {
        laeuft = true
        let frame = Frame(draw: feld.alsDrawBefehle(), dauer: dauer)
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
