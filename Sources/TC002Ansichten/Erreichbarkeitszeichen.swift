import SwiftUI
import TC002Core
import TC002Modell

/// Dass eine Uhr auf die letzte Abfrage nicht geantwortet hat.
///
/// Ein Zeichen an der Uhr und keine Meldung: Eine stumme Uhr ist kein Fehler,
/// den jemand wegklicken muss — sie ist aus, sie steht woanders, das WLAN
/// schlaeft. Ein Dialog davor legte sich ueber die ganze App und kam bei
/// mehreren Uhren mehrfach.
///
/// Nichts, solange nicht gefragt wurde (`nil`) oder die Uhr geantwortet hat:
/// Ein Haken an jeder erreichbaren Uhr waere fuenfmal dieselbe Auskunft.
public struct Erreichbarkeitszeichen: View {
    @Bindable var zustand: AppZustand
    private let id: UUID

    public init(zustand: AppZustand, id: UUID) {
        self.zustand = zustand
        self.id = id
    }

    public var body: some View {
        if zustand.erreichbar[id] == false {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .help(lok("Hat auf die letzte Abfrage nicht geantwortet"))
                .accessibilityLabel(Text("Hat auf die letzte Abfrage nicht geantwortet"))
        }
    }
}
