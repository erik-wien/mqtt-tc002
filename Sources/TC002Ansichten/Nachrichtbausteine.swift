import SwiftUI
import TC002Core
import TC002Modell

/// Was „Senden“ schickt: eine Anzeige auf einen der fünf Plätze oder eine
/// Nachricht (im Protokoll: Benachrichtigung), die die Schleife einmal
/// unterbricht und keinen Platz belegt. Der Rohwert liegt in `@AppStorage`.
public enum Sendeart: String, CaseIterable, Sendable {
    case anzeige, nachricht
}

/// Das Segment „Anzeige | Nachricht“ über dem Eingabefeld — am Mac, iPad und
/// iPhone dasselbe. Daneben „Nachricht zurückziehen“, solange eine von der App
/// geschickte, gehaltene Nachricht steht; es gilt für alle gewählten Uhren.
public struct Sendeartwahl: View {
    @Bindable var zustand: AppZustand
    @Binding var art: Sendeart

    public init(zustand: AppZustand, art: Binding<Sendeart>) {
        self.zustand = zustand
        self._art = art
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
            if zustand.nachrichtGehalten {
                Button {
                    Task { await zustand.benachrichtigungZurueckziehen() }
                } label: {
                    Label("Nachricht zurückziehen", systemImage: "bell.slash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .lineLimit(1)
                .fixedSize()
                .disabled(zustand.ziele().isEmpty)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Die Regler einer Nachricht — im Reiter „Zeit“ (Mac, iPad) und im
/// Formatblatt (iPhone). Gesperrt statt versteckt, solange „Anzeige“ gewählt
/// ist: ein Abschnitt, der erscheint und verschwindet, lässt den Inspektor
/// springen.
public struct Nachrichtabschnitt: View {
    @Binding var halten: Bool
    @Binding var aufwecken: Bool
    @Binding var ersetzen: Bool
    @Binding var durchlaeufe: Int
    let aktiv: Bool

    public init(halten: Binding<Bool>, aufwecken: Binding<Bool>, ersetzen: Binding<Bool>,
                durchlaeufe: Binding<Int>, aktiv: Bool) {
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
            Stepper(value: $durchlaeufe, in: 1...Nachrichtwahl.hoechstdurchlaeufe) {
                LabeledContent("Durchläufe") {
                    Text(verbatim: "\(durchlaeufe)").monospacedDigit()
                }
            }
        } header: {
            Abschnittskopf("Nachricht", hilfe: lok("Eine Nachricht unterbricht die Schleife und belegt keinen Platz. Halten: bleibt stehen, bis sie zurückgezogen wird. Aufwecken: erscheint auch bei ausgeschaltetem Display. Ersetzen: verdrängt die sichtbare, statt sich hinten anzustellen. Durchläufe: wie oft ein laufender Text durchzieht. Gilt nur, wenn oben „Nachricht“ gewählt ist."))
        }
        .disabled(!aktiv)
    }
}

/// Wie lange eine neue Anzeige lebt: „Behalten“ (Vorgabe aus), danach Zahl,
/// Einheit und was geschieht. Bei „Behalten“ sind „Nach“ und „Dann“ gesperrt,
/// nicht versteckt. Gilt nur für Anzeigen; bei „Nachricht“ ist der ganze
/// Abschnitt gesperrt.
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
            Stepper(value: $zahl, in: 1...Lebensdauerwahl.hoechstzahl) {
                LabeledContent("Nach") {
                    Text(verbatim: "\(zahl)").monospacedDigit()
                }
            }
            .disabled(behalten)
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
