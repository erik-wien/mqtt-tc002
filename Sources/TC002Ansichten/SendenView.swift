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

    /// Welcher Reiter im Inspektor steht. **Neu am 14.09.2026**: Bis dahin gab
    /// es hier keine Reiter, sondern einen durchgehenden Inspektor. „Wie lange
    /// ist etwas zu sehen" lag deshalb an drei Stellen verstreut — Dauer in der
    /// Sendezeile, Seitenwechsel und Scrolltempo unter „Einstellungen". Jetzt
    /// steht das zusammen, und zwar an derselben Stelle wie im Editor.
    @State private var inspektorreiter = Inspektorreiter.format

    enum Inspektorreiter: String, CaseIterable, Identifiable {
        case format, zeit
        var id: String { rawValue }
    }

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
        // **Nummer und Kante**, nicht nur die Nummer. Ein 16×16 traegt seinen
        // Dateinamen im selben Feld wie ein LaMetric-Icon seine Nummer; ohne
        // die Kante gewaenne bei gleichem Schluessel der 8×8-Bestand, weil er
        // vorn steht — und der Block zeigte das falsche Bild. Dieselbe
        // Bedingung wie in `init`, wo der zuletzt gewaehlte Stand gelesen wird.
        gewaehltesIcon = stand.icon.flatMap { nummer in
            Self.sammlungen.flatMap { $0.alle() }
                .first { $0.nummer == nummer && $0.kante == stand.iconKanteOderAcht }
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

    /// Welche Geraetefront die Vorschau zeigt — die der Uhr, auf die sich die
    /// Vorschau bezieht (`referenzUhr`, dieselbe, aus der auch die Bloecke
    /// lesen). `nil` heisst `.tc002`, wie bei `Uhr.typ`: Ohne eingerichtete Uhr
    /// zeigt die Vorschau die Werksfirmware, nicht gar nichts.
    private var geraeteart: Geraetetyp? { zustand.referenzUhr?.typ }

    /// Dieselbe Auskunft, nur ohne `Optional` — die Reglertabelle im Kern
    /// fragt nach einer Gattung, nicht nach „vielleicht keiner".
    private var gattung: Geraetetyp { geraeteart ?? .tc002 }

    /// Siehe `.task(id:)` oben.
    private func ausrichtungPruefen() {
        guard !gattung.waagrechteAusrichtungen.contains(horizontal) else { return }
        horizontal = .links
    }
    /// Auf wie vielen Punkten die **Vorschau** rechnet: den Maßen der Uhr, auf
    /// die sie sich bezieht. Ohne eingerichtete Uhr die Werksfirmware — wie bei
    /// `geraeteart` zeigt die Vorschau dann 52×16 und nicht gar nichts.
    private var mass: Anzeigemass { zustand.referenzUhr.map(Anzeigemass.fuer) ?? .tc002 }

    /// Die Optionen, mit denen die **Vorschau** rastert — auf einer NG-Uhr mit
    /// fester Näherungsschrift, weil das Gerät den Text ohnehin selbst setzt
    /// (`Meldungsoptionen.naeherung`). Was **gesendet** wird, sind unverändert
    /// `optionen`: `gebauterRahmen` fragt hier nicht.
    private var vorschauOptionen: Meldungsoptionen { optionen.naeherung(fuer: gattung) }

    private var passt: Bool {
        Meldungsbau.passt(vorschauOptionen, mitIcon: mitIcon, iconKante: iconKante, mass: mass)
    }
    private var feld: Pixelfeld {
        Meldungsbau.feld(vorschauOptionen, mitIcon: mitIcon, iconKante: iconKante, mass: mass)
    }

    /// Laeuft der Text als Laufschrift, ist die waagrechte Ausrichtung ohne
    /// Wirkung: `Textraster.laufschriftEinzelbilder` schiebt ihn immer von
    /// ganz aussen durchs Fenster und fragt `horizontal` gar nicht erst ab.
    /// Nur der Pixel-Weg laeuft in unserer eigenen Rechnung — beim Text-Weg
    /// entscheidet die Uhr selbst, ob und wie sie laufen laesst, und das
    /// wissen wir vorher nicht (siehe die Naeherungs-Meldung dort).
    private var waagrechtWirktNicht: Bool { weg == .pixel && !passt }

    /// **Das vorberechnete GIF geht nur mit, wenn es die Größe hat, in der
    /// gesendet wird.** Die Vorschau rastert auf dem Maß der angesehenen Uhr;
    /// gesendet wird an `zustand.ziele()`, und das dürfen mehrere sein
    /// (`ZielauswahlView`). Steht die Vorschau auf einer NG-Uhr, ist ihr GIF
    /// 32×8 — einer gleichzeitig gewählten TC002 hätte das als Nutzlast ein
    /// Viertel ihrer Anzeige gefüllt. In dem Fall rastert `Meldungsbau.rahmen`
    /// eben noch einmal selbst, in der Größe, die gesendet wird.
    private func gebauterRahmen() throws -> Frame {
        try Meldungsbau.rahmen(optionen, icon: gewaehltesIcon, sammlung: sammlung,
                               vorberechnet: mass == .tc002 ? laufschriftURI : nil)
    }

    /// Wie viele Bytes an eine NG-Uhr wirklich hinausgehen: der Rumpf, den
    /// `Anzeigen.nutzlast` für diese Gattung baut — Text, Regler und das Icon
    /// als Daten-URI. 0 auf der Werksfirmware, wo die Frage nicht gestellt wird.
    ///
    /// Das Icon wird dafür von der Platte gelesen; deshalb abseits des
    /// Hauptthreads, wie die Laufschrift selbst.
    private func ngNutzlastBytes() async -> Int {
        guard gattung.setztSelbst else { return 0 }
        let (o, icon, sammlung) = (optionen, gewaehltesIcon, sammlung)
        return await Task.detached(priority: .userInitiated) {
            let uri = icon.flatMap { try? sammlung.datenURI(fuer: $0) }
            let rumpf = try? NGNutzlast.anzeige(o, iconDatenURI: uri, iconKante: icon?.kante ?? 8)
            return rumpf?.utf8.count ?? 0
        }.value
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

    /// Wie groß die nächste Nutzlast wird. Bei der Werksfirmware ist das das
    /// Lauf-GIF; bei NG geht davon **nichts** hinaus, sondern der Text samt
    /// Reglern (`Anzeigen.nutzlast`) — die Zahl wird deshalb im Rechenlauf
    /// unten je nach Gattung verschieden ermittelt.
    @State private var nutzlastBytes = 0

    /// Zeichen, die die eingebaute Gerätschrift nicht kennt: keine Umlaute, von
    /// den Satzzeichen nur `%`, `.`, `-`, `:` (Gerätereferenz, §1). Nur fürs
    /// Vorwarnen beim Weg „als Text" gedacht — die Uhr meldet ein fehlendes
    /// Zeichen sonst nicht, sie zeigt an der Stelle einfach nichts. Geprüft
    /// wird `gesendeterText`, nicht `text`: Nach „Großbuchstaben" ist aus
    /// einem „ß" längst ein darstellbares „SS" geworden, das soll die Warnung
    /// nicht mehr treffen. Jedes betroffene Zeichen nur einmal, in der
    /// Reihenfolge des ersten Auftretens.
    /// **Die Liste steht im Kern** (`Geraeteschrift`), nicht hier: Sie ist eine
    /// Aussage ueber die eingebaute Schrift der Uhr, und das Telefon braucht
    /// dieselbe. Bis zum 18.09.2026 stand sie an dieser Stelle — und das
    /// Telefon warnte gar nicht.
    private var unbekannteZeichen: [Character] { Geraeteschrift.unbekannteZeichen(in: gesendeterText) }
    private var unbekannteZeichenText: String { Geraeteschrift.unbekannteZeichenText(in: gesendeterText) }

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
                // Die Vorschau zeigt beim Pixel-Weg, was ankommt: stehend, wenn es
                // passt, laufend, wenn nicht — bei der Laufschrift steckt das Icon
                // schon in den Einzelbildern, deshalb dort kein zweites. Beim Weg
                // „als Text" ist es immer unsere eigene Rasterung als Näherung, nie
                // laufend: das Laufen besorgt dort die Uhr, wir kennen ihre Schrift
                // nicht und können es nicht zeigen.
                //
                // Die Kantenlaenge richtet sich nach dem Platz, nicht nach einer
                // festen Zahl: Der Geraeterahmen ist um ein festes Verhaeltnis
                // breiter und hoeher als das Pixelfeld darin. Was in Breite und
                // Hoehe passt, bestimmt die Groesse; die Uhr steht mittig.
                //
                // **Die Faktoren kommen aus der Zeichnung, nicht von Hand.**
                // Bis hierher standen sie als 680/584 und 356/177 abgeschrieben
                // da — die Masse der TC002-Front. Seit es eine zweite Geraeteart
                // gibt, waeren sie fuer diese schlicht falsch, und der Rahmen
                // wuerde still beschnitten: keine Meldung, nur ein Bild, das
                // nicht ganz passt.
                GeometryReader { geo in
                    let zeichnung = Geraetezeichnung.fuer(geraeteart)
                    // Nicht `breitenFaktor`: Der setzt eine bereits ausgemessene
                    // Feldbreite in Punkten voraus, hier steht aber nur die
                    // Spaltenzahl des Pixelfelds. Bei der TC002 trifft sie
                    // zufaellig fast genau die Zeichnung, bei der AWTRIX
                    // unterschaetzte das die wirkliche Rahmenbreite um rund ein
                    // Viertel — genau das Mass, um das die Vorschau am iPad zu
                    // breit geriet, weil dort weniger Luft bleibt, es
                    // aufzufangen. `masse(inhaltHoehe:)` rechnet dieselbe Formel
                    // wie `GeraeteRahmen` selbst.
                    let einheit = zeichnung.masse(inhaltHoehe: Double(feld.hoehe))
                    // Die Punktreihe braucht Platz unter dem Rahmen, sonst
                    // schoebe sie ihn beim Erscheinen um ihre Hoehe hinauf.
                    let punktehoehe: Double = zustand.uhren.count > 1 ? 20 : 0
                    let nachBreite = (geo.size.width - 24) / einheit.rahmenBreite
                    let nachHoehe = (geo.size.height - 24 - punktehoehe) / einheit.rahmenHoehe
                    let kante = max(4, min(14, (min(nachBreite, nachHoehe)).rounded(.down)))
                    // **Die Punkte gehoeren an die Vorschau, nicht an den
                    // unteren Rand ihres Bereichs.** Standen sie ausserhalb
                    // des `GeometryReader`, rutschten sie mit dessen Dehnung
                    // nach unten weg — beim Abnehmen am 18.09.2026 wurden sie
                    // dort zuerst gar nicht gesucht. Jetzt sitzen sie im
                    // selben mittigen Stapel, direkt unter dem Rahmen.
                    VStack(spacing: 6) {
                        VorschauView(feld: feld, kantenlaenge: kante,
                                    typ: geraeteart,
                                    icon: (weg == .text || passt) ? gewaehltesIcon?.datei : nil,
                                    iconKante: iconKante,
                                    laufschriftBilder: (weg == .pixel && !passt) ? laufschriftFrames : nil)
                            .uhrenwischen(zustand)
                        Uhrenpunkte(zustand: zustand)
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                }
                // **Setzt die Uhr selbst, ist der Weg einerlei.** Eine NG bekommt
                // von `Anzeigen.nutzlast` in beiden Faellen den Text samt Reglern,
                // nie unsere Pixel. Die Zeile „Laufschrift · N Bilder · KB" spraeche
                // hier von einem GIF, das niemand je sieht; was wirklich hinausgeht,
                // ist der Rumpf, dessen Bytes `ngNutzlastBytes` misst.
                if gattung.setztSelbst {
                    Label("Nur eine Näherung — die Uhr setzt diesen Text selbst und zeigt ihn anders. Läuft er, weil er nicht passt, gilt das Lauftempo dieser Meldung.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                    if nutzlastBytes > 0 {
                        Text(lokf("Hinaus geht der Text samt Reglern · %@", Nutzlastzeile.groesse(nutzlastBytes)))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                switch weg {
                case .pixel:
                    if !passt {
                        // Zu langer Text ist kein Fehler, sondern der Grund fuers Laufen.
                        // Zeigen, worauf man sich einlaesst: niemand weiss, wo die Uhr bei
                        // der Nutzlastgroesse aussteigt (§4.2a).
                        // Nur der Stand, keine Erklaerung — die steht in der Hilfe
                        // („Senden", Absatz zur Nutzlastgroesse).
                        Nutzlastzeile(
                            art: lok("Laufschrift"),
                            bilder: laufschriftFrames.count,
                            bytes: nutzlastBytes,
                            rat: lok("nur ein kürzerer Text macht sie kleiner, das Tempo ändert daran nichts."))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                case .text:
                    // **Doch eine Breitenwarnung.** Bis zum 18.09.2026 stand hier,
                    // zu langer Text sei auf diesem Weg kein Fehler, weil die Uhr
                    // ihn von selbst laufen lasse. Das stimmt nicht: Gemessen am
                    // 11.09.2026 mit drei Fassungen laeuft selbst geschickter Text
                    // auf der Werksfirmware **nicht**, er wird abgeschnitten
                    // (`docs/firmware-beobachtungen.md` Nr. 1) — und `scrollSpeed`
                    // aendert daran nichts. Die Schaetzung ist ungenau, weil die
                    // Uhr ihre eigene Schrift setzt; deshalb „voraussichtlich".
                    if !passt {
                        Label("Voraussichtlich zu lang: Die Uhr schneidet selbst geschickten Text ab, statt ihn durchlaufen zu lassen. Wie viel auf ihre eingebaute Schrift passt, weiß diese App nicht genau — „als Pixel“ lässt ihn laufen.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    // Statt
                    // der Breitenwarnung steht hier, dass unsere Vorschau nur eine
                    // Naeherung ist: die Uhr rastert selbst, mit ihrer eigenen Schrift.
                    Label("Nur eine Näherung — die Uhr setzt diesen Text selbst und zeigt ihn anders.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !unbekannteZeichen.isEmpty {
                        Label(lokf("Diese Zeichen kennt die Gerätschrift nicht und lässt sie einfach weg: %@. „als Pixel“ kann sie.", unbekannteZeichenText),
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Nur noch die fuenf Bloecke: Die Dauer steht seit dem 14.09.2026
            // im Zeit-Reiter des Inspektors, bei Seitenwechsel und
            // Scrolltempo. Damit faellt auch der `ViewThatFits` weg, der hier
            // den Ueberlauf einer ueberladenen Zeile auffangen musste.
            slotZeile

            // **Feld und Empfaenger in einer Zeile** — wie am Telefon, wo das
            // Antennenzeichen rechts neben dem Eingabefeld sitzt. Das Senden
            // selbst steckt im Feld (⏎ am rechten Rand); daneben steht die
            // Frage, an wen.
            HStack(spacing: 8) {
                textFeld
                ZielauswahlView(zustand: zustand)
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
            // **Die angesehene Uhr, mittig.** Am Mac steht im Fenstertitel der
            // Programmname (`SchreibtischView` setzt `navigationTitle`
            // ausdruecklich nur unter iOS); `.principal` ist die Stelle, die
            // auf beiden Plattformen dasselbe meint — und dieselbe, an der
            // Xcode sein Ziel zeigt.
            // **Was man ansieht**, steht mittig im Titel. Der Empfaenger
            // steht **nicht** hier: Er gehoert zum Senden, also ans
            // Eingabefeld — wie am Telefon, wo das Antennenzeichen rechts
            // daneben sitzt. Drei Zeichen in einer Leiste zusammenzukleben
            // haette drei verschiedene Dinge nebeneinandergestellt: ansehen,
            // senden, Inspektor.
            ToolbarItem(placement: .principal) {
                Uhrenmenue(zustand: zustand)
            }
            // Ausdruecklich rechts: Der Schalter gehoert zu dem Bereich, den
            // er ein- und ausblendet, und der liegt rechts.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeInspektor.toggle()
                } label: {
                    Label(lok("Formatierung ein- oder ausblenden"), systemImage: "sidebar.trailing")
                }
                .namensichtbarAmIPad()
                .help(lok("Formatierung ein- oder ausblenden"))
            }
        }
        .inspector(isPresented: $zeigeInspektor) { inspektor }
        // Eine Ausrichtung, die es auf dieser Gattung nicht gibt, wird beim
        // Wechsel **sichtbar** zurueckgestellt. Sie stehen zu lassen hiesse,
        // im Waehler „rechts" zu zeigen und linksbuendig zu senden — und
        // gerade weil das niemandem auffiele, geschieht es hier oben und
        // nicht erst im Sendeweg. `.task` deckt den ersten Aufbau ab, bei dem
        // `onChange` noch nicht gefeuert hat.
        .task(id: geraeteart) { ausrichtungPruefen() }
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
            guard weg == .pixel, !passt else {
                laufschriftFrames = []; laufschriftURI = ""
                nutzlastBytes = await ngNutzlastBytes()
                return
            }
            // Mehrere hundert Einzelbilder rastern, als GIF kodieren, Base64
            // darueber — bei jedem Tastendruck. Das gehoert nicht auf den
            // Hauptthread, sonst stockt das Eingabefeld. Die Eingaben werden
            // vorher eingesammelt, damit der Rechenlauf keine View-Zustaende
            // anfasst; ein inzwischen ueberholter Lauf wirft sein Ergebnis weg.
            let (o, iconBilder, iconKante, mass) = (vorschauOptionen, iconRaster, iconKante, mass)
            let (frames, uri) = await Task.detached(priority: .userInitiated) {
                let frames = Meldungsbau.laufschriftBilder(o, iconBilder: iconBilder,
                                                           iconKante: iconKante, mass: mass)
                // Aus denselben Einzelbildern, die die Vorschau zeigt — nicht noch
                // einmal gerastert, sonst liefe die Rechnung zweimal.
                let uri = (try? Bildraster.alsDatenURI(
                    frames.map(\.pixel), breite: mass.breite,
                    hoehe: mass.hoehe, verzoegerung: o.tempo.bilddauer)) ?? ""
                return (frames, uri)
            }.value
            guard !Task.isCancelled else { return }
            laufschriftFrames = frames
            laufschriftURI = uri
            // Bei NG geht das eben gebaute GIF nicht hinaus — dort zaehlt, was
            // `Anzeigen` wirklich schickt.
            nutzlastBytes = gattung.setztSelbst ? await ngNutzlastBytes() : uri.utf8.count
        }
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhaengt — als `.task(id:)`-
    /// Schluessel, damit die (nicht ganz billige) Berechnung nur bei einer
    /// tatsaechlichen Aenderung neu laeuft, nicht bei jedem Bild der laufenden
    /// Vorschau.
    private var laufschriftSchluessel: String {
        "\(weg)|\(passt)|\(gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(rand)|\(gewaehltesIcon?.kennung ?? "")|\(iconLaeuftMit)|\(luecke)|\(gattung)|\(mass.breite)×\(mass.hoehe)"
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
        VStack(spacing: 0) {
            // **Symbole statt Woerter**, dieselbe Ueberlegung wie im Editor:
            // Die Namen stehen als `accessibilityLabel` am Segment, so wie es
            // die Ausrichtungswaehler weiter unten seit je halten.
            Picker("Inspektor", selection: $inspektorreiter) {
                Image(systemName: "textformat").tag(Inspektorreiter.format)
                    .accessibilityLabel(Text("Format"))
                Image(systemName: "clock").tag(Inspektorreiter.zeit)
                    .accessibilityLabel(Text("Zeit"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            inspektorinhalt
        }
    }

    @ViewBuilder
    private var inspektorinhalt: some View {
        switch inspektorreiter {
        case .zeit:
            Form {
                // **Die Laufschrift gehoert hierher, nicht zum Format.** Sie
                // beantwortet dieselbe Frage wie Dauer und Seitenwechsel: wie
                // lange man etwas sieht — nur bezogen auf einen Text, der
                // durchlaeuft, statt auf eine Anzeige, die steht. Bis zum
                // 14.09.2026 stand sie zwischen „Senden als" und „Icon", wo
                // sie zwar zur Sendung passte, aber nicht zu ihren Nachbarn.
                //
                // Der Abschnitt bleibt hier in `SendenView` und wandert nicht
                // nach `Zeitabschnitte`: Ob er wirkt, haengt an `weg` und
                // `passt` — Zustand dieser Ansicht. Ihn dorthin zu schieben
                // hiesse, drei Werte durchzureichen, damit ein Baustein
                // entscheiden kann, was der Aufrufer laengst weiss.
                Zeitabschnitte(zustand: zustand, dauerText: $dauerText) {
                    laufschriftAbschnitt
                }
            }
            .formStyle(.grouped)
        case .format:
            formatinhalt
        }
    }

    /// **Ein eigener Abschnitt** — die Begruendung steht in `Zeitabschnitte`:
    /// Im schmalen Inspektor faellt die Beschriftung eines Segmentschalters
    /// weg, und ein namenloses „langsam mittel schnell" unter der Dauer las
    /// sich als deren Teil. Die Ueberschrift eines Abschnitts faellt nicht weg.
    @ViewBuilder
    private var laufschriftAbschnitt: some View {
        Section("Laufschrift") {
            Picker("Tempo", selection: $tempo) {
                Text("langsam").tag(Lauftempo.langsam)
                Text("mittel").tag(Lauftempo.mittel)
                Text("schnell").tag(Lauftempo.schnell)
            }
            .pickerStyle(.segmented).labelsHidden()
            .disabled(!(weg == .pixel && !passt))
            .help(weg == .pixel && !passt ? lok("Wie schnell der Text durchläuft — nur wenn er nicht ins Display passt und deshalb läuft.")
                                          : lok("Gilt nur, wenn der Text nicht ins Display passt."))
            // Sagt, was die Ueberschrift nicht mehr sagt: fuer wie viele
            // Anzeigen das gilt, und wann ueberhaupt.
            Text("Gilt nur für diese Meldung — und nur, wenn der Text nicht ins Display passt und deshalb durchläuft.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var formatinhalt: some View {
        Form {
            // Segmentschalter ueber die volle Breite, ohne Beschriftung links:
            // Der Abschnittstitel sagt schon, worum es geht. Eine Beschriftung
            // daneben quetschte den Schalter zusammen — genau das sah man.
            Section {
                Picker("Weg", selection: $weg) {
                    Text("als Pixel").tag(SendeWeg.pixel)
                    Text("als Text").tag(SendeWeg.text)
                }
                .pickerStyle(.segmented).labelsHidden()
            } header: {
                Abschnittskopf("Senden als", hilfe: lok("Als Pixel rechnet die App das Bild selbst; passt der Text nicht, baut sie den Lauf als GIF. Als Text setzt ihn die Uhr mit ihrer eingebauten Schrift und lässt ihn bei Bedarf selbst durchlaufen — das Tempo steht dann in den Einstellungen der Uhr."))
            }

            // Immer da, gesperrt statt versteckt: Ein Abschnitt, der je nach
            // Zustand erscheint und verschwindet, laesst die Seitenleiste
            // springen. Gesperrt mit Begruendung ist die Bauart der uebrigen
            // Regler hier.
            Section("Icon") {
                IconAuswahlView(gewaehltesIcon: $gewaehltesIcon, sammlungen: Self.sammlungen,
                                sperre: { zustand.grafikSperre(hoehe: $0) })
                // Gehoert zum Icon, nicht zur Laufschrift — es sagt, was das Icon
                // beim Laufen tut.
                Toggle("Icon mitscrollen", isOn: $iconLaeuftMit)
                    .disabled(gewaehltesIcon == nil || !(weg == .pixel && !passt))
            }

            Section {
                // Blank, ohne `LabeledContent` und ohne `labelsHidden`: Ein
                // Waehler in einem gruppierten `Form` zeichnet die kanonische
                // Zeile selbst — Beschriftung links, Wert im grauen Kaestchen
                // mit Doppelpfeil rechts. Die Umwicklung nahm ihm genau das
                // und liess unter iPadOS blanken Text mit Doppelpfeil uebrig.
                // **Schrift und Groesse in einer Zeile.** Sie gehoeren
                // zusammen — welche Groessen es gibt, haengt an der Schrift
                // (`angeboteneGroessen`) —, und zwei volle Zeilen fuer eine
                // Entscheidung sind eine zu viel. `LabeledContent` traegt die
                // Beschriftung links, die beiden Waehler stehen rechts
                // nebeneinander; der Groessenwaehler bekommt nur so viel
                // Breite, wie „16 px" braucht.
                // **Ohne Beschriftung links.** Der Abschnitt heisst schon
                // „Schrift"; eine Zeile gleichen Namens darunter sagt nichts
                // und nimmt die halbe Breite. Was hier Platz braucht, ist der
                // Schriftname — „Silkscreen" stand als „Silk…reen" da, waehrend
                // links „Schrift" stand.
                //
                // Ohne `LabeledContent` faellt auch die Regel gegen umwickelte
                // Waehler nicht mehr ins Gewicht: Es gibt keine Umwicklung
                // mehr, nur zwei Waehler nebeneinander in einer Zeile.
                HStack(spacing: 8) {
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
                        // Nimmt, was uebrig ist — der Name ist das Lange von
                        // beiden.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(weg == .text)
                        .gattungssperre(.schriftart, gattung,
                            sonst: weg == .text ? lok("Die Uhr hat nur eine eingebaute Schrift — das gilt hier nicht.")
                                                : lok("Schriftart — bei 16 Pixeln Höhe eignen sich schmale, dicktengleiche Schriften am besten."))

                        // Eine Liste, kein Schieber: Die durchgesehenen Groessen haben
                        // Luecken — Tiny5 etwa 7, 8, 9, 12, 15, 16 —, und eine Luecke
                        // laesst sich als Schrittweite nicht ausdruecken.
                        Picker("Größe", selection: $groesse) {
                            ForEach(angeboteneGroessen, id: \.self) { g in
                                Text(lokf("%d px", Int(g))).tag(g)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .gattungssperre(.groesse, gattung,
                            sonst: eigenesRaster
                              ? lokf("Schriftgröße — %@ ist aufs Pixelraster gezeichnet, dazwischen gibt es keine saubere Größe.", schrift)
                              : lok("Schriftgröße"))
                }

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
                            .gattungssperre(.fett, gattung, sonst: fettHilfe)
                            .accessibilityLabel(Text("Fett"))
                        Toggle(isOn: $grossbuchstaben) { Image(systemName: "capslock") }
                            .toggleStyle(.button)
                            .disabled(!kleinbuchstabenMoeglich)
                            .gattungssperre(.grossbuchstaben, gattung, sonst: grossHilfe)
                            .accessibilityLabel(Text("Großbuchstaben"))
                        // **Kein blankes Systemfeld.** Bei weisser Schrift
                        // stuende dort ein weisser Fleck auf hellem Grund —
                        // `Farbkreis` legt einen Regenbogenring darum, der zum
                        // Element gehoert und nicht zur Farbe. Die
                        // Systempalette bleibt darunter der Ausloeser.
                        //
                        // Ohne Deckkraft: `farbeHex` haelt „#RRGGBB", ein
                        // Alphawert fiele beim Sichern ohnehin weg.
                        Farbkreis(farbe: farbe)
                    }
                }
            } header: {
                // Der Größenwähler steht in der Zeile darunter und hat keine
                // eigene Überschrift; seine Erklärung gehört deshalb hierher.
                Abschnittskopf("Schrift", hilfe: lok("Zur Wahl stehen nur Schriften, die aufs Pixelraster der Uhr gezeichnet oder dafür durchgesehen sind — schmale, dicktengleiche stehen bei sechzehn Zeilen am besten. Sechzehn Pixel füllen die volle Höhe; die hat nur die TC002. Eine TC001 unter AWTRIX NG hat acht Zeilen und setzt den Text ohnehin mit ihrer eigenen Schrift."))
            }

            Section("Lage") {
                LabeledContent("Rand") {
                    Schrittwahl("Rand", wert: $rand, bereich: 0...3)
                }
                .disabled(vertikal == .mittig)
                .gattungssperre(.rand, gattung)

                LabeledContent("Abstand") {
                    Schrittwahl("Abstand", wert: $luecke, bereich: 0...3)
                }
                .gattungssperre(.abstand, gattung)

                // Segmentschalter statt dreier loser Knoepfe — dieselbe Form wie
                // die Ausrichtung bei Pages.
                // Auch hier blank: Der Segmentschalter bleibt (die Wahl soll
                // nebeneinander stehen), aber die Beschriftung setzt die
                // `Form` selbst links daneben.
                // **Rechtsbuendig ist hier kein gesperrter Regler, sondern
                // einer, den es nicht gibt.** Die AWTRIX kennt nur „mittig ja
                // oder nein"; ein dritter Eintrag wuerde angenommen und dann
                // als linksbuendig gesendet — die Oberflaeche zeigte etwas
                // anderes, als auf der Uhr steht. Darum faellt der Eintrag
                // weg, und ein schon gewaehltes „rechts" wird beim Wechsel
                // sichtbar auf „links" gestellt (siehe `.onChange` unten),
                // statt still umgedeutet zu werden.
                Picker("Waagrecht", selection: $horizontal) {
                    Image(systemName: "text.alignleft").tag(SendenHAusrichtung.links)
                    Image(systemName: "text.aligncenter").tag(SendenHAusrichtung.mittig)
                    if gattung.waagrechteAusrichtungen.contains(.rechts) {
                        Image(systemName: "text.alignright").tag(SendenHAusrichtung.rechts)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(waagrechtWirktNicht)
                .help(waagrechtWirktNicht
                    ? lok("Läuft der Text als Laufschrift, füllt er das Fenster ohnehin von einem Rand zum anderen — die Ausrichtung bliebe ohne Wirkung.")
                    : lok("Waagrecht"))
                Picker("Senkrecht", selection: $vertikal) {
                    Image(systemName: "align.vertical.top").tag(SendenVAusrichtung.oben)
                    Image(systemName: "align.vertical.center").tag(SendenVAusrichtung.mittig)
                    Image(systemName: "align.vertical.bottom").tag(SendenVAusrichtung.unten)
                }
                .pickerStyle(.segmented)
                .gattungssperre(.senkrecht, gattung)
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
                // Das ⊗ liegt **ueber** dem Block und ausserhalb seines
                // Knopfes: Innen waere es Teil von dessen Beschriftung und
                // loeste beim Tippen die Platzwahl aus statt zu loeschen.
                // Etwas nach aussen versetzt, damit es die Vorschau im Block
                // nicht verdeckt.
                .overlay(alignment: .topTrailing) {
                    MeldungLoeschenKnopf(zustand: zustand, platz: i,
                                         belegt: belegtePlaetze.contains(i))
                        .offset(x: 8, y: -8)
                }
            }
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
    /// **Das Feld ist der Knopf.** Bis zum 18.09.2026 stand daneben ein
    /// eigener „Senden"; jetzt sitzt am rechten Rand des Feldes ein ⏎, das
    /// ansagt, was die Eingabetaste tut, und selbst anklickbar ist — dieselbe
    /// Bauart wie am Telefon, wo die Eingabetaste schon seit dem 15.09.2026
    /// schickt.
    ///
    /// `.onSubmit` und nicht mehr `keyboardShortcut(.defaultAction)`: Der
    /// Kurzbefehl hing am Knopf, und den gibt es nicht mehr. Die Prüfung, ob
    /// überhaupt gesendet werden kann, steht deshalb hier — vorher tat das
    /// `.disabled` des Knopfes.
    private var textFeld: some View {
        TextField("Text", text: $text)
            .font(.title2)
            // **Die Haupthandlung soll man sehen.** `.title2` vergroesserte
            // nur die Schrift, nicht die Fassung — uebrig blieb ein flaches
            // Feld mit grossen Buchstaben darin. `.extraLarge` ist der Weg des
            // Systems, ein Bedienelement groesser zu machen (macOS 14, siehe
            // `ControlSize`); von Hand eine Hoehe zu setzen haette Fokusring
            // und Innenabstaende auseinanderlaufen lassen.
            .controlSize(.extraLarge)
            .eingabefeld(loeschbar: $text,
                         senden: sendenMoeglich ? { senden() } : nil,
                         laeuft: laeuft)
            .onSubmit { if sendenMoeglich { senden() } }
    }

    /// Ob es überhaupt etwas zu senden gibt und jemanden, der es nimmt.
    private var sendenMoeglich: Bool {
        !laeuft && !zustand.ziele().isEmpty && !text.trimmingCharacters(in: .whitespaces).isEmpty
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
                                 slotIcon: slotIcon, slotIconKante: iconKante,
                                 slotPlatz: slotPlatz)
            laeuft = false
        }
    }
}

/// Löscht **diesen** Meldungsplatz auf den gewählten Uhren — ein ⊗ in der Ecke
/// des Blocks, den es betrifft.
///
/// Bis zum 14.09.2026 stand stattdessen **eine** breite rote Schaltfläche
/// neben der Blockreihe, beschriftet „Slot 3 auf der Uhr löschen". Sie war
/// aus zwei Gründen schlecht: Sie bezog sich auf den gerade *gewählten* Platz,
/// den man erst treffen musste, und sie nahm in einer ohnehin engen Zeile mehr
/// Platz ein als die fünf Blöcke zusammen. Ein Zeichen an dem Block, den es
/// angeht, braucht keine Beschriftung und keine Erklärung, welcher gemeint
/// ist.
///
/// **Nur an belegten Plätzen.** Ein leerer Platz hat nichts zu löschen; ein
/// abgeblendetes ⊗ an vier von fünf Blöcken wäre Unruhe ohne Aussage.
///
/// Das Gegenstück zum Einblendtext ist hier ein **Kontextmenü**, nicht
/// `namensichtbarAmIPad()`: Der Knopf wiederholt sich fünfmal, und fünf
/// ausgeschriebene Namen in der Blockreihe wären mehr Text als Bild — dieselbe
/// Überlegung wie beim Papierkorb im Icon-Raster
/// (`EinblendtextGegenstueckTests`).
struct MeldungLoeschenKnopf: View {
    @Bindable var zustand: AppZustand
    let platz: Int
    /// Ein leerer Platz lässt sich nicht löschen. Woher das bekannt ist, steht
    /// bei `belegtePlaetze`: gemeldet schlägt gemerkt.
    let belegt: Bool

    @State private var laeuft = false

    private var beschriftung: String { lokf("Slot %d auf der Uhr löschen", platz) }

    var body: some View {
        if belegt {
            Button(role: .destructive, action: loeschen) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .font(.system(size: 15))
                    // Polsterung, nicht Symbolgröße: Das Zeichen bleibt klein,
                    // die Trefferfläche wächst.
                    .padding(6)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(laeuft || zustand.ziele().isEmpty)
            .help(beschriftung)
            .accessibilityLabel(Text(beschriftung))
            .contextMenu {
                Button(role: .destructive, action: loeschen) { Text(beschriftung) }
            }
        }
    }

    private func loeschen() {
        laeuft = true
        let name = Meldungsplatz.name(fuer: platz)
        Task { await zustand.loeschen(name); laeuft = false }
    }
}
