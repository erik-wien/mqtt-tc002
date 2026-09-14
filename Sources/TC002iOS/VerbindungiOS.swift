import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Uhren und Broker einrichten. Eine Liste im Hochformat; die Mac-Fassung
/// bringt dieselben Felder in einem Fenster unter, hier stehen sie in
/// Abschnitten untereinander.
struct VerbindungiOS: View {
    @Bindable var zustand: AppZustand
    @State private var neueAdresse = ""
    @Environment(\.dismiss) private var schliessen
    /// `.numberPad` hat keine Eingabetaste — ohne Tastaturleiste kaeme man aus
    /// dem Port-Feld nur durch Tippen daneben heraus.
    @FocusState private var portFokus: Bool
    @State private var zeigeHilfe = false
    @State private var zeigeUeber = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                Form {
                    uhrenAbschnitt
                    brokerAbschnitt
                    Wolkenabschnitt(zustand: zustand, fussnote: .caption)
                    ueberAbschnitt
                }
            }
            .navigationTitle("Einstellungen")
            // Format- und Icon-Blatt haben "Fertig" bzw. "Abbrechen" in der
            // Titelleiste, dieses hatte nur den Greifer — uneinheitlich, und
            // ohne ausdruecklichen Weg hinaus.
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $zeigeHilfe) { HilfeiOS() }
        .sheet(isPresented: $zeigeUeber) { UeberiOS() }
        // Wischt man das Blatt weg, ohne „Sichern und prüfen“ zu drücken, ginge
        // ein eben erst eingetipptes Kennwort sonst verloren — es stünde nur im
        // Speicher, nicht im Schlüsselbund. Dasselbe Netz wie am Mac.
        .onDisappear { zustand.kennwortSichern() }
    }

    private var uhrenAbschnitt: some View {
        Section("Uhren") {
            ForEach($zustand.uhren) { $uhr in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(uhr.name)
                        Spacer()
                        if zustand.verbunden[uhr.id] == true {
                            Image(systemName: "checkmark.circle").foregroundStyle(.green)
                        } else if zustand.verbunden[uhr.id] == false {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }
                    Text(uhr.host).font(.caption).foregroundStyle(.secondary)
                    // Nur im MQTT-Betrieb: Bei einer HTTP-Uhr stuende hier
                    // „noch nicht abgefragt" und schickte jemanden hinter ein
                    // Praefix her, das diese Uhr nie braucht.
                    if uhr.wirksameBetriebsart == .mqtt {
                        Text(uhr.praefix.isEmpty ? lok("noch nicht abgefragt") : uhr.praefix)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Picker("Betriebsart", selection: betriebsart($uhr)) {
                        Text("HTTP").tag(Betriebsart.http)
                        Text("MQTT").tag(Betriebsart.mqtt)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    // **Am Telefon war die Geraeteart bis zum 14.09.2026 gar
                    // nicht zu stellen.** Am Mac gibt es den Waehler, hier gab
                    // es nur „Abfragen" — und das kommt an eine Uhr, die nur
                    // ueber MQTT erreichbar ist oder deren Schnittstelle eine
                    // Anmeldung verlangt, gar nicht heran. Wer die AWTRIX NG
                    // hier eintrug, hatte damit eine Uhr, die als Werksfirmware
                    // galt: Die App schickte auf `<Praefix>/custom/…` statt auf
                    // `<Praefix>/cmd/apps/pushed/…`, NG antwortet auf ein Thema
                    // ohne Route nicht, und auf der Uhr erschien nichts.
                    Picker("Geräteart", selection: geraeteart($uhr)) {
                        ForEach([Geraetetyp.tc002, .awtrixNG], id: \.self) { art in
                            Text(art.beschriftung).tag(art)
                        }
                    }
                    HStack {
                        Button("Abfragen") { zustand.abfragen(uhr.id) }
                            .knopfBefehl()
                        Spacer()
                        Button("Entfernen", role: .destructive) { zustand.uhrEntfernen(uhr.id) }
                            .knopfZerstoerend()
                    }
                    .font(.callout)
                }
            }
            HStack {
                // Beispiel statt Beschreibung — dieselbe Ueberlegung wie am
                // Mac: Man sieht sofort, dass eine IP-Adresse gemeint ist.
                TextField("z. B. 192.168.0.10", text: $neueAdresse)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { hinzufuegen() }
                Button("Hinzufügen") { hinzufuegen() }
                    .knopfBefehl()
                    .disabled(neueAdresse.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("HTTP meldet zurück, ob die Uhr die Anzeige angenommen hat. MQTT meldet das nie, liest dafür mit, was andere an dieselbe Uhr schicken.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Das Präfix ermittelt die App selbst und stellt dabei auch fest, was für ein Gerät antwortet. Bei einer Ulanzi ist es das eingestellte plus die letzten vier Stellen der MAC-Adresse, bei einer AWTRIX NG genau das eingestellte. Es gehört zum MQTT-Betrieb.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Die Betriebsart als nicht-wahlfreie Wahl fuer den Picker — dieselbe
    /// Ueberlegung wie in der Mac-Fassung: Das Optional ist ein Dateiformat,
    /// die Oberflaeche sieht nur zwei Faelle, und wer waehlt, schreibt einen
    /// Wert ausdruecklich hinein.
    /// Die Geraeteart als nicht-wahlfreie Wahl — wortgleich zur Mac-Fassung
    /// (`VerbindungView.geraeteart`), damit beide Oberflaechen dasselbe tun:
    /// `Uhr.typ` ist ein `Optional`, weil es ein Dateiformat ist, gelesen wird
    /// es ueber `gattung`, und wer waehlt, schreibt einen Wert ausdruecklich
    /// hinein.
    private func geraeteart(_ uhr: Binding<Uhr>) -> Binding<Geraetetyp> {
        Binding(get: { uhr.wrappedValue.gattung },
                set: { neu in
                    guard neu != uhr.wrappedValue.gattung else { return }
                    uhr.wrappedValue.typ = neu
                    zustand.geraeteartGeaendert(uhr.wrappedValue.id)
                })
    }

    private func betriebsart(_ uhr: Binding<Uhr>) -> Binding<Betriebsart> {
        Binding(get: { uhr.wrappedValue.wirksameBetriebsart },
                set: { neu in
                    guard neu != uhr.wrappedValue.wirksameBetriebsart else { return }
                    uhr.wrappedValue.betriebsart = neu
                    zustand.betriebsartGeaendert(uhr.wrappedValue.id)
                })
    }

    /// Hilfe und Über am Fuß der Einstellungen. iOS stellt für „Über“ keine
    /// Stelle bereit — macOS hat das Apple-Menü, hier gibt es nichts
    /// dergleichen —, und die eingebürgerte Stelle ist das Ende der
    /// App-eigenen Einstellungen. Die obere Leiste der Sendeansicht bleibt
    /// bei ihren zwei Symbolen: ein drittes Fragezeichen ist auf dem iPhone
    /// kein verbreitetes Muster.
    private var ueberAbschnitt: some View {
        Section {
            // Zwei Listenzeilen, keine Befehlsknoepfe: Sie fuehren weiter,
            // statt etwas zu tun, und eine Formularzeile ist auf dem Telefon
            // selbst schon als antippbar zu erkennen. Ausdruecklich
            // `.automatic`, damit die Entscheidung im Quelltext steht.
            Button("Hilfe") { zeigeHilfe = true }
                .buttonStyle(.automatic)
            Button("Über MQTT-TC002") { zeigeUeber = true }
                .buttonStyle(.automatic)
        }
    }

    private var brokerAbschnitt: some View {
        Section("Broker") {
            // Weiter sichtbar und weiter benutzbar — nur eingeordnet. Die
            // Begruendung steht bei der Mac-Fassung, sie gilt hier genauso:
            // Ein verschwindender Abschnitt liesse das Formular springen, ein
            // abgeblendeter verhinderte, den Broker **vor** dem Umstellen
            // einer Uhr einzutragen.
            if !Einstellungen.brokerNoetig(fuer: zustand.uhren) {
                Text("Zurzeit steht keine Uhr auf MQTT — dann wird hier nichts davon gebraucht. Eingetragen werden darf es trotzdem, und es gilt, sobald eine Uhr umgestellt wird.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            // Beschriftet waren die vier Felder hier schon; was fehlte, war
            // der Platzhalter, der nach dem Leeren der Vorgaben sichtbar wird.
            // Die Beschriftung links sagt, was das Feld ist, das Beispiel
            // rechts, wie ein Wert darin aussieht.
            LabeledContent("Adresse") {
                TextField("z. B. 192.168.0.20", text: $zustand.brokerHost)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Port") {
                TextField("Port", text: $zustand.brokerPort)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($portFokus)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            // Nur beim Port: `.keyboard` gilt sonst fuer jede
                            // Tastatur dieses Blattes, auch fuer Adresse,
                            // Benutzer und Kennwort, die ihre Eingabetaste
                            // schon haben.
                            if portFokus {
                                Spacer()
                                Button("Fertig") { portFokus = false }
                            }
                        }
                    }
            }
            LabeledContent("Benutzer") {
                TextField("z. B. pixdeck", text: $zustand.benutzer)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Kennwort") {
                SecureField("Kennwort", text: $zustand.kennwort)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { zustand.kennwortSichern() }
            }
            Button("Sichern und prüfen") { zustand.brokerSichernUndPruefen() }
                .knopfBefehl()
            standText
            Text("Das Kennwort liegt im Schlüsselbund, nicht in den Einstellungen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var standText: some View {
        switch zustand.brokerStand {
        case .unbekannt: Text("noch nicht geprüft").foregroundStyle(.secondary)
        case .laeuft: HStack { ProgressView(); Text("wird geprüft …") }
        case .angenommen: Text("angenommen").foregroundStyle(.green)
        case .abgelehnt(let grund): Text(grund).foregroundStyle(.red)
        }
    }

    private func hinzufuegen() {
        let adresse = neueAdresse.trimmingCharacters(in: .whitespaces)
        guard !adresse.isEmpty else { return }
        zustand.uhrHinzufuegen(host: adresse)
        neueAdresse = ""
    }
}
