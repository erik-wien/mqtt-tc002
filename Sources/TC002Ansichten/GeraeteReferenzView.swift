import SwiftUI
import TC002Core

/// Die Gerätereferenz: dieselbe Datei wie `docs/tc002-protokoll.md`, von
/// `build.sh` ins App-Paket kopiert und hier dargestellt. Dafür braucht es
/// einen Markdown-Zerleger — es gibt bewusst keine Paketabhängigkeit dafür,
/// und die Datei kommt ausschließlich aus unserer eigenen Hand, die darin
/// vorkommenden Formen sind also bekannt und eng begrenzt (siehe
/// `MarkdownDokument.parse` unten für die Liste).
public struct GeraeteReferenzView: View {
    @State private var ausgewaehlt: MarkdownAbschnitt.ID?

    /// **Zwei Geraete, zwei Dokumente.** Welches gilt, waehlt der Leser — nicht
    /// die eingerichtete Uhr: Die Referenz ist Nachschlagewerk, kein Zustand
    /// der App, und wer wissen will, was eine AWTRIX kann, hat meist noch
    /// keine eingetragen.
    @State private var gattung: Geraetetyp = .tc002
    @State private var abschnitte: [MarkdownAbschnitt] = []
    @State private var ladefehler: String?

    /// Die Referenz gibt es in zwei Sprachen, als zwei Dateien — nicht als
    /// uebersetzte Einzeltexte: ein durchgehendes Dokument gehoert am Stueck
    /// uebersetzt. Welche gilt, entscheidet dieselbe Wahl, die auch der Rest
    /// der Oberflaeche trifft; ohne englische Fassung bleibt es bei der
    /// deutschen.
    private static func referenzdatei(_ gattung: Geraetetyp) -> URL? {
        let englisch = Bundle.main.preferredLocalizations.first?.hasPrefix("en") == true
        // Die englische Fassung zuerst, die deutsche als Rueckfall — eine
        // fehlende Uebersetzung soll die Referenz nicht verschwinden lassen.
        let namen: [String]
        switch gattung {
        case .tc002:
            namen = englisch ? ["tc002-protocol.md", "tc002-protokoll.md"] : ["tc002-protokoll.md"]
        case .awtrixNG:
            namen = englisch ? ["awtrix-ng-protocol.md", "awtrix-ng-protokoll.md"]
                             : ["awtrix-ng-protokoll.md"]
        }
        return namen.lazy
            .compactMap { Bundle.main.resourceURL?.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    public init() {}

    /// Gelesen wird beim Erscheinen und bei jedem Wechsel der Gattung
    /// (`.task(id:)`), nicht im `init`: Die gewaehlte Gattung ist Zustand der
    /// Ansicht, und ein `init` sieht sie nur einmal.
    private func laden() {
        guard let url = Self.referenzdatei(gattung),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            abschnitte = []
            ausgewaehlt = nil
            ladefehler = lok("Die Gerätereferenz liegt nicht im App-Paket. Das passiert, wenn die App nicht über ./build.sh gebaut, sondern direkt aus Xcode gestartet wurde.")
            return
        }
        abschnitte = MarkdownDokument.gliedern(MarkdownDokument.parse(text))
        ladefehler = nil
        // Beim Wechsel auf das erste Kapitel des neuen Dokuments: Eine Auswahl
        // aus dem alten zeigte sonst auf nichts, und die rechte Seite bliebe leer.
        ausgewaehlt = abschnitte.first?.id
    }

    public var body: some View {
        Group {
            if let ladefehler {
                ContentUnavailableView(
                    "Gerätereferenz nicht gefunden",
                    systemImage: "doc.questionmark",
                    description: Text(ladefehler)
                )
                // Nur am Mac: Am iPad steht der Fehlerschirm in einer
                // ganzflaechigen Einblendung, die auch 320 Punkte breit sein
                // kann (Slide Over) — eine Forderung nach 480 schnitte ihn
                // dort an.
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 320)
                #endif
            } else {
                NavigationSplitView {
                    VStack(spacing: 0) {
                        // Zwei Eigennamen, keine uebersetzbaren Saetze —
                        // deshalb `verbatim` und nicht `lok`.
                        Picker("Gerät", selection: $gattung) {
                            ForEach(Geraetetyp.allCases, id: \.self) { art in
                                Text(verbatim: art.beschriftung).tag(art)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .padding(8)
                        List(abschnitte, selection: $ausgewaehlt) { a in
                            Text(a.titel).tag(a.id)
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 280)
                } detail: {
                    let a = abschnitte.first(where: { $0.id == ausgewaehlt }) ?? abschnitte.first
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(a?.bloecke ?? []) { block in
                                MarkdownBlockView(block: block)
                            }
                        }
                        .frame(maxWidth: 720, alignment: .leading)
                        .padding(24)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                // Nur am Mac, wo das Fenster gezogen werden kann. Kein iPad
                // erreicht 880 Punkte im Hochformat ausser dem 13-Zoll-Geraet
                // (1024); mini (744), iPad (820) und Air 11" (834) schnitten
                // die Referenz an, und in geteilter Ansicht jedes. Die
                // zweispaltige Gliederung klappt unter iOS von selbst
                // zusammen, wenn es eng wird — dafuer braucht sie keine
                // Mindestbreite, sondern deren Abwesenheit.
                #if os(macOS)
                .frame(minWidth: 880, minHeight: 620)
                #endif
                .onAppear {
                    if ausgewaehlt == nil { ausgewaehlt = abschnitte.first?.id }
                }
            }
        }
        .task(id: gattung) { laden() }
    }
}

// MARK: - Modell

private struct MarkdownBlock: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case heading(Int, String)
        case paragraph(String)
        case listItem(marker: String?, text: String)
        case quote(String)
        case code(String)
        case table([[String]])
        case hr
    }
}

private struct MarkdownAbschnitt: Identifiable {
    let id = UUID()
    let titel: String
    let bloecke: [MarkdownBlock]
}

// MARK: - Zerleger
//
// Unterstützte Formen (alles, was in `docs/tc002-protokoll.md` vorkommt):
// Überschriften `#`/`##`/`###`, Absätze mit `**fett**`/`` `Code` ``/Links,
// eingerückte ```-Codeblöcke, Aufzählungen mit `- ` UND mit `1. ` (beides kommt
// in der Datei vor — §6 zählt durch), Zitatblöcke mit `> `, Tabellen mit `|`
// und waagrechte Linien `---`. Zeilen, die zu einem Absatz/Listenpunkt/Zitat
// gehören, sind in der Quelldatei von Hand auf ~80 Zeichen umgebrochen und
// werden hier wieder zu einer logischen Zeile zusammengefügt.
private enum MarkdownDokument {
    static func parse(_ text: String) -> [MarkdownBlock] {
        var bloecke: [MarkdownBlock] = []
        let zeilen = text.components(separatedBy: "\n")
        var i = 0

        while i < zeilen.count {
            let zeile = zeilen[i].trimmingCharacters(in: .whitespaces)
            if zeile.isEmpty { i += 1; continue }

            if zeile.hasPrefix("```") {
                i += 1
                var code: [String] = []
                while i < zeilen.count, !zeilen[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(zeilen[i])
                    i += 1
                }
                i += 1 // schließende ``` überspringen
                bloecke.append(MarkdownBlock(kind: .code(code.joined(separator: "\n"))))
                continue
            }

            if zeile == "---" {
                bloecke.append(MarkdownBlock(kind: .hr))
                i += 1
                continue
            }

            if zeile.hasPrefix("### ") {
                bloecke.append(MarkdownBlock(kind: .heading(3, String(zeile.dropFirst(4)))))
                i += 1
                continue
            }
            if zeile.hasPrefix("## ") {
                bloecke.append(MarkdownBlock(kind: .heading(2, String(zeile.dropFirst(3)))))
                i += 1
                continue
            }
            if zeile.hasPrefix("# ") {
                bloecke.append(MarkdownBlock(kind: .heading(1, String(zeile.dropFirst(2)))))
                i += 1
                continue
            }

            if zeile.hasPrefix("|") {
                var tabellenzeilen: [String] = []
                while i < zeilen.count {
                    let t = zeilen[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix("|") else { break }
                    tabellenzeilen.append(t)
                    i += 1
                }
                var werte: [[String]] = []
                for (idx, zeile) in tabellenzeilen.enumerated() {
                    if idx == 1 { continue } // Kopf-Trennzeile |---|---|
                    var zellen = zeile.split(separator: "|", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    if zellen.first == "" { zellen.removeFirst() }
                    if zellen.last == "" { zellen.removeLast() }
                    werte.append(zellen)
                }
                bloecke.append(MarkdownBlock(kind: .table(werte)))
                continue
            }

            if zeile.hasPrefix("> ") || zeile == ">" {
                var teile: [String] = []
                while i < zeilen.count {
                    let t = zeilen[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    var rest = t.dropFirst()
                    if rest.hasPrefix(" ") { rest = rest.dropFirst() }
                    teile.append(String(rest))
                    i += 1
                }
                bloecke.append(MarkdownBlock(kind: .quote(teile.joined(separator: " "))))
                continue
            }

            if zeile.hasPrefix("- ") {
                var teile = [String(zeile.dropFirst(2))]
                i += 1
                while i < zeilen.count {
                    let t = zeilen[i].trimmingCharacters(in: .whitespaces)
                    if istNeuerBlockstart(t) { break }
                    teile.append(t)
                    i += 1
                }
                bloecke.append(MarkdownBlock(kind: .listItem(marker: nil, text: teile.joined(separator: " "))))
                continue
            }

            if let (marker, rest) = nummerierung(zeile) {
                var teile = [rest]
                i += 1
                while i < zeilen.count {
                    let t = zeilen[i].trimmingCharacters(in: .whitespaces)
                    if istNeuerBlockstart(t) { break }
                    teile.append(t)
                    i += 1
                }
                bloecke.append(MarkdownBlock(kind: .listItem(marker: marker, text: teile.joined(separator: " "))))
                continue
            }

            // gewöhnlicher Absatz
            var teile = [zeile]
            i += 1
            while i < zeilen.count {
                let t = zeilen[i].trimmingCharacters(in: .whitespaces)
                if istNeuerBlockstart(t) { break }
                teile.append(t)
                i += 1
            }
            bloecke.append(MarkdownBlock(kind: .paragraph(teile.joined(separator: " "))))
        }

        return bloecke
    }

    /// Gliedert die Blöcke anhand der `##`-Überschriften — die Datei hat davon
    /// sieben, durchnummeriert. Alles vor der ersten `##`-Überschrift (Titel,
    /// Einleitung, Legende) landet in einem vorangestellten „Überblick“.
    static func gliedern(_ bloecke: [MarkdownBlock]) -> [MarkdownAbschnitt] {
        var abschnitte: [MarkdownAbschnitt] = []
        var titel = "Überblick"
        var aktuell: [MarkdownBlock] = []
        for block in bloecke {
            if case .heading(2, let text) = block.kind {
                if !aktuell.isEmpty {
                    abschnitte.append(MarkdownAbschnitt(titel: titel, bloecke: aktuell))
                }
                titel = text
                aktuell = [block]
            } else {
                aktuell.append(block)
            }
        }
        if !aktuell.isEmpty {
            abschnitte.append(MarkdownAbschnitt(titel: titel, bloecke: aktuell))
        }
        return abschnitte
    }

    private static func istNeuerBlockstart(_ zeile: String) -> Bool {
        zeile.isEmpty
            || zeile.hasPrefix("#")
            || zeile.hasPrefix(">")
            || zeile.hasPrefix("|")
            || zeile.hasPrefix("```")
            || zeile == "---"
            || zeile.hasPrefix("- ")
            || nummerierung(zeile) != nil
    }

    /// Erkennt eine Zeile wie `1. Präfix.` und liefert Marker (`1.`) und Rest.
    private static func nummerierung(_ zeile: String) -> (marker: String, rest: String)? {
        guard let punkt = zeile.firstIndex(of: ".") else { return nil }
        let ziffern = zeile[zeile.startIndex..<punkt]
        guard !ziffern.isEmpty, ziffern.allSatisfy({ $0.isNumber }) else { return nil }
        let nachPunkt = zeile.index(after: punkt)
        guard nachPunkt < zeile.endIndex, zeile[nachPunkt] == " " else { return nil }
        let rest = zeile[zeile.index(after: nachPunkt)...]
        return (String(zeile[zeile.startIndex...punkt]), String(rest))
    }
}

// MARK: - Darstellung

/// Wandelt eine einzelne logische Zeile (Absatz, Listenpunkt, Zitat, Tabellenzelle)
/// mit `**fett**`, `` `Code` `` und `[Text](Adresse)` in klickbaren `Text` um.
private func inlineText(_ text: String) -> Text {
    if let attributiert = try? AttributedString(
        markdown: text,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    ) {
        return Text(attributiert)
    }
    return Text(text)
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block.kind {
        case .heading(let ebene, let text):
            inlineText(text)
                .font(schrift(fuerEbene: ebene))
                .padding(.top, ebene == 2 ? 10 : 4)
        case .paragraph(let text):
            inlineText(text)
        case .listItem(let marker, let text):
            ListenpunktView(marker: marker, text: text)
        case .quote(let text):
            ZitatView(text: text)
        case .code(let text):
            CodeBlockView(text: text)
        case .table(let zeilen):
            TabelleView(zeilen: zeilen)
        case .hr:
            Divider()
        }
    }

    private func schrift(fuerEbene ebene: Int) -> Font {
        switch ebene {
        case 1: return .title.bold()
        case 2: return .title2.bold()
        default: return .title3.weight(.semibold)
        }
    }
}

private struct ListenpunktView: View {
    let marker: String?
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(marker ?? "•")
                .frame(minWidth: marker == nil ? 12 : 22, alignment: .trailing)
            inlineText(text)
        }
    }
}

private struct ZitatView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 3)
            inlineText(text)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.08)))
    }
}

private struct CodeBlockView: View {
    let text: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .fixedSize(horizontal: true, vertical: false)
                .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
    }
}

private struct TabelleView: View {
    let zeilen: [[String]]

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 8) {
            ForEach(Array(zeilen.enumerated()), id: \.offset) { index, zeile in
                GridRow {
                    ForEach(Array(zeile.enumerated()), id: \.offset) { _, zelle in
                        inlineText(zelle)
                            .fontWeight(index == 0 ? .semibold : .regular)
                    }
                }
                if index == 0 {
                    Divider().gridCellColumns(max(zeile.count, 1))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}
