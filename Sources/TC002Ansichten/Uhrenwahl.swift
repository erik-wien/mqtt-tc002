import SwiftUI
import TC002Core
import TC002Modell

/// Eine Punktreihe unter der Vorschau, ein Punkt je Uhr — der gefüllte ist
/// die angesehene.
///
/// Sie beantwortet eine Frage, die bisher nirgends stand: wie viele Uhren es
/// gibt und die wievielte man gerade sieht. Dafür gibt es ein Vorbild, das
/// jeder kennt — Home-Bildschirm, Wetter, Fotos —, und es kommt ohne die
/// schwarzen Dreiecke aus, die man sonst danebenstellen müsste.
///
/// Am Zeiger anklickbar, am Finger wischbar: Das ist der eine Unterschied
/// zwischen den Bedienungen, den die Regel zulässt: Ein Punkt von acht Punkten
/// Durchmesser ist mit der Maus ein Ziel und mit dem Finger keines. Deshalb
/// trägt die Reihe hier die Klicks, und `Uhrenblaetterer` das Blättern über
/// der ganzen Vorschau — auf jeder Oberfläche beides, nur verschieden leicht
/// zu treffen.
///
/// Bei einer Uhr bleibt sie weg: Ein einzelner Punkt sagt nichts.
public struct Uhrenpunkte: View {
    @Bindable var zustand: AppZustand

    public init(zustand: AppZustand) { self.zustand = zustand }

    public var body: some View {
        if zustand.uhren.count > 1 {
            HStack(spacing: 8) {
                ForEach(zustand.uhren) { uhr in
                    Button { zustand.uhrAnsehen(uhr.id) } label: {
                        Circle()
                            .fill(uhr.id == zustand.aktiveID ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                            .frame(width: 8, height: 8)
                    }
                    .buttonStyle(.plain)
                    // Der Punkt bleibt 8 pt groß; die Trefferfläche ist 44 pt
                    // breit und hoch, ohne die Zeile höher zu machen (der
                    // Überstand nach oben und unten ist reine Trefferfläche).
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.vertical, -18)
                    .help(uhr.name)
                    .accessibilityLabel(Text(uhr.name))
                    .accessibilityAddTraits(uhr.id == zustand.aktiveID ? [.isSelected] : [])
                }
            }
            .padding(.top, 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Angesehene Uhr"))
        }
    }
}

/// Die Vorschau aller Uhren nebeneinander, blätterbar — ein Ausschnitt je Uhr.
///
/// Das Blättern kommt aus dem System (`.scrollTargetBehavior(.paging)` mit
/// `.scrollPosition`, ab iOS 17 und macOS 14) und nicht aus einer eigenen
/// Geste: Nur so folgt das Bild dem Finger, statt beim Loslassen etwas
/// überzublenden. Der Ausschnitt ist zugleich die Wahl der angesehenen Uhr —
/// wer blättert, sieht eine andere an.
///
/// Der Inhalt bekommt gesagt, ob seine Uhr die angesehene ist: Nur für sie
/// lohnt die teure Laufschriftberechnung, die Nachbarn zeigen ihr Standbild.
public struct Uhrenblaetterer<Inhalt: View>: View {
    @Bindable var zustand: AppZustand
    @ViewBuilder let inhalt: (Uhr, Bool) -> Inhalt

    public init(zustand: AppZustand,
                @ViewBuilder inhalt: @escaping (Uhr, Bool) -> Inhalt) {
        self.zustand = zustand
        self.inhalt = inhalt
    }

    public var body: some View {
        if zustand.uhren.count > 1 {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(zustand.uhren) { uhr in
                        inhalt(uhr, uhr.id == zustand.aktiveID)
                            .containerRelativeFrame(.horizontal)
                            .id(uhr.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: Binding(
                get: { zustand.aktiveID },
                set: { if let neu = $0, neu != zustand.aktiveID { zustand.uhrAnsehen(neu) } }))
        } else if let uhr = zustand.referenzUhr {
            inhalt(uhr, true)
        }
    }
}

