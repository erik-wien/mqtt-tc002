import SwiftUI
import TC002Core
import TC002Modell

/// Waehlt, an welche Uhr oder Uhren gesendet wird. Ein Knopf, der das Ziel
/// benennt, oeffnet ein Blatt mit einer Zeile je Uhr. Von „Senden“ und „Editor“
/// gemeinsam genutzt — zwei verschiedene Bedienungen fuer dieselbe Sache waeren
/// schlimmer als gar keine.
///
/// Erscheint erst ab zwei eingerichteten Uhren: bei nur einer ist die Wahl
/// bedeutungslos, und ein gesperrter oder ausgegrauter Knopf waere nur
/// zusaetzliche, wirkungslose Flaeche.
struct ZielauswahlView: View {
    @Bindable var zustand: AppZustand
    @State private var zeigeBlatt = false

    /// Was der Knopf gerade bedeutet, mit Fallback auf die aktive Uhr — genau
    /// das, was `AppZustand.ziele()` auch tatsaechlich verschickt.
    private var gewaehlteIDs: Set<UUID> {
        zustand.zielIDs.isEmpty ? Set(zustand.aktiveID.map { [$0] } ?? []) : zustand.zielIDs
    }

    private var beschriftung: String {
        let gewaehlt = gewaehlteIDs
        let anzahlUhren = zustand.uhren.count
        if anzahlUhren > 1, gewaehlt.count == anzahlUhren {
            return lokf("an alle Uhren (%d)", anzahlUhren)
        }
        if gewaehlt.count == 1, let uhr = zustand.uhren.first(where: { $0.id == gewaehlt.first }) {
            return lokf("an: %@", uhr.name)
        }
        return lokf("an %d Uhren", gewaehlt.count)
    }

    var body: some View {
        if zustand.uhren.count > 1 {
            Button {
                // Vor dem Oeffnen konkretisieren: sonst zeigte das Blatt bei
                // leerer Auswahl keine Uhr angehakt, obwohl der Knopf eben
                // noch die aktive Uhr als Ziel genannt hat.
                if zustand.zielIDs.isEmpty { zustand.zielIDs = gewaehlteIDs }
                zeigeBlatt = true
            } label: {
                // **Dasselbe Zeichen wie am Telefon** (dort das Antennensymbol
                // neben dem Eingabefeld), dazu das Wort. Bis zum 18.09.2026
                // stand hier ein ganzer Satz als Beschriftung — „an: Küche",
                // „an 2 Uhren" —, der neben dem Titelmenue wie ein zweiter
                // Titel las. Wohin es geht, sagt jetzt der Einblendtext und das
                // Blatt selbst.
                // **Die Zahl nur, wenn sie etwas sagt.** „Empfänger" allein
                // beantwortet nicht die eine Frage, die man im Vorbeigehen
                // hat: Geht das gerade an mehr als eine? Bei genau einer
                // bliebe die 1 dagegen stumm — und machte den Knopf breiter,
                // ohne etwas hinzuzufügen.
                //
                // `lok`/`lokf` in beiden Zweigen: Ein Ternär mit einem
                // `String`-Zweig zwänge `Label` in die
                // `StringProtocol`-Überladung, und die schlägt nichts nach
                // (CLAUDE.md, „Sprachen"). Hier ist beides schon übersetzt,
                // bevor `Label` es sieht.
                Label(gewaehlteIDs.count > 1 ? lokf("Empfänger · %d", gewaehlteIDs.count)
                                             : lok("Empfänger"),
                      systemImage: "antenna.radiowaves.left.and.right")
            }
            .knopfBefehl()
            .help(beschriftung)
            .accessibilityLabel(Text(beschriftung))
            .sheet(isPresented: $zeigeBlatt) { blatt }
        }
    }

    private var blatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("An welche Uhr senden?").font(.headline)

            HStack {
                Button("Alle") { zustand.zielIDs = Set(zustand.uhren.map(\.id)) }
                    .knopfBefehl()
                // **„Nur die angesehene" statt „Keine".** Der alte Knopf
                // schrieb die leere Menge — und die heisst fuer diese App „die
                // angesehene Uhr", fuer Werkzeug und Kurzbefehle aber **alle**
                // (`Einstellungen.ziele`). Dieselbe Einstellung, zwei
                // Bedeutungen: Wer hier „Keine" drueckte, schickte den naechsten
                // Kurzbefehl an jede eingerichtete Uhr.
                Button("Nur die angesehene") {
                    if let aktiveID = zustand.aktiveID { zustand.zielIDs = [aktiveID] }
                }
                .knopfBefehl()
                Spacer()
            }

            List(zustand.uhren) { uhr in
                // Ueber `zielUmschalten` und nicht ueber `insert`/`remove`:
                // Dort steht die Regel, dass die Menge nie leer wird.
                Toggle(isOn: Binding(
                    get: { zustand.zielIDs.contains(uhr.id) },
                    set: { _ in zustand.zielUmschalten(uhr.id) }
                )) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(uhr.name)
                            HStack(spacing: 6) {
                                // Woran eine Uhr fehlt, haengt an ihrer
                                // Betriebsart. „Kein Präfix" war fuer eine
                                // HTTP-Uhr die falsche Warnung: Sie braucht
                                // keines, und der Satz schickte jemanden zu
                                // „Abfragen", wo nichts zu holen war.
                                //
                                // `lok(…)`, weil ein Ternär mit einem
                                // `String`-Zweig SwiftUI in die
                                // `StringProtocol`-Überladung zwingt — die
                                // schlägt nichts nach.
                                if !uhr.beschickbar {
                                    Label(uhr.wirksameBetriebsart == .http
                                          ? lok("keine Adresse — kann nichts empfangen")
                                          : lok("kein Präfix — kann erst empfangen, wenn abgefragt"),
                                          systemImage: "exclamationmark.triangle")
                                        .font(.caption).foregroundStyle(.orange)
                                } else if uhr.wirksameBetriebsart == .http {
                                    Text("HTTP")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(uhr.praefix)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                // Nur die abweichende Gattung steht da. „Ulanzi
                                // TC002" an jeder Zeile waere eine Angabe, die
                                // nichts unterscheidet — und die Zeile soll
                                // sagen, was **diese** Uhr von den anderen
                                // trennt.
                                if uhr.gattung != .tc002 {
                                    Text(uhr.gattung.beschriftung)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Brokerzeichen(uhr: uhr, steht: zustand.verbunden[uhr.id])
                            }
                        }
                        Spacer()
                    }
                }
                // Nur am Mac: `.checkbox` gibt es unter iOS nicht. Dort bleibt
                // die Vorgabe (der Schalter) — geteilt wird die Ansicht, nicht
                // der Stil.
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
            }
            .frame(minHeight: 160)

            HStack {
                Spacer()
                Button("Schließen") { zeigeBlatt = false }
                    .knopfHaupthandlung()
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 320)
    }
}
