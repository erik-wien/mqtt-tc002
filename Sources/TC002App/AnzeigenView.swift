import SwiftUI
import TC002Core

struct AnzeigenView: View {
    @Bindable var zustand: AppZustand
    @State private var seitenwechsel = 0
    @State private var geladen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Angelegte Anzeigen").font(.headline)
            if zustand.bekannteAnzeigen.isEmpty {
                Text("Noch nichts gesendet.").foregroundStyle(.secondary)
            }
            ForEach(zustand.bekannteAnzeigen, id: \.self) { name in
                HStack {
                    Text(name).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Anzeigen") { umschalten(name) }
                    Button("Löschen", role: .destructive) { loeschen(name) }
                }
            }

            Divider()
            Text("Einstellungen der Uhr").font(.headline)
            Picker("Seitenwechsel", selection: $seitenwechsel) {
                Text("kein Wechsel").tag(0)
                ForEach([10, 20, 30, 60], id: \.self) { Text("alle \($0) Sekunden").tag($0) }
            }
            .frame(width: 320)
            .onChange(of: seitenwechsel) { _, neu in setzen("carouselSpeed", neu) }
            Spacer()
        }
        .padding()
        .task {
            guard !geladen else { return }
            geladen = true
            guard let host = zustand.aktiveUhr?.host else { return }
            // .task laeuft auf dem Hauptthread, konfiguration() blockiert bis zur Antwort
            // der Uhr. Ohne den losgeloesten Task steht das Fenster so lange still.
            let wert: Int? = await Task.detached {
                guard let k = try? Geraet(host: host).konfiguration() else { return nil }
                return k["carouselSpeed"] as? Int
            }.value
            if let wert { seitenwechsel = wert }
        }
    }

    private func umschalten(_ name: String) {
        guard let uhr = zustand.aktiveUhr, let a = zustand.anzeigen(fuer: uhr) else { return }
        Task.detached {
            do { try a.umschalten(auf: name); await MainActor.run { zustand.log("umgeschaltet auf \(name)") } }
            catch { await MainActor.run { zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)" } }
        }
    }

    private func loeschen(_ name: String) {
        guard let uhr = zustand.aktiveUhr, let a = zustand.anzeigen(fuer: uhr) else { return }
        Task.detached {
            do {
                try a.loeschen(name)
                await MainActor.run {
                    zustand.bekannteAnzeigen.removeAll { $0 == name }
                    zustand.log("gelöscht: \(name)")
                }
            } catch { await MainActor.run { zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)" } }
        }
    }

    private func setzen(_ feld: String, _ wert: Int) {
        guard let host = zustand.aktiveUhr?.host else { return }
        Task.detached {
            do { try Geraet(host: host).konfigurationSetzen(feld, wert)
                 await MainActor.run { zustand.log("\(feld) auf \(wert) gesetzt") } }
            catch { await MainActor.run { zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)" } }
        }
    }
}
