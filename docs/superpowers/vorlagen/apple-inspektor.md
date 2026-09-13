# Apple-Inspektor als Vorlage

Beobachtet an **Pages** und **Numbers** (iPad und iPhone, 13.09.2026), vom
Auftraggeber als Vorbild benannt. Hier steht, was daraus **als Regel** folgt —
nicht „sieht gut aus", sondern was wo wie aussieht.

## Die Leiste oben

- Eine **schwebende Kapsel** mit Symbolen, nicht eine durchgehende Leiste.
- Das **gewaehlte** Symbol sitzt in einem **gefuellten Kreis in der Akzentfarbe**
  (Numbers gruen, Pages orange), die uebrigen sind blosse Striche.
- Rueckgaengig, Teilen und die Mitarbeit stehen **in derselben Kapsel**, nicht
  daneben. → Das ist die Antwort auf **A3**: Die Modussymbole gehoeren **in** die
  vorhandene Leiste, nicht als zweite darueber.

## Zweite Ebene: Reiter

Numbers hat **beides** — Symbole fuer die Art des Inspektors, darunter eine
**Segmentwahl** fuer den Bereich („Tabelle · Zelle · Format · Anordnen").
Gewaehlt = weisses Feld auf grauem Grund, nicht farbig.
→ Fuer uns: Die drei Modi koennen als Segmentwahl **unter** der Leiste stehen,
statt als drittes Symbolpaar hinein.

## Karten

- Abgerundete Bloecke auf grauem Grund, **ohne Rahmen**.
- Zusammengehoeriges in **einer** Karte, Trennlinien **innerhalb**; zwischen den
  Karten ein Abstand. Nicht jede Zeile eine eigene Karte.
- Ueberschriften sind **optional** — Numbers laesst sie oft ganz weg.

## Zeilen

- **Beschriftung links, Wert rechts.** Der Wert ist **grau**, wenn er nur
  Auskunft gibt („Helvetica Neue"), gefolgt von einem Winkel `›`.
- **Zahl mit Schrittwahl:** Die Zahl steht in einem **eigenen grauen Kaestchen**,
  daneben `−│+` als **ein** zusammenhaengendes Element mit Trennstrich in der
  Mitte — nicht zwei einzelne Knoepfe.
  → Unsere Zeilen „Rand 1 − +" und „Abstand 1 − +" treffen das fast, aber der
  Wert braucht sein Kaestchen und die Schrittwahl ihre Fassung.
- **Schalter** gruen wenn an, grau wenn aus.
- Eine Karte darf auch **nur** eine Schrittwahl tragen, ohne Zahl
  („Tabellenschrift (Groesse)").

## Schaltflaechen

Aus dem Pages-Inspektor (`Verbinden …` gesperrt neben `Fertig`):
grauer abgerundeter Kasten, **kein Rahmen**, **dunkle Schrift**, beim Druecken
dunkler. Der gesperrte Zustand ist **sichtbar abgeblendet**, nicht verschwunden.

**Die Falle:** Am Mac faerbt `.bordered` die Beschriftung dunkel, auf iPadOS in
der Akzentfarbe — dort braucht es die Textfarbe zusaetzlich.

## Was daraus fuer uns folgt

1. **A3** loest sich ueber die Kapsel: ein Satz Symbole, nicht zwei Leisten.
2. **B1** ist mehr als der Knopfstil — auch Wertkaestchen, Schrittwahl und
   Kartengliederung gehoeren dazu.
3. Farbe **markiert die Wahl**, sie schmueckt nicht. Genau ein Element je
   Gruppe traegt sie.
