import SwiftUI
import TC002Core

/// Wie gross die naechste Nutzlast wird — und eine Warnung, sobald sie
/// auffaellig gross wird.
///
/// Wo die Uhr aussteigt, weiss niemand: Die Geraetereferenz nennt keine Grenze
/// (§4.2a). Deshalb steht hier der Stand und keine Zusage — wie viele
/// Einzelbilder es sind, wie viele Kilobyte daraus werden, und ab `heikelAb`
/// ein Satz darueber, was daran kleiner hilft. Eine Zeile, kein Absatz; die
/// Erklaerung steht in der Hilfe.
///
/// Eine Fassung fuer „Senden" und fuer den Editor. Zwei nebeneinander waeren
/// zwei Schwellen, die auseinanderlaufen, und zwei Uebersetzungsschluessel
/// fuer dieselbe Aussage. Was sich zwischen den beiden Stellen wirklich
/// unterscheidet, sind genau zwei Angaben: wie das Gebilde heisst und was es
/// kleiner macht — die stehen deshalb als Argument da.
struct Nutzlastzeile: View {
    /// Ab hier wird gewarnt. Die Zahl ist gesetzt, nicht gemessen — ein
    /// Lauf-GIF lag in der Messung bei 23 KB, und die Uhr nahm es. Sie soll
    /// aufmerksam machen, nicht verbieten.
    static let heikelAb = 60_000

    /// Wie das heisst, was da zusammenkommt — „Laufschrift" oder „Animation".
    /// Schon uebersetzt (`lok`), nicht erst hier: Ein Ternaer am Aufrufort
    /// schluege sonst nichts nach.
    let art: String
    let bilder: Int
    let bytes: Int
    /// Was die Nutzlast kleiner macht. Steht nur im Warnfall da.
    let rat: String

    /// „unter 1 KB", solange die erste nicht voll ist: Eine Nachkommastelle
    /// waere genauer, als die Sache ist.
    static func groesse(_ bytes: Int) -> String {
        bytes < 1024 ? lok("unter 1 KB Nutzlast")
                     : lokf("rund %d KB Nutzlast", bytes / 1024)
    }

    /// Der Stand als ein Satz. Einmal geschrieben, weil ihn zwei Stellen
    /// sagen: diese Zeile im Warnfall und der Einblendtext am Sendezeichen,
    /// wo er die Antwort auf „was passiert, wenn ich druecke" ist.
    static func stand(art: String, bilder: Int, bytes: Int) -> String {
        lokf("%@ · %d Bilder · %@", art, bilder, Self.groesse(bytes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.stand(art: art, bilder: bilder, bytes: bytes))
                .foregroundStyle(.secondary)
            if bytes > Self.heikelAb {
                Label(lokf("Eine auffällig große Nutzlast — %@", rat),
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
    }
}
