import SwiftUI
import TC002Core
import TC002Modell

/// Waehlt, an welche Uhr oder Uhren gesendet wird. Ein Knopf, der das Ziel
/// benennt, oeffnet ein Blatt mit einer Zeile je Uhr. Von allen drei
/// Sendeflaechen gemeinsam genutzt — zwei verschiedene Bedienungen fuer
/// dieselbe Sache waeren schlimmer als gar keine.
///
/// **Ein Blatt und kein `Menu`.** Am Telefon stand hier ein Menue mit einer
/// Zeile je Uhr; es schloss sich nach jedem Antippen, und wer drei Uhren
/// waehlen wollte, oeffnete es dreimal. Ein Menue fuehrt genau einen Befehl
/// aus — eine Mehrfachauswahl gehoert nach Apples Vorgabe in ein Blatt, das
/// stehen bleibt, bis man es schliesst. Erik: *„Bei der Empängerauswahl nicht
/// nach jeder Auswahl gleich schließen sondern ein schließen (x)
/// hinzufügen."*
///
/// Erscheint erst ab zwei eingerichteten Uhren: bei nur einer ist die Wahl
/// bedeutungslos, und ein gesperrter oder ausgegrauter Knopf waere nur
/// zusaetzliche, wirkungslose Flaeche.
public struct ZielauswahlView: View {
    @Bindable var zustand: AppZustand
    /// Wo der Knopf steht — davon haengt seine Fassung ab, nicht sein Inhalt.
    var stil: Zielstil = .leiste
    @State private var zeigeBlatt = false

    public init(zustand: AppZustand, stil: Zielstil = .leiste) {
        self.zustand = zustand
        self.stil = stil
    }

    /// Zwei Stellen, zwei Fassungen desselben Knopfs.
    ///
    /// In der Werkzeugleiste zeichnet iPadOS schon eine Kapsel um jedes
    /// Element; ein eigener Befehlsknopf darin ergab eine Pille in der Pille.
    /// Erik, mit einem Kringel um die Stelle: *„Pille um die Pille???"*
    ///
    /// Im Inhalt des Editors gibt es keine Leiste, die eine Fassung
    /// mitbraechte — dort traegt er seine eigene, rund wie das ✕ und der
    /// Haken darueber.
    public enum Zielstil: Equatable, Sendable {
        case leiste, rund
    }

    /// Was der Knopf gerade bedeutet, mit Fallback auf die aktive Uhr — genau
    /// das, was `AppZustand.ziele()` auch tatsaechlich verschickt.
    private var gewaehlteIDs: Set<UUID> {
        zustand.zielIDs.isEmpty ? Set(zustand.aktiveID.map { [$0] } ?? []) : zustand.zielIDs
    }

    private var beschriftung: String {
        let gewaehlt = gewaehlteIDs
        let anzahlUhren = zustand.uhren.count
        if anzahlUhren > 1, gewaehlt.count == anzahlUhren {
            return lokf("an alle Uhren (%d)", anzahlUhren)
        }
        if gewaehlt.count == 1, let uhr = zustand.uhren.first(where: { $0.id == gewaehlt.first }) {
            return lokf("an: %@", uhr.name)
        }
        return lokf("an %d Uhren", gewaehlt.count)
    }

    public var body: some View {
        if zustand.uhren.count > 1 {
            Button {
                // Vor dem Oeffnen konkretisieren: sonst zeigte das Blatt bei
                // leerer Auswahl keine Uhr angehakt, obwohl der Knopf eben
                // noch die aktive Uhr als Ziel genannt hat.
                if zustand.zielIDs.isEmpty { zustand.zielIDs = gewaehlteIDs }
                zeigeBlatt = true
            } label: {
                zeichen
            }
            .fassung(stil)
            .help(beschriftung)
            .accessibilityLabel(Text(beschriftung))
            .sheet(isPresented: $zeigeBlatt) { blatt.halbeHoehe() }
        }
    }

    /// Nur das Antennensymbol, kein Wort.
    ///
    /// Es stand einmal „Empfänger · 2" daran. Erik: *„Die Empfängerschaltfläche
    /// ist noch ein Artefakt von früher, dafür haben wir im Sendemodul ein
    /// neues Symbol, das ich bitte zu übernehmen."* Wohin es geht, sagt der
    /// Einblendtext, die Sprachausgabe und das Blatt selbst.
    private var zeichen: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            // Der Platz fuer die Zahl gehört zum Zeichen, statt sie mit
            // `offset` darüber hinauszuschieben: Die Werkzeugleiste des
            // Telefons legt einen Kreis um ihr Element und schneidet alles ab,
            // was außerhalb liegt — von „2/3" blieb ein halbes „2".
            // Auf beiden Seiten gleich viel, sonst säße die Antenne im Kreis
            // nicht mehr mittig.
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            // Hochgestellt und winzig, wie eine Fussnote: „2/4" sagt in zwei
            // Zeichen, was der Satz daneben in fünf Wörtern sagte. Erik: *„das
            // empfänger symbol könnte auch so eine hochgestellte minimale
            // bekommen, die zeigt 2/4 uhren sind ausgewählt."*
            .overlay(alignment: .topTrailing) {
                Text(verbatim: "\(gewaehlteIDs.count)/\(zustand.uhren.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    // Eine graue Pille darunter, kein blanker Text: Frei neben
                    // dem Zeichen stehend las sich die Zahl wie ein
                    // Ausrutscher. Erik: *„¼ gehört imho in eine graue Pille.
                    // So schaut's jedenfalls nicht gut aus."* Ein Abzeichen an
                    // einem Symbol ist der gewöhnliche Weg — Apple setzt es an
                    // Tableisten und Listenzeilen ebenso.
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.quaternary))
                    .fixedSize()
                    .allowsHitTesting(false)
            }
    }

    private var blatt: some View {
        Blatt(titel: lok("An welche Uhr senden?"),
              schliessen: { zeigeBlatt = false }) {
            VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Alle") { zustand.zielIDs = Set(zustand.uhren.map(\.id)) }
                    .knopfBefehl()
                // „Nur die angesehene" statt „Keine": Ein Knopf, der die
                // leere Menge schreibt, heisst fuer diese App „die
                // angesehene Uhr", fuer Werkzeug und Kurzbefehle aber alle
                // (`Einstellungen.ziele`). Dieselbe Einstellung, zwei
                // Bedeutungen — mit „Keine" ginge der naechste Kurzbefehl an
                // jede eingerichtete Uhr.
                Button("Nur die angesehene") {
                    if let aktiveID = zustand.aktiveID { zustand.zielIDs = [aktiveID] }
                }
                .knopfBefehl()
                Spacer()
            }

            List(zustand.uhren) { uhr in
                // Ueber `zielUmschalten` und nicht ueber `insert`/`remove`:
                // Dort steht die Regel, dass die Menge nie leer wird.
                Toggle(isOn: Binding(
                    get: { zustand.zielIDs.contains(uhr.id) },
                    set: { _ in zustand.zielUmschalten(uhr.id) }
                )) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(uhr.name)
                            HStack(spacing: 6) {
                                // Woran eine Uhr fehlt, haengt an ihrer
                                // Betriebsart. „Kein Präfix" war fuer eine
                                // HTTP-Uhr die falsche Warnung: Sie braucht
                                // keines, und der Satz schickte jemanden zu
                                // „Abfragen", wo nichts zu holen war.
                                //
                                // `lok(…)`, weil ein Ternär mit einem
                                // `String`-Zweig SwiftUI in die
                                // `StringProtocol`-Überladung zwingt — die
                                // schlägt nichts nach.
                                if !uhr.beschickbar {
                                    Label(uhr.wirksameBetriebsart == .http
                                          ? lok("keine Adresse — kann nichts empfangen")
                                          : lok("kein Präfix — kann erst empfangen, wenn abgefragt"),
                                          systemImage: "exclamationmark.triangle")
                                        .font(.caption).foregroundStyle(.orange)
                                } else if uhr.wirksameBetriebsart == .http {
                                    Text("HTTP")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(uhr.praefix)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                // Nur die abweichende Gattung steht da. „Ulanzi
                                // TC002" an jeder Zeile waere eine Angabe, die
                                // nichts unterscheidet — und die Zeile soll
                                // sagen, was diese Uhr von den anderen
                                // trennt.
                                if uhr.gattung != .tc002 {
                                    Text(uhr.gattung.beschriftung)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Brokerzeichen(uhr: uhr, steht: zustand.verbunden[uhr.id])
                            }
                        }
                        Spacer()
                    }
                }
                // Nur am Mac: `.checkbox` gibt es unter iOS nicht. Dort bleibt
                // die Vorgabe (der Schalter) — geteilt wird die Ansicht, nicht
                // der Stil.
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
            }
            .frame(minHeight: 160)
            }
            // Nur am Mac: Dort hat ein Blatt keine eigene Groesse und
            // schrumpfte sonst auf die Breite seiner laengsten Zeile. Am
            // Finger gibt die Hoehe des Blattes das Mass vor (`halbeHoehe`),
            // und 280 Punkte Mindesthoehe stuenden ihr im Weg.
            #if os(macOS)
            .frame(minWidth: 340, minHeight: 280)
            #endif
        }
    }
}

private extension View {
    /// Am Finger nimmt das Blatt die halbe Hoehe und laesst sich hochziehen.
    ///
    /// Vier Uhren sind vier Zeilen; ueber die ganze Hoehe gezogen stand
    /// darunter mehr Leerflaeche als Inhalt. `presentationDetents` gibt es
    /// nicht unter macOS — dort ist ein Blatt ohnehin ein Fenster in
    /// Inhaltsgroesse.
    @ViewBuilder
    func halbeHoehe() -> some View {
        #if os(macOS)
        self
        #else
        presentationDetents([.medium, .large])
        #endif
    }

    /// Die Fassung je Stelle — in der Leiste keine eigene, im Inhalt ein
    /// Kreis wie beim ✕ und beim Haken.
    @ViewBuilder
    func fassung(_ stil: ZielauswahlView.Zielstil) -> some View {
        switch stil {
        case .leiste: buttonStyle(.plain)
        // `.large`, damit der Kreis so gross wird wie das ✕ und der Haken
        // darueber: Drei Kreise verschiedener Groesse untereinander lesen sich
        // wie drei verschiedene Arten von Knopf.
        case .rund: knopfBefehl().buttonBorderShape(.circle).controlSize(.large)
        }
    }
}
