import AppKit
import SwiftUI
import TC002Core
import UniformTypeIdentifiers

/// Sammlung mehrerer gemalter 52×16-Bilder unter Namen — die Ablage neben dem
/// einen Arbeitsstand, den „Malen" ohnehin schon ueber Neustarts hinweg
/// behaelt. Baugleich mit `IconAuswahlView`/`ZielauswahlView`: derselbe
/// Blattkopf, derselbe „Schließen"-Knopf, damit sich alles gleich anfuehlt.
struct BilderView: View {
    @Binding var feld: Pixelfeld
    /// Wird nach dem Laden eines Bildes aufgerufen, damit der Aufrufer den
    /// neuen Stand wie gewohnt sichert.
    let nachLaden: () -> Void

    @State private var zeigeBlatt = false
    @State private var bilder: [Gemaltes] = []
    @State private var name = ""
    @State private var zuBestaetigen: Gemaltes?
    @State private var meldung: String?

    /// Zustand fuer „Datei einlesen…": erst die Dateiauswahl, danach ein Blatt
    /// fuer den Namen mit dem Dateinamen als Vorschlag.
    @State private var zeigeDateiImport = false
    @State private var zeigeImportBlatt = false
    @State private var importDatei: URL?
    @State private var importName = ""
    @State private var importGroesse: (breite: Int, hoehe: Int)?

    private var sammlung: Bildersammlung {
        Bildersammlung(ordner: Bilderordner.eigene)
    }

    private var feldIstLeer: Bool {
        feld.punkteRoh.allSatisfy { $0 == nil }
    }

    var body: some View {
        Button("Bilder") {
            bilder = sammlung.alle()
            zeigeBlatt = true
        }
        .sheet(isPresented: $zeigeBlatt) { blatt }
    }

    private var blatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bilder").font(.headline)

            if bilder.isEmpty {
                Text("Noch keine gesicherten Bilder.").font(.callout).foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104))], spacing: 10) {
                    ForEach(bilder, id: \.datei) { bild in
                        VStack(spacing: 4) {
                            if let vorschau = Bildladen.frisch(bild.datei) {
                                Image(nsImage: vorschau).interpolation(.none)
                                    .resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: 88, height: 27)
                                    .background(Color.black)
                            }
                            Text(bild.name).font(.caption).lineLimit(1)
                            Button("Löschen", role: .destructive) { loeschen(bild) }
                                .font(.caption2)
                        }
                        .padding(6)
                        .contentShape(Rectangle())
                        .onTapGesture { anklicken(bild) }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .frame(minHeight: 160)

            if let meldung {
                Text(meldung).font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                TextField("Name", text: $name)
                Button("Sichern") { sichern() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Button("Datei einlesen…") { zeigeDateiImport = true }
                    .fileImporter(isPresented: $zeigeDateiImport,
                                  allowedContentTypes: [.gif, .png, .jpeg]) { ergebnis in
                        guard case .success(let url) = ergebnis else { return }
                        importDatei = url
                        importName = url.deletingPathExtension().lastPathComponent
                        importGroesse = Bildraster.groesse(url)
                        zeigeImportBlatt = true
                    }
                Spacer()
                Button("Schließen") { zeigeBlatt = false }
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 380)
        .sheet(isPresented: $zeigeImportBlatt) { importBlatt }
        .alert("Aktuelles Bild ersetzen?",
               isPresented: Binding(get: { zuBestaetigen != nil }, set: { if !$0 { zuBestaetigen = nil } })) {
            Button("Abbrechen", role: .cancel) { zuBestaetigen = nil }
            Button("Laden", role: .destructive) {
                if let bild = zuBestaetigen { laden(bild) }
                zuBestaetigen = nil
            }
        } message: {
            Text("Das gemalte Bild ist nicht leer und geht dabei verloren.")
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

    private func anklicken(_ bild: Gemaltes) {
        if feldIstLeer { laden(bild) } else { zuBestaetigen = bild }
    }

    private func laden(_ bild: Gemaltes) {
        do {
            feld = try sammlung.laden(bild)
            nachLaden()
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
            meldung = "\(eintrag.name) gesichert."
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
                meldung = "\(eintrag.name) eingelesen. Das Bild wurde von \(groesse.breite)×\(groesse.hoehe) auf \(Pixelfeld.breiteStandard)×\(Pixelfeld.hoeheStandard) gerechnet."
            } else {
                meldung = "\(eintrag.name) eingelesen."
            }
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func loeschen(_ bild: Gemaltes) {
        do {
            try sammlung.loeschen(bild)
            bilder = sammlung.alle()
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
