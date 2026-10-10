#if canImport(AppKit)
import XCTest
import SwiftUI
import AppKit
import TC002Core
import TC002Modell
@testable import TC002Ansichten

/// Der Blaetterer darf beim ersten Layout keine Kette von Neuberechnungen
/// anstossen. Gemessen wird in einem echten `NSHostingView`, ohne Netz: Die
/// Uhren tragen Adressen, die nie angefragt werden, der Schluesselbund ist ein
/// Doppelgaenger.
@MainActor
final class BlaettererLayoutTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "zielIDs", "grabsteine"]
    private var sicherung: [String: Any?] = [:]

    private struct LeererSchluesselbund: Schluesselbundzugriff {
        func lesen(_ konto: String) -> String? { nil }
        func setzen(_ wert: String, fuer konto: String) -> Bool { true }
        func vorhanden(_ konto: String) -> Bool { false }
    }

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        for s in schluessel {
            if let w = sicherung[s] ?? nil { d.set(w, forKey: s) } else { d.removeObject(forKey: s) }
        }
        super.tearDown()
    }

    private func zustand(uhren anzahl: Int, aktiv: Int) throws -> AppZustand {
        let uhren = (0..<anzahl).map { Uhr(name: "Uhr \($0)", host: "uhr\($0).invalid") }
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(uhren[aktiv].id.uuidString, forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        return AppZustand(schluesselbund: LeererSchluesselbund(), wolkeGewaehlt: false)
    }

    /// Haengt den Blaetterer in ein Fenster und laesst die Laufschleife `sekunden` laufen.
    private func laufenLassen(_ z: AppZustand, sekunden: Double) -> (aufrufe: Int, aktivEnde: UUID?) {
        _ = NSApplication.shared
        var aufrufe = 0
        let wurzel = VStack {
            GeometryReader { geo in
                Uhrenblaetterer(zustand: z) { uhr, angesehen in
                    aufrufe += 1
                    let o = Meldungsoptionen(text: "Hallo Welt \(uhr.name)")
                    let mass = Anzeigemass.fuer(uhr)
                    let f = Meldungsbau.feld(o, mitIcon: false, mass: mass)
                    return Text("\(f.breite) \(angesehen ? 1 : 0)")
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .aspectRatio(3.25, contentMode: .fit)
            .frame(maxWidth: .infinity)
            Text("unten")
        }.frame(width: 600, height: 300)
        let fenster = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
                               styleMask: [.titled], backing: .buffered, defer: false)
        fenster.isReleasedWhenClosed = false
        fenster.contentView = NSHostingView(rootView: wurzel)
        fenster.orderBack(nil)
        let ende = Date().addingTimeInterval(sekunden)
        while Date() < ende { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        fenster.close()
        return (aufrufe, z.aktiveID)
    }

    func testErstesLayoutMitVierUhrenBleibtBeiDerGewaehlten() throws {
        let z = try zustand(uhren: 4, aktiv: 2)
        let gewaehlt = z.aktiveID
        let (aufrufe, ende) = laufenLassen(z, sekunden: 1.5)
        print("MESSUNG aufrufe=\(aufrufe) bleibt=\(ende == gewaehlt)")
        XCTAssertEqual(ende, gewaehlt)
        XCTAssertLessThan(aufrufe, 40)
    }
}
#endif
