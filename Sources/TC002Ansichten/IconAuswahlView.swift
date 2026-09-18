import SwiftUI
import TC002Core

/// Waehlt ein Icon aus der Sammlung — ohne Auswahl nennt der Knopf die Handlung
/// „Icon wählen…", mit Auswahl zeigt er Vorschau und Namen des gewaehlten Icons
/// und bleibt anklickbar, um ein anderes zu waehlen; ein Druck oeffnet ein Blatt
/// mit Suche und Raster. Baugleich mit `ZielauswahlView`: derselbe Blattkopf,
/// derselbe „Schließen"-Knopf — die Blaetter der App sollen sich gleich anfuehlen.
///
/// Ein Icon gehoert inhaltlich zum Text, nicht zum Versand — der Knopf steht
/// deshalb bei den uebrigen Formatierungsreglern im Inspektor (SendenView.swift),
/// nicht in der Sendezeile.
struct IconAuswahlView: View {
    @Binding var gewaehltesIcon: Icon?
    /// Alle Bestaende, aus denen gewaehlt werden darf — heute die 8×8 und die
    /// 16×16. Sie stehen im selben Raster nebeneinander: Beim Waehlen zaehlt,
    /// wie das Icon aussieht, nicht in welchem Ordner es liegt. Woher es
    /// stammt, weiss es selbst (`Icon.kante`), und das Loeschen fragt danach.
    let sammlungen: [Iconsammlung]
    /// Warum ein Icon dieser Kantenlaenge nicht ankaeme — `nil`, wenn es
    /// ankommt. Gereicht wird die Frage, nicht die Antwort: Wer sie
    /// beantwortet, sind die Zieluhren (`AppZustand.grafikSperre`), und das
    /// weiss die Auswahl nicht. So bleibt sie eine Auswahl und wird nicht
    /// zur zweiten Stelle, an der Geraetewissen steht.
    var sperre: (Int) -> String? = { _ in nil }

    @State private var zeigeBlatt = false
    @State private var suche = ""
    /// Das Icon, fuer das gerade die Loesch-Rueckfrage steht — `nil` heisst
    /// keine.
    @State private var zuLoeschen: Icon?
    /// Erzwingt das Neulesen von `sammlung.alle()`, das sonst niemand anstoesst:
    /// die Liste wird bei jedem Zugriff frisch von der Platte gelesen, aber
    /// SwiftUI zeichnet nur neu, wenn sich ein beobachteter Zustand aendert.
    @State private var aktualisierung = 0
    /// Die Filterleiste: Größe und Bewegung.
    @State private var filterkante: Int?
    @State private var nurBewegte = false
    /// Einmal gelesen — die Begründung steht bei `bewegteKennungen()`.
    @State private var bewegte: Set<String> = []

    private var gefilterte: [Icon] {
        _ = aktualisierung
        return sammlungen.flatMap { $0.alle() }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .gefiltert(Iconfilter(suche: suche, kante: filterkante, nurBewegte: nurBewegte),
                       bewegt: { bewegte.contains($0.kennung) })
    }

    /// Den Bestand einmal nach Bewegung fragen — beim Öffnen des Blattes und
    /// nach jeder Änderung am Bestand.
    private func bewegungLesen() {
        bewegte = sammlungen.flatMap { $0.alle() }.bewegteKennungen()
    }

    /// Das Mindestmass einer Kachel. `@ScaledMetric` laesst es mit der
    /// eingestellten Textgroesse wachsen — sonst braeche der Name darunter um,
    /// sobald jemand „Groessere Schrift" waehlt, waehrend die Kachel bliebe.
    @ScaledMetric(relativeTo: .caption2) private var kachelkante: Double = 72

    var body: some View {
        HStack(spacing: 4) {
            Button { zeigeBlatt = true } label: {
                HStack(spacing: 6) {
                    if let icon = gewaehltesIcon {
                        Rasterbild(datei: icon.datei, breite: icon.kante, hoehe: icon.kante,
                                   kante: 16 / Double(icon.kante))
                            // Das Bildchen gibt nicht nach: Ohne das schrumpft
                            // es, sobald der Name mehr Platz will — und gerade
                            // das Bildchen ist die Auskunft, welches Icon
                            // gewaehlt ist. Der Name ist die Zugabe.
                            .layoutPriority(1)
                        // Eine Zeile, abgeschnitten: „Moon cloud soleil nuage"
                        // brach im schmalen Inspektor auf vier Zeilen um und
                        // drueckte das Bildchen zu einem Fleck zusammen. Ein
                        // Name, der nicht ganz passt, ist als Anfang immer
                        // noch lesbar; ein Icon, das zum Fleck wird, ist es
                        // nicht mehr.
                        Text(icon.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Image(systemName: "photo")
                        Text("Icon wählen…").lineLimit(1)
                    }
                }
            }
            .knopfBefehl()
            if gewaehltesIcon != nil {
                // Das bloße Zeichen, ohne Beschriftung: Es steht unmittelbar
                // neben dem Namen des gewaehlten Icons; was es tut, sagt dort
                // seine Form. Eine Beschriftung daneben machte zuvor aus einer
                // Wertzeile zwei Knoepfe mit Text.
                //
                // Gedaempft und `.plain`: Der Hauptknopf (Icon wechseln) bleibt
                // im Vordergrund, und unter iPadOS faerbt ein fehlender Stil die
                // Beschriftung in der Akzentfarbe — ein blaues Zeichen neben
                // einem blauen Namen las sich als Verweis mit Schliessknopf.
                // Gewaehlt ist aber ein Wert, kein Verweis.
                //
                // Zwei Trefferflaechen und nicht ein Chip mit (x) darin:
                // Wechseln und Abwaehlen sind zwei Handlungen.
                Button { gewaehltesIcon = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(lok("Icon entfernen"))
                .accessibilityLabel(Text("Icon entfernen"))
            }
            // Ein schon gewaehltes Icon wird nicht von selbst abgewaehlt, wenn
            // man auf eine Uhr umschaltet, die es nicht nimmt: Eine stille
            // Aenderung der Wahl waere schlimmer als eine sichtbare Warnung.
            // Das Dreieck sagt, warum nichts ankaeme; weggenommen wird die
            // Wahl nur von Hand.
            if let icon = gewaehltesIcon, let grund = sperre(icon.kante) {
                Hilfezeichen(grund, warnung: true)
            }
        }
        .sheet(isPresented: $zeigeBlatt) { blatt.onAppear { bewegungLesen() } }
    }

    private var blatt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon wählen").font(.headline)
            TextField("Suchen", text: $suche)
                .eingabefeld(loeschbar: $suche)
            Filterleiste(wert: $filterkante,
                         angebot: [(Leinwandgroesse.icon8.beschriftung,
                                    Leinwandgroesse.icon8.kurzbeschriftung, 8),
                                   (Leinwandgroesse.icon16.beschriftung,
                                    Leinwandgroesse.icon16.kurzbeschriftung, 16)],
                         nurBewegte: $nurBewegte)
            ScrollView {
                // 72 statt 44: Die Kacheln waren so gross wie eine
                // Trefferflaeche mindestens sein muss — und damit so klein,
                // dass ein 8×8-Motiv zu raten war. Am Telefon nimmt eine
                // Kachel ein Fuenftel der Breite; hier ist die entsprechende
                // Groesse ein Raster, das sich an 72 Punkten ausrichtet.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: kachelkante))], spacing: 10) {
                    // Waehlen schliesst das Blatt: Es blieb zuvor offen, und
                    // man musste danach noch „Schliessen" druecken — zwei
                    // Handgriffe fuer eine Entscheidung. Ein Blatt, das nur
                    // eine Wahl treffen soll, ist mit der Wahl fertig; so
                    // halten es die Blaetter des Systems auch.
                    //
                    // Der Papierkorb in der Kachel schliesst ausdruecklich
                    // nicht: Er oeffnet eine Rueckfrage, und ein Blatt, das
                    // unter seiner eigenen Rueckfrage wegfaellt, nimmt sie
                    // mit.
                    Button { gewaehltesIcon = nil; zeigeBlatt = false } label: { Text("ohne").font(.caption) }
                        .knopfBefehl()
                    ForEach(gefilterte, id: \.kennung) { icon in
                        ZStack(alignment: .topTrailing) {
                            Button { gewaehltesIcon = icon; zeigeBlatt = false } label: {
                                VStack(spacing: 2) {
                                    // Beide Groessen gleich gross zeigen: Ein
                                    // 16×16 ist nicht das doppelt so grosse
                                    // Bild, sondern das feinere.
                                    Rasterbild(datei: icon.datei, breite: icon.kante, hoehe: icon.kante,
                                               kante: 64 / Double(icon.kante))
                                    // Dasselbe Zeichen wie in der
                                    // Bestandsliste, nur gibt es hier keine
                                    // Groessenzeile — also neben den Namen.
                                    // Nicht ins Bildchen: Bei 36 Punkten
                                    // Kantenlaenge verdeckte es das Motiv.
                                    HStack(spacing: 2) {
                                        if bewegte.contains(icon.kennung) {
                                            Image(systemName: "play.fill")
                                                .accessibilityLabel(Text("bewegt"))
                                        }
                                        Text(icon.name).lineLimit(1)
                                    }
                                    .font(.caption2)
                                }
                            }
                            .buttonStyle(.plain)
                            // Gesperrt, nicht verschwunden: Wer sein 16×16
                            // sucht, soll sehen, dass es noch da ist — und
                            // warum es gerade nicht geht. Verschwundenes wirkt
                            // verloren.
                            .disabled(sperre(icon.kante) != nil)
                            .opacity(sperre(icon.kante) == nil ? 1 : 0.35)
                            .help(sperre(icon.kante) ?? icon.name)
                            .padding(4)
                            .background(gewaehltesIcon?.kennung == icon.kennung ? Color.accentColor.opacity(0.25) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            Button { zuLoeschen = icon } label: {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(lokf("„%@“ löschen", icon.name))
                            .accessibilityLabel(lokf("„%@“ löschen", icon.name))
                            .offset(x: 2, y: -2)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Schließen") { zeigeBlatt = false }
                    .knopfHaupthandlung()
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 460, minHeight: 420)
        .confirmationDialog(
            "„\(zuLoeschen?.name ?? "")“ löschen?",
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            presenting: zuLoeschen
        ) { icon in
            Button("Löschen", role: .destructive) { loeschen(icon) }
        } message: { icon in
            Text(lokf("Das Icon „%@“ wird endgültig entfernt.", icon.name))
        }
    }

    private func loeschen(_ icon: Icon) {
        // Jede Sammlung raeumt nur ihren eigenen Ordner (`istEigen`) — welche
        // es ist, entscheidet also sie selbst und nicht diese Ansicht.
        guard let heimat = sammlungen.first(where: { $0.istEigen(icon) }),
              (try? heimat.loeschen(icon)) != nil else { return }
        // War das geloeschte Icon gerade gewaehlt, faellt die Wahl auf „ohne"
        // zurueck — es gibt danach schlicht nichts mehr, worauf sie zeigen koennte.
        if gewaehltesIcon?.kennung == icon.kennung { gewaehltesIcon = nil }
        aktualisierung += 1
        bewegungLesen()
    }
}
