import Foundation
import XCTest
@testable import TC002Ansichten

/// Welche abgelegten Dateien die Klangsammlung annimmt.
final class KlangablageTests: XCTestCase {
    func testNimmtMP3RtttlUndText() {
        for name in ["a.mp3", "A.MP3", "ping.rtttl", "ping.txt"] {
            XCTAssertTrue(Klangsammlungsansicht.angenommen(URL(fileURLWithPath: "/x/\(name)")), name)
        }
    }

    func testWeistAnderesAb() {
        for name in ["a.png", "a.wav", "a.pdf", "ohne"] {
            XCTAssertFalse(Klangsammlungsansicht.angenommen(URL(fileURLWithPath: "/x/\(name)")), name)
        }
    }
}
