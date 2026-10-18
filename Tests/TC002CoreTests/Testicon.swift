import Foundation
@testable import TC002Core

/// Legt ein Icon in einem frischen Ordner unter dem temporären Verzeichnis an —
/// nie im Bestand der App.
enum Testicon {
    /// `pixel` ist `kante × kante` groß, zeilenweise von oben links; ohne Angabe
    /// sind die erste und die letzte Zelle gesetzt (Tinte über die volle Breite).
    static func anlegen(nummer: String = "pruef", kante: Int = 8, pixel: [String?]? = nil) throws -> Icon {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let sammlung = Iconsammlung(ordner: ordner, kante: kante)
        var p = pixel ?? [String?](repeating: nil, count: kante * kante)
        if pixel == nil {
            p[0] = "#FF0000"
            p[kante * kante - 1] = "#00FF66"
        }
        return try sammlung.sichern(nummer: nummer, name: nummer, pixel: p)
    }

    /// Ein Icon mit Tinte nur in den Spalten `spalten` (jede Zeile), sonst leer.
    static func inSpalten(_ spalten: ClosedRange<Int>, kante: Int = 8, nummer: String = "spalten") throws -> Icon {
        var p = [String?](repeating: nil, count: kante * kante)
        for y in 0..<kante { for x in spalten { p[y * kante + x] = "#FF0000" } }
        return try anlegen(nummer: nummer, kante: kante, pixel: p)
    }
}
