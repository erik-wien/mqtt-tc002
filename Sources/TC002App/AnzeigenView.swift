import SwiftUI
import TC002Core

struct AnzeigenView: View {
    @Bindable var zustand: AppZustand
    @State private var seitenwechsel = 0
    @State private var geladen = false
    /// Kennzeichen fuer den gelesenen Wert: das folgende .onChange stammt dann vom
    /// Laden, nicht vom Nutzer, und darf nicht zurueckschreiben.
    @State private var ladeLauf = false

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
            Text("Einstellungen der Uhr").font(.headline)
            Picker("Seitenwechsel", selection: $seitenwechsel) {
                Text("kein Wechsel").tag(0)
                ForEach([10, 20, 30, 60], id: \.self) { Text("alle \($0) Sekunden").tag($0) }
            }
            .frame(width: 320)
            .onChange(of: seitenwechsel) { _, neu in
                guard !ladeLauf else { ladeLauf = false; return }
                setzen("carouselSpeed", neu)
            }
            Spacer()
        }
        .padding()
        .task {
            guard !geladen else { return }
            geladen = true
            guard let host = zustand.aktiveUhr?.host else { return }
            // .task laeuft auf dem Hauptthread, konfiguration() blockiert bis zur Antwort
            // der Uhr. Ohne den losgeloesten Task steht das Fenster so lange still.
            let ergebnis: (wert: Int?, fehler: String?) = await Task.detached {
                do { return (try Geraet(host: host).konfiguration()["carouselSpeed"] as? Int, nil) }
                catch { return (nil, (error as? LocalizedError)?.errorDescription ?? "\(error)") }
            }.value
            // Ohne Meldung zeigte der Picker nach einem Fehlschlag faelschlich
            // "kein Wechsel" — und sah aus wie eine Einstellung der Uhr.
            if let meldung = ergebnis.fehler {
                zustand.fehler = "Die Einstellung „Seitenwechsel“ ließ sich nicht lesen: \(meldung)"
            } else if let wert = ergebnis.wert {
                if wert != seitenwechsel { ladeLauf = true; seitenwechsel = wert }
            } else {
                zustand.fehler = "Die Uhr hat keinen Wert für „Seitenwechsel“ gemeldet."
            }
        }
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

    private func setzen(_ feld: String, _ wert: Int) {
        guard let host = zustand.aktiveUhr?.host else { return }
        Task.detached {
            do { try Geraet(host: host).konfigurationSetzen(feld, wert)
                 await MainActor.run { zustand.log("\(feld) auf \(wert) gesetzt") } }
            catch { await MainActor.run { zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)" } }
        }
    }
}
