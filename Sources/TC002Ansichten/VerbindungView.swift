import SwiftUI
import TC002Core
import TC002Modell

/// Die Einstellungen am Schreibtisch (Mac und iPad): drei Reiter, je ein
/// Thema. Was in einem Reiter steht, steht in `Einstellungsinhalt` und gilt
/// für beide Oberflächen; hier steht nur, wie man zwischen den Themen
/// wechselt.
///
/// Reiter und nicht eine rollende Form: Mehrere Themen untereinander waren am
/// Ende eine Wand, in der die virtuelle Uhr zwischen den Uhren und dem
/// Verlauf stand.
public struct VerbindungView: View {
    @Bindable var zustand: AppZustand
    @State private var thema: Einstellungsthema = .uhren
    /// Der Weg im Reiter „Uhren“ (Uhr, dann Gruppe), damit sich eine Seite von
    /// außen aufschlagen lässt (`ziel`).
    @State private var pfad = NavigationPath()
    /// Eine Stelle, die der Aufrufer aufgeschlagen haben will; wird hier
    /// entgegengenommen und auf `nil` gesetzt.
    private let ziel: Binding<Einstellungsziel?>

    public init(zustand: AppZustand, fensterOeffnen: ((String) -> Void)? = nil,
                ziel: Binding<Einstellungsziel?> = .constant(nil)) {
        self.zustand = zustand
        self.fensterOeffnen = fensterOeffnen
        self.ziel = ziel
    }

    /// Wo die virtuelle Uhr aufgeht: am Mac als eigenes Fenster, am iPad als
    /// Einblendung. Die Handlung kommt herein und wird hier nicht
    /// gewaehlt: `openWindow` gibt es unter iOS zwar als Aufruf, aber er tut
    /// dort nichts — deshalb steht er allein in der Mac-App, und diese
    /// Ansicht weiss gar nicht, dass es Fenster gibt (`PlattformwegeTests`).
    /// `nil` heisst: kein Fenster zur Hand, dann ein Blatt.
    private let fensterOeffnen: ((String) -> Void)?
    @State private var zeigeVirtuelleUhr = false

    private func ansehen() {
        if let fensterOeffnen {
            fensterOeffnen(Nebenfenster.virtuelleUhr.id)
        } else {
            zeigeVirtuelleUhr = true
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Eine Segmentwahl ueber dem Inhalt statt einer `TabView`: Die
            // zeichnet iPadOS als schwebende Leiste am unteren Rand — dort
            // gehoert die Wahl der App, nicht die eines Bereichs innerhalb
            // eines Bereichs. Die Vorlage (`docs/superpowers/vorlagen/
            // apple-inspektor.md`, „Zweite Ebene: Reiter") nennt genau diese
            // Form: Numbers waehlt den Bereich seines Inspektors so.
            Picker("Thema", selection: Binding(get: { thema },
                                               set: { thema = $0; pfad = NavigationPath() })) {
                ForEach(Einstellungsthema.allCases) { t in
                    Text(t.titel).tag(t)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)

            // Ein `NavigationStack` je Reiter: Nur der Reiter „Uhren" fuehrt
            // weiter, aber ein Stapel, der beim Themenwechsel verschwindet,
            // laesst auch den Weg dorthin nicht stehenbleiben.
            NavigationStack(path: $pfad) {
                Einstellungsinhalt(zustand: zustand, thema: thema,
                                   kanon: .schreibtisch,
                                   virtuelleUhrAnsehen: ansehen)
            }
            .id(thema)
        }
        // Beim Aufschlagen fragen, nicht erst auf Druck: Praefix
        // und Verbindungsstand sind genau das, was man hier wissen will. Die
        // Abrufe laufen nebeneinander, eine stumme Uhr haelt die uebrigen
        // nicht auf.
        .task { zustand.alleAbfragen() }
        .onChange(of: ziel.wrappedValue, initial: true) { _, neu in
            guard let neu else { return }
            let gruppe = neu.uhrgruppenziel
            var weg = NavigationPath()
            weg.append(gruppe.uhr)
            weg.append(gruppe)
            thema = .uhren
            pfad = weg
            ziel.wrappedValue = nil
        }
        .sheet(isPresented: $zeigeVirtuelleUhr) { Nebenfenster.virtuelleUhr.inhalt }
    }
}
