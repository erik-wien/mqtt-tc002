import SwiftUI
import TC002Core

/// **Der** Editor. Einer, nicht zwei.
///
/// Bis 13.09.2026 gab es `MalenView` (52×16) und `IconEditorView` (8×8) — zwei
/// Fassungen derselben Taetigkeit, die eine mit Bildleiste, Verzoegerung und
/// Abspielen, die andere ohne. Der Auftraggeber hat den Unterschied beim
/// Testen nicht verstanden, und das war kein Missverstaendnis, sondern ein
/// richtiges Urteil: Es gab keinen.
///
/// Die Groesse kommt von aussen (`Leinwand.breite`/`.hoehe`) — 8×8, 16×16 oder
/// 52×16. Umgerechnet wird zwischen ihnen **nicht**: ein 8×8 ist ein
/// LaMetric-Icon, ein 16×16 ist keins, und eine ganze Anzeige ist etwas
/// Drittes.
///
/// Was um den Editor herumsteht — Nummer, Name, Sichern, Sendezeile — bringt
/// der Bereich mit, der ihn benutzt; `zusatz` haengt seine Knoepfe in die
/// Werkzeugzeile.
struct PixelEditor<Zusatz: View>: View {
    @Binding var leinwand: Leinwand
    @Binding var farbe: Color
    /// Wird nach jeder Aenderung gerufen, die der Aufrufer sichern will —
    /// Strichende, Leeren, Bildleiste. Nicht bei jedem einzelnen Pixel
    /// waehrend des Ziehens: das waeren hunderte Schreibvorgaenge je Strich.
    var nachAenderung: () -> Void = {}
    @ViewBuilder var zusatz: () -> Zusatz

    @State private var radiert = false
    @State private var spielAb = false
    @State private var spielTask: Task<Void, Never>?
    /// Die verfuegbare Breite, von einem GeometryReader hinter der Flaeche
    /// gemessen. Ohne das liefe eine 52 Spalten breite Flaeche bei fester
    /// Kantenlaenge in einem schmalen Fenster rechts aus dem Bild.
    @State private var flaechenBreite: Double = 0

    /// Kantenlaenge eines Kaestchens — siehe `Malraster`.
    private var kante: Double {
        Malraster.kante(breite: leinwand.breite, hoehe: leinwand.hoehe,
                        verfuegbareBreite: flaechenBreite)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            malflaeche
            werkzeugzeile
            bildleiste
        }
        .onDisappear { stoppeAbspielen() }
    }

    // MARK: - Die Flaeche

    private var malflaeche: some View {
        Canvas { kontext, _ in
            for y in 0..<leinwand.hoehe {
                for x in 0..<leinwand.breite {
                    let r = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                   width: kante - 1, height: kante - 1)
                    let f = leinwand.farbe(x: x, y: y).flatMap(Color.init(hex:)) ?? Color(white: 0.12)
                    kontext.fill(Path(r), with: .color(f))
                }
            }
        }
        .frame(width: Double(leinwand.breite) * kante, height: Double(leinwand.hoehe) * kante)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { wert in
                let x = Int(wert.location.x / kante), y = Int(wert.location.y / kante)
                leinwand.setzen(x: x, y: y, farbe: radiert ? nil : farbe.hexWert)
            }
            .onEnded { _ in nachAenderung() })
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { flaechenBreite = geo.size.width }
                    .onChange(of: geo.size.width) { _, neu in flaechenBreite = neu }
            }
        )
    }

    // MARK: - Werkzeuge

    private var werkzeugzeile: some View {
        ViewThatFits(in: .horizontal) {
            HStack { werkzeuge }
            VStack(alignment: .leading, spacing: 8) { werkzeuge }
        }
    }

    @ViewBuilder
    private var werkzeuge: some View {
        HStack {
            ColorPicker("Farbe", selection: $farbe)
            Toggle("Radieren", isOn: $radiert).toggleStyle(.button)
            Button("Alles löschen") { leinwand.bildLeeren(); nachAenderung() }
                .help("Leert das gerade bearbeitete Einzelbild.")
            Spacer()
        }
        HStack {
            pfeilkreuz
            zusatz()
            Spacer()
        }
    }

    /// Vier Pfeile um einen Mittelpunkt — schiebt die ganze Grafik um ein
    /// Pixel. Was hinausgeschoben wird, kommt gegenueber wieder herein; warum,
    /// steht bei `Leinwand.verschieben`.
    ///
    /// Ein Kreuz und keine vier Knoepfe in einer Reihe: Richtung ist raeumlich,
    /// und in einer Reihe muesste man jedes Symbol einzeln lesen.
    private var pfeilkreuz: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.up", dx: 0, dy: -1).accessibilityLabel("Nach oben schieben")
                Color.clear.frame(width: 1, height: 1)
            }
            GridRow {
                pfeil("arrow.left", dx: -1, dy: 0).accessibilityLabel("Nach links schieben")
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.right", dx: 1, dy: 0).accessibilityLabel("Nach rechts schieben")
            }
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                pfeil("arrow.down", dx: 0, dy: 1).accessibilityLabel("Nach unten schieben")
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .help("Schiebt die ganze Grafik pixelweise. Was am Rand hinausgeschoben wird, kommt gegenüber wieder herein.")
    }

    /// Die Beschriftung fuer VoiceOver setzt der Aufrufer, nicht diese
    /// Funktion: Ein Text, der als Argument durchgereicht wird, steht fuer
    /// `scripts/texte-sammeln.py` nicht mehr an einer Stelle, die es kennt —
    /// er fehlte dann still in `en.lproj`, ohne dass die Pruefung etwas merkt.
    private func pfeil(_ symbol: String, dx: Int, dy: Int) -> some View {
        Button {
            leinwand.verschieben(dx: dx, dy: dy)
            nachAenderung()
        } label: {
            Image(systemName: symbol).frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Die Bildleiste

    /// Die waagrechte Leiste der Einzelbilder — mehrere ergeben beim Sichern
    /// ein animiertes GIF. Das gerade bearbeitete ist hervorgehoben.
    private var bildleiste: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(leinwand.bilder.indices, id: \.self) { i in
                            bildVorschau(i)
                        }
                    }
                }
                Button("+") { leinwand.anhaengen(); nachAenderung() }
                    .help("Leeres Bild anhängen")
                Button("Verdoppeln") { leinwand.verdoppeln(); nachAenderung() }
                Button("Entfernen", role: .destructive) { leinwand.entfernen(); nachAenderung() }
                    .disabled(leinwand.bilder.count <= 1)
            }
            HStack {
                Button { leinwand.tauschen(um: -1); nachAenderung() } label: { Image(systemName: "arrow.left") }
                    .disabled(leinwand.aktuell == 0)
                    .accessibilityLabel(Text("Bild nach vorn"))
                Button { leinwand.tauschen(um: 1); nachAenderung() } label: { Image(systemName: "arrow.right") }
                    .disabled(leinwand.aktuell == leinwand.bilder.count - 1)
                    .accessibilityLabel(Text("Bild nach hinten"))
                Text("Verzögerung")
                TextField("", value: $leinwand.verzoegerung, format: .number)
                    .frame(width: 50)
                Text("s")
                Button(spielAb ? lok("Stopp") : lok("Abspielen")) { abspielenUmschalten() }
                    .disabled(leinwand.bilder.count < 2)
                Spacer()
            }
        }
    }

    private func bildVorschau(_ i: Int) -> some View {
        Canvas { kontext, groesse in
            let kante = groesse.width / Double(leinwand.breite)
            for y in 0..<leinwand.hoehe {
                for x in 0..<leinwand.breite {
                    let feld = CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                      width: kante, height: kante)
                    let p = leinwand.bilder[i][y * leinwand.breite + x]
                    kontext.fill(Path(feld), with: .color(p.flatMap(Color.init(hex:)) ?? .black))
                }
            }
        }
        // Die Vorschau behaelt das Seitenverhaeltnis der Leinwand: bei 52×16
        // ist ein Quadrat nicht dasselbe Bild, sondern ein anderes.
        .frame(width: 28, height: 28 * Double(leinwand.hoehe) / Double(leinwand.breite))
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3)
            .stroke(leinwand.aktuell == i ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: leinwand.aktuell == i ? 2 : 1))
        .onTapGesture { stoppeAbspielen(); leinwand.waehlen(i) }
    }

    /// Laeuft die Leiste in Schleife durch, solange „Abspielen" gedrueckt ist —
    /// nur zur Ansicht, ohne dass vorher gesichert werden muss.
    private func abspielenUmschalten() {
        guard !spielAb else { stoppeAbspielen(); return }
        spielAb = true
        spielTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(max(0.05, leinwand.verzoegerung)))
                guard !Task.isCancelled, leinwand.bilder.count > 1 else { continue }
                await MainActor.run { leinwand.waehlen((leinwand.aktuell + 1) % leinwand.bilder.count) }
            }
        }
    }

    private func stoppeAbspielen() {
        spielAb = false
        spielTask?.cancel()
        spielTask = nil
    }
}

extension PixelEditor where Zusatz == EmptyView {
    init(leinwand: Binding<Leinwand>, farbe: Binding<Color>, nachAenderung: @escaping () -> Void = {}) {
        self.init(leinwand: leinwand, farbe: farbe, nachAenderung: nachAenderung) { EmptyView() }
    }
}
