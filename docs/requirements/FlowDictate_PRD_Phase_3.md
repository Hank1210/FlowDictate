# Product Requirements Document: FlowDictate Phase 3

**Version:** 3.0 Draft 2
**Datum:** 22. August 2026
**Produkt:** FlowDictate
**Phase:** Phase 3 – Live & Smart Dictation
**Teilphasen:** 3.1 Live Preview, 3.2 Smart Dictation, 3.3 App Integration, Audio Capture & Delivery
**Zielplattform:** macOS 14 oder neuer
**Technologie:** Swift, SwiftUI, AppKit, AVFoundation, ScreenCaptureKit, Speech, Accessibility APIs
**Status:** Phasen 3.1 und 3.2 umgesetzt und auf dem Referenz-Mac manuell abgenommen; Pflichtumfang von Phase 3.3 implementiert, manuelle Systemaudio- und App-Kompatibilitätsabnahme ausstehend.

---

## 1. Zweck dieses Dokuments

Dieses Dokument definiert Phase 3 von FlowDictate so konkret, dass die Umsetzung ohne weitere grundlegende Produktentscheidungen begonnen werden kann.

Phase 3 entwickelt die zuverlässige Standalone-App aus Phase 2 zu einem unmittelbar reagierenden und kontextsensitiven Diktierwerkzeug weiter. Der Benutzer soll bereits während des Sprechens eine Vorschau sehen, das Ergebnis mit nachvollziehbaren Regeln verbessern lassen und FlowDictate je nach Ziel-App unterschiedlich konfigurieren können.

Phase 3 wird in drei unabhängig lieferbare Abschnitte aufgeteilt:

1. **Phase 3.1 – Live Preview & Overlay**
2. **Phase 3.2 – Smart Dictation**
3. **Phase 3.3 – App Integration, Audio Capture & Delivery**

Jede Teilphase muss einzeln testbar und veröffentlichungsfähig sein. Keine Teilphase darf die in Phase 2 erreichte Aufnahme-, Recovery- oder History-Zuverlässigkeit verschlechtern.

---

## 2. Ausgangslage

Phase 2 enthält bereits:

- globale Start-/Stop-, Abbruch- und Restore-Last-Hotkeys,
- sichere lokale WAV-Aufnahme,
- frei wählbaren, dauerhaft autorisierten Aufnahmeordner,
- OpenAI-Dateitranskription nach Aufnahmeende,
- API-Key-Speicherung im macOS-Schlüsselbund,
- persistente History und Recovery,
- manuelle und begrenzte automatische Retries,
- Audio-Wiedergabe und Text-Export,
- nicht aktivierendes Aufnahme-Overlay,
- clipboard-sichere Einfügung,
- konfigurierbare Sprache, Modell und Aufbewahrung,
- Onboarding und Community-Release-Prozess.

### 2.1 Aktuelle Einschränkungen

- Während der Aufnahme ist eine optionale lokale Live Preview verfügbar.
- Das OpenAI-Ergebnis entsteht erst nach dem Stoppen der Aufnahme.
- Rohtranskript und verarbeitete Textstufen werden getrennt gespeichert.
- Schreibstile, gesprochene Formatierungsbefehle und persönliche Ersetzungen sind in Phase 3.2 umgesetzt.
- Einstellungen gelten global und nicht abhängig von der Ziel-App.
- Texte werden primär über die Zwischenablage eingefügt.
- Es gibt keinen gedrückt-halten-Modus und keine fortlaufende Diktierkette.
- Es gibt keine lokale Nutzungsstatistik und keinen Hinweis auf neue GitHub-Releases.

---

## 3. Produktziel

Phase 3 macht FlowDictate während des Sprechens sichtbar, nach dem Sprechen intelligent und beim Einfügen kontextsensitiv.

### 3.1 Leitsatz

> Der Benutzer sieht sofort, was FlowDictate versteht, behält jederzeit Zugriff auf das unveränderte Rohtranskript und kontrolliert jede optionale Textverarbeitung.

### 3.2 Exit-Kriterium der Gesamtphase

Phase 3 ist abgeschlossen, wenn:

1. unterstützte Macs während der Aufnahme eine flüssige, abschaltbare Live-Vorschau anzeigen,
2. ein Ausfall der Vorschau niemals Aufnahme oder finale Transkription verhindert,
3. Rohtranskript, deterministisch formatierter Text und finaler Text nachvollziehbar getrennt bleiben,
4. Schreibstile, Wörterbuch und gesprochene Formatierung produktiv nutzbar sind,
5. Ziel-Apps eigene Profile erhalten können,
6. direkte Accessibility-Einfügung mit sicherem Clipboard-Fallback verfügbar ist,
7. lokale Statistik und Release-Hinweise ohne Telemetrie funktionieren und
8. sämtliche Phase-2-Recovery- und Datenschutzgarantien weiterhin gelten.

---

## 4. Zielgruppen

### 4.1 Primär

- bestehende FlowDictate-Benutzer mit täglicher Nutzung,
- deutsch-, englisch- und gemischtsprachige Diktate,
- Benutzer, die unmittelbares visuelles Feedback erwarten,
- Benutzer, die unterschiedliche Texte für Mail, Chat, Dokumente und Entwicklungsumgebungen schreiben.

### 4.2 Sekundär

- Community-Nutzer ohne Entwicklerkenntnisse,
- Nutzer mit eigenem OpenAI-API-Key,
- Nutzer, die lokale Vorschau und kontrollierbare Cloud-Verarbeitung kombinieren möchten.

### 4.3 Nicht Bestandteil von Phase 3

- vollständig lokale Whisper-, Parakeet- oder andere große Modellpakete,
- automatische Meeting-Aufzeichnung, Sprechertrennung und Gesprächsanalyse,
- autonomer Command Mode für Systemaktionen,
- allgemeiner Agent oder Workflow-Automation,
- Cloud-Synchronisierung,
- Benutzerkonten oder Abonnements,
- zentrale Telemetrie,
- stilles automatisches Installieren von Updates,
- mobile oder Windows-Versionen.

Diese Themen können für Phase 4 bewertet werden.

---

## 5. Produktprinzipien

### 5.1 Final bleibt final

Eine Live-Vorschau ist vorläufig. Nur der abgeschlossene Transkriptions- und Verarbeitungsprozess erzeugt `finalText` und darf Text in die Ziel-App einfügen.

### 5.2 Preview darf Aufnahme nie gefährden

Preview-Verarbeitung ist nachrangig. Bei CPU-, Speicher-, Berechtigungs- oder Provider-Problemen werden Preview-Daten verworfen, niemals Aufnahmeblöcke oder die lokale Audiodatei.

### 5.3 Rohdaten bleiben erhalten

`originalTranscript` wird durch Wörterbuch, Formatierung, Schreibstil oder App-Profil niemals überschrieben. Jede Transformation erzeugt eine neue nachvollziehbare Stufe.

### 5.4 Local First und explizites Opt-in

- Die empfohlene Live-Vorschau läuft lokal.
- Cloud-Nachbearbeitung ist optional und sichtbar.
- Neue Datennutzung wird erklärt, bevor sie aktiviert wird.
- Keine Audio-, Text- oder Nutzungsdaten werden an FlowDictate-Entwickler übertragen.

### 5.5 Sichere Degradierung

Jede neue Funktion besitzt einen funktionierenden Fallback:

- keine Live-Vorschau → normale Phase-2-Aufnahme,
- Enhancement fehlgeschlagen → Rohtranskript verwenden oder Benutzer entscheiden lassen,
- direkte Einfügung nicht möglich → Clipboard/Paste,
- Profil ungültig → globale Standardkonfiguration,
- Systemaudio nicht verfügbar → Aufnahme nicht starten, Ursache anzeigen und Mikrofonmodus weiterhin anbieten; kein stiller Quellenwechsel,
- Update-Prüfung nicht erreichbar → App arbeitet unverändert weiter.

---

## 6. Gesamtarchitektur

### 6.1 Zielpipeline

```text
Gewählte Audioquelle
   ├── Mikrofon
   ├── Systemaudio
   └── Mikrofon + Systemaudio (Soll-Umfang 3.3)
                ↓
       sichere lokale Audiodatei ───────────→ finale Transkription
                │                                    ↓
                └──→ lokaler Preview-Stream     originalTranscript
                             ↓                         ↓
                          Overlay              gesprochene Formatierung
                                                       ↓
                                              persönliches Wörterbuch
                                                       ↓
                                            optionale AI-Nachbearbeitung
                                                       ↓
                                                   finalText
                                                       ↓
                                       direkte Einfügung oder Clipboard
```

### 6.2 Komponenten

Neue oder erweiterte Verantwortlichkeiten:

| Komponente | Verantwortung |
|---|---|
| `MicrophoneRecorder` | Audiodatei schreiben, Pegel liefern und kopierte Preview-Buffer publizieren |
| `SystemAudioRecorder` | digitalen macOS-Ausgabemix über ScreenCaptureKit ohne Videopersistenz erfassen |
| `AudioSourceCoordinator` | Aufnahmequelle auswählen, Berechtigungen prüfen und ein einheitliches Recording-Ergebnis liefern |
| `AudioMixer` | Mikrofon und Systemaudio im optionalen Mischmodus resamplen, synchronisieren und begrenzen |
| `LivePreviewProvider` | Audiobuffer in vorläufige Textereignisse umwandeln |
| `AppleSpeechLivePreviewProvider` | lokale Apple-Speech-Implementierung für Phase 3.1 |
| `LivePreviewCoordinator` | Session-Lebenszyklus, Backpressure, Fehler und UI-Updates |
| `RecordingOverlayController` | Status, Pegel und vorläufigen Text ohne Fokuswechsel anzeigen |
| `TranscriptProcessingPipeline` | deterministische und optionale AI-Verarbeitung ausführen |
| `PersonalDictionaryStore` | versionierte lokale Wörterbucheinträge speichern |
| `WritingStyleStore` | eingebaute und benutzerdefinierte Schreibstile verwalten |
| `AppProfileStore` | Bundle-ID auf Diktierkonfiguration abbilden |
| `AccessibilityTextInserter` | direkte Einfügung versuchen |
| `CompositeTextInserter` | direkte Einfügung und Clipboard-Fallback koordinieren |
| `UsageStatisticsService` | lokale Kennzahlen aus History ableiten |
| `ReleaseUpdateChecker` | GitHub-Releases prüfen und Downloadseite öffnen |

### 6.3 Provider-Trennung

Live-Vorschau und finale Transkription verwenden getrennte Protokolle. Dadurch bleibt die bestehende dateibasierte OpenAI-Transkription unverändert nutzbar.

```swift
protocol LivePreviewProviding: AnyObject {
    var isAvailable: Bool { get }
    func start(configuration: LivePreviewConfiguration) async throws
    func append(_ buffer: AVAudioPCMBuffer)
    func finish() async
    func cancel() async
}

enum LivePreviewEvent: Sendable, Equatable {
    case provisional(String)
    case finalizedSegment(String)
    case unavailable(String)
    case failed(String)
}
```

Vorgaben:

- `append` blockiert niemals den Audio-Thread.
- Audiobuffer werden vor Übergabe kopiert oder in eine sichere unveränderliche Darstellung konvertiert.
- Preview besitzt eine begrenzte Queue.
- Bei Überlast werden Preview-Buffer verworfen; Aufnahmebuffer werden niemals verworfen.
- Pro Diktat existiert höchstens eine Preview-Session.
- `finish` und `cancel` sind idempotent.

---

# Teilphase 3.1 – Live Preview & Overlay

## 7. Ziel von Phase 3.1

Der Benutzer sieht während des Sprechens einen vorläufigen Text im bestehenden Overlay. Die Funktion arbeitet lokal, ist abschaltbar und hat keinen Einfluss auf die sichere Aufnahme oder die finale OpenAI-Transkription.

### 7.1 Muss-Funktionen

- lokale Live-Vorschau über Apple Speech,
- partielle Textergebnisse während der Aufnahme,
- klar als vorläufig erkennbare Anzeige,
- Preview ein-/ausschalten,
- Overlay-Größe auswählen,
- maximale Vorschauzeichen konfigurieren,
- stabile Darstellung der letzten Textzeichen,
- eigener Berechtigungsstatus für Spracherkennung,
- zuverlässiger Fallback ohne Preview,
- vollständige Session-Bereinigung bei Stop, Abbruch und Fehler.

### 7.2 Soll-Funktionen

- Position unten oder nahe der Menüleiste,
- automatische Wahl des Bildschirms mit Maus oder Ziel-App,
- reduzierte Animation bei aktivierter macOS-Einstellung „Bewegung reduzieren“,
- kurze Statusanzeige, wenn lokale Preview für Sprache oder Gerät nicht verfügbar ist.

## 8. Apple-Speech-Preview

### 8.1 Konfiguration

Die erste Implementierung verwendet:

- `SFSpeechRecognizer`,
- `SFSpeechAudioBufferRecognitionRequest`,
- `shouldReportPartialResults = true`,
- standardmäßig `requiresOnDeviceRecognition = true`,
- die in FlowDictate ausgewählte Sprache beziehungsweise passende Locale.

Die Implementierung prüft vor Start:

1. Speech-Recognition-Berechtigung,
2. Verfügbarkeit des Recognizers,
3. Unterstützung der Locale,
4. Unterstützung lokaler Erkennung.

Wenn lokale Erkennung nicht unterstützt wird, bleibt die Vorschau deaktiviert. Phase 3.1 darf nicht still auf Apple-Cloud-Erkennung wechseln.

### 8.2 Berechtigung

Onboarding und **Settings → General/Permissions** erhalten einen Eintrag **Speech Recognition**.

Die Erklärung muss unterscheiden:

- Mikrofon: Aufnahme des Audios,
- Speech Recognition: lokale vorläufige Textanzeige,
- Accessibility: Einfügen in andere Apps.

Eine verweigerte Speech-Berechtigung blockiert keine Diktierung.

### 8.3 Vorläufiger und finaler Text

- Preview-Text wird nur im Arbeitsspeicher gehalten.
- Preview-Text wird nicht in History, Logs oder Diagnosepakete geschrieben.
- Preview-Text wird nie automatisch in die Ziel-App eingefügt.
- Nach Aufnahmeende zeigt das Overlay den Status **Finalisiere…**.
- Das finale OpenAI-Ergebnis ersetzt die Vorschau vollständig.
- Abweichungen zwischen Preview und finalem Text gelten als erwartetes Verhalten.

## 9. Overlay UX

### 9.1 Zustände

```text
idle
recordingWithoutPreview
recordingWaitingForPreview
recordingWithPreview
finalizing
enhancing (ab Phase 3.2)
inserting
success
error
```

### 9.2 Größen

| Größe | Inhalt |
|---|---|
| `compact` | Statuspunkt, Pegel/Waveform, höchstens eine Textzeile |
| `standard` | Pegel/Waveform und zwei bis vier Textzeilen |
| `expanded` | scrollbare Textvorschau mit größerer Höhe |

Default: `standard`.

### 9.3 Textdarstellung

- Default-Limit: 150 Zeichen,
- erlaubter Bereich: 50 bis 800 Zeichen,
- nur das Ende des Textes bleibt sichtbar,
- Änderungen werden maximal zehnmal pro Sekunde an das UI geliefert,
- keine Animation pro Zeichen,
- keine horizontalen Scrollbalken,
- Expanded-Modus scrollt bei neuem Text automatisch nach unten,
- Overlay bleibt `nonactivating` und übernimmt niemals Tastaturfokus.

### 9.4 Einstellungen

Unter **Settings → Dictation → Live Preview**:

- **Live Preview anzeigen** – standardmäßig aktiv, wenn lokale Erkennung verfügbar ist,
- Status und verfügbare Sprache,
- Overlay-Größe,
- Vorschauzeichen,
- Overlay-Position,
- Aktion **Preview testen**.

## 10. Performance und Zuverlässigkeit 3.1

- Zielzeit bis zum ersten sichtbaren Text: höchstens 2 Sekunden bei unterstützter lokaler Erkennung.
- Audioaufnahme darf durch Preview keine Dropouts erhalten.
- Preview-Queue hält höchstens eine kurze, definierte Audiomenge.
- Bei wachsender Queue wird der älteste nicht benötigte Preview-Buffer verworfen.
- UI-Aktualisierungen werden gedrosselt und auf dem Main Actor ausgeführt.
- Stop wartet begrenzt auf Preview-Cleanup, aber nicht auf ein Preview-Endergebnis.
- Abbruch beendet Preview sofort und sendet das Audio weiterhin nicht an OpenAI.
- App-Schließen oder Mikrofonwechsel hinterlässt keine aktive Recognition-Task.

## 11. Abnahmekriterien 3.1

Phase 3.1 ist abgeschlossen, wenn:

1. Preview bei deutscher und englischer Sprache sichtbar aktualisiert wird,
2. der erste Text unter normalen Bedingungen innerhalb von zwei Sekunden erscheint,
3. Stop und Abbruch jede Preview-Session zuverlässig beenden,
4. finale OpenAI-Transkription und Einfügung unverändert funktionieren,
5. Preview-Ausfall die Aufnahme nicht beendet,
6. deaktivierte Preview keine Speech-Berechtigung benötigt,
7. Preview-Text nicht persistent gespeichert oder geloggt wird,
8. Compact-, Standard- und Expanded-Overlay ohne Fokusverlust funktionieren,
9. Tests Überlast, schnellen Start/Stop und fehlende Berechtigung abdecken.

---

# Teilphase 3.2 – Smart Dictation

## 12. Ziel von Phase 3.2

Nach der finalen Transkription kann FlowDictate den Text mit transparenten, kontrollierbaren Regeln verbessern. Benutzer erhalten Schreibstile, ein persönliches Wörterbuch und gesprochene Formatierungsbefehle, ohne das Rohtranskript zu verlieren.

### 12.1 Muss-Funktionen

- getrennte Verarbeitungsstufen,
- eingebaute Schreibstile,
- benutzerdefinierte Schreibstile,
- persönliches Wörterbuch,
- gesprochene Formatierung für Deutsch und Englisch,
- Vorschau von Rohtext und finalem Text in History,
- Enhancement-Fallback bei Providerfehlern,
- Retry nur für die Nachbearbeitung,
- migrationsfähige History-Felder.

### 12.2 Eingebaute Schreibstile

- **Original** – keine AI-Nachbearbeitung,
- **Bereinigt** – Füllwörter und offensichtliche Wiederholungen reduzieren, Inhalt erhalten,
- **E-Mail** – lesbare Absätze und höflicher neutraler Stil,
- **Stichpunkte** – Inhalt als kompakte Liste strukturieren,
- **Formell** – professionelle Sprache ohne neue Fakten,
- **Locker** – natürlicher Chat-Stil ohne neue Fakten.

Default bleibt **Original**, bis der Benutzer bewusst einen anderen Stil auswählt.

### 12.3 Benutzerdefinierte Stile

```swift
struct WritingStyleProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instruction: String
    var isBuiltIn: Bool
    var isEnabled: Bool
    var schemaVersion: Int
}
```

Regeln:

- Name maximal 60 Zeichen,
- Anweisung maximal 4.000 Zeichen,
- keine geheimen Schlüssel in Profilen,
- eingebaute Profile nicht überschreiben; nur duplizieren,
- Löschung eines verwendeten Profils setzt betroffene Bindungen auf **Original** zurück,
- Import und Export enthalten keine API-Zugangsdaten.

## 13. Verarbeitungsreihenfolge

```text
originalTranscript
    ↓ gesprochene Formatierungsregeln
formattedTranscript
    ↓ persönliches Wörterbuch
dictionaryTranscript
    ↓ optionaler Schreibstil / AI Enhancement
finalText
```

Jede Stufe ist deterministisch wiederholbar, außer der optionalen AI-Nachbearbeitung. `originalTranscript` bleibt unveränderlich.

### 13.1 History-Datenmodell

`DictationRecord` erhält:

| Feld | Typ | Beschreibung |
|---|---|---|
| `formattedTranscript` | String? | Ergebnis gesprochener Formatierung |
| `dictionaryTranscript` | String? | Ergebnis persönlicher Ersetzungen |
| `writingStyleID` | UUID? | verwendeter Schreibstil |
| `processingStatus` | Enum | Status der Nachbearbeitung |
| `enhancementProviderID` | String? | verwendeter Provider |
| `enhancementModelID` | String? | verwendetes Modell |
| `enhancementAttemptCount` | Int | Anzahl Versuche |
| `enhancementErrorCategory` | Enum? | normalisierte Fehlerklasse |

Neue Statusfolge:

```text
transcribed
   ↓
formatting
   ↓
formatted
   ↓ optional
enhancing ─────────→ enhancementFailed
   ↓                       │
enhanced                   ├── Rohtext verwenden
   ↓                       └── Retry
inserting
```

## 14. Persönliches Wörterbuch

### 14.1 Datenmodell

```swift
struct DictionaryEntry: Codable, Identifiable, Equatable {
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

### 14.2 Regeln

- leere Werte sind unzulässig,
- exakte doppelte Regeln werden verhindert,
- längere Treffer werden vor kürzeren angewendet,
- Whole-Word-Matching ist Standard,
- Ersetzungen laufen lokal,
- Vorschau zeigt das Ergebnis vor dem Speichern einer Regel,
- Konflikte werden angezeigt,
- Import/Export als versioniertes JSON,
- Wörterbucheinträge werden weder geloggt noch an FlowDictate übertragen.

## 15. Gesprochene Formatierung

Vordefinierte Befehle für Deutsch und Englisch:

| Gesprochen | Ausgabe/Aktion |
|---|---|
| „Punkt“ / “period” | `.` plus passendes Leerzeichen |
| „Komma“ / “comma” | `,` plus passendes Leerzeichen |
| „Fragezeichen“ / “question mark” | `?` |
| „Ausrufezeichen“ / “exclamation mark” | `!` |
| „Neue Zeile“ / “new line” | einfacher Zeilenumbruch |
| „Neuer Absatz“ / “new paragraph” | doppelter Zeilenumbruch |
| „Aufzählung“ / “bullet point” | neue Listenzeile |
| „Klammer auf/zu“ / “open/close parenthesis” | `(` beziehungsweise `)` |

Regeln:

- Funktion ist separat aktivierbar,
- Befehle werden nur bei eindeutiger Phrase ersetzt,
- Escape-Mechanismus für wörtliche Verwendung, beispielsweise „wörtlich Punkt“,
- keine Interpretation komplexer Befehle oder Systemaktionen,
- Transformation ist in der History nachvollziehbar.

## 16. AI-Nachbearbeitung

### 16.1 Abstraktion

```swift
protocol TranscriptEnhancing {
    func enhance(_ request: TranscriptEnhancementRequest) async throws -> TranscriptEnhancementResult
}
```

Request enthält nur:

- zu verarbeitenden Text,
- Schreibstilanweisung,
- Sprache,
- optional Ziel-App-Kategorie ab Phase 3.3,
- keine Audiodatei,
- keinen Fenstertitel,
- keinen Clipboard-Inhalt.

### 16.2 Sicherheitsregeln für Prompts

- Inhalt darf nicht erweitert oder erfunden werden.
- Zahlen, Namen, URLs und Code sollen erhalten bleiben.
- Der Provider erhält die klare Anweisung, ausschließlich den umgeschriebenen Text zurückzugeben.
- Leere oder unverhältnismäßig lange Antworten werden abgelehnt.
- Eine maximale Längenabweichung wird plausibilisiert, jedoch nicht pauschal erzwungen.
- Wörterbuchersetzungen dürfen nicht rückgängig gemacht werden.

### 16.3 Fehlerverhalten

Default bei Enhancement-Fehler:

- Audio und sämtliche Textstufen bleiben gespeichert,
- keine automatische wiederholte Cloud-Anfrage außerhalb der konfigurierten Retry-Regeln,
- Overlay bietet **Rohtext einfügen**, **Erneut versuchen** und **In History anzeigen**,
- optional kann der Benutzer global **Bei Fehler automatisch Rohtext verwenden** aktivieren.

## 17. UX und Einstellungen 3.2

Unter **Settings → Smart Dictation**:

- Standard-Schreibstil,
- Liste eigener Stile,
- Wörterbuch verwalten,
- gesprochene Formatierung,
- AI-Nachbearbeitung aktivieren,
- Enhancement-Modell,
- Fallback-Verhalten,
- Testfeld mit Vergleich **Original → Final**.

History-Detailansicht:

- Tabs oder klar getrennte Bereiche **Original** und **Final**,
- verwendeter Stil,
- verwendete Wörterbuchregeln nur als Anzahl, nicht in normalen Logs,
- Aktion **Mit anderem Stil erneut verarbeiten**,
- erneute Verarbeitung überschreibt nie das Original.

## 18. Abnahmekriterien 3.2

Phase 3.2 ist abgeschlossen, wenn:

1. alle eingebauten Stile reproduzierbar auswählbar sind,
2. **Original** keinerlei Cloud-Nachbearbeitung auslöst,
3. Wörterbuch und Formatierungsbefehle offline funktionieren,
4. Original- und Finaltext in History getrennt bleiben,
5. Enhancement-Fehler kein Audio und keinen Text verlieren,
6. Rohtext aus dem Fehlerzustand eingefügt werden kann,
7. eigene Stile angelegt, dupliziert, exportiert und gelöscht werden können,
8. Migration bestehender Phase-2-Datensätze ohne Datenverlust funktioniert,
9. Tests Reihenfolge, Wortgrenzen, Konflikte, Retry und Fallback abdecken.

Die manuelle Abschlussprüfung auf dem Referenz-Mac wurde am 21. August 2026 erfolgreich durchgeführt. Geräteübergreifende Community-Installationstests bleiben Bestandteil des jeweiligen Release-Prozesses.

---

# Teilphase 3.3 – App Integration, Audio Capture & Delivery

## 19. Ziel von Phase 3.3

FlowDictate passt sich an die aktive Ziel-App an, kann wahlweise Mikrofon- oder digitales Systemaudio erfassen, fügt Text möglichst ohne Clipboard-Eingriff ein und bietet produktive Bedienmodi sowie lokale Nutzungs- und Updateinformationen.

### 19.1 Muss-Funktionen

- App-spezifische Profile,
- Audio Source Capture mit den Modi **Mikrofon** und **Systemaudio**,
- direkte Accessibility-Einfügung mit Clipboard-Fallback,
- gedrückt-halten-Modus,
- lokale Nutzungsstatistik,
- GitHub-Release-Hinweis,
- vollständige Einstellungs- und Datenmigration.

### 19.2 Soll-Funktionen

- fortlaufende Diktierkette,
- kombinierte Aufnahme **Mikrofon + Systemaudio**,
- Bulk-Export von History und Audio,
- Profilimport/-export,
- manuelle Kompatibilitätsausnahme für problematische Apps.

### 19.3 Audio Source Capture

#### 19.3.1 Ziel und Begriffe

Systemaudio bezeichnet den digitalen Ton, den macOS an die aktuell gewählte Ausgabe übergibt. Die Erfassung erfolgt vor Lautsprecher oder Kopfhörer und ist keine erneute Aufnahme über das Mikrofon. FlowDictate speichert bei reiner Systemaudioaufnahme kein Bildschirmbild und keine Videodatei.

#### 19.3.2 Pflichtmodi

Unter **Settings → Audio → Recording source** stehen mindestens zur Verfügung:

1. **Microphone** – bestehendes Verhalten und sicherer Standardwert,
2. **System Audio** – digitaler macOS-Ausgabemix ohne Mikrofonsignal.

Die gewählte Quelle wird lokal gespeichert und beim Start der Aufnahme im Overlay eindeutig angezeigt. Ein Quellenwechsel während einer laufenden Aufnahme ist nicht erlaubt.

#### 19.3.3 Optionaler Mischmodus

**Microphone + System Audio** ist Soll-Umfang. Er darf erst veröffentlicht werden, wenn:

- beide Quellen über monotone Zeitstempel synchronisiert werden,
- abweichende Sample-Raten außerhalb der Echtzeit-Callbacks konvertiert werden,
- Pegelbegrenzung Clipping verhindert,
- Ausfall einer Quelle die bereits gespeicherte Aufnahme nicht beschädigt,
- die eigene Audioausgabe von FlowDictate ausgeschlossen wird,
- lange Aufnahmen keinen unbegrenzten Speicherverbrauch verursachen.

Ist der Mischmodus für 3.3 nicht releasefähig, bleiben Mikrofon und Systemaudio als getrennte Pflichtmodi vollständig nutzbar.

#### 19.3.4 macOS-Integration

- Implementierung über Apples `ScreenCaptureKit` für den Systemaudio-Stream.
- `SCStream` liefert ausschließlich Audio an FlowDictate; Video-Outputs werden weder registriert noch gespeichert.
- `SCStreamConfiguration.capturesAudio` ist aktiviert.
- FlowDictates eigene Prozessausgabe wird nach Möglichkeit über `excludesCurrentProcessAudio` ausgeschlossen.
- Sample-Rate und Kanalzahl werden auf ein von der bestehenden Dateipipeline unterstütztes Format normalisiert.
- Die bestehende Transkriptions-, History-, Retry-, Recovery- und Retention-Pipeline wird wiederverwendet.
- Geschützte oder von macOS nicht bereitgestellte Inhalte werden nicht umgangen.

#### 19.3.5 Berechtigungen und Onboarding

- Mikrofonmodus benötigt weiterhin Mikrofon- und für die Einfügung Accessibility-Berechtigung.
- Systemaudio benötigt die macOS-Freigabe für Bildschirm- und Systemaudioaufnahme sowie für die spätere Einfügung Accessibility.
- FlowDictate fordert die zusätzliche Freigabe erst an, wenn der Benutzer **System Audio** oder den Mischmodus auswählt beziehungsweise testet.
- Ein eigener **Test System Audio for 5 Seconds…**-Ablauf prüft Quelle, Pegel und Dateierzeugung, sendet nichts an OpenAI, erzeugt keinen History-Eintrag und löscht die Testdatei.
- Bei verweigerter oder entzogener Freigabe bleibt der Mikrofonmodus unverändert nutzbar.
- FlowDictate wechselt niemals still von Systemaudio auf Mikrofon oder umgekehrt.

#### 19.3.6 Oberfläche und Status

- Overlay und Menü zeigen **Microphone**, **System Audio** oder **Mixed** als aktive Quelle.
- Ein eindeutiger Aufnahmeindikator bleibt während der gesamten Erfassung sichtbar.
- Für Systemaudio wird ein eigener Pegel dargestellt; im Mischmodus sind beide Quellen unterscheidbar.
- History zeigt die verwendete Quelle, ohne Namen abgespielter Apps, Fenster oder Medien zu speichern.
- Vor der ersten Systemaudioaufnahme erklärt FlowDictate, dass auch Töne anderer Apps erfasst werden können und erforderliche Einwilligungen beim Benutzer liegen.

#### 19.3.7 Datenmodell

```swift
enum RecordingAudioSource: String, Codable, Sendable {
    case microphone
    case systemAudio
    case mixed
}

struct AudioSourceMetadata: Codable, Sendable, Equatable {
    var source: RecordingAudioSource
    var sampleRate: Double
    var channelCount: Int
}
```

`DictationRecord` erhält `audioSource` mit dem migrationssicheren Default `.microphone`. Es werden keine Namen der Anwendungen persistiert, deren Ton im Systemaudio enthalten war.

#### 19.3.8 Live Preview

- Im Mikrofonmodus bleibt das Verhalten aus 3.1 unverändert.
- Im Systemaudiomodus darf der normalisierte Audiostream für die lokale Preview verwendet werden.
- Im Mischmodus verwendet die Preview zunächst nur eine klar definierte Quelle; der Benutzer sieht, welche. Die finale Transkription verarbeitet die gespeicherte Mischdatei.
- Ein Preview-Fehler gefährdet auch bei Systemaudio niemals Aufnahme oder finale Transkription.

## 20. App-spezifische Profile

### 20.1 Datenmodell

```swift
struct AppDictationProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleIdentifier: String
    var displayName: String
    var writingStyleID: UUID?
    var language: TranscriptionLanguage?
    var transcriptionModel: String?
    var spokenFormattingEnabled: Bool?
    var insertionPreference: InsertionPreference
    var isEnabled: Bool
}
```

`nil` bedeutet, dass der globale Wert geerbt wird.

### 20.2 Zuordnung

- Ziel-App wird beim Start der Diktierung eingefroren.
- Zuordnung erfolgt ausschließlich über Bundle-ID.
- Fenstertitel, Dokumentname und Textfeldinhalt werden nicht gespeichert.
- Das aktive Profil wird im Overlay optional als kurzer Name angezeigt.
- Fehlt oder verschwindet ein Profil, gelten globale Einstellungen.
- FlowDictate selbst kann kein Zielprofil sein.

### 20.3 Profilverwaltung

Unter **Settings → App Profiles**:

- zuletzt verwendete Apps anzeigen,
- Profil hinzufügen,
- globale Werte erben oder überschreiben,
- Profil duplizieren,
- Profil deaktivieren/löschen,
- effektive Konfiguration zusammenfassen.

## 21. Direkte Accessibility-Einfügung

### 21.1 Strategiereihenfolge

```text
Accessibility Direct Insert
        ↓ falls nicht unterstützt/fehlgeschlagen
Clipboard Paste mit sicherer Wiederherstellung
        ↓ falls fehlgeschlagen
Text im Clipboard belassen und Benutzer informieren
```

### 21.2 Anforderungen

- fokussiertes Accessibility-Element beim Einfügen neu auflösen,
- editierbare Textrollen erkennen,
- vorhandene Auswahl korrekt ersetzen,
- Cursorposition erhalten beziehungsweise erwartbar verschieben,
- sichere Größenbegrenzung für direkte AX-Werte,
- Passwortfelder und geschützte Eingaben ablehnen,
- pro Bundle-ID eine Kompatibilitätsausnahme speichern können,
- niemals Textfeldinhalte loggen,
- bei unklarem Ergebnis nicht automatisch doppelt einfügen.

### 21.3 Ziel-App-Testmatrix

Mindestens manuell testen:

- Apple Notes,
- Mail,
- Safari,
- Chrome,
- TextEdit,
- Microsoft Word oder gleichwertige Textverarbeitung,
- Visual Studio Code,
- Xcode,
- Slack oder vergleichbare Chat-App.

Für jede App dokumentieren:

- direkte Einfügung möglich,
- Auswahlersetzung korrekt,
- mehrzeiliger Text korrekt,
- Emoji und Sonderzeichen korrekt,
- Fallback korrekt,
- Fokus nach Einfügung korrekt.

## 22. Hotkey-Modi

### 22.1 Toggle

Bestehendes Verhalten:

- einmal drücken startet,
- erneut drücken stoppt und verarbeitet.

### 22.2 Press and Hold

- Hotkey drücken und halten startet,
- Loslassen stoppt und verarbeitet,
- Mindesthaltedauer schützt vor versehentlichem Auslösen,
- Escape oder Abbruch-Hotkey verwirft die Diktierung nach bestehenden Regeln,
- Tastaturwiederholung darf keine zweite Session starten.

Der Modus ist global auswählbar. App-Profile überschreiben ihn in Phase 3 nicht.

### 22.3 Fortlaufendes Diktieren

Optionaler Soll-Umfang:

- mehrere Diktate innerhalb eines kurzen Zeitfensters als Schreibkette behandeln,
- zwischen erfolgreichen Einfügungen automatisch ein konfigurierbares Leerzeichen oder einen Zeilenumbruch ergänzen,
- Großschreibung am Kettenanfang berücksichtigen,
- jedes Diktat bleibt ein eigener History-Datensatz,
- Restore Last betrifft weiterhin nur den letzten finalen Text.

## 23. Lokale Statistik

### 23.1 Kennzahlen

- Diktierzeit heute, diese Woche und insgesamt,
- Anzahl erfolgreicher Diktate,
- Anzahl Wörter und Zeichen,
- durchschnittliche Diktatlänge,
- Erfolgs- und Retry-Anzahl,
- geschätzte eingesparte Tippzeit.

Geschätzte Zeitersparnis:

```text
Tippzeit = Wortanzahl / konfigurierte persönliche Tippgeschwindigkeit
Zeitersparnis = max(0, Tippzeit - Diktierdauer)
```

Default-Tippgeschwindigkeit: 40 Wörter pro Minute, änderbar.

### 23.2 Datenschutz

- Statistik wird ausschließlich aus lokaler History berechnet.
- Keine Telemetrie und kein Analytics-SDK.
- Keine Ranglisten, Konten oder Cloud-Profile.
- Löschen der History aktualisiert die Statistik nachvollziehbar.
- Statistik kann vollständig ausgeblendet werden.

## 24. GitHub-Release-Hinweis

### 24.1 Umfang

Die Community-App darf prüfen, ob auf `Hank1210/FlowDictate` eine neuere stabile Version veröffentlicht wurde.

Verhalten:

- Prüfung beim manuellen Klick und höchstens einmal täglich automatisch,
- Vergleich semantischer Versionen,
- Beta-/Prerelease-Versionen standardmäßig ignorieren,
- Anzeige von Version, Kurzbeschreibung und Link,
- Aktion **Release-Seite öffnen**,
- Aktion **Später erinnern**,
- kein stiller Download und keine automatische Installation.

### 24.2 Begründung

Die kostenlose Community-App ist ad-hoc signiert und nicht notarisiert. Ein Update kann deshalb erneute macOS-Freigaben für Accessibility, Mikrofon oder Schlüsselbund erfordern. Phase 3.3 informiert über Updates, ersetzt aber nicht bewusst die Installationsentscheidung des Benutzers.

### 24.3 Datenschutz und Fehler

- Request enthält nur die technisch notwendigen GitHub-HTTP-Daten.
- Kein API-Key für öffentliche Release-Abfragen erforderlich.
- Fehler bleiben unaufdringlich und blockieren die App nicht.
- Die Prüfung kann deaktiviert werden.

## 25. Bulk-Export

Soll-Umfang:

- Auswahl mehrerer History-Einträge,
- ZIP mit `manifest.json`, Textdateien und optional vorhandenen Audiodateien,
- Fortschritt und Abbruch,
- fehlende Audiodateien im Manifest markieren,
- keine API-Keys, Bookmarks, Logs oder App-Einstellungen exportieren,
- Exportziel über macOS-Systemdialog auswählen.

## 26. Abnahmekriterien 3.3

Phase 3.3 ist abgeschlossen, wenn:

1. Mikrofon und Systemaudio getrennt auswählbar sind und jeweils eine transkribierbare lokale Audiodatei erzeugen,
2. ohne Systemaudiofreigabe keine versteckte oder leere Aufnahme beginnt und Mikrofon weiterhin nutzbar bleibt,
3. eine Systemaudioaufnahme keinerlei Video- oder Bildschirminhalt persistiert,
4. Quelle, Pegel und Aufnahmestatus in Overlay und History eindeutig erkennbar sind,
5. der fünfsekündige Systemaudio-Test nichts an OpenAI sendet und keine dauerhaften Testdaten hinterlässt,
6. mindestens zwei Ziel-Apps unterschiedliche Profile zuverlässig anwenden,
7. Bundle-ID statt Fenstertitel für Profile verwendet wird,
8. direkte Einfügung und Clipboard-Fallback in der Testmatrix dokumentiert sind,
9. Passwortfelder nicht beschrieben werden,
10. Press-and-Hold keine doppelten Sessions erzeugt,
11. Statistik vollständig lokal und ausblendbar ist,
12. Release-Prüfung stabile Versionen korrekt erkennt,
13. Update-Fehler die App nicht beeinträchtigen,
14. alle Phase-2-Restore-, Retry- und Recovery-Funktionen für jede freigegebene Audioquelle weiter funktionieren.

---

## 27. Persistenz und Migration

### 27.1 Versionsstände

Einzuführen beziehungsweise zu erhöhen:

- `onboardingVersion`,
- `historySchemaVersion`,
- `settingsSchemaVersion`,
- `writingStyleSchemaVersion`,
- `dictionarySchemaVersion`,
- `appProfileSchemaVersion`.

### 27.2 Migrationsregeln

- Phase-2-Datensätze erhalten `finalText = originalTranscript`, falls `finalText` fehlt.
- Neue optionale Felder starten mit `nil` oder sicheren Defaults.
- Bestehende globale Sprache und Modellwahl bleiben erhalten.
- Live Preview wird nur aktiviert, wenn lokale Unterstützung und Berechtigung vorhanden sind.
- Standard-Schreibstil ist **Original**.
- Gesprochene Formatierung und AI Enhancement starten deaktiviert, bis der Benutzer sie auswählt.
- Es wird kein automatisches App-Profil aus Fenstertiteln erzeugt.
- Vorhandene Datensätze erhalten für `audioSource` den sicheren Default `.microphone`.
- Die globale Aufnahmequelle startet bei bestehenden und neuen Installationen als `.microphone`; Systemaudio wird niemals durch Migration aktiviert.
- Migrationen sind wiederholbar und in Tests abgedeckt.

---

## 28. Fehlerkategorien

Neue Kategorien ergänzen Phase 2:

| Kategorie | Beispiele | Verhalten |
|---|---|---|
| `previewPermission` | Speech Recognition verweigert | Preview deaktivieren, Aufnahme fortsetzen |
| `previewUnavailable` | Locale/lokale Erkennung fehlt | Preview deaktivieren, Hinweis anzeigen |
| `previewRuntime` | Recognition-Task bricht ab | Preview ausblenden, Aufnahme fortsetzen |
| `systemAudioPermission` | Bildschirm-/Systemaudiofreigabe fehlt | Aufnahme nicht starten, Freigabe erklären, Mikrofonmodus anbieten |
| `systemAudioUnavailable` | ScreenCaptureKit liefert keine Audioquelle | Aufnahme nicht starten, Quelle neu laden oder Mikrofon wählen |
| `systemAudioInterrupted` | Stream oder Ausgabe endet während Aufnahme | vorhandene Datei sicher abschließen und Recovery anbieten |
| `audioMixing` | Resampling, Synchronisierung oder Pegelgrenze schlägt fehl | Mischaufnahme sicher beenden; vorhandene Daten nicht überschreiben |
| `formatting` | ungültige lokale Regel | Regel überspringen, Original erhalten |
| `dictionaryConflict` | konkurrierende Ersetzungen | Konflikt markieren, sichere Regel anwenden |
| `enhancementAuthentication` | API-Key ungültig | Rohtext anbieten, Key reparieren |
| `enhancementTemporary` | Netzwerk/429/5xx | Retry oder Rohtext |
| `enhancementInvalidOutput` | leer/unplausibel | Ergebnis ablehnen, Rohtext erhalten |
| `directInsertionUnsupported` | AX-Rolle nicht editierbar | Clipboard-Fallback |
| `directInsertionUnknown` | Ergebnis unklar | keine automatische Doppeleinfügung |
| `updateCheck` | GitHub nicht erreichbar | still bis nächste manuelle Prüfung |

Preview-Fehler werden nie als Diktatfehler in der History gespeichert, sofern finale Transkription und Einfügung erfolgreich sind.

---

## 29. Logging und Datenschutz

### 29.1 Zulässige Logs

- Preview-Session Start/Ende,
- Preview-Provider und Locale,
- Zeit bis zum ersten Preview-Ereignis,
- Anzahl gedrosselter oder verworfener Preview-Updates,
- Transformationstypen ohne Textinhalt,
- Schreibstil-ID und App-Profil-ID,
- verwendete Einfügungsstrategie,
- ausgewählte Audioquellen-Kategorie, Format und Dauer ohne App- oder Mediennamen,
- Start, Ende und technische Fehler des Systemaudio-Streams ohne Audiobuffer,
- lokale Statistikberechnung ohne Inhalte,
- Update-Prüfung mit Version und Ergebnis.

### 29.2 Verbotene Logs

- Preview-Text,
- Original-, Zwischen- oder Finaltranskript,
- Wörterbuchbegriffe,
- benutzerdefinierte Prompttexte,
- Inhalte fokussierter Textfelder,
- Fenstertitel,
- Clipboard-Inhalte,
- Audiobuffer,
- Namen oder Metadaten der Apps, Fenster, Meetings oder Medien im Systemaudio,
- API-Keys oder Authorization Header.

### 29.3 Datenschutzerklärung

`PRIVACY.md` und Onboarding werden vor Veröffentlichung aktualisiert. Sie müssen erklären:

- lokale Apple-Speech-Vorschau,
- finale Audioübertragung an OpenAI,
- optionale Übertragung des Transkripttexts zur AI-Nachbearbeitung,
- lokale App-Profile und Statistik,
- optionale GitHub-Release-Prüfung,
- Systemaudioaufnahme, zusätzliche macOS-Freigabe und mögliche Erfassung von Tönen anderer Apps,
- Verantwortung des Benutzers für notwendige Einwilligungen bei Gesprächen und geschützten Inhalten.

---

## 30. Tests

### 30.1 Unit Tests

- Preview-State-Machine,
- Backpressure und Buffer-Drop-Regeln,
- UI-Drosselung,
- Locale-Auswahl und Availability-Fallback,
- Transformationsreihenfolge,
- gesprochene Formatierung Deutsch/Englisch,
- Escape-Mechanismus,
- Wörterbuch-Wortgrenzen, Groß-/Kleinschreibung und Konflikte,
- Schreibstilvalidierung,
- Enhancement-Fallback und Retry,
- App-Profil-Vererbung,
- Insert-Strategieauswahl,
- Statistikberechnung,
- semantischer Versionsvergleich,
- Audioquellenauswahl und migrationssicherer Mikrofon-Default,
- Formatnormalisierung und Zeitstempelbehandlung,
- Systemaudio-Berechtigungs- und Fehlerzustände,
- Mischpegel und Synchronisierung, sofern der Mischmodus veröffentlicht wird,
- Datenmodellmigrationen.

### 30.2 Integration Tests

- simulierte Preview-Events während echter Coordinator-Session,
- Stop während laufender Preview-Verarbeitung,
- Abbruch vor erstem Preview-Ergebnis,
- Preview-Fehler mit erfolgreichem finalem Ergebnis,
- Enhancement-Fehler mit Rohtext-Einfügung,
- Profilwechsel zwischen zwei Ziel-Apps,
- direkte Einfügung mit Clipboard-Fallback,
- Systemaudio-Stream zu lokaler Datei und bestehender Transkriptionspipeline,
- Systemaudio-Test ohne Netzwerk-, History- oder Dateirückstand,
- Stream-Unterbrechung mit sicher abgeschlossenem Recovery-Datensatz,
- Mischaufnahme mit simuliert abweichenden Sample-Raten, sofern freigegeben,
- Recovery aus neuen Statuszuständen.

### 30.3 Manuelle Tests

- Deutsch, Englisch und gemischte Sprache,
- kurze und mindestens fünfminütige Aufnahme,
- schnelle Start-/Stop-Folge,
- Mikrofonwechsel und Gerätetrennung,
- Systemaudio mit Lautsprechern, kabelgebundenen Kopfhörern und Bluetooth-Ausgabe,
- Systemaudiofreigabe erlaubt, verweigert, entzogen und nach App-Update erneut erteilt,
- Wechsel des macOS-Ausgabegeräts vor und während der Aufnahme,
- mindestens 30 Minuten Systemaudioaufnahme ohne ungebremsten Speicheranstieg,
- geschützte beziehungsweise von macOS nicht erfassbare Inhalte mit verständlichem Fehlerverhalten,
- Mischmodus mit lokaler und entfernter Stimme, falls veröffentlicht,
- Speech-Berechtigung erlaubt/verweigert/zurückgesetzt,
- mehrere Bildschirme und MacBook-Notch,
- Reduced Motion, Light/Dark Mode und unterschiedliche Skalierungen,
- Ziel-App-Matrix aus Abschnitt 21.3,
- offline während Preview, Transkription, Enhancement und Update-Prüfung,
- Community-Update auf einem zweiten Mac.

---

## 31. Nichtfunktionale Anforderungen

### 31.1 Zuverlässigkeit

- Keine neue Funktion darf ungespeichertes Audio verursachen.
- Systemaudio wird ab Aufnahmestart fortlaufend in eine lokale Datei geschrieben und niemals nur flüchtig an OpenAI gestreamt.
- Ein verweigerter Quellenzugriff erzeugt keine scheinbar erfolgreiche Stummaufnahme.
- Jeder Netzwerkprozess ist abbrechbar und zeitlich begrenzt.
- Statuswechsel bleiben persistent, sobald Aufnahmeende erreicht ist.
- Kein automatischer Prozess darf Text doppelt einfügen.

### 31.2 Performance

- Preview-UI höchstens zehn Updates pro Sekunde.
- Kein synchrones Speech- oder Netzwerk-Processing auf Audio- oder Main-Thread.
- ScreenCaptureKit-Callbacks führen keine UI-, Netzwerk- oder schwere Formatkonvertierung aus.
- Mischmodus verwendet begrenzte Queues und monotone Zeitstempel; Drift wird gemessen und begrenzt.
- Idle-Ressourcenverbrauch bleibt annähernd auf Phase-2-Niveau.
- Deaktivierte Funktionen erzeugen keine Hintergrundarbeit.

### 31.3 Accessibility

- Overlay-Status besitzt verständliche Accessibility-Labels.
- Farbe ist nie einziger Statusträger.
- Einstellungen sind vollständig per Tastatur bedienbar.
- Reduced Motion wird respektiert.
- Textgrößen bleiben bei macOS-Skalierung lesbar.

### 31.4 Sicherheit

- API-Key bleibt ausschließlich im Schlüsselbund und im flüchtigen Session-Cache.
- Benutzertexte werden nicht in UserDefaults gespeichert.
- Profil- und Wörterbuchimporte werden größenbegrenzt und validiert.
- Update-Links akzeptieren nur das fest konfigurierte HTTPS-GitHub-Repository.
- Systemaudioaufnahme beginnt nur nach expliziter Benutzeraktion und sichtbarer Statusanzeige.
- Geschützte Audioquellen werden nicht umgangen und es wird kein versteckter Capture-Modus angeboten.

---

## 32. Lieferplan und Abhängigkeiten

### 32.1 Phase 3.1

Abhängigkeiten:

- MicrophoneRecorder-Buffer-Abzweigung,
- Speech-Framework,
- Overlay-Erweiterung,
- Permission- und Settings-Erweiterung.

Releasefähig, sobald Abschnitt 11 erfüllt ist.

### 32.2 Phase 3.2

Abhängigkeiten:

- stabile finale Transkriptionspipeline aus Phase 2,
- History-Schemamigration,
- Provider-Abstraktion für Textnachbearbeitung.

Kann nach 3.1 implementiert werden, ohne Preview technisch vorauszusetzen.

### 32.3 Phase 3.3

Abhängigkeiten:

- Schreibstile aus 3.2 für App-Profile,
- bestehende FocusTarget- und TextInserter-Abstraktionen,
- öffentliche GitHub-Releases,
- ScreenCaptureKit-Systemaudio und die zugehörige macOS-Datenschutzfreigabe,
- ein einheitliches Audioquellen- und Dateiformat für die bestehende Transkriptionspipeline.

Audio Source Capture bildet ein eigenes Arbeitspaket mit separatem Berechtigungs-, Langzeit- und Recovery-Gate. Direkte Einfügung, Statistik und Update-Hinweis können dazu intern parallel entwickelt werden, werden aber gemeinsam abgenommen.

---

## 33. Rollout

- Jede Teilphase erhält einen eigenen Feature-Schalter während der Entwicklung.
- Migrationen laufen vor Aktivierung neuer Funktionen.
- Community-Test zuerst auf dem Entwicklungs-Mac, danach auf mindestens einem zweiten Mac.
- Preview startet nur bei vorhandener lokaler Unterstützung.
- AI Enhancement bleibt bei Erstinstallation deaktiviert.
- Direkte Einfügung startet mit Clipboard-Fallback und App-Kompatibilitätsliste.
- Audio Source Capture startet hinter einem Feature-Schalter; Mikrofon bleibt Standard und Systemaudio erfordert explizite Auswahl.
- Der Mischmodus wird nur aktiviert, wenn Synchronisierung, Pegelgrenze und Langzeittest bestanden sind.
- Release-Prüfung zeigt nur stabile GitHub-Releases.

Empfohlene Versionierung:

- Phase 3.1: `3.1.0-preview` während Test, danach stabiler Zwischenrelease,
- Phase 3.2: `3.2.0`,
- Phase 3.3 / Gesamtabschluss: `3.3.0` oder öffentlich vereinfacht `FlowDictate 3`.

---

## 34. Referenz und Lizenzgrenze

FluidVoice dient als Produkt- und Architektur-Inspiration, insbesondere für:

- Streaming-Provider-Abstraktion,
- partielle Transkripte,
- begrenzte Preview-Anzeige,
- Overlay-Größen und -Positionen,
- App-Profile, Wörterbuch und direkte Einfügung.

Relevante öffentliche Referenzen:

- [FluidVoice README](https://github.com/altic-dev/FluidVoice/blob/main/README.md)
- [FluidVoice TranscriptionProvider](https://github.com/altic-dev/FluidVoice/blob/main/Sources/Fluid/Services/TranscriptionProvider.swift)
- [FluidVoice ASRService](https://github.com/altic-dev/FluidVoice/blob/main/Sources/Fluid/Services/ASRService.swift)
- [FluidVoice BottomOverlayView](https://github.com/altic-dev/FluidVoice/blob/main/Sources/Fluid/Views/BottomOverlayView.swift)
- [Apple Speech Audio Buffer Recognition](https://developer.apple.com/documentation/speech/sfspeechaudiobufferrecognitionrequest)
- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [SCStreamConfiguration capturesAudio](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/capturesaudio)
- [SCStreamConfiguration excludesCurrentProcessAudio](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/excludescurrentprocessaudio)
- [OpenAI Realtime Transcription Events](https://platform.openai.com/docs/api-reference/realtime-server-events/input_audio_buffer/committed)

FluidVoice steht aktuell unter GPLv3. FlowDictate bleibt MIT-lizenziert. Deshalb werden ausschließlich öffentlich beschriebene Produktideen und allgemeine Architekturmuster berücksichtigt. Es wird kein FluidVoice-Quellcode kopiert, angepasst oder in FlowDictate übernommen. Sämtliche Implementierung erfolgt eigenständig.

---

## 35. Definition of Done

Eine Teilphase gilt erst als abgeschlossen, wenn:

- alle Muss-Anforderungen umgesetzt sind,
- die jeweiligen Abnahmekriterien erfüllt sind,
- Unit- und Integrationstests bestehen,
- relevante manuelle Tests dokumentiert sind,
- Migrationen mit vorhandenen Phase-2-Daten getestet sind,
- `README.md`, `PRIVACY.md` und Installationshinweise aktualisiert sind,
- keine API-Keys, Transkripte, Audiodaten oder persönlichen Signierdaten im Repository liegen,
- Community-ZIP und Prüfsumme erfolgreich erzeugt und auf einem zweiten Mac geprüft wurden,
- bekannte Einschränkungen in den Release Notes stehen.

Phase 3 ist vollständig abgeschlossen, wenn alle drei Teilphasen diese Definition erfüllen.
