import SwiftUI
import TC002Core
import TC002Modell
import UniformTypeIdentifiers

/// Der Bereich „Editor": Pixel malen.
///
/// **Ein Bereich statt zweier.** Bis zum 13.09.2026 gab es „Icons" (8×8, 16×16)
/// und „Bilder" (52×16) nebeneinander. Der Auftraggeber hat beim Testen gesagt,
/// er verstehe den Unterschied zwischen Malen und Icons nicht — und hatte
/// recht: Es ist eine Taetigkeit. Was dabei herauskommt, entscheidet allein die
/// Leinwandgroesse, und was daraus folgt, steht abgeleitet in
/// `Leinwandgroesse`, nicht als Fallunterscheidung hier.
///
/// **Aufbau nach dem Muster von Pages:** Seitenleiste — Leinwand — Inspektor.
/// Der Inspektor hat drei Modi (Malen, Animation, Bestand), umgeschaltet ueber
/// die Segmentwahl an seinem Kopf. Unter der Leinwand steht die Sendezeile —
/// **nur bei 16×52**, denn ein Icon ist fuer sich keine Anzeige.
///
/// Eine Ansicht mit Unterschieden, nicht zwei mit Aehnlichkeiten: In diesem
/// Projekt ist genau daraus schon ein Fehler entstanden (`slotzustand` gab es
/// dreimal, und die abweichende Fassung war die falsche).
public struct EditorBereichView: View {
    @Bindable var zustand: AppZustand

    /// Der Arbeitsstand ueberlebt den Neustart.
    ///
    /// Derselbe Schluessel wie bisher (`bilder.arbeitsstand`) — er ist ein
    /// Dateiformat, und `Leinwand` traegt ihre Groesse selbst mit. Wer die App
    /// mit einem gemalten 52×16 verlaesst, findet es wieder; nur heisst der
    /// Bereich jetzt anders. Der noch aeltere Schluessel `malen.feld` (ein
    /// einzelnes Raster) wird weiter als Rueckfall gelesen.
    @State private var leinwand: Leinwand
    /// Rueckgaengig und Wiederherstellen. `@State`, nicht gesichert: Der Stapel
    /// ueberlebt den Programmlauf nicht.
    @State private var verlauf = Leinwandverlauf()

    /// Als "#RRGGBB" gesichert: @AppStorage kennt keine Color. Die Schluessel
    /// heissen weiter `malen.*` — sie sind ein Dateiformat, und wer sie
    /// umbenennt, wirft bei jeder laufenden Installation Farbe, Platzwahl und
    /// Dauer weg.
    @AppStorage("malen.farbe") private var farbeHex = "#00FF66"
    @AppStorage("malen.meldungsplatz") private var platz = 1
    @AppStorage("malen.dauer") private var dauerText = ""

    /// Der Bestand steht am Anfang, nicht die Werkzeuge: Wer den Editor
    /// oeffnet, will meist etwas Vorhandenes weiterbearbeiten, nicht auf einer
    /// leeren Flaeche beginnen. Erst waehlen, dann malen.
    @State private var modus = Inspektormodus.sichern
    @State private var zeigeInspektor = true
    @State private var radiert = false
    @State private var spielAb = false
    @State private var spielTask: Task<Void, Never>?
    @State private var laeuft = false
    /// Wie gross das naechste Laufbild wuerde. Gerechnet wird es abseits des
    /// Hauptthreads (siehe `.task(id:)` im `body`), deshalb ein Zustand und
    /// keine abgeleitete Groesse: GIF kodieren und Base64 darueber bei jedem
    /// Strich liesse das Malen stocken.
    @State private var laufbildBytes = 0
    @Environment(\.scenePhase) private var phase

    // Sichern und Bestand.
    @State private var name = ""
    @State private var nummer = ""
    @State private var suche = ""
    @State private var vorhandene: [Editoreintrag] = []
    @State private var meldung: String?
    @State private var lametricNummer = ""
    @State private var laedt = false

    // Rueckfragen.
    /// **Eine** Frage, vier Anlaesse — siehe `Rueckfrage`. Bis zum 14.09.2026
    /// lagen hier drei `.alert` nebeneinander, jeder mit eigenem Zustand.
    @State private var rueckfrage: Rueckfrage?
    @State private var zuLoeschen: Editoreintrag?

    /// „Oeffnen…": erst die Dateiauswahl, danach ein Blatt fuer Nummer
    /// und Namen mit dem Dateinamen als Vorschlag.
    ///
    /// Gemerkt wird der **Inhalt**, nicht die URL — warum, steht bei
    /// `dateiUebernehmen`.
    @State private var zeigeDateiImport = false
    @State private var zeigeImportBlatt = false
    @State private var importDaten: Data?
    @State private var importNummer = ""
    @State private var importName = ""
    /// Die Groesse, in der die gewaehlte Datei aufgenommen wird — **ihre
    /// eigene**, nicht die des Editors (`Editorbestand.zielgroesse(fuer:)`).
    /// Daran haengt auch, ob das Blatt nach einer Nummer fragt.
    @State private var importZiel: Leinwandgroesse?
    /// Was im Blatt steht, wenn das Einlesen nicht klappt. Im Blatt und nicht
    /// unter der Leinwand: Eine Meldung dahinter saehe niemand.
    @State private var importMeldung: String?
    /// Was das Blatt aufgenommen hat — abzuholen, **sobald es zu ist**
    /// (`blattGeschlossen`). `nil` heisst: abgebrochen.
    @State private var eingelesen: Editoreintrag?

    // Umbenennen. Ein eigenes Blatt, weil es dieselben zwei Felder braucht wie
    // der Import und dieselbe Frage stellt: Liegt dort schon etwas?
    @State private var zuBenennen: Editoreintrag?
    @State private var benennName = ""
    @State private var benennNummer = ""
    @State private var benennMeldung: String?

    static let arbeitsstandSchluessel = "bilder.arbeitsstand"

    public init(zustand: AppZustand) {
        self.zustand = zustand
        _leinwand = State(initialValue: Self.gelesenerArbeitsstand())
    }

    /// Was der Inspektor zeigt.
    enum Inspektormodus: String, CaseIterable, Identifiable {
        case malen, animation, sichern, zeit
        var id: String { rawValue }
    }

    /// **Eine Frage, vier Anlaesse.** Sie lautet immer gleich: Auf der Leinwand
    /// steht etwas, das nicht im Bestand liegt, und der naechste Schritt wuerde
    /// es verwerfen. Gestellt wird sie nur dann — `ungesichert` entscheidet
    /// das, und zwar fuer alle vier gleich.
    ///
    /// **Warum eine statt vier.** Bis zum 14.09.2026 lagen auf dieser Ansicht
    /// drei `.alert` und ein `.confirmationDialog` nebeneinander, jeder mit
    /// eigenem Zustand. Zwei Bedienelemente, die gleichzeitig aufgehen wollen,
    /// schliessen einander aus: SwiftUI zeigt einen davon und verschluckt den
    /// anderen stillschweigend — und es faellt nicht auf, weil beide fuer sich
    /// funktionieren. Ein einziger Zustand kann gar nicht erst zweierlei
    /// gleichzeitig meinen.
    enum Rueckfrage {
        /// „Neu" — Leinwand, Einzelbilder, Name und Nummer von vorn.
        case neu
        /// Ein Groessenwechsel. Umgerechnet wird zwischen den Groessen nichts.
        case groesse(Leinwandgroesse)
        /// Ein Stueck aus dem Bestand soll auf die Leinwand.
        case oeffnen(Editoreintrag)
        /// Ein eben geladenes Stueck — aus einer Datei oder von LaMetric. Es
        /// **liegt schon** im Bestand; zur Frage steht allein die Leinwand,
        /// und deshalb hat nur dieser Fall den dritten Weg.
        case geladen(Editoreintrag)

        var titel: String {
            switch self {
            case .neu: return lok("Neu anfangen?")
            case .groesse: return lok("Größe wechseln?")
            case .oeffnen, .geladen: return lok("Gemaltes ersetzen?")
            }
        }

        var text: String {
            switch self {
            case .neu, .oeffnen:
                return lok("Das Gemalte ist nicht gesichert und geht dabei verloren.")
            case .groesse:
                return lok("Zwischen den Größen wird nichts umgerechnet — das Gemalte geht dabei verloren. „Rückgängig“ holt es zurück.")
            case .geladen(let eintrag):
                return lokf("„%@“ liegt jetzt im Bestand. Auf die Leinwand kommt es nur, wenn es das Gemalte ersetzt — das ist nicht gesichert.",
                            eintrag.name)
            }
        }
    }

    // MARK: - Arbeitsstand

    /// Der gemerkte Arbeitsstand: erst der Schluessel mit der ganzen Leinwand,
    /// ersatzweise das einzelne Raster der Fassungen bis 13.09.2026, sonst
    /// eine leere Anzeige.
    private static func gelesenerArbeitsstand() -> Leinwand {
        let ablage = UserDefaults.standard
        if let daten = ablage.data(forKey: arbeitsstandSchluessel),
           let gelesen = try? JSONDecoder().decode(Leinwand.self, from: daten),
           Leinwandgroesse.fuer(gelesen) != nil {
            return gelesen
        }
        if let daten = ablage.data(forKey: "malen.feld"),
           let punkte = try? JSONDecoder().decode([String?].self, from: daten),
           let alt = Leinwand(breite: Pixelfeld.breiteStandard, hoehe: Pixelfeld.hoeheStandard,
                              bilder: [punkte]) {
            return alt
        }
        return Leinwandgroesse.anzeige.leereLeinwand
    }

    /// Nicht bei jedem einzelnen Pixel waehrend des Ziehens — das waeren
    /// hunderte Schreibvorgaenge je Strich —, sondern beim Loslassen, beim
    /// Verlassen der Ansicht und beim Beenden des Programms.
    private func arbeitsstandSichern() {
        guard let daten = try? JSONEncoder().encode(leinwand) else { return }
        UserDefaults.standard.set(daten, forKey: Self.arbeitsstandSchluessel)
    }

    // MARK: - Abgeleitetes

    /// Die Groesse kommt von der Leinwand, nicht aus einem zweiten Gedaechtnis
    /// daneben — zwei Quellen fuer dieselbe Angabe koennten auseinanderlaufen.
    private var groesse: Leinwandgroesse { Leinwandgroesse.fuer(leinwand) ?? .anzeige }

    private var bestand: Editorbestand { .eigene }

    /// Was sich in die gerade eingestellte Leinwand setzen laesst: kleinere
    /// Icons aus dem schon gelesenen Bestand, nie Groesseres.
    private var einfuegbare: [Editoreintrag] {
        vorhandene.filter { groesse.aufnehmbar.contains($0.groesse) }
    }

    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    /// Unter welchem Schluessel gesichert wird — bei 8×8 die Nummer, sonst der
    /// Name. Leer heisst: „Sichern" bleibt gesperrt.
    ///
    /// `nummerIstDateiname`, nicht `mitNummer`: Ein 16×52 hat seit dem
    /// 14.09.2026 eine Werknummer, heisst aber weiter nach seinem Namen — mit
    /// `mitNummer` liesse es sich ohne Nummer gar nicht mehr sichern.
    private var schluessel: String {
        Editorbestand.schluessel(groesse: groesse, nummer: nummer, name: name)
    }

    /// Ob dieser Eintrag gerade **der** auf der Leinwand ist. Verglichen wird
    /// der Schluessel, unter dem er liegt, mit dem, unter dem ein „Sichern"
    /// jetzt ablegen wuerde — nicht Name gegen Name: Bei 16×52 ist der
    /// Dateiname der bereinigte Name („Mario/Luigi" liegt als „Mario-Luigi"),
    /// und ein Vergleich der Namen ginge dort daneben.
    ///
    /// Zwei Handlungen haengen daran, und sie ziehen entgegengesetzte
    /// Schluesse: Beim **Loeschen** verliert die Leinwand ihren Bezug (Name
    /// und Nummer werden geleert, sonst legte das naechste „Sichern" das
    /// Geloeschte wieder an), beim **Umbenennen** zieht er mit.
    private func istGeoeffnet(_ eintrag: Editoreintrag) -> Bool {
        !schluessel.isEmpty && eintrag.groesse == groesse
            && eintrag.schluessel.caseInsensitiveCompare(schluessel) == .orderedSame
    }

    /// **Ob auf der Leinwand etwas steht, das nirgends liegt.** Die eine Frage
    /// vor allem, was sie verwirft — „Neu", ein Groessenwechsel, ein
    /// geoeffnetes Bild, ein geladenes Icon.
    ///
    /// Gerechnet wird sie im Kern (`Leinwandverlauf.weichtAb`), wo auch der
    /// gesicherte Stand liegt. Bis zum 14.09.2026 stand hier `istLeer`, und
    /// das war zweimal falsch: Eine gemalte, nie gesicherte Zeichnung ist
    /// nicht leer — gefragt wurde trotzdem nicht, wenn nur Name oder Nummer
    /// leer waren; und ein eben geoeffnetes Bild ist nicht ungesichert —
    /// gefragt wurde trotzdem.
    ///
    /// Name und Nummer zaehlen dabei **nicht** mit. Sie stehen in keiner
    /// Datei, solange nicht gesichert wurde, und ein Name ohne Zeichnung ist
    /// in zwei Anschlaegen wieder eingetippt.
    private var ungesichert: Bool { verlauf.weichtAb(leinwand) }

    /// Das gerade bearbeitete Bild als Pixelfeld — fuer die Rechteckzahl und
    /// fuer die Sendung eines unbewegten Bildes.
    private var feld: Pixelfeld {
        Pixelfeld(breite: leinwand.breite, hoehe: leinwand.hoehe, punkte: leinwand.bild)
            ?? Pixelfeld()
    }

    /// Belegt ist ein Platz, wenn irgendeine der Zieluhren ihn schon kennt.
    /// Dieselbe Grundlage wie unter „Senden" und „Verlauf": was die Uhr
    /// meldet, sonst was die App sich gemerkt hat.
    /// Woran die Nutzlast des Laufbilds haengt: die Einzelbilder und ihre
    /// Standzeit — **nicht** die Auswahl. Zwischen den Bildern zu blaettern
    /// aendert an dem, was hinausginge, nichts, soll die Rechnung also auch
    /// nicht noch einmal anstossen.
    private struct Laufbildstand: Equatable {
        let bilder: [[String?]]
        let verzoegerung: Double
    }

    private var laufbildstand: Laufbildstand {
        Laufbildstand(bilder: leinwand.bilder, verzoegerung: leinwand.verzoegerung)
    }

    private var belegtePlaetze: Set<Int> {
        let namen = Set(zustand.ziele().flatMap { zustand.anzeigenAufUhr($0.id) })
        return Set((1...Meldungsplatz.anzahl).filter { namen.contains(Meldungsplatz.name(fuer: $0)) })
    }

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann in der
    /// Nutzlast.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    // MARK: - Aufbau

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // **Dieselbe Stelle wie unter „Senden"**: oben rechts ueber der
            // Leinwand, nicht unten in der Sendezeile. Dort stand sie bis zum
            // 14.09.2026 zwischen Dauerfeld, Zwischenraum und Sendeknopf — bei
            // wenig Platz gequetscht und abgeschnitten, und vor allem an einer
            // anderen Stelle als in der Ansicht daneben. Zwei Orte fuer
            // dieselbe Wahl sind schlimmer als ein unguenstiger.
            //
            // Ohne zweite Uhr zeigt `ZielauswahlView` nichts, die Zeile bleibt
            // dann leer.
            HStack {
                Spacer()
                AngeseheneUhrView(zustand: zustand)
                ZielauswahlView(zustand: zustand)
            }
            Malflaeche(leinwand: $leinwand, farbe: farbe.wrappedValue, radiert: radiert,
                       vorStrich: { verlauf.merken(leinwand) },
                       nachStrich: arbeitsstandSichern)
            fusszeile
            if groesse.sendbar { sendezeile }
        }
        .padding()
        .toolbar { werkzeugleiste }
        .inspector(isPresented: $zeigeInspektor) { inspektor }
        .onAppear { vorhandene = bestand.alle() }
        .onDisappear { stoppeAbspielen(); arbeitsstandSichern() }
        // ⌘Q verlaesst diese Ansicht nicht — ohne dieses Netz ginge ein eben
        // erst gemalter, noch ungesicherter Strich verloren. `scenePhase` statt
        // `willTerminate`: Auf dem iPad gibt es dazu nichts Gleichwertiges.
        .onChange(of: phase) { _, neu in
            if neu != .active { arbeitsstandSichern() }
        }
        // Dieselbe Rechnung wie in `senden()` — die Zahl soll die sein, die
        // wirklich hinausginge. Abseits des Hauptthreads und nur bei
        // tatsaechlicher Aenderung, wie die Laufschrift unter „Senden".
        .task(id: laufbildstand) {
            guard groesse.sendbar, leinwand.bilder.count > 1 else { laufbildBytes = 0; return }
            let (bilder, breite, hoehe) = (leinwand.bilder, leinwand.breite, leinwand.hoehe)
            let verzoegerung = leinwand.verzoegerung
            let bytes = await Task.detached(priority: .userInitiated) {
                ((try? Bildraster.alsDatenURI(bilder, breite: breite, hoehe: hoehe,
                                              verzoegerung: verzoegerung)) ?? "").utf8.count
            }.value
            guard !Task.isCancelled else { return }
            laufbildBytes = bytes
        }
        // `onDismiss` und nicht unmittelbar in `einlesen()`: Eine Rueckfrage,
        // die im selben Durchlauf aufgeht, in dem das Blatt zugeht,
        // verschluckt SwiftUI — der Knopf haette dann nichts getan.
        .sheet(isPresented: $zeigeImportBlatt, onDismiss: blattGeschlossen) { importBlatt }
        // Zwei Blaetter an derselben Ansicht, aber nie zwei zugleich: Der
        // Stift steht in der Liste, und die liegt hinter dem Importblatt.
        .sheet(item: $zuBenennen) { umbenennenBlatt($0) }
        // Die **eine** Rueckfrage vor allem, was Ungesichertes verwirft
        // (siehe `Rueckfrage`). `titleVisibility: .visible`, weil hier die
        // Frage im Titel steht und nicht bloss ein Name.
        .confirmationDialog(
            Text(rueckfrage?.titel ?? ""),
            isPresented: Binding(get: { rueckfrage != nil }, set: { if !$0 { rueckfrage = nil } }),
            titleVisibility: .visible,
            presenting: rueckfrage
        ) { frage in
            switch frage {
            case .neu:
                Button("Neu anfangen", role: .destructive) { neu() }
            case .groesse(let neue):
                Button("Wechseln", role: .destructive) { groesseSetzen(neue) }
            case .oeffnen(let eintrag):
                Button("Öffnen", role: .destructive) { oeffnen(eintrag) }
            case .geladen(let eintrag):
                Button("Ersetzen", role: .destructive) { aufDieLeinwand(eintrag) }
                // Der zweite Weg, den es nur hier gibt: Das Stueck liegt schon
                // im Bestand, die Leinwand bleibt stehen.
                Button("Nur in den Bestand") { imBestandLassen(eintrag) }
            }
            // Fuer alle vier: Eine Rueckfrage ohne Ausweg ist keine.
            Button("Abbrechen", role: .cancel) {}
        } message: { frage in
            Text(frage.text)
        }
        // `Text(lokf(...))` statt eines eingesetzten Wertes im Schluessel: Eine
        // `LocalizedStringKey` mit Interpolation traegt zur Laufzeit den
        // Schluessel „%@ löschen?", im Quelltext steht aber der interpolierte
        // Ausdruck — `scripts/texte-sammeln.py` sieht ihn nicht, und der
        // Titel bliebe still deutsch. (So war es in beiden Vorgaengerbereichen.)
        .confirmationDialog(
            Text(lokf("„%@“ löschen?", zuLoeschen?.name ?? "")),
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            presenting: zuLoeschen
        ) { eintrag in
            Button("Löschen", role: .destructive) { loeschen(eintrag) }
        } message: { eintrag in
            Text(lokf("„%@“ wird endgültig entfernt.", eintrag.name))
        }
    }

    /// Was unter der Leinwand steht: die Rechteckzahl (nur da, wo sie etwas
    /// besagt — sie zaehlt die Befehle der naechsten Sendung) und die Meldung
    /// der letzten Handlung.
    @ViewBuilder
    private var fusszeile: some View {
        if groesse.sendbar {
            Text(lokf("%d Rechtecke — waagrechte Läufe gleicher Farbe werden zusammengefasst.",
                      feld.alsDrawBefehle().count))
                .font(.footnote).foregroundStyle(.secondary)
        }
        if let meldung {
            Text(meldung).font(.callout).foregroundStyle(.secondary)
        }
    }

    // MARK: - Werkzeugleiste

    /// Rueckgaengig, Wiederherstellen und der Schalter fuer den Inspektor —
    /// **drei** Symbole, nicht vier plus eine Segmentleiste.
    ///
    /// Die Modi standen bis 13.09.2026 hier mit drin und haben am iPad den
    /// Knopf „Seitenleiste schliessen" ueberdeckt; „Rueckgaengig" fiel dabei
    /// ganz aus der Leiste. Der Unterschied zum Mac ist nicht das Zeichnen,
    /// sondern **wem die Leiste gehoert**: Am Mac ist es die Werkzeugleiste
    /// des **Fensters** — mindestens 1140 Punkte breit, der Titel steht
    /// woanders, und was nicht mehr hineinpasst, wandert in ein
    /// Ueberlaufmenue. Am iPad ist es die Navigationsleiste der
    /// **Detailspalte**: Fenster minus Seitenleiste minus Inspektor, also im
    /// Hochformat und in geteilter Ansicht nur ein paar hundert Punkte, mit
    /// dem Seitenleistenknopf links und dem Titel in der Mitte. Sie laeuft
    /// nicht ueber, sie schiebt uebereinander — und die Segmentleiste war
    /// mit Abstand das breiteste Stueck darin.
    ///
    /// Die Modi sitzen deshalb jetzt in `modusWahl`, am Kopf des Inspektors.
    /// Das ist nicht der Notausgang, sondern die Vorlage: Numbers haelt genau
    /// **eine** Kapsel mit Symbolen (Rueckgaengig, Teilen, Mitarbeit) und
    /// darunter eine Segmentwahl fuer den Bereich des Inspektors.
    @ToolbarContentBuilder
    private var werkzeugleiste: some ToolbarContent {
        ToolbarItemGroup {
            Button { rueckgaengig() } label: { Label(lok("Rückgängig"), systemImage: "arrow.uturn.backward") }
                .namensichtbarAmIPad()
                .disabled(!verlauf.kannZurueck)
                .help(lok("Rückgängig"))
                .accessibilityLabel("Rückgängig")
            Button { wiederherstellen() } label: { Label(lok("Wiederherstellen"), systemImage: "arrow.uturn.forward") }
                .namensichtbarAmIPad()
                .disabled(!verlauf.kannVor)
                .help(lok("Wiederherstellen"))
                .accessibilityLabel("Wiederherstellen")
            Button { zeigeInspektor.toggle() } label: { Label(lok("Inspektor ein- oder ausblenden"), systemImage: "sidebar.trailing") }
                .namensichtbarAmIPad()
                .help(lok("Inspektor ein- oder ausblenden"))
                .accessibilityLabel("Inspektor ein- oder ausblenden")
        }
    }

    // MARK: - Inspektor

    /// `Form` mit `.formStyle(.grouped)` — dieselbe Bauart wie der
    /// Formatinspektor unter „Senden": abgesetzte Karten mit kleiner, grauer
    /// Ueberschrift, Ausrichtung und Zeilenabstand von selbst, und Rollen bei
    /// Bedarf ebenso.
    private var inspektor: some View {
        VStack(spacing: 0) {
            modusWahl
            Divider()
            Form {
                switch modus {
                case .malen: malenAbschnitte
                case .animation: animationAbschnitte
                case .sichern: sichernAbschnitte
                case .zeit: Zeitabschnitte(zustand: zustand, dauerText: $dauerText)
                }
            }
            .formStyle(.grouped)
        }
        // Wie unter „Senden": feste Breite am Mac, nachgebend auf dem iPad —
        // dort bleiben im ungünstigsten Fall 678 Punkte für Mitte und
        // Inspektor zusammen.
        #if os(macOS)
        .inspectorColumnWidth(330)
        #else
        .inspectorColumnWidth(min: 240, ideal: 330, max: 400)
        #endif
    }

    /// Die zweite Ebene der Vorlage: eine Segmentwahl fuer den Bereich, am Kopf
    /// des Inspektors und nicht in der Werkzeugleiste (warum, steht dort).
    ///
    /// **Woerter statt Symbolen.** In der Leiste war Platz nur fuer drei
    /// Zeichen, und `tray.and.arrow.down` fuer „Bestand" hat niemand geraten.
    /// Hier ist die Spalte mindestens 240 Punkte breit — Numbers beschriftet
    /// seine Segmentwahl aus demselben Grund („Tabelle · Zelle · Format ·
    /// Anordnen") und haelt die Symbole der Kapsel vor.
    ///
    /// Ist der Inspektor ausgeblendet, ist auch die Wahl weg. Das ist richtig
    /// und kein Verlust: Sie sagt, was **er** zeigt, und der Knopf, der ihn
    /// zurueckholt, steht in der Leiste.
    private var modusWahl: some View {
        // `.tag` ganz aussen: Ein Kennzeichen, das noch ein Modifikator
        // umhuellt, findet die Auswahl nicht mehr verlaesslich — und ein
        // Segmentschalter, dessen Wahl ins Leere greift, faellt beim
        // Uebersetzen nicht auf.
        // **Symbole statt Woerter.** Vier Reiter mit ausgeschriebenen Namen
        // passen in einen Segmentschalter von 330 Punkten nicht mehr, ohne
        // dass die Namen abgeschnitten werden — und ein abgeschnittenes Wort
        // sagt weniger als ein Bild. Die Namen gehen dabei nicht verloren: Sie
        // stehen als `accessibilityLabel` an jedem Segment, so wie es die
        // Ausrichtungswaehler in `SendenView` seit je halten.
        Picker("Inspektor", selection: $modus) {
            Image(systemName: "paintpalette").tag(Inspektormodus.malen)
                .accessibilityLabel(Text("Malen"))
            Image(systemName: "film").tag(Inspektormodus.animation)
                .accessibilityLabel(Text("Animation"))
            Image(systemName: "folder").tag(Inspektormodus.sichern)
                .accessibilityLabel(Text("Bestand"))
            Image(systemName: "clock").tag(Inspektormodus.zeit)
                .accessibilityLabel(Text("Zeit"))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var malenAbschnitte: some View {
        Section("Größe") {
            Picker("Größe", selection: Binding(get: { groesse }, set: { groesseWechseln($0) })) {
                Text("8 × 8").tag(Leinwandgroesse.icon8)
                Text("16 × 16").tag(Leinwandgroesse.icon16)
                Text("16 × 52").tag(Leinwandgroesse.anzeige)
            }
            .pickerStyle(.segmented).labelsHidden()
        }

        Section("Werkzeug") {
            ColorPicker("Farbe", selection: farbe)
            // Blank: Die `Form` setzt „Stift" links, der Segmentschalter
            // steht rechts. Die Umwicklung brachte nichts, was das System
            // nicht selbst tut.
            Picker("Stift", selection: $radiert) {
                Image(systemName: "paintbrush.pointed")
                    .accessibilityLabel("Malen").tag(false)
                Image(systemName: "eraser")
                    .accessibilityLabel("Radieren").tag(true)
            }
            .pickerStyle(.segmented)
            Button("Alles löschen", role: .destructive) { schritt(); leinwand.bildLeeren(); arbeitsstandSichern() }
                .knopfZerstoerend()
        }

        Section {
            LabeledContent("Verschieben") { pfeilkreuz }
        } footer: {
            Text("Was am Rand hinausgeschoben wird, kommt gegenüber wieder herein.")
        }

        if groesse.iconEinfuegbar {
            Section("Icon einfügen") {
                // Ein Befehl mit Auswahl, keine Wertzeile: Es bleibt danach
                // nichts „gewaehlt" stehen, das Icon wird eingefuegt.
                // Deshalb die Fassung eines Befehlsknopfs — `menuStyle(.button)`
                // schickt das Menue ueberhaupt erst durch einen Knopfstil.
                //
                // Nach Groesse gegliedert: Bei 16×52 stehen beide Icongroessen
                // zur Wahl, und welche man nimmt, entscheidet, wie viel Platz
                // daneben bleibt. Eine Liste, in der sie durcheinanderstehen,
                // machte das Merkmal zur Suchaufgabe.
                Menu("Icon wählen…") {
                    ForEach(groesse.aufnehmbar) { quelle in
                        Section(lok(quelle.beschriftung)) {
                            ForEach(einfuegbare.filter { $0.groesse == quelle }) { eintrag in
                                Button(eintrag.name) { iconEinfuegen(eintrag) }
                            }
                        }
                    }
                }
                .menuStyle(.button)
                .knopfBefehl()
                .disabled(einfuegbare.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var animationAbschnitte: some View {
        Section("Einzelbilder") {
            einzelbildstreifen
            Button("Bild anhängen") { schritt(); leinwand.anhaengen(); arbeitsstandSichern() }
                .knopfBefehl()
        }

        Section {
            LabeledContent("Verzögerung") {
                HStack(spacing: 6) {
                    TextField("", value: $leinwand.verzoegerung, format: .number)
                        .eingabefeld()
                        .frame(width: 60)
                    Text("s").foregroundStyle(.secondary)
                    abspielknopf
                }
            }
        } header: {
            Text("Abspielen")
        } footer: {
            Text("Mehrere Einzelbilder ergeben beim Sichern ein animiertes GIF.")
        }
    }

    /// **B3.** Kein eigener Knopf „Abspielen" mehr, sondern ein Symbol
    /// unmittelbar rechts neben dem Sekundenwert — so verlangt. Die Zeit und
    /// das Probelaufen gehoeren zusammen; zwei Zeilen liessen es wie zweierlei
    /// aussehen.
    ///
    /// Der Knopf **schaltet um**, also muss er beides zeigen: `play.fill`,
    /// solange es steht, `stop.fill`, solange es laeuft. Ein Symbol allein
    /// sagt der Sprachausgabe nichts — die Beschriftung steht deshalb in
    /// **beiden** Zustaenden da, und weil sie durch ein Ternaer kommt, ist
    /// jeder Zweig schon uebersetzt (`lok`), bevor SwiftUI ihn sieht: Ein
    /// Ternaer mit `String`-Zweig schlaegt selbst nichts mehr nach.
    private var abspielknopf: some View {
        Button { abspielenUmschalten() } label: {
            Label(spielAb ? lok("Stopp") : lok("Abspielen"), systemImage: spielAb ? "stop.fill" : "play.fill")
        }
        .namensichtbarAmIPad()
        .knopfBefehl()
        .disabled(leinwand.bilder.count < 2)
        .help(spielAb ? lok("Stopp") : lok("Abspielen"))
        .accessibilityLabel(Text(spielAb ? lok("Stopp") : lok("Abspielen")))
    }

    @ViewBuilder
    private var sichernAbschnitte: some View {
        Section {
            LabeledContent("Name") {
                TextField("Name", text: $name).labelsHidden().eingabefeld()
            }
            if groesse.mitNummer {
                LabeledContent("Nummer") {
                    TextField("Nummer", text: $nummer)
                        .labelsHidden()
                        .eingabefeld()
                        .help(groesse.nummerIstDateiname
                              ? lok("Die LaMetric-Nummer — zugleich der Dateiname.")
                              : lok("Die Ulanzi-Werknummer, falls es eine gibt — sie merkt sich nur, woher das Bild stammt."))
                }
            }
            // Der ausdrueckliche Knopfstil ist hier **kein Aussehen, sondern
            // die Trefferflaeche.** Eine Zeile einer `Form` ist selbst das
            // Bedienelement: Ein Knopf mit dem vorgegebenen Stil bekommt
            // darin die Flaeche der **ganzen Zeile**. Stehen zwei darin,
            // teilen sie sich dieselbe — ein Druck auf „Sichern" landete bei
            // „Neu". Und weil eine Zeile antippbar bleibt, auch wenn der
            // Knopf darin gesperrt ist, traf es bei noch leerer Nummer
            // zwangslaeufig „Neu", also den zerstoerenden von beiden.
            // Derselbe Grund wie beim Einzelbildstreifen und in der
            // Bestandszeile, wo der Stil deshalb schon steht.
            //
            // „Sichern" ist die **eine** Haupthandlung des Editors. Ohne Namen
            // bleibt es sichtbar abgeblendet stehen statt zu verschwinden —
            // wie „Verbinden …" neben „Fertig" in der Vorlage.
            HStack {
                Button("Sichern") { sichern() }
                    .knopfHaupthandlung()
                    .keyboardShortcut(.defaultAction)
                    .disabled(schluessel.isEmpty)
                Button("Neu") { neuAnfragen() }
                    .knopfBefehl()
            }
        } header: {
            Text("Diese Bildgruppe")
        } footer: {
            Text(groesse.nummerIstDateiname
                 ? lok("Die Nummer ist der Dateiname und zugleich die LaMetric-Nummer — sie muss eindeutig sein.")
                 : lok("Der Name ist zugleich der Dateiname — derselbe Name ersetzt das Vorhandene."))
        }

        // Was hier steht, sind Handlungen am **Bestand**, nicht an der
        // Leinwand: Ein geholtes LaMetric-Icon ist immer ein 8×8 im
        // 8×8-Bestand, gleich was gerade auf dem Tisch liegt. Bis zum
        // 13.09.2026 hing der ganze Abschnitt an `groesse.mitNummer` — wer
        // auf 16×16 stand, fand die LaMetric-Wahl nicht mehr und konnte
        // nicht erraten, warum.
        Section("Hinzufügen") {
            // Beschriftung links, gefasstes Feld rechts — wie „Zeilen 18" bei
            // Numbers. Bis 13.09.2026 stand „Nachladen" mit im rechten Teil
            // der Zeile; Feld und Knopf zusammen waren breiter als die
            // Inspektorspalte, SwiftUI stapelte sie deshalb **unter** die
            // Beschriftung, und die stand dann allein da wie eine
            // Ueberschrift. Der Knopf hat jetzt seine eigene Zeile.
            LabeledContent("LaMetric-Nummer") {
                TextField("Nummer", text: $lametricNummer)
                    .labelsHidden()
                    .eingabefeld()
                    .frame(width: 90)
                    .onSubmit { nachladen() }
            }
            Button(laedt ? lok("Hole…") : lok("Nachladen")) { nachladen() }
                .knopfBefehl()
                .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
            Link("LaMetric Icon Gallery", destination: URL(string: "https://developer.lametric.com/icons")!)
                .font(.caption)
            Button("Öffnen…") { zeigeDateiImport = true }
                .knopfBefehl()
                .fileImporter(isPresented: $zeigeDateiImport,
                              allowedContentTypes: [.gif, .png, .jpeg]) { ergebnis in
                    switch ergebnis {
                    case .success(let url): dateiUebernehmen(url)
                    // Bis 13.09.2026 stand hier `guard case .success … else
                    // { return }`: Wer eine Datei waehlte und scheiterte, sah
                    // nichts geschehen und konnte nicht wissen, woran es lag.
                    case .failure(let fehler):
                        zustand.fehler = lokf("Die Datei ließ sich nicht öffnen: %@",
                                              fehler.localizedDescription)
                    }
                }
            Button("Grundschatz wiederherstellen") { grundschatzWiederherstellen() }
                .knopfBefehl()
        }

        Section("Vorhandene") {
            TextField("Suchen", text: $suche)
                .eingabefeld()
            // Gesucht wird in der schon gelesenen Liste (`vorhandene`), nicht
            // bei jedem Tastendruck neu im Dateisystem.
            ForEach(vorhandene.gefiltert(nach: suche)) { eintrag in
                bestandszeile(eintrag)
            }
        }
    }

    /// Vier Pfeile um einen Mittelpunkt — schiebt die ganze Grafik um ein
    /// Pixel. Ein Kreuz und keine vier Knoepfe in einer Reihe: Richtung ist
    /// raeumlich, und in einer Reihe muesste man jedes Symbol einzeln lesen.
    private var pfeilkreuz: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.up", name: lok("Nach oben schieben"), dx: 0, dy: -1)
                Color.clear.frame(width: 1, height: 1)
            }
            GridRow {
                pfeil("arrow.left", name: lok("Nach links schieben"), dx: -1, dy: 0)
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.right", name: lok("Nach rechts schieben"), dx: 1, dy: 0)
            }
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.down", name: lok("Nach unten schieben"), dx: 0, dy: 1)
                Color.clear.frame(width: 1, height: 1)
            }
        }
    }

    /// Der Name kommt als `lok(...)`-Aufruf beim Aufrufer an, nicht als
    /// literale Zeichenkette in dieser Funktion — sonst saehe
    /// `scripts/texte-sammeln.py` ihn nicht mehr: Was in einer Variablen
    /// steht, bevor es angezeigt wird, findet der Sammler nicht. Der Name
    /// dient gleich dreifach: Beschriftung fuer VoiceOver, Einblendtext am
    /// Mac (`namensichtbarAmIPad()` blendet ihn dort aus) und sichtbarer Name
    /// am iPad, wo es kein Verweilen gibt.
    private func pfeil(_ symbol: String, name: String, dx: Int, dy: Int) -> some View {
        Button {
            schritt()
            leinwand.verschieben(dx: dx, dy: dy)
            arbeitsstandSichern()
        } label: {
            Label(name, systemImage: symbol).frame(width: 18, height: 18)
        }
        .namensichtbarAmIPad()
        .knopfBefehl()
        .help(name)
        .accessibilityLabel(name)
    }

    /// Die Leiste der Einzelbilder. „Verdoppeln" und „Entfernen" stehen **am
    /// Bild, auf das sie wirken** — beim gewaehlten unter seinem Vorschaubild
    /// und bei jedem im Kontextmenue; in einer gemeinsamen Zeile darunter war
    /// nicht zu sehen, welches Bild gemeint ist.
    private var einzelbildstreifen: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(leinwand.bilder.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        bildVorschau(i)
                        if leinwand.aktuell == i {
                            HStack(spacing: 2) {
                                Button {
                                    schritt(); leinwand.verdoppeln(); arbeitsstandSichern()
                                } label: {
                                    Image(systemName: "plus.square.on.square")
                                }
                                .knopfBefehl()
                                .help("Dieses Einzelbild verdoppeln")
                                .accessibilityLabel("Verdoppeln")
                                // Beim letzten Einzelbild gesperrt — sichtbar
                                // abgeblendet, nicht verschwunden.
                                Button(role: .destructive) {
                                    schritt(); leinwand.entfernen(); arbeitsstandSichern()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .knopfZerstoerend()
                                .disabled(leinwand.bilder.count <= 1)
                                .help("Dieses Einzelbild entfernen")
                                .accessibilityLabel("Entfernen")
                            }
                            .controlSize(.small)
                            .font(.caption)
                        }
                    }
                    .contextMenu {
                        Button("Verdoppeln") { schritt(); leinwand.waehlen(i); leinwand.verdoppeln(); arbeitsstandSichern() }
                        Button("Entfernen", role: .destructive) { schritt(); leinwand.waehlen(i); leinwand.entfernen(); arbeitsstandSichern() }
                            .disabled(leinwand.bilder.count <= 1)
                        Divider()
                        // Die Reihenfolge aendert die Animation und ist deshalb
                        // ein Schritt wie Anhaengen und Entfernen.
                        Button("Nach vorn") { schritt(); leinwand.waehlen(i); leinwand.tauschen(um: -1); arbeitsstandSichern() }
                            .disabled(i == 0)
                        Button("Nach hinten") { schritt(); leinwand.waehlen(i); leinwand.tauschen(um: 1); arbeitsstandSichern() }
                            .disabled(i == leinwand.bilder.count - 1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func bildVorschau(_ i: Int) -> some View {
        Canvas { kontext, groesse in
            let kante = groesse.width / Double(leinwand.breite)
            for y in 0..<leinwand.hoehe {
                for x in 0..<leinwand.breite {
                    let feld = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                      width: kante, height: kante)
                    let p = leinwand.bilder[i][y * leinwand.breite + x]
                    kontext.fill(Path(feld), with: .color(p.flatMap(Color.init(hex:)) ?? .black))
                }
            }
        }
        // Die Vorschau behaelt das Seitenverhaeltnis der Leinwand: bei 52×16
        // ist ein Quadrat nicht dasselbe Bild, sondern ein anderes.
        .frame(width: 34, height: 34 * Double(leinwand.hoehe) / Double(leinwand.breite))
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3)
            .stroke(leinwand.aktuell == i ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: leinwand.aktuell == i ? 2 : 1))
        // Ein Bild zu waehlen aendert nichts an der Zeichnung und ist deshalb
        // kein Schritt fuer „Rueckgaengig".
        .onTapGesture { stoppeAbspielen(); leinwand.waehlen(i) }
    }

    /// Eine Zeile der Liste der Vorhandenen — mit der Groesse als Merkmal, weil
    /// alle drei Bestaende in derselben Liste stehen.
    private func bestandszeile(_ eintrag: Editoreintrag) -> some View {
        HStack {
            // Alle drei Groessen in dasselbe Kaestchen von 44 × 24 Punkten
            // eingepasst — ohne Fallunterscheidung, damit eine vierte Groesse
            // hier nichts zu aendern haette. Ein 52×16 wird dabei breit und
            // flach, ein Quadrat quadratisch: Das ist das Bild, nicht ein
            // Fehler.
            Rasterbild(datei: eintrag.datei,
                       breite: eintrag.groesse.breite, hoehe: eintrag.groesse.hoehe,
                       kante: min(44 / Double(eintrag.groesse.breite),
                                  24 / Double(eintrag.groesse.hoehe)))
                .background(Color.black)
            VStack(alignment: .leading, spacing: 1) {
                Text(eintrag.name).lineLimit(1)
                // **Das Abspielzeichen neben die Groesse, nicht ins Bild.**
                // LaMetric und AWTRIX legen es durchscheinend ueber das
                // Vorschaubildchen; bei 8×8 verdeckt es damit ein Viertel des
                // Motivs, und gerade das Motiv soll man ja erkennen. In der
                // Beschriftungszeile kostet es nichts und steht bei den
                // uebrigen Angaben ueber die Datei.
                HStack(spacing: 4) {
                    Text(lok(eintrag.groesse.beschriftung) + (eintrag.nummer.map { " · \($0)" } ?? ""))
                    if Bildraster.bewegt(eintrag.datei) {
                        Image(systemName: "play.fill")
                            .accessibilityLabel(Text("bewegt"))
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // Derselbe Stil wie der Papierkorb daneben — gleiche Groesse,
            // gleiche Trefferflaeche —, aber **nicht gefaerbt und ohne
            // zerstoerende Rolle**: Umbenennen wirft nichts weg. Der Name
            // steht in beiden Beschriftungen, weil zwei gleiche Symbole
            // untereinander sonst nicht auseinanderzuhalten sind.
            Button { umbenennenBeginnen(eintrag) } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(lokf("„%@“ umbenennen", eintrag.name))
                .accessibilityLabel(Text(lokf("„%@“ umbenennen", eintrag.name)))
            Button { zuLoeschen = eintrag } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(lokf("„%@“ löschen", eintrag.name))
                .accessibilityLabel(Text(lokf("„%@“ löschen", eintrag.name)))
        }
        .contentShape(Rectangle())
        .onTapGesture { anklicken(eintrag) }
        .contextMenu {
            Button("Öffnen") { anklicken(eintrag) }
            Button("Umbenennen…") { umbenennenBeginnen(eintrag) }
            Button("Löschen", role: .destructive) { zuLoeschen = eintrag }
        }
    }

    // MARK: - Sendezeile

    /// Nur bei 16×52 — ein Icon ist fuer sich keine Anzeige.
    private var sendezeile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            // Dieselbe Zeile wie unter „Senden" (`Nutzlastzeile`), nicht eine
            // zweite daneben — hier ist die Gefahr sogar groesser: Ein
            // 16×52-Laufbild mit vielen Einzelbildern wird schnell gross.
            // Nur bei mehreren: Ein einzelnes Bild geht als `draw` hinaus und
            // ist klein; wie klein, sagt die Rechteckzahl in der Fusszeile.
            if leinwand.bilder.count > 1 {
                Nutzlastzeile(
                    art: lok("Animation"),
                    bilder: leinwand.bilder.count,
                    bytes: laufbildBytes,
                    rat: lok("nur weniger Einzelbilder machen sie kleiner, das Tempo ändert daran nichts."))
            }
            // Breit: Bloecke und Dauer nebeneinander. Schmal: die Dauer rueckt
            // darunter, statt dass die Zeile rechts abgeschnitten wird.
            // Nur noch Bloecke und Sendeknopf: Die Dauer steht im Zeit-Reiter
            // des Inspektors, die Zielauswahl oben. Was hier bleibt, passt
            // damit auch schmal in **eine** Zeile — das `ViewThatFits` von
            // vorher war die Folge einer ueberladenen Zeile, nicht ihre Kur.
            HStack(alignment: .bottom, spacing: 16) { sendeteile }
            if zustand.ziele().isEmpty {
                Text("Erst unter „Einstellungen“ eine Uhr eintragen und abfragen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var sendeteile: some View {
        HStack(spacing: 6) { slotBloecke }
        Spacer()
        sendeKnopf
    }

    /// Dieselben Bloecke wie unter „Senden", aus derselben Rechnung
    /// (`AppZustand.slotzustand`) — derselbe Platz derselben Uhr soll hier
    /// nicht etwas anderes zeigen. Antippen waehlt hier nur den Platz: Regler,
    /// die sich wiederherstellen liessen, gibt es beim Malen nicht.
    @ViewBuilder
    private var slotBloecke: some View {
        ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
            Button { platz = i } label: {
                Slotblock(platz: i,
                          zustand: zustand.slotzustand(i, belegt: belegtePlaetze.contains(i)),
                          gewaehlt: platz == i)
            }
            .buttonStyle(.plain)
            // Wie unter „Senden": das ⊗ ueber dem Block, den es betrifft.
            .overlay(alignment: .topTrailing) {
                MeldungLoeschenKnopf(zustand: zustand, platz: i,
                                     belegt: belegtePlaetze.contains(i))
                    .offset(x: 8, y: -8)
            }
        }
    }

    /// **Ohne `.defaultAction`** — die Eingabetaste gehoert „Sichern".
    ///
    /// Beide standen bis zum 14.09.2026 darauf, und welcher von zweien SwiftUI
    /// dann nimmt, ist nicht festgelegt. Genau so ein Gleichstand hat kurz
    /// zuvor „Sichern" das zerstoerende „Neu" ausloesen lassen.
    ///
    /// „Sichern" bekommt sie aus drei Gruenden: Es ist die **eine**
    /// Haupthandlung des Editors (`knopfHaupthandlung`, dieser hier ist ein
    /// Befehl unter mehreren). Es gibt es bei **jeder** Leinwandgroesse,
    /// diese Zeile nur bei 16×52 — eine Taste, die je nach Leinwand etwas
    /// anderes tut, waere schlimmer als keine. Und es steht in einem Formular
    /// mit Name und Nummer, wo die Eingabetaste ohnehin „uebernehmen" heisst,
    /// waehrend hier der irreversible Weg auf die Uhr begaenne.
    ///
    /// `lok` in beiden Zweigen: Ein Ternaer mit einem `String`-Zweig zwingt
    /// SwiftUI in die `StringProtocol`-Ueberladung, und die schlaegt nichts
    /// nach — der Eintrag staende in `en.lproj` und wuerde nie gefunden.
    private var sendeKnopf: some View {
        Button(laeuft ? lok("Sende…") : lok("Senden")) { senden() }
            .knopfBefehl()
            .disabled(laeuft || zustand.ziele().isEmpty || keineNimmtGemaltes)
            .help(keineNimmtGemaltes
                  ? lok("Ein gemaltes Bild nimmt nur die Werksfirmware an. Die AWTRIX hat acht Zeilen statt sechzehn — ein darauf gestauchtes Bild wäre nicht dasselbe Bild, und geschickt käme es als Stille zurück.")
                  : lok("Auf die Uhr senden"))
    }

    /// **Keine** der Zieluhren nimmt ein gemaltes Bild an — dann ist der Knopf
    /// gesperrt, statt ins Leere zu senden.
    ///
    /// Absichtlich „keine" und nicht „eine": Sind mehrere Uhren gewählt und ist
    /// nur eine davon eine AWTRIX, geht die Sendung an die übrigen und meldet
    /// für diese eine den Fehler — das ist mehr Auskunft als ein gesperrter
    /// Knopf, der auch die tauglichen Ziele mitsperrte. Ohne gewählte Uhr
    /// greift schon `zustand.ziele().isEmpty` davor.
    private var keineNimmtGemaltes: Bool {
        let ziele = zustand.ziele()
        return !ziele.isEmpty && !ziele.contains { $0.gattung.nimmtGemaltes }
    }

    // MARK: - Blatt „Oeffnen"

    /// **Eine** Ansicht fuer alle drei Groessen, nicht zwei Fassungen: Ob nach
    /// einer Nummer gefragt wird, leitet sich aus der Groesse **der Datei** ab
    /// — bei 16×16 und 16×52 gibt es keine.
    ///
    /// Gebaut wie der Inspektor: Beschriftung links, gefasstes Feld rechts,
    /// eine Karte mit Kopf und Fuss. Bis zum 13.09.2026 standen hier zwei
    /// nackte Felder unter einer kleinen grauen Ueberschrift, und **dass**
    /// LaMetric-Nummer und Titel gemeint waren, stand nirgends.
    private var importBlatt: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    if importMitNummer {
                        LabeledContent("LaMetric-Nummer") {
                            TextField("Nummer", text: $importNummer)
                                .labelsHidden()
                                .eingabefeld()
                                .frame(width: 100)
                        }
                    }
                    LabeledContent("Name") {
                        TextField("Name", text: $importName).labelsHidden().eingabefeld()
                    }
                } header: {
                    // Nach C1 nimmt die Datei ihre eigene Groesse mit; welche
                    // das ist, gehoert an den Kopf — der Eintrag landet sonst
                    // in einem Bestand, in dem niemand ihn sucht.
                    Text(lokf("Wird aufgenommen als %@", importZielname))
                } footer: {
                    Text(importNummerIstDateiname
                         ? lok("Die Nummer ist der Dateiname und zugleich die LaMetric-Nummer — sie muss eindeutig sein.")
                         : lok("Der Name ist zugleich der Dateiname — derselbe Name ersetzt das Vorhandene."))
                }

                // **Vor** dem Sichern, nicht danach: Wer eine vergebene Nummer
                // eintippt, ersetzt etwas — das soll er wissen, bevor er es
                // tut, und er soll sehen, was.
                if let vorhanden = importBelegt {
                    Label(lokf("„%@“ liegt dort schon und wird ersetzt.", vorhanden.name),
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let importMeldung {
                    Text(importMeldung).foregroundStyle(.orange)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Abbrechen") { zeigeImportBlatt = false }
                    .knopfBefehl()
                // Der Knopf sagt, was geschieht: „Ersetzen", wo etwas
                // ueberschrieben wird. `lok` in beiden Zweigen — ein Ternaer
                // mit `String`-Zweig schlaegt selbst nichts nach.
                Button(importBelegt == nil ? lok("Öffnen") : lok("Ersetzen")) { einlesen() }
                    .knopfHaupthandlung()
                    .keyboardShortcut(.defaultAction)
                    .disabled(importSchluessel.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 360)
    }

    /// Wonach das Blatt fragt, haengt an der Groesse **der Datei** — nicht an
    /// der des Editors. Bei 16×16 und 16×52 gibt es keine Nummer.
    private var importMitNummer: Bool { importZiel?.mitNummer ?? false }

    /// Und ob sie zugleich der Dateiname ist — nur beim 8×8. Davon haengt der
    /// Fuss des Blattes ab und nichts sonst: Ob ueberhaupt gefragt wird, sagt
    /// `importMitNummer`.
    private var importNummerIstDateiname: Bool { importZiel?.nummerIstDateiname ?? false }

    /// Wie die Groesse heisst, in der aufgenommen wird. Leer, solange keine
    /// Datei gewaehlt ist — dann steht auch das Blatt nicht.
    private var importZielname: String { importZiel.map { lok($0.beschriftung) } ?? "" }

    /// Der Eintrag, den ein Einlesen ersetzen wuerde. Gesucht wird in der
    /// schon gelesenen Liste, nicht bei jedem Tastendruck im Dateisystem.
    private var importBelegt: Editoreintrag? {
        guard let ziel = importZiel else { return nil }
        return Editorbestand.belegt(in: vorhandene, groesse: ziel,
                                    nummer: importNummer, name: importName)
    }

    private var importSchluessel: String {
        guard let ziel = importZiel else { return "" }
        return Editorbestand.schluessel(groesse: ziel,
                                        nummer: importNummer, name: importName)
    }

    // MARK: - Blatt „Umbenennen"

    /// Dieselben zwei Felder wie beim Import und dieselbe Frage davor: Liegt
    /// unter dem neuen Schluessel schon etwas? Nur der Kopf, der Knopf und die
    /// Handlung sind andere.
    ///
    /// Die Nummer steht da, wo es eine gibt (`mitNummer`) — beim 8×8 die
    /// LaMetric-Nummer, beim 16×52 die Ulanzi-Werknummer. Der Fuss sagt, was
    /// davon den Dateinamen traegt.
    private func umbenennenBlatt(_ eintrag: Editoreintrag) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    if eintrag.groesse.mitNummer {
                        LabeledContent("Nummer") {
                            TextField("Nummer", text: $benennNummer)
                                .labelsHidden()
                                .eingabefeld()
                                .frame(width: 100)
                        }
                    }
                    LabeledContent("Name") {
                        TextField("Name", text: $benennName).labelsHidden().eingabefeld()
                    }
                } header: {
                    Text(lokf("„%@“ umbenennen", eintrag.name))
                } footer: {
                    Text(eintrag.groesse.nummerIstDateiname
                         ? lok("Die Nummer ist der Dateiname und zugleich die LaMetric-Nummer — sie muss eindeutig sein.")
                         : lok("Der Name ist zugleich der Dateiname — derselbe Name ersetzt das Vorhandene."))
                }

                // Wie im Importblatt: **vor** dem Bestaetigen, und mit Namen.
                if let vorhanden = benennBelegt(eintrag) {
                    Label(lokf("„%@“ liegt dort schon und wird ersetzt.", vorhanden.name),
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let benennMeldung {
                    Text(benennMeldung).foregroundStyle(.orange)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Abbrechen") { zuBenennen = nil }
                    .knopfBefehl()
                Button(benennBelegt(eintrag) == nil ? lok("Umbenennen") : lok("Ersetzen")) {
                    umbenennen(eintrag)
                }
                .knopfHaupthandlung()
                .keyboardShortcut(.defaultAction)
                .disabled(benennSchluessel(eintrag).isEmpty
                          || benennName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 360)
    }

    /// Unter welchem Schluessel der Eintrag hinterher laege.
    private func benennSchluessel(_ eintrag: Editoreintrag) -> String {
        Editorbestand.schluessel(groesse: eintrag.groesse,
                                 nummer: benennNummer, name: benennName)
    }

    /// Was eine Umbenennung ersetzen wuerde — **er selbst zaehlt nicht**: Wer
    /// nur die Nummer aendert, ersetzt nichts, und eine Warnung darueber waere
    /// genau die, die man kuenftig wegklickt.
    private func benennBelegt(_ eintrag: Editoreintrag) -> Editoreintrag? {
        let treffer = Editorbestand.belegt(in: vorhandene, groesse: eintrag.groesse,
                                           nummer: benennNummer, name: benennName)
        return treffer?.id == eintrag.id ? nil : treffer
    }

    // MARK: - Rueckgaengig

    /// Vor jeder Aenderung, die ein Schritt ist. Ein Strich ruft es ueber
    /// `Malflaeche.vorStrich` einmal je Strich, nicht je Pixel.
    private func schritt() { verlauf.merken(leinwand) }

    private func rueckgaengig() {
        guard let vorheriger = verlauf.zurueck(von: leinwand) else { return }
        stoppeAbspielen()
        leinwand = vorheriger
        arbeitsstandSichern()
    }

    private func wiederherstellen() {
        guard let naechster = verlauf.vor(von: leinwand) else { return }
        stoppeAbspielen()
        leinwand = naechster
        arbeitsstandSichern()
    }

    // MARK: - Handlungen

    private func groesseWechseln(_ neue: Leinwandgroesse) {
        guard neue != groesse else { return }
        if ungesichert { rueckfrage = .groesse(neue) } else { groesseSetzen(neue) }
    }

    /// Umgerechnet wird zwischen den Groessen **nichts**. Der Wechsel ist ein
    /// Schritt — „Rueckgaengig" holt die verworfene Leinwand samt ihrer Groesse
    /// zurueck, weil `Leinwand` sie selbst traegt.
    private func groesseSetzen(_ neue: Leinwandgroesse) {
        schritt()
        stoppeAbspielen()
        leinwand = neue.leereLeinwand
        nummer = ""
        name = ""
        meldung = nil
        // Der Verlauf bleibt — „Rueckgaengig" holt die verworfene Leinwand samt
        // ihrer Groesse zurueck. Der gesicherte Stand nicht: Was jetzt auf dem
        // Tisch liegt, ist eine leere Flaeche und liegt in keinem Bestand.
        verlauf.gesichertMerken(nil)
        arbeitsstandSichern()
    }

    private func neuAnfragen() {
        if ungesichert { rueckfrage = .neu } else { neu() }
    }

    /// Von vorn — Leinwand, Einzelbilder, Verzoegerung, Name und Nummer. Der
    /// Verlauf faellt dabei weg: Von einem leeren Blatt aus fuehrt kein Weg
    /// zurueck zu dem, was nicht mehr da ist.
    private func neu() {
        stoppeAbspielen()
        verlauf.leeren()
        leinwand = groesse.leereLeinwand
        nummer = ""
        name = ""
        meldung = nil
        arbeitsstandSichern()
    }

    private func anklicken(_ eintrag: Editoreintrag) {
        if ungesichert { rueckfrage = .oeffnen(eintrag) } else { oeffnen(eintrag) }
    }

    /// Holt einen Eintrag des Bestands auf die Leinwand. `meldung` sagt, was
    /// darunter steht — gesetzt vom Aufrufer nur dort, wo mehr geschehen ist
    /// als ein Oeffnen (`aufDieLeinwand`).
    ///
    /// Der Rueckgabewert sagt, ob es geklappt hat: Ein Aufrufer, der hinterher
    /// etwas meldet, darf einen Fehlschlag nicht mit einer Erfolgsmeldung
    /// ueberschreiben.
    @discardableResult
    private func oeffnen(_ eintrag: Editoreintrag, meldung text: String? = nil) -> Bool {
        do {
            // Schwarz bleibt Schwarz: Beim Sichern wird „aus“ zu Schwarz, weil
            // GIF hier keine Durchsichtigkeit traegt — nach einem Rundlauf sind
            // beide dasselbe und nicht mehr auseinanderzuhalten.
            let neue = try bestand.oeffnen(eintrag)
            stoppeAbspielen()
            verlauf.leeren()
            leinwand = neue
            // Was jetzt auf der Leinwand steht, liegt genau so im Bestand: von
            // hier an weicht nichts ab, bis jemand etwas malt.
            verlauf.gesichertMerken(neue)
            nummer = eintrag.nummer ?? ""
            name = eintrag.name
            arbeitsstandSichern()
            meldung = text ?? (neue.bilder.count > 1
                ? lokf("%@ geöffnet (%d Bilder).", eintrag.name, neue.bilder.count)
                : lokf("%@ geöffnet.", eintrag.name))
            return true
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return false
        }
    }

    /// **Ein geladenes Stueck kommt auf die Leinwand** — aus einer Datei wie
    /// von LaMetric. Im Bestand liegt es da schon; steht auf der Leinwand
    /// etwas Ungesichertes, entscheidet die Rueckfrage, ob es mitgeht.
    ///
    /// Bis zum 14.09.2026 wanderte eine geladene Datei nur in den Bestand und
    /// war nirgends zu sehen — aus Sorge um genau dieses Gemalte. Die Sorge
    /// war richtig, das Schweigen die falsche Antwort darauf: Man fragt.
    private func geladenUebernehmen(_ eintrag: Editoreintrag) {
        if ungesichert { rueckfrage = .geladen(eintrag) } else { aufDieLeinwand(eintrag) }
    }

    /// Die Meldung nennt beides: den Bestand, in dem es gelandet ist — er kann
    /// ein anderer sein als der, auf den der Editor eingestellt war —, und
    /// dass es jetzt auch auf der Leinwand liegt.
    private func aufDieLeinwand(_ eintrag: Editoreintrag) {
        oeffnen(eintrag, meldung: lokf("%@ aufgenommen, %@ — und geöffnet.",
                                       eintrag.name, lok(eintrag.groesse.beschriftung)))
    }

    /// Der zweite Weg der Rueckfrage: Die Leinwand bleibt, wie sie ist. Zu tun
    /// ist dabei nichts — das Stueck liegt schon im Bestand; die Meldung sagt,
    /// in welchem.
    private func imBestandLassen(_ eintrag: Editoreintrag) {
        meldung = lokf("%@ aufgenommen, %@.", eintrag.name, lok(eintrag.groesse.beschriftung))
    }

    private func sichern() {
        do {
            let eintrag = try bestand.sichern(leinwand, name: name, nummer: nummer)
            vorhandene = bestand.alle()
            // Von hier an weicht nichts mehr ab. Der Verlauf bleibt stehen:
            // Rueckgaengig ueber ein Sichern hinweg ist erlaubt — und macht
            // die Leinwand dann wieder ungesichert, weil sie wieder anders
            // aussieht als das, was in der Datei liegt.
            verlauf.gesichertMerken(leinwand)
            name = eintrag.name
            meldung = lokf("%@ gesichert.", eintrag.name)
            zustand.log("Gesichert: \(eintrag.name)")
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func loeschen(_ eintrag: Editoreintrag) {
        do {
            try bestand.loeschen(eintrag)
            vorhandene = bestand.alle()
            // War das Geloeschte gerade geoeffnet, bleibt das Bild stehen, aber
            // Name und Nummer werden geleert — sonst legt ein erneutes
            // „Sichern" es unter demselben Namen wieder an.
            if istGeoeffnet(eintrag) {
                nummer = ""
                name = ""
            }
            meldung = lokf("%@ gelöscht.", eintrag.name)
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Das Blatt aufmachen — vorbelegt mit dem, was dasteht: Umbenennen heisst
    /// aendern, nicht neu eintippen.
    private func umbenennenBeginnen(_ eintrag: Editoreintrag) {
        benennName = eintrag.name
        benennNummer = eintrag.nummer ?? ""
        benennMeldung = nil
        zuBenennen = eintrag
    }

    /// **Liegt das Umbenannte gerade auf der Leinwand, zieht sein Name mit.**
    /// Das Bild ist dasselbe geblieben, nur sein Name ist ein anderer; bliebe
    /// der alte in den Feldern stehen, legte das naechste „Sichern" es unter
    /// dem alten Namen ein zweites Mal an — genau der Fall, den das Leeren
    /// beim Loeschen verhindert, nur andersherum.
    private func umbenennen(_ eintrag: Editoreintrag) {
        let offen = istGeoeffnet(eintrag)
        do {
            let neu = try bestand.umbenennen(eintrag, name: benennName, nummer: benennNummer)
            vorhandene = bestand.alle()
            if offen {
                name = neu.name
                nummer = neu.nummer ?? ""
            }
            zuBenennen = nil
            meldung = lokf("%@ umbenannt.", neu.name)
            zustand.log("Umbenannt: \(eintrag.name) → \(neu.name)")
        } catch {
            // Das Blatt bleibt stehen und sagt hier, woran es lag — eine
            // Meldung unter der Leinwand laege dahinter.
            benennMeldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func nachladen() {
        let n = lametricNummer.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        laedt = true
        Task.detached {
            // holen() wartet bis zu zehn Sekunden auf LaMetric — nicht auf dem
            // Hauptthread, sonst steht das Fenster so lange.
            let sammlung = Iconsammlung(schreibordner: Iconordner.eigene)
            do {
                let icon = try sammlung.holen(nummer: n)
                await MainActor.run {
                    vorhandene = bestand.alle()
                    lametricNummer = ""
                    laedt = false
                    // Dasselbe wie nach „Oeffnen…": Ein geholtes Icon will man
                    // auch sehen. Die Groesse kommt aus dem Icon, nicht aus
                    // der Annahme, ein LaMetric-Icon sei immer 8×8.
                    if let eintrag = Editorbestand.eintrag(fuer: icon) { geladenUebernehmen(eintrag) }
                }
            } catch {
                await MainActor.run {
                    meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    laedt = false
                }
            }
        }
    }

    /// Nimmt die gewaehlte Datei entgegen — und liest sie **sofort**.
    ///
    /// Eine URL aus dem Dateiwaehler zeigt in die Dateien-App und ist
    /// zugriffsgeschuetzt: Lesen darf man sie nur zwischen
    /// `startAccessingSecurityScopedResource` und `stop…`. Die App merkte sich
    /// bis 13.09.2026 die URL und las erst beim Bestaetigen des Blattes — da
    /// war der Zugriff laengst zu, und am iPad schlug jeder Import fehl. Am
    /// Mac fiel es nicht auf: Die App laeuft dort nicht in der Sandbox, und
    /// ohne Sandbox gilt die Einschraenkung nicht.
    ///
    /// `startAccessingSecurityScopedResource` gibt ausserhalb der Sandbox
    /// `false` zurueck, obwohl das Lesen dort klappt — deshalb ist der
    /// Rueckgabewert **kein** Grund abzubrechen, sondern nur die Frage, ob
    /// hinterher abzumelden ist.
    private func dateiUebernehmen(_ url: URL) {
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
        let daten: Data
        do {
            daten = try Data(contentsOf: url)
        } catch {
            zustand.fehler = lokf("„%@“ ließ sich nicht lesen: %@",
                                  url.lastPathComponent, error.localizedDescription)
            return
        }
        // Die Groesse entscheidet hier und nicht erst beim Bestaetigen:
        // Wer eine 32×32 gewaehlt hat, soll das erfahren, bevor ein Blatt ihn
        // nach einem Namen fragt, den niemand braucht.
        let ziel: Leinwandgroesse
        do {
            ziel = try Editorbestand.zielgroesse(fuer: daten)
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return
        }
        importDaten = daten
        importZiel = ziel
        let vorschlag = Editorbestand.vorschlag(
            fuerDateinamen: url.deletingPathExtension().lastPathComponent)
        importNummer = vorschlag.nummer
        importName = vorschlag.name
        importMeldung = nil
        zeigeImportBlatt = true
    }

    /// Legt die gelesenen Daten im Bestand **ihrer eigenen** Groesse ab. Die
    /// Meldung nennt sie: Der Eintrag kann in einem anderen Bestand liegen als
    /// dem, auf den der Editor gerade eingestellt ist, und dann faende ihn
    /// niemand.
    private func einlesen() {
        guard let daten = importDaten else { return }
        do {
            let eintrag = try bestand.einlesen(daten: daten,
                                               nummer: importNummer, name: importName)
            vorhandene = bestand.alle()
            importDaten = nil
            zustand.log("Eingelesen: \(eintrag.name)")
            // Weiter geht es erst, wenn das Blatt wirklich zu ist
            // (`blattGeschlossen`) — vorher gaebe es keine Rueckfrage zu sehen.
            eingelesen = eintrag
            zeigeImportBlatt = false
        } catch {
            // Das Blatt bleibt stehen und sagt hier, woran es lag: Eine
            // Meldung unter der Leinwand laege dahinter.
            importMeldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Was nach dem Blatt geschieht — und zwar erst, wenn es zu ist.
    ///
    /// **Ein Dialog, der im selben Durchlauf aufgeht, in dem ein Blatt zugeht,
    /// wird verschluckt.** SwiftUI hat dann ein Bedienelement zu schliessen und
    /// eines zu zeigen und tut nur das erste; die Rueckfrage stuende nirgends,
    /// und „Öffnen" haette scheinbar nichts getan. `onDismiss` ist der Ort,
    /// an dem das Blatt nachweislich weg ist.
    ///
    /// `nil` heisst abgebrochen — dann ist hier nichts zu tun.
    private func blattGeschlossen() {
        guard let eintrag = eingelesen else { return }
        eingelesen = nil
        geladenUebernehmen(eintrag)
    }

    /// Holt mitgelieferte Icons zurueck, die im Schreibordner fehlen. Vorhandene
    /// Dateien bleiben unberuehrt; die Meldung nennt die Anzahl, damit „nichts
    /// passiert" nicht wie ein Fehlschlag wirkt.
    private func grundschatzWiederherstellen() {
        let quelle = Iconsammlung(schreibordner: Iconordner.eigene,
                                  leseordner: [Iconordner.mitgeliefert])
        let anzahl = quelle.mitgelieferteUebernehmen()
        vorhandene = bestand.alle()
        meldung = anzahl > 0
            ? lokf("%d Icons aus dem Grundschatz wiederhergestellt.", anzahl)
            : lok("Nichts zu holen — der Grundschatz ist vollständig da.")
    }

    /// **C2.** „Icon einfuegen" ist der **eine** Weg, auf dem zwischen den
    /// Groessen gerechnet wird — ein Befehl, den man aufruft, kein stiller
    /// Nebeneffekt: 8×8 in ein 16×16 verdoppelt, 8×8 und 16×16 in die Anzeige
    /// eingesetzt. Der umgekehrte Weg kommt nicht vor; Verkleinern zerstoert.
    ///
    /// Gerechnet wird im Kern (`Leinwand.iconEinsetzen`), und zwar erst auf
    /// einer Kopie: Ein Schritt fuer „Rueckgaengig" entsteht nur, wenn
    /// tatsaechlich etwas geschieht.
    private func iconEinfuegen(_ eintrag: Editoreintrag) {
        do {
            let quelle = try bestand.oeffnen(eintrag)
            var neue = leinwand
            guard neue.iconEinsetzen(quelle.bild, groesse: eintrag.groesse) else { return }
            schritt()
            leinwand = neue
            arbeitsstandSichern()
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Laeuft die Einzelbilder in Schleife durch, solange „Abspielen" gedrueckt
    /// ist — nur zur Ansicht, ohne dass vorher gesichert werden muss.
    private func abspielenUmschalten() {
        guard !spielAb else { stoppeAbspielen(); return }
        spielAb = true
        spielTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(max(0.05, leinwand.verzoegerung)))
                guard !Task.isCancelled, leinwand.bilder.count > 1 else { continue }
                await MainActor.run { leinwand.waehlen((leinwand.aktuell + 1) % leinwand.bilder.count) }
            }
        }
    }

    private func stoppeAbspielen() {
        spielAb = false
        spielTask?.cancel()
        spielTask = nil
    }

    /// `slotPlatz` ohne `slotOptionen`: Ein gemaltes Bild hat keine Regler, es
    /// gibt hier nichts zu merken — wohl aber etwas zu vergessen. Stand auf dem
    /// Platz vorher eine Textsendung, liegt dazu ein gemerkter Stand, und der
    /// Block rechnete daraus beim naechsten Start ohne Broker weiter den alten
    /// Text. `AppZustand.senden` wirft ihn deshalb je erreichter Uhr weg.
    ///
    /// Ein einzelnes Bild geht als `draw` hinaus — klein und exakt. Mehrere
    /// gehen als ein animiertes GIF: Rechtecke kennen keine Zeit.
    private func senden() {
        let frame: Frame
        if leinwand.bilder.count > 1 {
            do {
                let uri = try Bildraster.alsDatenURI(leinwand.bilder,
                                                     breite: leinwand.breite, hoehe: leinwand.hoehe,
                                                     verzoegerung: leinwand.verzoegerung)
                frame = Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: dauer)
            } catch {
                zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                return
            }
        } else {
            frame = Frame(draw: feld.alsDrawBefehle(), dauer: dauer)
        }
        laeuft = true
        let anzeigenName = Meldungsplatz.name(fuer: platz)
        // Momentaufnahme wie in `SendenView.senden`: der Task soll den Platz
        // von jetzt sehen, nicht den beim spaeteren Ausfuehren.
        let slotPlatz = platz
        Task {
            await zustand.senden(frame, als: anzeigenName, slotPlatz: slotPlatz)
            laeuft = false
        }
    }
}
