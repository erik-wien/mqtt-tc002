import SwiftUI
import TC002Core

/// Die Zeilen der Zusatzicons (`icons[]`) im Abschnitt „Zusatzicons“: je Eintrag
/// die Wahl des Icons, die Stelle auf der Anzeige in Pixeln von links und von
/// oben (tippbar, auf den Bereich geklemmt) und „Entfernen“; darunter
/// „Zusatzicon hinzufügen“, bis vier erreicht sind.
///
/// Dieselben Zeilen am Mac, am iPad und am iPhone; nur die Wahl des Icons ist die
/// der Oberfläche (`auswahl`): am Mac das Blatt der Iconauswahl, am iPhone eine
/// Seite des Icon-Blatts. Gezeigt wird immer, auch wenn kein normales Icon
/// gewählt ist oder der Text ins Display passt: Die Zusatzicons hängen an keinem
/// von beiden und gehen in beiden Wegen hinaus.
///
/// Ein neuer Eintrag hat noch kein Icon (leere Nummer) und wird nicht gesendet,
/// bis eines gewählt ist.
public struct Zusatziconliste<Auswahl: View>: View {
    @Binding private var liste: [Zusatzicon]
    private let sammlungen: [Iconsammlung]
    private let auswahl: (Int, Binding<Icon?>) -> Auswahl

    public init(liste: Binding<[Zusatzicon]>, sammlungen: [Iconsammlung],
                @ViewBuilder auswahl: @escaping (Int, Binding<Icon?>) -> Auswahl) {
        self._liste = liste
        self.sammlungen = sammlungen
        self.auswahl = auswahl
    }

    public var body: some View {
        ForEach(Array(liste.indices), id: \.self) { i in
            LabeledContent {
                auswahl(i, iconBinding(i))
            } label: {
                Text(lokf("Zusatzicon %d", i + 1))
            }
            LabeledContent("Von links") {
                Schrittwahl("Von links", wert: stelle(i, \.x), bereich: Zusatzicons.xBereich)
            }
            LabeledContent("Von oben") {
                Schrittwahl("Von oben", wert: stelle(i, \.y), bereich: Zusatzicons.yBereich)
            }
            Button(role: .destructive) {
                liste.remove(at: i)
            } label: {
                Text("Zusatzicon entfernen")
            }
            .buttonStyle(.automatic)
        }
        Button {
            liste.append(Zusatzicon(nummer: ""))
        } label: {
            Label("Zusatzicon hinzufügen", systemImage: "plus")
        }
        .buttonStyle(.automatic)
        .disabled(!Zusatzicons.kannHinzufuegen(liste))
    }

    private func iconBinding(_ i: Int) -> Binding<Icon?> {
        Binding(get: { liste.indices.contains(i) ? Zusatzicons.icon(zu: liste[i], in: sammlungen) : nil },
                set: { neu in
                    guard liste.indices.contains(i) else { return }
                    Zusatzicons.setzen(neu, in: &liste[i])
                })
    }

    private func stelle(_ i: Int, _ pfad: WritableKeyPath<Zusatzicon, Int>) -> Binding<Int> {
        Binding(get: { liste.indices.contains(i) ? liste[i][keyPath: pfad] : 0 },
                set: { neu in
                    guard liste.indices.contains(i) else { return }
                    liste[i][keyPath: pfad] = neu
                })
    }
}
