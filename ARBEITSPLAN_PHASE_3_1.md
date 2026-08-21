# FlowDictate – Arbeitsplan Phase 3.1

**Phase:** 3.1 – Live Preview & Overlay

**Status:** Abgeschlossen; in Phase 3.2 integriert und auf dem Referenz-Mac geprüft

**Stand:** 21. August 2026

**Grundlage:** `FlowDictate_PRD_Phase_3.md` und `ARBEITSPLAN_VOR_PHASE_3_1.md`

**Umsetzungsstand:** Arbeitspakete A bis F sowie die automatisierten Teile von G sind implementiert. Der Test-Build und 26 automatisierte Tests sind erfolgreich. Offen bleiben die in G2 und G4 beschriebenen Messungen und manuellen Tests auf echter Hardware, insbesondere deutsche und englische Sprache, Berechtigungsdialoge, Mehrmonitor-Positionierung und Fokusverhalten in Drittanbieter-Apps.

## 1. Ziel

Phase 3.1 ergänzt FlowDictate um eine lokale, vorläufige Textanzeige während der Aufnahme. Die sichere Audiodatei, die finale OpenAI-Transkription, History, Retry und Einfügung bleiben davon unabhängig.

Nach Abschluss gilt:

- während einer Aufnahme kann lokaler Apple-Speech-Text im Overlay erscheinen,
- der Text ist eindeutig als vorläufig gekennzeichnet,
- die Vorschau ist abschaltbar und benötigt dann keine Speech-Berechtigung,
- ein Preview-Fehler beendet weder Aufnahme noch finale Transkription,
- Stop, Cancel, Fehler und App-Ende räumen jede Preview-Session auf,
- Compact-, Standard- und Expanded-Overlay bleiben nonactivating,
- Vorschautext wird weder gespeichert noch geloggt,
- deutsche und englische Vorschau sind manuell bestätigt.

## 2. Bereits vorhandene Basis

Folgende Teile werden weiterverwendet:

- ein einzelner Mikrofon-Tap schreibt zuerst die Audiodatei,
- `LivePreviewAudioBuffer` überträgt tiefe, unveränderliche Buffer-Kopien,
- `LivePreviewBufferChannel` besitzt eine begrenzte `bufferingNewest`-Queue,
- `MicrophoneRecorder.previewBufferHandler` ist optional und verursacht deaktiviert keine Kopierarbeit,
- `LivePreviewProviding` trennt Preview von finaler Transkription,
- `AppleSpeechLivePreviewProvider` verwendet lokale Apple-Speech-Erkennung,
- `NSSpeechRecognitionUsageDescription` ist für alle App-Konfigurationen gesetzt,
- Upload-, History-, Retry- und Restore-Basis sind getestet.

Phase 3.1 erweitert diese Basis; sie ersetzt nicht die finale Transkriptionspipeline.

## 3. Festgelegte Produktentscheidungen

### 3.1 Lokale Verarbeitung

- Phase 3.1 verwendet ausschließlich `requiresOnDeviceRecognition = true`.
- Es gibt keinen stillen Fallback auf Apple-Cloud-Erkennung.
- Ist lokale Erkennung nicht verfügbar, läuft FlowDictate wie in Phase 2 weiter.

### 3.2 Aktivierung und Migration

- Neuinstallationen sehen Live Preview im Onboarding als empfohlene, optionale Funktion.
- Bestehende Installationen behalten zunächst das bisherige Verhalten ohne neue unerwartete Berechtigungsabfrage.
- Bei bestehenden Installationen wird Live Preview erst durch eine bewusste Aktivierung in Settings eingeschaltet.
- Das Ablehnen der Speech-Berechtigung blockiert weder Onboarding noch Diktieren.
- Ein späteres Aktivieren ist jederzeit möglich.

### 3.3 Preview ist niemals final

- Preview-Text existiert nur im Arbeitsspeicher.
- Preview-Text wird nicht in `DictationRecord`, History, Diagnosen oder Logs geschrieben.
- Preview-Text wird nie in eine Ziel-App eingefügt.
- Nach Stop zeigt das Overlay `Finalizing…`; ausschließlich das OpenAI-Ergebnis wird eingefügt.

### 3.4 Zustandsmodell

`DictationState` bleibt für den produktiven Diktatablauf zuständig. Preview-Unterzustände werden separat als `LivePreviewState` beziehungsweise `OverlayPresentationState` modelliert. Dadurch bleiben Phase-2-Status, Recovery und Retry stabil.

### 3.5 Sprache und Locale

- `German` verwendet bevorzugt `de-DE`.
- `English` verwendet bevorzugt `en-US`.
- `Automatic` wählt die erste passende unterstützte Locale aus den macOS-Sprachpräferenzen.
- Die tatsächlich verwendete Locale wird in Settings angezeigt.
- Ist keine passende lokale Locale verfügbar, wird nur die Vorschau deaktiviert.

## 4. Nicht Bestandteil von Phase 3.1

- Cloud-Realtime-Transkription,
- lokale finale Transkription,
- Wörterbuch und gesprochene Formatierung,
- Schreibstile oder AI-Nachbearbeitung,
- direkte Accessibility-Texteinfügung,
- persistierter Preview-Text,
- Änderungen an API-Key-, Release- oder Lizenzmodell,
- vollständige Neugestaltung der History.

## 5. Zielarchitektur

```text
MicrophoneRecorder – ein Audio-Tap
    ├── Datei schreiben → AudioStore → finale OpenAI-Transkription
    ├── Pegel → Overlay
    └── optionale tiefe Kopie
            ↓
    LivePreviewBufferChannel (begrenzt)
            ↓
    AppleSpeechLivePreviewProvider (nur on-device)
            ↓
    LivePreviewCoordinator
       ├── Session-ID und Lebenszyklus
       ├── Fehler/Fallback
       ├── Drosselung auf maximal 10 UI-Updates/s
       └── Zeichenlimit/Suffix
            ↓
    RecordingOverlayController (nonactivating)
```

### 5.1 Neue beziehungsweise erweiterte Komponenten

| Komponente | Verantwortung |
|---|---|
| `LivePreviewCoordinator` | Start, Stop, Cancel, Session-Isolation, Queue und UI-Ereignisse |
| `LivePreviewState` | disabled, waiting, active, unavailable und failed |
| `LivePreviewAvailability` | Berechtigung, Locale, Recognizer- und On-Device-Verfügbarkeit |
| `AppleSpeechLivePreviewProvider` | Speech-Request, Audiobuffer und Providerereignisse |
| `PermissionManager` | Speech-Status, Anfrage und Link zu Systemeinstellungen |
| `RecordingOverlayModel` | Status, Pegel, Preview-Suffix und Darstellungskonfiguration |
| `AppSettings` | Aktivierung, Größe, Position und Zeichenlimit |

## 6. Arbeitspaket A – Schnittstellen, Datenmodelle, Einstellungen und Migration

### A1. Datenmodelle

Einzuführen sind:

```swift
enum LivePreviewState: Equatable, Sendable {
    case disabled
    case waiting
    case active(String)
    case unavailable(String)
    case failed(String)
}

enum OverlaySize: String, CaseIterable, Codable {
    case compact
    case standard
    case expanded
}

enum OverlayPosition: String, CaseIterable, Codable {
    case bottomTrailing
    case bottomCenter
    case menuBarTrailing
}
```

Providerereignisse unterscheiden mindestens:

- partiellen Text,
- finalisiertes Segment,
- Nichtverfügbarkeit,
- Providerfehler,
- kontrolliertes Session-Ende.

### A2. Persistente Einstellungen

`AppSettings` erhält:

- `livePreviewEnabled`,
- `overlaySize`, Default `standard`,
- `livePreviewCharacterLimit`, Default 150, Bereich 50 bis 800,
- `overlayPosition`, Default `bottomTrailing`,
- eine interne Migrationsmarke für die erstmalige Preview-Einführung.

Werte werden beim Laden validiert und bei unbekannten Enum-Werten sicher auf Defaults gesetzt.

### A3. Migration

- Neuinstallation: Preview wird im Onboarding angeboten und kann dort aktiviert werden.
- Bestehende Installation: Preview bleibt aus, bis der Benutzer sie einschaltet.
- Die Onboarding-Pflicht für API-Key, Ordner und bestehende Berechtigungen wird nicht erneut erzwungen.
- Eine neue optionale Funktion darf `needsOnboarding` nicht dauerhaft wahr machen.

### A4. Tests

- neue Defaults,
- Migration einer bestehenden Phase-2-Installation,
- Persistenz aller Werte,
- Clamp für 50 bis 800 Zeichen,
- unbekannte oder beschädigte Enum-Werte fallen auf Defaults zurück.

### Gate A

Einstellungen sind migrationssicher, ohne dass die Audio- oder Transkriptionspipeline verändert wurde.

## 7. Arbeitspaket B – Speech-Berechtigung und Verfügbarkeit

### B1. Permission-Abstraktion

`PermissionManaging` wird ergänzt um:

- aktuellen Speech-Authorization-Status,
- `requestSpeechRecognitionAccess()`,
- `openSpeechRecognitionSettings()`,
- getrennte Statusdarstellung für `notDetermined`, `authorized`, `denied` und `restricted`.

### B2. Regeln

- Bei deaktivierter Preview wird niemals Speech-Berechtigung angefragt.
- Die Anfrage erfolgt nur durch eine eindeutige Benutzeraktion im Onboarding oder in Settings.
- Eine Ablehnung erzeugt keinen Diktatfehler.
- Settings zeigen einen direkten Link zu Datenschutz → Spracherkennung.
- Onboarding erklärt Mikrofon, Speech Recognition und Accessibility getrennt.

### B3. Availability Service

Die Verfügbarkeitsprüfung bestimmt:

- gewählte Locale,
- `SFSpeechRecognizer.isAvailable`,
- `supportsOnDeviceRecognition`,
- Authorization-Status,
- verständlichen lokalen Status für die UI.

Verfügbarkeitsmeldungen dürfen keinen diktierten Text enthalten.

### B4. Tests

- deaktivierte Preview löst keine Anfrage aus,
- `notDetermined` wird korrekt angeboten,
- denied/restricted blockieren nur Preview,
- nicht unterstützte Locale deaktiviert nur Preview,
- Locale-Auflösung für Deutsch, Englisch und Automatic.

### Gate B

Alle Berechtigungszustände sind sichtbar und Diktieren funktioniert in jedem Zustand weiterhin.

## 8. Arbeitspaket C – Provider und Session-Lebenszyklus

### C1. Provider-Schnittstelle absichern

`LivePreviewProviding` wird so erweitert, dass:

- genau eine Session aktiv sein kann,
- Providerereignisse Fehler und Abschluss melden,
- `stop()` und `cancel()` getrennt, idempotent und testbar sind,
- alte Callbacks nach Sessionwechsel ignoriert werden,
- der Provider keine UI-Verantwortung besitzt.

### C2. `LivePreviewCoordinator`

Der Coordinator besitzt pro Aufnahme:

- eindeutige Session-ID,
- einen neuen `LivePreviewBufferChannel`,
- einen Provider,
- eine begrenzte Queue,
- gedrosselte Presentation-Updates,
- Zähler für verworfene Buffer nur für Debug-/Testdiagnostik.

Öffentliche Operationen:

- `prepareIfEnabled(configuration:)`,
- `start()`,
- `finish()`,
- `cancel()`,
- `handleProviderEvent()`.

### C3. UI-Drosselung und Textlimit

- maximal zehn sichtbare Textupdates pro Sekunde,
- Suffixbildung nach Swift-`Character`, nicht nach Bytes oder Unicode-Scalars,
- keine Persistenz zwischen Sessions,
- ein leeres Ergebnis entfernt keinen bereits sichtbaren sinnvolleren Partial-Text,
- nach Sessionende werden verspätete Events verworfen.

### C4. Cleanup

- `finish()` beendet die Queue und Recognition kontrolliert, wartet aber nicht auf finalen Preview-Text,
- `cancel()` verwirft Queue und Text sofort,
- Providerfehler beendet nur die Preview,
- Deinitialisierung und App-Ende räumen Tasks auf,
- Mikrofonwechsel während einer laufenden Aufnahme folgt weiterhin den bestehenden Aufnahmebedingungen.

### C5. Tests mit Fake-Provider

- normaler Partial-Text,
- langsamer Konsument und Buffer-Drops,
- Providerfehler während Aufnahme,
- fehlende Berechtigung,
- schneller Start/Stop,
- doppeltes Stop/Cancel,
- verspätetes Ereignis einer alten Session,
- Zeichenlimit mit Emoji und zusammengesetzten Unicode-Zeichen,
- maximal zehn UI-Updates pro Sekunde über injizierbare Clock/Scheduler.

### Gate C

Der Preview-Lebenszyklus ist vollständig isoliert und ohne echte Mikrofonaufnahme testbar.

## 9. Arbeitspaket D – Integration in die Aufnahme

### D1. Start

Vor `recorder.start()`:

1. Konfiguration und Verfügbarkeit bestimmen.
2. Nur bei aktivierter und erlaubter Preview eine Session anlegen.
3. `previewBufferHandler` mit der Session verbinden.
4. Preview starten.
5. Aufnahme starten.

Schlägt Schritt 2 bis 4 fehl, wird der Handler entfernt und die normale Aufnahme dennoch gestartet.

### D2. Laufende Aufnahme

- der Audio-Tap schreibt immer zuerst die Datei,
- Preview-Kopie wird nur bei gesetztem Handler erzeugt,
- eine volle Queue verwirft ausschließlich Preview-Buffer,
- Pegelanzeige und Hotkeys bleiben unabhängig,
- Preview-Text verändert weder `DictationState` noch `DictationRecord`.

### D3. Stop

1. Recorder stoppen und Datei schließen.
2. Preview-Handler sofort entfernen.
3. Queue beenden und Preview begrenzt aufräumen.
4. Overlay auf `Finalizing…` setzen.
5. Bestehenden `TranscriptionRunner` unverändert starten.

### D4. Cancel und Fehler

- Cancel entfernt Handler, beendet Preview sofort und sendet weiterhin nichts an OpenAI.
- Mikrofon- oder Dateifehler beendet Preview best effort.
- Transkriptions- und Einfügefehler laufen nach abgeschlossenem Preview über die bestehenden Wege.
- Preview-Fehler darf niemals `fail()` für das gesamte Diktat auslösen.

### D5. Tests

- Preview aktiviert/deaktiviert,
- Providerstart schlägt fehl, Aufnahme startet dennoch,
- Audiobuffer erreichen Datei und Preview,
- Stop beendet exakt eine Session,
- Cancel beendet Session und ruft Provider nicht zur finalen Transkription auf,
- zweite Aufnahme erhält eine neue Session,
- bestehende Start/Stop/Cancel/Retry/Restore-Tests bleiben grün.

### Gate D

Eine vollständige Diktatfolge arbeitet mit und ohne Preview identisch bis auf die Anzeige.

## 10. Arbeitspaket E – Overlay 3.1

### E1. Overlay-Modell

`RecordingOverlayPresenting` erhält gezielte Operationen für:

- Preview-Zustand,
- Preview-Text,
- Overlay-Größe,
- Overlay-Position,
- `Finalizing…`.

Tests und Mocks werden entsprechend erweitert. Das Overlay bleibt ein `NSPanel` mit:

- `.nonactivatingPanel`,
- `canBecomeKey == false`,
- `canBecomeMain == false`,
- `ignoresMouseEvents == true` während normaler Diktate.

### E2. Darstellungen

| Modus | Geplanter Inhalt |
|---|---|
| Compact | Status, Pegel und eine gekürzte Preview-Zeile |
| Standard | Status, Pegel und zwei bis vier Preview-Zeilen |
| Expanded | Status und vertikal scrollbarer Preview-Bereich |

Der Preview-Text erhält eine sichtbare Kennzeichnung `Live Preview` beziehungsweise einen zurückhaltenden vorläufigen Stil.

### E3. Verhalten

- Default-Limit 150 Zeichen,
- nur das Textende bleibt sichtbar,
- Expanded scrollt bei neuem Text nach unten,
- keine Animation pro Zeichen,
- Pegelanimation respektiert `accessibilityReduceMotion`,
- Position wird aus Settings angewendet,
- Bildschirmwahl verwendet zunächst den Bildschirm der Ziel-App, ersatzweise den Bildschirm mit Mauszeiger,
- Größenwechsel aktualisiert ein sichtbares Panel ohne Fokusübernahme.

### E4. Positionen

- `bottomTrailing`: heutige Position,
- `bottomCenter`: zentriert am unteren Rand,
- `menuBarTrailing`: rechts oben unterhalb der Menüleiste.

Alle Positionen verwenden `visibleFrame`, damit Dock und Menüleiste berücksichtigt werden.

### E5. Tests

- Zustands- und Textdarstellung,
- Suffix/Zeichenlimit,
- Größenberechnung,
- Positionierung auf mehreren virtuellen Bildschirmframes,
- Reduce Motion,
- Panel bleibt nonactivating,
- Preview-Text erscheint nicht in Logs oder History.

### Gate E

Alle drei Overlay-Größen und Positionen funktionieren ohne Fokusverlust.

## 11. Arbeitspaket F – Settings, Onboarding und Preview-Test

### F1. Settings → Dictation

Neue Section `Live Preview`:

- Toggle `Show Live Preview`,
- Authorization- und Availability-Status,
- tatsächlich verwendete Sprache/Locale,
- Overlay-Größe,
- Zeichenlimit über Slider plus Zahlenwert,
- Overlay-Position,
- Button `Test Preview…`.

Nicht verfügbare Optionen werden nicht versteckt, sondern mit kurzer Erklärung deaktiviert.

### F2. Onboarding

Der Permissions-Schritt erklärt:

- Mikrofon für Aufnahme,
- Speech Recognition für lokale vorläufige Anzeige,
- Accessibility für Einfügung.

Speech bleibt optional. `Continue` und `Start FlowDictate` hängen nicht davon ab.

### F3. Preview-Test

`Test Preview…` startet eine klar begrenzte Testsession:

- maximal fünf Sekunden,
- derselbe Recorder- und Einzel-Tap-Pfad,
- sichtbares Test-Overlay,
- kein OpenAI-Aufruf,
- kein History-Eintrag,
- keine dauerhafte Audiodatei; die Testdatei wird nach Stop oder Fehler gelöscht,
- kein Einfügen und keine Änderung der Zwischenablage,
- keine parallele Ausführung während eines echten Diktats.

### F4. Tests

- Controls spiegeln Settings,
- Toggle aus fragt keine Berechtigung an,
- Toggle an mit `notDetermined` zeigt explizite Anfrage,
- Preview-Test löscht temporäres Audio,
- Preview-Test kann nicht parallel zu Aufnahme/Transkription laufen,
- Onboarding bleibt ohne Speech-Berechtigung abschließbar.

### Gate F

Ein Benutzer kann Preview vollständig verstehen, aktivieren, testen, konfigurieren und wieder deaktivieren.

## 12. Arbeitspaket G – Performance, Datenschutz und Regression

### G1. Automatisierte Verifikation

- vollständiger Unit-Test-Satz,
- Preview-Coordinator- und Provider-Fakes,
- Settings- und Migrationsfälle,
- Permission-Fälle,
- Buffer-Backpressure,
- Start/Stop/Cancel-Rennen,
- Overlay-Modell und Positionierung,
- Debug-Test-Build,
- Release-Build,
- `git diff --check`.

### G2. Performance-Messungen

Für 1, 5, 15 und 30 Minuten Aufnahme:

- Speicherentwicklung,
- Queue-Höchststand,
- verworfene Preview-Buffer,
- Zeit bis zum ersten sichtbaren Text,
- UI-Updatefrequenz,
- Audiodateidauer und erkennbare Dropouts,
- CPU mit Preview an und aus.

Zielwerte:

- erster Text normalerweise unter zwei Sekunden,
- Queue bleibt fest begrenzt,
- UI maximal zehn Updates pro Sekunde,
- kein mit Aufnahmedauer wachsender Preview-Speicher,
- Preview aus erzeugt keine Buffer-Kopien oder Speech-Tasks.

### G3. Datenschutzprüfung

- kein Preview-Text in `FlowLogger`,
- kein Preview-Text in `DictationRecord`, History oder Diagnostics,
- keine Apple-Cloud-Erkennung,
- README und `PRIVACY.md` erklären lokale Preview und optionale Berechtigung,
- keine neue Telemetrie.

### G4. Manuelle Testmatrix

Geräte:

- internes Mac-Mikrofon,
- mindestens ein USB- oder Bluetooth-Mikrofon.

Sprachen:

- Deutsch,
- Englisch,
- Automatic mit deutscher und englischer Systemsprache, soweit verfügbar.

Szenarien:

1. Preview an und Berechtigung erlaubt.
2. Preview aus ohne Berechtigungsdialog.
3. Berechtigung verweigert und später in Systemeinstellungen erlaubt.
4. Locale oder lokale Erkennung nicht verfügbar.
5. Stop innerhalb der ersten Sekunde.
6. Mehrfacher schneller Start/Stop.
7. Cancel bei sichtbarem Preview-Text.
8. Providerfehler bei fortlaufender Aufnahme.
9. 30-Minuten-Aufnahme.
10. Compact, Standard und Expanded.
11. alle drei Positionen auf einem und mehreren Bildschirmen.
12. Reduce Motion ein und aus.
13. finale Transkription unterscheidet sich sichtbar vom Preview-Text.
14. Einfügung, Clipboard-Restore, Retry und Restore Last Dictation.

### Gate G

Alle automatisierten Tests sind grün und die manuelle Matrix enthält keine Aufnahme-, Fokus- oder Datenverlustregression.

## 13. Empfohlene Ausführungsreihenfolge

1. A – Schnittstellen, Datenmodelle, Einstellungen und Migration.
2. B – Speech-Berechtigung und Verfügbarkeit.
3. C – Provider und `LivePreviewCoordinator`.
4. D – Aufnahmeintegration ohne neue Overlay-Details.
5. E – Overlay-Darstellung und Positionierung.
6. F – Settings, Onboarding und Preview-Test.
7. G – Performance, Datenschutz, Regression und Dokumentation.

Nach jedem Gate wird ein kleiner, eigenständig testbarer Commit empfohlen. Die Phase wird nicht als abgeschlossen markiert, bevor Gate G einschließlich manueller Hardwaretests bestanden ist.

## 14. Definition of Done

Phase 3.1 ist abgeschlossen, wenn:

1. lokale deutsche und englische Preview während Aufnahme funktioniert,
2. Preview aus keinerlei Speech-Arbeit oder Berechtigungsanfrage erzeugt,
3. Preview-Fehler immer sicher auf Phase-2-Verhalten degradieren,
4. Stop, Cancel, Fehler und App-Ende keine Recognition-Tasks hinterlassen,
5. der erste Text normalerweise innerhalb von zwei Sekunden erscheint,
6. Queue und Speicher über lange Aufnahmen begrenzt bleiben,
7. Preview-Text niemals persistiert, geloggt oder eingefügt wird,
8. finales OpenAI-Ergebnis die Vorschau vollständig ersetzt,
9. Compact, Standard und Expanded ohne Fokusverlust funktionieren,
10. Settings, Onboarding und Testfunktion vollständig sind,
11. alle automatisierten und manuellen Regressionstests bestanden sind,
12. README, Privacy-Dokumentation und Phase-3-Status aktualisiert sind.

## 15. Hauptrisiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| Speech ist für Locale/Gerät nicht lokal verfügbar | Preview deaktivieren, finale Transkription unverändert fortsetzen |
| langsame Recognition staut Audio | feste Queue; nur alte Preview-Buffer verwerfen |
| verspätete Callbacks verändern neue Session | Session-ID prüfen und alte Events ignorieren |
| Speech-Prompt überrascht bestehende Nutzer | Migration standardmäßig aus; Anfrage nur nach Benutzeraktion |
| Overlay übernimmt Fokus | nonactivating Panel unverändert beibehalten und testen |
| UI flackert bei Partials | Updates auf 10 Hz drosseln und nur sinnvolle Änderungen anzeigen |
| Unicode-Suffix trennt Zeichen | Begrenzung anhand von Swift-`Character` |
| Cleanup blockiert Stop | begrenztes, idempotentes Cleanup ohne Warten auf finales Preview-Ergebnis |
| Preview beeinflusst Audiodatei | Datei immer zuerst schreiben; Preview bleibt optionaler nachrangiger Fan-out |
| Testfunktion hinterlässt Audio | eigene Temp-Datei und Cleanup in jedem Exit-Pfad |
