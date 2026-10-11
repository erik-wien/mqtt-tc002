import SwiftUI
import TC002Core
import TC002Modell

/// Der Hinweis, dass eine Uhr eine ältere Firmware trägt, als die App kennt
/// (`Firmwarestand`): Meldung und Weg zum Aktualisieren als Fußnote.
///
/// Ein Hinweis und keine Sperre — alles bleibt bedienbar. Nichts, solange die
/// Fassung unbekannt ist oder reicht.
public struct Firmwarewarnung: View {
    @Bindable var zustand: AppZustand
    private let id: UUID
    private let kanon: Formkanon

    public init(zustand: AppZustand, id: UUID, kanon: Formkanon) {
        self.zustand = zustand
        self.id = id
        self.kanon = kanon
    }

    public var body: some View {
        if let hinweis = zustand.geraetezustand[id]?.firmwarehinweis {
            VStack(alignment: .leading, spacing: 4) {
                Label { Text(verbatim: hinweis.meldung) } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Warnfarbe.symbol)
                }
                Text(verbatim: Firmwarehinweis.anleitung)
                    .foregroundStyle(.secondary)
            }
            .font(kanon.fussnote)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Das kleine Zeichen für die Uhrenliste: orange, mit Erklärung für den
/// Zeiger und die Sprachausgabe. Nichts, wenn die Fassung reicht.
public struct Firmwarezeichen: View {
    @Bindable var zustand: AppZustand
    private let id: UUID

    public init(zustand: AppZustand, id: UUID) {
        self.zustand = zustand
        self.id = id
    }

    public var body: some View {
        if let hinweis = zustand.geraetezustand[id]?.firmwarehinweis {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(Warnfarbe.symbol)
                .help(hinweis.volltext)
                .accessibilityLabel(Text(verbatim: hinweis.volltext))
        }
    }
}
