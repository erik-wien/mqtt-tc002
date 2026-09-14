import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

// Melden die Geometrie der schiebbaren Formatpille (Inhaltsbreite, sichtbare
// Breite, Schiebeversatz) von innerhalb der ScrollView nach aussen — daraus
// entscheidet `SendeniOS.zeigtPfeil`, ob rechts noch etwas liegt.
private struct PilleInhaltsbreiteKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct PilleSichtbarKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct PilleVersatzKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Der Kern der App, aufgebaut wie ein Nachrichtenfenster: die Vorschau oben
/// und sichtbar bleibend, Eingabe und Sendeknopf unten über der Tastatur. Wer
/// tippt, will sehen, was herauskommt — stünde die Vorschau unten, verdeckte
/// die Tastatur sie genau dann, wenn man sie braucht.
struct SendeniOS: View {
    @Bindable var zustand: AppZustand

    /// Solange nichts eingerichtet ist (`AppZustand.eingerichtet`: keine Uhr
    /// oder keine eingetragene Brokeradresse), geht das Einstellungsblatt beim
    /// Start von selbst auf. „Senden" waere sonst eine Sackgasse: keine
    /// Vorschau, kein Ziel, und der einzige Weg zu den Einstellungen ist hier
    /// ein Zahnrad in der oberen Leiste — keine Seitenleiste wie am Mac.
    ///
    /// **Ein Blatt und kein Wurzelwechsel**, obwohl der Schreibtisch dort den
    /// Bereich wechselt: `VerbindungiOS` bringt „Fertig" und den Greifer mit
    /// und ist damit auf dem Telefon der eingebuergerte Weg, Fehlendes
    /// nachzutragen. Als Wurzel gaebe es hinter „Fertig" nichts, und der
    /// Benutzer sitzt fest — das Gegenteil der Absicht.
    ///
    /// Im `init` und nicht in `.onAppear`: Der Anfangswert eines `@State` gilt
    /// genau einmal je Ansicht. Wer das Blatt wegwischt, ohne etwas
    /// einzutragen, bekommt es nicht gleich wieder vorgesetzt.
    @State private var zeigeEinstellungen: Bool

    @MainActor
    init(zustand: AppZustand) {
        self.zustand = zustand
        _zeigeEinstellungen = State(initialValue: !zustand.eingerichtet)
    }

    // Dieselben Schlüssel wie auf dem Mac. Wer sie ändert, verliert die
    // Einstellungen einer laufenden Installation.
    @AppStorage("senden.text") private var text = "Hallo"
    @AppStorage("senden.farbe") private var farbeHex = "#00FF66"
    @AppStorage("senden.schriftart") private var schrift = "Silkscreen"
    @AppStorage("senden.groesse") private var groesse = 8.0
    @AppStorage("senden.fett") private var fett = false
    @AppStorage("senden.luecke") private var luecke = 1
    @AppStorage("senden.grossbuchstaben") private var grossbuchstaben = false
    @AppStorage("senden.horizontal") private var horizontal: SendenHAusrichtung = .links
    @AppStorage("senden.vertikal") private var vertikal: SendenVAusrichtung = .oben
    @AppStorage("senden.rand") private var rand = 1
    @AppStorage("senden.weg") private var weg: SendeWeg = .pixel
    @AppStorage("senden.tempo") private var tempo: Lauftempo = .mittel
    @AppStorage("senden.iconmitlaufend") private var iconLaeuftMit = false
    @AppStorage("senden.icon") private var iconNummer = ""
    @AppStorage("senden.meldungsplatz") private var platz = 1
    @AppStorage("senden.dauer") private var dauerText = ""

    @State private var gewaehltesIcon: Icon?
    @State private var laufschriftFrames: [Bildraster.Einzelbild] = []
    @State private var laufschriftURI = ""
    @State private var laeuft = false
    @State private var zeigeFormat = false
    @State private var zeigeIcons = false
    @State private var zeigeVerlauf = false
    // Misst die schiebbare Formatpille, um den Pfeil nur zu zeigen, solange
    // rechts wirklich noch etwas liegt (siehe `zeigtPfeil` unten).
    @State private var pilleInhaltsbreite: CGFloat = 0
    @State private var pilleSichtbareBreite: CGFloat = 0
    @State private var pilleVersatz: CGFloat = 0

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    /// Dieselbe Auswahl wie auf dem Mac — geprueft bei sechzehn Pixeln Hoehe.
    /// Eine Liste fuer alle: Die acht Namen stehen seit der Schriftprobe ueber
    /// alle acht Schriften nur noch in `Schriften.auswahl` im Kern.
    ///
    /// Ungefiltert, anders als am Mac: Das iPhone bringt Geneva und Andale
    /// Mono nicht mit, und was daraus folgt, aendert diese Aufgabe nicht.
    private static let schriften = Schriften.auswahl

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann im Rahmen.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt —
    /// dieselbe Grundlage wie am Mac (`SendenView.belegtePlaetze`).
    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele().flatMap { zustand.anzeigenAufUhr($0.id) })
        return Set((1...Meldungsplatz.anzahl).filter { namen.contains(Meldungsplatz.name(fuer: $0)) })
    }

    /// Je Uhr eine Datei unter Application Support. Die gehaltene Fassung,
    /// nicht bei jedem Zugriff eine neue: `init` legt den Ordner an, und das
    /// gehoert nicht in einen Zugriff, der beim Zeichnen faellt (siehe
    /// `Slotgedaechtnis.gemeinsam`).
    private var gedaechtnis: Slotgedaechtnis { .gemeinsam }

    /// Waehlt den Platz und uebernimmt die gemerkten Regler — aber nur, wenn
    /// das belegbar ist: Pixel muessen mitgelesen worden sein, und ihre
    /// Pruefsumme muss zu den gemerkten Reglern passen. Dieselbe Regel wie am
    /// Mac (`SendenView.slotWaehlen`).
    private func slotWaehlen(_ i: Int) {
        platz = i
        guard let uhr = zustand.referenzUhr,
              let bild = zustand.slotInhalt[uhr.id]?[i],
              let stand = gedaechtnis.gemerkt(fuer: uhr.id, platz: i),
              Slotgedaechtnis.pruefsumme(pixel: bild.pixel) == stand.pruefsumme
        else { return }
        reglerUebernehmen(stand)
    }

    /// Setzt alle Regler auf den gemerkten Stand — dieselben Felder wie am
    /// Mac (`SendenView.reglerUebernehmen`).
    private func reglerUebernehmen(_ stand: Slotstand) {
        guard let o = stand.optionen else { return }
        text = o.text
        weg = o.weg
        schrift = o.schrift
        groesse = o.groesse
        fett = o.fett
        grossbuchstaben = o.grossbuchstaben
        rand = o.rand
        luecke = o.abstand
        horizontal = o.waagrecht
        vertikal = o.senkrecht
        farbeHex = o.farbe
        tempo = o.tempo
        iconLaeuftMit = o.iconLaeuftMit
        dauerText = o.dauer.map(String.init) ?? ""
        // `iconNummer` folgt von selbst aus `.onChange(of: gewaehltesIcon?.nummer)`.
        // Nummer **und** Kante: Das Telefon kennt nur den 8×8-Bestand. Ein am
        // Mac gemerkter Stand mit einem 16×16 findet hier also nichts — und
        // genau das ist richtig. Ohne den Kantenvergleich wuerde stattdessen
        // ein 8×8-Icon derselben Nummer eingesetzt, und die Vorschau zeigte
        // etwas anderes, als auf der Uhr steht.
        gewaehltesIcon = stand.icon.flatMap { nummer in
            sammlung.alle().first { $0.nummer == nummer && $0.kante == stand.iconKanteOderAcht }
        }
    }

    /// Die einzige Stelle, an der aus Ansichtszustand ein Auftrag wird.
    private var optionen: Meldungsoptionen {
        Meldungsoptionen(text: text, weg: weg, schrift: schrift, groesse: groesse,
                         fett: fett, farbe: farbeHex, grossbuchstaben: grossbuchstaben,
                         waagrecht: horizontal, senkrecht: vertikal, rand: rand,
                         abstand: luecke, tempo: tempo, iconLaeuftMit: iconLaeuftMit,
                         dauer: dauer)
    }

    private var mitIcon: Bool { gewaehltesIcon != nil }
    private var passt: Bool { Meldungsbau.passt(optionen, mitIcon: mitIcon) }

    /// Ob der fette Schnitt bei dieser Schrift und Groesse ueberhaupt etwas
    /// aendert — dieselbe Rechnung wie `SendenView.fettWirkt` (Mac). Ein Knopf
    /// ohne Wirkung ist schlimmer als keiner, deshalb wird er gesperrt statt
    /// nur eingefaerbt.
    private var fettWirkt: Bool {
        weg != .text && Textraster.kannFett(schrift: schrift, groesse: groesse)
    }

    /// Ob die Schrift eigene Kleinbuchstaben kennt — dieselbe Rechnung wie
    /// `SendenView.kleinbuchstabenMoeglich` (Mac). Silkscreen etwa setzt alles
    /// in Versalien; dort bliebe der Grossbuchstaben-Schalter wirkungslos.
    private var kleinbuchstabenMoeglich: Bool {
        weg == .text || Textraster.kannKleinbuchstaben(schrift: schrift, groesse: groesse)
    }

    /// Erklaerung fuer den gesperrten Fett-Knopf. Auf dem Telefon gibt es kein
    /// `.help`; VoiceOver bekommt denselben Wortlaut wie die Mac-Hilfe
    /// (`SendenView.fettHilfe`) als accessibilityHint mit.
    private var fettHinweis: String {
        if let grund = gattung.begruendung(.fett) { return grund }
        if weg == .text { return lok("Die Uhr kennt keinen fetten Schnitt — das gilt hier nicht.") }
        if !fettWirkt { return lokf("„%@“ hat bei dieser Größe keinen fetten Schnitt — der Knopf bliebe ohne Wirkung.", schrift) }
        return lok("Fett")
    }

    /// Wie `fettHinweis`, fuer Grossbuchstaben (`SendenView.grossHilfe`, Mac).
    private var grossHinweis: String {
        if let grund = gattung.begruendung(.grossbuchstaben) { return grund }
        if kleinbuchstabenMoeglich {
            return lok("Großbuchstaben — wirkt auf beiden Wegen, das Eingabefeld selbst bleibt unverändert.")
        }
        return lokf("„%@“ kennt nur Großbuchstaben — der Schalter bliebe ohne Wirkung.", schrift)
    }

    /// Erklaerung fuer den Schriftart-Knopf, gesperrt beim Weg „als Text" —
    /// dieselben zwei Saetze wie `.help(...)` an der Schriftart-Auswahl der
    /// Mac-Fassung (SendenView.swift).
    private var schriftartHinweis: String {
        if let grund = gattung.begruendung(.schriftart) { return grund }
        if weg == .text { return lok("Die Uhr hat nur eine eingebaute Schrift — das gilt hier nicht.") }
        return lok("Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")
    }

    /// Die Gattung der angesehenen Uhr. `nil` heisst `.tc002`, wie bei
    /// `Uhr.typ` — ohne eingerichtete Uhr gilt die Werksfirmware.
    private var gattung: Geraetetyp { zustand.referenzUhr?.typ ?? .tc002 }

    /// Eine Ausrichtung, die es auf dieser Gattung nicht gibt, wird beim
    /// Wechsel **sichtbar** zurueckgestellt — sonst zeigte das Menue
    /// „rechtsbuendig" und die Uhr setzte linksbuendig.
    private func ausrichtungPruefen() {
        guard !gattung.waagrechteAusrichtungen.contains(horizontal) else { return }
        horizontal = .links
    }

    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    /// Die Eintraege des Groessenmenues — dieselbe Liste wie am Mac, aus
    /// `Pixelgroessen` im Kern: die durchgesehene Schriftprobe, nicht die
    /// Messung.
    private var angeboteneGroessen: [Double] {
        Pixelgroessen.auswahl(fuer: schrift, mit: groesse)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                ScrollView {
                    VStack(spacing: 14) {
                        VorschauiOS(feld: Meldungsbau.feld(optionen, mitIcon: mitIcon),
                                    icon: (weg == .text || passt) ? gewaehltesIcon?.datei : nil,
                                    laufschriftBilder: (weg == .pixel && !passt) ? laufschriftFrames : nil,
                                    typ: zustand.referenzUhr?.typ)
                        if weg == .pixel && !passt {
                            Text(lokf("Läuft durch: %d Einzelbilder", laufschriftFrames.count))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        blockZeile
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                formatleiste
                eingabe
            }
            .navigationTitle(titel)
            // Der grosse Titel klappt nur beim Scrollen ein, nicht wenn die
            // Tastatur erscheint: iPhone mit Tastatur bleiben dann rund 233
            // von noetigen rund 265 Punkten fuer den Inhalt, die Slot-Zeile
            // liegt unter der Kante, bis man scrollt. .inline bringt die 52
            // Punkte des grossen Titels zurueck; das Titelmenue unten
            // funktioniert dort genauso — Dateien und Notizen machen es so.
            .navigationBarTitleDisplayMode(.inline)
            .titelmenuFallsMehrereUhren(zustand.uhren.count > 1) {
                Picker("Angesehene Uhr", selection: angesehene) {
                    ForEach(zustand.uhren) { uhr in
                        Text(uhr.name).tag(Optional(uhr.id))
                    }
                }
                .pickerStyle(.inline)
                Toggle("An alle Uhren senden", isOn: $zustand.anMehrereUhren)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        zeigeVerlauf = true
                    } label: {
                        Label("Verlauf", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        zeigeEinstellungen = true
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeFormat) {
            FormatblattiOS(weg: $weg, tempo: $tempo, iconLaeuftMit: $iconLaeuftMit,
                           dauerText: $dauerText)
        }
        .sheet(isPresented: $zeigeIcons) {
            IconauswahliOS(gewaehlt: $gewaehltesIcon)
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            VerbindungiOS(zustand: zustand)
        }
        .sheet(isPresented: $zeigeVerlauf) {
            AnzeigeniOS(zustand: zustand)
        }
        .onAppear {
            if gewaehltesIcon == nil, !iconNummer.isEmpty {
                gewaehltesIcon = sammlung.alle().first { $0.nummer == iconNummer }
            }
        }
        .onChange(of: gewaehltesIcon?.nummer) { _, neu in iconNummer = neu ?? "" }
        // Siehe `ausrichtungPruefen()`. `.task(id:)` statt `.onChange`, damit
        // auch der erste Aufbau abgedeckt ist, bei dem noch nichts gewechselt
        // hat — eine seit je gewaehlte Ausrichtung „rechts" traefe sonst auf
        // eine AWTRIX, die sie nicht kennt.
        .task(id: zustand.referenzUhr?.typ) { ausrichtungPruefen() }
        // Wie am Mac (`SendenView`): Nach dem Schriftwechsel gilt die Liste der
        // neuen Schrift; steht die eingestellte Groesse nicht darauf, faellt sie
        // auf die naechstgelegene, nicht auf die kleinste.
        .onChange(of: schrift) { _, neu in
            groesse = Pixelgroessen.naechstgelegene(zu: groesse, fuer: neu)
        }
        .task(id: laufschriftSchluessel) { await laufschriftRechnen() }
    }

    /// Der Titel nennt die **angesehene** Uhr — dieselbe, deren Stand die
    /// fuenf Bloecke und der Verlauf zeigen. Geht die Sendung darueber hinaus,
    /// sagt er zusaetzlich, an wie viele Uhren; sonst stuende hier ein einzelner
    /// Name, waehrend anderswohin gesendet wird. Bei nur einer eingerichteten
    /// Uhr gibt es nichts zu waehlen und nichts zu benennen.
    private var titel: String {
        guard zustand.uhren.count > 1, let uhr = zustand.aktiveUhr else { return lok("Senden") }
        guard zustand.zielIDs.count > 1 else { return uhr.name }
        return lokf("%@ · an %d Uhren", uhr.name, zustand.zielIDs.count)
    }

    /// Das Titelmenue waehlt, welche Uhr man ansieht. Dass damit auch das
    /// Sendeziel wechselt, entscheidet `AppZustand.uhrAnsehen` — auf dem
    /// Telefon sind das dieselbe Wahl, und der Nebenweg „an alle Uhren"
    /// steht als eigener Schalter darunter im selben Menue.
    private var angesehene: Binding<UUID?> {
        Binding(get: { zustand.aktiveID },
                set: { neu in if let neu { zustand.uhrAnsehen(neu) } })
    }

    /// Die fuenf Bloecke zeigen, was auf der aktiven Uhr liegt
    /// (`AppZustand.referenzUhr`) — Antippen waehlt den Platz und stellt,
    /// wenn belegbar, die Regler wieder her (siehe `slotWaehlen`). Was ein
    /// Block zeigt, rechnet `AppZustand.slotzustand` fuer alle Oberflaechen
    /// gleich.
    ///
    /// **Die Bloecke nehmen die ganze Breite.** Bis zum 14.09.2026 waren sie
    /// auf 44×44 festgenagelt — die Zeile war damit 294 Punkte breit und
    /// stand mit dem Dauer-Feld daneben. Ein Block zeigt aber das Display der
    /// Uhr, und das ist 52 zu 16: In 44 Punkten Breite blieben 13 Punkte
    /// Hoehe, auf denen nichts zu erkennen war. Seit das Dauer-Feld im
    /// Formatblatt sitzt, hat die Zeile die Breite fuer sich; jeder Block
    /// nimmt ein Fuenftel davon und wird dadurch um die Haelfte groesser.
    /// Die 44 Punkte bleiben als **Mindestmass** in `Slotblock` stehen, wo
    /// sie hingehoeren.
    private var blockZeile: some View {
        HStack(spacing: 8) {
            ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
                Button { slotWaehlen(i) } label: {
                    Slotblock(platz: i,
                              zustand: zustand.slotzustand(i, belegt: belegtePlaetze.contains(i)),
                              gewaehlt: platz == i)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                // **Dieselbe Entscheidung wie am Schreibtisch**: Das Loeschen
                // gehoert an den Block, den es betrifft, nicht als sechster
                // Knopf daneben. Der Papierkorb bezog sich auf den gerade
                // *gewaehlten* Platz — man musste ihn erst treffen — und nahm
                // in einer Zeile, die auf 44 Punkte je Platz gerechnet ist,
                // einen ganzen weiteren Platz ein.
                //
                // Das ⊗ liegt **ausserhalb** des Blockknopfes: Innen waere es
                // Teil von dessen Beschriftung und loeste beim Tippen die
                // Platzwahl aus statt zu loeschen.
                .overlay(alignment: .topTrailing) {
                    MeldungLoeschenKnopf(zustand: zustand, platz: i,
                                         belegt: belegtePlaetze.contains(i))
                        .offset(x: 6, y: -6)
                }
            }
        }
    }

    /// Symbol fuer den Stand der waagrechten Ausrichtung — kein Ternaer, sonst
    /// greift die nicht uebersetzende Overload von `Image(systemName:)`.
    private var horizontalSymbol: String {
        switch horizontal {
        case .links: return "text.alignleft"
        case .mittig: return "text.aligncenter"
        case .rechts: return "text.alignright"
        }
    }

    /// Dieselben Symbole wie am Mac (`ausrichtungsKnopf` in SendenView.swift).
    private var vertikalSymbol: String {
        switch vertikal {
        case .oben: return "align.vertical.top"
        case .mittig: return "align.vertical.center"
        case .unten: return "align.vertical.bottom"
        }
    }

    /// Wortlaut fuer die Bedienungshilfen der beiden Ausrichtungsknoepfe —
    /// dieselben Woerter wie in ihren Menues, kein Ternaer (siehe
    /// `horizontalSymbol` oben), kein neuer Uebersetzungsschluessel.
    private var horizontalWort: LocalizedStringKey {
        switch horizontal {
        case .links: return "Linksbündig"
        case .mittig: return "Zentriert"
        case .rechts: return "Rechtsbündig"
        }
    }
    private var vertikalWort: LocalizedStringKey {
        switch vertikal {
        case .oben: return "Oben"
        case .mittig: return "Mittig"
        case .unten: return "Unten"
        }
    }

    /// Sprachausgabe fuer den Sendeknopf, der laufend nur ein Symbol zeigt —
    /// dieselben zwei Woerter wie im Mac-Knopf (`SendenView.swift`), kein
    /// Ternaer (siehe `horizontalSymbol` oben), kein neuer Uebersetzungsschluessel.
    private var sendenWort: LocalizedStringKey {
        if laeuft { return "Sende…" }
        return "Senden"
    }

    /// Der Pfeil am rechten Rand der Pille zeigt nur an, solange dort
    /// wirklich noch etwas liegt, und verschwindet, sobald ganz durchgeschoben
    /// ist — sonst verspraeche er etwas, das nicht mehr da ist. 1pt Toleranz
    /// gegen Rundung der gemeldeten Groessen.
    private var zeigtPfeil: Bool {
        let rest = pilleInhaltsbreite - pilleSichtbareBreite - pilleVersatz
        return pilleInhaltsbreite > pilleSichtbareBreite + 1 && rest > 1
    }

    /// Was man ständig ändert, direkt erreichbar. Elf gleichwertige Symbole
    /// wie in Pages, nichts hinter einer Sammelstelle. Sie passen nicht alle
    /// nebeneinander auf ein Telefon, deshalb schiebbar — die ersten fuenf
    /// (Icon, waagrecht, senkrecht, Farbe, Pinsel) muessen dafuer ohne
    /// Schieben sichtbar bleiben, siehe Bericht zur Breitenrechnung. Farbe
    /// steht bewusst nicht neben Icon: beide sind bunt und rund, nebeneinander
    /// leicht verwechselt; mit dem Pinsel dazwischen nicht mehr.
    private var formatleiste: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { zeigeIcons = true } label: {
                        Group {
                            if let icon = gewaehltesIcon {
                                // Beide Groessen gleich gross: Ein 16×16 ist
                                // nicht das doppelt so grosse Bild, sondern
                                // das feinere — dieselbe Ueberlegung wie im
                                // Raster am Schreibtisch.
                                IconbildiOS(datei: icon.datei,
                                            kante: 20 / Double(icon.kante),
                                            pixelkante: icon.kante)
                            } else {
                                Image(systemName: "face.smiling")
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    // Symbol in einer Leiste, kein Befehlsknopf: Diese
                    // Pille ist die Werkzeugleiste des Telefons. Gilt fuer
                    // alle vier Knoepfe darin.
                    .buttonStyle(.automatic)
                    .accessibilityLabel("Icon")
                    Menu {
                        Button { horizontal = .links } label: {
                            Label("Linksbündig", systemImage: "text.alignleft")
                        }
                        Button { horizontal = .mittig } label: {
                            Label("Zentriert", systemImage: "text.aligncenter")
                        }
                        // Nicht gesperrt, sondern nicht vorhanden — dieselbe
                        // Begruendung wie in SendenView.swift: Ein Eintrag, der
                        // angenommen und dann als linksbuendig gesendet wuerde,
                        // zeigte etwas anderes an, als auf der Uhr steht.
                        if gattung.waagrechteAusrichtungen.contains(.rechts) {
                            Button { horizontal = .rechts } label: {
                                Label("Rechtsbündig", systemImage: "text.alignright")
                            }
                        }
                    } label: {
                        Image(systemName: horizontalSymbol)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(lok("Ausrichtung")) + Text(" ") + Text(horizontalWort))
                    Menu {
                        Button { vertikal = .oben } label: {
                            Label("Oben", systemImage: "align.vertical.top")
                        }
                        Button { vertikal = .mittig } label: {
                            Label("Mittig", systemImage: "align.vertical.center")
                        }
                        Button { vertikal = .unten } label: {
                            Label("Unten", systemImage: "align.vertical.bottom")
                        }
                    } label: {
                        Image(systemName: vertikalSymbol)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(!gattung.wirkt(.senkrecht))
                    .accessibilityLabel(Text(lok("Ausrichtung")) + Text(" ") + Text(vertikalWort))
                    .accessibilityHint(Text(gattung.begruendung(.senkrecht) ?? lok("Senkrecht ausrichten")))
                    ColorPicker("Farbe", selection: farbe, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Farbe")
                    Button { zeigeFormat = true } label: {
                        Image(systemName: "paintbrush")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.automatic)
                    .accessibilityLabel("Format")
                    Menu {
                        Picker("Schriftart", selection: $schrift) {
                            ForEach(Self.schriften, id: \.self) { Text($0).tag($0) }
                        }
                    } label: {
                        Text(schrift)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(weg == .text)
                    .disabled(!gattung.wirkt(.schriftart))
                    .accessibilityLabel(Text(lok("Schriftart")) + Text(" ") + Text(schrift))
                    .accessibilityHint(Text(schriftartHinweis))
                    Menu {
                        // Eine Liste, keine Folge: Die durchgesehenen Groessen
                        // haben Luecken — Tiny5 etwa 7, 8, 9, 12, 15, 16.
                        Picker("Größe", selection: $groesse) {
                            ForEach(angeboteneGroessen, id: \.self) { g in
                                Text(String(Int(g))).tag(g)
                            }
                        }
                    } label: {
                        Label { Text(String(Int(groesse))) } icon: { Image(systemName: "textformat.size") }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(!gattung.wirkt(.groesse))
                    .accessibilityLabel(Text(lokf("Größe %d", Int(groesse))))
                    .accessibilityHint(Text(gattung.begruendung(.groesse) ?? lok("Schriftgröße")))
                    Button { fett.toggle() } label: {
                        Image(systemName: "bold")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.automatic)
                    .foregroundStyle(fett ? Color.accentColor : Color.secondary)
                    // Nicht allein die Farbe traegt den Zustand — sonst hiesse
                    // Blau zugleich "tippbar" (wie bei den Menueknoepfen daneben)
                    // und "eingeschaltet". Ein Hintergrund macht "an" auch ohne
                    // Farbwahrnehmung sichtbar, dieselbe Bauart wie `formatKnopf`
                    // in der Mac-Fassung (SendenView.swift).
                    .background(fett ? Color.accentColor.opacity(0.3) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    // Wie am Mac (`fettWirkt`) statt nur beim Weg „als Text":
                    // auch Schriften/Groessen ohne fetten Schnitt sperren den
                    // Knopf, sonst waere er bedienbar, ohne etwas zu bewirken.
                    .disabled(!fettWirkt)
                    .disabled(!gattung.wirkt(.fett))
                    .accessibilityLabel("Fett")
                    .accessibilityHint(Text(fettHinweis))
                    .accessibilityAddTraits(fett ? [.isSelected] : [])
                    Button { grossbuchstaben.toggle() } label: {
                        Image(systemName: "capslock")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.automatic)
                    .foregroundStyle(grossbuchstaben ? Color.accentColor : Color.secondary)
                    .background(grossbuchstaben ? Color.accentColor.opacity(0.3) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(!kleinbuchstabenMoeglich)
                    .accessibilityLabel("Großbuchstaben")
                    .accessibilityHint(Text(grossHinweis))
                    .accessibilityAddTraits(grossbuchstaben ? [.isSelected] : [])
                    Menu {
                        Picker("Rand", selection: $rand) {
                            ForEach(0...3, id: \.self) { n in Text(String(n)).tag(n) }
                        }
                    } label: {
                        Label { Text(String(rand)) } icon: { Image(systemName: "arrow.up.and.down") }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    // Wie am Mac (SendenView.swift): bei "Mittig" wirkt der
                    // Rand nicht, deshalb gesperrt statt nur bedienbar ohne
                    // Wirkung.
                    .disabled(vertikal == .mittig)
                    .disabled(!gattung.wirkt(.rand))
                    .accessibilityLabel(Text(lokf("Rand %d", rand)))
                    .accessibilityHint(Text(gattung.begruendung(.rand) ?? lok("Zeilen, die bei „oben“ und „unten“ frei bleiben — 0 setzt die Schrift bündig an den Rand. Bündig sieht je nach Schrift verschieden aus, weil manche über der Großbuchstabenhöhe Platz mitbringen und andere nicht; ein eigener Rand macht den Eindruck davon unabhängig. Bei „mittig“ wirkt er nicht.")))
                    Menu {
                        Picker("Abstand", selection: $luecke) {
                            ForEach(0...3, id: \.self) { n in Text(String(n)).tag(n) }
                        }
                    } label: {
                        Label { Text(String(luecke)) } icon: { Image(systemName: "arrow.left.and.right") }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(!gattung.wirkt(.abstand))
                    .accessibilityLabel(Text(lokf("Abstand %d", luecke)))
                }
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: PilleInhaltsbreiteKey.self, value: geo.size.width)
                            .preference(key: PilleVersatzKey.self,
                                        value: -geo.frame(in: .named("pilleRaum")).minX)
                    }
                )
            }
            .coordinateSpace(.named("pilleRaum"))
            // Keine feste Hoehe mehr: Bei den groessten Bedienungshilfen-
            // Schriftgroessen wuchs .body auf rund 53 Punkte Zeilenhoehe, eine
            // starre 60-Punkte-Pille schnitt den Inhalt dann ab. Ohne Vorgabe
            // richtet sich die Hoehe nach dem Inhalt — die Kapsel wird dann
            // hoeher statt etwas abzuschneiden.
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PilleSichtbarKey.self, value: geo.size.width)
                }
            )
            .background(.thinMaterial)
            .clipShape(Capsule())
            .onPreferenceChange(PilleInhaltsbreiteKey.self) { pilleInhaltsbreite = $0 }
            .onPreferenceChange(PilleVersatzKey.self) { pilleVersatz = $0 }
            .onPreferenceChange(PilleSichtbarKey.self) { pilleSichtbareBreite = $0 }

            if zeigtPfeil {
                Image(systemName: "chevron.compact.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Weitere Bedienelemente")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var eingabe: some View {
        HStack(spacing: 8) {
            TextField("Text", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await senden() }
            } label: {
                Group {
                    if laeuft {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            // Die Haupthandlung des Telefons — aber nicht als gefuellter
            // Kasten: Der gefuellte Pfeil **ist** hier die Hervorhebung, wie
            // in Nachrichten und Mail. Ein `.borderedProminent` darum herum
            // waere die Antwort des Macs auf die Frage des iPhones.
            // Ausdruecklich `.automatic`, damit die Entscheidung im
            // Quelltext steht.
            .buttonStyle(.automatic)
            .disabled(laeuft || text.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel(Text(sendenWort))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhängt — damit die (nicht
    /// ganz billige) Berechnung nur bei einer tatsächlichen Änderung neu läuft.
    private var laufschriftSchluessel: String {
        "\(weg)|\(passt)|\(optionen.gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(rand)|\(iconNummer)|\(iconLaeuftMit)|\(luecke)"
    }

    /// Mehrere hundert Einzelbilder rastern, als GIF kodieren, Base64 darüber —
    /// bei jedem Tastendruck. Das gehört nicht auf den Hauptthread, sonst
    /// stockt das Eingabefeld.
    private func laufschriftRechnen() async {
        guard weg == .pixel, !passt else {
            laufschriftFrames = []; laufschriftURI = ""; return
        }
        let o = optionen
        let iconBilder = gewaehltesIcon.flatMap { i -> [[String?]]? in
            try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
        } ?? []
        let (frames, uri) = await Task.detached(priority: .userInitiated) {
            let frames = Meldungsbau.laufschriftBilder(o, iconBilder: iconBilder)
            let uri = (try? Bildraster.alsDatenURI(
                frames.map(\.pixel), breite: Pixelfeld.breiteStandard,
                hoehe: Pixelfeld.hoeheStandard, verzoegerung: o.tempo.bilddauer)) ?? ""
            return (frames, uri)
        }.value
        guard !Task.isCancelled else { return }
        laufschriftFrames = frames
        laufschriftURI = uri
    }

    private func senden() async {
        laeuft = true
        defer { laeuft = false }
        do {
            let rahmen = try Meldungsbau.rahmen(optionen, icon: gewaehltesIcon,
                                                sammlung: sammlung, vorberechnet: laufschriftURI)
            // Momentaufnahme fuer das Slotgedaechtnis — dieselbe Bauart wie
            // am Mac (SendenView.senden()).
            let slotOptionen = optionen
            await zustand.senden(rahmen, als: Meldungsplatz.name(fuer: platz), slotOptionen: slotOptionen,
                                 slotIcon: gewaehltesIcon?.nummer,
                                 slotIconKante: gewaehltesIcon?.kante ?? 8, slotPlatz: platz)
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}

/// Loescht den gewaehlten Meldungsplatz auf den gewaehlten Uhren — dieselbe
/// Bauart wie `MeldungLoeschenKnopf` in `SendenView.swift` (Mac), als eigene
/// Kopie: `TC002App` (Mac) und `MQTT-TC002-iOS` sind getrennte ausfuehrbare
/// Ziele, keins kann Typen vom anderen einbinden. Die 44×44-Trefferflaeche
/// kommt dazu, wie bei den uebrigen Symbolknoepfen dieser Datei (siehe
/// `formatleiste`) — am Mac reicht die Knopfgroesse von selbst, ein Zeiger
/// trifft auch kleine Ziele.
private struct MeldungLoeschenKnopf: View {
    @Bindable var zustand: AppZustand
    let platz: Int
    /// Ein leerer Platz laesst sich nicht loeschen. Woher das bekannt ist,
    /// steht bei `belegtePlaetze`: gemeldet schlaegt gemerkt.
    let belegt: Bool

    @State private var laeuft = false

    private var beschriftung: String { lokf("Slot %d auf der Uhr löschen", platz) }

    var body: some View {
        // **Nur an belegten Plaetzen.** Ein leerer Platz hat nichts zu
        // loeschen; ein abgeblendetes ⊗ an vier von fuenf Bloecken waere
        // Unruhe ohne Aussage.
        if belegt {
            Button(role: .destructive) {
                laeuft = true
                let name = Meldungsplatz.name(fuer: platz)
                Task { await zustand.loeschen(name); laeuft = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .font(.system(size: 15))
                    // Polsterung statt Symbolgroesse: Das Zeichen bleibt
                    // klein, die Trefferflaeche waechst. 44 Punkte wie bei
                    // den uebrigen Symbolknoepfen dieser Datei waeren hier
                    // groesser als der Block selbst.
                    .padding(6)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(laeuft || zustand.ziele().isEmpty)
            .accessibilityLabel(Text(beschriftung))
            // Das Gegenstueck zum fehlenden sichtbaren Namen: Der Knopf
            // wiederholt sich fuenfmal, ein Langdruck nennt ihn beim Namen.
            .contextMenu {
                Button(role: .destructive) {
                    laeuft = true
                    let name = Meldungsplatz.name(fuer: platz)
                    Task { await zustand.loeschen(name); laeuft = false }
                } label: { Text(beschriftung) }
            }
        }
    }
}

private extension View {
    /// Haengt das Auswahlmenue an den Titel, aber nur ab zwei Uhren — bei
    /// genau einer waere ein Menue mit einem Eintrag eine Falle, keine
    /// Auswahl, und der Titel bleibt schlichter Text ohne Pfeil.
    @ViewBuilder
    func titelmenuFallsMehrereUhren<Inhalt: View>(_ mehrere: Bool,
                                                  @ViewBuilder inhalt: () -> Inhalt) -> some View {
        if mehrere {
            toolbarTitleMenu(content: inhalt)
        } else {
            self
        }
    }
}
