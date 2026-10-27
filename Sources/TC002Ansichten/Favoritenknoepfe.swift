import SwiftUI
import TC002Core
import TC002Modell

/// „+ Favorit“ über dem Eingabefeld; solange ein Favorit bearbeitet wird,
/// stattdessen „Abbrechen“ und „Favorit speichern“. Der Titel kommt aus dem
/// Systemdialog mit Textfeld (`alert`), nicht aus einem eigenen Blatt.
public struct Favoritenknoepfe: View {
    @Bindable var zustand: AppZustand
    /// Der eingegebene Text; belegt das Titelfeld beim Anlegen vor.
    let vorgabetitel: String

    @State private var fragt = false
    @State private var titel = ""

    public init(zustand: AppZustand, vorgabetitel: String) {
        self.zustand = zustand
        self.vorgabetitel = vorgabetitel
    }

    public enum Modus: Equatable { case anlegen, bearbeiten }

    static func modus(bearbeitung: Favoritenbearbeitung?) -> Modus {
        bearbeitung == nil ? .anlegen : .bearbeiten
    }

    static func sichernErlaubt(titel: String) -> Bool {
        Favoriten.gueltigerTitel(titel) != nil
    }

    public var body: some View {
        let modus = Self.modus(bearbeitung: zustand.bearbeitung)
        Group {
            switch modus {
            case .anlegen:
                Button {
                    titel = vorgabetitel
                    fragt = true
                } label: {
                    // Ein `Label` setzt zwischen Zeichen und Wort einen Abstand, der
                    // die Kapsel am Telefon aus der Zeile der Sendeart drängt.
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Favorit")
                    }
                }
                .buttonStyle(.bordered)
                .help("Als Favorit sichern")
            case .bearbeiten:
                HStack(spacing: 8) {
                    Button("Abbrechen") { zustand.bearbeitungAbbrechen() }
                        .buttonStyle(.bordered)
                    Button("Favorit speichern") {
                        titel = zustand.bearbeitung?.titel ?? ""
                        fragt = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        // Kleine Kapseln wie die Knöpfe der Sendeartwahl daneben.
        .controlSize(.small)
        .alert("Favorit sichern", isPresented: $fragt) {
            TextField("Titel", text: $titel)
            Button("Abbrechen", role: .cancel) {}
            Button(modus == .anlegen ? "Sichern" : "Favorit speichern") {
                if modus == .anlegen {
                    zustand.favoritAnlegen(titel: titel)
                } else {
                    zustand.bearbeitungSpeichern(titel: titel)
                }
            }
            .disabled(!Self.sichernErlaubt(titel: titel))
        }
    }
}
