import SwiftUI
import UniformTypeIdentifiers
import TC002Core
import TC002Modell

/// Der Klang einer Nachricht — im Popover bzw. Blatt, das der Klangknopf neben
/// dem Segment „Anzeige | Nachricht“ öffnet (`Sendeartwahl`). Gesperrt mit
/// Grund, was keine der gewählten Uhren spielen kann (`Klangeignung`); was nur
/// ein Teil kann, bleibt wählbar und geht nur an diese Uhren.
///
/// Die Namen der Melodien und MP3-Dateien kommen von den Uhren, an die die
/// Nachricht geht (nur über HTTP), nicht von der angesehenen: die Vereinigung
/// ihrer Listen (`Klangeignung.melodien(in:)`). Was noch fehlt, holt das Blatt
/// beim Öffnen selbst (`AppZustand.listenFuerZieleHolen`); ein Name, den nur ein
/// Teil der Uhren führt, bleibt wählbar und wird bei den anderen als nicht
/// abspielbar gemeldet.
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

    private var ziele: [Klangziel] { zustand.klangziele() }
    private func keineKann(_ wahl: Klangwahl) -> Bool {
        !ziele.isEmpty && Klangeignung.ohne(wahl, in: ziele).count == ziele.count
    }
    private func keineKann(_ art: Klangart) -> Bool {
        !ziele.isEmpty && Klangeignung.ohne(art, in: ziele).count == ziele.count
    }
    private var kannUhrNamen: Bool { !keineKann(Klangwahl(art: .uhr)) }
    private var kannVorlesen: Bool { !keineKann(Klangwahl(art: .vorlesen)) }
    private var kannMelodien: Bool { !keineKann(.melodie) }
    private var zeigtMP3: Bool { Klangeignung.mp3Zeigen(in: ziele) }
    private var gesperrt: Bool { keineKann(klang) }
    /// Die Uhren, die die jetzige Wahl nicht spielen und deshalb ohne Klang bleiben.
    private var ohneKlang: [Klangziel] { klang.art == .keiner ? [] : Klangeignung.ohne(klang, in: ziele) }

    @Environment(\.dismiss) private var schliessen

    public var body: some View {
        Section {
            Picker("Klang", selection: $klang.art) {
                Text("Keiner").tag(Klangwahl.Art.keiner)
                if kannUhrNamen { Text("Von der Uhr").tag(Klangwahl.Art.uhr) }
                if kannVorlesen { Text("Vorlesen").tag(Klangwahl.Art.vorlesen) }
            }
            if gesperrt {
                Label(Klangsperre.grund(ohneKlang, von: ziele.count), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if !ohneKlang.isEmpty {
                Label(lokf("%@ zeigt die Nachricht ohne Ton: Diese Uhr kann den Klang nicht abspielen.", Klangsperre.namen(ohneKlang)),
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            switch klang.art {
            case .keiner:
                EmptyView()
            case .uhr:
                namenzeile
                listenhinweise
            case .vorlesen:
                vorlesezeile
            }
            HStack(spacing: 6) {
                Text("Klang")
                Hilfezeichen(lok("„1×“ spielt den Klang einmal beim Erscheinen. „In Schleife“ spielt ihn ohne Pause immer wieder, solange die Nachricht steht, und ist für Alarme gedacht. Steht die Nachricht „bis ich sie zurückziehe“, heißt das: bis du sie zurückziehst."))
                Spacer(minLength: 8)
                Picker("Klang", selection: $klang.wiederholen) {
                    Text("1×").tag(false)
                    Text("In Schleife").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .disabled(klang.art == .keiner || gesperrt)
            // Immer da, auch bei leerer Liste: Neue Klänge entstehen nur in der
            // Sammlung. Erst das Popover bzw. Blatt schließen, dann wechseln, sonst
            // trifft das Öffnen des Bereichs auf eine noch offene Einblendung.
            Button("Klänge verwalten …") {
                schliessen()
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    zustand.klaengeVerwalten()
                }
            }
            .knopfBefehl()
        } header: {
            Abschnittskopf("Klang", hilfe: lok("Der Klang spielt, wenn die Nachricht erscheint. „Von der Uhr“ nimmt eine Melodie oder MP3-Datei, die auf der Uhr liegt. „Vorlesen“ lässt die Uhr einen Text sprechen, und zwar auf Englisch. Mit „In Schleife“ spielt er, bis die Nachricht zurückgezogen wird oder ausläuft. Gilt nur, wenn oben „Nachricht“ gewählt ist."))
        }
        .disabled(!aktiv)
        // Eine Klangart, die keine Zieluhr kann, wird nicht angeboten; eine
        // gewählte fällt auf „Keiner“ zurück, wenn das Ziel wechselt.
        .onChange(of: kannUhrNamen, initial: true) { _, kann in if !kann, klang.art == .uhr { klang.art = .keiner } }
        .onChange(of: kannVorlesen, initial: true) { _, kann in if !kann, klang.art == .vorlesen { klang.art = .keiner } }
        // Beim Öffnen und bei jedem Wechsel der Ziele: Was von den Zieluhren
        // noch fehlt, wird geholt; bekannte Listen bleiben.
        .task(id: abrufschluessel) {
            guard klang.art == .uhr else { return }
            await zustand.listenFuerZieleHolen(tonlisten: true)
        }
    }

    private var abrufschluessel: String {
        "\(klang.art.rawValue)|\(ziele.map(\.id.uuidString).joined(separator: ","))"
    }

    private var lage: Listenlage { zustand.listenlage(tonlisten: true) }

    /// Was die Liste nicht zeigt, mit den Namen der Uhren: wird noch gefragt,
    /// antwortet eine nicht, hat eine keine Adresse, oder liegt dort nichts.
    @ViewBuilder
    private var listenhinweise: some View {
        if lage.laeuft {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Namen werden von der Uhr geholt …")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        if !lage.ausgeblieben.isEmpty {
            Text(lokf("Keine Antwort von %@.", Klangsperre.namen(lage.ausgeblieben)))
                .font(.caption).foregroundStyle(.secondary)
        }
        if !lage.ohneAdresse.isEmpty {
            Text(lokf("%@ hat keine Adresse: Die Namen lassen sich nicht holen.", Klangsperre.namen(lage.ohneAdresse)))
                .font(.caption).foregroundStyle(.secondary)
        }
        if !lage.leer.isEmpty {
            Text(lokf("Auf %@ liegen keine Melodien und keine MP3-Dateien.", Klangsperre.namen(lage.leer)))
                .font(.caption).foregroundStyle(.secondary)
        }
        if !lage.laeuft, lage.ausgeblieben.isEmpty, lage.ohneAdresse.isEmpty, melodienliste.isEmpty, mp3liste.isEmpty {
            Text("Melodien legst du in der Web-Oberfläche der Uhr oder mit „mqtttc002 ton melodie“ an.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var melodienliste: [String] { kannMelodien ? Klangeignung.melodien(in: ziele) : [] }
    private var mp3liste: [String] { zeigtMP3 ? Klangeignung.mp3(in: ziele) : [] }

    private var namenzeile: some View {
        let melodien = melodienliste
        let mp3 = mp3liste
        let unbekannt = !klang.name.isEmpty && !melodien.contains(klang.name) && !mp3.contains(klang.name)
        return LabeledContent("Name") {
            Menu {
                Picker("Name", selection: $klang.name) {
                    Text("Keiner gewählt").tag("")
                    if unbekannt { Text(verbatim: klang.name).tag(klang.name) }
                    if !melodien.isEmpty, kannMelodien {
                        Section("Melodien") {
                            ForEach(melodien, id: \.self) { eintrag($0, symbol: "music.note").tag($0) }
                        }
                    }
                    if !mp3.isEmpty {
                        Section("MP3-Dateien") {
                            ForEach(mp3, id: \.self) { eintrag($0, symbol: "waveform").tag($0) }
                        }
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 4) {
                    if !klang.name.isEmpty, let symbol = symbol(fuer: klang.name, melodien: melodien, mp3: mp3) {
                        Image(systemName: symbol).foregroundStyle(.secondary)
                    }
                    Text(verbatim: klang.name.isEmpty ? lok("Keiner gewählt") : klang.name)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
            }
        }
    }

    /// Ein Name mit einem blassen Zeichen davor: Notenzeichen für Melodien,
    /// Wellenform für MP3-Dateien.
    private func eintrag(_ name: String, symbol: String) -> some View {
        Label { Text(verbatim: name) } icon: { Image(systemName: symbol).foregroundStyle(.secondary) }
    }

    private func symbol(fuer name: String, melodien: [String], mp3: [String]) -> String? {
        if melodien.contains(name) { return "music.note" }
        return mp3.contains(name) ? "waveform" : nil
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

/// Der Abschnitt „Ton“ der Fernbedienung: was gerade spielt, Stopp, Lautstärken,
/// Radio und Startklang. Gelesen wird nur über HTTP; ohne Adresse der Uhr ist der ganze
/// Abschnitt grau, mit dem Grund daneben (wie die Tasten ohne MQTT).
///
/// Sender anlegen und ändern gehört nicht in die App, sondern in die
/// Web-Oberfläche der Uhr (Konfigurieren).
struct Tonabschnitt: View {
    @Bindable var zustand: AppZustand
    let uhr: Uhr
    let kanon: Formkanon

    @State private var sender: String?
    @State private var loeschtMP3: String?
    @State private var loeschtMelodie: String?

    private var id: UUID { uhr.id }
    private var faehigkeiten: Geraetefaehigkeiten? { zustand.faehigkeiten[id] }
    private var ton: Tonzustand? { zustand.tonzustand[id] }
    private var ohneAdresse: Bool { uhr.host.isEmpty }
    /// Die Uhr hat Fähigkeiten gemeldet und keine davon ist Ton: Der Abschnitt
    /// entfällt, die Uhr wird es nie können.
    private var ohneTon: Bool {
        guard let f = faehigkeiten else { return false }
        return f.ton == Tonfaehigkeiten()
    }
    private var gesperrt: Bool { ohneAdresse }
    private var radioGekonnt: Bool {
        faehigkeiten?.kann(.radio) ?? true
    }
    private var mp3Hochladbar: Bool { Klangeignung.mp3Hochladbar(faehigkeiten) }
    private var senderNamen: [String] { (ton?.sender ?? []).map(\.name) }
    private var ablage: Tonablage? { zustand.mp3Ablage[id] }
    private var melodien: Tonablage? { zustand.melodienAblage[id] }

    @ViewBuilder
    var body: some View {
        if !ohneTon { inhalt }
    }

    private var inhalt: some View {
        Section {
            LabeledContent("Spielt") { Text(verbatim: wasSpielt).multilineTextAlignment(.trailing) }
            LabeledContent("Alles anhalten") {
                Button("Stopp") { Task { await zustand.tonStoppen(nil, fuer: id) } }
                    .knopfBefehl()
            }
            Wertregler(titel: lok("Lautstärke"),
                       wert: zustand.uhreneinstellungen[id]?.ganzzahl(.volume) ?? 0, bereich: 0...100,
                       anzeige: { "\($0) %" },
                       setzen: { p in await zustand.einstellungSetzen("volume", wert: "\(p)", fuer: id).ganz })
            .id(id)
            radiozeilen
            // Radiolautstärke, Lautstärke der Apps und Hinweise, Startklang: die
            // Zeilen, die die Uhr meldet (`Einstellungszeile` prüft Schlüssel und
            // Wirkung).
            ForEach(Uhrgruppe.tonpfade, id: \.self) { pfad in
                Einstellungszeile(zustand: zustand, id: id, pfad: pfad)
            }
            klaengezeilen
            if ohneAdresse {
                Label("Ohne Adresse der Uhr nicht lesbar", systemImage: "info.circle")
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
            if !gesperrt, zustand.tonlisten[id] == nil { await zustand.tonlistenAbfragen(id) }
        }
        .confirmationDialog(lokf("„%@“ von der Uhr löschen?", loeschtMP3 ?? ""),
                            isPresented: Binding(get: { loeschtMP3 != nil }, set: { if !$0 { loeschtMP3 = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let name = loeschtMP3 { Task { await zustand.mp3Loeschen(name: name, fuer: id) } }
            }
        }
        .confirmationDialog(lokf("„%@“ von der Uhr löschen?", loeschtMelodie ?? ""),
                            isPresented: Binding(get: { loeschtMelodie != nil }, set: { if !$0 { loeschtMelodie = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let name = loeschtMelodie { Task { await zustand.melodieLoeschen(name: name, fuer: id) } }
            }
        }
    }

    /// Melodien und MP3-Dateien der Uhr: Zahl und Belegung, die Liste, der Knopf
    /// zu den Klängen. Eine Uhr ohne MP3 bekommt weder Knopf noch Hinweis.
    /// Hochgeladen wird nur aus der Sammlung (Bereich „Klänge“).
    @ViewBuilder
    private var klaengezeilen: some View {
        LabeledContent("Klänge auf der Uhr") {
            Text(verbatim: Klangbelegung.zusammenfassung(melodien: melodien, mp3: ablage, mp3Spielbar: mp3Hochladbar))
                .multilineTextAlignment(.trailing)
        }
        ForEach(melodien?.namen ?? [], id: \.self) { name in
            MP3Zeile(name: name, groesse: melodien?.groessen[name], symbol: "music.note") { loeschtMelodie = name }
        }
        if mp3Hochladbar {
            ForEach(ablage?.namen ?? [], id: \.self) { name in
                MP3Zeile(name: name, groesse: ablage?.groessen[name]) { loeschtMP3 = name }
            }
            Button("Klänge verwalten …") { zustand.klaengeVerwalten() }
                .knopfBefehl()
        }
    }

    /// Eine Uhr ohne Radio (TC001, Hardware) bekommt die Zeilen gar nicht.
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

/// Die Sätze, mit denen die Oberfläche sagt, welche Uhr einen Klang nicht spielt.
enum Klangsperre {
    static func namen(_ ziele: [Klangziel]) -> String { namen(ziele.map(\.name)) }
    static func namen(_ namen: [String]) -> String { namen.joined(separator: ", ") }

    /// Bei einer einzigen Zieluhr der Satz, bei mehreren die Namen.
    static func grund(_ ohne: [Klangziel], von gesamt: Int) -> String {
        gesamt == 1 ? lok("Diese Uhr kann diesen Klang nicht abspielen.") : lokf("Nicht abspielbar auf %@", namen(ohne))
    }
}
