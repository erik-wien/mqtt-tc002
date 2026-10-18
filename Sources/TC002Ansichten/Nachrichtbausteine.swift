import SwiftUI
import TC002Core
import TC002Modell

/// Was „Senden“ schickt: eine Anzeige auf einen der fünf Plätze oder eine
/// Nachricht (im Protokoll: Benachrichtigung), die die Schleife einmal
/// unterbricht und keinen Platz belegt. Der Rohwert liegt in `@AppStorage`.
public enum Sendeart: String, CaseIterable, Sendable {
    case anzeige, nachricht

    /// Die Überschrift über Dauer und Lauftempo nennt, was gerade geschickt
    /// wird: dieselben Wörter wie das Segment darüber.
    public var nurDiese: LocalizedStringKey {
        switch self {
        case .anzeige: return "Nur diese Anzeige"
        case .nachricht: return "Nur diese Nachricht"
        }
    }

    /// Die Überschrift des Overlay-Abschnitts: Das Overlay der Sendung ist nicht
    /// das der Uhr (Bereich „Uhr“, „Overlay jetzt auf der Uhr“).
    public var overlaytitel: String {
        switch self {
        case .anzeige: return lok("Overlay (nur diese Anzeige)")
        case .nachricht: return lok("Overlay (nur diese Nachricht)")
        }
    }

    /// Dasselbe für Tempo und mitlaufendes Icon: Die Uhr hat ein eigenes Tempo.
    public var laufschrifttitel: String {
        switch self {
        case .anzeige: return lok("Laufschrift (nur diese Anzeige)")
        case .nachricht: return lok("Laufschrift (nur diese Nachricht)")
        }
    }

    public var dauerErklaerung: LocalizedStringKey {
        switch self {
        case .anzeige: return "Wie lange die Uhr diese Anzeige zeigt, bevor sie weiterblättert. Leer oder 0: Es gilt die Anzeigedauer der Uhr."
        case .nachricht: return "Wie lange diese Nachricht steht: bis du sie zurückziehst, eine Zahl Sekunden oder eine Zahl Durchläufe des Textes."
        }
    }

    public var zeithilfe: String {
        switch self {
        case .anzeige: return lok("Dauer und Lauftempo reisen mit dieser einen Anzeige mit. Wie schnell die Uhr durch alle Anzeigen blättert, ist dagegen eine Einstellung der Uhr (Anzeigedauer).")
        case .nachricht: return lok("„Steht …“ und Lauftempo reisen mit dieser einen Nachricht mit. Durchläufe gibt es nur für Text, der durchläuft; läuft nichts durch, nimmt die Uhr ihre Anzeigedauer.")
        }
    }
}

/// „Steht …“ einer Nachricht: die Art, beide Zahlen und ob der Text auf
/// mindestens einer Zieluhr durchläuft (Durchläufe wirken nur dann).
public struct Stehtbindungen {
    let art: Binding<Nachrichtdauerart>
    let sekunden: Binding<Int>
    let durchlaeufe: Binding<Int>
    let textLaeuft: Bool

    public init(art: Binding<Nachrichtdauerart>, sekunden: Binding<Int>, durchlaeufe: Binding<Int>,
                textLaeuft: Bool) {
        self.art = art
        self.sekunden = sekunden
        self.durchlaeufe = durchlaeufe
        self.textLaeuft = textLaeuft
    }
}

/// Die Regler einer Nachricht, wie `Sendeartwahl` sie bindet.
public struct Nachrichtbindungen {
    let steht: Stehtbindungen
    let aufwecken: Binding<Bool>
    let ersetzen: Binding<Bool>
    let klang: Binding<Klangwahl>

    public init(steht: Stehtbindungen, aufwecken: Binding<Bool>, ersetzen: Binding<Bool>,
                klang: Binding<Klangwahl>) {
        self.steht = steht
        self.aufwecken = aufwecken
        self.ersetzen = ersetzen
        self.klang = klang
    }
}

/// Die eine Wahl „Steht …“ mit ihrer Zahl, im Popover bzw. Blatt der Nachricht
/// und im Reiter „Zeit“ (dieselben Bindungen, also genau eine Einstellung).
/// „Durchläufe“ ist gesperrt statt versteckt, solange kein Text durchläuft:
/// Mit einem längeren Text lässt es sich einschalten.
public struct StehtWahl: View {
    let steht: Stehtbindungen
    let aktiv: Bool
    /// Für die Zeile „Standard der Uhr“; ohne Zustand entfällt sie.
    let zustand: AppZustand?

    public init(steht: Stehtbindungen, aktiv: Bool = true, zustand: AppZustand? = nil) {
        self.steht = steht
        self.aktiv = aktiv
        self.zustand = zustand
    }

    public var body: some View {
        Picker("Steht …", selection: steht.art) {
            Text("bis ich sie zurückziehe").tag(Nachrichtdauerart.bisZurueckgezogen)
            Text("Sekunden").tag(Nachrichtdauerart.sekunden)
            if steht.textLaeuft {
                Text("Durchläufe").tag(Nachrichtdauerart.durchlaeufe)
            } else {
                Text("Durchläufe (nur für Text, der durchläuft)").tag(Nachrichtdauerart.durchlaeufe)
                    .disabled(true)
            }
        }
        .disabled(!aktiv)
        switch steht.art.wrappedValue {
        case .bisZurueckgezogen:
            EmptyView()
        case .sekunden:
            LabeledContent("Anzahl") {
                Schrittwahl("Sekunden", wert: steht.sekunden, bereich: Nachrichtdauer.sekundenbereich)
            }
            .gesperrterStepper(!aktiv)
        case .durchlaeufe:
            LabeledContent("Anzahl") {
                Schrittwahl("Durchläufe", wert: steht.durchlaeufe, bereich: Nachrichtdauer.durchlaufbereich)
            }
            .gesperrterStepper(!aktiv)
        }
        if Nachrichtdauerwahl(art: steht.art.wrappedValue).faelltAufAnzeigedauer(textLaeuft: steht.textLaeuft) {
            Text("Der Text läuft nicht durch: Die Uhr nimmt ihre Anzeigedauer.")
                .font(.caption).foregroundStyle(.secondary)
            if let zustand { Standarddauerzeile(zustand: zustand) }
        }
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
/// kein Menü: Sekunden, Durchläufe und Lebensdauer sind Zahlenwerte mit Stepper, und ein
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
        // „Ändern …“ in einem dieser Blätter führt in die Einstellungen; sie
        // gehen dafür zu.
        .onChange(of: zustand.einstellungsziel) { _, neu in
            if neu != nil { zeigeKlang = false; zeigeOptionen = false; zeigeLebensdauer = false }
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
                Nachrichtabschnitt(steht: nachricht.steht, aufwecken: nachricht.aufwecken,
                                   ersetzen: nachricht.ersetzen, aktiv: true, zustand: zustand)
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
    let steht: Stehtbindungen
    @Binding var aufwecken: Bool
    @Binding var ersetzen: Bool
    let aktiv: Bool
    let zustand: AppZustand?

    public init(steht: Stehtbindungen, aufwecken: Binding<Bool>, ersetzen: Binding<Bool>, aktiv: Bool,
                zustand: AppZustand? = nil) {
        self.steht = steht
        self._aufwecken = aufwecken
        self._ersetzen = ersetzen
        self.aktiv = aktiv
        self.zustand = zustand
    }

    public var body: some View {
        Section {
            StehtWahl(steht: steht, aktiv: aktiv, zustand: zustand)
            Toggle("Aufwecken", isOn: $aufwecken)
            Toggle("Ersetzen", isOn: $ersetzen)
        } header: {
            Abschnittskopf("Nachricht", hilfe: lok("Eine Nachricht unterbricht die Schleife und belegt keinen Platz. Steht …: „bis ich sie zurückziehe“ lässt sie stehen, bis du sie beendest; „Sekunden“ zeigt sie so lange; „Durchläufe“ lässt den Text so oft durchziehen und gilt nur, wenn er nicht ins Display passt. Aufwecken: erscheint auch bei ausgeschaltetem Display. Ersetzen: verdrängt die sichtbare, statt sich hinten anzustellen. Gilt nur, wenn oben „Nachricht“ gewählt ist."))
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
