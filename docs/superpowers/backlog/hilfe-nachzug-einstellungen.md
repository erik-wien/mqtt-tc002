# Hilfeschuld aus dem Umbau der Einstellungen

> **Erledigt.** Alle sechzehn Punkte stehen im Quelltext der Hilfe. Zwei
> Abweichungen vom Sollwortlaut, beide auf Ansage des Auftraggebers:
>
> - Punkt 15 wollte eine **Tabelle** „Fuenf Themen". Beides ist anders
>   gekommen: Die Ueberschrift nannte die Anzahl statt der Sache und ist weg,
>   die Tabelle ist eine Aufzaehlung geworden — den Baustein `tabelle` gibt es
>   nicht mehr (siehe `Hilfe.swift`, dort steht der Grund).
> - Punkt 16 hiess „Die Seite einer Uhr" und heisst jetzt
>   **„Konfigurieren der Pixel Uhr"**.
>
> Die Abbildungen waren nachzusehen und zeigten nichts Veraltetes.

Der Umbau nach Papier 11 (`einstellungen-nach-themen.md`) und 8
(`einstellungen-ohne-sichern-knopf.md`) hat die Bedienung der Einstellungen
umgestellt; die Hilfe beschreibt weiter die alte. Sie wurde **nicht**
mitgeändert — die Hilfe macht zum Schluss ein eigener Durchgang, und dieses
Papier ist dessen einzige Notiz.

Betroffen sind `Sources/TC002Ansichten/HilfeInhalt.swift` (beide
Oberflächen), `Sources/TC002Ansichten/HilfeView.swift` (Mac und iPad),
`Sources/TC002iOS/HilfeiOS.swift` (Telefon) und deren Übersetzung in
`Resources/Sprachen/en.lproj/Localizable.strings`. Jeder geänderte Absatz ist
ein Übersetzungsschlüssel: Der alte fällt weg, der neue kommt hinzu.

## Was jetzt gilt (Kurzfassung für den Bearbeiter)

- Die Einstellungen haben **fünf Themen**, auf allen Oberflächen dieselben und
  in derselben Reihenfolge: **Uhren · Broker · Aufzeichnung · iCloud ·
  Erweitert**.
- Am Schreibtisch (Mac und iPad) wählt eine **Segmentwahl über dem Inhalt** das
  Thema; auf dem Telefon ist der Einstieg eine **Liste mit fünf Einträgen**,
  jedes Thema eine eigene Seite. Hilfe und Über stehen weiter am Fuß dieser
  Liste.
- Das Thema **Uhren** zeigt je Uhr **eine Zeile** (Name, darunter Adresse ·
  Präfix · Gattung, rechts das Anmeldezeichen) und darunter die Zeile
  **„Uhr hinzufügen …“**, die ein Blatt mit **Adresse und Name** öffnet.
- Antippen einer Zeile öffnet die **Seite dieser Uhr**: Name, Adresse,
  Geräteart als Wahl, Betriebsart als Segmentwahl mit dem einen Satz darunter,
  **„Auf der Uhr“** (nur bei Werksfirmware), „Abfragen“ mit dem Präfix daneben,
  „Konfigurieren“ und am Fuß die rote Zeile **„Entfernen“**.
- **Entfernen fragt nach** — auf zwei Wegen mit derselben Rückfrage: die rote
  Zeile am Fuß der Uhrseite und **Wischen nach links** in der Liste.
- Der Brokerknopf heißt **„Verbindung prüfen“**, nicht mehr „Sichern und
  prüfen“. Adresse, Port und Benutzer sichern beim Tippen, das Kennwort beim
  Verlassen des Feldes.
- Unter dem Kennwortfeld steht, **ob** eines im Schlüsselbund liegt.
- Die **virtuelle Uhr** steht unter **Erweitert**, **Verlauf und Protokoll**
  unter **Aufzeichnung**, **iCloud** unter **iCloud**.

## Die Punkte im Einzelnen

### 1. `HilfeInhalt.startOhneEinrichtung`

**Jetzt falsch:** nichts am Inhalt — der Satz stimmt weiter. **Aber** er sagt
„beginnt die App bei den Einstellungen“; wer dort landet, sieht neuerdings die
Themenliste bzw. den Reiter „Uhren“ und nicht mehr ein Formular mit allem
darin.

**Soll:** Einen Halbsatz anhängen, der sagt, wo man dann steht: „… beginnt die
App bei den Einstellungen statt bei „Senden“ — beim Thema **Uhren**, wo die
erste Uhr eingetragen wird.“

### 2. `HilfeView.swift`, Überschrift „Uhr hinzufügen“ (Mac/iPad) und die entsprechende Stelle in `HilfeiOS.swift`

**Jetzt falsch:** „Unter „Einstellungen“ trägt man zuerst die Adresse einer Uhr
ein (das Feld unter der Liste, in dem eine Beispieladresse steht, dann
„Hinzufügen“ oder die Eingabetaste im Feld) …“

Das Feld unter der Liste gibt es nicht mehr.

**Soll:** „Unter „Einstellungen“ → **Uhren** steht am Fuß der Liste die Zeile
**„Uhr hinzufügen …“**. Sie öffnet ein Blatt mit **Adresse** und **Name**; der
Name ist freiwillig. Präfix und Geräteart stellt die App danach selbst fest.“

Der Rest des Absatzes (angesehene Uhr, Titelmenü, Sendeziel) bleibt richtig.

### 3. `HilfeInhalt.betriebsart`, erster Absatz

**Jetzt falsch:** „Jede Uhr hat **in ihrer Zeile** eine eigene Wahl mit zwei
Einträgen …“

Die Wahl steht nicht mehr in der Zeile, sondern auf der Seite der Uhr.

**Soll:** „Jede Uhr hat **auf ihrer Seite** eine eigene Wahl mit zwei
Einträgen: „HTTP“ und „MQTT“ …“ (Rest unverändert).

### 4. `HilfeView.swift`, der Absatz nach `HilfeInhalt.geraeteart`

**Jetzt falsch:** „Am Mac und auf dem iPad steht die Wahl als Zweierschalter in
der Zeile der Uhr, zwischen Adresse und Präfix.“

Es gibt keinen Zweierschalter in der Zeile mehr, und die Wahl der Geräteart ist
auf **beiden** Oberflächen dieselbe Zeile auf der Uhrseite.

**Soll:** Der Absatz **entfällt ersatzlos** (der Satz in
`HilfeInhalt.geraeteart` — „Abfragen stellt das selbst fest …“ — sagt bereits
alles, was gilt, und gilt jetzt für beide Oberflächen). Die entsprechende
Stelle in `HilfeiOS.swift`, die vom **Kontextmenü** spricht, entfällt ebenfalls:
Die Geräteart ist jetzt eine gewöhnliche Wahlzeile, kein Langdruck mehr.

### 5. `HilfeView.swift`, der Absatz zur Adressänderung

**Jetzt teilweise falsch:** „… und zeigt **in der Zeile** wieder „—“.“

Die Kennzeile der Liste zeigt bei einer HTTP-Uhr gar kein Präfix mehr, bei
einer MQTT-Uhr „noch nicht abgefragt“.

**Soll:** „… verwirft die App Präfix, MAC und Verbindungsstand; die Zeile der
Uhr zeigt dann wieder **„noch nicht abgefragt“**. Nach einer Adressänderung
also erneut „Abfragen“.“

### 6. `HilfeView.swift`, Überschrift „Entfernen“

**Jetzt falsch:** „„Entfernen“ **am rechten Rand der Zeile** löscht die Uhr aus
der Liste …“ — und es fehlt, dass jetzt nachgefragt wird.

**Soll:** „Eine Uhr wird auf zwei Wegen entfernt: mit der roten Zeile
**„Entfernen“** am Fuß ihrer Seite oder mit einem **Wischen nach links** in der
Liste. Beide fragen dasselbe nach. Auf der Uhr selbst ändert das nichts — eine
dort stehende Anzeige bleibt stehen, also besser vorher unter „Verlauf“
löschen.“

### 7. `HilfeView.swift`, der Absatz „Seitenwechsel und Scrolltempo“

**Jetzt ungenau:** „stehen hier, bei der Uhr, für die sie gelten“ — das stimmt
jetzt erst wirklich, vorher galt es der angesehenen Uhr. Zusätzlich fehlt, dass
der Abschnitt bei einer AWTRIX NG **gar nicht da** ist.

**Soll:** „**„Auf der Uhr“** — Seitenwechsel und Scrolltempo — steht auf der
Seite der Uhr, für die beides gilt: Beides sind Einstellungen des Geräts, sie
überdauern jede Meldung und werden beim Verstellen sofort geschrieben. Bei
einer **AWTRIX NG fehlt der Abschnitt**: Ihre Firmware kennt `/getConfig`
nicht, sie führt beides selbst. Der Seitenwechsel ist der Takt, in dem die Uhr
durch alles blättert, was auf ihr steht; das Scrolltempo gilt nur ihren eigenen
Anzeigen (Gerätereferenz, §4.3). Wie lange eine einzelne Meldung steht und wie
schnell sie läuft, entscheidet der Zeit-Reiter unter „Senden“.“

### 8. `HilfeView.swift`, Überschrift „Broker“

**Jetzt falsch:** „**Darunter** steht der Broker: Adresse, Port, Benutzer und
Kennwort.“

Der Broker steht nicht mehr darunter, sondern ist ein eigenes Thema.

**Soll:** „Der Broker ist ein eigenes Thema: Adresse, Port, Benutzer und
Kennwort.“

### 9. `HilfeView.swift`, der Absatz zum Sichern des Kennworts

**Jetzt unvollständig:** „Gesichert wird es, sobald man das Feld verlässt, die
Eingabetaste drückt, den Bereich wechselt oder die App beendet — nicht bei
jedem Tastendruck.“ Es fehlt, was mit **Adresse, Port und Benutzer** geschieht,
und genau das war der Anlass für Papier 8.

**Soll:** Zwei Sätze. „Adresse, Port und Benutzer sichern sich beim Tippen —
es gibt nichts zu bestätigen. Das Kennwort wird gesichert, sobald man das Feld
verlässt, die Eingabetaste drückt, das Thema wechselt oder die App beendet —
nicht bei jedem Tastendruck.“

Dieser Absatz steht heute nur in `HilfeView.swift`; nach der Umstellung gilt er
wortgleich für beide Oberflächen und gehört damit nach `HilfeInhalt`. Prüfen,
ob `HilfeiOS.swift` einen eigenen Satz dazu führt, und diesen dann streichen.

### 10. `HilfeInhalt.brokerKennwort` — neuer zweiter Satz

**Jetzt unvollständig:** „Das Kennwort liegt im Schlüsselbund und nicht, wie die
übrigen Felder, in den App-Einstellungen.“ Es fehlt, dass unter dem Feld steht,
**ob** eines hinterlegt ist.

**Soll:** Einen Satz anhängen: „Unter dem Feld steht, ob im Schlüsselbund eines
liegt — das Feld selbst zeigt es nie an.“

### 11. `HilfeInhalt.brokerPruefen`, erster Absatz

**Jetzt falsch:** „**„Sichern und prüfen“** schreibt Adresse, Port, Benutzer
und Kennwort ausdrücklich fest und fragt danach den Broker …“

Der Knopf heißt anders und sichert nichts mehr, was nicht schon gesichert wäre.

**Soll:** „**„Verbindung prüfen“** fragt den Broker, ob er die Anmeldung
annimmt — das dauert bis zu acht Sekunden und läuft unter einer eigenen
Client-Kennung, damit dabei keine laufende Sendung hinausfliegt. Zu sichern
gibt es dabei nichts: Adresse, Port und Benutzer stehen schon beim Tippen fest,
das Kennwort spätestens beim Verlassen des Feldes.“

Der zweite Absatz („Eine angenommene Anmeldung heißt aber nur …“) bleibt
unverändert richtig.

### 12. `HilfeInhalt.brokerNurFuerMqtt`

**Jetzt ungenau:** „Steht keine Uhr darauf, bleiben seine **Felder** ungenutzt
— ausgegraut oder versteckt sind sie trotzdem nicht.“ Das gilt weiter; neu ist
nur, dass es ein eigenes Thema ist und der Hinweis dort oben steht.

**Soll:** Unverändert lassen. Hier ist nichts falsch geworden.

### 13. `HilfeInhalt.virtuelleUhr`

**Jetzt unvollständig:** Es fehlt, wo der Schalter steht.

**Soll:** Im ersten Absatz „Der Schalter **„Virtuelle Uhr“** unter
**Einstellungen → Erweitert** startet eine Uhr, die es nicht gibt.“ — Der Rest
bleibt.

### 14. Verlauf und Protokoll

Beide Schalter stehen jetzt unter **Aufzeichnung**. Wo die Hilfe sie erwähnt
(„Verlauf führen“, „Protokoll führen“, der Absatz unter „Protokoll“, der sagt,
dass der Bereich nur da ist, wenn es eingeschaltet ist), gehört der Ort
nachgezogen: **Einstellungen → Aufzeichnung**.

`grep -n "Protokoll führen\|Verlauf führen" Sources/TC002Ansichten/HilfeView.swift Sources/TC002Ansichten/HilfeInhalt.swift Sources/TC002iOS/HilfeiOS.swift`

### 15. Ein neuer Absatz, den es noch gar nicht gibt: die Gliederung selbst

Die Hilfe sagt nirgends, dass die Einstellungen fünf Themen haben. Das ist das
Erste, was man wissen will.

**Soll:** Ganz an den Anfang des Abschnitts „Einstellungen“, vor
`startOhneEinrichtung`, eine Tabelle — sie gilt für beide Oberflächen und
gehört damit nach `HilfeInhalt`:

    .ueberschrift("Fünf Themen")
    .absatz("Die Einstellungen sind nach Themen gegliedert. Am Mac und auf dem
             iPad steht die Wahl als Segmentwahl über dem Inhalt, auf dem
             Telefon als Liste, deren Einträge auf je eine Seite führen.")
    .tabelle([
        ("Uhren",        "die eingetragenen Uhren, je eine Zeile, die auf ihre Seite führt"),
        ("Broker",       "Adresse, Port, Benutzer, Kennwort und die Prüfung"),
        ("Aufzeichnung", "Verlauf und Protokoll"),
        ("iCloud",       "der Abgleich"),
        ("Erweitert",    "die virtuelle Uhr"),
    ])

### 16. Und einer für die Uhrseite

**Soll:** Nach der Tabelle aus Punkt 15, ebenfalls in `HilfeInhalt`:

    .ueberschrift("Die Seite einer Uhr")
    .absatz("Eine Zeile in der Liste antippen öffnet die Seite dieser Uhr.
             Dort steht alles, was zu ihr gehört: Name, Adresse, Geräteart,
             Betriebsart, „Auf der Uhr“ (nur bei der Werksfirmware),
             „Abfragen“ und „Konfigurieren“ — und am Fuß, rot, „Entfernen“.
             Jeder Wert dort gilt dieser Uhr, nicht der angesehenen.")

Der letzte Halbsatz ist der Punkt: Vorher galt „Auf der Uhr“ der angesehenen
Uhr, und eine Fußnote sagte es. Die gibt es nicht mehr, weil es sie nicht mehr
braucht.

## Abbildungen

`Hilfebilder.swift` prüfen: Zeigt eine Abbildung die alte Uhrenzeile mit ihren
drei Knöpfen oder das Formular am Stück, ist sie neu zu zeichnen. Beim Umbau
wurde keine angefasst.

## Übersetzung

Nach jeder Änderung an der Hilfe:

    python3 scripts/texte-sammeln.py --pruefen

muss `0 ohne Uebersetzung` melden; die entfallenen Absätze sind aus
`Resources/Sprachen/en.lproj/Localizable.strings` zu streichen (sie erscheinen
dort als „unnoetig“).
