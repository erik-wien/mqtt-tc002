import SwiftUI
import TC002Core
import TC002Modell

/// Alles, was zu **einer** Uhr gehört, auf einer Seite: Name, Adresse,
/// Betriebsart, Abfragen, Konfigurieren
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
                Abschnittskopf("Betriebsart", hilfe: lok("Das Präfix ermittelt die App selbst: Es ist genau das in der Uhr eingestellte, und ist keines eingestellt, die Kennung der Uhr. Es gehört zum MQTT-Betrieb; im HTTP-Betrieb wird die Uhr unter ihrer Adresse angesprochen."))
            }

            Section {
                Picker("Modell", selection: modell) {
                    Text("Noch nicht bestimmt").tag(Uhrmodell?.none)
                    ForEach(Uhrmodell.allCases, id: \.self) { m in
                        Text(verbatim: m.bezeichnung).tag(Uhrmodell?.some(m))
                    }
                }
                if uhr.modell == .esp32DIY { eigenbau }
            } header: {
                Abschnittskopf("Modell", hilfe: lok("Das Modell schlägt die App bei der ersten Abfrage vor; hier lässt es sich ändern. Es bestimmt, wie die Vorschau die Uhr zeichnet und, beim selbstgebauten ESP32, welche Bauteile angenommen werden."))
            }

            // Die gespeicherten Einstellungen der Uhr, in Gruppen; was man jetzt
            // schalten will, steht in der Fernbedienung (Bereich „Uhr“).
            Section {
                Text("Gilt, wenn eine Anzeige nichts anderes sagt.")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
                ForEach(Uhrgruppe.sichtbar(faehigkeiten: zustand.faehigkeiten[uhr.id],
                                           einstellungen: zustand.uhreneinstellungen[uhr.id])) { gruppe in
                    NavigationLink(value: Uhrgruppenziel(uhr: uhr.id, gruppe: gruppe)) {
                        Label { Text(verbatim: gruppe.titel) } icon: { Image(systemName: gruppe.symbol) }
                    }
                }
            } header: {
                Text("Auf der Uhr")
            }

            Section {
                LabeledContent {
                    // Das Zeichen ist das Ergebnis des Knopfes und steht darum
                    // neben ihm, nicht in einer eigenen Zeile.
                    HStack(spacing: 8) {
                        Brokerzeichen(uhr: uhr, steht: zustand.verbunden[uhr.id])
                        Button("Abfragen") { zustand.abfragen(uhr.id) }
                            .knopfBefehl()
                    }
                } label: {
                    praefixzeile
                }
                Brokergrund(grund: zustand.brokergrund[uhr.id])
                Firmwarewarnung(zustand: zustand, id: uhr.id, kanon: kanon)
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
        .navigationDestination(for: Uhrgruppenziel.self) { ziel in
            Uhrgruppenseite(zustand: zustand, ziel: ziel, kanon: kanon)
        }
        .task { await zustand.zustandAbfragen(uhr.id) }
        .uhrentfernenRueckfrage(zeigt: $fragtEntfernen, zustand: zustand, id: uhr.id)
    }

    /// Die selbstgebaute Uhr: der Lautsprecher lässt sich nicht erkennen und
    /// wird deshalb angegeben; die übrigen Bauteile liest die App aus den
    /// Antworten der Uhr (`Ausstattung`) und zeigt sie nur an.
    @ViewBuilder
    private var eigenbau: some View {
        Toggle("Lautsprecher", isOn: lautsprecher)
        Text("Ob ein Lautsprecher dran ist, lässt sich nicht erkennen. Ohne ihn verschwinden alle Klangfunktionen für diese Uhr.")
            .font(kanon.fussnote).foregroundStyle(.secondary)
        let a = Ausstattung(uhr: uhr, zustand: zustand.geraetezustand[uhr.id],
                            faehigkeiten: zustand.faehigkeiten[uhr.id])
        Text("Ausstattung").font(.subheadline.weight(.semibold))
        LabeledContent("Display") { Text(verbatim: "\(a.anzeige.breite) × \(a.anzeige.hoehe)") }
        ausstattungszeile(lok("Akku"), a.akku)
        ausstattungszeile(lok("Lichtsensor"), a.lichtsensor)
        ausstattungszeile(lok("Temperatur"), a.temperatur)
        ausstattungszeile(lok("Feuchte"), a.feuchte)
        ausstattungszeile(lok("MP3-Player"), a.mp3Player)
    }

    private func ausstattungszeile(_ titel: String, _ vorhanden: Bool?) -> some View {
        LabeledContent {
            Text(verbatim: vorhanden.map { $0 ? lok("ja") : lok("nein") } ?? "–")
                .foregroundStyle(.secondary)
        } label: {
            Text(verbatim: titel)
        }
    }

    /// `Uhr.modell` ist ein `Optional`: `nil` heißt „noch nicht bestimmt".
    private var modell: Binding<Uhrmodell?> {
        Binding(get: { uhr.modell },
                set: { neu in
                    guard neu != uhr.modell else { return }
                    uhr.modell = neu
                    zustand.ausstattungGeaendert(uhr.id)
                })
    }

    /// `Uhr.lautsprecher` ist ein `Optional`, `nil` heißt „ja".
    private var lautsprecher: Binding<Bool> {
        Binding(get: { uhr.hatLautsprecher },
                set: { an in
                    uhr.lautsprecher = an ? nil : false
                    zustand.ausstattungGeaendert(uhr.id)
                })
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

    /// `Uhr.betriebsart` ist ein `Optional`, weil es ein Dateiformat ist; die
    /// Oberflaeche sieht zwei Faelle.
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
