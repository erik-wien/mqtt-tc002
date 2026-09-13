import SwiftUI
import TC002Core
import TC002Modell

public struct AnzeigenView: View {
    @Bindable var zustand: AppZustand

    public init(zustand: AppZustand) { self.zustand = zustand }

    public var body: some View {
        let liste = zustand.anzeigenDerAktivenMitQuelle()
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Anzeigen").font(.headline)
                // Der Unterschied ist die eigentliche Auskunft: das eine ist
                // Tatsache, das andere Erinnerung.
                Text(liste.quelle == .geraet ? lok("vom Gerät gemeldet") : lok("von dieser App angelegt"))
                    .font(.caption).foregroundStyle(.secondary)
                if let online = zustand.aktiveID.flatMap({ zustand.geraetOnline[$0] }) {
                    Text(online ? lok("· Uhr meldet sich online") : lok("· Uhr meldet sich offline"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if liste.namen.isEmpty {
                Text(liste.quelle == .geraet ? lok("Die Uhr meldet gerade keine Anzeige.")
                                             : lok("Noch nichts an diese Uhr gesendet."))
                    .foregroundStyle(.secondary)
            }
            ForEach(liste.namen, id: \.self) { name in
                HStack {
                    Text(name).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Zeigen") { umschalten(name) }
                        .knopfBefehl()
                    Button("Löschen", role: .destructive) { loeschen(name) }
                        .knopfZerstoerend()
                }
            }

            Divider()
            HStack {
                Text("Protokoll").font(.headline)
                Spacer()
                Button("Leeren", role: .destructive) { zustand.protokoll.removeAll() }
                    .knopfZerstoerend()
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
            zustand.fehler = lok("Keine Uhr eingerichtet. Unter „Einstellungen“ eine eintragen und abfragen.")
            return
        }
        guard let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = zustand.zugangsmeldung(uhr)
            return
        }
        Task.detached {
            do { try a.umschalten(auf: name); await MainActor.run { zustand.log(lokf("umgeschaltet auf %@", name)) } }
            catch { await MainActor.run { zustand.melde(error, uhr: uhr) } }
        }
    }

    private func loeschen(_ name: String) {
        guard let uhr = zustand.aktiveUhr else {
            zustand.fehler = lok("Keine Uhr eingerichtet. Unter „Einstellungen“ eine eintragen und abfragen.")
            return
        }
        guard let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = zustand.zugangsmeldung(uhr)
            return
        }
        Task.detached {
            do {
                try a.loeschen(name)
                await MainActor.run {
                    // Nur bei der aktiven Uhr: die leere Nutzlast ging auch nur dorthin.
                    zustand.anzeigeGeloescht(name, fuer: uhr)
                    zustand.log(lokf("gelöscht: %@", name))
                }
            } catch { await MainActor.run { zustand.melde(error, uhr: uhr) } }
        }
    }

}
