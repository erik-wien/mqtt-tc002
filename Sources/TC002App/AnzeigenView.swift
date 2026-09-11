import SwiftUI

struct AnzeigenView: View {
    @Bindable var zustand: AppZustand

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Angelegte Anzeigen").font(.headline)
            if zustand.anzeigenDerAktiven().isEmpty {
                Text("Noch nichts an diese Uhr gesendet.").foregroundStyle(.secondary)
            }
            ForEach(zustand.anzeigenDerAktiven(), id: \.self) { name in
                HStack {
                    Text(name).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Anzeigen") { umschalten(name) }
                    Button("Löschen", role: .destructive) { loeschen(name) }
                }
            }

            Divider()
            HStack {
                Text("Protokoll").font(.headline)
                Spacer()
                Button("Leeren") { zustand.protokoll.removeAll() }
                    .disabled(zustand.protokoll.isEmpty)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(zustand.protokoll.enumerated()), id: \.offset) { _, zeile in
                        Text(zeile)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(.footnote, design: .monospaced))
        }
        .padding()
    }

    private func umschalten(_ name: String) {
        guard let uhr = zustand.aktiveUhr else {
            zustand.fehler = "Keine Uhr eingerichtet. Unter „Verbindung“ eine eintragen und abfragen."
            return
        }
        guard let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = AppZustand.zugangsmeldung(uhr)
            return
        }
        Task.detached {
            do { try a.umschalten(auf: name); await MainActor.run { zustand.log("umgeschaltet auf \(name)") } }
            catch { await MainActor.run { zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)" } }
        }
    }

    private func loeschen(_ name: String) {
        guard let uhr = zustand.aktiveUhr else {
            zustand.fehler = "Keine Uhr eingerichtet. Unter „Verbindung“ eine eintragen und abfragen."
            return
        }
        guard let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = AppZustand.zugangsmeldung(uhr)
            return
        }
        Task.detached {
            do {
                try a.loeschen(name)
                await MainActor.run {
                    // Nur bei der aktiven Uhr: die leere Nutzlast ging auch nur dorthin.
                    zustand.anzeigeVergessen(name, fuer: uhr.id)
                    zustand.log("gelöscht: \(name)")
                }
            } catch { await MainActor.run { zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)" } }
        }
    }

}
