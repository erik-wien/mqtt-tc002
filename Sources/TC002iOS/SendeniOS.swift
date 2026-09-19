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
    /// Ein Blatt und kein Wurzelwechsel, obwohl der Schreibtisch dort den
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
    @State private var zeigeBilder = false
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
    /// Die Rechnung steht im Modell (`AppZustand.belegtePlaetze`) und fragt
    /// die angesehene Uhr, dieselbe, aus der `slotzustand` den Inhalt nimmt:
    /// Gegen die Zielmenge gefragt, setzte ein Block Belegung und Inhalt aus
    /// verschiedenen Uhren zusammen.
    private var belegtePlaetze: Set<Int> { zustand.belegtePlaetze() }

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
        reglerUebernehmen(o, icon: stand.icon, iconKante: stand.iconKanteOderAcht)
    }

    /// Dasselbe aus einem Verlaufseintrag — ein Rumpf fuer beide Quellen, wie
    /// am Schreibtisch.
    private func reglerUebernehmen(_ eintrag: Verlaufseintrag) {
        reglerUebernehmen(eintrag.optionen, icon: eintrag.iconNummer, iconKante: eintrag.iconKante)
        if let platz = eintrag.platz { self.platz = platz }
    }

    private func reglerUebernehmen(_ o: Meldungsoptionen, icon: String?, iconKante: Int) {
        text = o.text
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
        // Nummer und Kante: Das Telefon kennt nur den 8×8-Bestand. Ein am
        // Mac gemerkter Stand mit einem 16×16 findet hier also nichts — und
        // genau das ist richtig. Ohne den Kantenvergleich wuerde stattdessen
        // ein 8×8-Icon derselben Nummer eingesetzt, und die Vorschau zeigte
        // etwas anderes, als auf der Uhr steht.
        gewaehltesIcon = icon.flatMap { nummer in
            sammlung.alle().first { $0.nummer == nummer && $0.kante == iconKante }
        }
    }

    /// Die einzige Stelle, an der aus Ansichtszustand ein Auftrag wird.
    private var optionen: Meldungsoptionen {
        Meldungsoptionen(text: text, schrift: schrift, groesse: groesse,
                         fett: fett, farbe: farbeHex, grossbuchstaben: grossbuchstaben,
                         waagrecht: horizontal, senkrecht: vertikal, rand: rand,
                         abstand: luecke, tempo: tempo, iconLaeuftMit: iconLaeuftMit,
                         dauer: dauer)
    }

    private var mitIcon: Bool { gewaehltesIcon != nil }

    /// Auf wie vielen Punkten die Vorschau rechnet — den Maßen der angesehenen
    /// Uhr. Dieselbe Überlegung wie in `SendenView` am Schreibtisch.
    private var mass: Anzeigemass { zustand.referenzUhr.map(Anzeigemass.fuer) ?? .tc002 }

    /// Womit die Vorschau rastert: Auf einer NG-Uhr mit fester
    /// Näherungsschrift, weil das Gerät den Text selbst setzt. Gesendet werden
    /// unverändert `optionen`.
    private var vorschauOptionen: Meldungsoptionen { optionen.naeherung(fuer: gattung) }

    /// Die Vorschau einer bestimmten Uhr — jede hat ihr eigenes Maß und ihre
    /// eigene Gattung. Die Laufschrift bekommt nur die angesehene: Ihre
    /// Einzelbilder sind auf deren Maß gerechnet und wären auf einem anderen
    /// das falsche Bild.
    @ViewBuilder
    private func vorschau(fuer uhr: Uhr, angesehen: Bool) -> some View {
        let uhrmass = Anzeigemass.fuer(uhr)
        let o = optionen.naeherung(fuer: uhr.typ ?? .tc002)
        let sitzt = Meldungsbau.passt(o, mitIcon: mitIcon, mass: uhrmass)
        VorschauiOS(feld: Meldungsbau.feld(o, mitIcon: mitIcon, mass: uhrmass),
                    icon: sitzt ? gewaehltesIcon?.datei : nil,
                    laufschriftBilder: (sitzt || !angesehen) ? nil : laufschriftFrames,
                    typ: uhr.typ)
    }

    private var passt: Bool {
        Meldungsbau.passt(vorschauOptionen, mitIcon: mitIcon, mass: mass)
    }

    /// Laeuft der Text als Laufschrift, ist die waagrechte Ausrichtung ohne
    /// Wirkung — `Textraster.laufschriftEinzelbilder` schiebt ihn immer von
    /// ganz aussen durchs Fenster. Wortgleich mit `SendenView`.
    private var waagrechtWirktNicht: Bool { !passt }

    /// Ob der fette Schnitt bei dieser Schrift und Groesse ueberhaupt etwas
    /// aendert — dieselbe Rechnung wie `SendenView.fettWirkt` (Mac). Ein Knopf
    /// ohne Wirkung ist schlimmer als keiner, deshalb wird er gesperrt statt
    /// nur eingefaerbt.
    private var fettWirkt: Bool {
        Textraster.kannFett(schrift: schrift, groesse: groesse)
    }

    /// Ob die Schrift eigene Kleinbuchstaben kennt — dieselbe Rechnung wie
    /// `SendenView.kleinbuchstabenMoeglich` (Mac). Silkscreen etwa setzt alles
    /// in Versalien; dort bliebe der Grossbuchstaben-Schalter wirkungslos.
    private var kleinbuchstabenMoeglich: Bool {
        Textraster.kannKleinbuchstaben(schrift: schrift, groesse: groesse)
    }

    /// Erklaerung fuer den gesperrten Fett-Knopf. Auf dem Telefon gibt es kein
    /// `.help`; VoiceOver bekommt denselben Wortlaut wie die Mac-Hilfe
    /// (`SendenView.fettHilfe`) als accessibilityHint mit.
    private var fettHinweis: String {
        if let grund = gattung.begruendung(.fett) { return grund }
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
        return lok("Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")
    }

    /// Die Gattung der angesehenen Uhr. `nil` heisst `.tc002`, wie bei
    /// `Uhr.typ` — ohne eingerichtete Uhr gilt die Werksfirmware.
    private var gattung: Geraetetyp { zustand.referenzUhr?.typ ?? .tc002 }

    /// Eine Ausrichtung, die es auf dieser Gattung nicht gibt, wird beim
    /// Wechsel sichtbar zurueckgestellt — sonst zeigte das Menue
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

    /// Der Rumpf ohne die Blaetter.
    ///
    /// Ein SwiftUI-Rumpf ist ein einziger Ausdruck: NavigationStack,
    /// Titelmenue, Werkzeugleiste, fuenf Blaetter und vier Beobachter
    /// zusammen bringen den Uebersetzer bei `body` zum Aufgeben („unable to
    /// type-check this expression in reasonable time"). Die Teilung laeuft
    /// entlang der Naht, die ohnehin da ist — was man sieht, und was sich
    /// darueberlegt.
    private var rumpf: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                mitte
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
                // Nur, was man ansieht: Die Empfaenger stehen im
                // Antennenmenue neben dem Eingabefeld — wie am Schreibtisch,
                // wo der Titel die angesehene Uhr traegt und ein eigener Knopf
                // die Empfaenger. Beides in einem Menue ginge nicht: iOS zeigt
                // hier keine Abschnittsueberschriften, uebrig blieben zwei
                // unbeschriftete Listen derselben Uhren, in umgekehrter
                // Reihenfolge, weil das Menue nach oben aufklappt.
                Picker("Angesehene Uhr", selection: angesehene) {
                    ForEach(zustand.uhren) { uhr in
                        Text(uhr.name).tag(Optional(uhr.id))
                    }
                }
                .pickerStyle(.inline)
            }
            .toolbar {
                // Links die Empfaenger, mittig die angesehene Uhr, rechts
                // Protokoll und Einstellungen. Neben dem Eingabefeld hielt
                // der erste Anwender den Empfaengerknopf fuer den Sendeknopf.
                ToolbarItem(placement: .topBarLeading) {
                    empfaengermenue
                }
                // Ohne Protokoll kein Knopf dafuer — er fuehrte in eine
                // leere Ansicht.
                if zustand.protokollAn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            zeigeVerlauf = true
                        } label: {
                            Label("Protokoll", systemImage: "clock.arrow.circlepath")
                        }
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
    }

    var body: some View {
        rumpf
        .sheet(isPresented: $zeigeFormat) {
            FormatblattiOS(tempo: $tempo, iconLaeuftMit: $iconLaeuftMit,
                           dauerText: $dauerText)
        }
        .sheet(isPresented: $zeigeBilder) {
            BildauswahliOS(platz: platz, zustand: zustand)
        }
        .sheet(isPresented: $zeigeIcons) {
            IconauswahliOS(gewaehlt: $gewaehltesIcon,
                           sperre: { zustand.grafikSperre(hoehe: $0) })
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

    /// Der Titel nennt die angesehene Uhr — dieselbe, deren Stand die
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
    /// Die Bloecke nehmen die ganze Breite: Auf 44×44 festgenagelt waere die
    /// Zeile nur 294 Punkte breit. Ein Block zeigt aber das Display der Uhr,
    /// und das ist 52 zu 16 — bei 44 Punkten Breite blieben 13 Punkte Hoehe,
    /// auf denen nichts zu erkennen ist. Mit der Zeile fuer sich allein nimmt
    /// jeder Block ein Fuenftel der Breite und wird dadurch um die Haelfte
    /// groesser. Die 44 Punkte bleiben als Mindestmass in `Slotblock` stehen,
    /// wo sie hingehoeren.
    private var blockZeile: some View {
        HStack(spacing: 8) {
            ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
                Button { slotWaehlen(i) } label: {
                    Slotblock(platz: i,
                              zustand: zustand.slotzustand(i, belegt: belegtePlaetze.contains(i)),
                              gewaehlt: platz == i,
                              mass: mass)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                // Dieselbe Entscheidung wie am Schreibtisch: Das Loeschen
                // gehoert an den Block, den es betrifft, nicht als sechster
                // Knopf daneben. Ein Papierkorb, der sich auf den gerade
                // gewaehlten Platz bezieht, muss erst getroffen werden und
                // nimmt in einer Zeile, die auf 44 Punkte je Platz gerechnet
                // ist, einen ganzen weiteren Platz ein.
                //
                // Das ⊗ liegt ausserhalb des Blockknopfes: Innen waere es
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

    /// Die Mitte der Sendeansicht als eigenes Glied.
    ///
    /// Nicht der Ordnung halber: Ein SwiftUI-Rumpf ist ein einziger Ausdruck,
    /// und dessen Pruefung waechst ueberproportional — ueber eine gewisse
    /// Groesse gibt der Uebersetzer bei `body` auf („unable to type-check
    /// this expression in reasonable time"). Ihn zu teilen ist die Loesung,
    /// nicht ein Kunstgriff.
    /// Der ganze Bildschirm ist **eine** Liste — so bauen Mail, Nachrichten
    /// und die Einstellungen ihre Bildschirme. Vorschau und Slotleiste sind
    /// Zeilen darin, der Verlauf ein Abschnitt (`Verlaufsabschnitt`).
    ///
    /// Vorher stand eine `List` in einer `ScrollView`: Eine Liste bekommt dort
    /// keine eigene Hoehe, brauchte deshalb eine feste — und eine feste Hoehe
    /// mit wenigen Zeilen verteilt den Rest als Leere. Dazu waren es zwei
    /// ineinander rollende Bereiche, die am Finger nicht auseinanderzuhalten
    /// sind. Mit einer Liste rollt der Bildschirm als Ganzes: wenig Verlauf
    /// heisst wenig Zeilen und darunter nichts, viel Verlauf schiebt die
    /// Vorschau nach oben weg.
    @ViewBuilder
    private var mitte: some View {
        List {
            // Wischen ueber der Vorschau wechselt die angesehene
            // Uhr, die Punktreihe darunter sagt, die wievielte es
            // ist — dieselben zwei Bausteine wie am Schreibtisch
            // (`Uhrenwahl.swift`).
            VStack(spacing: 0) {
                Uhrenblaetterer(zustand: zustand) { uhr, angesehen in
                    vorschau(fuer: uhr, angesehen: angesehen)
                }
                Uhrenpunkte(zustand: zustand)
            }
            .listenzeileOhneRahmen(rand: 0)

            VStack(spacing: 8) {
                if !passt {
                    Text(lokf("Läuft durch: %d Einzelbilder", laufschriftFrames.count))
                        .font(.caption).foregroundStyle(.secondary)
                }
                blockZeile
            }
            .listenzeileOhneRahmen(rand: 16)

            // Der Verlauf fuellt die Flaeche unter den Bloecken mit dem, was
            // man am haeufigsten will: dasselbe noch einmal.
            Verlaufsabschnitt(zustand: zustand) { reglerUebernehmen($0) }
        }
        .listStyle(.plain)
        // Vor der Ueberschrift stuende sonst der Abstand eines eigenen
        // Kapitels; hier trennt sie nur Slotleiste und Verlauf, und die
        // gehoeren zusammen auf einen Bildschirm.
        .listSectionSpacing(0)
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
                                IconbildiOS(datei: icon.datei, pixelkante: icon.kante)
                                    .frame(width: 20, height: 20)
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
                    // `Picker` und nicht einzelne Knoepfe: Nur so traegt der
                    // gewaehlte Eintrag sein Haekchen, wie in den Menues der
                    // Einstellungen auch.
                    //
                    // Was die Uhr nicht kann, steht nicht drin — nicht
                    // gesperrt, sondern nicht vorhanden. Dieselbe Begruendung
                    // wie in SendenView.swift: Ein Eintrag, der angenommen und
                    // dann als linksbuendig gesendet wuerde, zeigte etwas
                    // anderes an, als auf der Uhr steht.
                    Menu {
                        Picker("Waagrecht", selection: $horizontal) {
                            Label("Linksbündig", systemImage: "text.alignleft")
                                .tag(SendenHAusrichtung.links)
                            Label("Zentriert", systemImage: "text.aligncenter")
                                .tag(SendenHAusrichtung.mittig)
                            if gattung.waagrechteAusrichtungen.contains(.rechts) {
                                Label("Rechtsbündig", systemImage: "text.alignright")
                                    .tag(SendenHAusrichtung.rechts)
                            }
                        }
                    } label: {
                        Image(systemName: horizontalSymbol)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    // Gesperrt, wenn der Text ohnehin laeuft — dieselbe
                    // Rechnung wie am Schreibtisch (`waagrechtWirktNicht`):
                    // Die Laufschrift schiebt ihn von ganz aussen durchs
                    // Fenster und fragt die Ausrichtung gar nicht ab.
                    .disabled(waagrechtWirktNicht)
                    .accessibilityLabel(Text(lok("Ausrichtung")) + Text(" ") + Text(horizontalWort))
                    .accessibilityHint(Text(waagrechtWirktNicht
                        ? lok("Läuft der Text als Laufschrift, füllt er das Fenster ohnehin von einem Rand zum anderen — die Ausrichtung bliebe ohne Wirkung.")
                        : lok("Waagrecht")))
                    Menu {
                        Picker("Senkrecht", selection: $vertikal) {
                            Label("Oben", systemImage: "align.vertical.top")
                                .tag(SendenVAusrichtung.oben)
                            Label("Mittig", systemImage: "align.vertical.center")
                                .tag(SendenVAusrichtung.mittig)
                            Label("Unten", systemImage: "align.vertical.bottom")
                                .tag(SendenVAusrichtung.unten)
                        }
                    } label: {
                        Image(systemName: vertikalSymbol)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(!gattung.wirkt(.senkrecht))
                    .accessibilityLabel(Text(lok("Ausrichtung")) + Text(" ") + Text(vertikalWort))
                    .accessibilityHint(Text(gattung.begruendung(.senkrecht) ?? lok("Senkrecht ausrichten")))
                    // Dasselbe Gesicht wie am Schreibtisch (`Farbkreis`) —
                    // unter iPadOS und hier zeigt das Systemfeld nicht einmal
                    // den Regenbogenkreis, den der Mac danebenstellt.
                    // Die Trefferflaeche bleibt bei 44 Punkten, der Kreis
                    // darin ist kleiner.
                    Farbkreis(farbe: farbe, kante: 26)
                        .frame(width: 44, height: 44)
                    Button { zeigeFormat = true } label: {
                        Image(systemName: "paintbrush")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.automatic)
                    .accessibilityLabel("Format")
                    // Hier und nicht am Ende der Pille: Die fuenf davor
                    // (Icon, waagrecht, senkrecht, Farbe, Pinsel) muessen
                    // ohne Schieben sichtbar bleiben; ein sechstes Zeichen
                    // von 44 Punkten passt daneben noch in die Breite —
                    // hinausgeschoben wird dadurch der Schriftname, nicht ein
                    // Knopf. Am Ende, hinter Rand und Abstand, faende es
                    // niemand.
                    Button { zeigeBilder = true } label: {
                        Image(systemName: "photo")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.automatic)
                    .accessibilityLabel("Bild senden")
                    Menu {
                        Picker("Schriftart", selection: $schrift) {
                            ForEach(Self.schriften, id: \.self) { Text($0).tag($0) }
                        }
                    } label: {
                        Text(schrift)
                    }
                    .frame(minWidth: 44, minHeight: 44)
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
                    // `Toggle` im Knopfstil statt eines `Button`, der seinen
                    // Zustand selbst faerbt: Der getoente Hintergrund im
                    // Zustand „an" und das Merkmal `.isSelected` fuer die
                    // Sprachausgabe kommen damit vom System.
                    //
                    // Wie am Mac (`fettWirkt`): Auch Schriften und Groessen
                    // ohne fetten Schnitt sperren den Knopf, sonst waere er
                    // bedienbar, ohne etwas zu bewirken.
                    Toggle(isOn: $fett) {
                        Image(systemName: "bold").frame(width: 44, height: 44)
                    }
                    .toggleStyle(.button)
                    .disabled(!fettWirkt)
                    .disabled(!gattung.wirkt(.fett))
                    .accessibilityLabel("Fett")
                    .accessibilityHint(Text(fettHinweis))
                    Toggle(isOn: $grossbuchstaben) {
                        Image(systemName: "capslock").frame(width: 44, height: 44)
                    }
                    .toggleStyle(.button)
                    .disabled(!kleinbuchstabenMoeglich)
                    .accessibilityLabel("Großbuchstaben")
                    .accessibilityHint(Text(grossHinweis))
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

    /// Kein Sendeknopf — wie in Nachrichten. Die Eingabetaste schickt.
    /// `axis: .vertical` fuegt bei Return sonst einen Zeilenumbruch ein, statt
    /// abzuschicken; das `.onChange` unten faengt genau dieses eine Zeichen ab,
    /// bevor es im Feld erscheint, und sendet an seiner Stelle. Ein echter
    /// Zeilenumbruch laesst sich damit nicht mehr eintippen — gewollt, die Uhr
    /// zeigt ohnehin nur eine Zeile.
    ///
    /// Daneben steht die Zielwahl — dasselbe Ziel wie im Titelmenü
    /// (`angesehene`, `zustand.anMehrereUhren`), nur an einer Stelle, die man
    /// nicht erst am Titel suchen muss. Bei nur einer eingerichteten Uhr gibt
    /// es nichts zu wählen, wie beim Titelmenü, und dort steht dann nichts.
    /// An wen die naechste Meldung geht. Die Zahl steht immer da, auch die 1:
    /// „an eine" und „noch nichts gewaehlt" saehen sonst gleich aus.
    @ViewBuilder
    private var empfaengermenue: some View {
        if zustand.uhren.count > 1 {
            Menu {
                Section("Senden an") {
                    ForEach(zustand.uhren) { uhr in
                        Button {
                            zustand.zielUmschalten(uhr.id)
                        } label: {
                            Label(uhr.name, systemImage: zustand.zielIDs.contains(uhr.id)
                                  ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    Button("Alle") { zustand.zielIDs = Set(zustand.uhren.map(\.id)) }
                    Button("Nur die angesehene") {
                        if let aktiveID = zustand.aktiveID { zustand.zielIDs = [aktiveID] }
                    }
                }
            } label: {
                Label(lokf("Empfänger · %d", zustand.ziele().count),
                      systemImage: "antenna.radiowaves.left.and.right")
            }
            .accessibilityLabel(Text("Ziel wählen"))
        }
    }

    private var eingabe: some View {
        HStack(spacing: 8) {
            TextField("Text", text: $text, axis: .vertical)
                .lineLimit(1...3)
                // Dieselbe Fassung wie am Schreibtisch, samt (x): Was die
                // eine Oberflaeche kann, soll die andere auch koennen — ein
                // Feld ohne Loeschzeichen, weil es Nachrichten nachgebaut
                // ist, waere kein Grund, es hier vorzuenthalten.
                .eingabefeld(loeschbar: $text)
                .submitLabel(.send)
                .disabled(laeuft)
                .onChange(of: text) { _, neu in
                    guard neu.hasSuffix("\n") else { return }
                    text = String(neu.dropLast())
                    guard !laeuft, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task { await senden() }
                }
            if laeuft {
                ProgressView()
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(Text("Sende…"))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhängt — damit die (nicht
    /// ganz billige) Berechnung nur bei einer tatsächlichen Änderung neu läuft.
    private var laufschriftSchluessel: String {
        "\(passt)|\(optionen.gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(rand)|\(iconNummer)|\(iconLaeuftMit)|\(luecke)|\(gattung)|\(mass.breite)×\(mass.hoehe)"
    }

    /// Mehrere hundert Einzelbilder rastern, als GIF kodieren, Base64 darüber —
    /// bei jedem Tastendruck. Das gehört nicht auf den Hauptthread, sonst
    /// stockt das Eingabefeld.
    private func laufschriftRechnen() async {
        guard !passt else {
            laufschriftFrames = []; laufschriftURI = ""; return
        }
        let (o, mass) = (vorschauOptionen, mass)
        let iconBilder = gewaehltesIcon.flatMap { i -> [[String?]]? in
            try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
        } ?? []
        let (frames, uri) = await Task.detached(priority: .userInitiated) {
            let frames = Meldungsbau.laufschriftBilder(o, iconBilder: iconBilder, mass: mass)
            let uri = (try? Bildraster.alsDatenURI(
                frames.map(\.pixel), breite: mass.breite,
                hoehe: mass.hoehe, verzoegerung: o.tempo.bilddauer)) ?? ""
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
            // Das vorberechnete GIF nur, wenn es die Größe hat, in der
            // gesendet wird: Die Vorschau rastert auf dem Maß der angesehenen
            // Uhr; „An alle Uhren senden" schickt aber an jede eingerichtete,
            // und eine TC002 bekäme das 32×8-GIF einer NG als Nutzlast.
            // `Meldungsbau.rahmen` rastert dann eben selbst.
            let rahmen = try Meldungsbau.rahmen(optionen, icon: gewaehltesIcon, sammlung: sammlung,
                                                vorberechnet: mass == .tc002 ? laufschriftURI : nil)
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
        // Nur an belegten Plaetzen: Ein leerer Platz hat nichts zu
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
    /// Eine Zeile, die nicht wie ein Listeneintrag aussehen soll: ohne
    /// Trennlinie, ohne Zeilenhintergrund, mit eigenem seitlichem Rand.
    ///
    /// Vorschau und Slotleiste sind Zeilen der Liste, damit der Bildschirm als
    /// Ganzes rollt (siehe `mitte`) — aussehen sollen sie deswegen nicht
    /// danach. Die Vorschau bekommt `rand: 0`, damit sie wie bisher bis an die
    /// Kante reicht.
    func listenzeileOhneRahmen(rand: CGFloat) -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: rand, bottom: 8, trailing: rand))
    }

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
