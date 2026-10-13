import SwiftUI

/// Das Zeichen „8+16" neben dem Namen eines Icons, das es in beiden Größen
/// gibt (`Iconbestaende.paarkennungen`). Neben dem Namen und nicht im Bild,
/// aus demselben Grund wie das Abspielzeichen: Im Bild verdeckte es das Motiv.
public struct Paarzeichen: View {
    public init() {}
    public var body: some View {
        Text(verbatim: "8+16")
            .help("Gibt es auch in der anderen Größe; eine Uhr mit acht Zeilen bekommt das 8 × 8.")
            .accessibilityLabel(Text("Gibt es auch in der anderen Größe; eine Uhr mit acht Zeilen bekommt das 8 × 8."))
    }
}
