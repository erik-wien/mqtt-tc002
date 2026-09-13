import SwiftUI
import TC002Core

/// Was die Kopfzeile der Schriftprobe zeigt: alle Schriften oder eine einzige.
///
/// Ein eigener Typ und kein `String?`, damit „Alle“ eine Stellung ist und kein
/// Sonderfall — und damit die Zusicherung geprüft werden kann, ohne eine
/// SwiftUI-Ansicht zu bauen.
public enum Schriftwahl: Hashable {
    case alle
    case nur(String)

    /// Was zu zeigen ist. **Gefiltert wird nur**: Die Messung liegt fertig vor,
    /// die Wahl sucht daraus aus und rechnet nichts nach. Eine Schrift, die es
    /// im Vorrat nicht gibt, ergibt nichts — und nicht sich selbst.
    public func schriften(aus vorrat: [String]) -> [String] {
        switch self {
        case .alle: return vorrat
        case .nur(let schrift): return vorrat.filter { $0 == schrift }
        }
    }
}

/// Die Schriftprobe: warum das Größenmenü diese Größen anbietet und jene nicht.
///
/// Ein Nachschlagewerk, keine Bedienoberfläche — deshalb steht hier Erklärung.
/// Sie **entscheidet nichts**: Gezeigt wird die Messung, und was daraus folgt,
/// sieht man mit eigenen Augen. „Nichts fällt zusammen“ heißt nicht „gut“.
///
/// Plattformfrei wie alles in diesem Ziel: Die Pixel zeichnet `Canvas`, nicht
/// AppKit — dieselbe Ansicht taugt später fürs iPad und fürs iPhone, wo es
/// bisher gar keine Referenz gibt.
public struct SchriftprobeView: View {
    /// Welche Größen das Größenmenü je Schrift anbietet — dieselbe Form wie
    /// `Pixelgroessen.abgesegnet`: Eine Schrift, die nicht darin steht, ist in
    /// jeder Größe zu haben. Die Ansicht **kennt die Regel nicht**, sie bekommt
    /// sie gereicht; entschieden hat darüber ein Augenpaar beim Durchsehen
    /// dieser Seite, nicht die Messung darunter.
    private let angeboteneGroessen: [String: [Double]]

    @State private var messungen: [Schriftprobe.Messung] = []

    /// Die Wahl aus der Kopfzeile. Sie filtert die fertige Messung und löst
    /// keine neue aus — deshalb steht sie hier und nicht in `.task`.
    @State private var wahl: Schriftwahl = .alle

    public init(angeboteneGroessen: [String: [Double]] = [:]) {
        self.angeboteneGroessen = angeboteneGroessen
    }

    public var body: some View {
        VStack(spacing: 0) {
            kopfzeile
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    einleitung
                    if messungen.isEmpty {
                        ProgressView(lok("Die Schriften werden vermessen …"))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(wahl.schriften(aus: Schriftprobe.schriften), id: \.self) { schrift in
                            abschnitt(schrift)
                        }
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(24)
            }
        }
        // Nur am Mac. Ganzflaechig auf einem iPad reichen 560 Punkte immer;
        // in Slide Over (rund 320) nicht, und dort schnitte die Forderung die
        // Tabellen rechts ab, statt sie rollen zu lassen.
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 520)
        #endif
        // Die Messung rastert dreiundsiebzig Zeichen je Schrift und Groesse —
        // acht Schriften, elf Groessen, rund sechs Zehntelsekunden. Im `body`
        // waere das ein haengendes Fenster, deshalb einmal beim Erscheinen und
        // abseits des Hauptthreads. `Schriftprobe.alleMessungen` merkt sich das
        // Ergebnis, ein zweites Oeffnen ist danach sofort da.
        //
        // Ohne `id:`, und das ist der Punkt: Die Schriftwahl oben filtert
        // dieses fertige Ergebnis, sie stoesst keine zweite Messung an
        // (`SchriftwahlTests`).
        .task {
            let ergebnis = await Task.detached(priority: .userInitiated) {
                Schriftprobe.alleMessungen()
            }.value
            messungen = ergebnis
        }
    }

    // MARK: - Text

    /// Die Kopfzeile: die Schriftwahl, sonst nichts.
    ///
    /// Sie bleibt beim Rollen stehen, weil sie sonst nichts nützte —
    /// achtundachtzig Blöcke (acht Schriften mal elf Größen) liegen in einem
    /// durchgehenden Lauf, und wer unten bei Tiny5 steht, findet eine Wahl
    /// nicht wieder, die oben im Inhalt mitgescrollt ist.
    ///
    /// Ein Aufklappmenü und keine segmentierte Wahl: Neun Stellungen nebeneinander
    /// bekommt weder ein schmales Fenster noch ein geteiltes iPad unter.
    private var kopfzeile: some View {
        Picker("Schrift", selection: $wahl) {
            Text("Alle").tag(Schriftwahl.alle)
            ForEach(Schriftprobe.schriften, id: \.self) { schrift in
                Text(verbatim: schrift).tag(Schriftwahl.nur(schrift))
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var einleitung: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Warum eigene Schriften?")
                .font(.title3.weight(.semibold))
            Text("Die eingebaute Schrift der Uhr kennt keine Umlaute. Wer „Grüße“ schreiben will, muss den Text selbst in Pixel wandeln — genau das tut diese App auf dem Weg „als Pixel“, mit einer der drei mitgelieferten Pixelschriften.")
            Text("Warum nicht jede Größe?")
                .font(.title3.weight(.semibold))
            Text("Die Anzeige ist 52 × 16 Pixel groß. Auf so wenigen Punkten rastern verschiedene Zeichen leicht zu genau demselben Bild — dann ist die Unterscheidung weg, und zwar unwiederbringlich, bevor die Uhr etwas davon sieht. Unten steht für jede Schrift und jede Größe, welche Zeichen das trifft, mit den tatsächlichen Pixeln.")
            Text("„Nichts fällt zusammen“ heißt nicht „gut“: Zwei Zeichen können sich um ein einziges Pixel unterscheiden und trotzdem unlesbar sein. Diese Messung kann eine Größe ausschließen, nie empfehlen.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Bausteine

    private func abschnitt(_ schrift: String) -> some View {
        let eigene = messungen.filter { $0.schrift == schrift }
        return VStack(alignment: .leading, spacing: 12) {
            // `Text(verbatim:)`: Schriftnamen sind Eigennamen. Als Schlüssel
            // stünden sie sinnlos in der Sprachdatei und würden übersetzt.
            Text(verbatim: schrift).font(.title3.weight(.semibold))
            // Nicht gemessen heißt hier immer: nicht installiert. CoreText
            // rastert sonst klaglos mit einer Ersatzschrift, und das Ergebnis
            // gehörte dann einer anderen Schrift.
            if eigene.isEmpty {
                Text("Auf diesem Gerät nicht installiert — nicht gemessen.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(eigene) { messung in
                block(messung)
            }
        }
    }

    /// Bietet das Größenmenü diese Größe an? Fehlt die Schrift in der Tabelle,
    /// sind alle Größen zu haben.
    private func angeboten(_ messung: Schriftprobe.Messung) -> Bool {
        angeboteneGroessen[messung.schrift].map { $0.contains(messung.groesse) } ?? true
    }

    private func block(_ messung: Schriftprobe.Messung) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(lokf("%d px", Int(messung.groesse))).font(.headline)
                Spacer()
                Text(angeboten(messung) ? lok("wird angeboten") : lok("wird nicht angeboten"))
                    .font(.caption)
                    .foregroundStyle(angeboten(messung) ? Color.accentColor : .secondary)
            }

            if messung.gruppen.isEmpty {
                Text("Kein Zeichen fällt mit einem anderen zusammen.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Diese Zeichen rastern zu demselben Bild:")
                    .font(.callout).foregroundStyle(.secondary)
                // Untereinander, jede Gruppe fuer sich: nebeneinander waeren
                // die groessten Gruppen (zehn Zeichen bei 16 px) breiter als
                // das Fenster, und abgesetzt gehoeren sie ohnehin.
                ForEach(messung.gruppen) { g in beschriftet(g.text, bild: g.bild) }
                if !messung.weitereGruppen.isEmpty {
                    Text(lokf("und %d weitere Gruppen: %@", messung.weitereGruppen.count,
                              messung.weitereGruppen.joined(separator: ", ")))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let umlautbild = messung.umlautbild {
                Text("Umlaute:").font(.callout).foregroundStyle(.secondary)
                beschriftet(Schriftprobe.umlautprobe, bild: umlautbild)
            }

            ForEach(messung.gruende.map(\.beschreibung), id: \.self) { grund in
                Text(grund).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            beschriftet(Schriftprobe.musterwort, bild: messung.musterbild)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Ein Pixelbild mit der Zeichenfolge darüber. `Text(verbatim:)`, weil hier
    /// Zeichen stehen und kein Satz: „H=K=X“ ist nichts, was übersetzt werden
    /// könnte, und als Schlüssel stünde es sinnlos in der Sprachdatei.
    ///
    /// Waagrecht scrollbar: Das breiteste Raster misst 112 Spalten
    /// („Fußgängerzone“ in Silkscreen 16) und wäre auf einem Telefon und im
    /// schmalsten Fenster sonst abgeschnitten — und ein abgeschnittenes
    /// Pixelbild beantwortet genau die Frage nicht, für die es da ist.
    private func beschriftet(_ text: String, bild: Pixelfeld) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: text)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Pixelgitter(feld: bild)
            }
            .scrollIndicators(.automatic)
        }
    }
}

/// Zeichnet ein Pixelfeld Punkt für Punkt — gesetzte Punkte hell, leere dunkel,
/// wie auf der Uhr. Rein darstellend: kein Rastern, keine eigene Meinung über
/// den Inhalt.
struct Pixelgitter: View {
    let feld: Pixelfeld

    /// Kantenlänge eines Punktes. Groß genug, dass man einzelne Pixel
    /// unterscheidet, klein genug, dass auch das breiteste Raster — 112
    /// Spalten, also 448 pt — in ein Fenster von 560 pt passt.
    private static let kante = 3.0
    private static let fuge = 1.0

    var body: some View {
        let breite = Double(feld.breite) * (Self.kante + Self.fuge)
        let hoehe = Double(feld.hoehe) * (Self.kante + Self.fuge)
        Canvas { kontext, _ in
            for y in 0..<feld.hoehe {
                for x in 0..<feld.breite {
                    let punkt = CGRect(x: Double(x) * (Self.kante + Self.fuge),
                                       y: Double(y) * (Self.kante + Self.fuge),
                                       width: Self.kante, height: Self.kante)
                    kontext.fill(Path(punkt), with: .color(
                        feld.farbe(x: x, y: y) == nil ? .gray.opacity(0.18) : .green))
                }
            }
        }
        .frame(width: breite, height: hoehe)
        .accessibilityHidden(true)
    }
}
