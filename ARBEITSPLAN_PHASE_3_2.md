# FlowDictate – Arbeitsplan Phase 3.2

**Phase:** 3.2 – Smart Dictation

**Status:** Abgeschlossen; automatisierte Tests und manueller Referenz-Mac-Test bestanden

**Stand:** 21. August 2026

**Grundlage:** `FlowDictate_PRD_Phase_3.md`, abgeschlossene Phase 3.1 und aktueller Code auf `main`

## 1. Ziel

Phase 3.2 ergänzt die bestehende Diktierpipeline um nachvollziehbare Textverarbeitung nach der finalen Transkription. Lokale Formatierungsregeln und das persönliche Wörterbuch laufen ohne zusätzliche Cloud-Anfrage. Eine AI-Nachbearbeitung über Schreibstile ist optional.

Nach Abschluss gilt:

- das unveränderte OpenAI-Transkript bleibt immer als Original erhalten,
- gesprochene Formatierungsbefehle funktionieren lokal für Deutsch und Englisch,
- persönliche Wörterbuchregeln funktionieren lokal, reproduzierbar und sprachabhängig,
- der Benutzer kann eingebaute und eigene Schreibstile verwenden,
- der Stil **Original** erzeugt keinen zusätzlichen API-Aufruf,
- jeder Verarbeitungsschritt ist in der History nachvollziehbar,
- ein Fehler der Nachbearbeitung verliert weder Audio noch Text,
- nur die Nachbearbeitung kann erneut versucht werden, ohne das Audio erneut zu transkribieren,
- bestehende History-Dateien werden ohne SQLite und ohne Datenverlust migriert.

## 2. Festgelegte Produktentscheidungen

### 2.1 Kein SQLite in Phase 3.2

- Die History bleibt eine atomar geschriebene, versionierte JSON-Datei.
- Die bestehende Begrenzung nach Alter und Datensatzmenge bleibt bestehen.
- Neue Felder werden rückwärtskompatibel dekodiert.
- Vor der ersten Schema-Migration wird eine Sicherung der bestehenden History angelegt.
- Eine spätere Datenbankmigration bleibt möglich, ist aber kein Bestandteil dieser Phase.

### 2.2 Original bleibt Standard

- Der Standardschreibstil ist **Original**.
- Bestehende Installationen und vorhandene History-Einträge werden auf **Original** migriert.
- Ohne bewusste Aktivierung gibt es keinen zusätzlichen API-Aufruf und keine zusätzlichen Kosten.
- Lokale Formatierung und Wörterbuch sind getrennt aktivierbar.

### 2.3 Klare Textstufen

```text
originalTranscript
    ↓ lokale gesprochene Formatierung
formattedTranscript
    ↓ lokales persönliches Wörterbuch
dictionaryTranscript
    ↓ optionaler AI-Schreibstil
finalText
```

- `originalTranscript` wird nach erfolgreicher Transkription nicht mehr verändert.
- Jede Stufe erhält ausschließlich die Ausgabe der vorherigen Stufe.
- Deaktivierte Stufen reichen den Text unverändert weiter.
- `finalText` ist ausschließlich der Text, der eingefügt oder exportiert wird.

### 2.4 Datenschutz und API-Nutzung

- Formatierungsbefehle und Wörterbuch werden vollständig lokal ausgeführt.
- Für AI-Nachbearbeitung wird nur Text übertragen, niemals Audio, Fenstertitel oder Clipboard-Inhalt.
- Wörterbuchinhalte, eigene Stilprompts und diktierter Text erscheinen nicht in normalen Logs.
- Der vorhandene API-Key wird weiter aus dem Schlüsselbund gelesen.
- Modell und Provider werden getrennt von der finalen Audiotranskription gespeichert.

### 2.5 Fokusverhalten

- Das Recording- und Live-Preview-Overlay bleibt während der Aufnahme nonactivating und ignoriert Mausklicks.
- Nach einem Enhancement-Fehler darf ein getrennter Wiederherstellungszustand Aktionen anbieten.
- Die ursprüngliche Ziel-App bleibt gespeichert; Einfügen stellt sie vor dem Paste-Vorgang wieder her.
- Kein Settings-, History- oder Fehlerfenster wird während einer normalen erfolgreichen Diktierung geöffnet.

## 3. Nicht Bestandteil von Phase 3.2

- app-spezifische Profile,
- direkte Einfügung über `AXUIElement`,
- Nutzungsstatistik und Zeitersparnis,
- GitHub-Updateprüfung,
- Cloud-Realtime-Transkription,
- lokale finale Transkription,
- komplexe Sprachbefehle wie „lösche den letzten Satz“,
- automatische Verwendung von Fensterinhalt oder Clipboard als AI-Kontext,
- Synchronisation von Stilen oder Wörterbuch über eine Cloud,
- SQLite.

## 4. Lieferstrategie

Phase 3.2 wird in drei einzeln prüfbare Schritte geteilt.

### 3.2.1 – Lokale Smart-Dictation-Grundlage

- History-Schema und Migration,
- Verarbeitungsstufen,
- gesprochene Formatierungsbefehle,
- persönliches Wörterbuch,
- lokale Tests ohne zusätzliche API-Aufrufe.

### 3.2.2 – Schreibstile und AI-Nachbearbeitung

- eingebaute Schreibstile,
- AI-Provider-Abstraktion,
- Enhancement-Pipeline,
- Ergebnisvalidierung,
- Retry und Rohtext-Fallback.

### 3.2.3 – Oberfläche, Import/Export und Abnahme

- Settings → Smart Dictation,
- Editor für eigene Stile und Wörterbuch,
- Original-/Final-Vergleich,
- History-Erweiterung,
- Fehleraktionen, Import/Export, Dokumentation und manuelle Tests.

Jeder Schritt erhält einen separaten Commit erst nach bestandenem Build, automatisierten Tests und der jeweils vorgesehenen manuellen Prüfung.

## 5. Zielarchitektur

```text
OpenAITranscriptionProvider
        ↓ originalTranscript unveränderlich speichern
SmartDictationPipeline
        ├── SpokenFormattingProcessor (lokal)
        ├── PersonalDictionaryProcessor (lokal)
        └── optional TranscriptEnhancer (API)
                ↓
        SmartDictationResult
                ↓
DictationHistoryStore → alle Textstufen und Status atomar speichern
                ↓
TextInserter → ausschließlich finalText
```

### 5.1 Neue beziehungsweise erweiterte Komponenten

| Komponente | Verantwortung |
|---|---|
| `SmartDictationPipeline` | Reihenfolge, Status, Persistenzpunkte und Abbruchregeln |
| `SpokenFormattingProcessor` | deterministische Befehle für Deutsch und Englisch |
| `PersonalDictionaryProcessor` | lokale, sortierte und konfliktgeprüfte Ersetzungen |
| `DictionaryStore` | versionierte JSON-Persistenz und Import/Export |
| `WritingStyleStore` | eingebaute und eigene Stilprofile |
| `TranscriptEnhancing` | vom konkreten AI-Anbieter unabhängige Schnittstelle |
| `OpenAITranscriptEnhancer` | textbasierte Nachbearbeitung mit bestehendem API-Key |
| `EnhancementResponseValidator` | leere, offensichtlich beschädigte oder unplausible Ergebnisse abweisen |
| `SmartDictationSettingsView` | zentrale Verwaltung aller 3.2-Einstellungen |
| `EnhancementRecoveryView` | Rohtext verwenden, Retry und History öffnen |

## 6. Arbeitspaket A – Datenmodelle und migrationsfähige History

### A1. Neue Modelle

Einzuführen sind mindestens:

```swift
enum SmartProcessingStatus: String, Codable, Sendable {
    case notStarted
    case formatting
    case formatted
    case enhancing
    case enhanced
    case enhancementFailed
    case completed
}

struct WritingStyleProfile: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var instruction: String
    var isBuiltIn: Bool
    var isEnabled: Bool
    var schemaVersion: Int
}

struct DictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var spokenForm: String
    var replacement: String
    var language: String?
    var caseSensitive: Bool
    var matchWholeWordsOnly: Bool
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

Eingebaute Stile erhalten feste UUID-Konstanten, damit History-Verweise über Versionen stabil bleiben.

### A2. Erweiterung von `DictationRecord`

Neue optionale beziehungsweise defaultfähige Felder:

- `formattedTranscript`,
- `dictionaryTranscript`,
- `writingStyleID`,
- `processingStatus`,
- `enhancementProviderID`,
- `enhancementModelID`,
- `enhancementAttemptCount`,
- `enhancementErrorCategory`,
- `enhancementErrorMessage`,
- `dictionaryReplacementCount`,
- `spokenFormattingEnabled`.

`originalTranscript`, Audioinformationen und bestehende Transkriptionsfehler bleiben unverändert.

### A3. Migration

- `FlowDictateVersion.historySchema` und `dictationRecordSchema` werden erhöht.
- Fehlende neue Felder erhalten beim Dekodieren sichere Defaults.
- Bei vorhandenen erfolgreichen Datensätzen gilt `finalText ?? originalTranscript` weiterhin als bisheriges Endergebnis.
- Bestehende Datensätze erhalten Stil **Original** und Status `completed`, ohne ihren Text neu zu verarbeiten.
- Vor dem ersten Schreiben des neuen Schemas wird `dictations-pre-3.2.json` als einmalige Sicherung angelegt.
- Eine teilweise oder beschädigte Migration überschreibt niemals die letzte lesbare Datei.
- Archivierte Datensätze bleiben kompakt; neue Textstufen werden beim Archivieren ebenfalls entfernt.

### A4. Tests

- Phase-2-/3.1-Fixture wird verlustfrei geladen,
- neue Datensätze werden vollständig round-trip-kodiert,
- unbekannte Enum-Werte führen zu einem kontrollierten Migrationsfehler statt Datenverlust,
- Backup wird genau einmal angelegt,
- fehlgeschlagene Persistenz lässt die vorherige History bestehen,
- Retention und Recovery berücksichtigen neue Processing-Status.

### Gate A

Alle bisherigen Tests bestehen; eine Kopie einer bestehenden History wird geladen, migriert und erneut geladen, ohne Audio- oder Textverlust.

## 7. Arbeitspaket B – Lokale gesprochene Formatierung

### B1. Unterstützte Befehle

Deutsch und Englisch unterstützen:

- Punkt / period,
- Komma / comma,
- Fragezeichen / question mark,
- Ausrufezeichen / exclamation mark,
- neue Zeile / new line,
- neuer Absatz / new paragraph,
- Aufzählung / bullet point,
- Klammer auf/zu / open/close parenthesis.

### B2. Verarbeitungsregeln

- Befehle werden nur als vollständige, eindeutige Phrasen erkannt.
- Längere Mehrwortbefehle werden vor kürzeren geprüft.
- Groß-/Kleinschreibung der gesprochenen Phrase ist standardmäßig irrelevant.
- Satzzeichen entfernen überflüssige Leerzeichen davor und erzeugen passende Leerzeichen danach.
- Zeilenumbrüche werden nicht durch anschließende Whitespace-Bereinigung zerstört.
- Wiederholte Befehle bleiben deterministisch.
- URLs, E-Mail-Adressen und erkennbare Codebestandteile werden nicht innerhalb eines Tokens verändert.
- „wörtlich“ beziehungsweise „literal“ schützt den unmittelbar folgenden Befehl und entfernt nur das Escape-Wort.

### B3. Tests

- jeder Befehl einzeln in Deutsch und Englisch,
- Befehle am Anfang, in der Mitte und am Ende,
- mehrere Befehle hintereinander,
- wörtlicher Escape,
- Groß-/Kleinschreibung,
- keine Teilworttreffer,
- Leerzeichen, Absätze und Listen,
- URLs, E-Mail-Adressen, Zahlen und einfache Codebeispiele,
- leere und sehr lange Eingaben.

### Gate B

Die Formatierung ist vollständig lokal, deterministisch und durch tabellengetriebene Tests für Deutsch und Englisch abgedeckt.

## 8. Arbeitspaket C – Persönliches Wörterbuch

### C1. Speicherung

- Datei unter Application Support → FlowDictate → SmartDictation → `dictionary.json`,
- versionierter Envelope,
- atomare Schreibvorgänge,
- komplexe Einträge nicht in `UserDefaults`,
- Import und Export enthalten keine Schlüssel oder History-Daten.

### C2. Validierung

- `spokenForm` und `replacement` dürfen nach Trimmen nicht leer sein,
- exakte Duplikate werden verhindert,
- Konflikte gleicher Ausgangsform werden sichtbar gemeldet,
- Sprache ist optional oder auf unterstützte Sprachcodes beschränkt,
- Standard ist Whole-Word-Matching ohne Beachtung der Groß-/Kleinschreibung,
- deaktivierte Einträge bleiben gespeichert, werden aber nicht angewendet.

### C3. Ersetzungsalgorithmus

- nur Einträge der aktuellen Sprache oder sprachneutrale Einträge verwenden,
- längere Ausgangsformen vor kürzeren anwenden,
- stabile Reihenfolge bei gleicher Länge,
- Whole-Word-Grenzen Unicode-fähig bestimmen,
- Case-sensitive Regeln exakt anwenden,
- Ersetzungen einer Regel werden innerhalb desselben Durchlaufs nicht erneut als Eingabe interpretiert,
- Ergebnis und Anzahl angewendeter Regeln zurückgeben.

### C4. Tests

- Wortgrenzen und Umlaute,
- Groß-/Kleinschreibung,
- überlappende lange und kurze Regeln,
- sprachabhängige Regeln,
- Konflikte und Duplikate,
- deaktivierte Regeln,
- Sonderzeichen in Ersetzungen,
- Import einer gültigen und Ablehnung einer beschädigten Datei,
- kein Logging der Inhalte.

### Gate C – Abschluss 3.2.1

Ein Diktat kann ohne zusätzliche Cloud-Anfrage lokal formatiert und durch das Wörterbuch verarbeitet werden. Original, Zwischenstufen und Endtext stehen getrennt in der History.

## 9. Arbeitspaket D – Schreibstilprofile

### D1. Eingebaute Stile

- **Original** – keine AI-Nachbearbeitung,
- **Bereinigt** – Füllwörter und offensichtliche Wiederholungen reduzieren,
- **E-Mail** – lesbare Absätze und höflich-neutraler Stil,
- **Stichpunkte** – kompakte Liste,
- **Formell** – professionelle Sprache,
- **Locker** – natürlicher Chat-Stil.

Jeder eingebaute Stil besitzt:

- stabile ID,
- lokalisierten Anzeigenamen,
- versionierte interne Anweisung,
- Kennzeichnung `isBuiltIn`,
- keine vom Benutzer editierbare Originaldefinition.

### D2. Eigene Stile

- Name maximal 60 Zeichen,
- Anweisung maximal 4.000 Zeichen,
- eingebaute Stile können dupliziert, aber nicht überschrieben werden,
- Löschen eines verwendeten Stils setzt nur die aktuelle Auswahl auf **Original**; alte History-Verweise bleiben lesbar,
- Import/Export als versioniertes JSON,
- Import prüft Größenlimits, IDs und Duplikate.

### D3. Speicherung

- eigene Stile unter Application Support → FlowDictate → SmartDictation → `styles.json`,
- eingebaute Stile kommen aus dem App-Bundle beziehungsweise Code und werden nicht in die Benutzerdatei kopiert,
- atomare Speicherung und kontrollierte Migration.

### Gate D

Alle eingebauten Stile sind stabil auswählbar; eigene Stile lassen sich anlegen, duplizieren, deaktivieren, exportieren, importieren und löschen.

## 10. Arbeitspaket E – AI-Nachbearbeitung

### E1. Schnittstelle

```swift
protocol TranscriptEnhancing: AnyObject {
    func enhance(
        _ request: TranscriptEnhancementRequest
    ) async throws -> TranscriptEnhancementResult
}
```

Der Request enthält ausschließlich:

- Eingabetext,
- Stilanweisung,
- Sprache,
- Modellkennung,
- Request-ID für lokale Zuordnung.

### E2. Provider

- `OpenAITranscriptEnhancer` verwendet den vorhandenen Schlüsselbund-Key.
- Der konkrete API-Endpunkt wird bei der Implementierung anhand der dann aktuellen offiziellen OpenAI-Dokumentation festgelegt.
- Für Transkription und Enhancement bleiben Modellwahl, Logging und Fehlerklassifikation getrennt.
- Es gibt Timeouts, Größenlimits und normalisierte Fehlerkategorien.
- Automatische Retries folgen ausschließlich der konfigurierten Retry-Regel und führen nie zu einer erneuten Audioübertragung.

### E3. Systemanweisung und Schutzregeln

Die Provideranweisung verlangt:

- keine neuen Fakten,
- Erhalt von Namen, Zahlen, URLs und Code,
- Erhalt bereits angewendeter Wörterbuchbegriffe,
- ausschließlich den umgeschriebenen Text als Antwort,
- keine Kommentare, Erklärungen oder Markdown-Einfassung, außer der Stil verlangt Listenstruktur.

### E4. Ergebnisvalidierung

Abgelehnt werden mindestens:

- leere Antworten,
- reine Fehlermeldungen oder Provider-Metatext,
- offensichtlich abgeschnittene Antworten,
- extreme, nicht durch den Stil erklärbare Längenabweichungen,
- Antworten oberhalb des lokalen Textlimits.

Zahlen, URLs und geschützte Wörterbuchersetzungen werden verglichen. Abweichungen erzeugen je nach Schwere einen Fehler oder eine sichtbare Warnung; sie werden nicht still ignoriert.

### E5. Tests

- **Original** ruft den Fake-Provider nie auf,
- jeder andere Stil erhält genau den Text nach Wörterbuchstufe,
- nur erlaubte Request-Felder werden übertragen,
- Erfolg, Timeout, Netzwerkfehler, Rate-Limit, Authentifizierung und ungültige Antwort,
- Retry erhöht nur den Enhancement-Zähler,
- Transkriptionszähler und Audiodatei bleiben beim Enhancement-Retry unverändert,
- Zahlen-/URL-/Wörterbuchschutz,
- Cancel und verspätete Antworten verändern keine abgeschlossene Session.

### Gate E – Abschluss 3.2.2

AI-Schreibstile funktionieren über die abstrahierte Schnittstelle. Providerfehler lassen Original, lokale Zwischenstufen, Audio und History vollständig erhalten.

## 11. Arbeitspaket F – Pipeline und Zustandsintegration

### F1. `SmartDictationPipeline`

Verantwortet:

1. Original unmittelbar nach Transkription speichern,
2. Status `formatting` speichern,
3. lokale Formatierung ausführen und speichern,
4. Wörterbuch anwenden und speichern,
5. bei Stil **Original** direkt `finalText` setzen,
6. andernfalls Status `enhancing` speichern,
7. AI-Ergebnis validieren und speichern,
8. erst danach an die bestehende Einfügung übergeben.

Jeder persistierte Übergang muss nach einem App-Abbruch wiederherstellbar sein.

### F2. Recovery

- Unterbrechung während lokaler Verarbeitung: deterministisch neu ab Original ausführen.
- Unterbrechung während Enhancement: Status `enhancementFailed` mit Kategorie `interrupted`.
- Keine automatische Cloud-Wiederholung beim nächsten App-Start.
- Benutzer entscheidet zwischen Retry, lokalem/Rohtext und History.
- Ein erfolgreich vorhandenes `finalText` wird bei Recovery niemals verworfen.

### F3. Retry und Neuverarbeitung

- **Enhancement erneut versuchen** verwendet `dictionaryTranscript` und denselben Stil.
- **Mit anderem Stil verarbeiten** startet ausschließlich die optionale Stilphase neu.
- **Lokale Regeln neu anwenden** startet ab `originalTranscript` und überschreibt nur abgeleitete Stufen.
- Keine Aktion überschreibt das Original.

### F4. Fallback

Konfigurierbare Optionen:

- bei Enhancement-Fehler anhalten und Auswahl anzeigen – Default,
- automatisch lokal verarbeiteten Text verwenden,
- ausdrücklich Originaltranskript verwenden.

Der ausgewählte Fallback wird in der History nachvollziehbar gespeichert.

### Gate F

Alle Statusübergänge, App-Abbrüche, Retries und Fallbacks sind mit Fake-Providern reproduzierbar getestet.

## 12. Arbeitspaket G – Settings und Verwaltungsoberflächen

### G1. Settings → Smart Dictation

Enthält:

- Aktivierung lokaler Formatierungsbefehle,
- Standard-Schreibstil,
- AI-Nachbearbeitung nur sichtbar beziehungsweise aktiv, wenn ein AI-Stil gewählt ist,
- Enhancement-Modell,
- Retry- und Fallback-Verhalten,
- Links zu **Wörterbuch verwalten** und **Schreibstile verwalten**,
- Testbereich **Original → Final** ohne Audioaufnahme.

### G2. Wörterbuchverwaltung

- durchsuchbare Liste,
- Hinzufügen, Bearbeiten, Aktivieren/Deaktivieren und Löschen,
- Felder für Sprache, Case-Sensitivity und Whole-Word,
- Live-Vorschau einer einzelnen Regel,
- Konflikt- und Duplikatmeldungen,
- Import und Export über `NSSavePanel`/`NSOpenPanel`.

### G3. Stilverwaltung

- Liste eingebauter und eigener Stile,
- eigene Stile anlegen und bearbeiten,
- eingebaute Stile duplizieren,
- Testfeld mit Beispieltext,
- Import/Export,
- Löschbestätigung bei aktuell ausgewähltem Stil.

### G4. UX-Regeln

- UI-Texte bleiben zunächst entsprechend der bestehenden App auf Englisch.
- Buttons benennen die konkrete Aktion.
- Fehler erklären Ursache und nächste sinnvolle Handlung.
- API-Kostenhinweis erscheint bei Aktivierung eines AI-Stils.
- Tastaturbedienung, VoiceOver-Beschriftungen und dynamische Fenstergrößen werden berücksichtigt.

### Gate G

Alle Einstellungen bleiben nach Neustart erhalten; lokale Testverarbeitung und Verwaltung funktionieren ohne Aufnahme.

## 13. Arbeitspaket H – History, Fehleraktionen und Einfügung

### H1. History-Detailansicht

Zeigt getrennt:

- **Original**,
- **Formatted** nur wenn abweichend,
- **Dictionary** nur wenn abweichend,
- **Final**,
- verwendeten Stil,
- Anzahl angewendeter Wörterbuchregeln,
- Provider, Modell, Versuche und Fehlerstatus der Nachbearbeitung.

Inhalte des persönlichen Wörterbuchs werden nicht als Liste in der normalen History dupliziert.

### H2. Aktionen

- Original kopieren,
- finalen Text kopieren,
- Original einfügen,
- finalen Text einfügen,
- Enhancement erneut versuchen,
- mit anderem Stil erneut verarbeiten,
- Audio abspielen und im Finder zeigen wie bisher.

### H3. Fehlerzustand

Nach einem Enhancement-Fehler werden angeboten:

- **Use locally processed text**,
- **Retry enhancement**,
- **Show in History**.

Der normale Recording-Overlay-Controller bleibt nonactivating. Falls Aktionen direkt am Overlay umgesetzt werden, geschieht dies über einen getrennten, erst nach Aufnahmeende aktivierbaren Recovery-Panel-Typ. Alternativ stehen dieselben Aktionen unmittelbar im Menüleisteneintrag bereit. Die finale UX wird im manuellen Test danach entschieden, welches Verhalten den Fokus zuverlässiger erhält.

### H4. Einfügung

- ausschließlich der ausdrücklich gewählte Text wird eingefügt,
- die bestehende FocusTarget- und Clipboard-Wiederherstellung bleibt unverändert,
- Neuverarbeitung fügt nicht automatisch ein, wenn die ursprüngliche Ziel-App nicht mehr verfügbar ist,
- History erlaubt weiterhin Kopieren, selbst wenn Einfügen nicht möglich ist.

### Gate H – Abschluss 3.2.3

Original und Final sind jederzeit unterscheidbar und wiederherstellbar. Ein Enhancement-Fehler kann ohne erneute Transkription und ohne Textverlust behandelt werden.

## 14. Arbeitspaket I – Qualität, Datenschutz und Dokumentation

### I1. Automatisierte Prüfungen

- Unit-Tests für sämtliche lokalen Transformationsregeln,
- Fixture-Tests für History-Migration,
- Fake-Provider-Tests für Pipeline, Retry und Fallback,
- Store-Tests für atomare Persistenz und Import/Export,
- Coordinator-Tests für Einfügung und Fehlerzustände,
- Build für Debug und Release-Konfiguration,
- `git diff --check` und sauberes Arbeitsverzeichnis vor Commit.

### I2. Manuelle Testmatrix

Mindestens:

| Szenario | Erwartung |
|---|---|
| Stil Original | keine zusätzliche AI-Anfrage |
| Formatierung aus, Wörterbuch aus | Final entspricht Original |
| deutsche Formatierungsbefehle | korrekte Satzzeichen und Absätze |
| englische Formatierungsbefehle | korrekte Satzzeichen und Absätze |
| Wörterbuch mit Umlaut und Produktname | korrekte Whole-Word-Ersetzung |
| AI-Stil erfolgreich | Original und Final getrennt gespeichert |
| Netzwerk während Enhancement aus | Text und Audio bleiben erhalten |
| API-Key ungültig | verständlicher Fehler und lokaler Fallback |
| App während Enhancement beenden | kontrollierter Recovery-Status beim Neustart |
| Ziel-App während Enhancement schließen | History bleibt nutzbar, keine falsche Einfügung |
| bestehende Phase-3.1-History öffnen | verlustfreie Migration |
| History-Limit anwenden | geschützte Fehlerdatensätze bleiben erhalten |
| eigener Stil Import/Export | Round Trip ohne API-Key oder History-Daten |

### I3. Datenschutzprüfung

- `PRIVACY.md` um optionale Textnachbearbeitung ergänzen,
- README erklärt lokale und cloudbasierte Schritte getrennt,
- Logs auf mögliche Text-, Stil- und Wörterbuchinhalte prüfen,
- Diagnoseexport enthält nur Status und Zähler, keine Inhalte,
- Community-Build verwendet weiterhin ausschließlich den vom Benutzer hinterlegten API-Key.

### I4. Dokumentation

- README Deutsch und Englisch aktualisieren,
- Phase-3-PRD-Status fortschreiben,
- Import-/Exportformat und Schema-Version dokumentieren,
- manuelle Abnahmeergebnisse im Arbeitsplan festhalten,
- bekannte Einschränkungen aufführen.

### Gate I

Alle automatisierten Prüfungen bestehen, die manuelle Testmatrix ist dokumentiert und Datenschutztexte entsprechen dem tatsächlichen Verhalten.

## 15. Empfohlene Dateistruktur

```text
FlowDictate/
├── SmartDictation/
│   ├── SmartDictationPipeline.swift
│   ├── SmartDictationModels.swift
│   ├── SpokenFormattingProcessor.swift
│   ├── PersonalDictionaryProcessor.swift
│   ├── DictionaryStore.swift
│   ├── WritingStyleStore.swift
│   ├── TranscriptEnhancer.swift
│   ├── OpenAITranscriptEnhancer.swift
│   └── EnhancementResponseValidator.swift
├── Settings/
│   ├── AppSettings.swift
│   ├── SmartDictationSettingsView.swift
│   ├── DictionaryEditorView.swift
│   └── WritingStyleEditorView.swift
├── History/
│   ├── DictationRecord.swift
│   ├── DictationHistoryStore.swift
│   └── HistoryView.swift
└── App/
    └── DictationCoordinator.swift
```

Die genaue Aufteilung darf während der Implementierung angepasst werden, solange Verantwortlichkeiten, Tests und Gates erhalten bleiben.

## 16. Definition of Done

Phase 3.2 ist abgeschlossen, wenn:

1. **Original** keine zusätzliche Cloud-Anfrage auslöst,
2. lokale Formatierung und Wörterbuch in Deutsch und Englisch reproduzierbar funktionieren,
3. alle eingebauten Stile verfügbar sind,
4. eigene Stile sicher verwaltet und importiert/exportiert werden können,
5. Original, Zwischenstufen und Final in der History getrennt bleiben,
6. bestehende History ohne SQLite und ohne Datenverlust migriert wird,
7. Enhancement-Retry keine neue Audio-Transkription startet,
8. Fehler Audio und sämtliche vorhandenen Textstufen erhalten,
9. Rohtext beziehungsweise lokal verarbeiteter Text aus dem Fehlerzustand eingefügt werden kann,
10. normale Diktierung weiterhin Fokus, Clipboard und Ziel-App korrekt behandelt,
11. alle automatisierten Tests und die manuelle Testmatrix bestanden sind,
12. README, Privacy-Dokument und PRD dem implementierten Verhalten entsprechen.

## 17. Reihenfolge der Umsetzung

```text
A  History-Schema und Migration
↓
B  gesprochene Formatierung
↓
C  persönliches Wörterbuch
↓  Gate 3.2.1
D  Schreibstilprofile
↓
E  AI-Nachbearbeitung
↓
F  Pipeline, Recovery und Retry
↓  Gate 3.2.2
G  Settings und Editoren
↓
H  History und Fehleraktionen
↓
I  Qualität, Datenschutz und Abnahme
↓  Gate 3.2.3 / Phase 3.2 abgeschlossen
```

## 18. Hauptrisiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| History-Migration beschädigt vorhandene Daten | Backup, Fixture-Test, atomare Speicherung, keine In-place-Konvertierung ohne erfolgreiche Dekodierung |
| Wörterbuch ersetzt Teilwörter oder erzeugt Kaskaden | Unicode-Wortgrenzen, längste Regel zuerst, nicht-rekursiver Durchlauf, tabellengetriebene Tests |
| Formatierungsbefehle verändern wörtlich gemeinte Wörter | eindeutige Phrasen und Escape-Mechanismus |
| AI erfindet oder entfernt Inhalte | restriktive Anweisung, Ergebnisvalidator, Original immer erhalten, bewusster Fallback |
| zusätzliche API-Kosten überraschen Benutzer | Default Original, Kostenhinweis, AI nur nach bewusster Stilwahl |
| Retry transkribiert Audio erneut | getrennte Enhancement-Schnittstelle und eigener Versuchszähler |
| Fehler-UI stiehlt Fokus | Recording-Overlay nonactivating lassen, Recovery-Aktionen erst nach Aufnahmeende |
| Umfang wächst in Richtung Phase 3.3 | klare Nicht-Ziele und Gates je Teilschritt |

## 19. Startpunkt

> Abschlussvermerk vom 21. August 2026: Die Arbeitspakete A bis I sind umgesetzt, 39 automatisierte Tests bestehen und Aufnahme, Live Preview, Transkription, Smart Dictation sowie Einfügung wurden auf dem Referenz-Mac erfolgreich geprüft.

Die Implementierung beginnt mit Arbeitspaket A. Vor der ersten Codeänderung werden:

1. Fixture-Dateien für das aktuelle History-Schema gesichert,
2. neue Schema-Versionen festgelegt,
3. das gewünschte Backup-Verhalten als Test formuliert,
4. die neuen optionalen `DictationRecord`-Felder mit sicheren Defaults eingeführt.

Erst wenn Gate A erfüllt ist, werden die lokalen Texttransformatoren gebaut.
