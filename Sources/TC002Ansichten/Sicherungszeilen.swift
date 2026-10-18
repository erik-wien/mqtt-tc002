import SwiftUI
import UniformTypeIdentifiers
import TC002Core
import TC002Modell

/// Eine Sicherung als Datei, für `fileExporter`. Die App legt sie nirgends selbst
/// ab: Der Anwender wählt den Ort im Systemdialog, denn das Zip enthält Kennwörter
/// im Klartext und gehört nicht automatisch in iCloud.
struct Sicherungsdokument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    static var writableContentTypes: [UTType] { [.zip] }

    var daten: Data

    init(daten: Data) { self.daten = daten }

    init(configuration: ReadConfiguration) throws {
        daten = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: daten)
    }
}

/// Die Zeilen „Sicherung“ im Abschnitt „Gerät“ der Fernbedienung: die Uhr in eine
/// Zip-Datei sichern und aus einer zurückspielen, im Format der Weboberfläche der
/// AWTRIX NG. Beides läuft über HTTP und braucht die Adresse der Uhr; ohne sie
/// sind die Zeilen gesperrt und sagen, woran es liegt. Eine Ansicht für Mac, iPad
/// und iPhone.
///
/// Zurückspielen schreibt sofort auf die Uhr und ist teils nicht rückgängig zu
/// machen: Vorher fragt ein Dialog, nachher zeigt die Ansicht, was die Uhr
/// eingespielt und übersprungen hat, und bietet den Neustart an.
struct Sicherungszeilen: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let kanon: Formkanon

    @State private var fragtSichern = false
    @State private var exportiert: Sicherungsdokument?
    @State private var waehltDatei = false
    @State private var gewaehlt: (zip: Data, name: String, vorschau: Sicherungszip.Vorschau)?
    @State private var ergebnis: Sicherungsergebnis?
    @State private var laeuft = false

    private var adresse: Bool { !uhr.host.isEmpty }

    var body: some View {
        Button("In Datei sichern …") { fragtSichern = true }
            .knopfBefehl()
            .disabled(!adresse || laeuft)
            .confirmationDialog("Sicherung anlegen?", isPresented: $fragtSichern, titleVisibility: .visible) {
                Button("Sichern …") { sichern() }
            } message: {
                Text("Die Sicherung enthält das WLAN-Kennwort, das MQTT-Kennwort und das Kennwort der Weboberfläche im Klartext. Bewahre die Datei wie ein Kennwort auf und lege sie nicht in einem geteilten Ordner ab.")
            }
            .fileExporter(isPresented: Binding(get: { exportiert != nil }, set: { if !$0 { exportiert = nil } }),
                          document: exportiert, contentType: .zip, defaultFilename: dateiname) { _ in }
        Button("Aus Datei zurückspielen …") { waehltDatei = true }
            .knopfBefehl()
            .disabled(!adresse || laeuft)
            .fileImporter(isPresented: $waehltDatei, allowedContentTypes: [.zip]) { wahl in
                guard case .success(let url) = wahl else { return }
                pruefen(url)
            }
            .confirmationDialog(lokf("Sicherung auf „%@“ zurückspielen?", uhr.name),
                                isPresented: Binding(get: { gewaehlt != nil }, set: { if !$0 { gewaehlt = nil } }),
                                titleVisibility: .visible) {
                Button("Zurückspielen", role: .destructive) { zurueckspielen() }
            } message: {
                Text(verbatim: warnung)
            }
            .alert("Sicherung zurückgespielt", isPresented: Binding(get: { ergebnis != nil }, set: { if !$0 { ergebnis = nil } })) {
                if ergebnis?.neustartNoetig == true {
                    Button("Uhr neu starten", role: .destructive) { Task { await zustand.neustarten(fuer: uhr.id) } }
                    Button("Später", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: {
                Text(verbatim: ergebnistext)
            }
        if !adresse {
            Label("Sicherung braucht die Adresse der Uhr", systemImage: "info.circle")
                .font(kanon.fussnote).foregroundStyle(.secondary)
        }
    }

    private var dateiname: String {
        let name = uhr.name.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
        return "Uhr-" + String(name) + "-" + Date().formatted(.iso8601.year().month().day())
    }

    private var warnung: String {
        guard let g = gewaehlt else { return "" }
        var teile: [String] = []
        if let am = g.vorschau.erstelltAm {
            teile.append(lokf("Die Sicherung ist vom %@.", am.formatted(date: .abbreviated, time: .shortened)))
        }
        teile.append(lokf("Sie enthält %d Einträge.", g.vorschau.eintraege))
        teile.append(lok("Zurückspielen schreibt sofort auf die Uhr und ersetzt Einstellungen, WLAN-Zugang und Dateien gleichen Namens. Das ist zum Teil nicht rückgängig zu machen."))
        return teile.joined(separator: " ")
    }

    private var ergebnistext: String {
        guard let e = ergebnis else { return "" }
        var teile = e.zeilen
        if e.uebersprungen > 0 {
            teile.append(lokf("Übersprungen: %d", e.uebersprungen))
        }
        if !e.warnungen.isEmpty {
            teile.append(lok("Warnungen der Uhr:"))
            teile.append(contentsOf: e.warnungen.prefix(8))
            if e.warnungen.count > 8 { teile.append("…") }
        }
        if e.neustartNoetig {
            teile.append(lok("WLAN-Zugang und Systemkonfiguration gelten erst nach einem Neustart der Uhr."))
        }
        return teile.joined(separator: "\n")
    }

    private func sichern() {
        laeuft = true
        Task {
            let zip = await zustand.sicherungErstellen(fuer: uhr.id)
            laeuft = false
            if let zip { exportiert = Sicherungsdokument(daten: zip) }
        }
    }

    private func pruefen(_ url: URL) {
        laeuft = true
        Task {
            let gelesen = await zustand.sicherungLesen(datei: url)
            laeuft = false
            if let gelesen { gewaehlt = (gelesen.zip, url.lastPathComponent, gelesen.vorschau) }
        }
    }

    private func zurueckspielen() {
        guard let g = gewaehlt else { return }
        gewaehlt = nil
        laeuft = true
        Task {
            ergebnis = await zustand.sicherungZurueckspielen(g.zip, name: g.name, fuer: uhr.id)
            laeuft = false
        }
    }
}
