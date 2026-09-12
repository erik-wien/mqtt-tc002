import SwiftUI
import TC002Core
import TC002Modell

/// Was auf der aktiven Uhr steht, und das Protokoll. Die Logik stammt aus
/// `AnzeigenView` der Mac-Fassung; ersetzt sind nur die Bedienelemente —
/// aus zwei Knöpfen je Zeile werden zwei Wischgesten.
struct AnzeigeniOS: View {
    @Bindable var zustand: AppZustand

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                List {
                    anzeigenAbschnitt
                    protokollAbschnitt
                }
            }
            .navigationTitle("Verlauf")
        }
        .presentationDragIndicator(.visible)
    }

    private var anzeigenAbschnitt: some View {
        let liste = zustand.anzeigenDerAktivenMitQuelle()
        return Section {
            if liste.namen.isEmpty {
                Text(liste.quelle == .geraet ? lok("Die Uhr meldet gerade keine Anzeige.")
                                             : lok("Noch nichts an diese Uhr gesendet."))
                    .foregroundStyle(.secondary)
            }
            ForEach(liste.namen, id: \.self) { name in
                Text(name).font(.system(.body, design: .monospaced))
                    .swipeActions(edge: .trailing) {
                        Button("Löschen", role: .destructive) { loeschen(name) }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Zeigen") { umschalten(name) }.tint(.blue)
                    }
            }
        } header: {
            HStack {
                Text(liste.quelle == .geraet ? lok("vom Gerät gemeldet")
                                             : lok("von dieser App angelegt"))
                if let uhr = zustand.aktiveUhr, let online = zustand.geraetOnline[uhr.id] {
                    Text(online ? lok("· Uhr meldet sich online") : lok("· Uhr meldet sich offline"))
                }
            }
        } footer: {
            Text("Nach links wischen löscht, nach rechts schaltet auf die Anzeige um.")
        }
    }

    private var protokollAbschnitt: some View {
        Section {
            ForEach(Array(zustand.protokoll.enumerated()), id: \.offset) { _, zeile in
                Text(zeile).font(.system(.caption, design: .monospaced))
            }
        } header: {
            HStack {
                Text("Protokoll")
                Spacer()
                Button("Leeren") { zustand.protokoll.removeAll() }.font(.caption)
            }
        }
    }

    private func umschalten(_ name: String) {
        guard let uhr = zustand.aktiveUhr, let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = zustand.zugangsmeldung(zustand.aktiveUhr ?? Uhr(name: "", host: ""))
            return
        }
        Task.detached {
            do {
                try a.umschalten(auf: name)
                await MainActor.run { zustand.log(lokf("umgeschaltet auf %@", name)) }
            } catch {
                await MainActor.run { zustand.melde(error, uhr: uhr) }
            }
        }
    }

    private func loeschen(_ name: String) {
        guard let uhr = zustand.aktiveUhr, let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = zustand.zugangsmeldung(zustand.aktiveUhr ?? Uhr(name: "", host: ""))
            return
        }
        Task.detached {
            do {
                try a.loeschen(name)
                await MainActor.run {
                    zustand.anzeigeVergessen(name, fuer: uhr.id)
                    zustand.log(lokf("gelöscht: %@", name))
                }
            } catch {
                await MainActor.run { zustand.melde(error, uhr: uhr) }
            }
        }
    }
}
