import SwiftUI
import TC002Core
import TC002Modell

/// Das Thema „Uhren" der Einstellungen: je Uhr **eine** Zeile, die auf ihre
/// Seite führt (`Uhrseite`), und darunter der Weg, eine weitere anzulegen.
///
/// Eine Zeile und keine Karte: Name, darunter Adresse · Präfix · Gattung,
/// rechts das Verbindungszeichen. Alles, was man mit einer Uhr tut, steht auf
/// ihrer Seite — vorher standen zwölf Knöpfe auf dem Bildschirm, bevor die
/// erste andere Einstellung kam.
public struct Uhrenliste: View {
    @Bindable var zustand: AppZustand
    private let kanon: Formkanon
    @State private var zeigtHinzufuegen = false
    /// Welche Uhr das Wischen treffen würde. Die Rückfrage ist dieselbe wie auf
    /// der Uhrseite (`Uhrentfernen`).
    @State private var wischtWeg: UUID?

    public init(zustand: AppZustand, kanon: Formkanon) {
        self.zustand = zustand
        self.kanon = kanon
    }

    public var body: some View {
        Form {
            Section {
                ForEach(zustand.uhren) { uhr in
                    NavigationLink(value: uhr.id) {
                        zeile(uhr)
                    }
                    // Wischen zusaetzlich zur roten Zeile auf der Seite: Der
                    // schnelle Weg fuer den Finger, der gruendliche fuer alle.
                    // Beide fragen dasselbe.
                    .swipeActions(edge: .trailing) {
                        Button(Uhrentfernen.knopf, role: .destructive) { wischtWeg = uhr.id }
                    }
                }
                // Eine Listenzeile, die weiterfuehrt, und darum ausdruecklich
                // `.automatic` — so halten es die Systemeinstellungen bei
                // „Account hinzufuegen". Ein grauer Kasten in der Liste saehe
                // aus wie ein Befehl, der etwas tut; dieser oeffnet ein Blatt.
                Button {
                    zeigtHinzufuegen = true
                } label: {
                    Label("Uhr hinzufügen …", systemImage: "plus")
                }
                .buttonStyle(.automatic)
            } footer: {
                Text("Antippen öffnet die Uhr: Name, Adresse, Betriebsart und was auf ihr eingestellt ist.")
                    .font(kanon.fussnote)
            }
        }
        .formStyle(.grouped)
        .navigationDestination(for: UUID.self) { id in
            Uhrseite(zustand: zustand, id: id, kanon: kanon)
        }
        .sheet(isPresented: $zeigtHinzufuegen) {
            UhrHinzufuegenBlatt(zustand: zustand, kanon: kanon)
        }
        .uhrentfernenRueckfrage(zeigt: Binding(get: { wischtWeg != nil },
                                               set: { if !$0 { wischtWeg = nil } }),
                                zustand: zustand, id: wischtWeg ?? UUID())
    }

    private func zeile(_ uhr: Uhr) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(uhr.name)
                Text(Uhrenliste.kennzeile(uhr))
                    .font(kanon.fussnote).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Brokerzeichen(uhr: uhr, steht: zustand.verbunden[uhr.id])
        }
    }

    /// Adresse, Themenpräfix und Geräteart in einer Zeile — mit Mittelpunkt
    /// getrennt, wie es Listen in den Systemeinstellungen halten. Das Präfix
    /// nur im MQTT-Betrieb: Bei einer HTTP-Uhr stünde dort „noch nicht
    /// abgefragt" und schickte jemanden hinter etwas her, das diese Uhr nie
    /// braucht.
    static func kennzeile(_ uhr: Uhr) -> String {
        var teile = [uhr.host]
        // Der Weg steht ausdruecklich da und nicht nur als Andeutung: Das
        // Praefix verriet ihn zwar (nur MQTT hat eines), aber wer die Regel
        // nicht kennt, sieht einer Zeile ohne Praefix nicht an, ob sie ueber
        // HTTP geht oder nur noch nicht abgefragt wurde.
        teile.append(uhr.wirksameBetriebsart == .mqtt ? lok("MQTT") : lok("HTTP"))
        if uhr.wirksameBetriebsart == .mqtt {
            teile.append(uhr.praefix.isEmpty ? lok("noch nicht abgefragt")
                                             : Themenpraefix.sichtbar(uhr.praefix))
        }
        teile.append(lok(uhr.gattung.beschriftung))
        return teile.joined(separator: " · ")
    }
}

/// Eine Uhr anlegen: Adresse und Name in einem Blatt, statt eines Feldes mit
/// Knopf daneben am Fuß der Liste. Der Name ist freiwillig — bleibt er leer,
/// vergibt `AppZustand.uhrHinzufuegen` einen.
private struct UhrHinzufuegenBlatt: View {
    @Bindable var zustand: AppZustand
    let kanon: Formkanon
    @Environment(\.dismiss) private var schliessen
    @State private var adresse = ""
    @State private var name = ""

    var body: some View {
        Blatt(titel: lok("Neue Uhr"),
              bestaetigung: lok("Hinzufügen"),
              bestaetigenMoeglich: !adresse.trimmingCharacters(in: .whitespaces).isEmpty,
              schliessen: { schliessen() },
              bestaetigen: hinzufuegen) {
            Form {
                Section {
                    // Ein Beispiel statt einer Beschreibung: Man sieht sofort,
                    // dass eine Adresse gemeint ist und nicht ein Name.
                    LabeledContent("Adresse") {
                        TextField("z. B. 192.168.0.10", text: $adresse)
                            .eingabefeld(inZeile: kanon)
                            .ohneAutokorrektur()
                            .onSubmit(hinzufuegen)
                    }
                    LabeledContent("Name") {
                        TextField("z. B. Küche", text: $name)
                            .eingabefeld(inZeile: kanon)
                    }
                } footer: {
                    Text("Präfix und Geräteart stellt die App selbst fest, sobald die Uhr antwortet.")
                        .font(kanon.fussnote)
                }
            }
            .formStyle(.grouped)
        }
    }

    private func hinzufuegen() {
        let adresse = adresse.trimmingCharacters(in: .whitespaces)
        guard !adresse.isEmpty else { return }
        zustand.uhrHinzufuegen(host: adresse, name: name.trimmingCharacters(in: .whitespaces))
        schliessen()
    }
}
