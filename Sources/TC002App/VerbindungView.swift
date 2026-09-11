import SwiftUI
import TC002Core

struct VerbindungView: View {
    @Bindable var zustand: AppZustand
    @State private var neuerHost = ""
    /// Das Kennwort wandert beim Verlassen des Feldes in den Schluesselbund, nicht
    /// bei jedem Tastendruck.
    @FocusState private var kennwortFokus: Bool

    @State private var seitenwechsel = 0
    @State private var geladen = false
    /// Kennzeichen fuer den gelesenen Wert: das folgende .onChange stammt dann vom
    /// Laden, nicht vom Nutzer, und darf nicht zurueckschreiben.
    @State private var ladeLauf = false
    /// Waehlt der Nutzer, waehrend die Abfrage noch unterwegs ist, darf der spaeter
    /// eintreffende gelesene Wert seine Wahl nicht ueberschreiben.
    @State private var nutzerHatGewaehlt = false

    /// `scrollSpeed` — dieselben drei Zustaende wie bei `seitenwechsel` oben,
    /// nur fuer ein zweites Feld derselben Konfiguration.
    @State private var scrollTempo = 0
    @State private var scrollLadeLauf = false
    @State private var nutzerHatScrollGewaehlt = false

    var body: some View {
        Form {
            Section("Uhren") {
                ForEach($zustand.uhren) { $uhr in
                    HStack {
                        Button {
                            zustand.aktiveID = uhr.id
                        } label: {
                            Image(systemName: zustand.aktiveID == uhr.id ? "largecircle.fill.circle" : "circle")
                        }
                        .buttonStyle(.plain)
                        .help("Diese Uhr ist das Ziel beim Senden")

                        TextField("Name", text: $uhr.name).frame(width: 140)
                        TextField("Adresse", text: $uhr.host).frame(width: 130)
                            .onChange(of: uhr.host) { _, _ in zustand.adresseGeaendert(uhr.id) }
                        Text(uhr.praefix.isEmpty ? "—" : uhr.praefix)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if let steht = zustand.verbunden[uhr.id] {
                            Image(systemName: steht ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundStyle(steht ? .green : .orange)
                                .help(steht ? "Am Broker angemeldet" : "Nicht am Broker angemeldet")
                        }
                        Spacer()
                        Button("Abfragen") { zustand.abfragen(uhr.id) }
                        Button("Entfernen", role: .destructive) { zustand.uhrEntfernen(uhr.id) }
                    }
                }
                HStack {
                    TextField("Adresse einer weiteren Uhr", text: $neuerHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 220)
                        .onSubmit { uhrHinzufuegen() }
                    Button("Hinzufügen") { uhrHinzufuegen() }
                }
                Text("Das Präfix ermittelt die App selbst — es ist das eingestellte plus die letzten vier Stellen der MAC-Adresse.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Einstellungen der aktiven Uhr") {
                Picker("Seitenwechsel", selection: $seitenwechsel) {
                    Text("kein Wechsel").tag(0)
                    ForEach([10, 20, 30, 60], id: \.self) { Text("alle \($0) Sekunden").tag($0) }
                }
                .onChange(of: seitenwechsel) { _, neu in
                    guard !ladeLauf else { ladeLauf = false; return }
                    nutzerHatGewaehlt = true
                    setzen("carouselSpeed", neu)
                }
                Stepper("Scrolltempo: \(scrollTempo)", value: $scrollTempo, in: 0...20)
                    .help("Lauftempo für Text, den die Uhr selbst setzt (unter „Senden“ der Weg „vom Gerät setzen“). Der gültige Wertebereich ist nicht dokumentiert.")
                    .onChange(of: scrollTempo) { _, neu in
                        guard !scrollLadeLauf else { scrollLadeLauf = false; return }
                        nutzerHatScrollGewaehlt = true
                        setzen("scrollSpeed", neu)
                    }
            }
            Section("Broker") {
                TextField("Adresse", text: $zustand.brokerHost)
                TextField("Port", text: $zustand.brokerPort)
                TextField("Benutzer", text: $zustand.benutzer)
                SecureField("Kennwort", text: $zustand.kennwort)
                    .focused($kennwortFokus)
                    .onSubmit { zustand.kennwortSichern() }
                    .onChange(of: kennwortFokus) { _, hat in if !hat { zustand.kennwortSichern() } }
                Text("Das Kennwort liegt im Schlüsselbund, nicht in den Einstellungen.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("Sichern und prüfen") { zustand.brokerSichernUndPruefen() }
                        .disabled(zustand.brokerStand == .laeuft)
                    brokerStandAnzeige
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        // Fokuswechsel ist nicht zugesichert, wenn diese Ansicht durch einen
        // Bereichswechsel zerstoert wird — ohne dieses Netz ginge ein eben erst
        // eingetipptes Kennwort dabei verloren.
        .onDisappear { zustand.kennwortSichern() }
        .task {
            guard !geladen else { return }
            geladen = true
            guard let host = zustand.aktiveUhr?.host else { return }
            // .task laeuft auf dem Hauptthread, konfiguration() blockiert bis zur Antwort
            // der Uhr. Ohne den losgeloesten Task steht das Fenster so lange still.
            // Ein Abruf fuer beide Felder statt zweier — sie stehen ohnehin in
            // derselben Antwort.
            let ergebnis: (carousel: Int?, scroll: Int?, fehler: String?) = await Task.detached {
                do {
                    let k = try Geraet(host: host).konfiguration()
                    return (k["carouselSpeed"] as? Int, k["scrollSpeed"] as? Int, nil)
                } catch { return (nil, nil, (error as? LocalizedError)?.errorDescription ?? "\(error)") }
            }.value
            // Ohne Meldung zeigte der Picker nach einem Fehlschlag faelschlich
            // "kein Wechsel" — und sah aus wie eine Einstellung der Uhr.
            if let meldung = ergebnis.fehler {
                zustand.fehler = "Die Einstellungen „Seitenwechsel“ und „Scrolltempo“ ließen sich nicht lesen: \(meldung)"
                return
            }
            // Hat der Nutzer waehrend der Abfrage schon selbst gewaehlt, gilt
            // seine Wahl — der spaet eintreffende gelesene Wert ueberschreibt sie nicht.
            if let wert = ergebnis.carousel {
                if wert != seitenwechsel, !nutzerHatGewaehlt { ladeLauf = true; seitenwechsel = wert }
            } else {
                zustand.fehler = "Die Uhr hat keinen Wert für „Seitenwechsel“ gemeldet."
            }
            if let wert = ergebnis.scroll {
                if wert != scrollTempo, !nutzerHatScrollGewaehlt { scrollLadeLauf = true; scrollTempo = wert }
            } else {
                zustand.fehler = "Die Uhr hat keinen Wert für „Scrolltempo“ gemeldet."
            }
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

    private func uhrHinzufuegen() {
        let host = neuerHost.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        zustand.uhrHinzufuegen(host: host)
        neuerHost = ""
    }

    @ViewBuilder
    private var brokerStandAnzeige: some View {
        switch zustand.brokerStand {
        case .unbekannt:
            Text("noch nicht geprüft")
                .font(.footnote).foregroundStyle(.secondary)
        case .laeuft:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("prüfe…").font(.footnote).foregroundStyle(.secondary)
            }
        case .angenommen:
            Text("Der Broker nimmt die Anmeldung an.")
                .font(.footnote).foregroundStyle(.green)
        case .abgelehnt(let text):
            Text(text)
                .font(.footnote).foregroundStyle(.red)
        }
    }
}
