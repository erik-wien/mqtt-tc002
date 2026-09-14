import SwiftUI
import TC002Core

/// Die Bedienungshilfe der Mac-Fassung. Eigenes Fenster, Abschnitte links,
/// Text rechts. Die Darstellung (`HilfeabschnittView`) und die Absätze, die
/// auf beiden Geräten gelten (`HilfeInhalt`), liegen in `TC002Ansichten` —
/// hier steht nur, was diese Oberfläche auszeichnet: Fenster, Seitenleiste,
/// Menüs, Inspektor, Finder und den Editor.
///
/// Was das Gerät kann, steht in der Gerätereferenz (Hilfe -> Gerätereferenz,
/// aus docs/tc002-protokoll.md, siehe GeraeteReferenzView.swift); hier steht
/// nur, was man in der App klickt.
public struct HilfeView: View {
    @State private var abschnitt: Abschnitt? = .ueberblick

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(Abschnitt.allCases, selection: $abschnitt) { a in
                Text(lok(a.rawValue)).tag(a)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 260)
        } detail: {
            let a = abschnitt ?? .ueberblick
            ScrollView {
                HilfeabschnittView(Hilfeabschnitt(a.rawValue, a.bausteine))
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // Nur am Mac — siehe GeraeteReferenzView: 760 Punkte hat kein iPad
        // hochkant ausser dem 13-Zoll-Geraet.
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 540)
        #endif
    }
}

private enum Abschnitt: String, CaseIterable, Identifiable {
    case ueberblick = "Was das Programm tut"
    case verbindung = "Einstellungen"
    case senden = "Senden"
    case editor = "Editor"
    case anzeigen = "Verlauf"
    case fehlersuche = "Wenn nichts erscheint"

    var id: String { rawValue }

    var bausteine: [Hilfebaustein] {
        switch self {
        case .ueberblick:
            return HilfeInhalt.wasEsTut
                + [
                    .absatz("Welcher Weg für eine Uhr gilt, steht unten bei „Einstellungen“ unter „Betriebsart“. Unabhängig davon spricht die App eine Uhr für ein paar Abfragen und Einstellungen immer selbst per HTTP an."),
                    .ueberschrift("Bereiche"),
                    .tabelle([
                        ("Senden", "Text und Icon verschicken"),
                        ("Editor", "Icons und ganze Anzeigen malen"),
                        ("Verlauf", "bereits verschickte Inhalte und das Protokoll"),
                        ("Einstellungen", "Uhren und Broker"),
                    ]),
                    .absatz("Was das Gerät selbst kann und wie das Protokoll dahinter aussieht, steht nicht hier, sondern unter „Hilfe → Gerätereferenz“. Diese Hilfe beschreibt nur, was man in der App klickt."),
                ]
        case .verbindung:
            return HilfeInhalt.startOhneEinrichtung
                + [
                    .ueberschrift("Uhr hinzufügen"),
                    .absatz("Unter „Einstellungen“ trägt man zuerst die Adresse einer Uhr ein (das Feld unter der Liste, in dem eine Beispieladresse steht, dann „Hinzufügen“ oder die Eingabetaste im Feld) oder passt eine vorhandene an. Der Punkt links in der Zeile wählt die **angesehene** Uhr: Vorschau, Geräterahmen, die fünf Blöcke und der Zeit-Reiter beziehen sich auf sie. Das ist nicht dasselbe wie das Sendeziel — das steht unter „Senden“ oben rechts, sobald mehr als eine Uhr eingetragen ist. Solange dort nichts eigenes gewählt ist, geht das Senden ebenfalls an die angesehene Uhr; bei nur einer Uhr fallen beide ohnehin zusammen."),
                    .absatz("Beim allerersten Start fragt macOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und die allererste „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt — einfach erlauben und erneut abfragen. Zurücknehmen lässt sich die Freigabe später unter Systemeinstellungen → Datenschutz & Sicherheit → Lokales Netzwerk."),
                ]
                + HilfeInhalt.uhrAbfragen
                + HilfeInhalt.betriebsart
                + HilfeInhalt.geraeteart
                + [
                    .absatz("Am Mac und auf dem iPad steht die Wahl als Zweierschalter in der Zeile der Uhr, zwischen Adresse und Präfix."),
                    .absatz("Ändert man die Adresse einer eingetragenen Uhr, verwirft die App Präfix, MAC und Verbindungsstand und zeigt in der Zeile wieder „—“: die neue Adresse gehört womöglich zu einer anderen Uhr, und das alte Präfix wäre dann das falsche Thema. Nach einer Adressänderung also erneut „Abfragen“."),
                    .ueberschrift("Entfernen"),
                    .absatz("„Entfernen“ am rechten Rand der Zeile löscht die Uhr aus der Liste, mitsamt dem, was die App sich für sie gemerkt hat. Auf der Uhr selbst ändert das nichts — eine dort stehende Anzeige bleibt stehen, also besser vorher unter „Verlauf“ löschen."),
                    .absatz("„Seitenwechsel“ und „Scrolltempo“ standen bis September 2026 hier; sie stehen jetzt im Zeit-Reiter des Inspektors, unter „Senden“ und im Editor — bei der „Dauer“, mit der sie zusammengehören."),
                    .ueberschrift("Broker"),
                    .absatz("Darunter steht der Broker: Adresse, Port, Benutzer und Kennwort."),
                ]
                + HilfeInhalt.brokerNurFuerMqtt
                + HilfeInhalt.brokerFelderLeer
                + HilfeInhalt.brokerKennwort
                + [
                    .absatz("Gesichert wird es, sobald man das Feld verlässt, die Eingabetaste drückt, den Bereich wechselt oder die App beendet — nicht bei jedem Tastendruck."),
                ]
                + HilfeInhalt.brokerPruefen
                + HilfeInhalt.wolkenabgleich
        case .senden:
            return [
                    .ueberschrift("Meldung und Platz"),
                ]
                + HilfeInhalt.fuenfPlaetze
                + HilfeInhalt.blockwissenAnfang
                + [
                    .absatz("Für Gemaltes gilt das nicht: Ein gemaltes Bild hat keine Regler, es wird nicht gemerkt, und eine Sendung aus dem Bereich „Editor“ wirft obendrein weg, was zu diesem Platz gemerkt war."),
                ]
                + HilfeInhalt.blockwissenSchluss
                + [
                    .ueberschrift("Weg: als Pixel oder als Text"),
                    .absatz("Ganz oben im Inspektor rechts steht unter „Senden als“ die Wahl des Wegs, mit zwei Einträgen: „als Pixel“ (Vorgabe) und „als Text“."),
                ]
                + HilfeInhalt.wegeRegel
                + [
                    .absatz("Läuft der Text beim Weg „als Pixel“, wird im Inspektor der Abschnitt „Laufschrift“ benutzbar: „Tempo“ — langsam, mittel oder schnell. Sonst steht er gesperrt da. Unter der Vorschau steht, wie viele Einzelbilder das ergibt und wie groß die Nutzlast wird."),
                    .absatz("Die Größe ist der Grund für die Angabe: Ein langer Text ergibt ein großes GIF, und wo die Grenze der Uhr liegt, weiß niemand (Gerätereferenz, §4.2a führt das als offene Frage). Wird es auffällig groß, sagt ein zusätzlicher Hinweis das."),
                    .absatz("Beim Weg „als Text“ rastert die App dagegen nichts — sie schickt den Text als eigenen Textblock, und die Uhr setzt ihn mit ihrer eingebauten Schrift (Gerätereferenz, §4.3). Dafür kann sie etwas, das „als Pixel“ nicht kann: Passt der Text nicht aufs Display, läuft er von selbst durch, ohne dass die App dafür ein GIF bauen muss — wie schnell, stellt „Scrolltempo“ unter „Einstellungen“ bei der aktiven Uhr ein (Gerätereferenz, §5.4). Eine Breitenwarnung gibt es hier deshalb nicht: Laufen ist auf diesem Weg der Normalfall, kein Fehler."),
                    .ueberschrift("Seitenwechsel und blockierende Anzeigen"),
                    .absatz("Damit das Blättern überhaupt etwas bringt, muss der Seitenwechsel der Uhr über null stehen — sonst bleibt der erste belegte Platz einfach stehen, und die anderen sieht man nie. Diese Einstellung findet sich unter „Einstellungen“ bei der aktiven Uhr."),
                ]
                + HilfeInhalt.blockierendeAnzeige
                + [
                    .ueberschrift("Löschen und Dauer"),
                ]
                + HilfeInhalt.papierkorb
                + [
                    .absatz("Dasselbe tut unter „Verlauf“ der Knopf „Löschen“, nur dort, wo man den Platz gerade in der Hand hat. Im Bereich „Editor“ sitzt er ebenso in der Sendezeile neben den fünf Blöcken. Ihn und „Alles löschen“ im Inspektor nicht verwechseln: „Alles löschen“ leert die Leinwand, der Papierkorb löscht die Anzeige auf der Uhr."),
                ]
                + HilfeInhalt.dauer
                + HilfeInhalt.zeichen
                + [
                    .absatz("Enthält der Text etwas anderes, sagt die App das vor dem Senden: welche Zeichen betroffen sind, und dass „als Pixel“ sie kann. Ohne diese Warnung würde die Uhr die Zeichen wortlos weglassen."),
                    .ueberschrift("Formatierung"),
                    .absatz("Alles Formatierende sitzt rechts im Inspektor, in fünf Abschnitten: „Senden als“ (der Weg), „Laufschrift“ (das Tempo), „Icon“, „Schrift“ (Schriftart, Größe und in der Zeile „Stil“ Fett, Großbuchstaben und die Farbe) und „Lage“ (Rand, Abstand, waagrechte und senkrechte Ausrichtung). Der Knopf rechts in der Werkzeugleiste blendet den Inspektor ein und aus; welche Richtung ein Symbolknopf setzt, sagt sein Einblendtext beim Verweilen mit der Maus."),
                    .absatz("Für den Weg „als Pixel“ gilt der ganze Inspektor, auch für den laufenden Text: Er wird in derselben Phase gerastert wie der stehende, damit dieselbe Schrift nicht einmal dünner und einmal dicker aussieht; die waagrechte Ausrichtung wirkt sich beim laufenden Text naturgemäß nicht aus, die senkrechte schon."),
                ]
                + HilfeInhalt.schriftart
                + [
                    .absatz("Eine früher gewählte Schrift, die nicht mehr in dieser Auswahl steht, bleibt gesetzt und wählbar, abgesetzt unten in der Liste, bis man selbst etwas anderes wählt."),
                ]
                + HilfeInhalt.groesse
                + HilfeInhalt.microFuenf
                + HilfeInhalt.fettUndGross
                + HilfeInhalt.randUndAbstand
                + HilfeInhalt.breiteUndAusrichtung
                + [
                    .ueberschrift("Icon wählen"),
                    .absatz("Im Abschnitt „Icon“ des Inspektors steht ein Knopf, der ohne Wahl „Icon wählen…“ heißt und mit Wahl Vorschaubild und Namen des Icons zeigt — in beiden Fällen ein Druck, der ein Blatt mit Suchfeld und Raster öffnet, dazu ein Eintrag „ohne“, um die Wahl im Blatt loszuwerden, und „Schließen“ zum Beenden. Ist ein Icon gewählt, steht daneben ein kleiner Knopf zum Entfernen, ohne das Blatt erst öffnen zu müssen."),
                    .absatz("Im Raster stehen beide Größen nebeneinander, gleich groß gezeigt: Ein 16×16 ist nicht das doppelt so große Bild, sondern das feinere. Welche der beiden es ist, merkt man erst an der Anzeige — ein 8×8 belegt zehn Spalten und schwimmt senkrecht mittig, ein 16×16 belegt achtzehn und füllt die volle Höhe. Für den Text bleiben entsprechend 42 oder 34 Spalten, und daran hängt auch, ob er steht oder läuft."),
                ]
                + HilfeInhalt.iconImLauf
                + [
                    .ueberschrift("Sendeziel"),
                    .absatz("Oben rechts über der Vorschau steht ein Knopf, der das aktuelle Sendeziel nennt — etwa „an: Küche“, „an alle Uhren (3)“ oder „an 2 Uhren“. Ein Druck öffnet ein Blatt mit einer Zeile je eingerichteter Uhr: Name, darunter das Präfix oder „HTTP“, bei MQTT-Uhren dazu derselbe Verbindungsstand wie unter „Einstellungen“, und ein Haken zum An- und Abwählen; „Alle“ und „Keine“ wählen mit einem Klick, „Schließen“ beendet die Auswahl."),
                    .absatz("Eine Uhr, die nichts empfangen kann, ist im Blatt als solche gekennzeichnet, und der Hinweis nennt, woran es liegt: einer MQTT-Uhr fehlt das Präfix — dann erst unter „Einstellungen“ „Abfragen“ —, einer HTTP-Uhr die Adresse. Beim Senden wird sie stillschweigend übersprungen, solange das so bleibt. Ist nichts angehakt, geht die Sendung an die gerade aktive Uhr."),
                    .absatz("Dieser Knopf erscheint erst ab zwei eingerichteten Uhren; bei nur einer geht jede Sendung ohne weitere Wahl automatisch an sie. Ist keine Uhr fertig eingerichtet, bleibt der Sendeknopf gesperrt und daneben steht der Hinweis, zuerst unter „Einstellungen“ eine Uhr einzutragen und abzufragen."),
                    .ueberschrift("Senden auslösen"),
                    .absatz("Die Eingabetaste löst „Senden“ aus, solange der Knopf nicht gesperrt ist. Geht dabei etwas schief — die Uhr nicht erreichbar, die Uhr weist die Anzeige ab, falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint ein Hinweisfenster mit dem Grund; bei mehreren Zieluhren eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert."),
                    .absatz("Was es heißt, wenn das Fenster ausbleibt, hängt an der Betriebsart: Bei einer HTTP-Uhr hat sie die Anzeige angenommen und sagt es auch. Bei einer MQTT-Uhr heißt es nur, dass die Nachricht beim Broker angekommen ist — was damit noch nicht gesagt ist, steht unter „Wenn nichts erscheint“."),
                ]
        case .editor:
            return [
                    .ueberschrift("Eine Tätigkeit, drei Größen"),
                    .absatz("Der Editor malt Pixel. Was dabei herauskommt, entscheidet allein die Größe der Leinwand: Ein 8×8 ist das kanonische LaMetric-Icon mit Nummer, ein 16×16 ein Icon ohne, und ein 16×52 ist die ganze Anzeige — nur sie lässt sich von hier aus senden. Bis zum 13.09.2026 waren das zwei Bereiche, „Bilder“ und „Icons“; es war aber immer dieselbe Tätigkeit."),
                    .absatz("Der Aufbau ist dreispaltig: Seitenleiste, Leinwand, Inspektor. Am Kopf des Inspektors steht eine Segmentwahl — „Malen“, „Animation“, „Bestand“ —, die umschaltet, was er zeigt. In der Werkzeugleiste darüber liegen nur noch „Rückgängig“, „Wiederherstellen“ und der Knopf, der den Inspektor ein- und ausblendet; ist er ausgeblendet, ist auch die Segmentwahl weg."),
                    .absatz("Die Leinwand nimmt den Platz, den ihre Spalte hergibt, und macht sie nie breiter, als sie ist: Bei 8×8 und 16×16 entscheidet die Höhe, bei 16×52 die Breite — dort bleiben die Kästchen zwangsläufig kleiner. Wird es so schmal, dass ein Kästchen unter sechs Punkte fiele, rollt die Leinwand waagrecht, statt über ihren Bereich hinauszulaufen. Das zuletzt Gemalte bleibt über einen Neustart der App hinweg erhalten."),
                    .ueberschrift("Malen"),
                    .absatz("Gemalt wird mit gedrückter Maustaste oder mit dem Finger. Im Inspektor stellt „Farbe“ den Systemfarbwähler, „Stift“ schaltet zwischen Malen und Radieren um, und „Alles löschen“ leert das gerade bearbeitete Einzelbild — nicht die anderen."),
                    .absatz("„Größe“ darüber wechselt zwischen 8×8, 16×16 und 16×52. Umgerechnet wird zwischen ihnen **nichts**, in keine Richtung: Ein Wechsel beginnt eine leere Leinwand und fragt vorher nach, wenn noch etwas Ungesichertes darauf steht. „Rückgängig“ holt sie samt ihrer Größe zurück."),
                    .absatz("Das Verschiebekreuz schiebt die ganze Grafik um ein Pixel — alle Einzelbilder zusammen, damit eine Animation nicht gegeneinander verrutscht. Was am Rand hinausgeschoben wird, kommt gegenüber wieder herein, statt abgeschnitten zu werden; der Gegenpfeil nimmt damit jeden Schritt genau zurück."),
                    .absatz("„Icon einfügen“ ist der eine Weg, auf dem zwischen den Größen gerechnet wird — ein Befehl, den man aufruft, kein stiller Nebeneffekt. Bei 16×16 stehen die 8×8-Icons zur Wahl und werden beim Einsetzen **verdoppelt**: Jedes Pixel wird ein Viererblock, das Ergebnis füllt die Fläche. Bei 16×52 stehen beide Icongrößen zur Wahl und behalten ihre Größe — ein 8×8 sitzt senkrecht mittig, ein 16×16 über die volle Höhe, an derselben Stelle, an der sie auch unter „Senden“ lägen."),
                    .absatz("Den umgekehrten Weg gibt es nicht: Aus einem 16×52 wird kein Icon und aus einem 16×16 kein 8×8. Verkleinern zerstört. Nach dem Einsetzen lässt sich frei weitermalen; durchsichtige Stellen im Icon lassen die Fläche dort unverändert, und das Einsetzen ist ein Schritt für „Rückgängig“."),
                    .ueberschrift("Rückgängig"),
                    .absatz("Ein Strich ist ein Schritt, nicht ein Pixel: Wer mit dem Finger über zwanzig Kästchen fährt, macht ihn mit einem Druck wieder rückgängig. Je ein Schritt sind außerdem „Alles löschen“, jede Bewegung des Verschiebekreuzes, ein Einzelbild anhängen, verdoppeln, entfernen oder umsortieren, und ein Größenwechsel. Farbwahl, Werkzeug, Bildwahl, Verzögerung, Name und Nummer ändern nichts an der Zeichnung und sind deshalb keine Schritte."),
                    .absatz("Fünfzig Schritte werden gemerkt, in beide Richtungen. Der Stapel überlebt den Programmlauf nicht und wird auch geleert, wenn man mit „Neu“ von vorn anfängt oder ein vorhandenes Bild öffnet — von einem anderen Blatt aus führt der alte Weg nirgendwohin."),
                    .ueberschrift("Animation"),
                    .absatz("Ein Bild kann aus mehreren Einzelbildern bestehen; das ergibt beim Sichern ein animiertes GIF, das in Schleife läuft. Der Streifen im Inspektor zeigt alle, das gerade bearbeitete hervorgehoben; ein Klick darauf schaltet die Leinwand um. „Bild anhängen“ hängt ein leeres an und schaltet die Leinwand gleich darauf um."),
                    .absatz("„Verdoppeln“ und „Entfernen“ stehen unter dem gewählten Einzelbild — an dem Bild also, auf das sie wirken. Dasselbe bietet das Kontextmenü jedes Bildes, dazu „Nach vorn“ und „Nach hinten“ zum Umsortieren. „Entfernen“ ist gesperrt, wenn nur noch ein Bild übrig ist."),
                    .absatz("„Verzögerung“ gilt für jedes Einzelbild gleich, in Sekunden. Das Wiedergabesymbol rechts neben dem Sekundenwert läuft den Streifen probeweise in Schleife durch, ohne dass vorher gesichert werden muss; während er läuft, zeigt es ein Stoppzeichen, und bei nur einem Einzelbild ist es gesperrt. Die Uhr spielt animierte GIFs ab, nicht nur deren erstes Einzelbild — am Gerät bestätigt (Hilfe → Gerätereferenz, §4.2)."),
                    .ueberschrift("Sichern"),
                    .absatz("„Ungesichert“ heißt hier: Was auf der Leinwand steht, weicht von dem ab, was im Bestand liegt — nicht, dass es beim Beenden verloren ginge; das zuletzt Gemalte übersteht einen Neustart ohnehin. Eine nie gesicherte Zeichnung ist deshalb ungesichert, ein eben geöffnetes Bild nicht, und wer seinen Strich mit „Rückgängig“ zurücknimmt, steht wieder auf dem gesicherten Stand. Danach fragt alles, was die Leinwand verwirft: „Neu“, ein Größenwechsel, ein geöffnetes und ein geladenes Bild. Name und Nummer zählen dabei nicht mit — sie sind in zwei Anschlägen wieder eingetippt."),
                    .absatz("„Name“ und „Sichern“ legen alle Einzelbilder auf einmal ab. Bei 8×8 kommt „Nummer“ dazu: Sie ist der Dateiname und zugleich die LaMetric-Nummer und muss eindeutig sein. Bei 16×52 gibt es ebenfalls eine — die Werknummer, die Ulanzi für seine „Pixel Art 16×52“ vergibt —, aber sie ist **wahlfrei** und benennt die Datei nicht: Dort heißt die Datei weiter nach dem Namen, und derselbe Name ersetzt das Vorhandene. Bei 16×16 gibt es keine Nummer; diese Größe ist nicht kanonisch, sie stammt von uns. Nachladen lässt sich von Ulanzi nichts — eine Adresse, die eine fertige 16×52-Datei liefert, gibt es dort nicht."),
                    .absatz("„Neu“ daneben beginnt von vorn: Leinwand, Einzelbilder, Verzögerung, Name und Nummer. Steht noch etwas Ungesichertes da, fragt eine Rückfrage vorher nach."),
                    .absatz("Die drei Bestände liegen weiterhin getrennt — 8×8 unter `~/Library/Application Support/MQTT-TC002/Icons`, 16×16 daneben unter `Icons16`, die Anzeigen unter `Bilder`. Gleiche Namen in zwei Beständen kommen sich deshalb nicht in die Quere. Über „Ablage“ öffnet der Finder den Icon- und den Bilderordner."),
                    .ueberschrift("Hinzufügen"),
                    .absatz("Bei 8×8 lässt sich eine Nummer von developer.lametric.com eintragen und mit „Nachladen“ holen — die Eingabetaste im Feld tut dasselbe. Das geholte Icon kommt danach auf die Leinwand, mit derselben Rückfrage wie eine geöffnete Datei. Eine unbekannte Nummer ergibt eine verständliche Meldung und macht sonst nichts kaputt. Der Verweis „LaMetric Icon Gallery“ darunter öffnet die Übersicht im Browser. „Grundschatz wiederherstellen“ ergänzt nur, was im eigenen Ordner fehlt, und lässt Vorhandenes unangetastet; die Meldung danach nennt die Anzahl."),
                    .absatz("„Öffnen…“ nimmt eine GIF-, PNG- oder JPEG-Datei von der Platte auf — und zwar in **ihrer eigenen** Größe: ein 8×8 als 8×8, ein 16×16 als 16×16, ein 16×52 als Anzeige. Der Editor stellt sich auf die Datei ein, nicht umgekehrt; die Meldung nennt deshalb den Bestand, in dem sie gelandet ist. Ein animiertes GIF behält dabei alle seine Einzelbilder."),
                    .absatz("Jede andere Größe wird **abgelehnt**, mit Begründung („Das Bild ist 32×32. Aufgenommen werden 8×8, 16×16 und 16×52.“). Bis zum 13.09.2026 wurde stattdessen stillschweigend auf die gerade eingestellte Größe heruntergerechnet — ein 16×16 landete als 8×8, wenn der Editor auf 8×8 stand. Verkleinern zerstört, und wer es nicht gewollt hat, sah es nicht."),
                    .absatz("Ein Blatt fragt danach nach dem Namen und — nur bei 8×8 — nach der LaMetric-Nummer; sein Kopf nennt die Größe, in der aufgenommen wird. Beginnt der Dateiname mit Nummer, Unterstrich und Titel, werden beide daraus vorbelegt: aus `2981_Severe TStorm.gif` also die Nummer `2981` und der Titel `Severe TStorm`. Sonst steht der ganze Dateiname im Namen und die Nummer bleibt leer."),
                    .absatz("Liegt unter dieser Nummer — oder, wo es keine gibt, unter diesem Namen — schon etwas, steht das im Blatt und nennt den Namen; der Knopf heißt dann „Ersetzen“ statt „Öffnen“. Abgewiesen wird es nicht: Dasselbe Icon in einer besseren Fassung noch einmal zu holen ist der häufigste Fall, und ersetzt wird beim Sichern ohnehin. Falsch war nicht das Ersetzen, sondern dass man es erst hinterher merkte."),
                    .absatz("Aufgenommenes kommt **auch auf die Leinwand** — in seiner eigenen Größe, die Leinwand stellt sich darauf ein. Steht dort Ungesichertes, fragt eine Rückfrage vorher: „Ersetzen“ legt das Geladene auf die Leinwand, „Nur in den Bestand“ lässt sie stehen, wie sie ist, „Abbrechen“ ändert gar nichts. In den Bestand geht es in jedem Fall; zur Frage steht allein die Leinwand. Bis zum 14.09.2026 wanderte eine eingelesene Datei nur in den Bestand und war nirgends zu sehen."),
                    .ueberschrift("Vorhandene"),
                    .absatz("Darunter stehen alle drei Bestände in einer Liste, jeder Eintrag mit seiner Größe als Merkmal und, wo es eine gibt, mit seiner Nummer. Das Suchfeld grenzt nach Name und Nummer ein. Ein Klick auf eine Zeile lädt sie mit allen Einzelbildern zurück auf die Leinwand — mit Rückfrage, wenn dort Ungesichertes steht. Das Papierkorb-Symbol in der Zeile löscht, mit Rückfrage, die den Namen nennt; dasselbe bietet „Löschen“ im Kontextmenü."),
                    .absatz("Das Stift-Symbol daneben benennt um — den Namen immer, und wo es eine Nummer gibt, auch sie; dasselbe bietet „Umbenennen…“ im Kontextmenü. Das Blatt ist dasselbe wie beim Aufnehmen und warnt ebenso **vorher**, wenn unter dem neuen Schlüssel schon etwas liegt; der Knopf heißt dann „Ersetzen“. Ohne Namen bleibt er gesperrt."),
                    .absatz("Umbenannt wird die Datei selbst: Bei 8×8 zieht sie mit der Nummer um, bei 16×16 und 16×52 mit dem Namen, und eine geänderte Werknummer lässt sie liegen, wo sie ist. Das Bild wird dabei nicht neu geschrieben, sondern verschoben — es bleibt Bit für Bit dasselbe. Liegt das umbenannte Stück gerade auf der Leinwand, ziehen Name und Nummer dort mit, sonst legte das nächste „Sichern“ es unter dem alten Namen ein zweites Mal an."),
                    .absatz("War das Gelöschte gerade geöffnet, bleibt das Bild auf der Leinwand stehen, nur Name und Nummer werden geleert — sonst legte ein erneutes „Sichern“ es unter demselben Namen wieder an."),
                    .ueberschrift("Zurückladen und Transparenz"),
                    .absatz("„Aus“ und „schwarz gemalt“ sind zweierlei, auch nach dem Sichern: Ein ausgeschaltetes Pixel wird im GIF durchsichtig abgelegt, ein schwarz gemaltes deckend schwarz. Auf der Uhr sieht beides gleich aus, weil ihr Grund schwarz ist — im Editor kommt ein wieder geöffnetes Bild aber so zurück, wie es gemalt war. Dass „aus“ durchsichtig bleibt, ist nebenbei die Bedingung dafür, dass die Laufschrift auf der Uhr sauber läuft (Gerätereferenz, §4.2a)."),
                    .ueberschrift("Senden"),
                    .absatz("Die Sendezeile unter der Leinwand gibt es nur bei 16×52 — ein Icon ist für sich keine Anzeige. Die fünf Slot-Blöcke stehen dort mit denselben drei Zuständen und demselben Stand der aktiven Uhr wie unter „Senden“; ein Antippen wählt hier aber nur den Platz: Regler, die sich wiederherstellen ließen, gibt es beim Malen nicht. Aus demselben Grund merkt sich die App ein gemaltes Bild nicht, und eine Sendung von hier wirft weg, was zu diesem Platz gemerkt war."),
                    .absatz("Der Papierkorb daneben löscht die Anzeige auf der Uhr — nicht die Leinwand. „Dauer (Sek.)“, die Zielauswahl und „Senden“ funktionieren wie unter „Senden“ beschrieben, samt Hinweisfenster bei Fehlern und gesperrtem Knopf, solange keine Uhr fertig eingerichtet ist."),
                    .absatz("Der Hinweis unter der Leinwand zeigt, wie viele Rechtecke die Uhr am Ende bekommt: waagrechte Läufe gleicher Farbe werden vor dem Senden zu einem Rechteck zusammengefasst. Ein einzelnes Bild geht so hinaus — klein und exakt. Mehrere gehen als ein animiertes GIF, denn Rechtecke kennen keine Zeit; was dabei an Nutzlast zusammenkommt, gilt wie bei der Laufschrift unter „Senden“ — ein langes Laufbild wird groß, und wo die Grenze der Uhr liegt, weiß niemand."),
                ]
        case .anzeigen:
            return HilfeInhalt.verlaufHerkunft
                + [
                    .absatz("Je Uhr getrennt: die Liste wechselt mit, wenn man unter „Einstellungen“ eine andere Uhr zur aktiven macht."),
                ]
                + HilfeInhalt.verlaufEntstehung
                + [
                    .ueberschrift("Anzeigen und Löschen"),
                    .absatz("„Zeigen“ schaltet auf den Namen um, „Löschen“ entfernt ihn mit leerer Nachricht von der aktiven Uhr."),
                ]
                + HilfeInhalt.verlaufLoeschen
                + HilfeInhalt.protokollListe
                + [
                    .absatz("Dazu jede Änderung des Seitenwechsels."),
                ]
                + HilfeInhalt.protokollLeeren
                + [
                    .ueberschrift("Seitenwechsel"),
                    .absatz("Die Einstellung „Seitenwechsel“ — wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert — findet sich nicht mehr hier, sondern unter „Einstellungen“ bei der jeweils aktiven Uhr, direkt neben der Liste der Uhren."),
                ]
        case .fehlersuche:
            return HilfeInhalt.fehlerStille
                + [
                    .absatz("Kam nach dem Senden kein Hinweisfenster, ist die Nachricht beim Broker gewesen — dann liegt die Ursache hinter ihm, und die folgenden Punkte helfen weiter."),
                ]
                + HilfeInhalt.fehlerWelche
                + HilfeInhalt.fehlerReihe
                + [
                    .ueberschrift("Weitere Symptome"),
                    .absatz("Blättert die Uhr nicht zur neuen Anzeige, obwohl mehrere angelegt sind: „Seitenwechsel“ unter „Einstellungen“ steht vermutlich auf „kein Wechsel“."),
                    .absatz("Fehlende Zeichen, insbesondere Umlaute, kann es im Editor nicht geben und bei „Senden“ nur auf dem Weg „als Text“ — dort warnt die App vorher, welche Zeichen betroffen sind. Beim Weg „als Pixel“ rastert die App jeden Text selbst, stehend wie laufend, und benutzt die umlautlose Schrift der Uhr überhaupt nicht."),
                ]
        }
    }
}
