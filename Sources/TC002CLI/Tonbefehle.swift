import Foundation
import TC002Core

// Die Ausgabe der Lesebefehle für Klang (`ton zustand`, `ton melodien`, `ton mp3`, `ton sender`).
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

func mp3AusgebenListe(_ ablage: Tonablage, ausgabe: (String) -> Void = { print($0) }) {
    for name in ablage.namen {
        let groesse = ablage.groessen[name].map { "\t" + lokf("%d Byte", $0) } ?? ""
        ausgabe(Terminaltext.sicher(name) + groesse)
    }
    ausgabe(lokf("%d MP3-Dateien", ablage.namen.count))
    if let belegt = ablage.belegteBytes, let gesamt = ablage.gesamteBytes {
        ausgabe(lokf("%d von %d Byte belegt", belegt, gesamt))
    }
}

func senderAusgeben(_ sender: [Radiosender], ausgabe: (String) -> Void = { print($0) }) {
    guard !sender.isEmpty else { ausgabe(lok("Keine Sender.")); return }
    for (i, s) in sender.enumerated() { ausgabe("\(i)\t\(Terminaltext.sicher(s.name))\t\(Terminaltext.sicher(s.url))") }
}

/// Prüft die Klänge einer Sendung gegen die Fähigkeiten der Uhr. Ein Dateiname
/// ist MP3 oder Melodie; welche, sagen die Listen der Uhr (nur über HTTP — ohne
/// Antwort bleibt der Name beides, und die Uhr entscheidet). Wirft für diese Uhr,
/// was sie nicht spielt: Die Sendung geht dann nicht an sie.
func klaengePruefen(_ klaenge: [Klang], anzeigen: Anzeigen, faehigkeiten: Geraetefaehigkeiten?,
                    inBenachrichtigung: Bool = false) throws {
    guard let faehigkeiten, faehigkeiten.ton != nil else { return }
    var listen: Tonlisten?
    if klaenge.contains(where: { if case .datei = $0.quelle { return true } else { return false } }),
       let melodien = try? anzeigen.melodienLesen() {
        listen = Tonlisten(melodien: melodien.namen, mp3: (try? anzeigen.mp3Lesen())?.namen ?? [])
    }
    for k in klaenge { try k.pruefen(inBenachrichtigung: inBenachrichtigung, faehigkeiten: faehigkeiten, listen: listen) }
}

func sammlungAusgeben(_ klaenge: [Sammlungsklang], ausgabe: (String) -> Void = { print($0) }) {
    guard !klaenge.isEmpty else { ausgabe(lok("Die Klangsammlung ist leer. Sie wird in der App gefüllt.")); return }
    for k in klaenge {
        let art = k.art == .melodie ? lok("Melodie") : "MP3"
        ausgabe("\(Terminaltext.sicher(k.name))\t\(art)\t" + lokf("%d Byte", k.groesse))
    }
    let m = klaenge.filter { $0.art == .melodie }.count
    ausgabe(lokf("%d Melodien, %d MP3-Dateien", m, klaenge.count - m))
}

func abgleichAusgeben(_ e: Uhrenabgleich, ausgabe: (String) -> Void = { print($0) }) {
    ausgabe("# " + Terminaltext.sicher(e.uhr))
    if let f = e.fehler { ausgabe(lokf("nicht erreicht: %@", Terminaltext.sicher(f))); return }
    func zeile(_ titel: String, _ namen: [String]) {
        guard !namen.isEmpty else { return }
        ausgabe(titel + "\t" + namen.map(Terminaltext.sicher).joined(separator: ", "))
    }
    let trocken = e.trocken
    zeile(trocken ? lok("würde hinzufügen") : lok("hinzugefügt"), e.hinzugefuegt)
    zeile(trocken ? lok("würde ersetzen") : lok("ersetzt"), e.ersetzt)
    for u in e.uebersprungen {
        ausgabe(lok("übersprungen") + "\t" + Terminaltext.sicher(u.name) + "\t" + u.grund.text)
    }
    ausgabe(lokf("%d unverändert", e.unveraendert.count))
}
