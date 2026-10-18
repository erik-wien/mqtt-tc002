import SwiftUI
import TC002Core
import TC002Modell

/// Was „Senden“ schickt: eine Anzeige auf einen der fünf Plätze oder eine
/// Nachricht (im Protokoll: Benachrichtigung), die die Schleife einmal
/// unterbricht und keinen Platz belegt. Der Rohwert liegt in `@AppStorage`.
public enum Sendeart: String, CaseIterable, Sendable {
    case anzeige, nachricht
}

/// Die Regler einer Nachricht, wie `Sendeartwahl` sie bindet.
public struct Nachrichtbindungen {
    let halten: Binding<Bool>
    let aufwecken: Binding<Bool>
    let ersetzen: Binding<Bool>
    let durchlaeufe: Binding<Int>
    let klang: Binding<Klangwahl>
    /// Dieselbe Dauer wie im Reiter „Zeit“ des Inspektors (`dauerText` der Sendeansicht).
    let dauer: Binding<String>

    public init(halten: Binding<Bool>, aufwecken: Binding<Bool>, ersetzen: Binding<Bool>,
                durchlaeufe: Binding<Int>, klang: Binding<Klangwahl>, dauer: Binding<String>) {
        self.dauer = dauer
        self.halten = halten
        self.aufwecken = aufwecken
        self.ersetzen = ersetzen
        self.durchlaeufe = durchlaeufe
        self.klang = klang
    }
}

/// Die Lebensdauer einer Anzeige, wie `Sendeartwahl` sie bindet.
public struct Lebensdauerbindungen {
    let behalten: Binding<Bool>
    let zahl: Binding<Int>
    let einheit: Binding<Lebensdauereinheit>
    let ablauf: Binding<Lebensablauf>

    public init(behalten: Binding<Bool>, zahl: Binding<Int>,
                einheit: Binding<Lebensdauereinheit>, ablauf: Binding<Lebensablauf>) {
        self.behalten = behalten
        self.zahl = zahl
        self.einheit = einheit
        self.ablauf = ablauf
    }
}

/// Das Segment „Anzeige | Nachricht“ über dem Eingabefeld — am Mac, iPad und
/// iPhone dasselbe — und daneben, was nur zur gewählten Art gehört: bei
/// „Nachricht“ der Klang und die Nachrichtoptionen, bei „Anzeige“ die
/// Lebensdauer. Die Optionen der anderen Art sind nicht da statt gesperrt:
/// Sie stehen direkt am Segment, und ein ausgegrauter Knopf dort ließe offen,
/// wozu er gehört. „Nachricht zurückziehen“ erscheint, solange eine von der App
/// geschickte, gehaltene Nachricht steht; es gilt für alle gewählten Uhren und
/// bleibt bei beiden Arten.
///
/// Die Optionen öffnen ein Popover (iPad, Mac) bzw. ein Blatt (iPhone) und
/// kein Menü: Durchläufe und Lebensdauer sind Zahlenwerte mit Stepper, und ein
/// Menü schließt sich nach jedem Eintrag — nach Apples Richtlinien sind Menüs
/// für Befehle und Einzelwahlen da, ein Popover für Einstellungen, die man
/// mehrere auf einmal ändert. Dasselbe Blatt trägt dieselben Abschnitte
/// (`Nachrichtabschnitt`, `Klangabschnitt`, `Lebensdauerabschnitt`) wie
/// vorher der Inspektor.
public struct Sendeartwahl: View {
    @Bindable var zustand: AppZustand
    @Binding var art: Sendeart
    let nachricht: Nachrichtbindungen
    let lebensdauer: Lebensdauerbindungen
    let kanon: Formkanon

    @State private var zeigeKlang = false
    @State private var zeigeOptionen = false
    @State private var zeigeLebensdauer = false

    public init(zustand: AppZustand, art: Binding<Sendeart>, nachricht: Nachrichtbindungen,
                lebensdauer: Lebensdauerbindungen, kanon: Formkanon) {
        self.zustand = zustand
        self._art = art
        self.nachricht = nachricht
        self.lebensdauer = lebensdauer
        self.kanon = kanon
    }

    public var body: some View {
        HStack(spacing: 8) {
            Picker("Art", selection: $art) {
                Text("Anzeige").tag(Sendeart.anzeige)
                Text("Nachricht").tag(Sendeart.nachricht)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            switch art {
            case .nachricht:
                // Kann keine Zieluhr Klang (ohne Lautsprecher), gibt es den Knopf nicht.
                if zustand.klangMoeglich { klangknopf }
                optionenknopf
            case .anzeige:
                lebensdauerknopf
            }
            Spacer(minLength: 0)
            // Im Modus „Nachricht“ immer: Sie nimmt die sichtbare Nachricht weg,
            // gleich von wem sie kam (Dismiss ohne Namen). Im Modus „Anzeige“
            // nur, solange diese App eine gehaltene Nachricht hinterlassen hat.
            if art == .nachricht || zustand.nachrichtGehalten {
                Button {
                    Task { await zustand.benachrichtigungZurueckziehen() }
                } label: {
                    Label("Nachricht zurückziehen", systemImage: "bell.slash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(zustand.ziele().isEmpty)
                .accessibilityLabel("Nachricht zurückziehen")
            }
        }
    }

    /// Das Zeichen allein, solange kein Klang gewählt ist; sonst mit seinem Namen.
    private var klangname: String? {
        let k = nachricht.klang.wrappedValue
        switch k.art {
        case .keiner: return nil
        case .uhr: return k.name.isEmpty ? nil : k.name
        case .vorlesen: return lok("Vorlesen")
        }
    }

    private var klangknopf: some View {
        Button {
            zeigeKlang = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                if let name = klangname {
                    Text(verbatim: name).lineLimit(1).frame(maxWidth: 80)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(Text("Klang") + Text(verbatim: klangname.map { " " + $0 } ?? ""))
        .popover(isPresented: $zeigeKlang) {
            Optionenblatt(titel: "Klang") {
                Klangabschnitt(zustand: zustand, klang: nachricht.klang, aktiv: true, kanon: kanon)
            }
        }
    }

    private var optionenknopf: some View {
        Button {
            zeigeOptionen = true
        } label: {
            Label("Nachrichtoptionen", systemImage: "slider.horizontal.3").labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .popover(isPresented: $zeigeOptionen) {
            Optionenblatt(titel: "Nachricht") {
                Nachrichtabschnitt(halten: nachricht.halten, aufwecken: nachricht.aufwecken,
                                   ersetzen: nachricht.ersetzen, durchlaeufe: nachricht.durchlaeufe,
                                   dauerText: nachricht.dauer, aktiv: true)
            }
        }
    }

    /// Zeichen und Wert: „Behalten“ oder die Frist („30 min“, „2 h“), damit man
    /// sie nicht erst öffnen muss.
    private var lebensdauertext: String {
        if lebensdauer.behalten.wrappedValue { return lok("Behalten") }
        let n = lebensdauer.zahl.wrappedValue
        return lebensdauer.einheit.wrappedValue == .stunden ? "\(n) h" : "\(n) min"
    }

    private var lebensdauerknopf: some View {
        Button {
            zeigeLebensdauer = true
        } label: {
            Label { Text(verbatim: lebensdauertext) } icon: { Image(systemName: "hourglass") }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(Text("Lebensdauer") + Text(verbatim: " " + lebensdauertext))
        .popover(isPresented: $zeigeLebensdauer) {
            Optionenblatt(titel: "Lebensdauer") {
                Lebensdauerabschnitt(behalten: lebensdauer.behalten, zahl: lebensdauer.zahl,
                                     einheit: lebensdauer.einheit, ablauf: lebensdauer.ablauf,
                                     aktiv: true)
            }
        }
    }
}

/// Der Rahmen um einen Abschnitt, der aus der Sendezeile aufgeht. Auf dem Mac
/// ein Popover fester Größe. Auf iOS ein Navigationsstapel mit „Fertig“: Er wird
/// im schmalen Fenster (iPhone) zum Blatt mit Detents, sonst bleibt er ein
/// Popover, und das braucht eine ideale Größe, sonst schrumpft es auf die
/// Titelleiste. Die Größenklasse spielt keine Rolle — auf dem iPad meldet sie
/// je nach Ort `.compact` oder `.regular`, und das Blatt ignoriert ideale Maße.
struct Optionenblatt<Inhalt: View>: View {
    let titel: LocalizedStringKey
    @ViewBuilder let inhalt: Inhalt
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        #if os(macOS)
        Form { inhalt }
            .formStyle(.grouped)
            .frame(width: 340, height: 440)
        #else
        NavigationStack {
            Form { inhalt }
                .navigationTitle(titel)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { schliessen() }
                    }
                }
        }
        .frame(idealWidth: 340, idealHeight: 440)
        .presentationCompactAdaptation(.sheet)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }
}

/// Die Regler einer Nachricht — im Popover bzw. Blatt neben dem Segment
/// „Anzeige | Nachricht“ (`Sendeartwahl`).
public struct Nachrichtabschnitt: View {
    @Binding var halten: Bool
    @Binding var aufwecken: Bool
    @Binding var ersetzen: Bool
    @Binding var durchlaeufe: Int
    @Binding var dauerText: String
    let aktiv: Bool

    public init(halten: Binding<Bool>, aufwecken: Binding<Bool>, ersetzen: Binding<Bool>,
                durchlaeufe: Binding<Int>, dauerText: Binding<String>, aktiv: Bool) {
        self._dauerText = dauerText
        self._halten = halten
        self._aufwecken = aufwecken
        self._ersetzen = ersetzen
        self._durchlaeufe = durchlaeufe
        self.aktiv = aktiv
    }

    public var body: some View {
        Section {
            Toggle("Halten", isOn: $halten)
            Toggle("Aufwecken", isOn: $aufwecken)
            Toggle("Ersetzen", isOn: $ersetzen)
            LabeledContent("Durchläufe") {
                Schrittwahl("Durchläufe", wert: $durchlaeufe, bereich: 1...Nachrichtwahl.hoechstdurchlaeufe)
            }
            .gesperrterStepper(!aktiv)
            // Mit „Halten“ ignoriert die Uhr die Dauer (`hold` ignoriert `durationMs`).
            LabeledContent("Dauer (s)") {
                TextField("", text: $dauerText)
                    .eingabefeld()
                    .frame(minWidth: 70)
                    #if !os(macOS)
                    .keyboardType(.numberPad)
                    #endif
                    .disabled(halten)
            }
            if halten {
                Text("Mit „Halten“ gilt keine Dauer: Die Nachricht bleibt, bis sie beendet wird.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Abschnittskopf("Nachricht", hilfe: lok("Eine Nachricht unterbricht die Schleife und belegt keinen Platz. Halten: bleibt stehen, bis sie beendet wird. Dauer: wie lange sie steht (dieselbe Dauer wie im Reiter „Zeit“; leer: die der Uhr). Aufwecken: erscheint auch bei ausgeschaltetem Display. Ersetzen: verdrängt die sichtbare, statt sich hinten anzustellen. Durchläufe: wie oft ein laufender Text durchzieht. Gilt nur, wenn oben „Nachricht“ gewählt ist."))
        }
        .disabled(!aktiv)
    }
}

/// Wie lange eine neue Anzeige lebt: „Behalten“ (Vorgabe aus), danach Zahl,
/// Einheit und was geschieht. Bei „Behalten“ sind „Nach“ und „Dann“ gesperrt,
/// nicht versteckt. Gilt nur für Anzeigen; steht im Popover bzw. Blatt neben
/// dem Segment „Anzeige | Nachricht“ (`Sendeartwahl`).
public struct Lebensdauerabschnitt: View {
    @Binding var behalten: Bool
    @Binding var zahl: Int
    @Binding var einheit: Lebensdauereinheit
    @Binding var ablauf: Lebensablauf
    let aktiv: Bool

    public init(behalten: Binding<Bool>, zahl: Binding<Int>, einheit: Binding<Lebensdauereinheit>,
                ablauf: Binding<Lebensablauf>, aktiv: Bool) {
        self._behalten = behalten
        self._zahl = zahl
        self._einheit = einheit
        self._ablauf = ablauf
        self.aktiv = aktiv
    }

    public var body: some View {
        Section {
            Toggle("Behalten", isOn: $behalten)
            LabeledContent("Nach") {
                Schrittwahl("Nach", wert: $zahl, bereich: 1...Lebensdauerwahl.hoechstzahl)
            }
            .gesperrterStepper(behalten || !aktiv)
            Picker("Einheit", selection: $einheit) {
                Text("Minuten").tag(Lebensdauereinheit.minuten)
                Text("Stunden").tag(Lebensdauereinheit.stunden)
            }
            .disabled(behalten)
            Picker("Dann", selection: $ablauf) {
                Text("Entfernen").tag(Lebensablauf.entfernen)
                Text("Rot markieren").tag(Lebensablauf.markieren)
            }
            .disabled(behalten)
        } header: {
            Abschnittskopf("Lebensdauer", hilfe: lok("Eine neue Anzeige verschwindet nach dieser Zeit von selbst, sofern „Behalten“ aus ist. „Rot markieren“ lässt sie stehen und setzt einen dunkelroten Rand. Der Platz merkt die Werte, bis er gelöscht oder neu belegt wird. Gilt nur für Anzeigen."))
        }
        .disabled(!aktiv)
    }
}

extension View {
    /// Ein gesperrter `Stepper` zeigt sich unter iPadOS 26 nicht abgeblendet,
    /// obwohl `.disabled` gilt (Simulator, 09.10.2026), anders als Schalter und
    /// Menüs daneben. Darum zusätzlich die Blässe des Systems nachgezeichnet und
    /// die Trefferprüfung abgeschaltet.
    func gesperrterStepper(_ gesperrt: Bool) -> some View {
        disabled(gesperrt)
            .allowsHitTesting(!gesperrt)
            .opacity(gesperrt ? 0.35 : 1)
    }
}
