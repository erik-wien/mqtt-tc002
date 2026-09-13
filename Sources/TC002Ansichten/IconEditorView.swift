import SwiftUI
import TC002Core
import TC002Modell
import UniformTypeIdentifiers

/// Der Bereich „Icons": Bildchen malen, die unter „Senden" neben dem Text
/// stehen. Editor links, die vorhandenen Icons als Liste rechts.
///
/// Gemalt wird mit demselben Editor wie im Bereich „Bilder" (`PixelEditor`) —
/// dasselbe Malprinzip, dieselbe Bildleiste, dieselbe Verzoegerung. Hier steht
/// nur, was den Icons eigen ist: Nummer und Name, die Ablage, LaMetric.
///
/// **Zwei Groessen, zwei Bestaende.** 8×8 sind die kanonischen LaMetric-Icons
/// mit Nummer; 16×16 sind es nicht — sie haben nur einen Namen, lassen sich
/// nicht nachladen, liegen in einem eigenen Ordner und gehen ungerechnet auf
/// die Uhr, wo sie die volle Hoehe fuellen. Umgerechnet wird zwischen den
/// beiden nichts.
public struct IconEditorView: View {
    @Bindable var zustand: AppZustand

    public init(zustand: AppZustand) { self.zustand = zustand }

    /// Welche Groesse gerade bearbeitet wird — 8 oder 16. Ueberlebt den
    /// Neustart, damit wer 16×16 malt nicht bei jedem Start umschalten muss.
    @AppStorage("icons.kante") private var kante = 8
    /// Ein oder mehrere Einzelbilder in der Groesse `kante` — mehrere ergeben
    /// beim Sichern ein animiertes GIF.
    @State private var leinwand = Leinwand(breite: 8, hoehe: 8)
    /// Die Groesse, auf die gewechselt werden soll, solange die Rueckfrage
    /// steht — `nil` heisst keine.
    @State private var zuWechseln: Int?
    @State private var farbe = Color(red: 1, green: 1, blue: 1)
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
    /// Steht die Rueckfrage vor „Neu“, weil im Raster noch etwas Ungesichertes
    /// steht.
    @State private var zeigeNeuBestaetigung = false

    /// Zustand fuer „Datei einlesen…": erst die Dateiauswahl, danach ein Blatt
    /// fuer Nummer und Namen mit dem Dateinamen als Vorschlag.
    @State private var zeigeDateiImport = false
    @State private var zeigeImportBlatt = false
    @State private var importDatei: URL?
    @State private var importNummer = ""
    @State private var importName = ""
    @State private var importGroesse: (breite: Int, hoehe: Int)?

    /// Je Groesse ein eigener Ordner — siehe `Iconordner.eigene16`.
    private var sammlung: Iconsammlung { Self.sammlung(kante: kante) }

    private static func sammlung(kante: Int) -> Iconsammlung {
        Iconsammlung(schreibordner: kante == 16 ? Iconordner.eigene16 : Iconordner.eigene,
                     kante: kante)
    }

    /// Ein 16×16 ist kein LaMetric-Icon: keine Nummer, kein Nachladen, kein
    /// Grundschatz. Der Name ist dort zugleich der Dateiname.
    private var kanonisch: Bool { kante == 8 }

    /// Unter welchem Dateinamen gesichert wird. Bei 8×8 die eingetragene
    /// Nummer, bei 16×16 der Name — dort gibt es keine Nummer.
    private var schluessel: String {
        kanonisch ? nummer.trimmingCharacters(in: .whitespaces) : Dateiname.aus(name)
    }

    public var body: some View {
        // `HSplitView` — die vom Nutzer verschiebbare Trennlinie — gibt es nur
        // am Mac. Unter iOS bleibt die Aufteilung dieselbe, nur ohne Griff.
        Group {
            #if os(macOS)
            HSplitView {
                editor
                seitenleiste
            }
            #else
            HStack(spacing: 0) {
                editor
                seitenleiste
            }
            #endif
        }
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

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Icon malen").font(.headline)
                Spacer()
                groessenwahl
            }

            PixelEditor(leinwand: $leinwand, farbe: $farbe) {
                Button("Neu") { neuAnfragen() }
                    .help("Beginnt ein neues Icon: Raster, Nummer und Name werden geleert.")
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    if kanonisch { nummerFeld }
                    nameFeld
                    sichernKnopf
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { if kanonisch { nummerFeld }; nameFeld }
                    sichernKnopf
                }
            }
            Text(kanonisch
                 ? lok("Die Nummer ist der Dateiname und zugleich die LaMetric-Nummer — sie muss eindeutig sein.")
                 : lok("Ein 16×16 bekommt keine LaMetric-Nummer; der Name ist hier der Dateiname und muss eindeutig sein."))
                .font(.caption2).foregroundStyle(.secondary)

            if let meldung {
                Text(meldung).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .alert("Neues Icon anfangen?", isPresented: $zeigeNeuBestaetigung) {
            Button("Abbrechen", role: .cancel) {}
            Button("Neu anfangen", role: .destructive) { neu() }
        } message: {
            Text("Das gemalte Icon ist nicht gesichert und geht dabei verloren.")
        }
        .alert("Größe wechseln?",
               isPresented: Binding(get: { zuWechseln != nil }, set: { if !$0 { zuWechseln = nil } })) {
            Button("Abbrechen", role: .cancel) { zuWechseln = nil }
            Button("Wechseln", role: .destructive) {
                if let neue = zuWechseln { kanteSetzen(neue) }
                zuWechseln = nil
            }
        } message: {
            Text("Zwischen den Größen wird nichts umgerechnet — das gemalte Icon geht dabei verloren.")
        }
    }

    /// Die Wahl zwischen den beiden Groessen. Umgerechnet wird nichts: Ein
    /// Wechsel beginnt ein neues Icon und fragt vorher nach, wenn im Raster
    /// noch etwas Ungesichertes steht.
    private var groessenwahl: some View {
        Picker("Größe", selection: Binding(get: { kante }, set: { kanteWechseln($0) })) {
            Text("8 × 8").tag(8)
            Text("16 × 16").tag(16)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 160)
        .help("8×8 sind die kanonischen LaMetric-Icons mit Nummer. Ein 16×16 hat keine, füllt auf der Uhr die volle Höhe und belegt achtzehn statt zehn Spalten.")
    }

    private func kanteWechseln(_ neue: Int) {
        guard neue != kante else { return }
        if istLeer { kanteSetzen(neue) } else { zuWechseln = neue }
    }

    private func kanteSetzen(_ neue: Int) {
        kante = neue
        leinwand = Leinwand(breite: neue, hoehe: neue)
        nummer = ""
        name = ""
        meldung = nil
        vorhandene = Self.sammlung(kante: neue).alle()
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
            .disabled(schluessel.isEmpty)
    }

    private var gefilterte: [Icon] { vorhandene.gefiltert(nach: suche) }

    private var seitenleiste: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorhandene Icons").font(.headline)
            if kanonisch {
                Link("LaMetric Icon Gallery", destination: URL(string: "https://developer.lametric.com/icons")!)
                    .font(.caption)
                HStack {
                    TextField("LaMetric-Nummer", text: $lametricNummer)
                        .frame(width: 140)
                        .onSubmit { nachladen() }
                    Button(laedt ? lok("Hole…") : lok("Nachladen")) { nachladen() }
                        .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Nummer von developer.lametric.com — das Icon landet bei den eigenen.")
                    .font(.caption).foregroundStyle(.secondary)
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
            TextField("Suchen", text: $suche)
                .textFieldStyle(.roundedBorder)
            List(gefilterte, id: \.nummer) { icon in
                HStack {
                    Rasterbild(datei: icon.datei, breite: icon.kante, hoehe: icon.kante,
                               kante: 24 / Double(icon.kante))
                    VStack(alignment: .leading) {
                        Text(icon.name)
                        Text(icon.nummer).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { zuLoeschen = icon } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(lokf("„%@“ löschen", icon.name))
                }
                .contentShape(Rectangle())
                .onTapGesture { oeffnen(icon) }
                .contextMenu {
                    Button("Öffnen") { oeffnen(icon) }
                    Button("Löschen", role: .destructive) { zuLoeschen = icon }
                }
            }
            if kanonisch {
                Button("Grundschatz wiederherstellen") { grundschatzWiederherstellen() }
                    .font(.caption)
                    .help("Holt gelöschte Icons des Grundschatzes zurück — Vorhandenes bleibt unangetastet.")
            }
        }
        .padding()
        .frame(minWidth: 240)
        .onAppear { groesseUebernehmen(); vorhandene = sammlung.alle() }
        .confirmationDialog(
            "„\(zuLoeschen?.name ?? "")“ löschen?",
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            presenting: zuLoeschen
        ) { icon in
            Button("Löschen", role: .destructive) { loeschen(icon) }
        } message: { icon in
            Text(lokf("Das Icon „%@“ wird endgültig entfernt.", icon.name))
        }
    }

    /// Laedt ein Icon zurueck ins Raster — bei einem animierten alle
    /// Einzelbilder, nicht nur das erste, und in der Groesse, in der es in
    /// seinem Bestand liegt.
    private func oeffnen(_ icon: Icon) {
        do {
            // Schwarz bleibt Schwarz. Beim Sichern wird „aus“ zu Schwarz, weil GIF hier
            // keine Durchsichtigkeit traegt und die Uhr ohnehin schwarzen Grund hat —
            // nach einem Rundlauf sind „aus“ und „schwarz gemalt“ deshalb dasselbe und
            // nicht mehr auseinanderzuhalten. Ein schwarzes Pixel hier zu leeren waere
            // kein Rueckweg, sondern Verlust: was schwarz gemalt war, waere weg.
            let gelesen = try sammlung.einzelbilder(fuer: icon)
            let kante = icon.kante
            // Die Standzeit kommt aus der Datei, nicht aus dem Anfangswert —
            // sonst zeigt das Feld beim Oeffnen immer 0,2 und ueberschreibt die
            // gesicherte Zeit beim naechsten Sichern still.
            let zeit = gelesen.first.map { $0.dauer > 0 ? $0.dauer : leinwand.verzoegerung }
                ?? leinwand.verzoegerung
            guard let neue = Leinwand(breite: kante, hoehe: kante,
                                      bilder: gelesen.map(\.pixel), verzoegerung: zeit) else {
                meldung = lok("Dieses Icon lässt sich nicht öffnen.")
                return
            }
            leinwand = neue
        } catch {
            meldung = lok("Dieses Icon lässt sich nicht öffnen.")
            return
        }
        nummer = icon.nummer
        name = icon.name
        meldung = leinwand.bilder.count > 1
            ? lokf("%@ geöffnet (%d Bilder).", icon.name, leinwand.bilder.count)
            : lokf("%@ geöffnet.", icon.name)
    }

    /// Ob der Editor gerade leer ist — Raster, Nummer und Name. „Neu“ fragt
    /// nur nach, wenn hier tatsaechlich etwas stuende, das verloren ginge.
    private var istLeer: Bool {
        nummer.trimmingCharacters(in: .whitespaces).isEmpty
            && name.trimmingCharacters(in: .whitespaces).isEmpty
            && leinwand.istLeer
    }

    /// Der Editor soll beim ersten Aufbau die gemerkte Groesse zeigen, nicht
    /// die 8×8 des Anfangswerts von `leinwand`.
    private func groesseUebernehmen() {
        guard leinwand.breite != kante else { return }
        leinwand = Leinwand(breite: kante, hoehe: kante)
    }

    private func neuAnfragen() {
        if istLeer { neu() } else { zeigeNeuBestaetigung = true }
    }

    /// Setzt den Editor auf den Anfangszustand zurueck: ein leeres
    /// Einzelbild, keine Nummer, kein Name, Verzoegerung auf ihren
    /// Anfangswert. Der bisherige Trick — Raster leeren und Nummer/Name von
    /// Hand ueberschreiben — ist damit nicht mehr noetig.
    private func neu() {
        leinwand.zuruecksetzen()
        zuWechseln = nil
        nummer = ""
        name = ""
        meldung = nil
    }

    private func sichern() {
        let n = schluessel
        do {
            let icon = try sammlung.sichern(nummer: n, name: name.isEmpty ? n : name,
                                            bilder: leinwand.bilder,
                                            verzoegerung: leinwand.verzoegerung)
            vorhandene = sammlung.alle()
            meldung = lokf("%@ gesichert.", icon.name)
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
            let sammlung = Iconsammlung(schreibordner: Iconordner.eigene)
            do {
                let icon = try sammlung.holen(nummer: n)
                let liste = sammlung.alle()
                await MainActor.run {
                    vorhandene = liste
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
            if let groesse = importGroesse, groesse != (kante, kante) {
                meldung = lokf("%@ eingelesen. Das Bild wurde von %d×%d auf %d×%d gerechnet.", icon.name, groesse.breite, groesse.hoehe, kante, kante)
            } else {
                meldung = lokf("%@ eingelesen.", icon.name)
            }
            zustand.log("Icon eingelesen: \(icon.name)")
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Holt mitgelieferte Icons zurueck, die im Schreibordner fehlen — etwa
    /// nach dem Loeschen. Vorhandene Dateien bleiben unberuehrt; die Meldung
    /// nennt die Anzahl, damit „nichts passiert“ nicht wie ein Fehlschlag wirkt.
    private func grundschatzWiederherstellen() {
        let quelle = Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
        let anzahl = quelle.mitgelieferteUebernehmen()
        vorhandene = sammlung.alle()
        meldung = anzahl > 0
            ? lokf("%d Icons aus dem Grundschatz wiederhergestellt.", anzahl)
            : lok("Nichts zu holen — der Grundschatz ist vollständig da.")
    }

    private func loeschen(_ icon: Icon) {
        do {
            try sammlung.loeschen(icon)
            vorhandene = sammlung.alle()
            if schluessel == icon.nummer {
                // War das geloeschte Icon gerade geoeffnet, bleibt das Bild im
                // Raster stehen, aber Nummer und Name werden geleert — sonst
                // sichert man aus Versehen wieder unter demselben Namen.
                nummer = ""
                name = ""
            }
            meldung = lokf("%@ gelöscht.", icon.name)
        } catch {
            // Hier kommt nur noch ein Dateisystemfehler an — Rechte, Datei schon
            // weg —, keine Herkunftsfrage: die Sammlung kennt nur den eigenen Ordner.
            meldung = (error as? LocalizedError)?.errorDescription ?? lok("Das Icon ließ sich nicht löschen.")
        }
    }
}
