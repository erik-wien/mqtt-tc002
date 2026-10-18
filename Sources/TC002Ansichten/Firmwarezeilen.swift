import SwiftUI
import UniformTypeIdentifiers
import TC002Core
import TC002Modell

/// Die Zeilen „Firmware“ im Abschnitt „Gerät“ der Fernbedienung: die laufende Fassung,
/// „Nach Update suchen …“ und — wenn es ein Paket für diese Uhr gibt — „Aktualisieren …“
/// mit einem Bestätigungsblatt. Eine Ansicht für Mac, iPad und iPhone.
///
/// Gesucht wird nur auf Druck des Knopfes, nie beim Öffnen der Seite: Die Suche fragt
/// GitHub. Aktualisiert wird nur nach der Bestätigung im Blatt, jedes Mal.
struct Firmwarezeilen: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let kanon: Formkanon

    @State private var fragt: Firmwarepaket?

    private var ablauf: Firmwareablauf? { zustand.firmwareablauf[uhr.id] }
    private var geraet: Geraetezustand? { zustand.geraetezustand[uhr.id] }
    private var lage: Firmwarelage { Firmwarelage.fuer(adresse: !uhr.host.isEmpty, zustand: geraet) }
    private var beschaeftigt: Bool { ablauf?.beschaeftigt == true }

    var body: some View {
        if lage != .verborgen {
            LabeledContent("Firmware") { Text(verbatim: geraet?.fassung ?? "—") }
            statuszeile
            Button("Nach Update suchen …") { Task { await zustand.firmwareSuchen(fuer: uhr.id) } }
                .knopfBefehl()
                .disabled(lage == .ohneAdresse || beschaeftigt)
            if case .verfuegbar(let paket)? = ablauf {
                Button("Aktualisieren …") { fragt = paket }
                    .knopfBefehl()
                    .disabled(beschaeftigt)
                    .sheet(isPresented: Binding(get: { fragt != nil }, set: { if !$0 { fragt = nil } })) {
                        Firmwareblatt(zustand: zustand, uhr: uhr, paket: paket, kanon: kanon) { fragt = nil }
                    }
            }
            if lage == .ohneAdresse {
                Label("Update braucht die Adresse der Uhr", systemImage: "info.circle")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var statuszeile: some View {
        switch ablauf {
        case nil:
            EmptyView()
        case .sucht?:
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Suche …") }
                .font(kanon.fussnote).foregroundStyle(.secondary)
        case .aktuell?:
            Label("Aktuell", systemImage: "checkmark.circle").font(kanon.fussnote).foregroundStyle(.secondary)
        case .verfuegbar(let p)?:
            Text(verbatim: lokf("Version %@ ist verfügbar", p.fassung)).font(kanon.fussnote)
        case .keinPaket(let fassung, _)?:
            Text(verbatim: lokf("Version %@ ist erschienen, aber ohne Paket für diese Uhr", fassung))
                .font(kanon.fussnote).foregroundStyle(.secondary)
        case .unterwegs(let stufe, _)?:
            VStack(alignment: .leading, spacing: 4) {
                switch stufe {
                case .laedt(let p):
                    Text("Paket wird geladen …"); ProgressView(value: p)
                case .uebertraegt(let p):
                    Text("Paket geht an die Uhr …"); ProgressView(value: p)
                case .startetNeu:
                    Text("Uhr startet neu …"); ProgressView()
                }
            }
            .font(kanon.fussnote)
        case .fertig(let e)?:
            VStack(alignment: .leading, spacing: 2) {
                Label { Text(verbatim: lokf("Fassung %@ läuft", e.fassung)) }
                    icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if e.bestaetigungAusstehend {
                    Text("Die Uhr bestätigt sie nach einer Minute.").foregroundStyle(.secondary)
                }
            }
            .font(kanon.fussnote)
        case .fehler(let text)?:
            Label { Text(verbatim: text) }
                icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Warnfarbe.symbol) }
                .font(kanon.fussnote)
        }
    }
}

/// Das Bestätigungsblatt: was installiert wird, woher es kommt und was danach geschieht.
/// „Erst sichern …“ ruft dieselbe Sicherung wie der Abschnitt „Gerät“.
struct Firmwareblatt: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let paket: Firmwarepaket
    let kanon: Formkanon
    let schliessen: () -> Void

    @State private var exportiert: Sicherungsdokument?
    @State private var sichert = false

    var body: some View {
        Blatt(titel: lok("Firmware aktualisieren"), bestaetigung: lok("Aktualisieren"),
              schliessen: schliessen,
              bestaetigen: {
                  schliessen()
                  Task { await zustand.firmwareAktualisieren(fuer: uhr.id) }
              }) {
            Form {
                Section {
                    LabeledContent("Installiert") { Text(verbatim: zustand.geraetezustand[uhr.id]?.fassung ?? "—") }
                    LabeledContent("Neu") { Text(verbatim: paket.fassung) }
                    LabeledContent("Quelle") {
                        if let notizen = paket.notizen {
                            Link(destination: notizen) { Text(verbatim: Firmwarequelle.herkunft) }
                        } else {
                            Text(verbatim: Firmwarequelle.herkunft)
                        }
                    }
                    LabeledContent("Paket") {
                        Text(verbatim: paket.dateiname + " · "
                             + ByteCountFormatter.string(fromByteCount: Int64(paket.groesse), countStyle: .file))
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Das Paket ist nicht signiert. Die Uhr startet danach neu.")
                        .font(kanon.fussnote)
                }
                Section {
                    Button("Erst sichern …") { sichern() }
                        .knopfBefehl()
                        .disabled(sichert)
                }
            }
            .formStyle(.grouped)
            .fileExporter(isPresented: Binding(get: { exportiert != nil }, set: { if !$0 { exportiert = nil } }),
                          document: exportiert, contentType: .zip,
                          defaultFilename: Sicherungsdokument.dateiname(fuer: uhr)) { _ in }
        }
    }

    private func sichern() {
        sichert = true
        Task {
            let zip = await zustand.sicherungErstellen(fuer: uhr.id)
            sichert = false
            if let zip { exportiert = Sicherungsdokument(daten: zip) }
        }
    }
}
