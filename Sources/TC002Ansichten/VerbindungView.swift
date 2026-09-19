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

            Aufzeichnungsabschnitt(zustand: zustand, kanon: .schreibtisch)
            Brokerabschnitt(zustand: zustand, kanon: .schreibtisch)
            Wolkenabschnitt(zustand: zustand, kanon: .schreibtisch)
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

}
