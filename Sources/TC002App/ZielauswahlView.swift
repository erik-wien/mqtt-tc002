import SwiftUI

/// Waehlt, an welche Uhr oder Uhren gesendet wird. Ein Knopf, der das Ziel
/// benennt, oeffnet ein Blatt mit einer Zeile je Uhr. Von „Senden“ und „Malen“
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
            return "an alle Uhren (\(anzahlUhren))"
        }
        if gewaehlt.count == 1, let uhr = zustand.uhren.first(where: { $0.id == gewaehlt.first }) {
            return "an: \(uhr.name)"
        }
        return "an \(gewaehlt.count) Uhren"
    }

    var body: some View {
        if zustand.uhren.count > 1 {
            Button(beschriftung) {
                // Vor dem Oeffnen konkretisieren: sonst zeigte das Blatt bei
                // leerer Auswahl keine Uhr angehakt, obwohl der Knopf eben
                // noch die aktive Uhr als Ziel genannt hat.
                if zustand.zielIDs.isEmpty { zustand.zielIDs = gewaehlteIDs }
                zeigeBlatt = true
            }
            .sheet(isPresented: $zeigeBlatt) { blatt }
        }
    }

    private var blatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("An welche Uhr senden?").font(.headline)

            HStack {
                Button("Alle") { zustand.zielIDs = Set(zustand.uhren.map(\.id)) }
                Button("Keine") { zustand.zielIDs = [] }
                Spacer()
            }

            List(zustand.uhren) { uhr in
                Toggle(isOn: Binding(
                    get: { zustand.zielIDs.contains(uhr.id) },
                    set: { gewaehlt in
                        if gewaehlt { zustand.zielIDs.insert(uhr.id) }
                        else { zustand.zielIDs.remove(uhr.id) }
                    }
                )) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(uhr.name)
                            HStack(spacing: 6) {
                                if uhr.praefix.isEmpty {
                                    Label("kein Präfix — kann erst empfangen, wenn abgefragt",
                                          systemImage: "exclamationmark.triangle")
                                        .font(.caption).foregroundStyle(.orange)
                                } else {
                                    Text(uhr.praefix)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                if let steht = zustand.verbunden[uhr.id] {
                                    Image(systemName: steht ? "checkmark.circle" : "exclamationmark.triangle")
                                        .foregroundStyle(steht ? .green : .orange)
                                        .help(steht ? "Am Broker angemeldet" : "Nicht am Broker angemeldet")
                                }
                            }
                        }
                        Spacer()
                    }
                }
                .toggleStyle(.checkbox)
            }
            .frame(minHeight: 160)

            HStack {
                Spacer()
                Button("Schließen") { zeigeBlatt = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 320)
    }
}
