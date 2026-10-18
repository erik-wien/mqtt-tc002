import XCTest
@testable import TC002Core

final class ProbehoerenTests: XCTestCase {
    private let ohneRtttl = Geraetefaehigkeiten(ton: Tonfaehigkeiten(mp3: false, rtttl: false, song: false, speech: false,
                                                                    radio: false, url: false, effect: false, clip: false, track: false))
    private func uhr(_ name: String, host: String = "uhr.test", lautsprecher: Bool? = nil, modell: Uhrmodell? = nil) -> Uhr {
        Uhr(name: name, host: host, modell: modell, lautsprecher: lautsprecher)
    }

    func testInfrageKommenUhrenMitAdresseUndLautsprecher() {
        let a = uhr("A"), b = uhr("B", host: ""), c = uhr("C"), d = uhr("D", lautsprecher: false, modell: .esp32DIY)
        let f = [c.id: ohneRtttl]
        XCTAssertEqual(Probehoeren.uhren([a, b, c, d], faehigkeiten: f).map(\.name), ["A"])
    }

    func testUnbekannteFaehigkeitIstErlaubt() {
        XCTAssertEqual(Probehoeren.uhren([uhr("A")], faehigkeiten: [:]).count, 1)
    }

    func testVorgabeIstDieGezeigteUhrSonstDieErste() {
        let a = uhr("A"), b = uhr("B")
        XCTAssertEqual(Probehoeren.vorgabe(unter: [a, b], gezeigt: b.id), b.id)
        XCTAssertEqual(Probehoeren.vorgabe(unter: [a, b], gezeigt: UUID()), a.id)
        XCTAssertEqual(Probehoeren.vorgabe(unter: [a, b], gezeigt: nil), a.id)
        XCTAssertNil(Probehoeren.vorgabe(unter: [], gezeigt: a.id))
    }

    func testWahlGiltSolangeSieInfrageKommt() {
        let a = uhr("A"), b = uhr("B")
        XCTAssertEqual(Probehoeren.ziel(gewaehlt: a.id, unter: [a, b], gezeigt: b.id), a.id)
        XCTAssertEqual(Probehoeren.ziel(gewaehlt: UUID(), unter: [a, b], gezeigt: b.id), b.id)
    }

    func testHinweisNurWennAdresseDasHindernisIst() {
        let ohneAdresse = uhr("A", host: "")
        XCTAssertTrue(Probehoeren.brauchtAdresse([ohneAdresse], faehigkeiten: [:]))
        XCTAssertFalse(Probehoeren.brauchtAdresse([ohneAdresse, uhr("B")], faehigkeiten: [:]))
        XCTAssertFalse(Probehoeren.brauchtAdresse([], faehigkeiten: [:]))
        let stumm = uhr("S", host: "", lautsprecher: false, modell: .esp32DIY)
        XCTAssertFalse(Probehoeren.brauchtAdresse([stumm], faehigkeiten: [:]))
        let ohne = uhr("O", host: "")
        XCTAssertFalse(Probehoeren.brauchtAdresse([ohne], faehigkeiten: [ohne.id: ohneRtttl]))
    }
}
