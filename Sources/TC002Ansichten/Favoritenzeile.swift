import SwiftUI
import TC002Core
import TC002Modell

/// Was rechts in der Zeile eines Favoriten steht.
public enum Standzeichen: Equatable, Sendable { case fortschritt, haken, warnung }

/// Eine Zeile der Favoritenliste: ein Tippen sendet, das Kontextmenü trägt
/// Bearbeiten, Duplizieren, Umbenennen und Löschen. Die Zeile gehört in keine
/// Auswahl (kein `tag`), ein Klick wechselt also den Bereich nicht.
public struct Favoritenzeile: View {
    @Bindable var zustand: AppZustand
    let favorit: Favorit
    let bestaende: [Iconsammlung]
    let oeffneSenden: () -> Void

    @State private var umbenennen: Favorit?
    @State private var loeschen: Favorit?
    @ScaledMetric(relativeTo: .body) private var zeichen: CGFloat = 14

    public init(zustand: AppZustand, favorit: Favorit, bestaende: [Iconsammlung],
                oeffneSenden: @escaping () -> Void) {
        self.zustand = zustand
        self.favorit = favorit
        self.bestaende = bestaende
        self.oeffneSenden = oeffneSenden
    }

    /// Kein Stand, kein Zeichen.
    static func standzeichen(_ stand: Favoritenstand?) -> Standzeichen? {
        switch stand {
        case nil: return nil
        case .laeuft: return .fortschritt
        case .ganz: return .haken
        case .teilweise: return .warnung
        }
    }

    public var body: some View {
        Button {
            Task { await zustand.favoritSenden(favorit.id, bestaende: bestaende) }
        } label: {
            HStack(spacing: 6) {
                Label {
                    Text(verbatim: favorit.titel).lineLimit(1).truncationMode(.tail)
                } icon: {
                    Image(systemName: "star")
                }
                Spacer(minLength: 4)
                Favoritenstandsymbol(stand: zustand.favoritenstand[favorit.id], mass: zeichen)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Bearbeiten") {
                zustand.favoritBearbeiten(favorit.id)
                oeffneSenden()
            }
            Button("Duplizieren") {
                zustand.favoritDuplizieren(favorit.id)
                oeffneSenden()
            }
            Button("Umbenennen …") { umbenennen = favorit }
            Button("Löschen …", role: .destructive) { loeschen = favorit }
        }
        .favoritendialoge(zustand: zustand, umbenennen: $umbenennen, loeschen: $loeschen)
    }
}

/// Das Zeichen rechts in der Zeile; sagt der Sprachausgabe, was es zeigt.
struct Favoritenstandsymbol: View {
    let stand: Favoritenstand?
    let mass: CGFloat

    var body: some View {
        switch Favoritenzeile.standzeichen(stand) {
        case nil: EmptyView()
        case .fortschritt?:
            ProgressView().controlSize(.small)
        case .haken?:
            Image(systemName: "checkmark").foregroundStyle(Warnfarbe.erfolg)
                .frame(width: mass, height: mass)
                .accessibilityLabel(Text(lok("Hinausgeschickt")))
        case .warnung?:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Warnfarbe.symbol)
                .frame(width: mass, height: mass)
                .accessibilityLabel(Text(lok("Nur an manche Uhren hinausgeschickt")))
        }
    }
}

extension View {
    /// Umbenennen (Systemdialog mit Textfeld) und Löschen (Bestätigung). Der
    /// Aufrufer hält den Zustand: Ein Menü kann keine Dialoge tragen, am
    /// Telefon hängen sie darum außerhalb des Titelmenüs.
    func favoritendialoge(zustand: AppZustand, umbenennen: Binding<Favorit?>,
                          loeschen: Binding<Favorit?>) -> some View {
        modifier(Favoritendialoge(zustand: zustand, umbenennen: umbenennen, loeschen: loeschen))
    }
}

private struct Favoritendialoge: ViewModifier {
    let zustand: AppZustand
    @Binding var umbenennen: Favorit?
    @Binding var loeschen: Favorit?
    @State private var titel = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: umbenennen) { _, neu in if let neu { titel = neu.titel } }
            .alert("Favorit umbenennen", isPresented: Binding(
                get: { umbenennen != nil }, set: { if !$0 { umbenennen = nil } })) {
                TextField("Titel", text: $titel)
                Button("Abbrechen", role: .cancel) {}
                Button("Umbenennen") {
                    if let f = umbenennen { zustand.favoritUmbenennen(f.id, zu: titel) }
                }
                .disabled(Favoriten.gueltigerTitel(titel) == nil)
            }
            .confirmationDialog(
                lokf("„%@“ löschen?", loeschen?.titel ?? ""),
                isPresented: Binding(get: { loeschen != nil }, set: { if !$0 { loeschen = nil } }),
                titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let f = loeschen { zustand.favoritLoeschen(f.id) }
                }
                Button("Abbrechen", role: .cancel) {}
            }
    }
}
