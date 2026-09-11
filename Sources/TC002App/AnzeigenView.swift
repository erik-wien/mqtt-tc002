import SwiftUI

struct AnzeigenView: View {
    @Bindable var zustand: AppZustand

    var body: some View {
        let liste = zustand.anzeigenDerAktivenMitQuelle()
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Anzeigen").font(.headline)
                // Der Unterschied ist die eigentliche Auskunft: das eine ist
                // Tatsache, das andere Erinnerung.
                Text(liste.quelle == .geraet ? "vom Gerät gemeldet" : "von dieser App angelegt")
                    .font(.caption).foregroundStyle(.secondary)
                    .help(liste.quelle == .geraet
                          ? "Die Uhr veröffentlicht selbst, welche Anzeigen auf ihr stehen — auch solche, die ein anderes Werkzeug angelegt hat."
                          : "Solange die Uhr nichts gemeldet hat, zeigt die Liste, was diese App selbst an sie geschickt hat. Was ein anderes Werkzeug angelegt hat, fehlt darin.")
                if let online = zustand.aktiveID.flatMap({ zustand.geraetOnline[$0] }) {
                    Text(online ? "· Uhr meldet sich online" : "· Uhr meldet sich offline")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if liste.namen.isEmpty {
                Text(liste.quelle == .geraet ? "Die Uhr meldet gerade keine Anzeige."
                                             : "Noch nichts an diese Uhr gesendet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(liste.namen, id: \.self) { name in
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
