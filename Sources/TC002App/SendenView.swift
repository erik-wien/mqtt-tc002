import AppKit
import SwiftUI
import TC002Core

/// Waagrechte Ausrichtung des Textes innerhalb der verfuegbaren Breite (52 Pixel
/// ohne Icon, ab Spalte 10 mit Icon).
enum SendenHAusrichtung: String, CaseIterable, Identifiable {
    case links, mittig, rechts
    var id: String { rawValue }
}

/// Senkrechte Ausrichtung innerhalb der 16 Zeilen, gerechnet ueber die tatsaechlich
/// gesetzte Hoehe (`Textraster.hoehe`), nicht die Schriftgroesse.
enum SendenVAusrichtung: String, CaseIterable, Identifiable {
    case oben, mittig, unten
    var id: String { rawValue }
}

/// Der Weg, auf dem der Text zur Uhr kommt. `.pixel` (Vorgabe) rastert die App
/// selbst — passt der Text, steht er starr, sonst laeuft er als GIF (siehe
/// `passt`). `.text` schickt ihn stattdessen als `Textblock`, den die Uhr mit
/// ihrer eigenen Schrift setzt und selbst zum Laufen bringt, wenn er nicht
/// passt (`docs/tc002-protokoll.md` §4.3, §5.4). Deren Schrift kennt weder
/// Schriftartwahl noch Fett — deshalb sind genau diese zwei Regler dort
/// gesperrt, nicht mehr.
enum SendeWeg: String, CaseIterable, Identifiable {
    case pixel, text
    var id: String { rawValue }
}

/// Wie schnell die Laufschrift durchlaeuft. Ein Regler statt zweier Zahlen:
/// Schrittweite und Bilddauer rechnet niemand im Kopf in ein Tempo um.
enum Lauftempo: String, CaseIterable, Identifiable {
    case langsam, mittel, schnell
    var id: String { rawValue }

    /// Pixel Versatz je Einzelbild. Schnell heisst groebere Schritte — sonst
    /// waechst die Nutzlast mit dem Tempo statt zu schrumpfen.
    var schrittweite: Int { self == .schnell ? 2 : 1 }

    /// Standzeit je Einzelbild in Sekunden.
    var bilddauer: Double {
        switch self {
        case .langsam: return 0.12
        case .mittel: return 0.07
        case .schnell: return 0.05
        }
    }
}

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

    init(zustand: AppZustand) {
        self.zustand = zustand
        let nummer = UserDefaults.standard.string(forKey: "senden.icon") ?? ""
        let sammlung = Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
        _gewaehltesIcon = State(initialValue: nummer.isEmpty ? nil : sammlung.alle().first { $0.nummer == nummer })
    }

    /// Fuer den ColorPicker: liest/schreibt `farbeHex` als `Color`.
    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt — bei
    /// mehreren Zieluhren zaehlt jede davon. Dieselbe Grundlage wie die Liste
    /// unter „Anzeigen": was die Uhr meldet, sonst was die App sich gemerkt hat.
    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele().flatMap { zustand.anzeigenAufUhr($0.id) })
        return Set((1...MeldungsplatzWahl.anzahl).filter { namen.contains(MeldungsplatzWahl.name(fuer: $0)) })
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
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    /// Beginn und Breite der Flaeche, in der der Text ausgerichtet wird: ohne Icon
    /// die volle Displaybreite, mit Icon erst ab der Spalte, an der das Icon endet.
    private var flaecheX: Int { gewaehltesIcon == nil ? 0 : 10 }
    private var flaecheBreite: Int { gewaehltesIcon == nil ? Pixelfeld.breiteStandard : Pixelfeld.breiteStandard - 10 }

    /// Der Text, wie er tatsächlich gerastert bzw. an die Uhr geschickt wird —
    /// die einzige Stelle, an der „Großbuchstaben" wirkt. Das Eingabefeld
    /// bleibt unangetastet, an ihm hängt nur `text`. Nebeneffekt von
    /// `uppercased()`: aus „ß" wird „SS" — beim Weg „als Text" ein Gewinn,
    /// die Gerätschrift kennt kein „ß" (§1); „Ä", „Ö", „Ü" bleiben Umlaute und
    /// fehlen dort weiterhin.
    private var gesendeterText: String { grossbuchstaben ? text.uppercased() : text }

    /// Diese drei mitgelieferten Pixelschriften sind je aufs eigene Pixelraster
    /// gezeichnet und tragen nur ihre eigene Entwurfsgroesse bzw. ein Vielfaches
    /// davon sauber. Dazwischen entscheidet ohne Kantenglaettung ein Schwellwert
    /// willkuerlich, welche Punkte gesetzt werden — das Ergebnis war beim
    /// Nutzer „hässlich". Alle anderen Schriften bleiben im allgemeinen Bereich
    /// 6...16 waehlbar.
    static let sauberePixelgroessen: [String: [Double]] = [
        "Micro 5": [12],
        "Silkscreen": [8, 16],
        "Tiny5": [8, 16],
    ]

    /// Die sauberen Groessen der aktuell gewaehlten Schrift, oder nil, wenn sie
    /// keine Pixelschrift mit eigenem Raster ist.
    private var zulaessigeGroessen: [Double]? { Self.sauberePixelgroessen[schrift] }

    /// Deutscher Aufzaehlungstext der sauberen Groessen, etwa "8 und 16 Pixeln"
    /// oder bei nur einem Wert "12 Pixeln" — fuer den erklaerenden Satz unten.
    private func groessenText(_ werte: [Double]) -> String {
        let zahlen = werte.map { String(Int($0)) }
        guard let letzte = zahlen.last else { return "" }
        guard zahlen.count > 1 else { return "\(letzte) Pixeln" }
        return zahlen.dropLast().joined(separator: ", ") + " und \(letzte) Pixeln"
    }

    private var textBreite: Int { Textraster.breite(gesendeterText, schrift: schrift, groesse: groesse, fett: fett, luecke: luecke) }
    private var textHoehe: Int { Textraster.hoehe(gesendeterText, schrift: schrift, groesse: groesse, fett: fett) }

    private var textX: Int {
        switch horizontal {
        case .links: return flaecheX
        case .mittig: return flaecheX + max(0, (flaecheBreite - textBreite) / 2)
        case .rechts: return flaecheX + max(0, flaecheBreite - textBreite)
        }
    }

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
        if weg == .text { return "Die Uhr kennt keinen fetten Schnitt — das gilt hier nicht." }
        return fettWirkt ? "Fett"
            : "„\(schrift)“ hat bei dieser Größe keinen fetten Schnitt — der Knopf bliebe ohne Wirkung."
    }

    private var grossHilfe: String {
        kleinbuchstabenMoeglich
            ? "Großbuchstaben — wirkt auf beiden Wegen, das Eingabefeld selbst bleibt unverändert."
            : "„\(schrift)“ kennt nur Großbuchstaben — der Schalter bliebe ohne Wirkung."
    }

    private var textY: Int {
        let puffer = textPuffer
        guard let tinte = Textraster.tintenZeilen(puffer) else { return 0 }
        let hoehe = tinte.letzte - tinte.erste + 1
        switch vertikal {
        case .oben:   return -tinte.erste
        case .mittig: return (Pixelfeld.hoeheStandard - hoehe) / 2 - tinte.erste
        case .unten:  return (Pixelfeld.hoeheStandard - hoehe) - tinte.erste
        }
    }

    /// Der gerasterte Text ohne jede Ausrichtung — die Grundlage fuer `textY`
    /// und fuer das fertige Feld darunter.
    private var textPuffer: Pixelfeld {
        Textraster.rasterPuffer(gesendeterText, schrift: schrift, groesse: groesse,
                                fett: fett, farbe: farbeHex, luecke: luecke)
    }

    /// Vorschau und Sendung entstehen aus demselben Feld. Gerastert wird immer in
    /// derselben Phase, ausgerichtet wird durch Verschieben — sonst saehe dieselbe
    /// Schrift stehend anders aus als laufend.
    private var feld: Pixelfeld {
        var f = Pixelfeld()
        Textraster.einsetzen(textPuffer, x: textX, y: textY, in: &f)
        return f
    }

    /// Die eine Entscheidung, die diese Ansicht faellt: Passt der Text in die
    /// verfuegbare Breite, steht er still — sonst laeuft er als GIF durch. Kein
    /// Schalter dafuer; die App weiss es, weil sie die Breite ohnehin ausrechnet.
    ///
    /// Gerechnet wird mit der Breite des stehenden Falls (mit Icon 42 Spalten).
    /// Haenge die Rechnung an „Icon mitscrollen", wuerde das Einschalten den Text
    /// passend machen, den Schalter verschwinden lassen und ihn wieder umwerfen.
    private var passt: Bool { textBreite <= flaecheBreite }

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

    /// `align`/`valign` fuer den Weg „als Text" — dieselbe Wahl aus der
    /// Formatleiste, nur in den Namen, die das Geraet fuer `text` erwartet (§4.3).
    private var geraeteAusrichtung: String {
        switch horizontal { case .links: "left"; case .mittig: "center"; case .rechts: "right" }
    }
    private var geraeteVertikal: String {
        switch vertikal { case .oben: "top"; case .mittig: "middle"; case .unten: "bottom" }
    }

    /// Der Textblock fuer den Weg „als Text": Groesse, Ausrichtung und Farbe aus
    /// derselben Formatleiste wie beim eigenen Raster — Schriftart und Fett
    /// gelten hier nicht, die Uhr setzt ihre eigene Schrift. `zeichenabstand`
    /// bleibt bei seiner eigenen Vorgabe: „Luecke" ist die Zahl leerer Spalten
    /// zwischen Zeichen, die wir selbst rastern (siehe oben) — eine andere
    /// Einheit als `charSpacing` fuer die Gerätschrift, die beiden gleichzusetzen
    /// waere nur zufaellig richtig.
    private var textblock: Textblock {
        var t = Textblock(inhalt: gesendeterText)
        t.schrifthoehe = Int(groesse)
        t.x = flaecheX
        t.y = 0
        t.farbe = farbeHex
        t.ausrichtung = geraeteAusrichtung
        t.vertikal = geraeteVertikal
        t.flaeche = [flaecheX, 0, flaecheBreite, Pixelfeld.hoeheStandard]
        return t
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
            Picker("Weg", selection: $weg) {
                Text("als Pixel").tag(SendeWeg.pixel)
                Text("als Text").tag(SendeWeg.text)
            }
            .pickerStyle(.segmented).labelsHidden()
            .help("„als Pixel“: die App rastert selbst — mit Umlauten, zu langer Text läuft als GIF. „als Text“: die Uhr setzt den Text selbst und lässt ihn bei Bedarf laufen, kennt dabei aber keine Umlaute.")

            if weg == .pixel && !passt {
                HStack(spacing: 16) {
                    Picker("Tempo", selection: $tempo) {
                        Text("langsam").tag(Lauftempo.langsam)
                        Text("mittel").tag(Lauftempo.mittel)
                        Text("schnell").tag(Lauftempo.schnell)
                    }
                    .pickerStyle(.segmented).frame(width: 240)
                    .help("Wie schnell der Text durchläuft.")
                    if gewaehltesIcon != nil {
                        Toggle("Icon mitscrollen", isOn: $iconLaeuftMit)
                            .help("Aus: das Icon steht links, der Text läuft rechts daneben durch. An: es steht am Anfang des Textes und wandert mit hinaus.")
                    }
                    Spacer()
                }
            }

            formatleiste
            if weg == .pixel {
                Text("Nur so wenige, weil bei sechzehn Pixeln Höhe kaum eine Schrift sauber aufs Raster fällt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let zulaessig = zulaessigeGroessen {
                Text("\(schrift) ist aufs Pixelraster gezeichnet — nur bei \(groessenText(zulaessig)) fallen die Striche sauber auf ganze Pixel, dazwischen gibt es keine saubere Größe.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                TextField("Text", text: $text)
                IconAuswahlView(gewaehltesIcon: $gewaehltesIcon, sammlung: sammlung)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Die Vorschau zeigt beim Pixel-Weg, was ankommt: stehend, wenn es
                // passt, laufend, wenn nicht — bei der Laufschrift steckt das Icon
                // schon in den Einzelbildern, deshalb dort kein zweites. Beim Weg
                // „als Text" ist es immer unsere eigene Rasterung als Näherung, nie
                // laufend: das Laufen besorgt dort die Uhr, wir kennen ihre Schrift
                // nicht und können es nicht zeigen.
                VorschauView(feld: feld, kantenlaenge: 12,
                            icon: (weg == .text || passt) ? gewaehltesIcon?.datei : nil,
                            laufschriftBilder: (weg == .pixel && !passt) ? laufschriftFrames : nil)
                switch weg {
                case .pixel:
                    if !passt {
                        // Zu langer Text ist kein Fehler, sondern der Grund fuers Laufen.
                        // Zeigen, worauf man sich einlaesst: niemand weiss, wo die Uhr bei
                        // der Nutzlastgroesse aussteigt (§4.2a).
                        Label("Läuft durch: \(laufschriftFrames.count) Einzelbilder, \(nutzlastText) — wo die Größengrenze der Uhr liegt, ist offen (Gerätereferenz, §4.2a).",
                              systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(.secondary)
                        if nutzlastBytes > 60_000 {
                            Label("Eine auffällig große Nutzlast — kürzerer Text oder höheres Tempo macht sie kleiner.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    }
                case .text:
                    // Zu langer Text ist hier kein Fehler und keine eigene Warnung
                    // wert — die Uhr laesst ihn von selbst laufen (§4.3, §5.4). Statt
                    // der Breitenwarnung steht hier, dass unsere Vorschau nur eine
                    // Naeherung ist: die Uhr rastert selbst, mit ihrer eigenen Schrift.
                    Label("Nur eine Näherung — die Uhr setzt diesen Text selbst und zeigt ihn anders. Läuft er, weil er nicht passt, bestimmt „Scrolltempo“ unter „Verbindung“ das Tempo.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !unbekannteZeichen.isEmpty {
                        Label("Diese Zeichen kennt die Gerätschrift nicht und lässt sie einfach weg: \(unbekannteZeichenText). „als Pixel“ kann sie.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack(alignment: .bottom, spacing: 16) {
                MeldungsplatzWahl(platz: $platz, belegtePlaetze: belegtePlaetze)
                    .help("Blättert nur zwischen belegten Plätzen, wenn der Seitenwechsel unter „Verbindung“ nicht auf „kein Wechsel“ steht.")
                MeldungLoeschenKnopf(zustand: zustand, platz: platz,
                                     belegt: belegtePlaetze.contains(platz))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dauer (Sek.)").font(.caption).foregroundStyle(.secondary)
                    TextField("Uhr entscheidet", text: $dauerText).frame(width: 100)
                }
                Spacer()
                ZielauswahlView(zustand: zustand)
                Button(laeuft ? "Sende…" : "Senden") { senden() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(laeuft || zustand.ziele().isEmpty)
            }
            if zustand.ziele().isEmpty {
                Text("Erst unter „Verbindung“ eine Uhr eintragen und abfragen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
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
            laufschriftFrames = Textraster.laufschriftEinzelbilder(
                gesendeterText, schrift: schrift, groesse: groesse, fett: fett, farbe: farbeHex,
                schrittweite: tempo.schrittweite, bilddauer: tempo.bilddauer,
                versatzY: textY, iconBilder: iconRaster, iconLaeuftMit: iconLaeuftMit, luecke: luecke)
            // Aus denselben Einzelbildern, die die Vorschau zeigt — nicht noch
            // einmal gerastert, sonst liefe die Rechnung zweimal.
            laufschriftURI = (try? Bildraster.alsDatenURI(
                laufschriftFrames.map(\.pixel), breite: Pixelfeld.breiteStandard,
                hoehe: Pixelfeld.hoeheStandard, verzoegerung: tempo.bilddauer)) ?? ""
        }
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhaengt — als `.task(id:)`-
    /// Schluessel, damit die (nicht ganz billige) Berechnung nur bei einer
    /// tatsaechlichen Aenderung neu laeuft, nicht bei jedem Bild der laufenden
    /// Vorschau.
    private var laufschriftSchluessel: String {
        "\(weg)|\(passt)|\(gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(iconNummer)|\(iconLaeuftMit)|\(luecke)"
    }

    /// Alles, was den Text betrifft, in einer eigenen Leiste ueber dem Eingabefeld
    /// — wie in einem Textprogramm gewohnt, statt zwischen den Sendeoptionen
    /// verstreut. Systemmaterial statt fest eingetragener Farben, damit die
    /// Leiste in hell und dunkel gleich stimmig aussieht.
    private var formatleiste: some View {
        HStack(spacing: 10) {
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
            .labelsHidden().frame(width: 150)
            .disabled(weg == .text)
            .help(weg == .text ? "Die Uhr hat nur eine eingebaute Schrift — das gilt hier nicht."
                               : "Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten.")

            if let zulaessig = zulaessigeGroessen, let erste = zulaessig.first, let letzte = zulaessig.last {
                let schritt = zulaessig.count > 1 ? zulaessig[1] - zulaessig[0] : 1
                Stepper("\(Int(groesse))", value: $groesse, in: erste...letzte, step: schritt).frame(width: 80)
                    .help("Schriftgröße — \(schrift) ist aufs Pixelraster gezeichnet, dazwischen gibt es keine saubere Größe.")
            } else {
                Stepper("\(Int(groesse))", value: $groesse, in: 6...16).frame(width: 80)
                    .help("Schriftgröße")
            }

            formatKnopf(icon: "bold", hilfe: fettHilfe, aktiv: fett && fettWirkt) { fett.toggle() }
                .disabled(!fettWirkt)

            formatKnopf(icon: "capslock", hilfe: grossHilfe,
                       aktiv: grossbuchstaben && kleinbuchstabenMoeglich) { grossbuchstaben.toggle() }
                .disabled(!kleinbuchstabenMoeglich)

            Divider().frame(height: 18)

            Stepper("Abstand \(luecke)", value: $luecke, in: 0...3).frame(width: 110)
                .help("Leere Spalten zwischen den Zeichen, 0 bis 3 — nur beim Weg „als Pixel“: Jedes Zeichen wird einzeln gerastert und nach seiner Tinte angehängt, der Abstand ist also immer exakt so groß wie hier eingestellt, unabhängig von Schriftart, Größe und Zeichenpaar.")

            Divider().frame(height: 18)

            HStack(spacing: 2) {
                ausrichtungsKnopf(.links, aktuell: $horizontal, icon: "text.alignleft", hilfe: "Links ausrichten")
                ausrichtungsKnopf(.mittig, aktuell: $horizontal, icon: "text.aligncenter", hilfe: "Mittig ausrichten")
                ausrichtungsKnopf(.rechts, aktuell: $horizontal, icon: "text.alignright", hilfe: "Rechts ausrichten")
            }
            HStack(spacing: 2) {
                ausrichtungsKnopf(.oben, aktuell: $vertikal, icon: "align.vertical.top", hilfe: "Oben ausrichten")
                ausrichtungsKnopf(.mittig, aktuell: $vertikal, icon: "align.vertical.center", hilfe: "Mittig ausrichten")
                ausrichtungsKnopf(.unten, aktuell: $vertikal, icon: "align.vertical.bottom", hilfe: "Unten ausrichten")
            }

            Divider().frame(height: 18)

            ColorPicker("Farbe", selection: farbe).labelsHidden()
                .help("Farbe")

            Spacer()
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Ein einzelner Umschaltknopf einer Ausrichtungsgruppe — Symbol statt Wort,
    /// mit Einblendtext. Als eigene Buttons statt eines segmentierten Pickers,
    /// damit jeder Knopf sein eigenes `.help(...)` tragen kann.
    private func ausrichtungsKnopf<T: Equatable>(_ wert: T, aktuell: Binding<T>, icon: String, hilfe: String) -> some View {
        formatKnopf(icon: icon, hilfe: hilfe, aktiv: aktuell.wrappedValue == wert) { aktuell.wrappedValue = wert }
    }

    private func formatKnopf(icon: String, hilfe: String, aktiv: Bool,
                             aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: icon).frame(width: 22, height: 20)
        }
        .buttonStyle(.borderless)
        .background(aktiv ? Color.accentColor.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(hilfe)
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
        let anzeigenName = MeldungsplatzWahl.name(fuer: platz)
        Task { await zustand.senden(frame, als: anzeigenName); laeuft = false }
    }

    /// Baut den Rahmen fuer den gewaehlten Weg. Beim Pixel-Weg zwei Faelle, einer
    /// je Entscheidung von `passt`: ein starrer `draw`-Rahmen mit dem Icon als
    /// zweitem Bild, oder ein einziges animiertes GIF, in dem das Icon schon
    /// steckt. Beim Text-Weg ein `Textblock`, den die Uhr selbst setzt — ein
    /// gewaehltes Icon kommt auch hier als eigenes Bild dazu, aber nie
    /// mitlaufend: das Laufen macht dort die Uhr, nicht unsere Laufschrift.
    private func gebauterRahmen() throws -> Frame {
        switch weg {
        case .pixel:
            guard passt else {
                let uri = laufschriftURI.isEmpty
                    ? try Textraster.laufschrift(gesendeterText, schrift: schrift, groesse: groesse, fett: fett,
                                                 farbe: farbeHex, schrittweite: tempo.schrittweite,
                                                 bilddauer: tempo.bilddauer, versatzY: textY,
                                                 iconBilder: iconRaster, iconLaeuftMit: iconLaeuftMit,
                                                 luecke: luecke)
                    : laufschriftURI
                return Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: dauer)
            }
            var frame = Frame(draw: feld.alsDrawBefehle(), dauer: dauer)
            if let icon = gewaehltesIcon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4))
            }
            return frame
        case .text:
            var frame = Frame(texte: [textblock], dauer: dauer)
            if let icon = gewaehltesIcon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4))
            }
            return frame
        }
    }
}
