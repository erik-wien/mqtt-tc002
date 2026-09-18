import SwiftUI
import TC002Core
import TC002Modell

public struct VerbindungView: View {
    @Bindable var zustand: AppZustand

    public init(zustand: AppZustand, fensterOeffnen: ((String) -> Void)? = nil) {
        self.zustand = zustand
        self.fensterOeffnen = fensterOeffnen
    }
    @State private var neuerHost = ""
    /// Das Kennwort wandert beim Verlassen des Feldes in den Schluesselbund, nicht
    /// bei jedem Tastendruck.
    @FocusState private var kennwortFokus: Bool

    /// Wo die virtuelle Uhr aufgeht: am Mac als eigenes Fenster, am iPad als
    /// Einblendung. Die Handlung kommt herein und wird hier nicht
    /// gewaehlt: `openWindow` gibt es unter iOS zwar als Aufruf, aber er tut
    /// dort nichts — deshalb steht er allein in der Mac-App, und diese
    /// Ansicht weiss gar nicht, dass es Fenster gibt (`PlattformwegeTests`).
    /// `nil` heisst: kein Fenster zur Hand, dann ein Blatt.
    private let fensterOeffnen: ((String) -> Void)?
    @State private var zeigeVirtuelleUhr = false

    private func ansehen() {
        if let fensterOeffnen {
            fensterOeffnen(Nebenfenster.virtuelleUhr.id)
        } else {
            zeigeVirtuelleUhr = true
        }
    }

    /// Die vier Spaltenbreiten der Uhrenzeile. Zusammen 518 Punkte plus
    /// Zwischenraum — der Kasten eines gruppierten Formulars ist am Mac bei
    /// 704 gedeckelt, gleich wie breit das Fenster ist.
    ///
    /// `@ScaledMetric` und keine festen Zahlen: Sonst hebelt die Zeile die
    /// Textgrößen-Einstellung des Systems aus und schneidet den Inhalt ab,
    /// statt ihn wachsen zu lassen.
    @ScaledMetric(relativeTo: .body) private var breiteName: Double = 140
    @ScaledMetric(relativeTo: .body) private var breiteAdresse: Double = 130
    @ScaledMetric(relativeTo: .body) private var breiteBetriebsart: Double = 116
    @ScaledMetric(relativeTo: .body) private var breiteGeraeteart: Double = 132

    public var body: some View {
        Form {
            Section {
                ForEach($zustand.uhren) { $uhr in
                    // Zwei Zeilen, nicht eine: Neun Bedienelemente in einer
                    // Reihe brauchen rund 820 Punkte; der Kasten eines
                    // gruppierten Formulars ist am Mac aber bei 704 gedeckelt
                    // und zentriert, gleich ob das Fenster 900 oder 1200
                    // Punkte breit ist. `.frame(maxWidth: .infinity)` hilft
                    // nicht, der Deckel sitzt im Stil. Eine Zeile liesse
                    // „Abfragen" und „Entfernen" zu „A…" und „E…"
                    // zusammenschnurren und das Praefix ueber zwei Zeilen
                    // brechen.
                    //
                    // Oben steht, was die Uhr ist, unten, was sie gerade
                    // meldet und was man mit ihr tut.
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("Name", text: $uhr.name)
                                .eingabefeld()
                                .frame(width: breiteName)
                            TextField("Adresse", text: $uhr.host)
                                .eingabefeld()
                                .frame(width: breiteAdresse)
                                .onChange(of: uhr.host) { _, _ in zustand.adresseGeaendert(uhr.id) }
                            Spacer(minLength: 8)
                            Picker("Betriebsart", selection: betriebsart($uhr)) {
                                Text("HTTP").tag(Betriebsart.http)
                                Text("MQTT").tag(Betriebsart.mqtt)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: breiteBetriebsart)
                            // Der Tausch-Hinweis gehoert an den Schalter,
                            // nicht als Fusstext unter die Liste — dort
                            // kostet er keine Zeile und steht, wo die Wahl
                            // getroffen wird. Ausfuehrlich steht beides in
                            // der Hilfe (`HilfeInhalt`, „Betriebsart: HTTP
                            // oder MQTT").
                            .help("HTTP meldet zurück, ob die Uhr die Anzeige angenommen hat. MQTT meldet das nie, liest dafür mit, was andere an dieselbe Uhr schicken.")
                            Picker("Geräteart", selection: geraeteart($uhr)) {
                                ForEach([Geraetetyp.tc002, .awtrixNG], id: \.self) { art in
                                    Text(art.beschriftung).tag(art)
                                }
                            }
                            .labelsHidden()
                            .frame(width: breiteGeraeteart)
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
                        Adresswarnung(host: uhr.host)
                            .padding(.leading, 24)
                        Brokergrund(grund: zustand.brokergrund[uhr.id])
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
                Text("Das Präfix ermittelt die App selbst und stellt dabei auch fest, was für ein Gerät antwortet. Bei einer Ulanzi ist es das eingestellte plus die letzten vier Stellen der MAC-Adresse, bei einer AWTRIX NG genau das eingestellte. Es gehört zum MQTT-Betrieb.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("Uhren")
            }
            // Die Einstellungen der angesehenen Uhr — Seitenwechsel und
            // Scrolltempo. Nicht im Zeit-Reiter des Inspektors neben Dauer
            // und Lauftempo: Dort stuenden zwei Sorten Zustand nebeneinander,
            // die mit einer Meldung mitreisende und die, die auf dem Geraet
            // bleibt. Der Unterschied steht als (?) an beiden Stellen.
            Uhreinstellungen(zustand: zustand)
            VirtuelleUhrAbschnitt(zustand: zustand, betrieb: .gemeinsam, ansehen: ansehen)

            // Der Verlauf ist ab Werk an — anders als das Protokoll. Er ist
            // keine technische Mitschrift, sondern das, was man geschickt hat, und
            // ein Druck darauf stellt es wieder her.
            Section {
                Toggle("Verlauf führen", isOn: $zustand.verlaufAn)
                Button("Verlauf löschen", role: .destructive) { zustand.verlaufLeeren() }
                        .knopfZerstoerend()
                Text("Merkt sich jede gesendete Meldung samt ihren Einstellungen — unter „Senden“ steht sie unter den Plätzen, ein Druck stellt sie wieder her. Wird über iCloud abgeglichen, wenn das eingeschaltet ist, und hält die letzten 200 Sendungen je Gerät.")
                        .font(.footnote).foregroundStyle(.secondary)
            }

            // Ab Werk aus: Das Protokoll ist ein Werkzeug fuer den Fall, dass
            // etwas nicht klappt — kein Mitschnitt, den eine App von sich aus
            // fuehrt. Wer einen Fehler sucht, schaltet es ein; das Ausschalten
            // raeumt das Vorhandene weg.
            Section {
                Toggle("Protokoll führen", isOn: $zustand.protokollAn)
                Text("Schreibt mit, was die App sendet und was die Uhren melden — unter „Verlauf“ nachzulesen. Nur nötig, wenn etwas nicht klappt; ausgeschaltet wird nichts aufgezeichnet und das Vorhandene weggeräumt.")
                        .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Broker") {
                // Der Abschnitt wird nicht ausgeblendet und nicht
                // abgeblendet, sondern nur eingeordnet. Ausgeblendet spraenge
                // das Formular bei jedem Griff an die Betriebsart; abgeblendet
                // liesse sich ein Broker nicht mehr eintragen, bevor man
                // eine Uhr auf MQTT stellt — und genau in der Reihenfolge geht
                // man vor. Die Felder sind auch nicht wirkungslos: Sie wirken,
                // sobald eine Uhr sie benutzt.
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
        // Beim Aufschlagen fragen, nicht erst auf Druck: Praefix, Gattung
        // und Verbindungsstand sind genau das, was man hier wissen will. Die
        // Abrufe laufen nebeneinander, eine stumme Uhr haelt die uebrigen
        // nicht auf.
        .task { zustand.alleAbfragen() }
        .padding()
        // `.padding()` legt sich um die rollende Flaeche, nicht in sie
        // hinein: Der Inhalt rollt bis an ihre Kante, und der letzte Abschnitt
        // endete buendig am Fensterrand. Ein Rand innerhalb der Rollflaeche
        // endet dagegen mit dem Inhalt.
        .contentMargins(.bottom, 16, for: .scrollContent)
        // Fokuswechsel ist nicht zugesichert, wenn diese Ansicht durch einen
        // Bereichswechsel zerstoert wird — ohne dieses Netz ginge ein eben erst
        // eingetipptes Kennwort dabei verloren.
        .onDisappear { zustand.kennwortSichern() }
        .sheet(isPresented: $zeigeVirtuelleUhr) { Nebenfenster.virtuelleUhr.inhalt }
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
