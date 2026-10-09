import SwiftUI
import TC002Core

/// Eine Abbildung in der Hilfe.
///
/// Gezeichnet wird sie aus denselben Ansichten wie die App selbst
/// (`VorschauView`, `Slotblock`, `Geraetezeichnung`), nicht aus abgelegten
/// Bilddateien. Damit folgt sie Sprache, Erscheinungsbild und jeder Änderung
/// an der Darstellung; eine aufgenommene Abbildung täte das nicht und wäre
/// beim nächsten Umbau still falsch.
public enum Hilfebild: String, CaseIterable, Sendable, Identifiable {
    /// Kurzer Text steht, langer läuft — die Regel aus `Meldungsbau.passt`.
    case stehtOderLaeuft
    /// Die drei Zustände eines Platzblocks: frei, bekannt, belegt ohne Inhalt.
    case slotzustaende
    /// Was die waagrechte und die senkrechte Ausrichtung tun.
    case ausrichtung
    /// Das Eingabefeld mit Löschzeichen und Sendeknopf.
    case sendezeile

    public var id: String { rawValue }
}

/// Zeichnet ein `Hilfebild` samt Beschriftungen.
struct HilfebildView: View {
    let bild: Hilfebild

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch bild {
            case .stehtOderLaeuft: stehtOderLaeuft
            case .slotzustaende: slotzustaende
            case .ausrichtung: ausrichtung
            case .sendezeile: sendezeile
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Die Abbildungen

    private var stehtOderLaeuft: some View {
        VStack(alignment: .leading, spacing: 12) {
            beschriftet(lok("Passt in die Breite: der Text steht.")) {
                anzeige(Self.kurz)
            }
            beschriftet(lok("Passt nicht: der Text läuft durch.")) {
                LaufabbildungView(optionen: Self.lang)
            }
        }
    }

    private var slotzustaende: some View {
        HStack(alignment: .top, spacing: 14) {
            block(1, .frei, lok("frei"))
            block(2, .bekannt(Meldungsbau.feld(Self.kurz, mitIcon: false).punkteRoh), lok("belegt, Inhalt bekannt"))
            block(3, .unbekannt, lok("belegt, Inhalt unbekannt"))
        }
    }

    private var ausrichtung: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                beschriftet(lok("links")) { anzeige(Self.kurz.mit(waagrecht: .links)) }
                beschriftet(lok("mittig")) { anzeige(Self.kurz.mit(waagrecht: .mittig)) }
                beschriftet(lok("rechts")) { anzeige(Self.kurz.mit(waagrecht: .rechts)) }
            }
            HStack(alignment: .top, spacing: 12) {
                beschriftet(lok("oben")) { anzeige(Self.kurz.mit(senkrecht: .oben)) }
                beschriftet(lok("mittig")) { anzeige(Self.kurz.mit(senkrecht: .mittig)) }
                beschriftet(lok("unten")) { anzeige(Self.kurz.mit(senkrecht: .unten)) }
            }
        }
    }

    /// Das Eingabefeld, wie es wirklich aussieht — mit dem Löschzeichen links
    /// und dem Sendeknopf rechts.
    ///
    /// Beim ersten Anwendertest wurde der Knopf nicht als Schaltfläche
    /// erkannt; eine Abbildung davon ist deshalb nicht Zierat, sondern die
    /// Antwort auf eine Frage, die wirklich gestellt wurde.
    private var sendezeile: some View {
        beschriftet(lok("Die Eingabetaste schickt — oder der blaue Knopf rechts. Das ⊗ daneben leert das Feld.")) {
            TextField("Text", text: .constant(lok("Hallo")))
                .font(.title2)
                .controlSize(.extraLarge)
                .eingabefeld(loeschbar: .constant(lok("Hallo")),
                             senden: {},
                             laeuft: false)
                .disabled(true)
                .frame(maxWidth: 360)
        }
    }

    // MARK: - Bausteine

    /// Die Vorschau, wie sie über dem Eingabefeld steht — nur kleiner.
    private func anzeige(_ o: Meldungsoptionen) -> some View {
        VorschauView(feld: Meldungsbau.feld(o, mitIcon: false),
                     kantenlaenge: Self.punktgroesse)
    }

    private func block(_ platz: Int, _ zustand: Slotzustand, _ text: String) -> some View {
        beschriftet(text) {
            Slotblock(platz: platz, zustand: zustand, gewaehlt: false)
                .frame(width: 96)
        }
    }

    private func beschriftet<Inhalt: View>(_ text: String,
                                           @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            inhalt()
            // Schon nachgeschlagen (siehe Aufrufer) — sonst waere der Schluessel
            // eine Variable, und die findet `scripts/texte-sammeln.py` nicht.
            Text(verbatim: text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// So groß, dass die einzelnen Punkte noch zu erkennen sind, und schmal
    /// genug, dass zwei Anzeigen nebeneinander in die Detailspalte passen.
    private static let punktgroesse = 3.0

    private static let kurz = Meldungsoptionen(text: "Hallo")
    private static let lang = Meldungsoptionen(text: "Ein längerer Text läuft durch")
}

/// Der laufende Text als Abbildung.
///
/// Die Einzelbilder werden hier gerechnet und nicht mitgeliefert; das ist
/// dieselbe Rechnung, die vor dem Senden läuft (`Meldungsbau.laufschriftBilder`),
/// und sie gehört nicht auf den Hauptthread.
private struct LaufabbildungView: View {
    let optionen: Meldungsoptionen
    @State private var bilder: [Bildraster.Einzelbild] = []

    var body: some View {
        VorschauView(feld: Pixelfeld(breite: Anzeigemass.vorgabe.breite,
                                     hoehe: Anzeigemass.vorgabe.hoehe),
                     kantenlaenge: 3.0,
                     laufschriftBilder: bilder.isEmpty ? nil : bilder)
            .task {
                let o = optionen
                bilder = await Task.detached(priority: .utility) {
                    Meldungsbau.laufschriftBilder(o, iconBilder: [])
                }.value
            }
    }
}

extension Meldungsoptionen {
    /// Dieselben Optionen mit einer geänderten Ausrichtung — nur für die
    /// Abbildungen, die drei Stellungen desselben Textes zeigen.
    func mit(waagrecht: SendenHAusrichtung? = nil,
             senkrecht: SendenVAusrichtung? = nil) -> Meldungsoptionen {
        var o = self
        if let waagrecht { o.waagrecht = waagrecht }
        if let senkrecht { o.senkrecht = senkrecht }
        return o
    }
}
