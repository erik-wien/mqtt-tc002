import SwiftUI
import TC002Modell

/// Das Thema „Aufzeichnung" der Einstellungen — für beide Oberflächen
/// derselbe Baustein. Zwei Abschnitte, weil es zwei Sorten Mitschrift sind
/// und sie verschieden voreingestellt sind.
public struct Aufzeichnungsabschnitt: View {
    @Bindable var zustand: AppZustand
    private let kanon: Formkanon

    public init(zustand: AppZustand, kanon: Formkanon) {
        self.zustand = zustand
        self.kanon = kanon
    }

    public var body: some View {
        // Der Verlauf ist ab Werk an — anders als das Protokoll. Er ist keine
        // technische Mitschrift, sondern das, was man geschickt hat, und ein
        // Druck darauf stellt es wieder her.
        Section {
            Toggle("Verlauf führen", isOn: $zustand.verlaufAn)
            Button("Verlauf löschen", role: .destructive) { zustand.verlaufLeeren() }
                .knopfZerstoerend()
            Text("Merkt sich jede gesendete Meldung samt ihren Einstellungen — unter „Senden“ steht sie unter den Plätzen, ein Druck stellt sie wieder her. Wird über iCloud abgeglichen, wenn das eingeschaltet ist, und hält die letzten 200 Sendungen je Gerät.")
                .font(kanon.fussnote).foregroundStyle(.secondary)
        }

        // Ab Werk aus: Das Protokoll ist ein Werkzeug für den Fall, dass etwas
        // nicht klappt — kein Mitschnitt, den eine App von sich aus führt. Wer
        // einen Fehler sucht, schaltet es ein; das Ausschalten räumt das
        // Vorhandene weg.
        Section {
            Toggle("Protokoll führen", isOn: $zustand.protokollAn)
            Text("Schreibt mit, was die App sendet und was die Uhren melden — unter „Verlauf“ nachzulesen. Nur nötig, wenn etwas nicht klappt; ausgeschaltet wird nichts aufgezeichnet und das Vorhandene weggeräumt.")
                .font(kanon.fussnote).foregroundStyle(.secondary)
        }
    }
}
