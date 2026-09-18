import XCTest
@testable import TC002Ansichten

/// Die Titel der vier Nebenfenster.
final class NebenfensterTests: XCTestCase {
    /// Ein Fenstertitel benennt das Fenster, nicht das Programm.
    ///
    /// „Über MQTT-TC002“ stand am iPad in der Kopfzeile unmittelbar über einem
    /// Inhalt, der den Programmnamen noch einmal groß zeigt — am Mac genauso,
    /// nur in der Titelleiste. Der Programmname gehört in den Menüeintrag,
    /// der das Fenster öffnet, nicht in den Titel des Fensters selbst.
    func testKeinTitelWiederholtDenProgrammnamen() {
        for fenster in Nebenfenster.allCases {
            XCTAssertFalse(fenster.rawValue.contains("MQTT-TC002"),
                           "„\(fenster.rawValue)“ wiederholt den Programmnamen, der im Inhalt schon steht")
        }
    }
}
