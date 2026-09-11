import SwiftUI
import TC002Core
import UniformTypeIdentifiers

/// 8×8-Editor fuer eigene Icons. Dasselbe Malprinzip wie der grosse Editor, nur
/// kleiner und mit Ablage: was hier gesichert wird, steht unter „Senden" zur Wahl.
struct IconEditorView: View {
    @Bindable var zustand: AppZustand

    /// Ein oder mehrere Einzelbilder — mehrere ergeben beim Sichern ein animiertes
    /// GIF. Gemalt wird immer auf `bilder[aktuellesBild]`.
    @State private var bilder: [[String?]] = [[String?](repeating: nil, count: 64)]
    @State private var aktuellesBild = 0
    /// Verzoegerung je Einzelbild in Sekunden, gemeinsam fuer die ganze Animation.
    @State private var verzoegerung: Double = 0.2
    @State private var spielAb = false
    @State private var spielTask: Task<Void, Never>?
    @State private var farbe = Color(red: 1, green: 1, blue: 1)
    @State private var radiert = false
    @State private var nummer = ""
    @State private var name = ""
    @State private var vorhandene: [Icon] = []
    @State private var meldung: String?
    @State private var lametricNummer = ""
    @State private var laedt = false
    @State private var suche = ""
    /// Das Icon, fuer das gerade die Loesch-Rueckfrage steht — `nil` heisst
    /// keine.
    @State private var zuLoeschen: Icon?

    /// Zustand fuer „Datei einlesen…": erst die Dateiauswahl, danach ein Blatt
    /// fuer Nummer und Namen mit dem Dateinamen als Vorschlag.
    @State private var zeigeDateiImport = false
    @State private var zeigeImportBlatt = false
    @State private var importDatei: URL?
    @State private var importNummer = ""
    @State private var importName = ""
    @State private var importGroesse: (breite: Int, hoehe: Int)?

    private let kante: Double = 28

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    var body: some View {
        HSplitView {
            malflaeche
            seitenleiste
        }
        .onDisappear { stoppeAbspielen() }
        .sheet(isPresented: $zeigeImportBlatt) { importBlatt }
    }

    private var importBlatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datei einlesen").font(.headline)
            nummerFeldImport
            nameFeldImport
            HStack {
                Spacer()
                Button("Abbrechen") { zeigeImportBlatt = false }
                Button("Einlesen") { einlesen() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(importNummer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }

    private var nummerFeldImport: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nummer").font(.caption).foregroundStyle(.secondary)
            TextField("Nummer", text: $importNummer)
        }
    }

    private var nameFeldImport: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Name").font(.caption).foregroundStyle(.secondary)
            TextField("Name", text: $importName)
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
                        let p = bilder[aktuellesBild][y * 8 + x]
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
                bilder[aktuellesBild][y * 8 + x] = radiert ? nil : farbe.hexWert
            })

            bildleiste

            HStack {
                ColorPicker("Farbe", selection: $farbe)
                Toggle("Radieren", isOn: $radiert).toggleStyle(.button)
                Button("Alles löschen") { bilder[aktuellesBild] = [String?](repeating: nil, count: 64) }
                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    nummerFeld
                    nameFeld
                    sichernKnopf
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { nummerFeld; nameFeld }
                    sichernKnopf
                }
            }
            Text("Die Nummer ist der Dateiname und zugleich die LaMetric-Nummer — sie muss eindeutig sein.")
                .font(.caption2).foregroundStyle(.secondary)

            if let meldung {
                Text(meldung).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    /// Die waagrechte Leiste der Einzelbilder — mehrere ergeben beim Sichern ein
    /// animiertes GIF. Das gerade bearbeitete ist hervorgehoben.
    private var bildleiste: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(bilder.indices, id: \.self) { i in
                            bildVorschau(i)
                        }
                    }
                }
                Button("+") {
                    bilder.append([String?](repeating: nil, count: 64))
                    aktuellesBild = bilder.count - 1
                }
                .help("Leeres Bild anhängen")
                Button("Verdoppeln") {
                    bilder.insert(bilder[aktuellesBild], at: aktuellesBild + 1)
                    aktuellesBild += 1
                }
                Button("Entfernen", role: .destructive) { bildEntfernen() }
                    .disabled(bilder.count <= 1)
            }
            HStack {
                Button { verschieben(-1) } label: { Image(systemName: "arrow.left") }
                    .disabled(aktuellesBild == 0)
                Button { verschieben(1) } label: { Image(systemName: "arrow.right") }
                    .disabled(aktuellesBild == bilder.count - 1)
                Text("Verzögerung")
                TextField("", value: $verzoegerung, format: .number)
                    .frame(width: 50)
                Text("s")
                Button(spielAb ? "Stopp" : "Abspielen") { abspielenUmschalten() }
                    .disabled(bilder.count < 2)
                Spacer()
            }
        }
    }

    private func bildVorschau(_ i: Int) -> some View {
        Canvas { kontext, groesse in
            let kante = groesse.width / 8
            for y in 0..<8 {
                for x in 0..<8 {
                    let feld = CGRect(x: Double(x) * kante, y: Double(y) * kante, width: kante, height: kante)
                    let p = bilder[i][y * 8 + x]
                    kontext.fill(Path(feld), with: .color(p.flatMap(Color.init(hex:)) ?? .black))
                }
            }
        }
        .frame(width: 28, height: 28)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3)
            .stroke(aktuellesBild == i ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: aktuellesBild == i ? 2 : 1))
        .onTapGesture { stoppeAbspielen(); aktuellesBild = i }
    }

    private func bildEntfernen() {
        guard bilder.count > 1 else { return }
        bilder.remove(at: aktuellesBild)
        aktuellesBild = min(aktuellesBild, bilder.count - 1)
    }

    private func verschieben(_ richtung: Int) {
        let ziel = aktuellesBild + richtung
        guard bilder.indices.contains(ziel) else { return }
        bilder.swapAt(aktuellesBild, ziel)
        aktuellesBild = ziel
    }

    /// Laeuft die Leiste in Schleife durch, solange „Abspielen" gedrueckt ist —
    /// nur zur Ansicht, ohne dass vorher gesichert werden muss.
    private func abspielenUmschalten() {
        guard !spielAb else { stoppeAbspielen(); return }
        spielAb = true
        spielTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(max(0.05, verzoegerung)))
                guard !Task.isCancelled, bilder.count > 1 else { continue }
                await MainActor.run { aktuellesBild = (aktuellesBild + 1) % bilder.count }
            }
        }
    }

    private func stoppeAbspielen() {
        spielAb = false
        spielTask?.cancel()
        spielTask = nil
    }

    private var nummerFeld: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nummer").font(.caption).foregroundStyle(.secondary)
            TextField("Nummer", text: $nummer).frame(minWidth: 90)
        }
    }

    private var nameFeld: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Name").font(.caption).foregroundStyle(.secondary)
            TextField("Name", text: $name).frame(minWidth: 140)
        }
    }

    private var sichernKnopf: some View {
        Button("Sichern") { sichern() }
            .keyboardShortcut(.defaultAction)
            .disabled(nummer.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private var gefilterte: [Icon] { vorhandene.gefiltert(nach: suche) }

    private var seitenleiste: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorhandene Icons").font(.headline)
            Link("LaMetric Icon Gallery", destination: URL(string: "https://developer.lametric.com/icons")!)
                .font(.caption)
            HStack {
                TextField("LaMetric-Nummer", text: $lametricNummer)
                    .frame(width: 140)
                    .onSubmit { nachladen() }
                Button(laedt ? "Hole…" : "Nachladen") { nachladen() }
                    .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Nummer von developer.lametric.com — das Icon landet bei den eigenen.")
                .font(.caption).foregroundStyle(.secondary)
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
            TextField("Suchen", text: $suche)
                .textFieldStyle(.roundedBorder)
            List(gefilterte, id: \.nummer) { icon in
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
                    // Nur eigene Icons duerfen geloescht werden — mitgelieferte
                    // liegen im App-Bundle, ein Versuch schluege ohnehin fehl.
                    if sammlung.istEigen(icon) {
                        Button { zuLoeschen = icon } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("„\(icon.name)“ löschen")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { oeffnen(icon) }
                .contextMenu {
                    Button("Öffnen") { oeffnen(icon) }
                    if sammlung.istEigen(icon) {
                        Button("Löschen", role: .destructive) { zuLoeschen = icon }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 240)
        .onAppear { vorhandene = sammlung.alle() }
        .confirmationDialog(
            "„\(zuLoeschen?.name ?? "")“ löschen?",
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            presenting: zuLoeschen
        ) { icon in
            Button("Löschen", role: .destructive) { loeschen(icon) }
        } message: { icon in
            Text("Das Icon „\(icon.name)“ wird endgültig entfernt.")
        }
    }

    /// Laedt ein Icon zurueck ins Raster — bei einem animierten alle Einzelbilder,
    /// nicht nur das erste. Groesseres wird auf 8×8 gerechnet — die Uhr zeigt
    /// ohnehin nur 8×8.
    private func oeffnen(_ icon: Icon) {
        stoppeAbspielen()
        do {
            // Schwarz bleibt Schwarz. Beim Sichern wird „aus“ zu Schwarz, weil GIF hier
            // keine Durchsichtigkeit traegt und die Uhr ohnehin schwarzen Grund hat —
            // nach einem Rundlauf sind „aus“ und „schwarz gemalt“ deshalb dasselbe und
            // nicht mehr auseinanderzuhalten. Ein schwarzes Pixel hier zu leeren waere
            // kein Rueckweg, sondern Verlust: was schwarz gemalt war, waere weg.
            let gelesen = try sammlung.einzelbilder(fuer: icon)
            bilder = gelesen.map(\.pixel)
            // Die Standzeit kommt aus der Datei, nicht aus dem Anfangswert —
            // sonst zeigt das Feld beim Oeffnen immer 0,2 und ueberschreibt die
            // gesicherte Zeit beim naechsten Sichern still.
            if let erste = gelesen.first?.dauer, erste > 0 { verzoegerung = erste }
        } catch {
            meldung = "Dieses Icon lässt sich nicht öffnen."
            return
        }
        aktuellesBild = 0
        nummer = icon.nummer
        name = icon.name
        meldung = bilder.count > 1
            ? "\(icon.name) geöffnet (\(bilder.count) Bilder)."
            : "\(icon.name) geöffnet."
    }

    private func sichern() {
        let n = nummer.trimmingCharacters(in: .whitespaces)
        do {
            let icon = try sammlung.sichern(nummer: n, name: name.isEmpty ? n : name,
                                            bilder: bilder, verzoegerung: verzoegerung)
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

    /// Liest die zuvor per „Datei einlesen…" gewaehlte Datei unter der im Blatt
    /// eingetragenen Nummer und Namen ein. Der Hinweis auf eine Umrechnung
    /// nennt die Originalgroesse nur, wenn tatsaechlich gerechnet wurde.
    private func einlesen() {
        guard let datei = importDatei else { return }
        let n = importNummer.trimmingCharacters(in: .whitespaces)
        let name = importName.trimmingCharacters(in: .whitespaces)
        do {
            let icon = try sammlung.einfuegen(datei: datei, nummer: n, name: name.isEmpty ? n : name)
            vorhandene = sammlung.alle()
            zeigeImportBlatt = false
            if let groesse = importGroesse, groesse != (8, 8) {
                meldung = "\(icon.name) eingelesen. Das Bild wurde von \(groesse.breite)×\(groesse.hoehe) auf 8×8 gerechnet."
            } else {
                meldung = "\(icon.name) eingelesen."
            }
            zustand.log("Icon eingelesen: \(icon.name)")
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func loeschen(_ icon: Icon) {
        do {
            try sammlung.loeschen(icon)
            vorhandene = sammlung.alle()
            if nummer == icon.nummer {
                // War das geloeschte Icon gerade geoeffnet, bleibt das Bild im
                // Raster stehen, aber Nummer und Name werden geleert — sonst
                // sichert man aus Versehen wieder unter demselben Namen.
                nummer = ""
                name = ""
            }
            meldung = "\(icon.name) gelöscht."
        } catch {
            meldung = "Mitgelieferte Icons lassen sich nicht löschen."
        }
    }
}
