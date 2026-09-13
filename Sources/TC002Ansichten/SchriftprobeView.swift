import SwiftUI
import TC002Core

/// Die Schriftprobe: warum der Schieber diese Größen anbietet und jene nicht.
///
/// Ein Nachschlagewerk, keine Bedienoberfläche — deshalb steht hier Erklärung.
/// Sie **entscheidet nichts**: Gezeigt wird die Messung, und was daraus folgt,
/// sieht man mit eigenen Augen. „Nichts fällt zusammen“ heißt nicht „gut“.
///
/// Plattformfrei wie alles in diesem Ziel: Die Pixel zeichnet `Canvas`, nicht
/// AppKit — dieselbe Ansicht taugt später fürs iPad und fürs iPhone, wo es
/// bisher gar keine Referenz gibt.
public struct SchriftprobeView: View {
    /// Welche Größen der Schieber je Schrift anbietet — dieselbe Form wie
    /// `SendenView.sauberePixelgroessen`: Eine Schrift, die nicht darin steht,
    /// ist in jeder Größe zu haben. Die Ansicht **kennt die Regel nicht**, sie
    /// bekommt sie gereicht; entschieden wird darüber in der Sendeansicht.
    private let angeboteneGroessen: [String: [Double]]

    @State private var messungen: [Schriftprobe.Messung] = []

    public init(angeboteneGroessen: [String: [Double]] = [:]) {
        self.angeboteneGroessen = angeboteneGroessen
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                einleitung
                if messungen.isEmpty {
                    ProgressView(lok("Die Schriften werden vermessen …"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    ForEach(Schriftprobe.mitgelieferteSchriften, id: \.self) { schrift in
                        abschnitt(schrift)
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 520)
        // Die Messung rastert dreiundsiebzig Zeichen je Schrift und Groesse und
        // braucht rund sechs Zehntelsekunden. Im `body` waere das ein
        // haengendes Fenster, deshalb einmal beim Erscheinen und abseits des
        // Hauptthreads. `Schriftprobe.alleMessungen` merkt sich das Ergebnis,
        // ein zweites Oeffnen ist danach sofort da.
        .task {
            let ergebnis = await Task.detached(priority: .userInitiated) {
                Schriftprobe.alleMessungen()
            }.value
            messungen = ergebnis
        }
    }

    // MARK: - Text

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
        VStack(alignment: .leading, spacing: 12) {
            Text(schrift).font(.title3.weight(.semibold))
            ForEach(messungen.filter { $0.schrift == schrift }) { messung in
                block(messung)
            }
        }
    }

    /// Bietet der Schieber diese Größe an? Fehlt die Schrift in der Tabelle,
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
