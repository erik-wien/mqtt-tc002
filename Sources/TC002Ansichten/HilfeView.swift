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
    case editor = "Icons"
    case anzeigen = "Protokoll"
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
                        ("Icons", "Icons und ganze Anzeigen malen"),
                        ("Protokoll", "die technische Mitschrift — nur da, wenn eingeschaltet"),
                        ("Einstellungen", "fünf Themen: Uhren, Broker, Aufzeichnung, iCloud, Erweitert"),
                    ]),
                    .absatz("Was das Gerät selbst kann und wie das Protokoll dahinter aussieht, steht nicht hier, sondern unter „Hilfe → Gerätereferenz“ — dort steht je ein Dokument für beide Gattungen, die Wahl darüber sitzt über dem Inhaltsverzeichnis. Diese Hilfe beschreibt nur, was man in der App klickt."),
                ]
        case .verbindung:
            return HilfeInhalt.themen
                + HilfeInhalt.startOhneEinrichtung
                + HilfeInhalt.uhrHinzufuegen
                + [
                    .absatz("Welche Uhr man **ansieht**, wählt das Titelmenü in der Werkzeugleiste unter „Senden“ — dort steht ihr Name, und Vorschau, Geräterahmen und die fünf Blöcke beziehen sich auf sie. Das ist nicht dasselbe wie das Sendeziel: Das steht links oben in derselben Leiste, sobald mehr als eine Uhr eingetragen ist. Solange dort nichts eigenes gewählt ist, geht das Senden ebenfalls an die angesehene Uhr; bei nur einer Uhr fallen beide ohnehin zusammen."),
                    .absatz("Beim allerersten Start fragt macOS, ob die App auf Geräte im lokalen Netzwerk zugreifen darf. Ohne diese Freigabe erreicht sie weder Uhr noch Broker, und die allererste „Abfragen“ scheitert dann mit einer Meldung, die auf die falsche Ursache zeigt — einfach erlauben und erneut abfragen. Zurücknehmen lässt sich die Freigabe später unter Systemeinstellungen → Datenschutz & Sicherheit → Lokales Netzwerk."),
                ]
                + HilfeInhalt.uhrAbfragen
                + HilfeInhalt.betriebsart
                + HilfeInhalt.geraeteart
                + [
                    .absatz("Ändert man die Adresse einer eingetragenen Uhr, verwirft die App Präfix, MAC und Verbindungsstand; die Zeile der Uhr zeigt dann wieder „noch nicht abgefragt“: die neue Adresse gehört womöglich zu einer anderen Uhr, und das alte Präfix wäre dann das falsche Thema. Nach einer Adressänderung also erneut „Abfragen“."),
                ]
                + HilfeInhalt.uhrEntfernen
                + HilfeInhalt.aufDerUhr
                + [
                    .ueberschrift("Broker"),
                    .absatz("Der Broker ist ein eigenes Thema: Adresse, Port, Benutzer und Kennwort."),
                ]
                + HilfeInhalt.brokerNurFuerMqtt
                + HilfeInhalt.brokerFelderLeer
                + HilfeInhalt.brokerKennwort
                + HilfeInhalt.brokerSichern
                + HilfeInhalt.brokerPruefen
                + HilfeInhalt.virtuelleUhr
                + HilfeInhalt.wolkenabgleich
        case .senden:
            return [
                    .ueberschrift("Meldung und Platz"),
                ]
                + HilfeInhalt.fuenfPlaetze
                + HilfeInhalt.blockwissenAnfang
                + [
                    .absatz("Für Gemaltes gilt das nicht: Ein gemaltes Bild hat keine Regler, es wird nicht gemerkt, und eine Sendung aus dem Bereich „Icons“ wirft obendrein weg, was zu diesem Platz gemerkt war."),
                ]
                + HilfeInhalt.blockwissenSchluss
                + HilfeInhalt.verlaufHerkunft
                + HilfeInhalt.verlaufEntstehung
                + HilfeInhalt.verlaufLoeschen
                + [
                    .ueberschrift("Stehen oder laufen"),
                ]
                + HilfeInhalt.wegeRegel
                + [
                    .absatz("Läuft der Text, wird im Zeit-Reiter des Inspektors der Abschnitt „Laufschrift“ benutzbar: „Tempo“ — langsam, mittel oder schnell. Sonst steht er gesperrt da."),
                    .absatz("Wie viele Einzelbilder das ergibt und wie groß die Nutzlast wird, steht als Einblendtext am ⏎ im Eingabefeld — es ist die Antwort auf „was passiert, wenn ich drücke“, und dort drückt man. Unter der Vorschau steht davon nur, was ein Befund ist: Ein langer Text ergibt ein großes GIF, und wo die Grenze der Uhr liegt, weiß niemand (Gerätereferenz, §4.2a führt das als offene Frage) — wird die Nutzlast auffällig groß, sagt es eine Zeile dort von selbst."),
                    .ueberschrift("Seitenwechsel und blockierende Anzeigen"),
                    .absatz("Damit das Blättern überhaupt etwas bringt, muss der Seitenwechsel der Uhr über null stehen — sonst bleibt der erste belegte Platz einfach stehen, und die anderen sieht man nie. Diese Einstellung findet sich unter „Einstellungen“ → „Uhren“ auf der Seite der Uhr, unter „Auf der Uhr“."),
                ]
                + HilfeInhalt.blockierendeAnzeige
                + [
                    .ueberschrift("Löschen und Dauer"),
                ]
                + HilfeInhalt.blockLoeschen
                + [
                    .absatz("Dasselbe tut ein Wischen nach links in der Liste unter den Blöcken. Die Blockreihe im Bereich „Icons“ verhält sich genauso. Das ⊗ und „Alles löschen“ im Reiter „Malen“ nicht verwechseln: „Alles löschen“ leert die Leinwand, das ⊗ löscht die Anzeige auf der Uhr."),
                ]
                + HilfeInhalt.dauer
                + HilfeInhalt.zeichen
                + [
                    .ueberschrift("Formatierung"),
                    .absatz("Alles Formatierende sitzt rechts im Inspektor, im Reiter „Format“ und dort in drei Abschnitten: „Icon“, „Schrift“ (Schriftart, Größe und in der Zeile „Stil“ Fett, Großbuchstaben und die Farbe) und „Lage“ (Rand, Abstand, waagrechte und senkrechte Ausrichtung). Der zweite Reiter, „Zeit“, führt zusammen, wie lange etwas zu sehen ist: die Dauer dieser Meldung und das Tempo ihrer Laufschrift. Der Knopf rechts in der Werkzeugleiste blendet den Inspektor ein und aus; welche Richtung ein Symbolknopf setzt, sagt sein Einblendtext beim Verweilen mit der Maus."),
                    .absatz("Der ganze Inspektor gilt auch für den laufenden Text: Er wird in derselben Phase gerastert wie der stehende, damit dieselbe Schrift nicht einmal dünner und einmal dicker aussieht; die waagrechte Ausrichtung wirkt sich beim laufenden Text naturgemäß nicht aus, die senkrechte schon."),
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
                    .absatz("Im Abschnitt „Icon“ des Inspektors steht ein Knopf, der ohne Wahl „Icon wählen…“ heißt und mit Wahl Vorschaubild und Namen des Icons zeigt — in beiden Fällen ein Druck, der ein Blatt mit Suchfeld, Filterleiste und Raster öffnet — die Leiste grenzt nach Größe (8 × 8 oder 16 × 16) und auf bewegte Icons ein —, dazu ein Eintrag „ohne“, um die Wahl im Blatt loszuwerden, und „Schließen“ zum Beenden. Ist ein Icon gewählt, steht daneben ein kleiner Knopf zum Entfernen, ohne das Blatt erst öffnen zu müssen."),
                    .absatz("Im Raster stehen beide Größen nebeneinander, gleich groß gezeigt: Ein 16×16 ist nicht das doppelt so große Bild, sondern das feinere. Welche der beiden es ist, merkt man erst an der Anzeige — ein 8×8 belegt zehn Spalten und schwimmt senkrecht mittig, ein 16×16 belegt achtzehn und füllt die volle Höhe. Für den Text bleiben entsprechend 42 oder 34 Spalten, und daran hängt auch, ob er steht oder läuft."),
                ]
                + HilfeInhalt.iconImLauf
                + [
                    .ueberschrift("Sendeziel"),
                    .absatz("Zwei Entscheidungen, zwei Griffe: **welche Uhr man ansieht** steht mittig in der Werkzeugleiste als Menü mit ihrem Namen — daran hängen Vorschau, Geräterahmen und die fünf Blöcke —, und darunter sagt eine Punktreihe, wie viele Uhren es gibt und die wievielte das ist. Ein Klick auf einen Punkt wechselt; über der Vorschau blättert man zur nächsten, wie zwischen zwei Seiten."),
                    .absatz("**Wohin gesendet wird**, nennt der Knopf links oben in der Werkzeugleiste: „Empfänger“ mit der Zahl der gewählten Uhren. Ein Druck öffnet ein Blatt mit einer Zeile je eingerichteter Uhr: Name, darunter das Präfix oder „HTTP“, bei MQTT-Uhren dazu derselbe Verbindungsstand wie unter „Einstellungen“, und ein Haken zum An- und Abwählen; „Alle“ und „Nur die angesehene“ wählen mit einem Klick."),
                    .absatz("Das Ziel folgt dem Blick **nicht**: Wer die angesehene Uhr wechselt, sendet weiter dorthin, wo er es eingestellt hat. Das war am Telefon bis September 2026 anders — dort waren beide dasselbe —, und ist es seit der eigenen Zielwahl auch dort nicht mehr."),
                    .absatz("Eine Uhr, die nichts empfangen kann, ist im Blatt als solche gekennzeichnet, und der Hinweis nennt, woran es liegt: einer MQTT-Uhr fehlt das Präfix — dann erst unter „Einstellungen“ „Abfragen“ —, einer HTTP-Uhr die Adresse. Beim Senden wird sie stillschweigend übersprungen, solange das so bleibt. Ist nichts angehakt, geht die Sendung an die gerade aktive Uhr."),
                    .absatz("Dieser Knopf erscheint erst ab zwei eingerichteten Uhren; bei nur einer geht jede Sendung ohne weitere Wahl automatisch an sie. Ist keine Uhr fertig eingerichtet, bleibt der Sendeknopf gesperrt und daneben steht der Hinweis, zuerst unter „Einstellungen“ eine Uhr einzutragen und abzufragen."),
                    .ueberschrift("Senden auslösen"),
                    .abbildung(.sendezeile),
                    .absatz("Die Eingabetaste schickt. Am rechten Rand des Feldes steht dafür ein blauer runder Knopf mit Pfeil, den man ebenso anklicken kann; er erscheint, sobald etwas im Feld steht, und weicht während des Sendens einem Fortschrittsdreher. Links daneben leert ein ⊗ das Feld. Auf dem iPad heißt die Eingabetaste der Bildschirmtastatur „Senden“. Geht dabei etwas schief — die Uhr nicht erreichbar, die Uhr weist die Anzeige ab, falsches Broker-Kennwort, Broker nicht erreichbar, Zeitüberschreitung, unlesbare Icondatei —, erscheint ein Hinweisfenster mit dem Grund; bei mehreren Zieluhren eine Zeile je betroffener Uhr, die übrigen werden trotzdem beliefert."),
                    .absatz("Was es heißt, wenn das Fenster ausbleibt, hängt an der Betriebsart: Bei einer HTTP-Uhr hat sie die Anzeige angenommen und sagt es auch. Bei einer MQTT-Uhr heißt es nur, dass die Nachricht beim Broker angekommen ist — was damit noch nicht gesagt ist, steht unter „Wenn nichts erscheint“."),
                ]
        case .editor:
            return [
                    .ueberschrift("Eine Tätigkeit, drei Größen"),
                    .absatz("Der Bereich „Icons“ malt Pixel. Was dabei herauskommt, entscheidet allein die Größe der Leinwand: Ein 8×8 ist das kanonische LaMetric-Icon mit Nummer, ein 16×16 ein Icon ohne, und ein 52×16 ist die ganze Anzeige."),
                    .absatz("Er beginnt mit der **Übersicht**: alles, was im Bestand liegt, nach Größe gruppiert im Hauptfenster. Ein Suchfeld grenzt nach Name und Nummer ein, daneben blendet ein Schalter auf bewegte Stücke ein. Ein Druck auf ein Stück holt es auf die Leinwand; in der Werkzeugleiste steht dort nur das Plus, und dahinter alles, was Neues hereinholt."),
                    .absatz("Das Kontextmenü einer Kachel bietet „Öffnen“, „Duplizieren“, „Umbenennen…“ und „Löschen“. **Duplizieren** ist der Weg, ein mitgeliefertes oder von LaMetric geholtes Icon zu bearbeiten, ohne das Vorbild zu verlieren: Die Kopie bekommt den nächsten freien Namen und, wo es eine gibt, die nächste freie Nummer."),
                    .absatz("Auf der Leinwand ist der Aufbau dreispaltig: Seitenleiste, Leinwand, Inspektor. Über der Leinwand steht eine Zeile mit „Fertig“ links, dem Namen des Stücks in der Mitte und „Sichern“ rechts. Am Kopf des Inspektors schaltet eine Segmentwahl um, was er zeigt — „Malen“, „Animation“, „Bestand“; in der Werkzeugleiste darüber liegen „Rückgängig“, „Wiederherstellen“ und der Knopf für den Inspektor."),
                    .absatz("Die Leinwand nimmt den Platz, den ihre Spalte hergibt, und macht sie nie breiter, als sie ist: Bei 8×8 und 16×16 entscheidet die Höhe, bei 52×16 die Breite — dort bleiben die Kästchen zwangsläufig kleiner. Wird es so schmal, dass ein Kästchen unter sechs Punkte fiele, rollt die Leinwand waagrecht, statt über ihren Bereich hinauszulaufen. Das zuletzt Gemalte bleibt über einen Neustart der App hinweg erhalten."),
                    .ueberschrift("Malen"),
                    .absatz("Gemalt wird mit gedrückter Maustaste oder mit dem Finger. Im Inspektor stellt „Farbe“ den Systemfarbwähler und „Stift“ schaltet zwischen Malen und Radieren um. Ganz unten im Reiter „Malen“ steht „Alles löschen“; es leert das gerade bearbeitete Einzelbild — nicht die anderen — und „Rückgängig“ holt es zurück."),
                    .absatz("„Größe“ darüber wechselt zwischen 8×8, 16×16 und 52×16. Umgerechnet wird zwischen ihnen **nichts**, in keine Richtung: Ein Wechsel beginnt eine leere Leinwand und fragt vorher nach, wenn noch etwas Ungesichertes darauf steht. „Rückgängig“ holt sie samt ihrer Größe zurück."),
                    .absatz("Das Verschiebekreuz schiebt die Grafik um ein Pixel. Bei mehreren Einzelbildern steht darunter die Wahl, ob alle zusammen wandern oder nur das gerade bearbeitete — das eine richtet die ganze Animation aus, das andere versetzt ein Bild gegen die übrigen. Was am Rand hinausgeschoben wird, kommt gegenüber wieder herein, statt abgeschnitten zu werden; der Gegenpfeil nimmt damit jeden Schritt genau zurück."),
                    .absatz("„Icon einfügen“ ist der eine Weg, auf dem zwischen den Größen gerechnet wird — ein Befehl, den man aufruft, kein stiller Nebeneffekt. Bei 16×16 stehen die 8×8-Icons zur Wahl und werden beim Einsetzen **verdoppelt**: Jedes Pixel wird ein Viererblock, das Ergebnis füllt die Fläche. Bei 52×16 stehen beide Icongrößen zur Wahl und behalten ihre Größe — ein 8×8 sitzt senkrecht mittig, ein 16×16 über die volle Höhe, an derselben Stelle, an der sie auch unter „Senden“ lägen."),
                    .absatz("Den umgekehrten Weg gibt es nicht: Aus einem 52×16 wird kein Icon und aus einem 16×16 kein 8×8. Verkleinern zerstört. Nach dem Einsetzen lässt sich frei weitermalen; durchsichtige Stellen im Icon lassen die Fläche dort unverändert, und das Einsetzen ist ein Schritt für „Rückgängig“."),
                    .ueberschrift("Rückgängig"),
                    .absatz("Ein Strich ist ein Schritt, nicht ein Pixel: Wer mit dem Finger über zwanzig Kästchen fährt, macht ihn mit einem Druck wieder rückgängig. Je ein Schritt sind außerdem „Alles löschen“, jede Bewegung des Verschiebekreuzes, ein Einzelbild anhängen, verdoppeln, entfernen oder umsortieren, und ein Größenwechsel. Farbwahl, Werkzeug, Bildwahl, Verzögerung, Name und Nummer ändern nichts an der Zeichnung und sind deshalb keine Schritte."),
                    .absatz("Fünfzig Schritte werden gemerkt, in beide Richtungen. Der Stapel überlebt den Programmlauf nicht und wird auch geleert, wenn man mit „Neu“ von vorn anfängt oder ein vorhandenes Bild öffnet — von einem anderen Blatt aus führt der alte Weg nirgendwohin."),
                    .ueberschrift("Animation"),
                    .absatz("Ein Bild kann aus mehreren Einzelbildern bestehen; das ergibt beim Sichern ein animiertes GIF, das in Schleife läuft. Der Streifen unter der Leinwand zeigt alle, das gerade bearbeitete hervorgehoben; ein Klick darauf schaltet die Leinwand um. Er steht nur da, wenn es mehr als ein Einzelbild gibt. „Bild anhängen“ im Reiter „Animation“ hängt ein leeres an und schaltet die Leinwand gleich darauf um."),
                    .absatz("„Verdoppeln“ und „Entfernen“ stehen unter dem gewählten Einzelbild — an dem Bild also, auf das sie wirken. Dasselbe bietet das Kontextmenü jedes Bildes, dazu „Nach vorn“ und „Nach hinten“ zum Umsortieren. „Entfernen“ ist gesperrt, wenn nur noch ein Bild übrig ist."),
                    .absatz("„Verzögerung“ gilt für jedes Einzelbild gleich, in Sekunden. Abgespielt wird über das runde Zeichen — groß neben der Leinwand, bei einer 52 × 16-Anzeige knapp darunter, und klein neben „Bild anhängen“ im Reiter „Animation“. Auf dem Bild liegt es nie: Ein Zeichen im Raster verdeckt Pixel, die man malen will. Es läuft probeweise in Schleife, ohne dass vorher gesichert werden muss, und wird zur Pause, solange es läuft; angehalten bleibt das gerade gezeigte Einzelbild stehen. Bei nur einem Einzelbild steht es gar nicht erst da. Die Uhr spielt animierte GIFs ab, nicht nur deren erstes Einzelbild — am Gerät bestätigt (Hilfe → Gerätereferenz, §4.2)."),
                    .ueberschrift("Sichern"),
                    .absatz("„Ungesichert“ heißt hier: Was auf der Leinwand steht, weicht von dem ab, was im Bestand liegt — nicht, dass es beim Beenden verloren ginge; das zuletzt Gemalte übersteht einen Neustart ohnehin. Eine nie gesicherte Zeichnung ist deshalb ungesichert, ein eben geöffnetes Bild nicht, und wer seinen Strich mit „Rückgängig“ zurücknimmt, steht wieder auf dem gesicherten Stand. Danach fragt, was die Leinwand verwirft: das Kreuz, „Neu“, ein Größenwechsel und ein geladenes Bild. Ein Stück aus der Übersicht zu öffnen fragt nicht — dort ist der Druck darauf die Ansage, dass man es will. Name und Nummer zählen ohnehin nicht mit; sie sind in zwei Anschlägen wieder eingetippt."),
                    .absatz("Gesichert wird über den Haken rechts über der Leinwand; er legt alle Einzelbilder auf einmal ab. Bei einem neuen Stück und bei jedem nummerngeführten Icon fragt vorher ein Blatt nach Nummer und Namen und sagt, was es ersetzen würde — so ersetzt ein bearbeitetes LaMetric-Icon sein Vorbild nicht stillschweigend. Das Kreuz links daneben führt zurück zur Übersicht, ohne zu sichern; steht Ungesichertes da, fragt es vorher nach. Bei 8×8 gilt für die Nummer: Sie ist der Dateiname und zugleich die LaMetric-Nummer und muss eindeutig sein. Bei 52×16 gibt es ebenfalls eine — die Werknummer, die Ulanzi für seine „Pixel Art 52×16“ vergibt —, aber sie ist **wahlfrei** und benennt die Datei nicht: Dort heißt die Datei weiter nach dem Namen, und derselbe Name ersetzt das Vorhandene. Bei 16×16 gibt es keine Nummer; diese Größe ist nicht kanonisch, sie stammt von uns. Nachladen lässt sich von Ulanzi nichts — eine Adresse, die eine fertige 52×16-Datei liefert, gibt es dort nicht."),
                    .absatz("„Neu zeichnen“ hinter dem Plus der Übersicht beginnt von vorn: Leinwand, Einzelbilder, Verzögerung, Name und Nummer, in der gewählten Größe. Steht noch etwas Ungesichertes da, fragt eine Rückfrage vorher nach."),
                    .absatz("Die drei Bestände liegen weiterhin getrennt — 8×8 unter `~/Library/Application Support/MQTT-TC002/Icons`, 16×16 daneben unter `Icons16`, die Anzeigen unter `Bilder`. Gleiche Namen in zwei Beständen kommen sich deshalb nicht in die Quere. Über „Ablage“ öffnet der Finder den Icon- und den Bilderordner."),
                    .ueberschrift("Hinzufügen"),
                    .absatz("Hinter dem Plus der Übersicht liegt alles, was Neues hereinholt: „Neu zeichnen“ in einer der drei Größen, die „LaMetric Icon Gallery“, eine Datei und der Grundschatz."),
                    .absatz("„LaMetric Icon Gallery“ öffnet developer.lametric.com in einem Blatt, mit einem Nummernfeld darunter: Wer dort ein Icon findet, trägt seine Nummer ein und holt es, ohne die App zu verlassen — die Eingabetaste im Feld tut dasselbe wie „Holen“. Das geholte Icon ist immer ein 8×8, landet im 8×8-Bestand und kommt danach auf die Leinwand. Eine unbekannte Nummer ergibt eine verständliche Meldung und macht sonst nichts kaputt. „Grundschatz wiederherstellen“ ergänzt nur, was im eigenen Ordner fehlt, und lässt Vorhandenes unangetastet; die Meldung danach nennt die Anzahl."),
                    .absatz("„Finder …“ — am iPad „Dateien …“ — nimmt eine GIF-, PNG- oder JPEG-Datei von der Platte auf — und zwar in **ihrer eigenen** Größe: ein 8×8 als 8×8, ein 16×16 als 16×16, ein 52×16 als Anzeige. Was kleiner ist, kommt mittig in den kleinsten Raster, der es fasst — ein 7×7 wird ein 8×8-Icon mit leerem Rand, ein 32×8 eine Anzeige. Der Editor stellt sich auf die Datei ein, nicht umgekehrt; die Meldung nennt deshalb den Bestand, in dem sie gelandet ist. Ein animiertes GIF behält dabei alle seine Einzelbilder."),
                    .absatz("Nur was nicht auf die Anzeige passt, wird **abgelehnt**, mit Begründung („Das Bild ist 32×32 und passt nicht auf die Anzeige (52×16).“). Verkleinert wird nicht: Verkleinern zerstört, und wer es nicht gewollt hat, sähe es nicht."),
                    .absatz("Ein Blatt fragt danach nach dem Namen und — nur bei 8×8 — nach der LaMetric-Nummer; sein Kopf nennt die Größe, in der aufgenommen wird. Beginnt der Dateiname mit Nummer, Unterstrich und Titel, werden beide daraus vorbelegt: aus `2981_Severe TStorm.gif` also die Nummer `2981` und der Titel `Severe TStorm`. Sonst steht der ganze Dateiname im Namen und die Nummer bleibt leer."),
                    .absatz("Liegt unter dieser Nummer — oder, wo es keine gibt, unter diesem Namen — schon etwas, steht das im Blatt und nennt den Namen; der Knopf heißt dann „Ersetzen“ statt „Öffnen“. Abgewiesen wird es nicht: Dasselbe Icon in einer besseren Fassung noch einmal zu holen ist der häufigste Fall, und ersetzt wird beim Sichern ohnehin. Falsch war nicht das Ersetzen, sondern dass man es erst hinterher merkte."),
                    .absatz("Aufgenommenes kommt **auch auf die Leinwand** — in seiner eigenen Größe, die Leinwand stellt sich darauf ein. Steht dort Ungesichertes, fragt eine Rückfrage vorher: „Ersetzen“ legt das Geladene auf die Leinwand, „Nur in den Bestand“ lässt sie stehen, wie sie ist, „Abbrechen“ ändert gar nichts. In den Bestand geht es in jedem Fall; zur Frage steht allein die Leinwand. Bis zum 14.09.2026 wanderte eine eingelesene Datei nur in den Bestand und war nirgends zu sehen."),
                    .ueberschrift("Umbenennen und Löschen"),
                    .absatz("Beides steht im Kontextmenü einer Kachel der Übersicht. „Löschen“ fragt vorher nach und nennt den Namen. „Umbenennen…“ ändert den Namen immer, und wo es eine Nummer gibt, auch sie. Das Blatt ist dasselbe wie beim Aufnehmen und warnt ebenso **vorher**, wenn unter dem neuen Schlüssel schon etwas liegt; der Knopf heißt dann „Ersetzen“. Ohne Namen bleibt er gesperrt."),
                    .absatz("Umbenannt wird die Datei selbst: Bei 8×8 zieht sie mit der Nummer um, bei 16×16 und 52×16 mit dem Namen, und eine geänderte Werknummer lässt sie liegen, wo sie ist. Das Bild wird dabei nicht neu geschrieben, sondern verschoben — es bleibt Bit für Bit dasselbe. Liegt das umbenannte Stück gerade auf der Leinwand, ziehen Name und Nummer dort mit, sonst legte das nächste „Sichern“ es unter dem alten Namen ein zweites Mal an."),
                    .absatz("War das Gelöschte gerade geöffnet, bleibt das Bild auf der Leinwand stehen, nur Name und Nummer werden geleert — sonst legte ein erneutes „Sichern“ es unter demselben Namen wieder an."),
                    .ueberschrift("Zurückladen und Transparenz"),
                    .absatz("„Aus“ und „schwarz gemalt“ sind zweierlei, auch nach dem Sichern: Ein ausgeschaltetes Pixel wird im GIF durchsichtig abgelegt, ein schwarz gemaltes deckend schwarz. Auf der Uhr sieht beides gleich aus, weil ihr Grund schwarz ist — im Editor kommt ein wieder geöffnetes Bild aber so zurück, wie es gemalt war. Dass „aus“ durchsichtig bleibt, ist nebenbei die Bedingung dafür, dass die Laufschrift auf der Uhr sauber läuft (Gerätereferenz, §4.2a)."),
                    .ueberschrift("Senden"),
                    .absatz("Die Sendezeile unter der Leinwand gilt für jede Größe: Auch bei einem Icon will man sehen, wie es auf dem Gerät aussieht — es geht dann als Bild in die linke obere Ecke. Als Zubehör einer Meldung wählt man es weiterhin unter „Senden“. Die fünf Slot-Blöcke stehen dort mit denselben drei Zuständen und demselben Stand der aktiven Uhr wie unter „Senden“; ein Antippen wählt hier aber nur den Platz: Regler, die sich wiederherstellen ließen, gibt es beim Malen nicht. Aus demselben Grund merkt sich die App ein gemaltes Bild nicht, und eine Sendung von hier wirft weg, was zu diesem Platz gemerkt war."),
                    .absatz("Das ⊗ an einem belegten Block löscht die Anzeige auf der Uhr — nicht die Leinwand. Die Zielauswahl und „Senden“ funktionieren wie unter „Senden“ beschrieben, samt Hinweisfenster bei Fehlern und gesperrtem Knopf, solange keine Uhr fertig eingerichtet ist. Nimmt keine der Zieluhren ein gemaltes Bild an — eine AWTRIX hat acht Zeilen statt sechzehn —, steht der Grund sichtbar neben dem gesperrten Knopf. Eine eigene Dauer bekommt ein von hier geschicktes Bild nicht; wie lange es steht, entscheidet der Seitenwechsel der Uhr."),
                    .absatz("Der Hinweis unter der Leinwand zeigt, wie viele Rechtecke die Uhr am Ende bekommt: waagrechte Läufe gleicher Farbe werden vor dem Senden zu einem Rechteck zusammengefasst. Ein einzelnes Bild geht so hinaus — klein und exakt. Mehrere gehen als ein animiertes GIF, denn Rechtecke kennen keine Zeit; was dabei an Nutzlast zusammenkommt, gilt wie bei der Laufschrift unter „Senden“ — ein langes Laufbild wird groß, und wo die Grenze der Uhr liegt, weiß niemand."),
                ]
        case .anzeigen:
            return [
                    .absatz("Dieser Bereich ist die technische Mitschrift und sonst nichts. Was auf der Uhr liegt, steht unter „Senden“ in der Liste unter den fünf Blöcken."),
                    .absatz("Ist „Protokoll führen“ unter „Einstellungen“ → „Aufzeichnung“ ausgeschaltet — und das ist es ab Werk —, verschwindet der Eintrag in der Seitenleiste ganz: Ein Bereich, der nichts zeigt, ist kein Bereich. Dort steht auch „Verlauf führen“ mitsamt „Verlauf löschen“."),
                ]
                + HilfeInhalt.protokollListe
                + [
                    .absatz("Dazu jede Änderung des Seitenwechsels."),
                ]
                + HilfeInhalt.protokollLeeren
                + [
                    .ueberschrift("Seitenwechsel"),
                    .absatz("Die Einstellung „Seitenwechsel“ — wie lange eine Anzeige stehen bleibt, bevor die Uhr zur nächsten blättert — findet sich nicht hier, sondern unter „Einstellungen“ → „Uhren“ auf der Seite der Uhr, für die sie gilt."),
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
                    .absatz("Fehlende Zeichen, insbesondere Umlaute, kann es auf einer Ulanzi-Werksfirmware nicht geben: Die App rastert dorthin jeden Text selbst, stehend wie laufend, und benutzt die umlautlose Schrift der Uhr überhaupt nicht. Auf einer TC001 unter AWTRIX NG setzt die Uhr selbst — dort hängt es an ihrer Schrift."),
                ]
        }
    }
}
