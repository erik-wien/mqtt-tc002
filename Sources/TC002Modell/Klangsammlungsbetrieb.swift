import Foundation
import TC002Core

/// Die Klangsammlung in der App: Bestand lesen und ändern, von einer Uhr
/// übernehmen, mit Uhren abgleichen. Gerechnet wird im Kern (`Klangsammlung`,
/// `Klangabgleich`); hier steht nur der Zustand und der Weg in den Hintergrund.
extension AppZustand {
    public var klangsammlung: Klangsammlung {
        Klangsammlung(ordner: klangordnerAnders ?? Klangordner.eigene)
    }

    /// Der Bestand; liest bei jeder Änderung (`klangstand`) neu.
    public func klaenge() -> [Sammlungsklang] {
        _ = klangstand
        return klangsammlung.alle()
    }

    private func sammlungsfehler(_ error: Error) {
        fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }

    /// Sichert eine Melodie (neu oder ersetzend).
    @discardableResult
    public func melodieSammeln(name: String, rtttl: String) -> Bool {
        do {
            try klangsammlung.melodieSichern(name: name, rtttl: rtttl)
            klangstand += 1
            return true
        } catch { sammlungsfehler(error); return false }
    }

    /// Nimmt eine gewählte Datei auf: `.mp3` als MP3, sonst als RTTTL-Text.
    /// Gelesen wird im Hintergrund; der Zugriff auf eine vom Anwender gewählte
    /// Datei gilt nur, solange er ausdrücklich geöffnet ist.
    @discardableResult
    public func dateiSammeln(_ datei: URL, name: String) async -> Bool {
        let sammlung = klangsammlung
        do {
            try await Hintergrund.lauf {
                let offen = datei.startAccessingSecurityScopedResource()
                defer { if offen { datei.stopAccessingSecurityScopedResource() } }
                if datei.pathExtension.lowercased() == "mp3" {
                    if let g = try? datei.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                       g > Geraet.mp3Hoechstgroesse {
                        throw KlangFehler.mp3ZuGross(bytes: g, grenze: Geraet.mp3Hoechstgroesse)
                    }
                    guard let daten = try? Data(contentsOf: datei) else {
                        throw SammlungFehler.nichtLesbar(datei.lastPathComponent)
                    }
                    try sammlung.mp3Sichern(name: name, daten: daten)
                } else {
                    guard let text = try? String(contentsOf: datei, encoding: .utf8) else {
                        throw SammlungFehler.nichtLesbar(datei.lastPathComponent)
                    }
                    try sammlung.melodieSichern(name: name, rtttl: text)
                }
            }
            klangstand += 1
            return true
        } catch { sammlungsfehler(error); return false }
    }

    public func klangUmbenennen(_ klang: Sammlungsklang, nach neu: String) {
        do { try klangsammlung.umbenennen(klang, nach: neu); klangstand += 1 }
        catch { sammlungsfehler(error) }
    }

    public func klangAusSammlungLoeschen(_ klang: Sammlungsklang) {
        do { try klangsammlung.loeschen(klang); klangstand += 1 }
        catch { sammlungsfehler(error) }
    }

    /// Übernimmt die Melodien einer Uhr (nur HTTP). `nil`: Uhr nicht erreichbar.
    public func melodienVonUhrUebernehmen(_ id: UUID) async -> Klangsammlung.Uebernahme? {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return nil }
        guard !uhr.host.isEmpty else {
            fehler = lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", uhr.name)
            return nil
        }
        let host = uhr.host, sitzung = netzsitzung
        do {
            let liste = try await Hintergrund.lauf { try Geraet(host: host, sitzung: sitzung).melodien() }
            let bilanz = klangsammlung.uebernehmen(melodien: liste)
            klangstand += 1
            log(lokf("%@: %d Melodien übernommen", uhr.name, bilanz.neu.count + bilanz.ersetzt.count))
            return bilanz
        } catch { melde(error, uhr: uhr); return nil }
    }

    /// Gleicht die Uhren an die Sammlung an. Je Uhr eine eigene Arbeit im
    /// Hintergrund; eine Uhr ohne Adresse steht mit Fehler im Ergebnis.
    public func klaengeAbgleichen(mit ids: [UUID]) async -> [Uhrenabgleich] {
        let bestand = klangsammlung.alle()
        var ergebnisse: [Uhrenabgleich] = []
        for id in ids {
            guard let uhr = uhren.first(where: { $0.id == id }) else { continue }
            guard !uhr.host.isEmpty else {
                var e = Uhrenabgleich(uhr: uhr.name)
                e.fehler = lok("Ohne Adresse der Uhr nicht möglich.")
                ergebnisse.append(e)
                continue
            }
            let host = uhr.host, sitzung = netzsitzung, caps = faehigkeiten[id], name = uhr.name
            let e = await Hintergrund.lauf {
                Klangabgleich.abgleichen(sammlung: bestand, geraet: Geraet(host: host, sitzung: sitzung),
                                         uhrname: name, faehigkeiten: caps)
            }
            log(lokf("%@: Klänge abgeglichen (%d neu, %d ersetzt)", name, e.hinzugefuegt.count, e.ersetzt.count))
            ergebnisse.append(e)
            await tonlistenAbfragen(id)
        }
        return ergebnisse
    }
}
