import SwiftUI
import UniformTypeIdentifiers
import TC002Core
import TC002Modell

/// Die Klangsammlung in den Einstellungen („Klänge“) — für Mac, iPad und iPhone
/// dieselbe Seite. Die Sammlung ist das Original, die Uhren werden daran
/// angeglichen (`Klangabgleich`): Fehlendes kommt hinzu, Abweichendes wird
/// ersetzt, Überzähliges auf der Uhr bleibt.
public struct Klangsammlungsansicht: View {
    @Bindable var zustand: AppZustand
    let kanon: Formkanon

    @State private var neueMelodie = false
    @State private var waehltDatei = false
    @State private var gewaehlteDateien: [DateiEintrag] = []
    @State private var zuLoeschen: Sammlungsklang?
    @State private var umzubenennen: Sammlungsklang?
    @State private var uebernahme: String?
    @State private var uebernimmt = false
    @State private var abgleichZiele: Set<UUID>?
    @State private var gleichtAb = false
    @State private var ergebnisse: [Uhrenabgleich] = []

    public init(zustand: AppZustand, kanon: Formkanon) {
        self.zustand = zustand
        self.kanon = kanon
    }

    private var klaenge: [Sammlungsklang] { zustand.klaenge() }
    private var uhrenMitAdresse: [Uhr] { zustand.uhren.filter { !$0.host.isEmpty } }
    private var gewaehlteUhren: Set<UUID> {
        abgleichZiele ?? Set(uhrenMitAdresse.map(\.id))
    }

    public var body: some View {
        Form {
            sammlung
            hinzufuegen
            abgleich
            if !ergebnisse.isEmpty { ergebnis }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $neueMelodie) { Melodieblatt(zustand: zustand, kanon: kanon) }
        .sheet(isPresented: Binding(get: { !gewaehlteDateien.isEmpty },
                                    set: { if !$0 { gewaehlteDateien = [] } })) {
            Dateiblatt(zustand: zustand, kanon: kanon, eintraege: gewaehlteDateien)
        }
        .fileImporter(isPresented: $waehltDatei,
                      allowedContentTypes: Self.dateitypen, allowsMultipleSelection: true) { ergebnis in
            guard case .success(let urls) = ergebnis else { return }
            gewaehlteDateien = urls.map { DateiEintrag(url: $0) }
        }
        .confirmationDialog(lokf("„%@“ aus der Sammlung löschen?", zuLoeschen?.name ?? ""),
                            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let k = zuLoeschen { zustand.klangAusSammlungLoeschen(k) }
            }
        } message: {
            Text("Auf den Uhren bleibt der Klang, bis du ihn dort löschst.")
        }
        .sheet(item: $umzubenennen) { k in
            Umbenennblatt(zustand: zustand, kanon: kanon, klang: k)
        }
    }

    static let dateitypen: [UTType] = {
        var typen: [UTType] = [.mp3, .plainText]
        if let t = UTType(filenameExtension: "rtttl") { typen.append(t) }
        return typen
    }()

    // MARK: - Abschnitte

    private var sammlung: some View {
        Section {
            if klaenge.isEmpty {
                Text("Noch leer. Füge Melodien und MP3-Dateien hinzu, dann gleichst du die Uhren daran an.")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            }
            ForEach(klaenge) { k in
                zeile(k)
            }
        } header: {
            Abschnittskopf("Sammlung", hilfe: lok("Die Sammlung liegt in der App und ist das Original: Von hier aus gleichst du die Uhren ab. Melodien sind RTTTL-Texte, MP3-Dateien bleiben Dateien. Der Name gilt auf der Uhr: Buchstaben, Ziffern, _ und -, bei Melodien bis 24 Zeichen, bei MP3-Dateien bis 32. Eine Melodie und eine MP3 teilen sich keinen Namen."))
        }
    }

    private func zeile(_ k: Sammlungsklang) -> some View {
        LabeledContent {
            Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(k.groesse), countStyle: .file))
                .foregroundStyle(.secondary)
        } label: {
            Label {
                Text(verbatim: k.name)
            } icon: {
                Image(systemName: k.art == .melodie ? "music.note" : "waveform")
            }
        }
        .contextMenu {
            if let text = k.rtttl, let uhr = zustand.referenzUhr, !uhr.host.isEmpty,
               zustand.faehigkeiten[uhr.id]?.kann(.rtttl) != false {
                Button(lok("Probehören")) { Task { await zustand.rtttlProbehoeren(text, fuer: uhr.id) } }
            }
            Button(lok("Umbenennen …")) { umzubenennen = k }
            Button(lok("Löschen …"), role: .destructive) { zuLoeschen = k }
        }
        .swipeActions {
            Button(lok("Löschen …"), role: .destructive) { zuLoeschen = k }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: lok("Löschen …")) { zuLoeschen = k }
    }

    private var hinzufuegen: some View {
        Section {
            Menu {
                ForEach(uhrenMitAdresse) { uhr in
                    Button(zustand.uhren.count > 1 ? lokf("Melodien von „%@“ übernehmen", uhr.name)
                                                   : lok("Melodien von der Uhr übernehmen")) {
                        Task { await uebernehmen(uhr) }
                    }
                }
                Button(lok("Melodie eingeben oder einfügen …")) { neueMelodie = true }
                Button(lok("Aus Datei …")) { waehltDatei = true }
            } label: {
                Label("Klang hinzufügen", systemImage: "plus")
            }
            .disabled(uebernimmt)
            if let uebernahme {
                Text(verbatim: uebernahme).font(kanon.fussnote).foregroundStyle(.secondary)
            }
            Text("MP3-Dateien lassen sich nicht von der Uhr holen; sie kommen aus Dateien.")
                .font(kanon.fussnote).foregroundStyle(.secondary)
        } header: {
            Text("Hinzufügen")
        }
    }

    private var abgleich: some View {
        Section {
            if uhrenMitAdresse.isEmpty {
                Text("Keine Uhr mit Adresse. Der Abgleich läuft über die Adresse der Uhr.")
                    .font(kanon.fussnote).foregroundStyle(.secondary)
            }
            ForEach(uhrenMitAdresse) { uhr in
                Toggle(isOn: Binding(
                    get: { gewaehlteUhren.contains(uhr.id) },
                    set: { an in
                        var neu = gewaehlteUhren
                        if an { neu.insert(uhr.id) } else { neu.remove(uhr.id) }
                        abgleichZiele = neu
                    })) {
                    Text(verbatim: uhr.name)
                }
            }
            HStack {
                Button("Mit Uhren abgleichen") { Task { await abgleichen() } }
                    .knopfBefehl()
                    .disabled(gleichtAb || klaenge.isEmpty || gewaehlteUhren.isEmpty)
                if gleichtAb { ProgressView().controlSize(.small) }
            }
            Text("Fehlendes kommt auf die Uhr, Abweichendes wird ersetzt. Was nur auf der Uhr liegt, bleibt dort.")
                .font(kanon.fussnote).foregroundStyle(.secondary)
        } header: {
            Text("Abgleich")
        }
    }

    private var ergebnis: some View {
        Section {
            ForEach(ergebnisse, id: \.uhr) { e in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: e.uhr).font(.headline)
                    if let f = e.fehler {
                        Label(f, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    } else {
                        Text(verbatim: zusammenfassung(e)).foregroundStyle(.secondary)
                        ForEach(e.uebersprungen, id: \.name) { u in
                            Label(lokf("%@ übersprungen: %@", u.name, u.grund.text), systemImage: "info.circle")
                                .font(kanon.fussnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Ergebnis")
        }
    }

    private func zusammenfassung(_ e: Uhrenabgleich) -> String {
        lokf("%d hinzugefügt · %d ersetzt · %d übersprungen · %d unverändert",
             e.hinzugefuegt.count, e.ersetzt.count, e.uebersprungen.count, e.unveraendert.count)
    }

    // MARK: - Arbeit

    private func uebernehmen(_ uhr: Uhr) async {
        uebernimmt = true
        defer { uebernimmt = false }
        guard let b = await zustand.melodienVonUhrUebernehmen(uhr.id) else { uebernahme = nil; return }
        var teile = [lokf("%d neu", b.neu.count)]
        if !b.gleich.isEmpty { teile.append(lokf("%d schon gleich", b.gleich.count)) }
        if !b.uebersprungen.isEmpty {
            teile.append(lokf("%d übersprungen (%@)", b.uebersprungen.count,
                              b.uebersprungen.map { "\($0.name): \($0.grund)" }.joined(separator: "; ")))
        }
        uebernahme = lokf("Von „%@“: ", uhr.name) + teile.joined(separator: " · ")
    }

    private func abgleichen() async {
        gleichtAb = true
        defer { gleichtAb = false }
        let ids = uhrenMitAdresse.map(\.id).filter { gewaehlteUhren.contains($0) }
        ergebnisse = await zustand.klaengeAbgleichen(mit: ids)
    }
}

// MARK: - Umbenennen

struct Umbenennblatt: View {
    @Bindable var zustand: AppZustand
    let kanon: Formkanon
    let klang: Sammlungsklang
    @Environment(\.dismiss) private var schliessen
    @State private var name: String

    init(zustand: AppZustand, kanon: Formkanon, klang: Sammlungsklang) {
        self.zustand = zustand
        self.kanon = kanon
        self.klang = klang
        _name = State(initialValue: klang.name)
    }

    private var gueltig: Bool {
        switch klang.art {
        case .melodie: return (try? Klangbau.melodienameInOrdnung(name)) != nil
        case .mp3: return Klangname.gueltig(name)
        }
    }
    private var belegt: Bool { name != klang.name && zustand.klaenge().contains { $0.name == name } }

    var body: some View {
        Blatt(titel: lok("Umbenennen"), bestaetigung: lok("Umbenennen"),
              bestaetigenMoeglich: gueltig && !belegt && name != klang.name,
              schliessen: { schliessen() }, bestaetigen: umbenennen) {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("Name", text: $name)
                            .eingabefeld(inZeile: kanon)
                            .ohneAutokorrektur()
                    }
                    if !gueltig {
                        Label(lokf("Erlaubt sind Buchstaben, Ziffern, _ und -, höchstens %d Zeichen.",
                                   klang.art == .mp3 ? Klangname.hoechstlaenge : Klangbau.melodienamenGrenze),
                              systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    } else if belegt {
                        Label(lokf("„%@“ gibt es in der Sammlung schon.", name),
                              systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            #if os(macOS)
            .frame(minWidth: 380)
            #endif
        }
    }

    private func umbenennen() {
        zustand.klangUmbenennen(klang, nach: name)
        schliessen()
    }
}

// MARK: - Melodie eingeben

/// Eine Melodie tippen oder einfügen, probehören und sichern.
struct Melodieblatt: View {
    @Bindable var zustand: AppZustand
    let kanon: Formkanon
    @Environment(\.dismiss) private var schliessen

    @State private var text = ""
    @State private var name = ""
    @State private var nameGeaendert = false

    private var pruefung: Result<String, RtttlFehler> {
        do { return .success(try Rtttl.geprueft(text)) } catch { return .failure(error as? RtttlFehler ?? .leer) }
    }
    private var nameFehler: String? {
        do { try Klangbau.melodienameInOrdnung(name) } catch {
            return (error as? LocalizedError)?.errorDescription
        }
        if let k = zustand.klaenge().first(where: { $0.name == name }), k.art == .mp3 {
            return lokf("„%@“ ist in der Sammlung der Name einer MP3.", name)
        }
        return nil
    }
    private var ersetzt: Bool { zustand.klaenge().contains { $0.name == name && $0.art == .melodie } }
    private var darfSichern: Bool { (try? pruefung.get()) != nil && nameFehler == nil }
    private var uhr: Uhr? { zustand.referenzUhr.flatMap { $0.host.isEmpty ? nil : $0 } }
    /// Die Sammlung gilt für alle Uhren, Sichern hängt an keiner. Nur das
    /// Probehören braucht die angesehene Uhr; kann sie nie Melodien spielen
    /// (`audio.rtttl` `false`), entfällt es.
    private var uhrKannNieMelodien: Bool { uhr.map { zustand.faehigkeiten[$0.id]?.kann(.rtttl) == false } ?? false }

    var body: some View {
        Blatt(titel: lok("Melodie"), bestaetigung: lok("Sichern"), bestaetigenMoeglich: darfSichern,
              schliessen: { schliessen() }, bestaetigen: sichern) {
            Form {
                Section {
                    TextField("RTTTL, zum Beispiel ping:d=4,o=5,b=120:c,e,g", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .eingabefeld(inZeile: kanon)
                        .ohneAutokorrektur()
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       case .failure(let f) = pruefung {
                        Label(f.errorDescription ?? "", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    LabeledContent("Name") {
                        TextField("Name", text: $name)
                            .eingabefeld(inZeile: kanon)
                            .ohneAutokorrektur()
                            .onChange(of: name) { _, neu in
                                if neu != Rtttl.namensvorschlag(text) { nameGeaendert = true }
                            }
                    }
                    if let f = nameFehler, !name.isEmpty || nameGeaendert {
                        Label(f, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    } else if ersetzt {
                        Label(lokf("„%@“ gibt es in der Sammlung schon und wird ersetzt.", name),
                              systemImage: "info.circle").foregroundStyle(.secondary)
                    }
                }
                if !uhrKannNieMelodien {
                Section {
                    Button("Probehören") {
                        if let uhr, case .success(let t) = pruefung {
                            Task { await zustand.rtttlProbehoeren(t, fuer: uhr.id) }
                        }
                    }
                    .knopfBefehl()
                    .disabled((try? pruefung.get()) == nil || uhr == nil)
                    Text(verbatim: uhr.map { lokf("Spielt auf „%@“, ohne etwas zu speichern.", $0.name) }
                         ?? lok("Zum Probehören braucht die gewählte Uhr eine Adresse."))
                        .font(kanon.fussnote).foregroundStyle(.secondary)
                }
                }
            }
            .formStyle(.grouped)
            #if os(macOS)
            .frame(minWidth: 460)
            #endif
        }
        .onChange(of: text) { _, neu in
            if !nameGeaendert { name = Rtttl.namensvorschlag(neu) }
        }
    }

    private func sichern() {
        guard darfSichern else { return }
        if zustand.melodieSammeln(name: name, rtttl: text) { schliessen() }
    }
}

// MARK: - Aus Datei

struct DateiEintrag: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
    var istMP3: Bool { url.pathExtension.lowercased() == "mp3" }
}

/// Mehrere gewählte Dateien: je Zeile ein Name auf der Uhr, vorbelegt mit dem
/// Vorschlag aus dem Dateinamen und live geprüft.
struct Dateiblatt: View {
    @Bindable var zustand: AppZustand
    let kanon: Formkanon
    let eintraege: [DateiEintrag]
    @Environment(\.dismiss) private var schliessen

    @State private var namen: [URL: String] = [:]
    @State private var laeuft = false

    private var bestand: [Sammlungsklang] { zustand.klaenge() }

    private func vorschlag(_ e: DateiEintrag) -> String {
        let roh = Klangname.vorschlag(ausDateiname: e.url.deletingPathExtension().lastPathComponent)
        return e.istMP3 ? roh : String(roh.prefix(Klangbau.melodienamenGrenze))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    }
    private func name(_ e: DateiEintrag) -> String { namen[e.url] ?? vorschlag(e) }

    private func fehler(_ e: DateiEintrag) -> String? {
        let n = name(e)
        if e.istMP3 {
            guard Klangname.gueltig(n) else { return lokf("Erlaubt sind Buchstaben, Ziffern, _ und -, höchstens %d Zeichen.", Klangname.hoechstlaenge) }
        } else {
            guard (try? Klangbau.melodienameInOrdnung(n)) != nil else {
                return lokf("Erlaubt sind Buchstaben, Ziffern, _ und -, höchstens %d Zeichen.", Klangbau.melodienamenGrenze)
            }
        }
        if eintraege.filter({ name($0) == n }).count > 1 { return lok("Der Name kommt in dieser Auswahl doppelt vor.") }
        if let k = bestand.first(where: { $0.name == n }), (k.art == .mp3) != e.istMP3 {
            return lokf("„%@“ gehört in der Sammlung schon einem anderen Klang.", n)
        }
        return nil
    }

    private var darfHinzufuegen: Bool { !laeuft && eintraege.allSatisfy { fehler($0) == nil } }

    var body: some View {
        Blatt(titel: lok("Aus Datei"), bestaetigung: lok("Hinzufügen"), bestaetigenMoeglich: darfHinzufuegen,
              schliessen: { schliessen() }, bestaetigen: hinzufuegen) {
            Form {
                ForEach(eintraege) { e in
                    Section {
                        LabeledContent("Datei") {
                            Text(verbatim: e.url.lastPathComponent)
                                .lineLimit(2).truncationMode(.middle).multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Name") {
                            TextField("Name", text: Binding(get: { name(e) }, set: { namen[e.url] = $0 }))
                                .eingabefeld(inZeile: kanon)
                                .ohneAutokorrektur()
                        }
                        if let f = fehler(e) {
                            Label(f, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        } else if bestand.contains(where: { $0.name == name(e) }) {
                            Label(lokf("„%@“ gibt es in der Sammlung schon und wird ersetzt.", name(e)),
                                  systemImage: "info.circle").foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(verbatim: e.istMP3 ? "MP3" : lok("Melodie"))
                    }
                }
            }
            .formStyle(.grouped)
            #if os(macOS)
            .frame(minWidth: 460, minHeight: 240)
            #endif
        }
    }

    private func hinzufuegen() {
        guard darfHinzufuegen else { return }
        laeuft = true
        Task {
            var alleGut = true
            for e in eintraege {
                if await !zustand.dateiSammeln(e.url, name: name(e)) { alleGut = false; break }
            }
            laeuft = false
            if alleGut { schliessen() }
        }
    }
}
