import CoreText
import SwiftUI
import TC002Core
import TC002Modell

public struct SendenView: View {
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
    /// 8, nicht 11: Vorgabeschrift ist Silkscreen, und 8 steht auf ihrer Liste
    /// (`Pixelgroessen.abgesegnet`), 11 nicht.
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
    /// Dazu die Kantenlaenge des gewaehlten Icons — die Nummer allein trifft
    /// seit den 16×16 nicht mehr eindeutig: Beide Bestaende duerfen denselben
    /// Namen tragen. Vorgabe 8, damit eine vorhandene Einstellung ohne diesen
    /// Schluessel weiter auf dasselbe Icon zeigt wie bisher.
    @AppStorage("senden.iconkante") private var iconKanteGemerkt = 8
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

    public init(zustand: AppZustand) {
        self.zustand = zustand
        let nummer = UserDefaults.standard.string(forKey: "senden.icon") ?? ""
        let kante = UserDefaults.standard.object(forKey: "senden.iconkante") as? Int ?? 8
        _gewaehltesIcon = State(initialValue: nummer.isEmpty ? nil
            : Self.sammlungen.flatMap { $0.alle() }.first { $0.nummer == nummer && $0.kante == kante })
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

    /// Je Uhr eine Datei unter Application Support. Die gehaltene Fassung,
    /// nicht bei jedem Zugriff eine neue: `init` legt den Ordner an, und das
    /// gehoert nicht in einen Zugriff, der beim Zeichnen faellt (siehe
    /// `Slotgedaechtnis.gemeinsam`).
    private var gedaechtnis: Slotgedaechtnis { .gemeinsam }

    /// Waehlt den Platz und uebernimmt die gemerkten Regler — aber nur, wenn
    /// das belegbar ist: Pixel muessen mitgelesen worden sein (sonst gibt es
    /// nichts, wogegen zu pruefen waere), und ihre Pruefsumme muss zu den
    /// gemerkten Reglern passen (sonst hat ein fremder Absender geschrieben).
    /// In jedem anderen Fall bleiben die Regler unangeruehrt — auch dann, wenn
    /// `AppZustand.slotzustand` trotzdem Pixel zeigt (neu gerechnet aus dem
    /// Gedaechtnis): dass dieses Gedaechtnis noch stimmt, ist dort unbelegt.
    private func slotWaehlen(_ i: Int) {
        platz = i
        guard let uhr = zustand.referenzUhr,
              let bild = zustand.slotInhalt[uhr.id]?[i],
              let stand = gedaechtnis.gemerkt(fuer: uhr.id, platz: i),
              Slotgedaechtnis.pruefsumme(pixel: bild.pixel) == stand.pruefsumme
        else { return }
        reglerUebernehmen(stand)
    }

    /// Setzt alle Regler auf den gemerkten Stand — dieselben Felder, die
    /// `optionen` oben aus ihnen zusammensetzt, plus Dauer und Icon, die dort
    /// nicht mitgefuehrt werden.
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
        // `iconNummer` folgt von selbst aus `.onChange(of: gewaehltesIcon)`.
        gewaehltesIcon = stand.icon.flatMap { nummer in
            Self.sammlungen.flatMap { $0.alle() }.first { $0.nummer == nummer }
        }
    }

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann in der
    /// Nutzlast wie bisher.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Geprueft bei 16 Pixeln Hoehe: Diese Schriften rastern mit gleichmaessigen
    /// Strichstaerken. Silkscreen ist die Vorgabe — sie ist eigens aufs
    /// 8-Pixel-Raster gezeichnet (mitgeliefert) und kann, anders als die
    /// Geraetschrift, Umlaute und das scharfe S. Alle anderen installierten
    /// Schriften sind bei dieser Groesse unbrauchbar — Courier, SF Mono und
    /// Helvetica etwa bekommen Loecher in den Staemmen. Die Namen stehen in
    /// `Schriften.auswahl` im Kern, an einer Stelle fuer alle Oberflaechen und
    /// fuer die Schriftprobe.
    ///
    /// Einmal ermittelt statt bei jedem Neuaufbau — CoreText befragt das System.
    /// Gefiltert auf das, was dieser Rechner tatsaechlich installiert hat; nicht
    /// jede dieser acht Schriften bringt jedes System mit. Bleibt danach nichts
    /// uebrig (kaum vorstellbar, aber moeglich), faellt es auf die Systemschrift
    /// zurueck, statt eine leere Auswahl zu zeigen.
    private static let schriftarten: [String] = {
        let gefiltert = Schriften.auswahl.filter(Schriften.vorhanden)
        return gefiltert.isEmpty ? [systemschrift()] : gefiltert
    }()

    /// Der Familienname der Systemschrift, ueber CoreText statt ueber AppKit —
    /// dieselbe Zeile gilt damit auch auf dem iPad. `0` als Groesse heisst
    /// „Vorgabegroesse"; welche es ist, spielt fuer den Familiennamen keine
    /// Rolle. Der Rueckfall bleibt "Helvetica".
    private static func systemschrift() -> String {
        guard let f = CTFontCreateUIFontForLanguage(.system, 0, nil) else { return "Helvetica" }
        return CTFontCopyFamilyName(f) as String
    }

    /// Beide Bestaende: die kanonischen 8×8 und die eigenen 16×16. Der Erste
    /// ist zugleich der, den `Meldungsbau.rahmen` bekommt — der liest daraus
    /// nur die Daten-URI der Datei, und die haengt am Icon, nicht am Ordner.
    private static var sammlungen: [Iconsammlung] {
        [Iconsammlung(schreibordner: Iconordner.eigene),
         Iconsammlung(schreibordner: Iconordner.eigene16, kante: 16)]
    }

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
    /// Acht ohne Icon — der Wert zaehlt dann ohnehin nicht.
    private var iconKante: Int { gewaehltesIcon?.kante ?? 8 }
    private var passt: Bool { Meldungsbau.passt(optionen, mitIcon: mitIcon, iconKante: iconKante) }
    private var feld: Pixelfeld { Meldungsbau.feld(optionen, mitIcon: mitIcon, iconKante: iconKante) }

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

    /// Die Eintraege des Groessenmenues. Welche das sind, entscheidet
    /// `Pixelgroessen` im Kern — die durchgesehene Schriftprobe, nicht diese
    /// Ansicht und schon gar nicht die Messung.
    private var angeboteneGroessen: [Double] {
        Pixelgroessen.auswahl(fuer: schrift, mit: groesse)
    }

    /// Hat die gewaehlte Schrift eine durchgesehene Liste? Nur dann sagt der
    /// Einblendtext etwas ueber das Pixelraster; jede Systemschrift bekommt den
    /// vollen Bereich und keine Begruendung, die es nicht gibt.
    private var eigenesRaster: Bool { Pixelgroessen.abgesegnet[schrift] != nil }

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
        guard let icon = gewaehltesIcon else { return [] }
        return ((try? Bildraster.lesenMitZeiten(icon.datei, breite: icon.kante, hoehe: icon.kante)) ?? [])
            .map(\.pixel)
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

    public var body: some View {
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
                                iconKante: iconKante,
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

            // Breit: Bloecke und Dauer nebeneinander. Schmal: die Dauer
            // rueckt darunter. Die fuenf Bloecke geben nicht nach — sie
            // bringen ihre 44-Punkt-Trefferflaeche mit —, und mit Papierkorb
            // und Dauerfeld kommt die Zeile auf rund 420 Punkte Mindestbreite.
            // Der zweite Zweig ist damit ein Ueberlaufschutz, kein zweites
            // Aussehen: Er kommt erst, wenn der erste nicht mehr passt. Am Mac
            // ist das Fenster mindestens 1120 breit — dort kommt er nie, und
            // nichts sieht anders aus als vorher.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    slotZeile
                    dauerFeld
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
                    slotZeile
                    dauerFeld
                }
            }

            // Breit: Feld und Knopf in einer Zeile. Schmal: der Knopf rueckt
            // unter das Feld, rechts — damit die Mitte weiter nachgeben kann,
            // bevor irgendetwas abgeschnitten wird.
            ViewThatFits(in: .horizontal) {
                HStack {
                    // Ohne Mindestbreite "passt" das Feld immer, weil es sich
                    // beliebig zusammendruecken laesst — dann kaeme die zweite
                    // Variante nie zum Zug.
                    textFeld.frame(minWidth: 320)
                    sendeKnopf
                }
                VStack(alignment: .trailing, spacing: 8) {
                    textFeld
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
        //
        // Nur am Mac: Dort steht daneben ein `minWidth: 1120` am Fenster, die
        // Forderung geht also immer auf. Auf dem iPad gibt es kein Fenster zu
        // ziehen — in Slide Over sind es rund 320 Punkte, und eine Forderung
        // nach 420 schnitte die Slot-Zeile rechts ab. Dort traegt stattdessen
        // der zweite Zweig des `ViewThatFits` oben: „Dauer" rueckt unter die
        // Bloecke.
        #if os(macOS)
        .frame(minWidth: 420)
        #endif
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
        .onChange(of: gewaehltesIcon) { _, neu in
            iconNummer = neu?.nummer ?? ""
            iconKanteGemerkt = neu?.kante ?? 8
        }
        .onAppear {
            // Nach einem Besuch im Icon-Editor kann das gewaehlte Icon geaendert,
            // umbenannt oder geloescht sein. Deshalb hier neu nachschlagen statt
            // dem gemerkten Wert zu glauben — ist es weg, faellt die Wahl auf
            // „ohne", statt auf eine Datei zu zeigen, die es nicht mehr gibt.
            guard !iconNummer.isEmpty else { return }
            gewaehltesIcon = Self.sammlungen.flatMap { $0.alle() }
                .first { $0.nummer == iconNummer && $0.kante == iconKanteGemerkt }
        }
        .onChange(of: schrift) { _, neu in
            // Nach dem Wechsel gilt die Liste der neuen Schrift. Steht die
            // eingestellte Groesse nicht darauf, faellt sie auf die
            // naechstgelegene — nicht auf die kleinste: Der Sprung von 15 auf 7
            // waere eine Ueberraschung, wo 16 danebenliegt.
            groesse = Pixelgroessen.naechstgelegene(zu: groesse, fuer: neu)
        }
        .task(id: laufschriftSchluessel) {
            guard weg == .pixel, !passt else { laufschriftFrames = []; laufschriftURI = ""; return }
            // Mehrere hundert Einzelbilder rastern, als GIF kodieren, Base64
            // darueber — bei jedem Tastendruck. Das gehoert nicht auf den
            // Hauptthread, sonst stockt das Eingabefeld. Die Eingaben werden
            // vorher eingesammelt, damit der Rechenlauf keine View-Zustaende
            // anfasst; ein inzwischen ueberholter Lauf wirft sein Ergebnis weg.
            let (o, iconBilder, iconKante) = (optionen, iconRaster, iconKante)
            let (frames, uri) = await Task.detached(priority: .userInitiated) {
                let frames = Meldungsbau.laufschriftBilder(o, iconBilder: iconBilder, iconKante: iconKante)
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
        "\(weg)|\(passt)|\(gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(rand)|\(gewaehltesIcon?.kennung ?? "")|\(iconLaeuftMit)|\(luecke)"
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
                IconAuswahlView(gewaehltesIcon: $gewaehltesIcon, sammlungen: Self.sammlungen)
                // Gehoert zum Icon, nicht zur Laufschrift — es sagt, was das Icon
                // beim Laufen tut.
                Toggle("Icon mitscrollen", isOn: $iconLaeuftMit)
                    .disabled(gewaehltesIcon == nil || !(weg == .pixel && !passt))
                    .help("Aus: das Icon steht links, der Text läuft rechts daneben durch. An: es steht am Anfang des Textes und wandert mit hinaus.")
            }

            Section("Schrift") {
                // Blank, ohne `LabeledContent` und ohne `labelsHidden`: Ein
                // Waehler in einem gruppierten `Form` zeichnet die kanonische
                // Zeile selbst — Beschriftung links, Wert im grauen Kaestchen
                // mit Doppelpfeil rechts. Die Umwicklung nahm ihm genau das
                // und liess unter iPadOS blanken Text mit Doppelpfeil uebrig.
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
                .disabled(weg == .text)
                .help(weg == .text ? "Die Uhr hat nur eine eingebaute Schrift — das gilt hier nicht."
                                   : "Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")

                // Eine Liste, kein Schieber: Die durchgesehenen Groessen haben
                // Luecken — Tiny5 etwa 7, 8, 9, 12, 15, 16 —, und eine Luecke
                // laesst sich als Schrittweite nicht ausdruecken.
                Picker("Größe", selection: $groesse) {
                    ForEach(angeboteneGroessen, id: \.self) { g in
                        Text(lokf("%d px", Int(g))).tag(g)
                    }
                }
                .help(eigenesRaster
                      ? lokf("Schriftgröße — %@ ist aufs Pixelraster gezeichnet, dazwischen gibt es keine saubere Größe.", schrift)
                      : lok("Schriftgröße"))

                // Beide Schalter und der Farbwaehler in einer Zeile, wie B I U
                // samt Textfarbe bei Pages — nicht je eine volle Zeile fuer ein
                // einsames Symbol rechts. Die Farbe stand bis 13.09.2026 in
                // einer eigenen Zeile darunter; am iPad fiel auf, dass sie dort
                // eine ganze Zeile fuer einen Kringel verbraucht.
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
                        // `labelsHidden` nimmt nur die sichtbare Beschriftung;
                        // fuer VoiceOver bleibt „Farbe“ die des Waehlers. Der
                        // Einblendtext ersetzt das Wort, das die eigene Zeile
                        // vorher gezeigt hat.
                        ColorPicker("Farbe", selection: farbe)
                            .labelsHidden()
                            .help("Farbe")
                    }
                }
            }

            Section("Lage") {
                LabeledContent("Rand") {
                    Schrittwahl("Rand", wert: $rand, bereich: 0...3)
                }
                .disabled(vertikal == .mittig)
                .help("Zeilen, die bei „oben“ und „unten“ frei bleiben — 0 setzt die Schrift bündig an den Rand. Bündig sieht je nach Schrift verschieden aus, weil manche über der Großbuchstabenhöhe Platz mitbringen und andere nicht; ein eigener Rand macht den Eindruck davon unabhängig. Bei „mittig“ wirkt er nicht.")

                LabeledContent("Abstand") {
                    Schrittwahl("Abstand", wert: $luecke, bereich: 0...3)
                }
                .help("Leere Spalten zwischen den Zeichen, 0 bis 3 — nur beim Weg „als Pixel“: Jedes Zeichen wird einzeln gerastert und nach seiner Tinte angehängt, der Abstand ist also immer exakt so groß wie hier eingestellt, unabhängig von Schriftart, Größe und Zeichenpaar.")

                // Segmentschalter statt dreier loser Knoepfe — dieselbe Form wie
                // die Ausrichtung bei Pages.
                // Auch hier blank: Der Segmentschalter bleibt (die Wahl soll
                // nebeneinander stehen), aber die Beschriftung setzt die
                // `Form` selbst links daneben.
                Picker("Waagrecht", selection: $horizontal) {
                    Image(systemName: "text.alignleft").tag(SendenHAusrichtung.links)
                    Image(systemName: "text.aligncenter").tag(SendenHAusrichtung.mittig)
                    Image(systemName: "text.alignright").tag(SendenHAusrichtung.rechts)
                }
                .pickerStyle(.segmented)
                Picker("Senkrecht", selection: $vertikal) {
                    Image(systemName: "align.vertical.top").tag(SendenVAusrichtung.oben)
                    Image(systemName: "align.vertical.center").tag(SendenVAusrichtung.mittig)
                    Image(systemName: "align.vertical.bottom").tag(SendenVAusrichtung.unten)
                }
                .pickerStyle(.segmented)
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
        //
        // Auf dem iPad muss die Spalte nachgeben, sonst geht die Rechnung
        // nicht auf: Hochkant verschwindet die Seitenleiste zwar hinter einem
        // Knopf, aber auf dem kleinsten iPad bleiben 744 Punkte fuer Mitte und
        // Inspektor zusammen, und in halber geteilter Ansicht auf dem
        // 13-Zoll-Geraet rund 678. Bei kompakter Breite (Slide Over, Drittel)
        // macht `.inspector` von selbst ein Blatt daraus — dort wirkt keine
        // Spaltenbreite mehr.
        #if os(macOS)
        .inspectorColumnWidth(340)
        #else
        .inspectorColumnWidth(min: 240, ideal: 340, max: 400)
        #endif
    }

    /// Die fuenf Bloecke zeigen, was auf der Uhr liegt — Antippen waehlt den
    /// Platz und stellt, wenn belegbar, die Regler wieder her (siehe
    /// `slotWaehlen`). Der Papierkorb gehoert zum gewaehlten Platz und leert
    /// ihn — direkt daneben.
    private var slotZeile: some View {
        HStack(spacing: 6) {
            ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
                Button { slotWaehlen(i) } label: {
                    Slotblock(platz: i,
                              zustand: zustand.slotzustand(i, belegt: belegtePlaetze.contains(i)),
                              gewaehlt: platz == i)
                }
                .buttonStyle(.plain)
            }
            MeldungLoeschenKnopf(zustand: zustand, platz: platz,
                                 belegt: belegtePlaetze.contains(platz))
        }
    }

    /// Das Eingabefeld fuer die Meldung. Einmal geschrieben, weil beide Zweige
    /// des `ViewThatFits` oben dasselbe Feld zeigen — zweimal getippt liefen
    /// Schrift und Rahmen frueher oder spaeter auseinander.
    ///
    /// **Groesse:** `.title2` statt der Vorgabe — am Mac 17 statt 13 Punkt, auf
    /// dem iPad 22 statt 17. Ein benannter Schriftstil, kein fester Wert: Auf
    /// dem iPad waechst das Feld damit weiter mit der eingestellten Textgroesse
    /// mit, eine Zahl in Punkt taete das nicht. Nur dieses eine Feld; „Dauer“
    /// und der Inspektor bleiben bei der Systemgroesse.
    ///
    /// **Rahmen:** fuer beide Desktop-Oberflaechen derselbe. Bis 13.09.2026
    /// stand er hinter `#if os(macOS)` — der Mac sollte bei seiner Vorgabe
    /// bleiben, weil die einen Rahmen zeichnet. Am abgenommenen Bildschirmfoto
    /// war zu sehen, dass sie das in dieser Flaeche eben nicht tut: Das Feld
    /// stand dort so unsichtbar wie unter iPadOS. Der Zweig ist damit
    /// hinfaellig (siehe `Eingabefeld.swift`). Das iPhone setzt seinen Rahmen
    /// weiterhin in `SendeniOS` selbst.
    private var textFeld: some View {
        TextField("Text", text: $text)
            .font(.title2)
            .eingabefeld()
    }

    /// Beschriftung links, Wert rechts, Einheit dahinter — nicht eine
    /// Ueberschrift ueber dem Feld.
    private var dauerFeld: some View {
        LabeledContent("Dauer") {
            HStack(spacing: 4) {
                TextField("Uhr entscheidet", text: $dauerText)
                    .eingabefeld()
                    .frame(width: 90)
                Text("s").foregroundStyle(.secondary)
            }
        }
    }

    /// Die **eine** Haupthandlung dieser Ansicht. Gesperrt bleibt sie
    /// sichtbar abgeblendet stehen, nicht verschwunden — wie „Verbinden …"
    /// neben „Fertig" in der Vorlage.
    private var sendeKnopf: some View {
        Button(laeuft ? "Sende…" : "Senden") { senden() }
            .knopfHaupthandlung()
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
        // Momentaufnahme fuer das Slotgedaechtnis: `optionen` ist berechnet,
        // nicht gespeichert — der Task unten soll den Stand von jetzt sehen,
        // nicht den beim spaeteren Ausfuehren.
        let slotOptionen = optionen
        let slotPlatz = platz
        let slotIcon = gewaehltesIcon?.nummer
        Task {
            await zustand.senden(frame, als: anzeigenName, slotOptionen: slotOptionen,
                                 slotIcon: slotIcon, slotPlatz: slotPlatz)
            laeuft = false
        }
    }
}

/// Löscht den gewählten Meldungsplatz auf den gewählten Uhren. Er steht neben
/// der Blockreihe, weil man den Platz dort gerade in der Hand hat — unter
/// „Verlauf" geht es weiterhin auch, nur eben nicht dort, wo man arbeitet.
///
/// Symbol und Einblendtext sagen ausdrücklich, dass es die Uhr betrifft: Im
/// Malbereich gibt es oben in der Werkzeugzeile „Leeren", und das meint das
/// Bild, nicht das Gerät.
struct MeldungLoeschenKnopf: View {
    @Bindable var zustand: AppZustand
    let platz: Int
    /// Ein leerer Platz lässt sich nicht löschen. Woher das bekannt ist, steht
    /// bei `belegtePlaetze`: gemeldet schlägt gemerkt.
    let belegt: Bool

    @State private var laeuft = false

    var body: some View {
        Button(role: .destructive) {
            laeuft = true
            let name = Meldungsplatz.name(fuer: platz)
            Task { await zustand.loeschen(name); laeuft = false }
        } label: {
            Image(systemName: "trash")
        }
        .knopfZerstoerend()
        .disabled(!belegt || laeuft || zustand.ziele().isEmpty)
        .help(lokf("Slot %d auf der Uhr löschen", platz))
    }
}
