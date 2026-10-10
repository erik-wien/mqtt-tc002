import SwiftUI
import UniformTypeIdentifiers
import TC002Core
import TC002Modell

/// Der Klang einer Nachricht — im Reiter „Zeit“ (Mac, iPad) und im Formatblatt
/// (iPhone), gleich unter den Nachrichtenreglern. Gesperrt statt versteckt,
/// solange „Anzeige“ gewählt ist (eine Anzeige hat keinen Klang), und gesperrt
/// mit Grund, wenn die angesehene Uhr die Fähigkeit nicht meldet.
///
/// Die Namen der Melodien und MP3-Dateien kommen von der Uhr (nur über HTTP) und
/// stehen erst nach der ersten Abfrage da; davor zeigt das Menü „Uhr abfragen …“,
/// wie bei den Effektnamen.
public struct Klangabschnitt: View {
    @Bindable var zustand: AppZustand
    @Binding var klang: Klangwahl
    let aktiv: Bool
    let kanon: Formkanon

    public init(zustand: AppZustand, klang: Binding<Klangwahl>, aktiv: Bool, kanon: Formkanon) {
        self.zustand = zustand
        self._klang = klang
        self.aktiv = aktiv
        self.kanon = kanon
    }

    private var uhr: Uhr? { zustand.referenzUhr }
    private var faehigkeiten: Geraetefaehigkeiten? { uhr.flatMap { zustand.faehigkeiten[$0.id] } }
    private var listen: Tonlisten? { uhr.flatMap { zustand.tonlisten[$0.id] } }
    private var kannUhrNamen: Bool { Klangwahl(art: .uhr).gekonnt(von: faehigkeiten) }
    private var kannVorlesen: Bool { Klangwahl(art: .vorlesen).gekonnt(von: faehigkeiten) }
    private var gesperrt: Bool { !klang.gekonnt(von: faehigkeiten) }

    public var body: some View {
        Section {
            Picker("Klang", selection: $klang.art) {
                Text("Keiner").tag(Klangwahl.Art.keiner)
                Text("Von der Uhr").tag(Klangwahl.Art.uhr).selectionDisabled(!kannUhrNamen)
                Text("Vorlesen").tag(Klangwahl.Art.vorlesen).selectionDisabled(!kannVorlesen)
            }
            if gesperrt {
                Label("Diese Uhr meldet diese Fähigkeit nicht.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            switch klang.art {
            case .keiner:
                EmptyView()
            case .uhr:
                namenzeile
                if let listen, listen.leer {
                    Text("Keine Melodien oder MP3-Dateien auf der Uhr. Melodien legst du in der Web-Oberfläche der Uhr oder mit „mqtttc002 ton melodie“ an.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .vorlesen:
                vorlesezeile
            }
            Toggle("Wiederholen, bis die Nachricht geht", isOn: $klang.wiederholen)
                .disabled(klang.art == .keiner || gesperrt)
        } header: {
            Abschnittskopf("Klang", hilfe: lok("Der Klang spielt, wenn die Nachricht erscheint. „Von der Uhr“ nimmt eine Melodie oder MP3-Datei, die auf der Uhr liegt. „Vorlesen“ lässt die Uhr einen Text sprechen, und zwar auf Englisch. Mit „Wiederholen“ spielt er, bis die Nachricht zurückgezogen wird oder ausläuft. Gilt nur, wenn oben „Nachricht“ gewählt ist."))
        }
        .disabled(!aktiv)
        // Die Namen holt die Uhr nur einmal; ein erneutes Abfragen steht im Menü.
        .task(id: abrufschluessel) {
            guard klang.art == .uhr, listen == nil, let uhr else { return }
            await zustand.tonlistenAbfragen(uhr.id)
        }
    }

    private var abrufschluessel: String {
        "\(klang.art.rawValue)|\(uhr?.id.uuidString ?? "")"
    }

    private var namenzeile: some View {
        let melodien = listen?.melodien ?? []
        let mp3 = listen?.mp3 ?? []
        let unbekannt = !klang.name.isEmpty && !melodien.contains(klang.name) && !mp3.contains(klang.name)
        return LabeledContent("Name") {
            Menu {
                Picker("Name", selection: $klang.name) {
                    Text("Keiner gewählt").tag("")
                    if unbekannt { Text(verbatim: klang.name).tag(klang.name) }
                    if !melodien.isEmpty {
                        Section("Melodien") { ForEach(melodien, id: \.self) { Text(verbatim: $0).tag($0) } }
                    }
                    if !mp3.isEmpty {
                        Section("MP3-Dateien") { ForEach(mp3, id: \.self) { Text(verbatim: $0).tag($0) } }
                    }
                }
                .pickerStyle(.inline)
                if listen == nil {
                    Divider()
                    Button(lok("Noch nicht abgefragt. Die Namen kommen von der Uhr.")) {}
                        .disabled(true)
                }
                Button(lok("Uhr abfragen …")) {
                    guard let uhr else { return }
                    Task { await zustand.tonlistenAbfragen(uhr.id) }
                }
                .disabled(uhr == nil || uhr?.host.isEmpty == true)
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: klang.name.isEmpty ? lok("Keiner gewählt") : klang.name)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
            }
        }
    }

    private var vorlesezeile: some View {
        Group {
            LabeledContent("Text") {
                TextField("Text (leer: die Nachricht)", text: Binding(
                    get: { klang.sprechtext },
                    set: { klang.sprechtext = Klangwahl.gekuerzt($0) }))
                    .eingabefeld(inZeile: kanon)
            }
            LabeledContent("Länge") {
                Text(verbatim: "\(klang.sprechtext.utf8.count) / \(Klangwahl.sprechgrenze) Byte")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Label("Die Uhr spricht Englisch.", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Der Abschnitt „Ton“ der Fernbedienung: was gerade spielt, Stopp, Lautstärke
/// und Radio. Gelesen wird nur über HTTP; ohne Adresse der Uhr ist der ganze
/// Abschnitt grau, mit dem Grund daneben (wie die Tasten ohne MQTT).
///
/// Sender anlegen und ändern gehört nicht in die App, sondern in die
/// Web-Oberfläche der Uhr (Konfigurieren).
struct Tonabschnitt: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let kanon: Formkanon

    @State private var sender: String?
    @State private var waehltMP3 = false
    @State private var mp3Auswahl: MP3Auswahl?
    @State private var loeschtMP3: String?

    private var id: UUID { uhr.id }
    private var faehigkeiten: Geraetefaehigkeiten? { zustand.faehigkeiten[id] }
    private var ton: Tonzustand? { zustand.tonzustand[id] }
    private var ohneAdresse: Bool { uhr.host.isEmpty }
    /// Die Uhr hat Fähigkeiten gemeldet und keine davon ist Ton.
    private var ohneTon: Bool {
        guard let f = faehigkeiten else { return false }
        return (f.ton ?? Tonfaehigkeiten()) == Tonfaehigkeiten()
    }
    private var gesperrt: Bool { ohneAdresse || ohneTon }
    private var radioGekonnt: Bool {
        faehigkeiten.map { ($0.ton ?? Tonfaehigkeiten()).radio } ?? true
    }
    private var senderNamen: [String] { (ton?.sender ?? []).map(\.name) }
    private var ablage: Tonablage? { zustand.mp3Ablage[id] }

    var body: some View {
        Section {
            LabeledContent("Spielt") { Text(verbatim: wasSpielt).multilineTextAlignment(.trailing) }
            LabeledContent("Alles anhalten") {
                Button("Stopp") { Task { await zustand.tonStoppen(nil, fuer: id) } }
                    .knopfBefehl()
            }
            Wertregler(titel: lok("Lautstärke"),
                       wert: zustand.uhreneinstellungen[id]?.ganzzahl(.volume) ?? 0, bereich: 0...100,
                       anzeige: { "\($0) %" },
                       setzen: { p in Task { await zustand.einstellungSetzen("volume", wert: "\(p)", fuer: id) } })
            radiozeilen
            klaengezeilen
            if ohneAdresse {
                Label("Ohne Adresse der Uhr nicht lesbar", systemImage: "info.circle")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            } else if ohneTon {
                Label("Diese Uhr meldet keinen Ton.", systemImage: "info.circle")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            }
        } header: {
            Abschnittskopf("Ton", hilfe: lok("Zeigt, was die Uhr gerade spielt, und hält es an. Die Sender der Uhr legst du in ihrer Web-Oberfläche unter „Konfigurieren“ an; die App wählt nur aus. Gelesen wird über die Adresse der Uhr, alle fünf bis zehn Sekunden, solange diese Seite offen ist."))
        }
        .disabled(gesperrt)
        .opacity(gesperrt ? 0.55 : 1)
        .onAppear { senderWaehlen() }
        .onChange(of: senderNamen) { _, _ in senderWaehlen() }
        .task(id: id) {
            if !gesperrt, zustand.mp3Ablage[id] == nil { await zustand.tonlistenAbfragen(id) }
        }
        .fileImporter(isPresented: $waehltMP3, allowedContentTypes: [.mp3]) { ergebnis in
            if case .success(let url) = ergebnis { mp3Auswahl = MP3Auswahl(url: url) }
        }
        .sheet(item: $mp3Auswahl) { auswahl in
            MP3Hochladeblatt(zustand: zustand, uhr: uhr, datei: auswahl.url, kanon: kanon)
        }
        .confirmationDialog(lokf("„%@“ von der Uhr löschen?", loeschtMP3 ?? ""),
                            isPresented: Binding(get: { loeschtMP3 != nil }, set: { if !$0 { loeschtMP3 = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let name = loeschtMP3 { Task { await zustand.mp3Loeschen(name: name, fuer: id) } }
            }
        }
    }

    /// Die MP3-Dateien der Uhr: Zahl und Belegung, die Liste, der Knopf zum Hochladen.
    @ViewBuilder
    private var klaengezeilen: some View {
        LabeledContent("Klänge auf der Uhr") {
            Text(verbatim: belegung).multilineTextAlignment(.trailing)
        }
        ForEach(ablage?.namen ?? [], id: \.self) { name in
            MP3Zeile(name: name, groesse: ablage?.groessen[name]) { loeschtMP3 = name }
        }
        Button("MP3 hochladen …") { waehltMP3 = true }
            .knopfBefehl()
    }

    private var belegung: String {
        guard let ablage else { return "—" }
        func menge(_ b: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file) }
        guard let belegt = ablage.belegteBytes, let gesamt = ablage.gesamteBytes else {
            return lokf("%d MP3", ablage.namen.count)
        }
        return lokf("%d MP3 · %@ von %@", ablage.namen.count, menge(belegt), menge(gesamt))
    }

    @ViewBuilder
    private var radiozeilen: some View {
        if radioGekonnt {
            if senderNamen.isEmpty {
                Label("Keine Sender eingetragen. Sender legst du in der Web-Oberfläche der Uhr unter „Konfigurieren“ an.",
                      systemImage: "info.circle")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            } else {
                Picker("Sender", selection: Binding(get: { sender ?? "" }, set: { sender = $0 })) {
                    ForEach(senderNamen, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                LabeledContent("Radio") {
                    HStack(spacing: 8) {
                        Button("Abspielen") {
                            if let sender { Task { await zustand.radioSpielen(sender: sender, fuer: id) } }
                        }
                        .knopfBefehl()
                        .disabled(sender == nil)
                        Button("Radio aus") { Task { await zustand.tonStoppen(.radio, fuer: id) } }
                            .knopfBefehl()
                    }
                }
            }
        } else {
            Label("Diese Uhr meldet kein Radio.", systemImage: "info.circle")
                .font(kanon.fussnote).foregroundStyle(.secondary)
        }
    }

    /// Der spielende Sender, sonst der erste der Liste.
    private func senderWaehlen() {
        if let spielt = ton?.radio.sender, ton?.radio.spielt == true, senderNamen.contains(spielt) {
            sender = spielt
        } else if sender == nil || !senderNamen.contains(sender ?? "") {
            sender = senderNamen.first
        }
    }

    private var wasSpielt: String {
        guard let ton else { return "—" }
        if ton.radio.spielt {
            let teile = [ton.radio.sender, ton.radio.titel].filter { !$0.isEmpty }
            return lokf("Radio: %@", teile.isEmpty ? "—" : teile.joined(separator: " · "))
        }
        if ton.alarm.spielt { return lokf("Alarm: %@", ton.alarm.name.isEmpty ? "—" : ton.alarm.name) }
        if ton.app.spielt { return lokf("App: %@", ton.app.name.isEmpty ? "—" : ton.app.name) }
        return lok("Still")
    }
}
