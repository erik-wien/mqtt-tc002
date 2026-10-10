import SwiftUI
import TC002Core

/// Der Schalter „Schrift der Uhr": aus rastert die App den Text selbst und
/// schickt ein Bild, an setzt die Uhr ihn mit ihrer eigenen Schrift
/// (`SendeWeg.text`). Eine Zeile für Mac, iPad und iPhone, damit beide
/// Oberflächen dieselbe Beschriftung und denselben Hilfetext tragen.
///
/// Die Erklärung hängt an einem (?) neben dem Namen: Der Schalter ändert, was
/// sich sonst noch bedienen lässt, und das muss am Finger ebenso nachzulesen
/// sein wie am Zeiger.
public struct SchriftDerUhrSchalter: View {
    @Binding var weg: SendeWeg

    public init(weg: Binding<SendeWeg>) {
        self._weg = weg
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text("Schrift der Uhr")
            Hilfezeichen(AwtrixNG.schriftDerUhrHilfe)
            Spacer(minLength: 8)
            Toggle("Schrift der Uhr", isOn: $weg.schriftDerUhr)
                .labelsHidden()
        }
    }
}
