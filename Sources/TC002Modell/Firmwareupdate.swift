import Foundation
import TC002Core

/// Wo das Firmware-Update einer Uhr steht. Die Oberfläche zeigt nur diesen Wert.
public enum Firmwareablauf: Equatable, Sendable {
    case sucht
    case aktuell(String)
    case verfuegbar(Firmwarepaket)
    /// Neuere Fassung bei GitHub, aber ohne Datei für diese Uhr.
    case keinPaket(fassung: String, dateiname: String)
    case unterwegs(Firmwarestufe, Firmwarepaket)
    case fertig(Firmwareergebnis)
    case fehler(String)

    /// Eine Suche oder ein Update läuft; dann nimmt die App keinen zweiten Auftrag an.
    public var beschaeftigt: Bool {
        switch self {
        case .sucht, .unterwegs: return true
        default: return false
        }
    }
}

/// Firmware-Update der Uhr aus der App: Nach dem Release suchen (GitHub), das Paket
/// laden, hochladen (`POST /update`), den Neustart abwarten. Nur über HTTP, also mit
/// Adresse. Beides — Suchen und Aktualisieren — läuft nur auf ausdrücklichen Auftrag
/// des Nutzers; die Ansicht fragt vor dem Aktualisieren jedes Mal nach.
extension AppZustand {
    private func firmwareuhr(_ id: UUID) -> Uhr? {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return nil }
        guard !uhr.host.isEmpty else {
            firmwareablauf[id] = .fehler(lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.", uhr.name))
            return nil
        }
        return uhr
    }

    /// Sucht das neueste Release und vergleicht es mit der Fassung, die die Uhr jetzt
    /// meldet.
    public func firmwareSuchen(fuer id: UUID) async {
        guard firmwareablauf[id]?.beschaeftigt != true, let uhr = firmwareuhr(id) else { return }
        firmwareablauf[id] = .sucht
        await zustandAbfragen(id)
        guard let stand = geraetezustand[id], let image = stand.updateImage else {
            firmwareablauf[id] = .fehler(Firmwarefehler.keinPaketFuerDieseUhr.localizedDescription)
            return
        }
        do {
            let angebot = try await firmwarequelle.suchen(updateImage: image,
                                                          installiert: stand.fassung ?? "")
            switch angebot {
            case .aktuell(let f): firmwareablauf[id] = .aktuell(f)
            case .verfuegbar(let p):
                firmwareablauf[id] = .verfuegbar(p)
                log(lokf("%@: Firmware %@ gefunden", uhr.name, p.fassung))
            case .keinPaket(let f, let d): firmwareablauf[id] = .keinPaket(fassung: f, dateiname: d)
            }
        } catch {
            firmwareablauf[id] = .fehler(error.localizedDescription)
        }
    }

    private func firmwareFortschritt(_ id: UUID, _ stufe: Firmwarestufe, _ paket: Firmwarepaket) {
        // Ein spät eintreffender Fortschritt darf eine spätere Stufe nicht überschreiben.
        switch (firmwareablauf[id], stufe) {
        case (.unterwegs(.laedt, _)?, .laedt), (.unterwegs(.uebertraegt, _)?, .uebertraegt):
            firmwareablauf[id] = .unterwegs(stufe, paket)
        default: break
        }
    }

    /// Spielt das gefundene Paket ein: laden, prüfen, hochladen, auf den Neustart warten
    /// und erst melden, wenn die neue Fassung antwortet. Gestartet wird nur aus dem
    /// Zustand `verfuegbar`.
    public func firmwareAktualisieren(fuer id: UUID) async {
        guard case .verfuegbar(let paket)? = firmwareablauf[id], let uhr = firmwareuhr(id) else { return }
        let host = uhr.host, sitzung = netzsitzung, quelle = firmwarequelle, zeit = firmwarewartezeit
        firmwareablauf[id] = .unterwegs(.laedt(0), paket)
        do {
            let daten = try await quelle.laden(paket) { [weak self] p in
                Task { @MainActor in self?.firmwareFortschritt(id, .laedt(p), paket) }
            }
            firmwareablauf[id] = .unterwegs(.uebertraegt(0), paket)
            let geraet = Geraet(host: host, sitzung: sitzung)
            _ = try await geraet.firmwareHochladen(daten, dateiname: paket.dateiname) { [weak self] p in
                Task { @MainActor in self?.firmwareFortschritt(id, .uebertraegt(p), paket) }
            }
            firmwareablauf[id] = .unterwegs(.startetNeu, paket)
            log(lokf("%@: Firmware %@ hochgeladen", uhr.name, paket.fassung))
            let ergebnis = try await Hintergrund.lauf {
                try geraet.neustartAbwarten(erwartet: paket.fassung, zeit: zeit)
            }
            firmwareablauf[id] = .fertig(ergebnis)
            log(lokf("%@: Firmware %@ läuft", uhr.name, ergebnis.fassung))
            await zustandAbfragen(id)
        } catch {
            firmwareablauf[id] = .fehler(error.localizedDescription)
            log(lokf("%@: Firmware-Update gescheitert: %@", uhr.name, error.localizedDescription))
            await zustandAbfragen(id)
        }
    }

    /// Setzt eine Anzeige wie „Aktuell“ oder einen Fehler zurück, damit die Zeile wieder
    /// den Stand der Uhr zeigt.
    public func firmwareablaufVergessen(_ id: UUID) {
        if firmwareablauf[id]?.beschaeftigt != true { firmwareablauf[id] = nil }
    }
}
