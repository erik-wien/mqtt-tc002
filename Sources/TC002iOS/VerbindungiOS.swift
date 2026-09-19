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
    @State private var zeigeVirtuelleUhr = false
    @State private var zeigeHilfe = false
    @State private var zeigeUeber = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                Form {
                    uhrenAbschnitt
                    // Die Einstellungen der angesehenen Uhr — derselbe
                    // Baustein wie am Schreibtisch: Seitenwechsel und
                    // Scrolltempo sind Einstellungen des Geraets, keine Frage
                    // der Bedienung, und gehoeren darum auch hier hin.
                    Uhreinstellungen(zustand: zustand)
                    Aufzeichnungsabschnitt(zustand: zustand, kanon: .telefon)
                    Brokerabschnitt(zustand: zustand, kanon: .telefon)
                    VirtuelleUhrAbschnitt(zustand: zustand, betrieb: .gemeinsam,
                                          ansehen: { zeigeVirtuelleUhr = true })
                    Wolkenabschnitt(zustand: zustand, kanon: .telefon)
                    ueberAbschnitt
                }
            }
            // Wie am Schreibtisch: beim Aufschlagen fragen, nicht erst auf
            // Druck (`AppZustand.alleAbfragen`).
            .task { zustand.alleAbfragen() }
            .navigationTitle("Einstellungen")
            // Format- und Icon-Blatt haben "Fertig" bzw. "Abbrechen" in der
            // Titelleiste, dieses hatte nur den Greifer — uneinheitlich, und
            // ohne ausdruecklichen Weg hinaus.
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $zeigeVirtuelleUhr) { VirtuelleUhrView(betrieb: .gemeinsam) }
        .sheet(isPresented: $zeigeHilfe) { HilfeiOS() }
        .sheet(isPresented: $zeigeUeber) { UeberiOS() }
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
                    // Adresse, Praefix und Geraeteart in einer Zeile: Drei
                    // Angaben, die man liest und nicht bedient. Das Praefix
                    // nur im MQTT-Betrieb — bei einer HTTP-Uhr stuende dort
                    // „noch nicht abgefragt" und schickte jemanden hinter
                    // etwas her, das diese Uhr nie braucht.
                    Text(kennzeile(uhr))
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Adresswarnung(host: uhr.host)
                    Brokergrund(grund: zustand.brokergrund[uhr.id])
                    Picker("Betriebsart", selection: betriebsart($uhr)) {
                        Text("HTTP").tag(Betriebsart.http)
                        Text("MQTT").tag(Betriebsart.mqtt)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    HStack {
                        Button("Abfragen") { zustand.abfragen(uhr.id) }
                            .knopfBefehl()
                        Uhrlink(host: uhr.host)
                        Spacer()
                        Button("Entfernen", role: .destructive) { zustand.uhrEntfernen(uhr.id) }
                            .knopfZerstoerend()
                    }
                    .font(.callout)
                }
                // Die Geraeteart stellt „Abfragen" selbst fest. Von Hand
                // gebraucht wird sie nur dort, wo das nicht gelingt: Eine
                // AWTRIX NG hinter einer Anmeldung antwortet auf keine Frage
                // und gilt sonst als Werksfirmware — die App schickte dann auf
                // `<Praefix>/custom/…` statt auf `<Praefix>/cmd/apps/pushed/…`,
                // und auf der Uhr erschiene nichts. Darum im Kontextmenue und
                // nicht in der Liste: ein Ausweg, kein Regelfall.
                .contextMenu {
                    Picker("Geräteart", selection: geraeteart($uhr)) {
                        ForEach([Geraetetyp.tc002, .awtrixNG], id: \.self) { art in
                            Text(art.beschriftung).tag(art)
                        }
                    }
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

    /// Adresse, Themenpraefix und Geraeteart in einer Zeile — mit Mittelpunkt
    /// getrennt, wie es Listen in den Systemeinstellungen halten.
    private func kennzeile(_ uhr: Uhr) -> String {
        var teile = [uhr.host]
        if uhr.wirksameBetriebsart == .mqtt {
            teile.append(uhr.praefix.isEmpty ? lok("noch nicht abgefragt")
                                             : Themenpraefix.sichtbar(uhr.praefix))
        }
        teile.append(lok(uhr.gattung.beschriftung))
        return teile.joined(separator: " · ")
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
            Button("Über Pixel Clock Messenger") { zeigeUeber = true }
                .buttonStyle(.automatic)
        }
    }

    private func hinzufuegen() {
        let adresse = neueAdresse.trimmingCharacters(in: .whitespaces)
        guard !adresse.isEmpty else { return }
        zustand.uhrHinzufuegen(host: adresse)
        neueAdresse = ""
    }
}
