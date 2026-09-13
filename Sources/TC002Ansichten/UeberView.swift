import SwiftUI
import TC002Core

#if canImport(AppKit)
import AppKit
#endif

/// Das Über-Fenster. Am Mac ersetzt es den Vorgabedialog von macOS
/// (`CommandGroup(replacing: .appInfo)` in `App.swift`), am iPhone hängt es
/// als Blatt am Fuß der Einstellungen: iOS stellt dafür keine Stelle, und die
/// eingebürgerte ist das Ende der App-eigenen Einstellungen.
///
/// Reines SwiftUI ohne Netzzugriff, alle Verweise sind Text und werden nur
/// über `Link` im Browser geöffnet.
///
/// Das Programmsymbol oben gibt es nur am Mac: `NSApp.applicationIconImage`
/// hat unter iOS keine Entsprechung, die ohne Raten an das Symbol käme. Ein
/// Über-Fenster ohne Symbol ist besser als eines, das beim Bauen bricht.
public struct UeberView: View {
    @State private var lizenztextSichtbar = false
    @State private var micro5LizenztextSichtbar = false
    @State private var silkscreenLizenztextSichtbar = false
    @State private var tiny5LizenztextSichtbar = false

    public init() {}

    /// Fassung samt Commit. Die Nummer allein sagt nicht, welchen Bau man vor
    /// sich hat — zwischen zwei Veroeffentlichungen entstehen viele, und alle
    /// tragen dieselbe. Der angehaengte Commit macht ein laufendes Programm
    /// eindeutig zuordenbar; ein „+" heisst, es wurde aus einem geaenderten,
    /// nicht eingecheckten Stand gebaut. Das iOS-Projekt traegt ihn nicht ein,
    /// dort bleibt es bei der Nummer.
    private var fassung: String {
        let info = Programmbuendel.eigenes.infoDictionary
        let nummer = info?["CFBundleShortVersionString"] as? String ?? "–"
        guard let commit = info?["TC002Commit"] as? String,
              !commit.isEmpty, commit != "unbekannt" else { return nummer }
        return "\(nummer) (\(commit))"
    }

    public var body: some View {
        #if canImport(AppKit)
        // Feste Größe wie bisher: ein Über-Fenster, das man zieht, ist keines.
        blaetter(inhalt.padding(28).frame(width: 440, height: 620).fixedSize())
        #else
        // Am Telefon rollt der Inhalt: 620 Punkte Höhe passen auf kein iPhone,
        // und eine feste Breite schnitte bei großen Textgrößen ab.
        blaetter(ScrollView { inhalt.padding(20) })
        #endif
    }

    /// Die vier Lizenztexte hängen an beiden Fassungen gleich.
    private func blaetter<Inhalt: View>(_ ansicht: Inhalt) -> some View {
        ansicht
            .sheet(isPresented: $lizenztextSichtbar) {
                LizenztextView(dismiss: { lizenztextSichtbar = false })
            }
            .sheet(isPresented: $micro5LizenztextSichtbar) {
                LizenztextView(dismiss: { micro5LizenztextSichtbar = false }, pfad: "Schriften/OFL-Micro5.txt")
            }
            .sheet(isPresented: $silkscreenLizenztextSichtbar) {
                LizenztextView(dismiss: { silkscreenLizenztextSichtbar = false }, pfad: "Schriften/OFL-Silkscreen.txt")
            }
            .sheet(isPresented: $tiny5LizenztextSichtbar) {
                LizenztextView(dismiss: { tiny5LizenztextSichtbar = false }, pfad: "Schriften/OFL-Tiny5.txt")
            }
    }

    private var inhalt: some View {
        VStack(spacing: 18) {
            #if canImport(AppKit)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            #endif

            VStack(spacing: 2) {
                Text("MQTT-TC002").font(.title2).fontWeight(.semibold)
                Text(lokf("Version %@", fassung))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Schickt Text-, Icon- und Bildanzeigen über MQTT an Ulanzi-TC002-Pixeluhren.")
                .font(.callout)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                Text("Lizenz").font(.subheadline).fontWeight(.semibold)
                Text("GPL-3.0, weil die App auf Teilen von PixDeck aufbaut, das selbst unter der GPL-3.0 steht.")
                Link("www.gnu.org/licenses/gpl-3.0.html", destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
                textknopf(lok("Lizenztext anzeigen…")) { lizenztextSichtbar = true }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Danksagungen").font(.subheadline).fontWeight(.semibold)
                danksagung(
                    name: "PixDeck",
                    url: "https://github.com/cailurus/PixDeck",
                    text: "Von PixDeck stammt die Erkenntnis, dass sich dasselbe Rahmen-JSON auch per HTTP an /api/custom?name= schicken lässt — und die GPL-3.0-Lizenz, unter der auch diese App steht."
                )
                danksagung(
                    name: "Ulanzi",
                    url: "https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002",
                    text: "Das Herstellerrepository belegt die Präfixbildung der Themen und die Zeichenbefehle der Uhr."
                )
                danksagung(
                    name: "AWTRIX",
                    url: "https://blueforcer.github.io/awtrix-light/",
                    text: "Aus der AWTRIX-Gemeinschaft rund um solche Pixeluhren stammt die Sitte, Icons über LaMetric-Nummern anzusprechen."
                )
                danksagung(
                    name: "LaMetric",
                    url: "https://developer.lametric.com/icons",
                    text: "Herkunft der Icons, die sich über ihre Nummer nachladen lassen."
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pixelschriften").fontWeight(.semibold)
                    Text("Drei mitgelieferte, eigens aufs Pixelraster gezeichnete Schriften, die Umlaute und „ß“ können — anders als die eingebaute Gerätschrift. Alle drei SIL Open Font License 1.1.")
                    HStack(spacing: 4) {
                        Link("Micro 5", destination: URL(string: "https://github.com/scfried/soft-type-micro")!)
                        textknopf(lok("Lizenztext…")) { micro5LizenztextSichtbar = true }
                    }
                    HStack(spacing: 4) {
                        Link("Silkscreen", destination: URL(string: "https://github.com/googlefonts/silkscreen")!)
                        textknopf(lok("Lizenztext…")) { silkscreenLizenztextSichtbar = true }
                    }
                    HStack(spacing: 4) {
                        Link("Tiny5", destination: URL(string: "https://github.com/Gissio/font_tiny5")!)
                        textknopf(lok("Lizenztext…")) { tiny5LizenztextSichtbar = true }
                    }
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Claude Code & erik.huemer@jardyx.com • www.jardyx.com")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Ein Knopf, der wie ein Verweis aussieht — den Stil `.link` gibt es nur
    /// unter macOS; am Telefon ist die Vorgabe schon ein blauer Text.
    ///
    /// Die Beschriftung kommt schon übersetzt herein (`lok(…)`): Ein `String`
    /// an `Button` trifft die Überladung, die nichts nachschlägt, und der
    /// Textsammler fände eine Zeichenkette in diesem eigenen Aufruf ohnehin
    /// nicht.
    @ViewBuilder
    private func textknopf(_ titel: String, _ aktion: @escaping () -> Void) -> some View {
        #if canImport(AppKit)
        Button(titel, action: aktion).buttonStyle(.link)
        #else
        Button(titel, action: aktion)
        #endif
    }

    private func danksagung(name: String, url: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Link(name, destination: URL(string: url)!)
                .fontWeight(.semibold)
            Text(text)
        }
    }
}

/// Zeigt einen Lizenztext aus dem App-Paket an — Vorgabe die GPL-3.0 aus
/// `LICENSE`, wahlweise auch die SIL Open Font License einer der drei
/// Pixelschriften aus `Schriften/OFL-*.txt`. Am Mac kopiert `build.sh` sie ins
/// App-Paket, in die iOS-App kommen sie über `project.yml`; beide Lizenzen
/// verlangen, den Text mitzuliefern, nicht nur einen Verweis darauf.
private struct LizenztextView: View {
    let dismiss: () -> Void
    var pfad = "LICENSE"

    private var text: String {
        guard let url = Programmbuendel.eigenes.resourceURL?.appendingPathComponent(pfad),
              let inhalt = try? String(contentsOf: url, encoding: .utf8) else {
            return lok("Die Lizenzdatei liegt nicht im App-Paket. Am Mac passiert das, wenn die App nicht über ./build.sh gebaut wurde.")
        }
        return inhalt
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            Divider()
            HStack {
                Spacer()
                Button("Fertig", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        #if canImport(AppKit)
        .frame(width: 560, height: 480)
        #endif
    }
}
