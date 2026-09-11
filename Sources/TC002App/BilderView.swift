import AppKit
import SwiftUI
import TC002Core

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
                            if let vorschau = NSImage(contentsOf: bild.datei) {
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
                Spacer()
                Button("Schließen") { zeigeBlatt = false }
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 380)
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

    private func loeschen(_ bild: Gemaltes) {
        do {
            try sammlung.loeschen(bild)
            bilder = sammlung.alle()
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
