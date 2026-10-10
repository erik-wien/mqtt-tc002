import Foundation
import TC002Core

// Die Ausgabe der Lesebefehle für Klang (`ton zustand`, `ton melodien`, `ton sender`).
// Die Befehle selbst laufen in `steuerbefehl` (Steuerbefehle.swift).

private func wiedergabezeile(_ spielt: Bool, _ name: String) -> String {
    guard spielt else { return lok("aus") }
    return name.isEmpty ? lok("spielt") : lokf("spielt „%@“", Terminaltext.sicher(name))
}

func tonzustandAusgeben(_ z: Tonzustand, ausgabe: (String) -> Void = { print($0) }) {
    func zeile(_ name: String, _ wert: String) { ausgabe("\(name)\t\(wert)") }
    zeile("Radio", wiedergabezeile(z.radio.spielt, z.radio.sender))
    if !z.radio.titel.isEmpty { zeile(lok("Titel"), Terminaltext.sicher(z.radio.titel)) }
    if !z.radio.fehler.isEmpty { zeile(lok("Fehler Radio"), Terminaltext.sicher(z.radio.fehler)) }
    zeile("App", wiedergabezeile(z.app.spielt, z.app.name))
    if !z.app.fehler.isEmpty { zeile(lok("Fehler App"), Terminaltext.sicher(z.app.fehler)) }
    zeile(lok("Alarm"), wiedergabezeile(z.alarm.spielt, z.alarm.name))
    if !z.alarm.fehler.isEmpty { zeile(lok("Fehler Alarm"), Terminaltext.sicher(z.alarm.fehler)) }
    zeile(lok("Sender"), String(z.sender.count))
}

func melodienAusgeben(_ ablage: Tonablage, ausgabe: (String) -> Void = { print($0) }) {
    for name in ablage.namen { ausgabe(Terminaltext.sicher(name)) }
    ausgabe(lokf("%d Melodien", ablage.namen.count))
    if let belegt = ablage.belegteBytes, let gesamt = ablage.gesamteBytes {
        ausgabe(lokf("%d von %d Byte belegt", belegt, gesamt))
    }
}

func senderAusgeben(_ sender: [Radiosender], ausgabe: (String) -> Void = { print($0) }) {
    guard !sender.isEmpty else { ausgabe(lok("Keine Sender.")); return }
    for (i, s) in sender.enumerated() { ausgabe("\(i)\t\(Terminaltext.sicher(s.name))\t\(Terminaltext.sicher(s.url))") }
}
