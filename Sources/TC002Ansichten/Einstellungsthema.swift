import SwiftUI
import TC002Core
import TC002Modell

/// Die fünf Themen der Einstellungen — auf allen Oberflächen dieselben, in
/// derselben Reihenfolge.
///
/// Vorher lag alles in einer rollenden Form, und die Reihenfolge war
/// gewachsen: die virtuelle Uhr (ein Prüfwerkzeug) zwischen den Uhren und dem
/// Verlauf, Verlauf und Protokoll vor dem Broker, iCloud ganz unten. Jetzt
/// steht die Ordnung an einer Stelle, und beide Oberflächen lesen sie hier ab.
///
/// Die Titel gehen durch `lok(…)` und nicht über `rawValue`: Ein über eine
/// Variable nachgeschlagener Text ist für `scripts/texte-sammeln.py`
/// unsichtbar und müsste dort von Hand geführt werden.
public enum Einstellungsthema: String, CaseIterable, Identifiable, Sendable {
    case uhren, broker, aufzeichnung, wolke, erweitert

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .uhren: return lok("Uhren")
        case .broker: return lok("Broker")
        case .aufzeichnung: return lok("Aufzeichnung")
        case .wolke: return lok("iCloud")
        case .erweitert: return lok("Erweitert")
        }
    }

    public var symbol: String {
        switch self {
        case .uhren: return "clock"
        case .broker: return "antenna.radiowaves.left.and.right"
        case .aufzeichnung: return "list.bullet.rectangle"
        case .wolke: return "icloud"
        case .erweitert: return "wrench.and.screwdriver"
        }
    }
}

/// Was unter einem Thema steht — der gemeinsame Inhalt beider Oberflächen.
///
/// Am Schreibtisch trägt ein Reiter diese Ansicht, auf dem Telefon eine Seite
/// hinter einem Listeneintrag. Die Anordnung unterscheidet sich, der Umfang
/// nicht: Beide bekommen dieselben Bausteine gereicht.
public struct Einstellungsinhalt: View {
    @Bindable var zustand: AppZustand
    private let thema: Einstellungsthema
    private let kanon: Formkanon
    /// Wo die virtuelle Uhr aufgeht, entscheidet die Oberfläche — am Mac ein
    /// Fenster, sonst ein Blatt.
    private let virtuelleUhrAnsehen: () -> Void

    public init(zustand: AppZustand, thema: Einstellungsthema, kanon: Formkanon,
                virtuelleUhrAnsehen: @escaping () -> Void) {
        self.zustand = zustand
        self.thema = thema
        self.kanon = kanon
        self.virtuelleUhrAnsehen = virtuelleUhrAnsehen
    }

    public var body: some View {
        switch thema {
        case .uhren:
            Uhrenliste(zustand: zustand, kanon: kanon)
        case .broker:
            Form { Brokerabschnitt(zustand: zustand, kanon: kanon) }
                .formStyle(.grouped)
        case .aufzeichnung:
            Form { Aufzeichnungsabschnitt(zustand: zustand, kanon: kanon) }
                .formStyle(.grouped)
        case .wolke:
            Form { Wolkenabschnitt(zustand: zustand, kanon: kanon) }
                .formStyle(.grouped)
        case .erweitert:
            Form {
                VirtuelleUhrAbschnitt(zustand: zustand, betrieb: .gemeinsam,
                                      ansehen: virtuelleUhrAnsehen)
            }
            .formStyle(.grouped)
        }
    }
}
