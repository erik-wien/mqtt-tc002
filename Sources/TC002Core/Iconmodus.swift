import Foundation

/// Was ein laufender Text mit dem Icon tut (`iconMode` der Firmware,
/// `docs/awtrix-ng-protokoll.md` §5.3).
///
/// Drei Stellungen statt des früheren Schalters „Icon mitscrollen“: `fest` lässt
/// das Icon stehen und den Text daran vorbeilaufen (`fixed`), `einmal` lässt
/// den Text es einmal hinausschieben, danach bleibt es weg (`pushOnce`), `mit`
/// holt es in jedem Durchlauf zurück (`push`).
public enum Iconmodus: String, CaseIterable, Identifiable, Sendable, Codable {
    case fest, einmal, mit
    public var id: String { rawValue }

    /// Aus den zwei gespeicherten Schaltern der Oberflaeche (`senden.iconmitlaufend`,
    /// `senden.iconeinmal`): „einmal“ gilt nur, wo das Icon ueberhaupt mitlaeuft.
    public init(laeuftMit: Bool, einmal: Bool) {
        self = laeuftMit ? (einmal ? .einmal : .mit) : .fest
    }

    /// Wie `init(laeuftMit:einmal:)` zurueck.
    public var laeuftMit: Bool { self != .fest }
    public var einmal: Bool { self == .einmal }

    /// Das Wort der Firmware.
    public var ng: String {
        switch self {
        case .fest: return "fixed"
        case .einmal: return "pushOnce"
        case .mit: return "push"
        }
    }

    /// Ob die Stellung auf diesem Weg etwas tut. „Einmal“ gibt es nur bei der
    /// Schrift der Uhr: Das GIF des Pixelwegs läuft in Schleife, und ein Icon,
    /// das nach dem ersten Durchlauf fehlt, ließe sich darin nicht darstellen.
    public func wirkt(weg: SendeWeg) -> Bool { self != .einmal || weg == .text }

    /// Was auf diesem Weg tatsächlich geschieht: Im Pixelweg läuft das Icon bei
    /// „Einmal“ wie bei „Mitscrollen“ mit. Die gespeicherte Wahl bleibt, wie sie ist.
    public func wirksam(weg: SendeWeg) -> Iconmodus { wirkt(weg: weg) ? self : .mit }

    /// Warum eine Stellung auf diesem Weg gesperrt ist; `nil`, wo sie gilt. Der
    /// Nutzer kann es ändern (Schalter „Schrift der Uhr“), darum wird sie
    /// ausgegraut und nicht ausgeblendet.
    public func begruendung(weg: SendeWeg) -> String? {
        guard !wirkt(weg: weg) else { return nil }
        return lok("„Einmal mitscrollen“ gibt es nur mit „Schrift der Uhr“. Sonst läuft das Icon mit dem Text mit.")
    }
}

extension Meldungsoptionen {
    /// Die Stellung des früheren Schalters „Icon mitscrollen“ als Auswahl. Die
    /// beiden gespeicherten Felder bleiben, wie ältere Fassungen sie lesen:
    /// `iconLaeuftMit` ist bei „einmal“ und „mit“ wahr, `iconModus` trägt nur,
    /// welche der beiden gemeint ist (`nil` heißt „mit“).
    public var iconmodus: Iconmodus {
        get {
            guard iconLaeuftMit else { return .fest }
            return iconModus ?? .mit
        }
        set {
            iconLaeuftMit = newValue != .fest
            iconModus = newValue == .einmal ? .einmal : nil
        }
    }

    /// Was auf dem gewählten Weg gilt.
    public var wirksamerIconmodus: Iconmodus { iconmodus.wirksam(weg: weg) }
}
