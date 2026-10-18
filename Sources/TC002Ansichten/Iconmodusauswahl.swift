import SwiftUI
import TC002Core

/// „Icon mitscrollen“ mit drei Stellungen: fest, einmal, mit (`Iconmodus`). Für
/// den Inspektor am Mac und iPad und das Blatt am iPhone gemeinsam; nur die
/// Anordnung der Zeile gehört der Oberfläche.
///
/// „Einmal mitscrollen“ gibt es nur mit der Schrift der Uhr
/// (`Iconmodus.wirkt(weg:)`). Es bleibt im Menü, grau, weil der Nutzer den
/// Schalter „Schrift der Uhr“ selbst einschalten kann; der Grund steht hinter dem
/// (?) neben der Zeile. `modus` liefert, was auf dem gewählten Weg gilt
/// (`Iconmodus.wirksam(weg:)`), damit keine gesperrte Stellung als gewählt
/// erscheint.
public struct Iconmodusauswahl: View {
    @Binding var modus: Iconmodus
    let weg: SendeWeg
    /// Ohne Icon oder bei Text, der ins Display passt, gibt es nichts zu wählen.
    let gesperrt: Bool

    public init(modus: Binding<Iconmodus>, weg: SendeWeg, gesperrt: Bool) {
        _modus = modus
        self.weg = weg
        self.gesperrt = gesperrt
    }

    public var body: some View {
        HStack {
            Picker("Icon mitscrollen", selection: $modus) {
                Text("Fest").tag(Iconmodus.fest)
                Text("Einmal mitscrollen").tag(Iconmodus.einmal)
                    .disabled(!Iconmodus.einmal.wirkt(weg: weg))
                Text("Mitscrollen").tag(Iconmodus.mit)
            }
            .disabled(gesperrt)
            Hilfezeichen(Self.hilfe)
        }
    }

    static var hilfe: String {
        lok("Gilt nur, wenn der Text nicht ins Display passt und deshalb durchläuft. „Einmal mitscrollen“ schiebt der Text das Icon einmal hinaus, danach bleibt es weg; das gibt es nur mit „Schrift der Uhr“.")
    }
}
