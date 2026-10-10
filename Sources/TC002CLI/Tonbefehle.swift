import Foundation
import TC002Core

// Die Ausgabe der Lesebefehle für Klang (`ton zustand`, `ton melodien`, `ton sender`).
// Die Befehle selbst laufen in `steuerbefehl` (Steuerbefehle.swift).

private func wiedergabezeile(_ spielt: Bool, _ name: String) -> String {
    guard spielt else { return lok("aus") }
    return name.isEmpty ? lok("spielt") : lokf("spielt „%@“", name)
}

func tonzustandAusgeben(_ z: Tonzustand) {
    func zeile(_ name: String, _ wert: String) { print("\(name)\t\(wert)") }
    zeile("Radio", wiedergabezeile(z.radio.spielt, z.radio.sender))
    if !z.radio.titel.isEmpty { zeile(lok("Titel"), z.radio.titel) }
    if !z.radio.fehler.isEmpty { zeile(lok("Fehler Radio"), z.radio.fehler) }
    zeile("App", wiedergabezeile(z.app.spielt, z.app.name))
    if !z.app.fehler.isEmpty { zeile(lok("Fehler App"), z.app.fehler) }
    zeile(lok("Alarm"), wiedergabezeile(z.alarm.spielt, z.alarm.name))
    if !z.alarm.fehler.isEmpty { zeile(lok("Fehler Alarm"), z.alarm.fehler) }
    zeile(lok("Sender"), String(z.sender.count))
}

func melodienAusgeben(_ ablage: Tonablage) {
    for name in ablage.namen { print(name) }
    print(lokf("%d Melodien", ablage.namen.count))
    if let belegt = ablage.belegteBytes, let gesamt = ablage.gesamteBytes {
        print(lokf("%d von %d Byte belegt", belegt, gesamt))
    }
}

func senderAusgeben(_ sender: [Radiosender]) {
    guard !sender.isEmpty else { print(lok("Keine Sender.")); return }
    for (i, s) in sender.enumerated() { print("\(i)\t\(s.name)\t\(s.url)") }
}
