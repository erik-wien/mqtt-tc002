# Einstellungen: nach Themen gegliedert, mit Reitern

> **Erledigt.** Zwei Abweichungen vom Papier, beide begruendet:
>
> - **Keine `TabView`, sondern eine Segmentwahl ueber dem Inhalt.** Das Papier
>   liess das offen („wenn iPadOS die Reiter als Leiste unten zeichnet,
>   stattdessen `Picker` mit `.segmented`") — genau das tut iPadOS 26, und dort
>   gehoert die untere Leiste der App, nicht einem Bereich innerhalb eines
>   Bereichs. Die Vorlage nennt die Segmentwahl fuer die zweite Ebene.
> - **Hinzufuegen als Zeile am Fuss der Liste, nicht als `+` in der
>   Werkzeugleiste.** Die Einstellungen stehen am Mac im Detailbereich eines
>   `NavigationSplitView`; ein `.toolbar` daraus landet in der Fensterleiste
>   neben dem Uhrenmenue. Eine Zeile „Uhr hinzufuegen …" ist die Bauart der
>   Systemeinstellungen („Account hinzufuegen") und traegt auf allen drei
>   Oberflaechen.
>
> Die Hilfe wurde **nicht** mitgeaendert; der Nachzug steht vollstaendig in
> `hilfe-nachzug-einstellungen.md`.

**Vom Auftraggeber bestellt, 19.09.2026:** *„die einstellungen gehören mit
tabs strukturiert und besser nach themen gruppiert."* Vor Papier 8
(`einstellungen-ohne-sichern-knopf.md`) zu bauen; dessen Knopf und
Kennwortfeld werden dabei miterledigt, das Papier danach mit Vermerk
geschlossen.

## Was heute geschieht

Eine einzige rollende `Form` auf allen drei Oberflaechen
(`TC002Ansichten/VerbindungView.swift` fuer Mac und iPad, 296 Zeilen;
`TC002iOS/VerbindungiOS.swift` fuer das Telefon, 290 Zeilen), in dieser
Reihenfolge: Uhren — Auf der Uhr (`Uhreinstellungen`) — Virtuelle Uhr —
Verlauf — Protokoll — Broker — iCloud (`Wolkenabschnitt`) — am Telefon
zusaetzlich Hilfe und Ueber.

Vier Dinge daran, alle auf den Telefon-Fotos vom 19.09. zu sehen:

1. **Die Uhrenliste ist eine Wand.** Je Uhr eine Karte mit Name,
   Kennzeile, Segmentwahl HTTP/MQTT und drei Knoepfen (Abfragen,
   Konfigurieren, Entfernen in Rot). Bei vier Uhren zwoelf Knoepfe und vier
   Segmentwahlen auf einem Bildschirm, bevor die erste andere Einstellung
   kommt. Entfernen als roter Dauerknopf in jeder Karte.
2. **„Auf der Uhr" gilt fuer eine Uhr, steht aber unter allen.** Seitenwechsel
   und Scrolltempo betreffen die *angesehene* Uhr — die Fussnote sagt es
   („Gilt fuer die angesehene Uhr: …"), die Stelle nicht. Wer eine andere
   Uhr meint, muss die Einstellungen verlassen, umschalten, zurueckkommen.
3. **Themen liegen durcheinander.** Die Virtuelle Uhr (ein Pruefwerkzeug)
   steht zwischen den Uhren und dem Verlauf; Verlauf und Protokoll
   (Aufzeichnung) stehen vor dem Broker (Verbindung); iCloud ganz unten.
4. **Erklaertexte in Absaetzen.** Unter Seitenwechsel zwei Absaetze, unter
   der Virtuellen Uhr zwei, unter HTTP/MQTT einer, unter dem Verlauf einer.
   Eine Einstellung, die einen Absatz braucht, um verstanden zu werden,
   steht am falschen Ort oder heisst falsch.

## Was gelten soll

### Die Themen — auf allen drei Oberflaechen dieselben, in derselben Reihenfolge

| Reiter | Inhalt |
|---|---|
| **Uhren** | Die Liste der Uhren; Hinzufuegen; je Uhr eine eigene Seite (unten) |
| **Broker** | Adresse, Port, Benutzer, Kennwort, „Verbindung pruefen" mit Stand |
| **Aufzeichnung** | Verlauf fuehren, Verlauf loeschen, Protokoll fuehren |
| **iCloud** | Ueber iCloud abgleichen, die zwei Saetze dazu |
| **Erweitert** | Virtuelle Uhr — ein Werkzeug zum Ausprobieren, kein Betriebsteil |

Hilfe und Ueber bleiben am Telefon am Fuss des Einstiegs (iOS hat keine
Menueleiste); am Mac und iPad stehen sie in Menue und Seitenleiste und
nicht in den Einstellungen.

### Je Uhr eine Seite

Die Liste zeigt je Uhr **eine Zeile**: Name, darunter die Kennzeile
(Adresse · Praefix · Gattung, wie `kennzeile` heute), rechts das
Verbindungszeichen (`Brokerzeichen`). Antippen oeffnet die Seite der Uhr:

- Name, Adresse, Gattung (als Wahl, nicht mehr nur im Kontextmenue),
  Betriebsart HTTP/MQTT als Segmentwahl mit dem einen Satz darunter, der
  den Unterschied sagt;
- **„Auf der Uhr"** — Seitenwechsel und Scrolltempo, **nur bei einer TC002
  mit Werksfirmware**; eine NG hat sie nicht, dort fehlt der Abschnitt
  (heute `Uhreinstellungen`, das ohnehin die Gattung prueft);
- Abfragen und Konfigurieren als zwei Zeilen mit ihrem Stand;
- **Entfernen** als rote Zeile am Fuss der Seite — wie „Dieses Geraet
  entfernen" in Einstellungen. Zusaetzlich Wischen in der Liste
  (`.swipeActions`, `role: .destructive`) mit Rueckfrage.

Hinzufuegen: `+` in der Werkzeugleiste des Uhren-Reiters, oeffnet ein
`Blatt` (`TC002Ansichten/Blatt.swift`) mit Adresse und Name; das Feld
„z. B. 192.168.0.10" mit Knopf daneben entfaellt.

### Die Reiter je Oberflaeche

- **Mac:** `TabView` mit `.tabViewStyle(.automatic)` — die Reiterleiste
  oben, wie Systemeinstellungen alter Bauart und Xcode → Settings.
  Die Ansicht bleibt der Bereich „Einstellungen" in der Seitenleiste
  (`SchreibtischView`), das aendert sich nicht. Jeder Reiter eine
  `Form` in `.grouped`, ohne Rollen, wo es der Inhalt hergibt.
- **iPad:** dieselbe `TabView`; iPadOS zeichnet sie als Segmentwahl
  ueber dem Inhalt. Im Simulator ansehen — wenn iPadOS die Reiter als
  Leiste unten zeichnet, stattdessen `Picker` mit `.segmented` ueber der
  `Form` (dieselben fuenf Namen).
- **iPhone:** Eine Reiterleiste in einem Blatt ist auf dem Telefon nicht
  ueblich — Reiter gehoeren dort der App, nicht einem Blatt. Der Einstieg
  ist darum eine `List` mit den fuenf Themen als `NavigationLink` (die
  Bauart der Einstellungen-App), jedes Thema eine eigene Seite mit
  derselben `Form`. Das ist der eine Unterschied zwischen den
  Oberflaechen, begruendet mit dem Platz, und steht als Satz an der
  Stelle. Die Inhalte der Seiten sind **dieselben Bausteine** wie die
  Reiter am Mac (`Brokerabschnitt`, `Aufzeichnungsabschnitt`,
  `Wolkenabschnitt`, `Uhrseite` …) — je Thema eine Datei in
  `TC002Ansichten`, aus der beide Oberflaechen ihre Form bauen.
  `VerbindungiOS` und `VerbindungView` schrumpfen dabei auf das Geruest.

### Erklaertexte

Je Einstellung **hoechstens ein Satz** als Fussnote, in `.footnote`. Was
laenger ist, steht hinter dem (?) (`Abschnittskopf(…, hilfe:)`,
`Hilfezeichen`) oder in der Hilfe. Die zwei Absaetze unter Seitenwechsel
werden ein Satz („Der Takt, in dem die Uhr durch alles blaettert, was auf
ihr steht") plus (?); die zwei unter der Virtuellen Uhr ein Satz („Nimmt
Anzeigen entgegen wie eine Ulanzi mit Werksfirmware, ohne Geraet im Netz")
plus (?). Der Absatz unter HTTP/MQTT wird der eine Satz unter der
Segmentwahl auf der Uhrseite.

## Abnahme

- Bildschirmfotos aller fuenf Reiter am Mac, aller fuenf Seiten am iPhone,
  einer Uhrseite auf beiden.
- Eine NG-Uhrseite zeigt keinen Abschnitt „Auf der Uhr"; eine TC002-Seite
  zeigt ihn — und die Werte gelten fuer **diese** Uhr, nicht die angesehene
  (Test in `Tests/TC002ModellTests`: Seitenwechsel auf Uhr B setzen, Uhr A
  bleibt).
- Entfernen fragt nach; Wischen und Zeile fuehren auf dieselbe Rueckfrage.
- Kein Erklaertext laenger als ein Satz (Sichtpruefung ueber
  `grep -n "Text(\"" Sources/TC002Ansichten/*abschnitt*.swift`, wo jeder
  Fussnotentext steht).
- `0 ohne Uebersetzung`; entfallene Absaetze aus `en.lproj` gestrichen.
- Hilfe → Einstellungen beschreibt die Reiter und die Uhrseite; die
  Abbildung dazu, falls eine existiert (`Hilfebilder.swift`), passt noch.
- Die `Codable`-Form von `Uhr` bleibt unveraendert (`EinstellungenTests`) —
  hier aendert sich die Oberflaeche, nicht die Ablage.

## Waechter, die sich melden werden

`HilfezeichenTests` (die Koepfe mit (?) je Datei), `KnopfstilTests`,
`LoeschzeichenTests` (die Felder mit Loeschzeichen: `$text`, Adresse …),
`EinblendtextGegenstueckTests`, `UhrenwahlTests`. Nach der Aufteilung in
Dateien je Thema zeigen die Pfade in diesen Tests auf Dateien, die es
nicht mehr gibt — jeden auf die neue Datei umschreiben, keinen streichen.

## Nicht anfassen

`AppZustand` (Betriebsart, Abfragen, Konfigurieren, Broker pruefen sind
dort fertig), `Einstellungen` im Kern, `Uhr`.
