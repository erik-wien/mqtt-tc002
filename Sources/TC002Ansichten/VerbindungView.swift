import SwiftUI
import TC002Core
import TC002Modell

public struct VerbindungView: View {
    @Bindable var zustand: AppZustand

    public init(zustand: AppZustand) { self.zustand = zustand }
    @State private var neuerHost = ""
    /// Das Kennwort wandert beim Verlassen des Feldes in den Schluesselbund, nicht
    /// bei jedem Tastendruck.
    @FocusState private var kennwortFokus: Bool

    public var body: some View {
        Form {
            Section("Uhren") {
                ForEach($zustand.uhren) { $uhr in
                    // **Zwei Zeilen, nicht eine.** Neun Bedienelemente in einer
                    // Reihe brauchen rund 820 Punkte; der Kasten eines
                    // gruppierten Formulars ist am Mac aber bei 704 gedeckelt
                    // und zentriert — gemessen am 14.09.2026 offscreen, bei 900
                    // und bei 1200 Punkten Fensterbreite derselbe Kasten.
                    // `.frame(maxWidth: .infinity)` hilft nicht, der Deckel
                    // sitzt im Stil. Uebrig blieb eine Zeile, in der „Abfragen"
                    // und „Entfernen" zu „A…" und „E…" zusammenschnurrten und
                    // das Praefix ueber zwei Zeilen brach.
                    //
                    // Oben steht, was die Uhr **ist**, unten, was sie gerade
                    // **meldet** und was man mit ihr **tut**.
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button {
                                zustand.aktiveID = uhr.id
                            } label: {
                                Image(systemName: zustand.aktiveID == uhr.id ? "largecircle.fill.circle" : "circle")
                            }
                            .buttonStyle(.plain)
                            // **Nicht „das Ziel beim Senden"**, und genau so stand
                            // es bis zum 14.09.2026 hier. Das stimmt nur, solange
                            // niemand unter „Senden" ein eigenes Ziel gewaehlt hat
                            // (`AppZustand.ziele()` faellt dann auf die aktive Uhr
                            // zurueck). Wovon die Wahl **immer** entscheidet, ist,
                            // welche Uhr die App zeigt — und wer das verwechselt,
                            // sucht die Erklaerung fuer einen falschen
                            // Geraeterahmen an der falschen Stelle.
                            .help("Die angesehene Uhr: Vorschau, Geräterahmen, die fünf Blöcke und der Zeit-Reiter beziehen sich auf sie")
                            .accessibilityLabel("Diese Uhr ansehen")

                            TextField("Name", text: $uhr.name)
                                .eingabefeld()
                                .frame(width: 140)
                            TextField("Adresse", text: $uhr.host)
                                .eingabefeld()
                                .frame(width: 130)
                                .onChange(of: uhr.host) { _, _ in zustand.adresseGeaendert(uhr.id) }
                            Spacer(minLength: 8)
                            Picker("Betriebsart", selection: betriebsart($uhr)) {
                                Text("HTTP").tag(Betriebsart.http)
                                Text("MQTT").tag(Betriebsart.mqtt)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 116)
                            // **Der Tausch gehoert an den Schalter, nicht unter die
                            // Liste.** Als Fusstext stand er bis zum 14.09.2026 da
                            // und nahm den Platz weg, an dem jetzt steht, was der
                            // Punkt links bedeutet. Am Schalter kostet er keine
                            // Zeile — und er steht dort, wo die Wahl getroffen
                            // wird. Ausfuehrlich steht beides in der Hilfe
                            // (`HilfeInhalt`, „Betriebsart: HTTP oder MQTT").
                            .help("HTTP meldet zurück, ob die Uhr die Anzeige angenommen hat. MQTT meldet das nie, liest dafür mit, was andere an dieselbe Uhr schicken.")
                            Picker("Geräteart", selection: geraeteart($uhr)) {
                                ForEach([Geraetetyp.tc002, .awtrixNG], id: \.self) { art in
                                    Text(art.beschriftung).tag(art)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 132)
                            .help("„Abfragen“ stellt die Geräteart selbst fest. Von Hand zu wählen ist sie nur dort, wo das nicht gelingt — etwa wenn die Schnittstelle der AWTRIX eine Anmeldung verlangt.")
                        }
                        HStack(spacing: 8) {
                            // Das Praefix ist eine Auskunft, kein Feld: eine
                            // Zeile, nie zwei.
                            Text(uhr.praefix.isEmpty ? "—" : Themenpraefix.sichtbar(uhr.praefix))
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Brokerzeichen(uhr: uhr, steht: zustand.verbunden[uhr.id])
                            Spacer(minLength: 8)
                            Uhrlink(host: uhr.host)
                            Button("Abfragen") { zustand.abfragen(uhr.id) }
                                .knopfBefehl()
                                .fixedSize()
                            Button("Entfernen", role: .destructive) { zustand.uhrEntfernen(uhr.id) }
                                .knopfZerstoerend()
                                .fixedSize()
                        }
                        // Unter dem Punkt eingerueckt: Die zweite Zeile gehoert
                        // zur Uhr darueber und faengt nicht neu am Rand an.
                        .padding(.leading, 24)
                    }
                }
                HStack {
                    // Ein Beispiel sagt mehr als eine Beschreibung: Man sieht
                    // sofort, dass eine IP-Adresse gemeint ist und nicht ein
                    // Name.
                    TextField("z. B. 192.168.0.10", text: $neuerHost)
                        .eingabefeld()
                        .frame(minWidth: 220)
                        .onSubmit { uhrHinzufuegen() }
                    Button("Hinzufügen") { uhrHinzufuegen() }
                        .knopfBefehl()
                }
                Text("Der Punkt links wählt die angesehene Uhr: Vorschau, Geräterahmen, die fünf Blöcke und der Zeit-Reiter beziehen sich auf sie. Das ist nicht dasselbe wie das Sendeziel — das steht unter „Senden“ oben rechts. Solange dort nichts eigenes gewählt ist, geht das Senden ebenfalls an die angesehene Uhr.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Das Präfix ermittelt die App selbst und stellt dabei auch fest, was für ein Gerät antwortet. Bei einer Ulanzi ist es das eingestellte plus die letzten vier Stellen der MAC-Adresse, bei einer AWTRIX NG genau das eingestellte. Es gehört zum MQTT-Betrieb.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Broker") {
                // Der Abschnitt wird **nicht** ausgeblendet und nicht
                // abgeblendet, sondern nur eingeordnet. Ausgeblendet spraenge
                // das Formular bei jedem Griff an die Betriebsart; abgeblendet
                // liesse sich ein Broker nicht mehr eintragen, **bevor** man
                // eine Uhr auf MQTT stellt — und genau in der Reihenfolge geht
                // man vor. Die Felder sind auch nicht wirkungslos: Sie wirken,
                // sobald eine Uhr sie benutzt. Nur das gehört gesagt.
                if !Einstellungen.brokerNoetig(fuer: zustand.uhren) {
                    Text("Zurzeit steht keine Uhr auf MQTT — dann wird hier nichts davon gebraucht. Eingetragen werden darf es trotzdem, und es gilt, sobald eine Uhr umgestellt wird.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                // `LabeledContent` statt der Beschriftung, die `TextField`
                // selbst mitbringt: Am Mac zeigt SwiftUI die zwar an, auf dem
                // iPad dagegen ist sie der Platzhalter — und der verschwindet,
                // sobald etwas im Feld steht. Vier gefuellte Felder ohne jede
                // Beschriftung waren das Ergebnis. Die Beschriftung kommt
                // deshalb von aussen, das Feld traegt nur noch das Beispiel.
                LabeledContent("Adresse") {
                    TextField("z. B. 192.168.0.20", text: $zustand.brokerHost)
                        .labelsHidden().eingabefeld()
                }
                LabeledContent("Port") {
                    TextField("Port", text: $zustand.brokerPort)
                        .labelsHidden().eingabefeld()
                }
                LabeledContent("Benutzer") {
                    TextField("z. B. pixdeck", text: $zustand.benutzer)
                        .labelsHidden().eingabefeld()
                }
                LabeledContent("Kennwort") {
                    SecureField("Kennwort", text: $zustand.kennwort)
                        .labelsHidden()
                        .eingabefeld()
                        .focused($kennwortFokus)
                        .onSubmit { zustand.kennwortSichern() }
                        .onChange(of: kennwortFokus) { _, hat in if !hat { zustand.kennwortSichern() } }
                }
                Text("Das Kennwort liegt im Schlüsselbund, nicht in den Einstellungen.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("Sichern und prüfen") { zustand.brokerSichernUndPruefen() }
                        .knopfBefehl()
                        .disabled(zustand.brokerStand == .laeuft)
                    brokerStandAnzeige
                }
            }
            Wolkenabschnitt(zustand: zustand, fussnote: .footnote)
        }
        .formStyle(.grouped)
        .padding()
        // `.padding()` legt sich **um** die rollende Flaeche, nicht in sie
        // hinein: Der Inhalt rollt bis an ihre Kante, und der letzte Abschnitt
        // endete buendig am Fensterrand. Ein Rand innerhalb der Rollflaeche
        // endet dagegen mit dem Inhalt.
        .contentMargins(.bottom, 16, for: .scrollContent)
        // Fokuswechsel ist nicht zugesichert, wenn diese Ansicht durch einen
        // Bereichswechsel zerstoert wird — ohne dieses Netz ginge ein eben erst
        // eingetipptes Kennwort dabei verloren.
        .onDisappear { zustand.kennwortSichern() }
    }



    /// Die Geraeteart als nicht-wahlfreie Wahl fuer den Picker — dieselbe
    /// Bauart wie `betriebsart` darunter und aus demselben Grund: `Uhr.typ` ist
    /// ein `Optional`, weil es ein Dateiformat ist; die Oberflaeche sieht zwei
    /// Faelle.
    ///
    /// Wer waehlt, schreibt den Wert ausdruecklich — auch „Ulanzi TC002",
    /// obwohl das ohnehin galt. Danach steht in der Datei eine Entscheidung
    /// und keine Auslassung mehr.
    private func geraeteart(_ uhr: Binding<Uhr>) -> Binding<Geraetetyp> {
        Binding(get: { uhr.wrappedValue.gattung },
                set: { neu in
                    guard neu != uhr.wrappedValue.gattung else { return }
                    uhr.wrappedValue.typ = neu
                    zustand.geraeteartGeaendert(uhr.wrappedValue.id)
                })
    }

    /// Die Betriebsart als nicht-wahlfreie Wahl fuer den Picker.
    ///
    /// `Uhr.betriebsart` ist ein `Optional`, weil es ein Dateiformat ist; die
    /// Oberflaeche hat damit nichts zu schaffen und sieht nur zwei Faelle. Wer
    /// waehlt, schreibt den Wert ausdruecklich — auch „MQTT", auch wenn es
    /// ohnehin schon galt: Danach steht in der Datei eine Entscheidung und
    /// keine Auslassung mehr.
    private func betriebsart(_ uhr: Binding<Uhr>) -> Binding<Betriebsart> {
        Binding(get: { uhr.wrappedValue.wirksameBetriebsart },
                set: { neu in
                    guard neu != uhr.wrappedValue.wirksameBetriebsart else { return }
                    uhr.wrappedValue.betriebsart = neu
                    zustand.betriebsartGeaendert(uhr.wrappedValue.id)
                })
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
