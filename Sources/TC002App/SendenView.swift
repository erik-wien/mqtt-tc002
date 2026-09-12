import AppKit
import SwiftUI
import TC002Core
import TC002Modell

struct SendenView: View {
    @Bindable var zustand: AppZustand

    /// Ueberlebt den Neustart — Einstellungen dieser einen Ansicht, kein
    /// geteilter Zustand, deshalb @AppStorage statt des Umwegs ueber AppZustand.
    @AppStorage("senden.meldungsplatz") private var platz = 1
    @AppStorage("senden.dauer") private var dauerText = ""
    @AppStorage("senden.text") private var text = "Hallo"
    /// Als "#RRGGBB": @AppStorage kennt keine Color. `farbe` unten wandelt fuer
    /// den ColorPicker um, `Textraster.rastern` nimmt den Hex-Wert ohnehin direkt.
    @AppStorage("senden.farbe") private var farbeHex = "#00FF66"
    @AppStorage("senden.schriftart") private var schrift = "Silkscreen"
    /// 8, nicht 11: Vorgabeschrift ist Silkscreen, die nur 8 und 16 sauber traegt.
    @AppStorage("senden.groesse") private var groesse = 8.0
    @AppStorage("senden.fett") private var fett = false
    /// Zahl leerer Spalten zwischen zwei Zeichen, 0 bis 3, Vorgabe 1. Wirkt nur
    /// beim Weg „als Pixel": Dort wird jedes Zeichen einzeln gerastert und nach
    /// seiner Tinte an das vorige angehaengt (siehe `Textraster.rasterPuffer`),
    /// nicht nach der Vorschubbreite der Schrift — die ist fuer gedruckte
    /// Groessen gemacht und faellt auf sechzehn Pixeln mal zu eng, mal zu weit
    /// aus. Beim Weg „als Text" setzt die Uhr selbst, mit ihrem eigenen,
    /// unveraenderten `Textblock.zeichenabstand` (siehe `textblock` unten).
    @AppStorage("senden.luecke") private var luecke = 1
    /// Wandelt erst beim Rastern bzw. beim Bauen des `Textblock` um (siehe
    /// `gesendeterText`), nie das Eingabefeld selbst — wer tippt, soll lesen,
    /// was er geschrieben hat.
    @AppStorage("senden.grossbuchstaben") private var grossbuchstaben = false
    @AppStorage("senden.horizontal") private var horizontal: SendenHAusrichtung = .links
    @AppStorage("senden.vertikal") private var vertikal: SendenVAusrichtung = .oben
    /// Zeilen, die bei „oben" und „unten" frei bleiben. Buendig (0) sieht je nach
    /// Schrift verschieden aus: Manche bringen ueber der Grossbuchstabenhoehe
    /// Platz mit, andere nicht. Ein eigener Rand macht den Eindruck unabhaengig
    /// vom Bau der Schrift. Bei „mittig" wirkt er naturgemaess nicht.
    @AppStorage("senden.rand") private var rand: Int = 1
    @AppStorage("senden.weg") private var weg: SendeWeg = .pixel
    /// Nur wirksam, wenn der Text laeuft.
    @AppStorage("senden.tempo") private var tempo: Lauftempo = .mittel
    @AppStorage("senden.iconmitlaufend") private var iconLaeuftMit = false
    /// Nur die Nummer wird gesichert, kein Pfad — der bricht, sobald ein Icon
    /// zwischen mitgeliefert und eigenen wandert. `gewaehltesIcon` wird daraus
    /// einmalig beim Start nachgeschlagen; eine verschwundene Nummer ergibt
    /// kommentarlos „kein Icon“.
    @AppStorage("senden.icon") private var iconNummer = ""
    @State private var gewaehltesIcon: Icon?
    @State private var laeuft = false
    /// Die Einzelbilder der Laufschrift — einmal je Aenderung an Text oder
    /// Formatierung berechnet (`.task(id:)`), nicht bei jedem Neuzeichnen der
    /// mit `TimelineView` laufenden Vorschau. Fuellt zugleich die Groessenanzeige.
    @State private var laufschriftFrames: [Bildraster.Einzelbild] = []
    /// Das fertig kodierte GIF zu diesen Einzelbildern — einmal gebaut, zweimal
    /// gebraucht: fuer die Groessenangabe unter der Vorschau und fuers Senden.
    @State private var laufschriftURI = ""
    /// Steuert den Inspektor (`.inspector`), der alle Formatierungsregler
    /// traegt. Offen als Vorgabe: Schrift, Groesse, Ausrichtung und Farbe sind
    /// keine Kuer, sondern werden staendig gebraucht — versteckt haetten sie
    /// beim ersten Start ausgesehen, als waeren sie weg.
    @State private var zeigeInspektor = true

    init(zustand: AppZustand) {
        self.zustand = zustand
        let nummer = UserDefaults.standard.string(forKey: "senden.icon") ?? ""
        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene)
        _gewaehltesIcon = State(initialValue: nummer.isEmpty ? nil : sammlung.alle().first { $0.nummer == nummer })
    }

    /// Fuer den ColorPicker: liest/schreibt `farbeHex` als `Color`.
    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt — bei
    /// mehreren Zieluhren zaehlt jede davon. Dieselbe Grundlage wie die Liste
    /// unter „Verlauf": was die Uhr meldet, sonst was die App sich gemerkt hat.
    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele().flatMap { zustand.anzeigenAufUhr($0.id) })
        return Set((1...Meldungsplatz.anzahl).filter { namen.contains(Meldungsplatz.name(fuer: $0)) })
    }

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann in der
    /// Nutzlast wie bisher.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Geprueft bei 16 Pixeln Hoehe: Diese Schriften rastern mit gleichmaessigen
    /// Strichstaerken. Silkscreen ist die Vorgabe — sie ist eigens aufs
    /// 8-Pixel-Raster gezeichnet (mitgeliefert, siehe unten) und kann, anders
    /// als die Geraetschrift, Umlaute und das scharfe S. Micro 5 und Tiny5 sind
    /// ebenfalls mitgelieferte Pixelschriften mit vollem Zeichenumfang (siehe
    /// `sauberePixelgroessen` unten). Der registrierte Familienname von Micro5
    /// traegt ein Leerzeichen ("Micro 5") — im Font-Editor gepruefte Tatsache,
    /// nicht Tippfehler. Alle anderen installierten Schriften sind bei dieser
    /// Groesse unbrauchbar — Courier, SF Mono und Helvetica etwa bekommen
    /// Loecher in den Staemmen.
    static let geeigneteSchriften = ["Micro 5", "Silkscreen", "Tiny5", "Geneva", "Monaco", "Andale Mono", "Menlo", "PT Mono"]

    /// Einmal ermittelt statt bei jedem Neuaufbau — NSFontManager befragt das System.
    /// Gefiltert auf das, was dieser Mac tatsaechlich installiert hat; nicht jede
    /// dieser sechs Schriften bringt jedes macOS mit. Bleibt danach nichts uebrig
    /// (kaum vorstellbar, aber moeglich), faellt es auf die Systemschrift zurueck,
    /// statt eine leere Auswahl zu zeigen.
    private static let schriftarten: [String] = {
        // NSFontManager.availableFontFamilies listet Schriften, die nur fuer
        // diesen Prozess angemeldet sind, NICHT auf — die mitgelieferten fielen
        // dadurch immer heraus, obwohl CoreText sie kennt. Deshalb CoreText
        // direkt fragen: Kommt derselbe Familienname zurueck, ist die Schrift
        // da; sonst liefert es klaglos eine Ersatzschrift.
        let gefiltert = geeigneteSchriften.filter { name in
            let f = CTFontCreateWithName(name as CFString, 12, nil)
            return (CTFontCopyFamilyName(f) as String) == name
        }
        return gefiltert.isEmpty
            ? [NSFont.systemFont(ofSize: NSFont.systemFontSize).familyName ?? "Helvetica"]
            : gefiltert
    }()

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene)
    }

    /// Die Optionen dieser Ansicht als Wertetyp — die einzige Stelle, an der
    /// aus Ansichtszustand ein Auftrag wird.
    private var optionen: Meldungsoptionen {
        Meldungsoptionen(text: text, weg: weg, schrift: schrift, groesse: groesse,
                         fett: fett, farbe: farbeHex, grossbuchstaben: grossbuchstaben,
                         waagrecht: horizontal, senkrecht: vertikal, rand: rand,
                         abstand: luecke, tempo: tempo, iconLaeuftMit: iconLaeuftMit,
                         dauer: dauer)
    }

    private var mitIcon: Bool { gewaehltesIcon != nil }
    private var passt: Bool { Meldungsbau.passt(optionen, mitIcon: mitIcon) }
    private var feld: Pixelfeld { Meldungsbau.feld(optionen, mitIcon: mitIcon) }

    private func gebauterRahmen() throws -> Frame {
        try Meldungsbau.rahmen(optionen, icon: gewaehltesIcon, sammlung: sammlung,
                               vorberechnet: laufschriftURI)
    }

    /// Der Text, wie er tatsächlich gerastert bzw. an die Uhr geschickt wird —
    /// die einzige Stelle, an der „Großbuchstaben" wirkt. Das Eingabefeld
    /// bleibt unangetastet, an ihm hängt nur `text`. Nebeneffekt von
    /// `uppercased()`: aus „ß" wird „SS". Beim Weg „als Text" hilft das nur,
    /// wenn die Gerätschrift Versalien kennt — belegt sind bisher allein
    /// Kleinbuchstaben und Ziffern (Gerätereferenz, §1); „Ä", „Ö", „Ü" bleiben
    /// Umlaute und fehlen dort in jedem Fall.
    private var gesendeterText: String { optionen.gesendeterText }

    /// Silkscreen ist streng aufs 8-Pixel-Raster gezeichnet: Bei 8 und 16 sitzen
    /// die Striche auf ganzen Pixeln, dazwischen entscheidet ohne Kantenglaettung
    /// ein Schwellwert willkuerlich — am Bildschirm geprueft und vom Nutzer als
    /// „hässlich" bestaetigt.
    ///
    /// Fuer Micro 5 und Tiny5 galt diese Einschraenkung hier eine Zeit lang
    /// ebenfalls. Das war eine unbelegte Verallgemeinerung: Geprueft war nur
    /// Silkscreen. Micro 5 traegt in Groesse 12 nur acht Zeilen Tinte und wirkte
    /// dadurch verloren auf einem sechzehn Zeilen hohen Display; erst bei 16
    /// fuellt sie es. Beide stehen deshalb wieder im vollen Bereich.
    static let sauberePixelgroessen: [String: [Double]] = ["Silkscreen": [8, 16]]

    /// Die sauberen Groessen der aktuell gewaehlten Schrift, oder nil, wenn sie
    /// keine Pixelschrift mit eigenem Raster ist.
    private var zulaessigeGroessen: [Double]? { Self.sauberePixelgroessen[schrift] }

    private var textHoehe: Int { Textraster.hoehe(gesendeterText, schrift: schrift, groesse: groesse, fett: fett) }

    /// Wohin der gerasterte Text senkrecht geschoben wird.
    ///
    /// `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie der Schrift sie
    /// hinlegt — nicht an den oberen Rand. Frueher wurde dieses Feld einfach
    /// zusaetzlich nach unten geschoben; „oben" hiess damit „lass es, wo es ist",
    /// und „unten" schob die Tinte unten hinaus. Deshalb wird hier erst gemessen,
    /// wo sie liegt, und dann die Verschiebung dorthin gerechnet, wo sie hinsoll.
    /// Ob der fette Schnitt bei dieser Schrift und Groesse ueberhaupt etwas
    /// aendert — gemessen, nicht geraten. Sechs der acht angebotenen Schriften
    /// haben keinen, und ein Knopf ohne Wirkung ist schlimmer als keiner.
    private var fettWirkt: Bool {
        weg != .text && Textraster.kannFett(schrift: schrift, groesse: groesse)
    }

    /// Ob die Schrift eigene Kleinbuchstaben kennt. Silkscreen etwa setzt alles
    /// in Versalien — dort bliebe der Grossbuchstaben-Schalter wirkungslos.
    private var kleinbuchstabenMoeglich: Bool {
        weg == .text || Textraster.kannKleinbuchstaben(schrift: schrift, groesse: groesse)
    }

    private var fettHilfe: String {
        if weg == .text { return lok("Die Uhr kennt keinen fetten Schnitt — das gilt hier nicht.") }
        return fettWirkt ? lok("Fett")
            : lokf("„%@“ hat bei dieser Größe keinen fetten Schnitt — der Knopf bliebe ohne Wirkung.", schrift)
    }

    private var grossHilfe: String {
        kleinbuchstabenMoeglich
            ? lok("Großbuchstaben — wirkt auf beiden Wegen, das Eingabefeld selbst bleibt unverändert.")
            : lokf("„%@“ kennt nur Großbuchstaben — der Schalter bliebe ohne Wirkung.", schrift)
    }

    /// Die Einzelbilder des gewaehlten Icons, fuer die Laufschrift, die sie
    /// einbaeckt. Leer ohne Icon oder bei unlesbarer Datei — das Senden meldet
    /// den Fehler dann noch einmal richtig.
    private var iconRaster: [[String?]] {
        guard let datei = gewaehltesIcon?.datei else { return [] }
        return ((try? Bildraster.lesenMitZeiten(datei, breite: 8, hoehe: 8)) ?? []).map(\.pixel)
    }

    private var nutzlastBytes: Int { laufschriftURI.utf8.count }

    /// Die Zahl, an der man merkt, ob man der ungeklaerten Grenze der Uhr
    /// nahekommt — die Zeichenzahl des Textes sieht man selbst, sie half nicht.
    private var nutzlastText: String {
        nutzlastBytes < 1024 ? "unter 1 KB Nutzlast" : "rund \(nutzlastBytes / 1024) KB Nutzlast"
    }

    /// Zeichen, die die eingebaute Gerätschrift nicht kennt: keine Umlaute, von
    /// den Satzzeichen nur `%`, `.`, `-`, `:` (Gerätereferenz, §1). Nur fürs
    /// Vorwarnen beim Weg „als Text" gedacht — die Uhr meldet ein fehlendes
    /// Zeichen sonst nicht, sie zeigt an der Stelle einfach nichts. Geprüft
    /// wird `gesendeterText`, nicht `text`: Nach „Großbuchstaben" ist aus
    /// einem „ß" längst ein darstellbares „SS" geworden, das soll die Warnung
    /// nicht mehr treffen. Jedes betroffene Zeichen nur einmal, in der
    /// Reihenfolge des ersten Auftretens.
    private var unbekannteZeichen: [Character] {
        let erlaubteSatzzeichen = Set("%.-:")
        var gefunden: [Character] = []
        for zeichen in gesendeterText where !gefunden.contains(zeichen) {
            if zeichen.isASCII && (zeichen.isLetter || zeichen.isNumber) { continue }
            if zeichen == " " { continue }
            if erlaubteSatzzeichen.contains(zeichen) { continue }
            gefunden.append(zeichen)
        }
        return gefunden
    }

    private var unbekannteZeichenText: String {
        unbekannteZeichen.map { "„\($0)“" }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Wie ein Nachrichtenfenster: Vorschau oben und sichtbar bleibend
            // (waechst mit dem Fenster, siehe .frame(...) unten), Eingabe und
            // Sendeknopf ganz unten — dieselbe Reihenfolge wie am iPhone
            // (SendeniOS.swift), nur ohne dessen ScrollView: hier passt alles
            // ohne Scrollen ins Fenster.
            VStack(alignment: .leading, spacing: 4) {
                // Die Uhrenauswahl sitzt hier oben, nicht neben der Vorschau:
                // am iPhone steht ihr Gegenstueck (ein Aufklappmenue) im
                // Titel, also ueber dem Vorschaubereich, nicht daneben — das
                // uebernimmt dieselbe Stelle, ohne die Bauart des Knopfs
                // (samt seinem Blatt) anzutasten. Ohne zweite Uhr zeigt
                // ZielauswahlView nichts, die Zeile bleibt dann leer.
                HStack {
                    Spacer()
                    ZielauswahlView(zustand: zustand)
                }
                // Die Vorschau zeigt beim Pixel-Weg, was ankommt: stehend, wenn es
                // passt, laufend, wenn nicht — bei der Laufschrift steckt das Icon
                // schon in den Einzelbildern, deshalb dort kein zweites. Beim Weg
                // „als Text" ist es immer unsere eigene Rasterung als Näherung, nie
                // laufend: das Laufen besorgt dort die Uhr, wir kennen ihre Schrift
                // nicht und können es nicht zeigen.
                //
                // Die Kantenlaenge richtet sich nach dem Platz, nicht nach einer
                // festen Zahl: Der Geraeterahmen ist 680/584 mal so breit und
                // 356/177 mal so hoch wie das Pixelfeld darin. Was in Breite und
                // Hoehe passt, bestimmt die Groesse; die Uhr steht mittig.
                GeometryReader { geo in
                    let breitenFaktor = 680.0 / 584.0
                    let hoehenFaktor = 356.0 / 177.0
                    let nachBreite = (geo.size.width - 24) / (Double(feld.breite) * breitenFaktor)
                    let nachHoehe = (geo.size.height - 24) / (Double(feld.hoehe) * hoehenFaktor)
                    let kante = max(4, min(14, (min(nachBreite, nachHoehe)).rounded(.down)))
                    VorschauView(feld: feld, kantenlaenge: kante,
                                icon: (weg == .text || passt) ? gewaehltesIcon?.datei : nil,
                                laufschriftBilder: (weg == .pixel && !passt) ? laufschriftFrames : nil)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                }
                switch weg {
                case .pixel:
                    if !passt {
                        // Zu langer Text ist kein Fehler, sondern der Grund fuers Laufen.
                        // Zeigen, worauf man sich einlaesst: niemand weiss, wo die Uhr bei
                        // der Nutzlastgroesse aussteigt (§4.2a).
                        // Nur der Stand, keine Erklaerung — die steht in der Hilfe
                        // („Senden", Absatz zur Nutzlastgroesse).
                        Text(lokf("Laufschrift · %d Bilder · %@", laufschriftFrames.count, nutzlastText))
                            .font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        if nutzlastBytes > 60_000 {
                            Label("Eine auffällig große Nutzlast — nur ein kürzerer Text macht sie kleiner, das Tempo ändert daran nichts.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    }
                case .text:
                    // Zu langer Text ist hier kein Fehler und keine eigene Warnung
                    // wert — die Uhr laesst ihn von selbst laufen (§4.3, §5.4). Statt
                    // der Breitenwarnung steht hier, dass unsere Vorschau nur eine
                    // Naeherung ist: die Uhr rastert selbst, mit ihrer eigenen Schrift.
                    Label("Nur eine Näherung — die Uhr setzt diesen Text selbst und zeigt ihn anders. Läuft er, weil er nicht passt, bestimmt „Scrolltempo“ unter „Einstellungen“ das Tempo.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !unbekannteZeichen.isEmpty {
                        Label(lokf("Diese Zeichen kennt die Gerätschrift nicht und lässt sie einfach weg: %@. „als Pixel“ kann sie.", unbekannteZeichenText),
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(alignment: .center, spacing: 20) {
                // Der Papierkorb gehoert zum Slot, den er leert — direkt daneben.
                HStack(spacing: 6) {
                    MeldungsplatzWahl(platz: $platz, belegtePlaetze: belegtePlaetze)
                        .help("Blättert nur zwischen belegten Plätzen, wenn der Seitenwechsel unter „Einstellungen“ nicht auf „kein Wechsel“ steht.")
                    MeldungLoeschenKnopf(zustand: zustand, platz: platz,
                                         belegt: belegtePlaetze.contains(platz))
                }
                // Beschriftung links, Wert rechts, Einheit dahinter — nicht eine
                // Ueberschrift ueber dem Feld.
                LabeledContent("Dauer") {
                    HStack(spacing: 4) {
                        TextField("Uhr entscheidet", text: $dauerText).frame(width: 90)
                        Text("s").foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Breit: Feld und Knopf in einer Zeile. Schmal: der Knopf rueckt
            // unter das Feld, rechts — damit die Mitte weiter nachgeben kann,
            // bevor irgendetwas abgeschnitten wird.
            ViewThatFits(in: .horizontal) {
                HStack {
                    TextField("Text", text: $text)
                    sendeKnopf
                }
                VStack(alignment: .trailing, spacing: 8) {
                    TextField("Text", text: $text)
                    sendeKnopf
                }
            }
            if zustand.ziele().isEmpty {
                Text("Erst unter „Einstellungen“ eine Uhr eintragen und abfragen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        // Die Mitte braucht mindestens so viel wie die Slot-Zeile (Slot,
        // Papierkorb, Dauer); das Eingabefeld gibt weiter nach, weil der
        // Sendeknopf bei Enge darunterrueckt. Mit Seitenleiste 170 und
        // Inspektor 340 bleiben bei 980 Fensterbreite 470 — reicht.
        .frame(minWidth: 420)
        // Alle Formatierungsregler sitzen im Inspektor rechts (siehe
        // `inspektor` unten) — auf macOS/iPadOS eine Seitenleiste, auf dem
        // iPhone (liefe diese Ansicht dort) ein Blatt von unten, ganz von
        // selbst durch `.inspector`. Der Knopf in der Werkzeugleiste blendet
        // ihn ein und aus.
        .toolbar {
            ToolbarItem {
                Button {
                    zeigeInspektor.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("Formatierung ein- oder ausblenden")
            }
        }
        .inspector(isPresented: $zeigeInspektor) { inspektor }
        .onChange(of: gewaehltesIcon) { _, neu in iconNummer = neu?.nummer ?? "" }
        .onAppear {
            // Nach einem Besuch im Icon-Editor kann das gewaehlte Icon geaendert,
            // umbenannt oder geloescht sein. Deshalb hier neu nachschlagen statt
            // dem gemerkten Wert zu glauben — ist es weg, faellt die Wahl auf
            // „ohne", statt auf eine Datei zu zeigen, die es nicht mehr gibt.
            guard !iconNummer.isEmpty else { return }
            gewaehltesIcon = sammlung.alle().first { $0.nummer == iconNummer }
        }
        .onChange(of: schrift) { _, neu in
            // Wechsel weg von einer Pixelschrift laesst die Groesse stehen —
            // sie passt ja weiterhin in den allgemeinen Bereich 6...16.
            if let zulaessig = Self.sauberePixelgroessen[neu], !zulaessig.contains(groesse) {
                groesse = zulaessig.min() ?? groesse
            }
        }
        .task(id: laufschriftSchluessel) {
            guard weg == .pixel, !passt else { laufschriftFrames = []; laufschriftURI = ""; return }
            // Mehrere hundert Einzelbilder rastern, als GIF kodieren, Base64
            // darueber — bei jedem Tastendruck. Das gehoert nicht auf den
            // Hauptthread, sonst stockt das Eingabefeld. Die Eingaben werden
            // vorher eingesammelt, damit der Rechenlauf keine View-Zustaende
            // anfasst; ein inzwischen ueberholter Lauf wirft sein Ergebnis weg.
            let (o, iconBilder) = (optionen, iconRaster)
            let (frames, uri) = await Task.detached(priority: .userInitiated) {
                let frames = Meldungsbau.laufschriftBilder(o, iconBilder: iconBilder)
                // Aus denselben Einzelbildern, die die Vorschau zeigt — nicht noch
                // einmal gerastert, sonst liefe die Rechnung zweimal.
                let uri = (try? Bildraster.alsDatenURI(
                    frames.map(\.pixel), breite: Pixelfeld.breiteStandard,
                    hoehe: Pixelfeld.hoeheStandard, verzoegerung: o.tempo.bilddauer)) ?? ""
                return (frames, uri)
            }.value
            guard !Task.isCancelled else { return }
            laufschriftFrames = frames
            laufschriftURI = uri
        }
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhaengt — als `.task(id:)`-
    /// Schluessel, damit die (nicht ganz billige) Berechnung nur bei einer
    /// tatsaechlichen Aenderung neu laeuft, nicht bei jedem Bild der laufenden
    /// Vorschau.
    private var laufschriftSchluessel: String {
        "\(weg)|\(passt)|\(gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(rand)|\(iconNummer)|\(iconLaeuftMit)|\(luecke)"
    }

    /// Der Inspektor rechts (`.inspector`, siehe `body`): alles Formatierende,
    /// das frueher zwischen Vorschau und Eingabefeld stand. `.inspector` macht
    /// daraus je nach Geraet von selbst das Richtige — eine Seitenleiste am
    /// Mac und am (kuenftigen) iPad, ein Blatt von unten am iPhone, liefe diese
    /// Ansicht dort. Deshalb hier keine feste Fensterbreite voraussetzen.
    ///
    /// `Form` mit `.formStyle(.grouped)` statt handgestapelter `VStack`s: Genau
    /// diese Form benutzt macOS selbst fuer Seitenleisten wie in Pages — sie
    /// bringt Ausrichtung (Beschriftung links, Bedienelement rechts, an
    /// derselben Kante), Zeilenabstand und die kleinen grauen Abschnittstitel
    /// von selbst mit, ohne dass hier noch etwas dafuer getan werden muss.
    /// Scrollt bei Bedarf ebenfalls von selbst, ein eigenes `ScrollView` bräuchte
    /// es dafuer nicht mehr.
    private var inspektor: some View {
        Form {
            // Segmentschalter ueber die volle Breite, ohne Beschriftung links:
            // Der Abschnittstitel sagt schon, worum es geht. Eine Beschriftung
            // daneben quetschte den Schalter zusammen — genau das sah man.
            Section("Senden als") {
                Picker("Weg", selection: $weg) {
                    Text("als Pixel").tag(SendeWeg.pixel)
                    Text("als Text").tag(SendeWeg.text)
                }
                .pickerStyle(.segmented).labelsHidden()
                .help("„als Pixel“: die App rastert selbst — mit Umlauten, zu langer Text läuft als GIF. „als Text“: die Uhr setzt den Text selbst und lässt ihn bei Bedarf laufen, kennt dabei aber keine Umlaute.")
            }

            // Immer da, gesperrt statt versteckt: Ein Abschnitt, der je nach
            // Zustand erscheint und verschwindet, laesst die Seitenleiste
            // springen. Gesperrt mit Begruendung ist die Bauart der uebrigen
            // Regler hier.
            Section("Laufschrift") {
                Picker("Tempo", selection: $tempo) {
                    Text("langsam").tag(Lauftempo.langsam)
                    Text("mittel").tag(Lauftempo.mittel)
                    Text("schnell").tag(Lauftempo.schnell)
                }
                .pickerStyle(.segmented).labelsHidden()
                .disabled(!(weg == .pixel && !passt))
                .help(weg == .pixel && !passt ? "Wie schnell der Text durchläuft."
                                              : "Gilt nur, wenn der Text nicht ins Display passt.")
            }

            Section("Icon") {
                IconAuswahlView(gewaehltesIcon: $gewaehltesIcon, sammlung: sammlung)
                // Gehoert zum Icon, nicht zur Laufschrift — es sagt, was das Icon
                // beim Laufen tut.
                Toggle("Icon mitscrollen", isOn: $iconLaeuftMit)
                    .disabled(gewaehltesIcon == nil || !(weg == .pixel && !passt))
                    .help("Aus: das Icon steht links, der Text läuft rechts daneben durch. An: es steht am Anfang des Textes und wandert mit hinaus.")
            }

            Section("Schrift") {
                LabeledContent("Schriftart") {
                    Picker("Schriftart", selection: $schrift) {
                        ForEach(Self.schriftarten, id: \.self) { Text($0).tag($0) }
                        // Eine frueher gewaehlte, seither aus der Auswahl gefallene Schrift
                        // bleibt gesetzt und waehlbar, bis man selbst etwas anderes waehlt —
                        // abgesetzt durch den Trenner, statt sie kommentarlos zu verwerfen.
                        if !Self.schriftarten.contains(schrift) {
                            Divider()
                            Text(schrift).tag(schrift)
                        }
                    }
                    .labelsHidden()
                }
                .disabled(weg == .text)
                .help(weg == .text ? "Die Uhr hat nur eine eingebaute Schrift — das gilt hier nicht."
                                   : "Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")

                if let zulaessig = zulaessigeGroessen, let erste = zulaessig.first, let letzte = zulaessig.last {
                    let schritt = zulaessig.count > 1 ? zulaessig[1] - zulaessig[0] : 1
                    LabeledContent("Größe") {
                        Stepper(lokf("%d px", Int(groesse)), value: $groesse, in: erste...letzte, step: schritt)
                    }
                    .help(lokf("Schriftgröße — %@ ist aufs Pixelraster gezeichnet, dazwischen gibt es keine saubere Größe.", schrift))
                } else {
                    LabeledContent("Größe") {
                        Stepper(lokf("%d px", Int(groesse)), value: $groesse, in: 6...16)
                    }
                    .help("Schriftgröße")
                }

                // Beide Schalter in einer Zeile, wie B I U bei Pages — nicht je
                // eine volle Zeile fuer ein einsames Symbol rechts.
                LabeledContent("Stil") {
                    HStack(spacing: 4) {
                        Toggle(isOn: $fett) { Image(systemName: "bold") }
                            .toggleStyle(.button)
                            .disabled(!fettWirkt)
                            .help(fettHilfe)
                            .accessibilityLabel(Text("Fett"))
                        Toggle(isOn: $grossbuchstaben) { Image(systemName: "capslock") }
                            .toggleStyle(.button)
                            .disabled(!kleinbuchstabenMoeglich)
                            .help(grossHilfe)
                            .accessibilityLabel(Text("Großbuchstaben"))
                    }
                }

                // Farbe gehoert zur Schrift, wie „Textfarbe" bei Pages — kein
                // eigener Abschnitt mit einer einzigen Zeile.
                LabeledContent("Farbe") {
                    ColorPicker("Farbe", selection: farbe).labelsHidden()
                }
            }

            Section("Lage") {
                LabeledContent("Rand") {
                    Stepper(String(rand), value: $rand, in: 0...3)
                }
                .disabled(vertikal == .mittig)
                .help("Zeilen, die bei „oben“ und „unten“ frei bleiben — 0 setzt die Schrift bündig an den Rand. Bündig sieht je nach Schrift verschieden aus, weil manche über der Großbuchstabenhöhe Platz mitbringen und andere nicht; ein eigener Rand macht den Eindruck davon unabhängig. Bei „mittig“ wirkt er nicht.")

                LabeledContent("Abstand") {
                    Stepper(String(luecke), value: $luecke, in: 0...3)
                }
                .help("Leere Spalten zwischen den Zeichen, 0 bis 3 — nur beim Weg „als Pixel“: Jedes Zeichen wird einzeln gerastert und nach seiner Tinte angehängt, der Abstand ist also immer exakt so groß wie hier eingestellt, unabhängig von Schriftart, Größe und Zeichenpaar.")

                // Segmentschalter statt dreier loser Knoepfe — dieselbe Form wie
                // die Ausrichtung bei Pages.
                LabeledContent("Waagrecht") {
                    Picker("Waagrecht", selection: $horizontal) {
                        Image(systemName: "text.alignleft").tag(SendenHAusrichtung.links)
                        Image(systemName: "text.aligncenter").tag(SendenHAusrichtung.mittig)
                        Image(systemName: "text.alignright").tag(SendenHAusrichtung.rechts)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                LabeledContent("Senkrecht") {
                    Picker("Senkrecht", selection: $vertikal) {
                        Image(systemName: "align.vertical.top").tag(SendenVAusrichtung.oben)
                        Image(systemName: "align.vertical.center").tag(SendenVAusrichtung.mittig)
                        Image(systemName: "align.vertical.bottom").tag(SendenVAusrichtung.unten)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
        // Die Breite bestimmt der Inspektor ueber seine Spalte — NICHT ueber
        // ein `.frame(minWidth:)` am Inhalt. Das machte den Inhalt breiter als
        // die Spalte; er wurde mittig gesetzt und lief auf beiden Seiten hinaus,
        // links fehlten die ersten Buchstaben jeder Zeile.
        // Feste Breite aus demselben Grund wie bei der Seitenleiste links:
        // Schrumpft das Fenster, soll die Vorschau kleiner werden, nicht der
        // Inspektor. Die Zeilen darin sind auf 340 gerechnet.
        .inspectorColumnWidth(340)
    }

    private var sendeKnopf: some View {
        Button(laeuft ? "Sende…" : "Senden") { senden() }
            .keyboardShortcut(.defaultAction)
            .disabled(laeuft || zustand.ziele().isEmpty || text.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func senden() {
        laeuft = true
        let frame: Frame
        do {
            frame = try gebauterRahmen()
        } catch {
            // Ohne Meldung ginge die Anzeige bei unlesbarer Icondatei kommentarlos
            // ohne das gewaehlte Icon hinaus.
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            laeuft = false
            return
        }
        let anzeigenName = Meldungsplatz.name(fuer: platz)
        Task { await zustand.senden(frame, als: anzeigenName); laeuft = false }
    }
}
