import Foundation
import TC002Core

/// Wie weit die Sendung eines Favoriten ist.
public enum Favoritenstand: Equatable, Sendable { case laeuft, ganz, teilweise }

/// Ein Favorit, dessen Werte gerade im Senden-Schirm stehen.
public struct Favoritenbearbeitung: Equatable, Sendable {
    /// nil: Duplikat, legt beim Speichern neu an.
    public let favoritID: UUID?
    public var titel: String
    /// Beim Duplikat das Original.
    public let hinter: UUID?
    /// Stand vor dem ersten Bearbeiten, samt Zielen; „Abbrechen“ stellt ihn her.
    let vorher: Sendeauftrag
}

extension AppZustand {
    /// Sendet einen Auftrag so, wie die Senden-Ansicht es täte, aber an `nurIDs`
    /// (nil: an die Wahl des Zielmenüs). Schreibt Slotgedächtnis und Verlauf wie
    /// jede andere Sendung. Ein Icon, das es nicht mehr gibt, heißt: ohne Icon.
    @discardableResult
    public func auftragSenden(_ a: Sendeauftrag, bestaende: [Iconsammlung],
                              nurIDs: [UUID]? = nil) async -> Sendebilanz {
        guard let sammlung = bestaende.first else { return Sendebilanz(erreicht: [], ziele: 0) }
        // Nummer allein ist nicht eindeutig: 8×8 und 16×16 dürfen sie teilen.
        let icon = a.iconNummer.flatMap { nummer in
            bestaende.lazy.compactMap { $0.alle().first { $0.nummer == nummer && $0.kante == a.iconKante } }.first
        }
        let ziele = nurIDs ?? (a.zielIDs.isEmpty ? nil : a.zielIDs)
        if let wahl = a.nachricht {
            // Für eine Nachricht gilt „Steht …“, nicht die Anzeigedauer.
            var optionen = a.optionen
            optionen.dauer = wahl.dauerSekunden
            let gesetzt = optionen
            return await benachrichtigen(
                rahmenFuer: { try Meldungsbau.rahmen(gesetzt, icon: icon, sammlung: sammlung, uhr: $0,
                                                     bestaende: { bestaende }) },
                wahl.optionen(nachrichtentext: a.optionen.text), nurIDs: ziele)
        }
        let optionen = a.optionen
        return await senden(
            rahmenFuer: { try Meldungsbau.rahmen(optionen, icon: icon, sammlung: sammlung, uhr: $0,
                                                 bestaende: { bestaende }) },
            als: Meldungsplatz.name(fuer: a.platz), slotOptionen: optionen, slotIcon: icon,
            slotPlatz: a.platz, nurIDs: ziele)
    }

    /// Sendet den Favoriten an seine eigenen Uhren; `zielIDs` des Zustands bleiben
    /// unberührt. Der Stand steht eine Sekunde nach dem Ende, dann wird er entfernt.
    public func favoritSenden(_ id: UUID, bestaende: [Iconsammlung]) async {
        guard let f = favoriten.first(where: { $0.id == id }) else { return }
        favoritenstand[id] = .laeuft
        // Ein Favorit ohne Ziele sendet an keine Uhr, nicht an die Wahl des Zielmenüs.
        let bilanz = await auftragSenden(f.auftrag, bestaende: bestaende, nurIDs: f.auftrag.zielIDs)
        guard !bilanz.nichts else { favoritenstand[id] = nil; return }
        let stand: Favoritenstand = bilanz.ganz ? .ganz : .teilweise
        favoritenstand[id] = stand
        let dauer = favoritenstandDauer
        Task { [weak self] in
            try? await Task.sleep(for: dauer)
            if self?.favoritenstand[id] == stand { self?.favoritenstand[id] = nil }
        }
    }

    public func favoritUmbenennen(_ id: UUID, zu titel: String) {
        guard let gueltig = Favoriten.gueltigerTitel(titel) else { return }
        favoritenAendern(Favoriten.umbenennen(id, zu: gueltig, in: favoriten))
    }

    public func favoritLoeschen(_ id: UUID) {
        favoritenAendern(Favoriten.entfernen(id, aus: favoriten))
    }

    /// Hebt den Stand des Senden-Schirms unter dem Titel auf.
    public func favoritAnlegen(titel: String, ablage: UserDefaults = .standard) {
        guard let gueltig = Favoriten.gueltigerTitel(titel) else { return }
        let auftrag = Sendeauftrag.aus(ablage, zielIDs: ziele().map(\.id))
        favoritenAendern(Favoriten.anfuegen(Favorit(titel: gueltig, auftrag: auftrag), an: favoriten))
    }

    public func favoritBearbeiten(_ id: UUID, ablage: UserDefaults = .standard) {
        guard let f = favoriten.first(where: { $0.id == id }) else { return }
        bearbeitungBeginnen(f, id: f.id, titel: f.titel, hinter: nil, ablage: ablage)
    }

    public func favoritDuplizieren(_ id: UUID, ablage: UserDefaults = .standard) {
        guard let f = favoriten.first(where: { $0.id == id }) else { return }
        bearbeitungBeginnen(f, id: nil, titel: Favoriten.kopietitel(f.titel), hinter: f.id, ablage: ablage)
    }

    /// Ein zweites Bearbeiten behält den Stand vor dem ersten.
    private func bearbeitungBeginnen(_ f: Favorit, id: UUID?, titel: String, hinter: UUID?, ablage: UserDefaults) {
        let vorher = bearbeitung?.vorher ?? Sendeauftrag.aus(ablage, zielIDs: Array(zielIDs))
        bearbeitung = Favoritenbearbeitung(favoritID: id, titel: titel, hinter: hinter, vorher: vorher)
        f.auftrag.schreiben(in: ablage)
        zielIDs = Set(f.auftrag.zielIDs)
    }

    /// Übernimmt den Stand des Senden-Schirms; die Werte dort bleiben stehen.
    /// Ist der Favorit inzwischen gelöscht, wird er neu angelegt statt verworfen.
    public func bearbeitungSpeichern(titel: String, ablage: UserDefaults = .standard) {
        guard let b = bearbeitung, let gueltig = Favoriten.gueltigerTitel(titel) else { return }
        let auftrag = Sendeauftrag.aus(ablage, zielIDs: ziele().map(\.id))
        if let id = b.favoritID, favoriten.contains(where: { $0.id == id }) {
            favoritenAendern(Favoriten.ersetzen(Favorit(id: id, titel: gueltig, auftrag: auftrag), in: favoriten))
        } else {
            let neu = Favorit(titel: gueltig, auftrag: auftrag)
            if let hinter = b.hinter {
                favoritenAendern(Favoriten.einfuegen(neu, hinter: hinter, in: favoriten))
            } else {
                favoritenAendern(Favoriten.anfuegen(neu, an: favoriten))
            }
        }
        bearbeitung = nil
    }

    public func bearbeitungAbbrechen(ablage: UserDefaults = .standard) {
        guard let b = bearbeitung else { return }
        b.vorher.schreiben(in: ablage)
        zielIDs = Set(b.vorher.zielIDs)
        bearbeitung = nil
    }

    private func favoritenAendern(_ neu: [Favorit]) {
        favoriten = neu
        if !favoritenablage.sichern(neu) { log(lok("Die Favoriten ließen sich nicht schreiben.")) }
    }
}
