import SwiftUI
import TC002Core
import TC002Modell

/// Die drei Themen der Einstellungen — auf allen Oberflächen dieselben, in
/// derselben Reihenfolge. „Allgemein“ trägt, was weder eine Uhr noch den
/// Broker betrifft: Aufzeichnung, iCloud und die virtuelle Uhr.
///
/// Die Titel gehen durch `lok(…)` und nicht über `rawValue`: Ein über eine
/// Variable nachgeschlagener Text ist für `scripts/texte-sammeln.py`
/// unsichtbar und müsste dort von Hand geführt werden.
public enum Einstellungsthema: String, CaseIterable, Identifiable, Sendable {
    case uhren, broker, allgemein

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .uhren: return lok("Uhren")
        case .broker: return lok("MQTT-Broker")
        case .allgemein: return lok("Allgemein")
        }
    }

    public var symbol: String {
        switch self {
        case .uhren: return "clock"
        case .broker: return "antenna.radiowaves.left.and.right"
        case .allgemein: return "gearshape"
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
        case .allgemein:
            Form {
                Aufzeichnungsabschnitt(zustand: zustand, kanon: kanon)
                Wolkenabschnitt(zustand: zustand, kanon: kanon)
                VirtuelleUhrAbschnitt(zustand: zustand, betrieb: .gemeinsam,
                                      ansehen: virtuelleUhrAnsehen)
            }
            .formStyle(.grouped)
        }
    }
}
