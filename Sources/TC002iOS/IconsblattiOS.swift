import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell
import UniformTypeIdentifiers

/// Ein Icon als stehende Vorschau. Zeigt das erste Einzelbild; animierte Icons
/// laufen hier nicht, das wäre im Raster nur Unruhe.
///
/// Nimmt die Fläche, die es bekommt, und rechnet die Punktgröße daraus — wie
/// `Slotraster` es im Block tut. Die Kante je Bildpunkt von außen gereicht zu
/// bekommen, aus einer gemessenen Rasterbreite, ist eine Falle: Eine Ansicht,
/// deren Größe von einer Messung abhängt, die ihrerseits von der Größe
/// abhängt, kann bei zu kleiner Messung Icons in Originalauflösung zeigen,
/// also stecknadelkopfgroß. Der Aufrufer setzt darum einen Rahmen, und das
/// Bild füllt ihn.
struct IconbildiOS: View {
    let datei: URL
    /// Die Kantenlaenge des Icons in Pixeln — 8 oder 16: Fest auf 8 zu
    /// stellen ginge nur, solange das Telefon ausschliesslich den
    /// 8×8-Bestand kennt — die eigenen 16×16 kommen ueber iCloud aber auch
    /// hierher.
    var pixelkante: Int = 8

    var body: some View {
        IconRasteriOS(pixel: (try? Bildraster.lesen(datei, breite: pixelkante, hoehe: pixelkante))?.first ?? [],
                      pixelkante: pixelkante)
    }
}

/// Zeichnet ein bereits gelesenes Pixelraster in die verfügbare Fläche — der
/// gemeinsame Kern von `IconbildiOS` (ein stehendes Einzelbild) und der
/// Einzelansicht, die zusätzlich laufende Icons zeigt. Quadratisch, weil ein
/// Icon quadratisch ist; beide Größen werden damit gleich groß gezeigt, das
/// 16×16 ist nicht das doppelt so große Bild, sondern das feinere.
private struct IconRasteriOS: View {
    let pixel: [String?]
    /// 8 oder 16 — siehe `IconbildiOS.pixelkante`.
    var pixelkante: Int = 8

    var body: some View {
        Canvas { kontext, groesse in
            guard pixel.count == pixelkante * pixelkante else { return }
            let kante = groesse.width / Double(pixelkante)
            for y in 0..<pixelkante {
                for x in 0..<pixelkante {
                    guard let farbe = pixel[y * pixelkante + x], let c = Color(hex: farbe) else { continue }
                    kontext.fill(Path(CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                             width: kante, height: kante)), with: .color(c))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Die ganze Sammlung am Telefon: 8 × 8, 16 × 16 und die 52 × 16-Anzeigen,
/// nach Größe gruppiert wie in der Übersicht am Schreibtisch.
///
/// Dass eine 52 × 16 nicht in der Iconauswahl steht, ist richtig — ein Icon
/// steht *neben* dem Text, eine Anzeige ersetzt Text und Icon. Am Schreibtisch
/// trägt „Icons" diese Entscheidung, weil es dort den zweiten Ort gibt, an dem
/// die Anzeigen liegen. Am Telefon gab es den nicht: Die Anzeigen hingen an
/// einem unbeschrifteten Knopf am Ende der Formatpille, ohne Überblick, ohne
/// Suche, ohne Weg, etwas hinzuzufügen. Deshalb ein Blatt statt zweier — der
/// Unterschied zwischen Icon und Anzeige steht jetzt in den Gruppen, nicht in
/// zwei Türen.
///
/// Gemalt wird hier nicht. Ein 8 × 8-Raster mit dem Finger ist keine
/// Arbeitsfläche; ansehen, suchen, hinzufügen und verschicken ist etwas
/// anderes als malen.
struct IconsblattiOS: View {
    /// Der Meldungsplatz, auf den eine 52 × 16 ginge — die Anzeige ersetzt
    /// alles, was auf diesem Platz steht.
    let platz: Int
    @Binding var gewaehlt: Icon?
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen

    /// Beide Unterseiten hängen an diesem Pfad statt an je einem
    /// `NavigationLink` im Raster: Eine Kachel im `LazyVGrid` einer Listenzeile
    /// bekäme als `NavigationLink` das Aussehen einer Listenzeile mitsamt
    /// Pfeil. Die 52 × 16 sind wirkliche Listenzeilen und dürfen ihren haben.
    @State private var pfad: [Editoreintrag] = []
    @State private var vorhandene: [Editoreintrag] = []
    /// Einmal gelesen, nicht bei jedem Tastendruck: Ob sich etwas bewegt,
    /// steht in der Datei. Über den Dateipfad, weil ein 8 × 8 und ein 16 × 16
    /// denselben Namen tragen dürfen.
    @State private var bewegte: Set<String> = []
    @State private var filter = Bestandsfilter()
    @State private var lametricNummer = ""
    @State private var laedt = false
    @State private var meldung: String?
    @State private var zeigeDateiwahl = false
    /// Die gelesenen Bytes einer gewählten Datei, bis Nummer und Name
    /// feststehen — nicht deren URL, siehe `dateiUebernehmen`.
    @State private var importDaten: Data?
    @State private var importZiel: Leinwandgroesse?
    @State private var importNummer = ""
    @State private var importName = ""
    @State private var fragtImport = false
    /// `.numberPad` hat keine Eingabetaste — ohne Tastaturleiste kaeme man aus
    /// dem Nummernfeld nur durch Tippen daneben heraus.
    @FocusState private var lametricFokus: Bool

    /// Vier statt fuenf: Bei fuenf blieben rund 60 Punkte je Kachel, und
    /// Namen wie „Animated cloud" oder „Best Real Fire Flame" standen auch
    /// zweizeilig noch mit „…" da. Ein Icon, dessen Name nicht zu lesen ist,
    /// muss man am Bild erraten.
    private static let spalten = 4
    private static let zwischenraum = 10.0

    /// Die drei Bestaende dieser Installation. Nicht `Editorbestand.eigene`:
    /// Am Telefon wird der Grundschatz aus dem Buendel mitgelesen, weil es
    /// dort kein „Grundschatz wiederherstellen" gibt, das ihn erst in den
    /// eigenen Ordner holte.
    private var bestand: Editorbestand {
        Editorbestand(icons8: Iconsammlung(schreibordner: Iconordner.eigene,
                                           leseordner: [Iconordner.mitgeliefert]),
                      icons16: Iconsammlung(schreibordner: Iconordner.eigene16, kante: 16),
                      bilder: Bildersammlung(ordner: Bilderordner.eigene))
    }

    private var gefilterterBestand: [Editoreintrag] {
        vorhandene.gefiltert(filter, bewegt: { bewegte.contains($0.datei.path) })
    }

    /// Warum ein Stueck dieser Groesse an keine der Zieluhren gehen kann —
    /// `nil`, wenn es ankommt. Beantwortet wird die Frage von den Zieluhren
    /// (`AppZustand.grafikSperre`), das Blatt stellt sie nur. Dieselbe Naht
    /// wie am Schreibtisch (`IconAuswahlView`).
    private func sperre(_ eintrag: Editoreintrag) -> String? {
        zustand.grafikSperre(hoehe: eintrag.groesse.hoehe)
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            // Die Sammlung zuerst, das Hinzufuegen darunter: Wer das Blatt
            // oeffnet, will fast immer waehlen. Oben stand zuerst ein Feld
            // fuer eine LaMetric-Nummer, und die Icons begannen unterhalb des
            // halben Bildschirms.
            List {
                auswahl
                ForEach(Leinwandgroesse.allCases) { gruppe($0) }
                if gefilterterBestand.isEmpty {
                    Text("Nichts gefunden. Über „Hinzufügen“ kommt Neues herein.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                hinzufuegen
            }
            // Ohne das stand zwischen Titel und erster Karte ein leeres Band
            // von rund 45 Punkten: Eine gruppierte `List` haelt oben Platz
            // fuer eine Abschnittsueberschrift frei, auch wo keine steht.
            // `listSectionSpacing` erreicht das nicht — das regelt den
            // Abstand *zwischen* Abschnitten, nicht den Rand darueber.
            .contentMargins(.top, 8, for: .scrollContent)
            .searchable(text: $filter.suche, prompt: Text("Suchen"))
            .navigationTitle("Icons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { schliessen() }
            } }
            .navigationDestination(for: Editoreintrag.self) { seite($0) }
            .onAppear { neuLesen() }
        }
        .presentationDragIndicator(.visible)
        .fileImporter(isPresented: $zeigeDateiwahl,
                      allowedContentTypes: [.gif, .png, .jpeg]) { ergebnis in
            switch ergebnis {
            case .success(let url): dateiUebernehmen(url)
            // Kein stilles `return`: Wer eine Datei waehlte und scheiterte,
            // saehe sonst nichts geschehen und wuesste nicht, woran es lag.
            case .failure(let fehler):
                meldung = lokf("Die Datei ließ sich nicht öffnen: %@", fehler.localizedDescription)
            }
        }
        .alert("Hinzufügen", isPresented: $fragtImport) {
            // Die Nummer nur, wo sie der Dateiname ist: Bei 8 × 8 muss sie da
            // und eindeutig sein, bei den anderen beiden heisst die Datei nach
            // ihrem Namen.
            if importZiel?.nummerIstDateiname == true {
                TextField("Nummer", text: $importNummer)
                    .keyboardType(.numberPad)
            }
            TextField("Name", text: $importName)
            Button("Abbrechen", role: .cancel) { importDaten = nil }
            Button("Übernehmen") { einlesen() }
        } message: {
            Text(importZiel.map { lokf("Die Datei kommt zu den %@.", lok($0.beschriftung)) } ?? "")
        }
    }

    // MARK: - Die Abschnitte

    private var hinzufuegen: some View {
        Section {
            HStack {
                TextField("LaMetric-Nummer", text: $lametricNummer)
                    .keyboardType(.numberPad)
                    .focused($lametricFokus)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Fertig") { lametricFokus = false }
                        }
                    }
                Button("Nachladen") { nachladen() }
                    .knopfBefehl()
                    .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            // Eine Listenzeile wie „Hilfe" in den Einstellungen, kein
            // Befehlsknopf — sie steht fuer sich in der Liste und ist dort
            // schon als antippbar zu erkennen. Gilt fuer alle drei solchen
            // Zeilen in diesem Blatt.
            Button("Dateien …") { zeigeDateiwahl = true }
                .buttonStyle(.automatic)
            if let meldung {
                Text(meldung).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Hinzufügen")
        } footer: {
            Text("Die Nummer kommt von developer.lametric.com. Eine Datei landet im Bestand ihrer Größe; Kleineres wird mittig eingepasst, Größeres als die Anzeige abgelehnt.")
        }
    }

    private var auswahl: some View {
        Section {
            Button("Kein Icon") { gewaehlt = nil; schliessen() }
                .buttonStyle(.automatic)
            Filterleiste(wert: $filter.groesse,
                         angebot: Leinwandgroesse.allCases.map {
                             (titel: $0.beschriftung, kurz: $0.kurzbeschriftung, wert: $0)
                         },
                         nurBewegte: $filter.nurBewegte)
            // Nur, wenn es etwas zurueckzunehmen gibt: ein Knopf, der nichts
            // zu tun hat, ist eine Frage ohne Anlass. Dieselbe Entscheidung
            // wie in der Uebersicht am Schreibtisch.
            if filter.schraenktEin {
                Button("Zurücksetzen") { filter.zuruecksetzen() }
                    .buttonStyle(.automatic)
            }
        }
    }

    /// Eine Groessengruppe, und nur, wenn etwas darin steht. Die Ueberschrift
    /// ist die Groesse — welche es gibt, ist die Antwort und nicht die Frage.
    @ViewBuilder
    private func gruppe(_ groesse: Leinwandgroesse) -> some View {
        let stuecke = gefilterterBestand.filter { $0.groesse == groesse }
        if !stuecke.isEmpty {
            Section {
                // Icons ins Raster, Anzeigen in Zeilen: Ein 52 × 16 ist
                // dreimal so breit wie hoch, fuenf davon nebeneinander waeren
                // auf einem Telefon nicht mehr zu erkennen.
                if groesse.istIcon {
                    raster(stuecke)
                } else {
                    ForEach(stuecke) { anzeigezeile($0) }
                }
            } header: {
                Text(lok(groesse.beschriftung))
            }
        }
    }

    private func raster(_ stuecke: [Editoreintrag]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.zwischenraum),
                                 count: Self.spalten),
                  spacing: 14) {
            ForEach(stuecke) { kachel($0) }
        }
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
    }

    private func kachel(_ eintrag: Editoreintrag) -> some View {
        Button {
            pfad.append(eintrag)
        } label: {
            VStack(spacing: 3) {
                IconbildiOS(datei: eintrag.datei, pixelkante: eintrag.groesse.breite)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.accentColor,
                                    lineWidth: gewaehlt?.datei == eintrag.datei ? 2 : 0)
                    )
                // Das Abspielzeichen neben den Namen, nicht ins Bild —
                // dieselbe Entscheidung wie in den Listen am Schreibtisch.
                // LaMetric und AWTRIX legen es durchscheinend ueber das
                // Vorschaubildchen und verdecken damit gerade das Motiv, das
                // man erkennen soll. Hier ist die Namenszeile ohnehin da.
                // Zwei Zeilen, wie in der Uebersicht am Schreibtisch:
                // Einzeilig stehen in fuenf Spalten mehrere „Home Assista…"
                // nebeneinander, die sich nur im Bild unterscheiden.
                // `reservesSpace` haelt den Platz auch fuer einen einzeiligen
                // Namen frei, sonst macht er die ganze Reihe kuerzer.
                HStack(alignment: .top, spacing: 2) {
                    if bewegte.contains(eintrag.datei.path) {
                        Image(systemName: "play.fill")
                            .accessibilityHidden(true)
                    }
                    Text(eintrag.name)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.center)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        // `.plain`, und daran haengt, ob ueberhaupt das getroffene Icon
        // aufgeht. Eine Listenzeile ist selbst ein Bedienelement: Knoepfe mit
        // dem vorgegebenen Stil darin teilen sich ihre Flaeche, und ein Tipp
        // landet beim ersten. Vierzig Kacheln in einer Zeile hiessen also
        // vierzigmal dasselbe Icon. Derselbe Fallstrick wie im Editor bei
        // „Sichern"/„Neu" und in der Blockreihe.
        .buttonStyle(.plain)
        // Gesperrt, nicht verschwunden — dieselbe Entscheidung wie am
        // Schreibtisch: Wer sein 16×16 sucht, soll sehen, dass es noch da ist.
        .disabled(sperre(eintrag) != nil)
        .opacity(sperre(eintrag) == nil ? 1 : 0.35)
        .accessibilityLabel(Text(bewegte.contains(eintrag.datei.path)
                                 ? lokf("%@, bewegt", eintrag.name) : eintrag.name))
        .accessibilityAddTraits(gewaehlt?.datei == eintrag.datei ? [.isSelected] : [])
    }

    /// Eine 52 × 16 als Listenzeile mit Pfeil — sie fuehrt weiter, statt zu
    /// waehlen. Anders als eine gesperrte Icon-Kachel bleibt sie bedienbar:
    /// Senden ist eine Handlung, und ihre Verweigerung braucht einen Grund an
    /// der Stelle, an der der Knopf steht.
    private func anzeigezeile(_ eintrag: Editoreintrag) -> some View {
        NavigationLink(value: eintrag) {
            HStack(spacing: 10) {
                Rasterbild(datei: eintrag.datei,
                           breite: eintrag.groesse.breite, hoehe: eintrag.groesse.hoehe,
                           kante: 2)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(eintrag.name).lineLimit(1)
                    if bewegte.contains(eintrag.datei.path) {
                        // Dasselbe Zeichen wie bei den Icons: neben der
                        // Angabe, nicht ins Bild.
                        Label("bewegt", systemImage: "play.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Wohin ein Stueck fuehrt: ein Icon auf seine Einzelansicht, eine
    /// 52 × 16 auf ihre Sendeseite.
    @ViewBuilder
    private func seite(_ eintrag: Editoreintrag) -> some View {
        if eintrag.groesse.istIcon {
            IconseiteiOS(eintrag: eintrag,
                         // Eigen heisst: Es liegt in einem Schreibordner
                         // dieser App. Der Grundschatz im Buendel liegt das
                         // nicht und laesst sich weder umbenennen noch
                         // loeschen.
                         darfAendern: darfAendern(eintrag),
                         sperrgrund: sperre(eintrag),
                         uebernehmen: { gewaehlt = icon(aus: $0); schliessen() },
                         umbenennen: { umbenennen($0, auf: $1) },
                         loeschen: { loeschen($0) })
        } else {
            AnzeigeseiteiOS(eintrag: eintrag, platz: platz, zustand: zustand,
                            fertig: { schliessen() })
        }
    }

    // MARK: - Der Bestand

    private func neuLesen() {
        vorhandene = bestand.alle()
        bewegte = Set(vorhandene.filter { Bildraster.bewegt($0.datei) }.map(\.datei.path))
    }

    /// Ob dieses Stueck im Schreibordner liegt. Die Anzeigen tun das immer —
    /// zu ihnen gibt es keinen mitgelieferten Bestand.
    private func darfAendern(_ eintrag: Editoreintrag) -> Bool {
        guard let sammlung = bestand.iconsammlung(fuer: eintrag.groesse) else { return true }
        return sammlung.istEigen(icon(aus: eintrag))
    }

    /// Ein Eintrag als `Icon` — die Form, in der die Sendeansicht ein
    /// gewaehltes Icon fuehrt. Die Nummer ist der Dateiname ohne Endung, genau
    /// wie `Iconsammlung.alle()` sie vergibt; die Kategorie steht nur in der
    /// Sammlung und wird nirgends gebraucht, wo dieses `Icon` hingeht.
    private func icon(aus eintrag: Editoreintrag) -> Icon {
        Icon(nummer: eintrag.schluessel, name: eintrag.name, kategorie: "",
             datei: eintrag.datei, kante: eintrag.groesse.breite)
    }

    /// Gibt dem Icon einen neuen Namen. Die Nummer bleibt — sie ist der
    /// Dateiname und das, worauf sich ein Kurzbefehl oder das
    /// Kommandozeilenwerkzeug beruft. Zurück kommt das umbenannte Stück, damit
    /// die Einzelansicht ihren Titel nachziehen kann.
    private func umbenennen(_ eintrag: Editoreintrag, auf name: String) -> Editoreintrag? {
        guard let neu = try? bestand.umbenennen(eintrag, name: name,
                                                nummer: eintrag.nummer ?? eintrag.schluessel) else {
            return nil
        }
        if gewaehlt?.datei == eintrag.datei { gewaehlt = icon(aus: neu) }
        neuLesen()
        return neu
    }

    /// Entfernt das Stück endgültig. War es gerade gewählt, fällt die Wahl auf
    /// „Kein Icon" zurück — es gibt danach nichts mehr, worauf sie zeigen
    /// könnte. Dieselbe Entscheidung wie im Auswahlblatt am Schreibtisch.
    private func loeschen(_ eintrag: Editoreintrag) {
        guard (try? bestand.loeschen(eintrag)) != nil else { return }
        if gewaehlt?.datei == eintrag.datei { gewaehlt = nil }
        neuLesen()
    }

    /// Holt ein Icon über seine Nummer. Blockiert nicht den Hauptthread — der
    /// Abruf geht übers Netz und dauert.
    private func nachladen() {
        let nummer = lametricNummer.trimmingCharacters(in: .whitespaces)
        guard let quelle = bestand.iconsammlung(fuer: .icon8) else { return }
        laedt = true
        meldung = nil
        Task.detached {
            do {
                let icon = try quelle.holen(nummer: nummer)
                await MainActor.run {
                    neuLesen()
                    gewaehlt = icon
                    meldung = lokf("%@ geholt.", icon.name)
                    lametricNummer = ""
                    laedt = false
                }
            } catch {
                await MainActor.run {
                    meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    laedt = false
                }
            }
        }
    }

    /// Liest die gewählte Datei **sofort** und merkt sich die Bytes, nicht die
    /// URL: Eine URL aus dem Dateiwähler ist zugriffsgeschützt und gilt nur
    /// zwischen `startAccessingSecurityScopedResource` und `stop…`. Wer sie
    /// aufhebt und erst beim Bestätigen des Namens liest, greift ins Leere.
    ///
    /// `startAccessingSecurityScopedResource` gibt außerhalb der Sandbox
    /// `false` zurück, obwohl das Lesen dort klappt — der Rückgabewert ist
    /// deshalb kein Grund abzubrechen, sondern nur die Frage, ob hinterher
    /// abzumelden ist.
    private func dateiUebernehmen(_ url: URL) {
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
        let daten: Data
        do {
            daten = try Data(contentsOf: url)
        } catch {
            meldung = lokf("„%@“ ließ sich nicht lesen: %@",
                           url.lastPathComponent, error.localizedDescription)
            return
        }
        // Die Groesse entscheidet hier und nicht erst beim Uebernehmen: Wer
        // eine 32×32 gewaehlt hat, soll das erfahren, bevor ihn eine Rueckfrage
        // nach einem Namen fragt, den niemand braucht.
        do {
            importZiel = try Editorbestand.zielgroesse(fuer: daten)
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return
        }
        let vorschlag = Editorbestand.vorschlag(
            fuerDateinamen: url.deletingPathExtension().lastPathComponent)
        importDaten = daten
        importNummer = vorschlag.nummer
        importName = vorschlag.name
        meldung = nil
        fragtImport = true
    }

    /// Legt die gelesenen Daten im Bestand ihrer eigenen Größe ab. Die Meldung
    /// nennt sie: Der Eintrag kann in einer anderen Gruppe landen als der, in
    /// der man gerade sucht, und dann fände ihn niemand.
    private func einlesen() {
        guard let daten = importDaten else { return }
        do {
            let eintrag = try bestand.einlesen(daten: daten, nummer: importNummer, name: importName)
            importDaten = nil
            neuLesen()
            meldung = lokf("%@ aufgenommen — %@.", eintrag.name, lok(eintrag.groesse.beschriftung))
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}

/// Einzelansicht eines Icons: Name als Titel, groß gerastert — bei einem
/// laufenden Icon auch laufend —, darunter „Übernehmen“. Im Menü rechts oben
/// stehen „Umbenennen“ und „Löschen“; sie sind hier und nicht in der Kachel,
/// weil erst hier der Name dabeisteht, den die Rückfrage nennt.
///
/// Bauart wie die Vorschau am Sendebildschirm (`VorschauiOS`): Die
/// Einzelbilder samt Standzeiten werden einmal über `.task(id:)` in
/// `@State` gelesen, nicht bei jedem Neuzeichnen — `TimelineView(.animation)`
/// liefe sonst 60 bis 120 mal je Sekunde auf dem Hauptthread. `TimelineView`
/// wird zudem nur montiert, wenn es tatsächlich mehr als ein Einzelbild gibt.
private struct IconseiteiOS: View {
    let darfAendern: Bool
    /// Warum dieses Icon an keine der Zieluhren gehen kann — `nil`, wenn es
    /// geht. Steht als Satz unter der grossen Ansicht, und „Uebernehmen" ist
    /// dann gesperrt: Von hier aus waere es sonst der zweite Weg an der
    /// Sperre vorbei, den die Kachel schon zumacht.
    let sperrgrund: String?
    let uebernehmen: (Editoreintrag) -> Void
    let umbenennen: (Editoreintrag, String) -> Editoreintrag?
    let loeschen: (Editoreintrag) -> Void
    @Environment(\.dismiss) private var zurueck

    /// Der Eintrag liegt hier als Zustand und nicht als Übergabewert: Nach dem
    /// Umbenennen soll der Titel der neue sein, ohne dass die Seite zugeht.
    @State private var eintrag: Editoreintrag
    @State private var bilder: [Bildraster.Einzelbild] = []
    @State private var neuerName = ""
    @State private var fragtUmbenennen = false
    @State private var fragtLoeschen = false

    /// Kantenlaenge der grossen Ansicht in Punkten — nicht je Bildpunkt.
    private static let kante = 220.0

    init(eintrag: Editoreintrag, darfAendern: Bool, sperrgrund: String? = nil,
         uebernehmen: @escaping (Editoreintrag) -> Void,
         umbenennen: @escaping (Editoreintrag, String) -> Editoreintrag?,
         loeschen: @escaping (Editoreintrag) -> Void) {
        _eintrag = State(initialValue: eintrag)
        self.darfAendern = darfAendern
        self.sperrgrund = sperrgrund
        self.uebernehmen = uebernehmen
        self.umbenennen = umbenennen
        self.loeschen = loeschen
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if bilder.count > 1 {
                TimelineView(.animation) { zeit in
                    IconRasteriOS(pixel: Self.einzelbild(aus: bilder, bei: zeit.date)?.pixel ?? bilder[0].pixel,
                                  pixelkante: eintrag.groesse.breite)
                        .frame(width: Self.kante, height: Self.kante)
                }
            } else {
                IconRasteriOS(pixel: bilder.first?.pixel ?? [],
                              pixelkante: eintrag.groesse.breite)
                    .frame(width: Self.kante, height: Self.kante)
            }
            Spacer()
            if let sperrgrund {
                Label(sperrgrund, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
                    .padding(.bottom, 8)
            }
            Button("Übernehmen") { uebernehmen(eintrag) }
                .knopfHaupthandlung()
                .disabled(sperrgrund != nil)
        }
        .padding()
        .navigationTitle(eintrag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if darfAendern {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Umbenennen") {
                            neuerName = eintrag.name
                            fragtUmbenennen = true
                        }
                        Button("Löschen", role: .destructive) { fragtLoeschen = true }
                    } label: {
                        Label("Mehr", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Umbenennen", isPresented: $fragtUmbenennen) {
            TextField("Name", text: $neuerName)
            Button("Abbrechen", role: .cancel) {}
            Button("Sichern") {
                if let neu = umbenennen(eintrag, neuerName) { eintrag = neu }
            }
        } message: {
            Text("Die Nummer bleibt, wie sie ist — Kurzbefehle finden das Icon weiterhin.")
        }
        .confirmationDialog(Text(lokf("„%@“ löschen?", eintrag.name)),
                            isPresented: $fragtLoeschen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                loeschen(eintrag)
                zurueck()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(lokf("Das Icon „%@“ wird endgültig entfernt.", eintrag.name))
        }
        .task(id: eintrag.datei) {
            bilder = (try? Bildraster.lesenMitZeiten(eintrag.datei,
                                                     breite: eintrag.groesse.breite,
                                                     hoehe: eintrag.groesse.hoehe)) ?? []
        }
    }

    /// Wählt anhand der verstrichenen Zeit das fällige Einzelbild — dieselbe
    /// Logik wie in `VorschauiOS`, hier dupliziert, weil jene Methode dort
    /// privat ist.
    private static func einzelbild(aus liste: [Bildraster.Einzelbild], bei zeitpunkt: Date) -> Bildraster.Einzelbild? {
        guard !liste.isEmpty else { return nil }
        let gesamt = liste.reduce(0) { $0 + $1.dauer }
        guard gesamt > 0 else { return liste.first }
        var rest = zeitpunkt.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: gesamt)
        for bild in liste {
            if rest < bild.dauer { return bild }
            rest -= bild.dauer
        }
        return liste.last
    }
}

/// Die Seite einer 52 × 16-Anzeige: Vorschau und der Knopf, sie auf den
/// gewählten Meldungsplatz zu schicken.
///
/// Eine Anzeige ist kein Icon: Ein Icon steht *neben* dem Text, eine 52 × 16
/// ist das ganze Display und ersetzt Text und Icon. Deshalb wird sie hier
/// geschickt, statt sich in den Sendebildschirm zu setzen.
private struct AnzeigeseiteiOS: View {
    let eintrag: Editoreintrag
    @Bindable var zustand: AppZustand
    /// Schliesst das ganze Blatt — nach dem Senden gibt es hier nichts mehr
    /// zu tun.
    let fertig: () -> Void

    /// Der Platz wird **hier** gewaehlt, nicht drueben im Sendebildschirm.
    /// Wer ein Bild ausgesucht hat, entscheidet im selben Atemzug, wohin es
    /// geht; zurueckzugehen, nur um den Platz zu stellen, und dann wieder
    /// herzufinden, war der Umweg, der den Weg unbrauchbar machte. Der Platz
    /// aus dem Sendebildschirm ist die Vorgabe.
    @State private var platz: Int
    @State private var laeuft = false
    @State private var meldung: String?

    init(eintrag: Editoreintrag, platz: Int, zustand: AppZustand,
         fertig: @escaping () -> Void) {
        self.eintrag = eintrag
        self.zustand = zustand
        self.fertig = fertig
        _platz = State(initialValue: platz)
    }

    /// Warum eine ganze 52 × 16-Anzeige an keine der Zieluhren gehen kann.
    ///
    /// Ohne diese Sperre schickte der Knopf trotzdem, und auf einer AWTRIX NG
    /// kam nichts an — die Fussnote unten sagt zwar „Eine AWTRIX NG nimmt sie
    /// nicht", aber ein Satz, der eine Sperre beschreibt, ohne dass eine da
    /// ist, ist schlimmer als keiner.
    private var sperre: String? { zustand.grafikSperre(hoehe: Pixelfeld.hoeheStandard) }

    /// Welche Plaetze der angesehenen Uhr belegt sind — dieselbe Quelle wie
    /// im Sendebildschirm.
    private var belegte: Set<Int> { zustand.belegtePlaetze() }

    private func loeschen(_ i: Int) {
        Task { await zustand.loeschen(Meldungsplatz.name(fuer: i)) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            // Sechs Punkte je Pixel: 312 × 96 Punkte, das breiteste Mass, das
            // auf einem Telefon im Hochformat noch ganz hineingeht. Stehend
            // wie in der Zeile — eine bewegte Anzeige laeuft erst auf der Uhr;
            // `Rasterbild` liest die Datei bei jedem Neuzeichnen, und in einem
            // `TimelineView` waere das sechzigmal je Sekunde.
            Rasterbild(datei: eintrag.datei,
                       breite: eintrag.groesse.breite, hoehe: eintrag.groesse.hoehe,
                       kante: 6)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text("Eine 52 × 16-Anzeige füllt das Display und ersetzt Text und Icon. Eine AWTRIX NG nimmt sie nicht — ihre Anzeige ist 32 × 8.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Dieselben Bloecke wie im Sendebildschirm, aus derselben
            // Rechnung (`AppZustand.slotzustand`): Derselbe Platz derselben
            // Uhr soll hier nicht etwas anderes zeigen. Antippen waehlt.
            VStack(spacing: 6) {
                Text("Auf welchen Platz?")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(1...Meldungsplatz.anzahl, id: \.self) { i in
                        Button { platz = i } label: {
                            Slotblock(platz: i,
                                      zustand: zustand.slotzustand(i, belegt: belegte.contains(i)),
                                      gewaehlt: platz == i,
                                      mass: zustand.referenzUhr.map(Anzeigemass.fuer) ?? .tc002)
                        }
                        .buttonStyle(.plain)
                        .slotmenue(belegt: belegte.contains(i),
                                   loeschen: { loeschen(i) },
                                   zeigen: { zustand.umschalten(auf: Meldungsplatz.name(fuer: i)) })
                    }
                }
            }
            Spacer()
            if let sperre {
                Label(sperre, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
            }
            if let meldung {
                Text(meldung).font(.footnote).foregroundStyle(.secondary)
            }
            Button(lokf("An Platz %d senden", platz)) { senden() }
                .knopfHaupthandlung()
                .disabled(laeuft || sperre != nil)
        }
        .padding()
        .navigationTitle(eintrag.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Der Rahmen wird im Kern gebaut (`Bildsendung.rahmen`) — ein Einzelbild
    /// als Rechtecke, mehrere als GIF. Dieselbe Entscheidung wie im Editor am
    /// Schreibtisch, an einer Stelle.
    private func senden() {
        laeuft = true
        meldung = nil
        do {
            let rahmen = try Bildsendung.rahmen(aus: eintrag.datei)
            let name = Meldungsplatz.name(fuer: platz)
            // Was der Block danach zeigt: das erste Einzelbild der Datei. Ohne
            // das stuende dort „unbekannt" — die Uhr schickt ein GIF zurueck,
            // und aus dem laesst sich nichts mehr zerlegen.
            let slotPixel = try? Bildraster.lesen(Data(contentsOf: eintrag.datei),
                                                  breite: eintrag.groesse.breite,
                                                  hoehe: eintrag.groesse.hoehe).first
            Task {
                await zustand.senden(rahmen, als: name, slotPlatz: platz, slotPixel: slotPixel)
                laeuft = false
                fertig()
            }
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            laeuft = false
        }
    }
}
