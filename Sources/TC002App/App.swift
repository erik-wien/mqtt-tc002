import AppKit
import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

@main
struct TC002App: App {
    /// Die mitgelieferten Schriften muessen angemeldet sein, bevor irgendeine
    /// Ansicht ihre Schriftliste aufbaut — die wird einmal berechnet und bleibt
    /// dann stehen. In .onAppear waere es zu spaet gewesen.
    ///
    /// Ebenfalls hier: die mitgelieferten Icons wandern beim allerersten Start
    /// in den Schreibordner (`Iconsammlung.grundschatzEinmalUebernehmen`) —
    /// auch das, bevor eine Ansicht die Iconliste zum ersten Mal liest.
    init() {
        Schriften.registrieren()
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
            .grundschatzEinmalUebernehmen()
        Iconsammlung.grundschatz16().grundschatzEinmalUebernehmen(schluessel: Iconsammlung.merker16)
    }

    @State private var zustand = AppZustand()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup("Pixel Clock Messenger") {
            hauptfenster
        }
        .defaultSize(width: 1360, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Über Pixel Clock Messenger") { openWindow(id: Nebenfenster.ueber.id) }
            }
            CommandGroup(replacing: .help) {
                Button("Pixel Clock Messenger-Hilfe") { openWindow(id: Nebenfenster.hilfe.id) }
                    .keyboardShortcut("?", modifiers: .command)
                Button("Gerätereferenz") { openWindow(id: Nebenfenster.geraetereferenz.id) }
                Button("Schriftprobe") { openWindow(id: Nebenfenster.schriftprobe.id) }
            }
            // Es gibt ein Hauptfenster: ein zweites auf demselben Zustand
            // zeigte dieselben Regler doppelt und stritte um den Entwurf.
            CommandGroup(replacing: .newItem) {}
            Bearbeitenbefehle()
            // Blendet den Inspektor des Fensters ein und aus (⌥⌘I) —
            // dieselbe Handlung wie der Knopf in der Werkzeugleiste.
            InspectorCommands()
            // Beide Ordner liegen normalerweise unsichtbar in der Library und
            // werden von Iconordner.eigene bzw. Bilderordner.eigene bei Bedarf
            // selbst angelegt — der Finder greift hier also nie ins Leere.
            CommandGroup(after: .newItem) {
                Divider()
                Button("Eigene Icons im Finder zeigen") {
                    NSWorkspace.shared.open(Iconordner.eigene)
                }
                Button("Eigene Bilder im Finder zeigen") {
                    NSWorkspace.shared.open(Bilderordner.eigene)
                }
            }
        }

        // ⌘, öffnet dieses Fenster — so findet man Einstellungen am Mac. Der
        // Eintrag „Einstellungen“ in der Seitenleiste bleibt: Er ist der
        // Startbereich einer noch nicht eingerichteten App, und der iPad
        // teilt sich die Seitenleiste. Beide zeigen denselben Zustand.
        Settings {
            VerbindungView(zustand: zustand, fensterOeffnen: { openWindow(id: $0) })
                .frame(minWidth: 520, idealWidth: 600, minHeight: 480, idealHeight: 620)
        }

        // Die vier Nebenfenster. Titel und Kennung kommen aus `Nebenfenster`,
        // damit sie nicht von dem abweichen, was das iPad anbietet — dort gibt
        // es `Window` nicht, und `openWindow(id:)` uebersetzt, tut aber nichts.
        Window(Nebenfenster.ueber.titel, id: Nebenfenster.ueber.id) {
            Nebenfenster.ueber.inhalt
        }
        .windowResizability(.contentSize)

        Window(Nebenfenster.hilfe.titel, id: Nebenfenster.hilfe.id) {
            Nebenfenster.hilfe.inhalt
        }
        .windowResizability(.contentSize)

        Window(Nebenfenster.geraetereferenz.titel, id: Nebenfenster.geraetereferenz.id) {
            Nebenfenster.geraetereferenz.inhalt
        }
        .windowResizability(.contentSize)

        Window(Nebenfenster.schriftprobe.titel, id: Nebenfenster.schriftprobe.id) {
            Nebenfenster.schriftprobe.inhalt
        }
        .windowResizability(.contentSize)

        // Nicht `.contentSize`: Die virtuelle Uhr zeigt etwas Laufendes,
        // kein Dokument: Wer sie neben dem Sendebildschirm stehen hat, will
        // sie zurechtziehen koennen.
        Window(Nebenfenster.virtuelleUhr.titel, id: Nebenfenster.virtuelleUhr.id) {
            Nebenfenster.virtuelleUhr.inhalt
        }
    }

    /// Die Oberflaeche selbst liegt in `TC002Ansichten` — das iPad zeigt
    /// dieselbe. Hier haengt nur an, was es dort nicht gibt.
    private var hauptfenster: some View {
        SchreibtischView(zustand: zustand, fensterOeffnen: { openWindow(id: $0) })
            // ⌘Q verlaesst das Fokusfeld nicht — ohne dieses Netz ginge ein eben
            // erst eingetipptes Kennwort verloren, das noch nicht im
            // Schluesselbund steht.
            //
            // `scenePhase` statt `willTerminate`: Auf dem iPad gibt es dazu keine
            // gleichwertige Benachrichtigung. Sie feuert dafuer oefter — das ist
            // hier folgenlos, weil `kennwortSichern()` bei unveraendertem Wert
            // nichts tut.
            //
            // Und weil beim harten Abschuss gar nichts feuert, haengt das Kennwort
            // nicht allein an dieser Zeile: `VerbindungView` sichert es schon beim
            // Verlassen des Feldes, bei der Eingabetaste und beim Ansichtswechsel.
            // Enger geht es nicht — jeder Tastendruck wuerde den Schluesselbund-
            // Eintrag loeschen und neu anlegen (siehe `AppZustand.kennwort`).
            .onChange(of: phase) { _, neu in
                if neu != .active { zustand.kennwortSichern() }
            }
            .onAppear {
                // Nur am Mac: Unter iOS braeuchte ein Bonjour-Browser
                // zusaetzlich `NSBonjourServices` in der Info.plist, sonst
                // laeuft er an, findet nie etwas und bricht still ab (S9).
                Netzfreigabe.anfragen()
                // Erst hier, nicht im Konstruktor: ein AppZustand allein soll keine
                // Verbindung aufbauen — sonst horchte auch jeder Test mit.
                zustand.horchenStarten()
                // Dieselbe Ueberlegung wie bei `horchenStarten`: Ein
                // `AppZustand` allein soll keinen Port aufmachen, sonst
                // laege in jedem Test ein Dienst auf 8752. Der Dienst kommt
                // deshalb hier hoch — und nur, wenn er beim Beenden lief.
                Virtuelleuhrbetrieb.gemeinsam.beimStart()
            }
    }
}

/// Rückgängig, Wiederherstellen, Sichern und Senden in der Menüleiste.
///
/// Die Editoraktionen kommen über `FocusedValue` aus dem Fenster
/// (`EditorBereichView`). Rückgängig und Wiederherstellen ersetzen die
/// Systemeinträge und müssen deshalb selbst an ein Textfeld weiterreichen:
/// Wer gerade in einem Feld tippt, meint dessen Verlauf, nicht den der
/// Leinwand. Die Einträge sind nicht ausgegraut, denn ob ein Feld bearbeitet
/// wird, ändert sich, ohne dass die Menüleiste neu aufgebaut wird.
private struct Bearbeitenbefehle: Commands {
    @FocusedValue(\.editorAktionen) private var editor
    @FocusedValue(\.sendeAktion) private var sende

    private var textWirdBearbeitet: Bool { NSApp.keyWindow?.firstResponder is NSTextView }

    private func anSystem(_ selektor: String) {
        NSApp.sendAction(Selector((selektor)), to: nil, from: nil)
    }

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Rückgängig") {
                if let editor, !textWirdBearbeitet { editor.zurueck() } else { anSystem("undo:") }
            }
            .keyboardShortcut("z", modifiers: .command)
            Button("Wiederherstellen") {
                if let editor, !textWirdBearbeitet { editor.vor() } else { anSystem("redo:") }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .saveItem) {
            Button("Sichern") { editor?.sichern?() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(editor?.sichern == nil)
        }
        CommandGroup(before: .importExport) {
            Button("Senden") { sende?.senden?() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(sende?.senden == nil)
        }
    }
}
