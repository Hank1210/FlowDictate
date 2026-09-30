# Product Requirements Document: FlowDictate Phase 4.0

**Phase:** 4.0 – Local-first & Reliable Dictation
**Status:** Abgeschlossen und zur Veröffentlichung freigegeben
**Stand:** 30. August 2026
**Ausgangsversion:** FlowDictate 3.4.0, Build 8, Tag `v3.4.0`, Release-Commit `e00571a`
**Zielversion:** FlowDictate 4.0.0, Build 24
**Grundlagen:** `FlowDictate_PRD_Phase_3.md`, `FlowDictate_PRD_Phase_3_4.md` und der aktuelle Code auf `main`

## 1. Zweck

Phase 4.0 entwickelt FlowDictate von einer ausschließlich cloudbasierten zu einer local-first arbeitenden Diktierpipeline weiter. Nutzer können eine geeignete lokale Transkriptionsengine verwenden, ohne einen API-Key zu hinterlegen. OpenAI bleibt als ausdrücklich gewählte Cloudoption erhalten.

Aufnahme und Verarbeitung erfolgen bewusst jeweils für genau ein Diktat. Ein neues Diktat kann beginnen, sobald Transkription, Textverarbeitung und Einfügung des vorherigen Diktats abgeschlossen sind. Jedes Diktat bleibt ein eigener, lokal gesicherter und recoverbarer Job mit eingefrorener Konfiguration und eingefrorenem Einfügungsziel.

Phase 4.0 ergänzt außerdem sichere Korrekturbefehle innerhalb des gerade gesprochenen Diktats. Sie verändert noch keinen bereits in einer fremden App vorhandenen Text.

## 2. Produktpositionierung

### 2.1 Leitsatz

FlowDictate 4.0 ist ein zuverlässiges macOS-Diktatsystem, das wahlweise vollständig lokal oder bewusst über einen Cloudprovider arbeitet und weder Originalaufnahme noch Verarbeitungsfortschritt verliert.

### 2.2 Differenzierung

FlowDictate konkurriert nicht über ein eigenes Cloudkonto, plattformübergreifende Synchronisierung oder ein Abonnement. Die Produktstärken bleiben:

- lokaler Besitz von Aufnahme, History und Textstufen,
- wahlweise Offline-Transkription oder direkter BYOK-Cloudzugriff,
- keine Entwickler-Cloud und keine Telemetrie,
- reproduzierbare Long-Form-Segmentierung und Recovery,
- deterministische lokale Textverarbeitung,
- offene, nachvollziehbare Community-Implementierung,
- bestehende Unterstützung für Intel- und Apple-Silicon-Macs, soweit technisch vertretbar.

## 3. Ausgangslage und Einschränkungen von 3.4

FlowDictate 3.4 bietet eine stabile Aufnahme-, Transkriptions-, Smart-Dictation-, History-, Einfügungs- und Long-Form-Pipeline. Trotzdem gelten folgende Einschränkungen:

1. Finale Transkription setzt einen OpenAI-API-Key voraus.
2. `DictationCoordinator.startRecording()` verweigert den Start ohne API-Key.
3. Die aktive Providererzeugung ist auf `OpenAITranscriptionProvider` festgelegt.
4. Providerfehler und Dateigrenzen enthalten noch OpenAI-spezifische Annahmen.
5. Aufnahme und Verarbeitung teilen einen globalen Coordinator-Zustand.
6. Während `Processing` kann keine neue Aufnahme beginnen.
7. Eine Providerinstanz besitzt noch kein maschinenlesbares Fähigkeitsmodell.
8. App-Profile wählen Sprache und Modell, aber keinen Transkriptionsprovider.
9. Lokale Modelle können weder installiert, geprüft, getestet noch entfernt werden.
10. Spoken Formatting unterstützt Satzzeichen und Struktur, aber keine semantischen Korrekturen des aktuellen Diktats.

## 4. Produktentscheidungen

### 4.1 Desktop-Fokus

Phase 4.0 ist ausschließlich eine macOS-Phase. Eine mögliche spätere iPhone-/iPad-App bleibt offen und erzeugt keine Anforderungen an UI, Storage, Distribution oder Plattformabstraktion.

Geschäftslogik soll dennoch nicht unnötig AppKit-gebunden werden. Es werden aber keine mobilen Targets, App Groups, Widgets, Tastaturerweiterungen oder plattformübergreifenden Packages auf Vorrat eingeführt.

### 4.2 Intel und Apple Silicon

- macOS 14 bleibt zunächst Mindestversion.
- Der Community-Build bleibt universal, sofern die ausgewählte lokale Bibliothek ohne unverhältnismäßige Sonderkonstruktion für `arm64` und `x86_64` gebaut werden kann.
- Lokale Modelle dürfen zunächst nur auf geeigneten Apple-Silicon-Macs verfügbar sein.
- Intel-Macs behalten den OpenAI-Pfad und alle sonstigen 3.4-Funktionen.
- Falls die lokale Engine einen stabilen Universal-Build verhindert oder dauerhaft stark verkompliziert, darf 4.0 nach einem dokumentierten Gate Apple-Silicon-only werden. Diese Entscheidung muss vor Implementierungsabschluss und vor einer Community-ZIP getroffen werden.

### 4.3 Keine stille Cloud-Degradierung

Eine lokal gestartete Transkription darf bei Fehler, Modellmangel, Speicherknappheit oder nicht unterstützter Sprache niemals automatisch Audio an OpenAI senden. Ein Providerwechsel erfordert eine ausdrückliche Nutzeraktion.

### 4.4 Provider einer laufenden Session bleibt stabil

Provider, Engine, Modell, Sprache und relevante Optionen werden beim Start eines Dictation Jobs eingefroren. Eine Long-Form-Session wird mit derselben Engine und demselben Modell fortgesetzt. Ist das Modell nicht mehr verfügbar, bleibt der Job pausiert, bis es wiederhergestellt oder ausdrücklich als neue Transkriptionssession mit einem anderen Provider gestartet wird.

### 4.5 Ein Diktat zur Zeit

Phase 4.0 verarbeitet höchstens einen Dictation Job gleichzeitig und nimmt währenddessen kein weiteres Diktat an. Das persistierte Jobmodell bleibt für Recovery erhalten, dient aber nicht als fortlaufende Nutzer-Queue. Diese Entscheidung begrenzt lokale Modelllast, verhindert konkurrierende Einfügungen und vermeidet die in Vorabtests gemessene zusätzliche Queue- und Main-Actor-Latenz.

### 4.6 Mikrofon plus Systemaudio ist Phase 4.1

Phase 4.0 verändert die vorhandenen Einzelquellen Mikrofon und Systemaudio nicht grundlegend. Synchronisierte kombinierte Aufnahme, Track-Merge und Meeting-Funktionen werden in `FlowDictate_PRD_Phase_4_1.md` spezifiziert.

## 5. Ziele und Erfolgskriterien

Nach Abschluss von Phase 4.0 gilt:

1. Auf unterstützter Hardware kann FlowDictate ohne API-Key vollständig lokal transkribieren.
2. Nutzer sehen vor jeder Enginewahl eindeutig, ob Audio oder Text das Gerät verlassen kann.
3. OpenAI bleibt als kompatibler Cloudprovider erhalten.
4. Nach dem Stoppen beginnt der persistierte Job ohne vermeidbare Queue-Wartezeit mit der Verarbeitung.
5. Jeder Job besitzt eigene Aufnahme, History-ID, Konfiguration, Zielanwendung und Recoverydaten.
6. Ein neues Diktat wird erst nach vollständigem Abschluss des vorherigen Jobs freigegeben.
7. App-Neustart stellt wartende oder unterbrochene Jobs wieder her, ohne bereits erfolgreiche Long-Form-Segmente neu zu verarbeiten.
8. Lokale Modelle werden kontrolliert heruntergeladen, geprüft, atomar installiert und vollständig entfernbar verwaltet.
9. Korrekturbefehle ändern nur den Text des aktuellen Diktats und sind lokal, deterministisch und nachvollziehbar.
10. Mikrofon-, Systemaudio-, Long-Form-, Smart-Dictation-, Profile-, History- und Einfügungsfunktionen aus 3.4 bleiben regressionsfrei.

## 6. Umfang

### 6.1 Pflichtumfang

- providerneutrale Transkriptionsauswahl,
- mindestens eine veröffentlichungsfähige lokale finale Transkriptionsengine,
- Betrieb ohne OpenAI-Key bei lokaler Engine,
- Modellverfügbarkeits- und Hardwareprüfung,
- lokaler Modellmanager,
- explizite Netzwerk-/Privacy-Modi,
- Providerwahl in globalen Settings und App-Profilen,
- persistierbares `DictationJob`-Modell,
- klar getrennte Zustände für Aufnahme und Jobverarbeitung,
- unmittelbare Verarbeitung genau eines persistierten Jobs,
- gesperrter Aufnahmestart während vorheriger Verarbeitung,
- geordnete, genau einmal ausgeführte Einfügung,
- Recovery wartender und unterbrochener Jobs,
- lokale Korrekturen innerhalb des aktuellen Diktats,
- providerneutrale Long-Form-Verarbeitung,
- additive History- und Settingsmigration,
- inhaltsfreie Performanceinstrumentierung,
- Regressionstests und finale Community-ZIP-Abnahme.

### 6.2 Soll-Umfang mit eigenem Gate

- Apple `SpeechAnalyzer` als zusätzliche Engine unter macOS 26,
- mehr als ein lokales Modell mit Qualitäts-/Geschwindigkeitsprofilen,
- automatischer Engine-Benchmark mit datenschutzfreier Testaufnahme,
- Pause und manuelle Neuordnung wartender Jobs vor ihrer Verarbeitung,
- manuelle erneute Transkription eines Jobs mit anderem Provider,
- Korrekturvorschau in History vor erneuter Einfügung.

Soll-Funktionen dürfen Offline-Garantie, unmittelbaren Verarbeitungsstart oder 3.4-Recovery nicht verzögern oder schwächen.

### 6.3 Nicht Bestandteil

- iPhone-, iPad-, Windows- oder Web-App,
- Cloudkonto oder FlowDictate-eigener Backenddienst,
- iCloud-Synchronisierung,
- parallele Verarbeitung mehrerer Dictation Jobs,
- parallele Netzwerktranskription mehrerer Segmente,
- Mikrofon und Systemaudio gleichzeitig,
- Speaker-Diarization,
- Cloud-Streaming während der Aufnahme,
- automatische Bearbeitung bereits vorhandenen Textes in einer Ziel-App,
- generische Voice-Agent- oder Chat-Assistentenfunktion,
- automatischer Modellwechsel ohne Zustimmung,
- automatische Installation von App-Updates,
- Aufgabe der JSON-basierten History zugunsten von SQLite,
- Veröffentlichung vor Test der finalen Community-ZIP.

## 7. Privacy- und Ausführungsmodi

### 7.1 Modi

| Modus | Audio | Text für AI-Enhancement | Updatecheck |
|---|---|---|---|
| `offline` | bleibt lokal | bleibt lokal; Cloud-Styles deaktiviert | deaktiviert, bis Nutzer manuell online prüft oder Offline beendet |
| `localWithOptionalCloudEnhancement` | bleibt lokal | nur nach ausdrücklich aktivierter Cloud-Writing-Style-Verarbeitung | erlaubt gemäß Einstellungen |
| `cloudTranscription` | an den gewählten Cloudprovider | gemäß Writing-Style-Einstellung | erlaubt gemäß Einstellungen |

Die UI verwendet verständliche Bezeichnungen und keine ausschließlich technischen Enum-Namen.

### 7.2 Netzwerkdurchsetzung

- `offline` blockiert Providerrequests, Credentialvalidierung, AI-Enhancement und automatische Releasechecks.
- Ein manueller Versuch einer Cloudfunktion zeigt eine Erklärung und fordert einen Moduswechsel an.
- Logs dürfen keine Audioinhalte, Transkripte, Prompts, API-Keys oder Modell-Downloadtokens enthalten.
- Tests müssen nachweisen, dass im Offline-Modus kein injizierter Netzwerkclient aufgerufen wird.

## 8. Providerarchitektur

### 8.1 Fähigkeitsmodell

Jeder Provider veröffentlicht mindestens:

```swift
struct TranscriptionProviderCapabilities: Sendable, Equatable {
    var providerID: String
    var engineID: String
    var executionLocation: ExecutionLocation
    var requiresCredential: Bool
    var supportsPrompt: Bool
    var supportsTimestamps: Bool
    var supportsLongForm: Bool
    var supportedLanguages: Set<String>?
    var maximumInputBytes: Int64?
    var recommendedAudioFormat: AudioFormatRequirement
}
```

`nil` bei Sprachen oder Dateigröße bedeutet nicht unbegrenzt, sondern „vom Provider dynamisch zu prüfen“.

### 8.2 Provider Registry

Eine `TranscriptionProviderRegistry` ist verantwortlich für:

- bekannte Providerdeskriptoren,
- Hardware- und OS-Verfügbarkeit,
- Credentialbedarf,
- Engine-/Modellauflösung,
- verständliche Nichtverfügbarkeitsgründe,
- Erzeugung einer laufzeitgebundenen Providerinstanz.

Der `DictationCoordinator` darf weder API-Key-Zwang noch konkrete OpenAI-Erzeugung als allgemeine Startvoraussetzung enthalten.

### 8.3 Fehlerdomäne

Fehler werden mindestens unterschieden in:

- Engine nicht unterstützt,
- Modell fehlt oder ist beschädigt,
- unzureichender Speicher,
- nicht unterstützte Sprache,
- lokale Initialisierung fehlgeschlagen,
- Eingabeformat nicht unterstützt,
- Netzwerk offline,
- Credential fehlt/ungültig,
- Providerlimit oder temporärer Serverfehler,
- Transkript leer oder ungültig,
- Job unterbrochen oder abgebrochen.

Fehlermeldungen nennen nicht pauschal OpenAI, wenn eine lokale Engine aktiv ist.

## 9. Auswahl der lokalen Engine

### 9.1 Kandidaten

Mindestens folgende Optionen werden in einem technischen Spike mit identischem Testkorpus verglichen:

- FluidAudio/Parakeet,
- WhisperKit,
- Apple SpeechAnalyzer unter macOS 26, sofern als Releaseengine geeignet.

### 9.2 Auswahlkriterien

- Qualität für Deutsch und Englisch,
- Fachbegriffe, Zahlen, Satzzeichen und gemischte Sprache,
- Warm- und Cold-Start-Latenz,
- Peak- und stabiler RAM-Bedarf,
- CPU-, GPU- und Neural-Engine-Last,
- Modellgröße und Downloadzuverlässigkeit,
- Unterstützung langer Dateien und Zeitstempel,
- Cancellation und Fortschritt,
- macOS-14- und Universal-Build-Kompatibilität,
- Lizenz- und Modelllizenzkompatibilität mit MIT,
- Wartungsaktivität und reproduzierbare Versionierung.

Marketingangaben eines Frameworks ersetzen keine Messung mit FlowDictate-Aufnahmen. Die veröffentlichte Standardengine muss auf mindestens einem Baseline-Mac der ersten Apple-Silicon-Generation akzeptabel laufen.

## 10. Modellverwaltung

### 10.1 Modellmanifest

```swift
struct LocalModelDescriptor: Codable, Sendable, Equatable {
    var id: String
    var engineID: String
    var displayName: String
    var version: String
    var languages: [String]
    var downloadBytes: Int64
    var installedBytes: Int64
    var checksum: String?
    var licenseIdentifier: String
    var minimumOSVersion: String
    var supportedArchitectures: [String]
}
```

### 10.2 Anforderungen

- Modelle sind nicht Bestandteil der Community-ZIP, sofern Lizenz oder Größe dies nicht ausdrücklich sinnvoll machen.
- Vor Download werden Größe, freier Speicher, Quelle und Datenschutzwirkung angezeigt.
- Downloads verwenden eine temporäre Datei und werden erst nach Integritätsprüfung atomar aktiviert.
- Abbruch oder App-Neustart hinterlässt kein scheinbar installiertes Teilmodell.
- Ein aktives oder für einen recoverbaren Job benötigtes Modell darf nicht ohne Warnung entfernt werden.
- Modelle können vollständig gelöscht und später erneut installiert werden.
- Unbekannte oder manuell veränderte Modelldateien werden nicht stillschweigend ausgeführt.

## 11. Persistierter Einzeljob

### 11.1 Zielverhalten

```text
Recording A ──Stop──> Job A processing ──> Insert A ──> Ready for Recording B
```

Eine neue Aufnahme bleibt deaktiviert, solange der vorherige Job transkribiert, segmentiert, enhanced oder eingefügt wird.

### 11.2 Verarbeitungsregeln

- höchstens eine aktive Aufnahme,
- höchstens ein verarbeitender Job,
- kein neuer Aufnahmestart während eines verarbeitenden Jobs,
- ein regulär beendetes Diktat startet ohne absichtliche Wartezeit,
- keine konkurrierenden automatischen Einfügungen,
- ein Job gilt erst nach atomarer Persistenz als angenommen,
- ein pausierter Long-Form-Job wechselt in einen recoverbaren Historyzustand und gibt danach den Aufnahmestart wieder frei,
- nach Neustart gefundene Jobs werden kontrolliert recoverbar gemacht; eine unsichere automatische Einfügung unterbleibt.

### 11.3 Einfügungsreihenfolge und Ziel

- Jeder Job friert `FocusTarget`, Bundle-Identifier, effektives App-Profil und Einfügungspräferenz beim Aufnahmestart ein.
- Ein in-memory AX-Element wird nicht als dauerhaft persistierbar behandelt.
- Solange das Ziel verfügbar ist, wird genau einmal eingefügt.
- Ist das Ziel nicht mehr sicher verfügbar, wird nicht in die aktuell zufällig fokussierte App geschrieben.
- Der Text bleibt in History und Zwischenablage; der Job erhält `insertionDeferred` oder `insertionFailed`.
- Nach App-Neustart werden recoverte Jobs nie automatisch in eine fremde App eingefügt. Der Nutzer verwendet Retry/Restore bewusst.

### 11.4 Abbruch und Pause

- Cancel während Aufnahme betrifft nur die aktive Aufnahme und ruft keinen Provider auf.
- Cancel oder Aufgabe eines recoverbaren Jobs behält Aufnahme und History gemäß bestehender Recoveryregel.
- Pause eines laufenden Long-Form-Jobs erfolgt an einer atomaren Segmentgrenze.
- App-Beenden persistiert den Jobzustand vor kontrolliertem Shutdown, soweit macOS Zeit gewährt.
- Ein harter Prozessabbruch wird beim nächsten Start aus Job- und Sessiondateien normalisiert.

## 12. Datenmodell

### 12.1 Jobstatus

```swift
enum DictationJobStatus: String, Codable, Sendable {
    case queued
    case preparing
    case transcribing
    case correcting
    case formatting
    case enhancing
    case readyToInsert
    case inserting
    case completed
    case paused
    case failed
    case cancelled
    case insertionDeferred
}
```

### 12.2 Dictation Job

```swift
struct DictationJob: Codable, Sendable, Identifiable {
    var schemaVersion: Int
    var id: UUID
    var recordID: UUID
    var createdAt: Date
    var updatedAt: Date
    var queueSequence: Int64
    var audioRelativePath: String
    var audioSource: RecordingAudioSource
    var providerID: String
    var engineID: String
    var modelID: String
    var executionLocation: ExecutionLocation
    var language: String?
    var targetBundleIdentifier: String?
    var effectiveConfiguration: PersistedDictationConfiguration
    var status: DictationJobStatus
    var correctionSummary: CorrectionSummary?
    var insertionAttemptCount: Int
    var lastErrorCategory: DictationErrorCategory?
    var lastErrorMessage: String?
}
```

Geheime Credentials, absolute private Pfade und AX-Objekte sind kein Bestandteil des Jobs.

### 12.3 Invarianten

- `queueSequence` ist stabil und pro Installation monoton.
- Ein Job referenziert genau einen Historyrecord.
- Ein Job wird erst verarbeitet, nachdem die Aufnahme dauerhaft gespeichert ist.
- `completed` setzt finales, nicht leeres Ergebnis und abgeschlossene oder bewusst zurückgestellte Einfügung voraus.
- Provider/Engine/Modell ändern sich innerhalb eines Jobs nicht.
- Ein finaler Text wird höchstens einmal automatisch eingefügt.
- Job- und Long-Form-Sessionstatus dürfen sich nicht widersprechen.

## 13. Persistenz und Recovery

- Jobmanifeste werden separat von `dictations.json` atomar gespeichert.
- History enthält eine kompakte Jobzusammenfassung und Referenz.
- Erfolgreiche Textstufen werden vor dem nächsten irreversiblen Schritt gespeichert.
- Beim Start werden `preparing`, `transcribing`, `enhancing` und `inserting` in sichere unterbrochene Zustände normalisiert.
- Ein unterbrochenes `inserting` wird nicht automatisch wiederholt, weil der Text bereits angekommen sein könnte. Die UI bietet Copy/Restore an.
- Erfolgreiche Long-Form-Segmente werden auch bei Queue-Recovery nicht erneut transkribiert.
- Fehlende oder beschädigte Jobmanifeste überschreiben weder History noch Originalaudio.
- Retention schützt wartende, pausierte und fehlgeschlagene Jobs sowie deren benötigte Modelle/Sessiondateien.

## 14. Inline-Korrekturen

### 14.1 Umfang

Korrekturen wirken ausschließlich auf den Rohtext desselben Diktats vor Spoken Formatting, Wörterbuch und optionalem AI-Enhancement.

Pflichtbefehle Deutsch/Englisch:

- `ersetze X durch Y` / `replace X with Y`,
- `ersetze alle X durch Y` / `replace all X with Y`,
- `lösche das letzte Wort` / `delete the last word`,
- `lösche den letzten Satz` / `delete the last sentence`,
- `widerrufe die letzte Korrektur` / `undo the last correction`,
- bestehender Literal-Escape `wörtlich` / `literal`.

### 14.2 Semantik

- Ohne `alle` wird das letzte passende Vorkommen vor dem Befehl geändert.
- Quell- und Zielphrase dürfen nicht leer sein.
- Unsichere oder mehrdeutige Befehle bleiben als normaler Text erhalten und werden gezählt/diagnostiziert, nicht geraten.
- Korrekturen dürfen keine URLs, E-Mail-Adressen oder geschützten Dictionarybegriffe unbeabsichtigt verändern.
- Jeder angewandte Befehl erzeugt einen lokalen, inhaltsarmen Summaryeintrag; Originaltranskript und korrigierte Stufe bleiben in History erhalten.
- Eine Korrektur darf nie Aktionen in der Ziel-App auslösen.

### 14.3 Textpipeline

```text
Provider transcript
  → InlineCorrectionProcessor
  → SpokenFormattingProcessor
  → PersonalDictionaryProcessor
  → optional TranscriptEnhancer
  → final text
  → insertion
```

## 15. UX und Settings

### 15.1 Transcription Settings

- Privacy-/Ausführungsmodus,
- Provider,
- Engine und Modell,
- Hardware-/OS-Verfügbarkeit,
- Modellgröße und Installationsstatus,
- Testtranskription ohne Historyeintrag,
- OpenAI-Key nur anzeigen/verlangen, wenn ein Cloudpfad gewählt ist,
- verständlicher Status `Runs on this Mac` oder `Sends audio to OpenAI`.

### 15.2 Processing-Feedback

- Nach Stop wird die Aufnahme sofort als lokal gesichert und anschließend als `Processing` angezeigt.
- Menu und History zeigen Provider, Status und Recoveryaktion.
- `Processing` unterscheidet lokale Vorbereitung und Providerwartezeit in den Diagnoselogs.
- `Inserted` wird kurz bestätigt und darf die anschließende Aufnahmefreigabe nicht unnötig verzögern.

### 15.3 Onboarding

- Nutzer wählen `Local` oder `OpenAI`.
- Local führt durch Hardwareprüfung und Modelldownload, nicht durch API-Key-Eingabe.
- OpenAI behält Keychainvalidierung.
- Wechsel bleibt später möglich.
- Ein Upgrade von 3.4 zeigt kein erzwungenes neues Onboarding und behält OpenAI als Default.

## 16. Concurrency- und Ressourcenverträge

- Aufnahmecallbacks, lokale Inferenz, Audioexport, Modellprüfung und Netzwerk laufen nicht auf dem Main Actor.
- UI erhält begrenzte, monotone Statusereignisse.
- Jobsteuerung und Jobstore sind Actor-isoliert.
- Modellinstanzen besitzen einen klaren Lifecycle und werden nicht pro Segment unnötig neu geladen.
- Lokale Inferenz darf Mikrofonaufnahme, Pegelanzeige, Stop/Cancel oder globale Hotkeys nicht blockieren.
- Bei thermischer oder speicherbedingter Überlastung wird Verarbeitung pausiert oder verständlich abgebrochen; Originalaufnahme und Jobzustand bleiben erhalten.
- Cancellation wird an lokale Engine, Segmentexport, Providerrequest und Retry-Sleep weitergereicht.

## 17. Performanceziele

Vorläufige Budgets auf einem dokumentierten Referenz-Mac; die Engine-Evaluierung darf sie begründet schärfen:

| Messgröße | Ziel |
|---|---|
| Hotkey bis sichtbare Aufnahme | p95 ≤ 150 ms |
| Stop bis Job atomar persistiert ist | p95 ≤ 200 ms nach Recorderfinalisierung |
| Jobpersistenz bis Start der Audioaufbereitung | p95 ≤ 250 ms |
| längste zusammenhängende 4.0-Arbeit auf Main Actor | ≤ 50 ms |
| Progressupdates | höchstens 10/s je sichtbarer Anzeige |
| Warmstart, lokale Transkription von 30 s Sprache | Ziel p95 ≤ 5 s auf Baseline-Apple-Silicon-Mac |
| Cold Model Load bis sichtbarer Fortschritt | ≤ 2 s; Gesamtdauer sichtbar und abbrechbar |
| Peak-RAM des empfohlenen Standardmodells | Ziel ≤ 2 GB zusätzlich |
| wartende Audiojobs im RAM | keine vollständigen Audiodateien; dateibasiert |
| Main-Actor-Reaktion während lokaler Inferenz/Uploadvorbereitung | keine sichtbaren UI- oder Hotkey-Hitches |

Netzwerkdauer erhält kein hartes Ziel. Unmittelbarer Jobstart, UI-Reaktion, Timeout und Recovery bleiben unabhängig davon verbindlich.

## 18. Migration

### 18.1 Vorgesehene Schemata

- `historySchema`: 5 → 6,
- `dictationRecordSchema`: 5 → 6,
- neues `dictationJobSchema`: 1,
- `transcriptionSessionSchema`: bleibt kompatibel oder wird nur additiv erweitert,
- Settings nur additiv mit sicheren Defaults.

### 18.2 Regeln

- Vor dem ersten Schema-6-Schreiben entsteht einmalig `dictations-pre-4.0.json`.
- Bestehende Backups werden nicht überschrieben.
- Alte Records erhalten keine synthetischen Jobs.
- Bestehende abgeschlossene und fehlgeschlagene 3.4-Records bleiben inhaltlich unverändert.
- Bestehender Providerdefault ist OpenAI; kein Upgrade lädt automatisch ein Modell.
- App-Profile ohne Providerfeld erben den globalen Provider.
- API-Key bleibt im Keychain und wird weder exportiert noch in neue Jobdateien kopiert.
- Eine unbekannte neuere Schema-Version wird nicht überschrieben.

## 19. Datenschutz und Sicherheit

- Offline-Modus ist technisch testbar und nicht nur eine UI-Bezeichnung.
- Modellquellen, Versionen, Checksums und Lizenzen werden dokumentiert.
- Modelldownloads sind keine Transkriptionsuploads und werden in der UI getrennt erklärt.
- Audio, Transkripte und Dictionarydaten werden nicht für Modelltraining übertragen.
- Cloudrequests gehen weiterhin direkt vom Gerät zum ausdrücklich gewählten Provider.
- Keine lokale Engine darf private Inhalte loggen.
- Joblogs enthalten nur IDs, Dauer, Größen, Status und inhaltsfreie Zeiten.
- Passwortfelder bleiben für Einfügung und Kontextzugriff geschützt.
- Community-ZIP enthält keine Modelle, Credentials, persönlichen Testaufnahmen oder privaten Fixtures, sofern nicht ausdrücklich anders freigegeben.

## 20. Tests

### 20.1 Unit-Tests

- Provider Registry und Capabilities,
- Hardware-/OS-/Architekturverfügbarkeit,
- kein API-Key-Zwang für Local,
- API-Key-Zwang für OpenAI,
- Offline-Modus ruft keinen Netzwerkclient auf,
- kein stiller Local-to-Cloud-Fallback,
- Modelldescriptor, Downloadzustände, Checksumfehler und atomare Aktivierung,
- unmittelbarer Verarbeitungsstart eines persistierten Jobs,
- neue Aufnahme während Jobverarbeitung gesperrt,
- eingefrorene Konfiguration und App-Profile,
- Einfügung genau einmal,
- Ziel nicht verfügbar → deferred statt falscher App,
- Normalisierung unterbrochener Jobzustände,
- Jobmanifest Roundtrip und beschädigte Fixtures,
- Retention schützt aktive und recoverbare Jobs,
- Long-Form-Resume mit identischem lokalen Modell,
- fehlendes Modell pausiert statt Cloudfallback,
- Korrekturbefehle Deutsch/Englisch,
- letztes gegenüber allen Vorkommen,
- Undo, Literal-Escape, URLs und Mehrdeutigkeit,
- Migration Schema 5 → 6 mit Backup,
- bestehende OpenAI- und 3.4-Regressionstests.

### 20.2 Integrationstests

- lokale kurze Transkription ohne gespeicherten API-Key,
- lokale segmentierte Langtranskription mit Pause/Resume,
- OpenAI-Single- und Long-Form-Pfade unverändert,
- Aufnahme B und C während Verarbeitung A,
- FIFO-Verarbeitung und Einfügung A/B/C,
- Appwechsel zwischen Aufnahmen mit getrennten Zielobjekten,
- Relaunch mit queued, transcribing und ready-to-insert Jobs,
- Offline-/Online-Wechsel ohne verdeckten Request,
- Modell während pausiertem Job fehlt und wird wiederhergestellt,
- wenig Speicher vor Modelldownload und Inferenz,
- Smart Dictation lokal sowie optionale Cloud-Nachbearbeitung,
- Systemaudio mit lokaler Engine,
- Intel-Build und OpenAI-Smoke, falls Universal-Support beibehalten wird.

### 20.3 Qualitätskorpus

Ein lokales, veröffentlichbares oder synthetisches Korpus enthält mindestens:

- kurze und lange deutsche Diktate,
- kurze und lange englische Diktate,
- Fachbegriffe und persönliche Wörterbuchbegriffe,
- Zahlen, Daten, URLs, E-Mail-Adressen und Satzzeichen,
- leise/laute Sprache und moderate Hintergrundgeräusche,
- gemischte deutsche/englische Begriffe,
- Korrekturbefehle und Literal-Escapes.

Es werden Wortfehlerrate beziehungsweise nachvollziehbare textuelle Differenzen, Latenz, RAM und Modellgröße dokumentiert. Persönliche Nutzeraufnahmen gelangen nicht ins Repository.

### 20.4 Manuelle Tests

- Apple Silicon der Baseline-Generation und aktueller Referenz-Mac,
- Intel-Mac, falls Universal-Support erhalten bleibt,
- macOS 14 sowie aktuelles unterstütztes macOS,
- lokaler Erstdownload, Abbruch, Wiederaufnahme, Löschen und Neuinstallation,
- Start ohne Netzwerk und ohne API-Key,
- Wechsel Local/OpenAI/Offline,
- fünf schnell aufeinanderfolgende Diktate,
- lange lokale Aufnahme während neuer Mikrofonaufnahme,
- Notes, Mail, Browser, VS Code/Codex und TextEdit,
- Appwechsel und geschlossenes Einfügungsziel,
- Quit/Crash/Neustart an jeder Jobphase,
- Systemaudio lokal und OpenAI,
- Korrekturen Deutsch und Englisch,
- wenig Speicher, hohe CPU-Last und thermische Last.

## 21. Community-ZIP- und Release-Gate

Vor Tag oder GitHub Release müssen:

1. alle Unit- und Integrationstests erfolgreich sein,
2. Debug- und Release-Build erfolgreich sein,
3. finale Engine- und Modelllizenzen dokumentiert sein,
4. `git diff --check` sauber sein,
5. Community-ZIP und SHA-256 erzeugt und geprüft sein,
6. exakt die entpackte ZIP-App signatur- und architekturgeprüft sein,
7. exakt diese App Local ohne API-Key und OpenAI mit Key bestehen,
8. Offline-Modus mit Netzwerkbeobachtung keinen unerlaubten Request erzeugen,
9. exakt diese App mindestens drei aufeinanderfolgende Diktate ohne zusätzliche Queue-Wartezeit korrekt verarbeiten und einfügen,
10. mindestens ein lokaler Long-Form-Resume ohne erneute erfolgreiche Segmente bestehen,
11. bestehende Mikrofon-, Systemaudio-, History-, Profile- und Smart-Dictation-Smokes bestehen,
12. Universal-/Intel-Gate oder Apple-Silicon-only-Entscheidung ausdrücklich dokumentiert sein.

Keine Veröffentlichung erfolgt allein aufgrund erfolgreicher Xcode-Tests.

## 22. Akzeptanzkriterien

Phase 4.0 ist produktseitig abgeschlossen, wenn:

- [ ] mindestens eine lokale Engine die Qualitäts- und Performancefreigabe erreicht,
- [ ] ein neuer Nutzer ohne API-Key lokal diktieren kann,
- [ ] ein Upgrade unverändert OpenAI verwendet, bis der Nutzer wechselt,
- [ ] Offline-Modus keine Cloudrequests ausführt,
- [ ] Provider und Modell je Job stabil und in History sichtbar sind,
- [ ] eine neue Aufnahme während vorheriger Verarbeitung zuverlässig gesperrt ist,
- [ ] aufeinanderfolgende Diktate jeweils unmittelbar verarbeitet werden,
- [ ] automatische Einfügung höchstens einmal und nie in ein falsches Ziel erfolgt,
- [ ] persistierte Jobs und Long-Form nach Neustart recoverbar sind,
- [ ] Inline-Korrekturen deterministisch und literal escapebar sind,
- [ ] lokale Inferenz Aufnahme, Overlay und Hotkeys nicht blockiert,
- [ ] Modelldownload, Prüfung, Abbruch und Entfernen sicher funktionieren,
- [ ] Schema-6-Migration bestehende History und Textstufen bewahrt,
- [ ] 3.4-Funktionen regressionsfrei sind,
- [ ] finale Community-ZIP vollständig abgenommen ist.

## 23. Risiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| lokale Qualität schlechter als OpenAI | transparentes Engineprofil, Korpusmessung, OpenAI bleibt wählbar |
| Modell zu groß/langsam für Baseline-Mac | Standardmodellbudget, Hardwareprüfung, alternative Engine |
| Bibliothek verhindert Universal-Build | früher Architekturspike und explizites Intel-Gate |
| Aufnahme verliert Samples unter Inferenzlast | sequenzielle Verarbeitung, Priorität der Capturepfade, Belastungstest |
| Recovery fügt in falsche App ein | Ziel pro Job einfrieren; bei Unsicherheit deferred statt raten |
| Crash bei Einfügung führt zu Doppeltext | `inserting` nach Restart nie automatisch wiederholen |
| Offline-Modus sendet durch Nebenfunktion Daten | zentraler Network Policy Gate und injizierte Netzwerkclients |
| Modellquelle oder Datei kompromittiert | HTTPS, Versionpinning, Checksum/Signatur soweit verfügbar |
| Korrekturparser verändert ungewollten Text | konservative Grammatik, Originalstufe, Escape und Unit-Tests |
| Coordinator-Umbau regressiert 3.4 | einzelner unmittelbarer Jobpfad und breite Regressionstests |

## 24. Technische Referenzen

- [Apple SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [WWDC25: Bring advanced speech-to-text to your app](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Argmax OSS / WhisperKit](https://github.com/argmaxinc/argmax-oss-swift)
- [FluidAudio](https://github.com/FluidInference/FluidAudio)

API-, Plattform-, Framework-, Modell- und Lizenzangaben müssen zu Beginn der Implementierung und unmittelbar vor dem Release erneut gegen die Primärquellen geprüft werden. Dieses PRD legt noch keine externe Engineabhängigkeit verbindlich fest.

## 25. Definition of Done

Phase 4.0 ist erst abgeschlossen, wenn Implementierung, Migration, dokumentiertes Engine-Benchmarking, automatisierte Tests, manuelle Belastungstests und Abnahme der finalen Community-ZIP erfolgreich sind. Ein Tag, Asset-Upload oder GitHub Release benötigt wie bisher einen separaten ausdrücklichen Veröffentlichungsauftrag.
