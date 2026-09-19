import SwiftUI
import TC002Core
import TC002Modell

/// Alles, was zu **einer** Uhr gehört, auf einer Seite: Name, Adresse,
/// Gattung, Betriebsart, ihre Geräteeinstellungen, Abfragen, Konfigurieren
/// und das Entfernen.
///
/// Warum eine eigene Seite und nicht eine Karte in der Liste: Vier Uhren
/// ergaben zwölf Knöpfe und vier Segmentwahlen, bevor die erste andere
/// Einstellung kam. Vor allem aber standen „Auf der Uhr" — Seitenwechsel und
/// Scrolltempo — unter *allen* Uhren und galten der angesehenen; wer eine
/// andere meinte, musste die Einstellungen verlassen und umschalten. Hier
/// gilt jeder Wert der Uhr, deren Seite man aufgeschlagen hat.
///
/// Die Uhr kommt als Kennung herein und nicht als Bindung: Wird sie entfernt,
/// während die Seite offen steht, zeigte eine gehaltene Bindung auf einen
/// Platz, den es nicht mehr gibt.
public struct Uhrseite: View {
    @Bindable var zustand: AppZustand
    private let id: UUID
    private let kanon: Formkanon

    public init(zustand: AppZustand, id: UUID, kanon: Formkanon) {
        self.zustand = zustand
        self.id = id
        self.kanon = kanon
    }

    public var body: some View {
        Group {
            if let i = zustand.uhren.firstIndex(where: { $0.id == id }) {
                Uhrblatt(zustand: zustand, uhr: $zustand.uhren[i], kanon: kanon)
            } else {
                // Die Uhr ist weg, die Seite steht noch: der eine Atemzug
                // zwischen dem Entfernen und dem Zurueckspringen.
                ContentUnavailableView("Diese Uhr gibt es nicht mehr",
                                       systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(zustand.uhren.first { $0.id == id }?.name ?? lok("Uhr"))
    }
}

/// Der Inhalt der Uhrseite, sobald feststeht, dass es die Uhr noch gibt.
/// Eigene Ansicht, weil eine `Binding<Uhr>` erst hier gebildet werden kann.
private struct Uhrblatt: View {
    @Bindable var zustand: AppZustand
    @Binding var uhr: Uhr
    let kanon: Formkanon
    @State private var fragtEntfernen = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("Name", text: $uhr.name)
                        .eingabefeld(inZeile: kanon)
                }
                LabeledContent("Adresse") {
                    TextField("Adresse", text: $uhr.host)
                        .eingabefeld(inZeile: kanon)
                        .ohneAutokorrektur()
                        .onChange(of: uhr.host) { _, _ in zustand.adresseGeaendert(uhr.id) }
                }
                // Als Wahl und nicht mehr nur im Kontextmenue: Ein Ausweg, den
                // man nur ueber einen Langdruck findet, ist auf dem Telefon
                // keiner. Gebraucht wird er, wo „Abfragen" die Gattung nicht
                // feststellen kann — etwa bei einer AWTRIX NG hinter einer
                // Anmeldung.
                Picker("Geräteart", selection: geraeteart) {
                    ForEach([Geraetetyp.tc002, .awtrixNG], id: \.self) { art in
                        Text(art.beschriftung).tag(art)
                    }
                }
                Adresswarnung(host: uhr.host)
            }

            Section {
                Picker("Betriebsart", selection: betriebsart) {
                    Text("HTTP").tag(Betriebsart.http)
                    Text("MQTT").tag(Betriebsart.mqtt)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                Text("HTTP meldet zurück, ob die Uhr die Anzeige angenommen hat. MQTT meldet das nie, liest dafür mit, was andere an dieselbe Uhr schicken.")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            } header: {
                Abschnittskopf("Betriebsart", hilfe: lok("Das Präfix ermittelt die App selbst und stellt dabei auch fest, was für ein Gerät antwortet. Bei einer Ulanzi ist es das eingestellte plus die letzten vier Stellen der MAC-Adresse, bei einer AWTRIX NG genau das eingestellte. Es gehört zum MQTT-Betrieb; im HTTP-Betrieb wird die Uhr unter ihrer Adresse angesprochen."))
            }

            // Nur bei der Ulanzi-Werksfirmware: `Uhreinstellungen` prueft die
            // Gattung selbst und zeigt bei einer AWTRIX NG gar nichts.
            Uhreinstellungen(zustand: zustand, uhr: uhr, kanon: kanon)

            Section {
                LabeledContent {
                    Button("Abfragen") { zustand.abfragen(uhr.id) }
                        .knopfBefehl()
                } label: {
                    praefixzeile
                }
                Brokerzeichen(uhr: uhr, steht: zustand.verbunden[uhr.id])
                Brokergrund(grund: zustand.brokergrund[uhr.id])
                Uhrlink(host: uhr.host)
            }

            // Die rote Zeile am Fuss, wie „Dieses Geraet entfernen" in den
            // Systemeinstellungen: zerstoerend, deshalb ganz unten und nicht
            // neben den Knoepfen, die man oft drueckt.
            Section {
                Button(Uhrentfernen.knopf, role: .destructive) { fragtEntfernen = true }
                    .knopfZerstoerend()
            }
        }
        .formStyle(.grouped)
        .uhrentfernenRueckfrage(zeigt: $fragtEntfernen, zustand: zustand, id: uhr.id)
    }

    /// Das Themenpraefix ist eine Auskunft, kein Feld — und nur im
    /// MQTT-Betrieb eine: Bei einer HTTP-Uhr schickte „noch nicht abgefragt"
    /// jemanden hinter etwas her, das diese Uhr nie braucht.
    @ViewBuilder
    private var praefixzeile: some View {
        if uhr.wirksameBetriebsart == .mqtt {
            Text(uhr.praefix.isEmpty ? lok("noch nicht abgefragt")
                                     : Themenpraefix.sichtbar(uhr.praefix))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("Präfix")
                .foregroundStyle(.secondary)
        }
    }

    /// Die Geraeteart als nicht-wahlfreie Wahl fuer den Picker: `Uhr.typ` ist
    /// ein `Optional`, weil es ein Dateiformat ist; die Oberflaeche sieht zwei
    /// Faelle. Wer waehlt, schreibt den Wert ausdruecklich — danach steht in
    /// der Datei eine Entscheidung und keine Auslassung mehr.
    private var geraeteart: Binding<Geraetetyp> {
        Binding(get: { uhr.gattung },
                set: { neu in
                    guard neu != uhr.gattung else { return }
                    uhr.typ = neu
                    zustand.geraeteartGeaendert(uhr.id)
                })
    }

    /// Dieselbe Bauart und aus demselben Grund wie `geraeteart` darueber.
    private var betriebsart: Binding<Betriebsart> {
        Binding(get: { uhr.wirksameBetriebsart },
                set: { neu in
                    guard neu != uhr.wirksameBetriebsart else { return }
                    uhr.betriebsart = neu
                    zustand.betriebsartGeaendert(uhr.id)
                })
    }
}

/// Der Wortlaut der Rückfrage vor dem Entfernen — einmal im Quelltext, weil
/// beide Wege ihn brauchen: das Wischen in der Liste und die rote Zeile am Fuß
/// der Uhrseite. Ein zweiter Satz mit derselben Aussage wäre ein zweiter
/// Übersetzungsschlüssel.
public enum Uhrentfernen {
    public static var titel: String { lok("Diese Uhr entfernen?") }
    public static var erklaerung: String {
        lok("Sie verschwindet aus dieser App. Auf dem Gerät selbst ändert sich nichts.")
    }
    public static var knopf: String { lok("Entfernen") }
}

public extension View {
    /// Dieselbe Rückfrage an beiden Stellen — einmal gebaut, damit Wischen und
    /// rote Zeile nicht auseinanderlaufen können.
    func uhrentfernenRueckfrage(zeigt: Binding<Bool>, zustand: AppZustand,
                                id: UUID) -> some View {
        confirmationDialog(Uhrentfernen.titel, isPresented: zeigt) {
            Button(Uhrentfernen.knopf, role: .destructive) { zustand.uhrEntfernen(id) }
        } message: {
            Text(Uhrentfernen.erklaerung)
        }
    }
}
