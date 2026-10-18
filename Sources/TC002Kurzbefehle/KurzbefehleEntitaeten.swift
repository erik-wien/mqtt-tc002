import AppIntents
import Foundation
import TC002Core

/// Eine eingerichtete Uhr als Auswahl in der Kurzbefehle-App. Die Kennung ist
/// die `Uhr.id`, nicht der Name: Wer eine Uhr umbenennt, behält seine
/// Kurzbefehle. Gelesen wird wie bei den Kurzbefehlen selbst aus den
/// Einstellungen der App (`Einstellungen.gelesen()`), nicht aus `AppZustand`.
struct UhrEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Uhr")
    static let defaultQuery = UhrAbfrage()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }

    init(_ uhr: Uhr) {
        id = uhr.id
        name = uhr.name
    }
}

struct UhrAbfrage: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [UhrEntity] {
        let e = Einstellungen.gelesen()
        return identifiers.compactMap { e.uhr(id: $0) }.map(UhrEntity.init)
    }

    func entities(matching string: String) async throws -> [UhrEntity] {
        Einstellungen.gelesen().uhren
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(UhrEntity.init)
    }

    func suggestedEntities() async throws -> [UhrEntity] {
        Einstellungen.gelesen().uhren.map(UhrEntity.init)
    }
}

/// Ein fertiges Bild aus dem Bestand (`Bilderordner.eigene`). Die Kennung ist
/// der Name, unter dem es im Editor gesichert wurde — derselbe Schlüssel, den
/// der Kurzbefehl bisher als Text bekam.
struct BildEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bild")
    static let defaultQuery = BildAbfrage()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: id))
    }
}

struct BildAbfrage: EntityStringQuery {
    private func namen() -> [String] {
        Bildersammlung(ordner: Bilderordner.eigene).alle().map(\.name).sorted()
    }

    func entities(for identifiers: [String]) async throws -> [BildEntity] {
        let vorhanden = Set(namen())
        return identifiers.filter(vorhanden.contains).map(BildEntity.init)
    }

    func entities(matching string: String) async throws -> [BildEntity] {
        namen().filter { $0.localizedCaseInsensitiveContains(string) }.map(BildEntity.init)
    }

    func suggestedEntities() async throws -> [BildEntity] {
        namen().map(BildEntity.init)
    }
}
