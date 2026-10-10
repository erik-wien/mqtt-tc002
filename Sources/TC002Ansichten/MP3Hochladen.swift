import SwiftUI
import TC002Core
import TC002Modell

/// Eine gewählte MP3-Datei auf dem Weg zur Uhr; `Identifiable` für `.sheet(item:)`.
struct MP3Auswahl: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Das Blatt zum Hochladen einer MP3-Datei: der Originalname, der Name auf der
/// Uhr (vorbelegt mit dem Vorschlag, live geprüft) und, wenn er schon vergeben
/// ist, die Wahl zwischen Ersetzen und einem freien Namen.
///
/// Die Namen auf der Uhr stehen erst nach der Abfrage der Listen fest; bis dahin
/// bleibt „Hochladen“ gesperrt, denn eine gleichnamige MP3 ersetzt die Uhr still.
struct MP3Hochladeblatt: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let datei: URL
    let kanon: Formkanon
    @Environment(\.dismiss) private var schliessen

    @State private var name: String
    @State private var ersetzen = false
    @State private var laeuft = false
    @State private var groesse: Int?

    init(zustand: AppZustand, uhr: Uhr, datei: URL, kanon: Formkanon) {
        self.zustand = zustand
        self.uhr = uhr
        self.datei = datei
        self.kanon = kanon
        _name = State(initialValue: Klangname.vorschlag(ausDateiname: datei.lastPathComponent))
    }

    private var listen: Tonlisten? { zustand.tonlisten[uhr.id] }
    private var melodien: [String] { listen?.melodien ?? [] }
    private var mp3: [String] { listen?.mp3 ?? [] }
    private var vergeben: [String] { mp3 + melodien }
    private var freierName: String { Klangname.freierName(name, vorhanden: vergeben) }
    private var istMelodie: Bool { melodien.contains(name) }
    private var istMP3: Bool { mp3.contains(name) }
    private var gueltig: Bool { Klangname.gueltig(name) }
    private var zuGross: Bool { (groesse ?? 0) > Geraet.mp3Hoechstgroesse }
    private var kannMP3: Bool { Klangeignung.mp3Hochladbar(zustand.faehigkeiten[uhr.id]) }
    private var darfHochladen: Bool {
        kannMP3 && gueltig && listen != nil && !laeuft && !zuGross && !istMelodie && (!istMP3 || ersetzen)
    }

    var body: some View {
        Blatt(titel: lok("MP3-Datei"),
              bestaetigung: lok("Hochladen"),
              bestaetigenMoeglich: darfHochladen,
              schliessen: { schliessen() },
              bestaetigen: hochladen) {
            Form {
                Section {
                    LabeledContent("Datei") {
                        Text(verbatim: datei.lastPathComponent)
                            .lineLimit(2).truncationMode(.middle).multilineTextAlignment(.trailing)
                    }
                    if let groesse {
                        LabeledContent("Größe") {
                            Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(groesse), countStyle: .file))
                                .foregroundStyle(zuGross ? .red : .secondary)
                        }
                    }
                    LabeledContent("Name auf der Uhr") {
                        TextField("Name auf der Uhr", text: $name)
                            .eingabefeld(inZeile: kanon)
                            .ohneAutokorrektur()
                            .onSubmit { if darfHochladen { hochladen() } }
                    }
                    LabeledContent("Länge") {
                        Text(verbatim: "\(name.unicodeScalars.count) / \(Klangname.hoechstlaenge)")
                            .monospacedDigit()
                            .foregroundStyle(name.unicodeScalars.count > Klangname.hoechstlaenge ? .red : .secondary)
                    }
                    meldungen
                }
                if listen == nil {
                    Section {
                        Label("Uhr abfragen", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            #if os(macOS)
            .frame(minWidth: 420)
            #endif
        }
        .task {
            if listen == nil { await zustand.tonlistenAbfragen(uhr.id) }
        }
        .task {
            groesse = await Hintergrund.lauf { () -> Int? in
                let offen = datei.startAccessingSecurityScopedResource()
                defer { if offen { datei.stopAccessingSecurityScopedResource() } }
                return try? datei.resourceValues(forKeys: [.fileSizeKey]).fileSize
            }
        }
    }

    @ViewBuilder
    private var meldungen: some View {
        if !kannMP3 {
            warnung(lok("Diese Uhr kann keine MP3 spielen."))
        } else if name.isEmpty {
            warnung(lok("Der Name darf nicht leer sein."))
        } else if !gueltig {
            let falsch = Klangname.ungueltigeZeichen(in: name)
            if falsch.isEmpty {
                warnung(lokf("Höchstens %d Zeichen.", Klangname.hoechstlaenge))
            } else {
                warnung(lokf("Nicht erlaubt: %@", falsch.map { $0 == " " ? "␣" : String($0) }.joined(separator: " ")))
            }
        } else if istMelodie {
            warnung(lokf("„%@“ ist auf der Uhr der Name einer Melodie.", name))
            Button(lokf("Freien Namen nehmen: %@", freierName)) { name = freierName }
                .knopfBefehl()
        } else if istMP3 {
            warnung(lokf("„%@“ gibt es auf der Uhr schon.", name))
            Toggle("Vorhandene Datei ersetzen", isOn: $ersetzen)
            Button(lokf("Freien Namen nehmen: %@", freierName)) { name = freierName; ersetzen = false }
                .knopfBefehl()
        }
        if zuGross {
            warnung(lokf("Die Datei ist größer als %@.",
                         ByteCountFormatter.string(fromByteCount: Int64(Geraet.mp3Hoechstgroesse), countStyle: .file)))
        }
    }

    private func warnung(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
    }

    private func hochladen() {
        guard darfHochladen else { return }
        laeuft = true
        let ziel = name
        Task {
            let ok = await zustand.mp3Hochladen(datei: datei, name: ziel, fuer: uhr.id)
            laeuft = false
            if ok { schliessen() }
        }
    }
}

/// Eine MP3-Datei der Uhr in der Liste: Name und Größe, Löschen über das
/// Kontextmenü, am Zeiger zusätzlich über ein Zeichen, das erst unter dem Zeiger
/// erscheint, am Finger über Wischen.
struct MP3Zeile: View {
    let name: String
    let groesse: Int?
    var symbol = "waveform"
    let loeschen: () -> Void
    @State private var darueber = false

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                if let groesse {
                    Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(groesse), countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                if darueber {
                    Button(role: .destructive, action: loeschen) { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(lok("Löschen"))
                }
            }
        } label: {
            Label { Text(verbatim: name) } icon: { Image(systemName: symbol) }
        }
        .onHover { darueber = $0 }
        .contextMenu {
            Button(lok("Löschen …"), role: .destructive, action: loeschen)
        }
        .swipeActions {
            Button(lok("Löschen …"), role: .destructive, action: loeschen)
        }
    }
}
