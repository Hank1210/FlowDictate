# FlowDictate – Arbeitsplan Phase 3.4

**Phase:** 3.4 – Long-Form Transcription & Responsiveness
**Status:** 3.4.0 (Build 8) lokal freigegeben; Veröffentlichung am 25. August 2026 ausdrücklich beauftragt
**Stand:** 25. August 2026
**Ausgangsbasis:** FlowDictate 3.3.0, Build 7, Commit `174a88b`, Tag `v3.3.0`
**Anforderungsgrundlage:** `FlowDictate_PRD_Phase_3_4.md`

## 1. Ziel und Lieferregel

Phase 3.4 führt eine quellenunabhängige, lokale Segmentpipeline für lange Mikrofon- und Systemaudioaufnahmen ein. Segmenttranskripte werden geordnet, atomar und fortsetzbar gespeichert. Bereits erfolgreiche Abschnitte werden nach Fehler oder Neustart nicht erneut hochgeladen. Lange Aufnahme- und Verarbeitungsvorgänge bleiben UI- und Hotkey-responsiv.

Die Phase endet nicht mit einem erfolgreichen Xcode-Build. Sie endet erst nach automatisierter Regression, manueller Langzeit- und Recoveryabnahme sowie Test der finalen, mit `./scripts/build-community-release.sh` erzeugten Community-ZIP.

Bis zu diesem Gate gilt ausdrücklich:

- keine Versionsveröffentlichung,
- kein neuer Release-Tag,
- kein GitHub Release,
- kein Upload eines Community-Artefakts,
- keine Behauptung, dass Phase 3.4 abgeschlossen sei.

## 2. Festgelegter Umfang

### 2.1 Pflichtumfang

1. technische Baseline und Performanceprofil,
2. Main-Actor-Entkopplung der Upload- und Long-Form-Arbeit,
3. Datenmodell und atomare Sessionpersistenz,
4. Audio-Preflight und Moduswahl,
5. pausensensitive Segmentplanung,
6. begrenzter Segmentexport und Speicherprüfung,
7. sequenzielle segmentweise Transkription,
8. deterministischer Merge,
9. Progress, Pause, Retry und Resume,
10. Start-Recovery, Retention und M4A-Orphan-Erkennung,
11. vollständige Regression und Performanceabnahme,
12. Dokumentation und finale Community-ZIP-Abnahme.

### 2.2 Bewusst zurückgestellt

- parallele Netzwerkrequests,
- kombinierte Mikrofon-/Systemaudioaufnahme,
- Speaker-Diarization,
- lokaler finaler Provider,
- SQLite,
- Kostenschätzung mit dynamischen Modellpreisen,
- Bulk-Export und Profilimport/-export,
- AX-Kompatibilitätscache.

## 3. Technische Leitplanken

- Der bestehende Einzelupload bleibt der Standard für kurze, sicher uploadfähige Aufnahmen.
- Segmentierung wird nicht anhand der Audioquelle, sondern anhand technischer Preflightdaten gewählt.
- Netzwerkparallelität bleibt fest auf `1`.
- Es darf höchstens ein Segment lokal voraus vorbereitet werden.
- Die Originalaufnahme wird niemals verändert.
- Ein erfolgreiches Teiltranskript wird vor dem nächsten Upload atomar gespeichert.
- Teiltranskripte lösen keine automatische Einfügung aus.
- Segmentdetails liegen in einer separaten Sessiondatei; History enthält nur Zusammenfassung und Referenz.
- Alle schweren Audio-, Datei- und Netzwerkoperationen laufen außerhalb des Main Actors.
- API-Grenzwerte sind zentral definiert und vor Release gegen die offizielle Dokumentation zu prüfen.
- Jeder Arbeitsschritt endet mit Tests und einem eigenen Gate.

## 4. Geplante Komponenten und Dateien

Voraussichtliche neue Dateien:

```text
FlowDictate/Transcription/LongForm/
├── AudioAssetInspector.swift
├── AudioSegmentPlanner.swift
├── SilenceBoundaryDetector.swift
├── AudioSegmentExporter.swift
├── LongFormTranscriptionModels.swift
├── TranscriptionSessionStore.swift
├── LongFormTranscriptionRunner.swift
├── PartialTranscriptMerger.swift
└── TranscriptionPerformanceRecorder.swift
```

Voraussichtlich zu ändern:

```text
FlowDictate/Transcription/TranscriptionProvider.swift
FlowDictate/Transcription/OpenAITranscriptionProvider.swift
FlowDictate/Transcription/TranscriptionRunner.swift
FlowDictate/Transcription/MultipartUploadFileBuilder.swift
FlowDictate/Audio/AudioUploadPreparer.swift
FlowDictate/Audio/SystemAudioRecorder.swift
FlowDictate/Audio/AudioStore.swift
FlowDictate/App/DictationCoordinator.swift
FlowDictate/App/DictationState.swift
FlowDictate/Overlay/RecordingOverlayController.swift
FlowDictate/History/DictationRecord.swift
FlowDictate/History/DictationHistoryStore.swift
FlowDictate/History/HistoryView.swift
FlowDictate/Recovery/DictationFailureClassifier.swift
FlowDictate/Utilities/FlowDictateVersion.swift
FlowDictateTests/FlowDictateTests.swift
```

Die tatsächliche Dateiaufteilung darf während der Implementierung angepasst werden, solange Verantwortlichkeiten und Testbarkeit erhalten bleiben. Der `DictationCoordinator` darf keine eigene Segmentzustandsmaschine aufnehmen.

## 5. Lieferübersicht

| Schritt | Ergebnis | Releasefähig? |
|---|---|---|
| 3.4.0 | reproduzierbare Baseline, Fixtures und Signposts | nein |
| 3.4.1 | Concurrency- und Providerverträge außerhalb Main Actor | nein |
| 3.4.2 | Schema 5 und atomarer SessionStore | nein |
| 3.4.3 | Preflight, Moduswahl und Speicherprüfung | nein |
| 3.4.4 | pausensensitive Planung und Segmentexport | nein |
| 3.4.5 | sequenzielle Long-Form-Transkription und Merge | nein |
| 3.4.6 | Progress, Pause, History-Retry und Resume | nein |
| 3.4.7 | Start-Recovery, Retention und Orphan-Fixes | nein |
| 3.4.8 | Performanceoptimierung und Gesamtregression | nein |
| 3.4.9 | Dokumentation und finale Community-ZIP-Abnahme | lokal freigabefähig |

Ein Schritt beginnt erst nach erfülltem Gate des vorherigen Schritts. Kritische Baseline-Fixes werden separat committet und nicht mit der Segmentlogik vermischt.

## 6. Schritt 3.4.0 – Baseline, Fixtures und Messung

### 6.1 Aufgaben

- Arbeitsbaum und Releasebaseline erneut bestätigen.
- Vorhandenen Unit-Testbefehl unverändert ausführen und Ergebnis protokollieren.
- `git diff --check`, Debug-Build und einen lokalen Release-Build ausführen.
- Kurze Mikrofon- und Systemaudio-Smokes durchführen.
- Datenschutzfreie Testassets bereitstellen oder deterministisch während Tests erzeugen:
  - kurze Monoaufnahme,
  - Audio mit klarer Pause nahe Segmentgrenze,
  - Audio ohne geeignete Pause,
  - Audio mit Musik plus Sprache,
  - beschädigte beziehungsweise leere Datei.
- Lange Performanceassets nicht in Git aufnehmen; stattdessen Erzeugung oder lokalen Speicherort dokumentieren.
- `OSSignposter`-Messpunkte ergänzen für:
  - Hotkey → `finalizing`,
  - `stopCapture`,
  - Capture-Queue-Drain,
  - Writer-Finalisierung,
  - Uploadvorbereitung und Multipart-Erzeugung.
- 5-, 30- und möglichst 60-minütige Systemaudioaufnahme mit Instruments messen.
- Main Thread Hangs, Time Profiler, Allocations und File Activity erfassen.
- Aktuelle Zeit- und Speicherwerte als Baseline im Arbeitsstand dokumentieren.

### 6.2 Frühe Baseline-Fixes

Nur klar isolierte Fehler dürfen hier korrigiert werden:

- Orphan-Erkennung um originale M4A-Aufnahmen erweitern,
- Arbeitsdateipräfixe eindeutig von Originalaufnahmen trennen,
- veraltete temporäre Upload-/Multipart-Dateien weiter sicher bereinigen,
- keine Segmentfunktion vorziehen.

### 6.3 Tests

- vorhandene Unit-Suite,
- Test, dass M4A-Orphans erkannt werden,
- Test, dass zukünftige Session-Arbeitsdateien nicht als Diktat importiert werden,
- manueller Stop-Reaktionstest mit sichtbarem Overlay,
- Instruments-Messung ohne Transkript- oder Audioinhalte in Logs.

### 6.4 Gate

- Baseline-Tests sind grün.
- Messpunkte erzeugen verwertbare, inhaltsfreie Daten.
- mindestens ein reproduzierbares Langzeitprofil liegt vor.
- bekannte Main-Actor- oder I/O-Hotspots sind mit Datei und Messwert benannt.
- keine Verhaltensänderung am Transkriptionspfad.

## 7. Schritt 3.4.1 – Concurrency- und Providerfundament

### 7.1 Ziel

Uploadvorbereitung, Providerrequest und spätere Long-Form-Orchestrierung dürfen nicht pauschal auf dem Main Actor laufen. UI-Status bleibt Main-Actor-isoliert.

### 7.2 Aufgaben

- `AudioUploadPreparing` von unnötiger Main-Actor-Isolation lösen.
- `AudioUploadPreparer` als Sendable-sichere Komponente oder Actor ausführen.
- `OpenAITranscriptionProvider` von unnötiger Main-Actor-Isolation lösen.
- `TranscriptionRunner` so strukturieren, dass Persistenz über Actors und UI-Updates über explizite Progressereignisse erfolgen.
- `TranscriptionRequest` additiv um optionalen `prompt` erweitern.
- Multipart-Felder um `prompt` ergänzen, wenn nicht leer.
- Cancellation bis `URLSession.upload`, Konvertierung und temporäre Dateibereinigung prüfen.
- Test-Doubles concurrency-sicher machen.
- UI-affine Keychain- oder Settingszugriffe vor Runnerstart als unveränderliche Sessionkonfiguration auflösen.

### 7.3 Verträge

```swift
nonisolated struct TranscriptionRequest: Sendable {
    let audioURL: URL
    let language: String?
    let prompt: String?
}
```

- Provider erhält keine mutable Settingsreferenz.
- API-Key wird vor Start sicher aufgelöst und nicht persistiert.
- Audio- und Multipartdateien werden auch bei Cancellation bereinigt.
- bestehende Provider-Stubs bleiben verwendbar.

### 7.4 Tests

- bestehender Einzelupload und Retry,
- Multipart ohne Prompt bleibt byteinhaltlich erwartbar,
- Multipart mit Prompt enthält genau ein korrektes Feld,
- leerer Prompt wird nicht gesendet,
- Cancellation löscht temporäre Dateien,
- langsamer Stub-Provider blockiert einen Main-Actor-Testmarker nicht,
- API-Key wird weiterhin nur einmal je App-Session aus dem Keychaincache gelesen.

### 7.5 Gate

- alle bisherigen Tests bestehen,
- der kurze Diktierpfad arbeitet funktional unverändert,
- ein langsamer Provider blockiert Overlay und Main-Actor-Testprobe nicht,
- keine unsicheren `nonisolated(unsafe)`-Erweiterungen werden nur zur Umgehung von Compilerfehlern eingeführt.

## 8. Schritt 3.4.2 – Datenmodell, Migration und SessionStore

### 8.1 Aufgaben

- `FlowDictateVersion.historySchema` und `dictationRecordSchema` von 4 auf 5 erhöhen.
- additive Summaryfelder aus dem PRD in `DictationRecord` aufnehmen.
- migrationssichere `CodingKeys` und Defaults implementieren.
- einmaliges Backup `dictations-pre-3.4.json` vor erstem Schema-5-Schreiben erzeugen.
- bestehendes `dictations-pre-3.2.json` niemals überschreiben.
- Long-Form-Session-, Segment- und Fingerprintmodelle implementieren.
- Modellinvarianten zentral validieren.
- `TranscriptionSessionStore` als Actor implementieren.
- atomare Manifestpersistenz mit temporärer Datei und sicherem Replace implementieren.
- optional letzte gültige Backupkopie für ein laufendes Replace vorhalten.
- Sessionverzeichnis aus Record-ID ableiten und Pfadtraversal verhindern.
- CRUD für Manifest und reproduzierbare Arbeitsdateipfade implementieren.
- Sessionauflistung für Start-Recovery bereitstellen.

### 8.2 Commit-Reihenfolge bei Segmenterfolg

Verbindliche Reihenfolge:

1. Providerergebnis vollständig erhalten und validieren.
2. Segmenttext und `succeeded` in neues Manifest schreiben.
3. Manifest atomar ersetzen.
4. History-Summary auf X von Y aktualisieren.
5. Erst danach nächstes Segment vorbereiten oder hochladen.

Schlägt Schritt 3 fehl, darf Schritt 5 nicht stattfinden. Schlägt nur Schritt 4 fehl, stoppt die Session, bis Manifest und History abgeglichen wurden.

### 8.3 Migrationstests

- echtes Schema-4-Fixture mit Systemaudiofeldern,
- Schema-3-/älteres Fixture über bestehende Migration,
- Backup wird genau einmal erzeugt,
- vorhandenes Backup bleibt unverändert,
- unbekannte zusätzliche Felder verursachen keinen Datenverlust soweit Codable-Vertrag dies erlaubt,
- alte Records erhalten keine fiktive Session,
- vorhandene Original-, Format-, Dictionary- und Finaltexte bleiben identisch,
- beschädigte History überschreibt weder Quelle noch Backup.

### 8.4 SessionStore-Tests

- Roundtrip aller Statuswerte,
- stabile Datums- und Integer-Zeitcodierung,
- parallele Updates werden serialisiert,
- abgebrochener Write lässt letzte gültige Datei lesbar,
- ungültige Segmentreihenfolge wird abgelehnt,
- `succeeded` ohne Text wird abgelehnt,
- unbekannte neuere Schemaversion wird nicht überschrieben,
- Verzeichnis- und Dateinamen enthalten keine Transkriptinhalte.

### 8.5 Gate

- alle Migrationstests bestehen,
- Backup- und Rollbackverhalten ist nachgewiesen,
- SessionStore verliert bei simuliertem Schreibfehler keinen zuletzt bestätigten Segmenterfolg,
- noch kein Netzwerk- oder UI-Pfad verwendet die neuen Sessions produktiv.

## 9. Schritt 3.4.3 – Audio-Preflight, Moduswahl und Speicherprüfung

### 9.1 AudioAssetInspector

Ermitteln:

- Datei vorhanden und regulär lesbar,
- Dateigröße,
- Dauer,
- Sample-Rate und Kanalzahl soweit verfügbar,
- Container/Dateiendung und kompatibler Codec,
- Audio enthält verwertbare Samples,
- bereits kompakt oder Konvertierung erforderlich.

Die Inspektion lädt nicht das gesamte Asset in den Speicher.

### 9.2 TranscriptionModeResolver

Ergebnis:

```swift
nonisolated enum TranscriptionPreparationMode: Sendable, Equatable {
    case singleFile
    case longForm(reason: LongFormReason)
}
```

Entscheidungsparameter zentral kapseln:

- 15 Minuten Zieldauer,
- ungefähr 12–17 Minuten Zielfenster,
- 20.000.000 Bytes weiches Ziel,
- 24.500.000 Bytes harte Grenze,
- mindestens 500.000 Bytes externe Reserve.

Nicht dieselben Zahlen über Provider, Preparer und Planner duplizieren.

### 9.3 Speicherprüfung

- freien Speicher am tatsächlichen Arbeitsvolume bestimmen,
- größtes gleichzeitiges Segment plus Multipart plus Reserve schätzen,
- mindestens 250 MB Sicherheitsreserve vorsehen,
- bei unbekanntem Speicherstatus konservativ fehlschlagen oder einen eindeutig sicheren Pfad nutzen,
- kein Netzwerkzugriff bei unzureichendem Speicher,
- Benutzerfehler nennt benötigten und verfügbaren Umfang ohne private Pfade zu loggen.

### 9.4 Tests

- kleine M4A → Einzelupload,
- große M4A → Long Form,
- lange, aber kleine Datei → Long Form nach Dauer,
- WAV mit unsicherer vorbereiteter Größe → konservative Entscheidung,
- exakt weiches und hartes Grenzverhalten,
- leere und beschädigte Datei,
- fehlende Datei,
- ausreichend/zu wenig/unbekannter freier Speicher,
- Provider wird bei Preflightfehler nie aufgerufen.

### 9.5 Gate

- kurze 3.3-Aufnahmen bleiben im Einzelpfad,
- lange und zu große Assets werden zuverlässig erkannt,
- Größenwerte existieren nur in zentraler Konfiguration,
- jeder Preflightfehler bewahrt die Originalaufnahme und verhindert Netzwerkzugriff.

## 10. Schritt 3.4.4 – Pausensensitive Planung und Segmentexport

### 10.1 AudioSegmentPlanner

- nominale Grenzen nach Zieldauer erzeugen,
- Suchfenster um jede Grenze definieren,
- ersten und letzten Bereich korrekt klemmen,
- Segmentplan in stabilen ganzzahligen Zeiteinheiten darstellen,
- erlaubte Überlappung explizit speichern,
- vollständige Abdeckung validieren.

### 10.2 SilenceBoundaryDetector

- nur begrenzte PCM-Fenster dekodieren,
- RMS/Energie in kleinen Buckets berechnen,
- Glättung und Mindestpausenlänge anwenden,
- Kandidaten nach Energie und Zielnähe bewerten,
- kein Kandidat → deterministischer Zeitfallback,
- Musik oder dauerhafte Hintergrundgeräusche dürfen den Planner nicht hängen lassen.

Defaultwerte werden zunächst intern gehalten und anhand Fixtures kalibriert. Jede Änderung erhält Tests.

### 10.3 Überlappung

- sichere Pause → keine oder minimale technische Überlappung,
- Zeitfallback → ungefähr 1,5 Sekunden,
- keine negative Zeit und keine Überschreitung der Assetdauer,
- Überlappung darf Größenlimit nicht verletzen.

### 10.4 AudioSegmentExporter

- M4A zeitbereichsbasiert und möglichst ohne unnötige vollständige Neukodierung exportieren,
- andere Quellen mit begrenztem Buffer in kompaktes Mono-AAC/M4A umwandeln,
- Cancellation zwischen Buffern und Exportphasen prüfen,
- Output atomar fertigstellen,
- Größe, Dauer und Lesbarkeit validieren,
- übergroßen Output deterministisch teilen,
- Arbeitsdateinamen aus Record-ID und Index erzeugen,
- Original nie überschreiben,
- höchstens aktuelles und optional nächstes Segment vorhalten.

### 10.5 Tests

#### Planner

- Dauer unter Schwelle → ein Segment,
- zwei und viele Segmente,
- Pause vor, auf und nach nominaler Grenze,
- zwei gleich gute Pausen mit deterministischem Tie-Break,
- keine Pause,
- sehr kurze Restdauer,
- Abdeckung, Reihenfolge und erlaubte Überlappung als Property-artige Tests.

#### Exporter

- M4A- und WAV-Quelle,
- Segmentdauer innerhalb Toleranz,
- valide Mono-AAC-Ausgabe,
- Post-Export-Größe unter Grenze,
- künstlich übergroß → Split vor Provideraufruf,
- Cancellation löscht unvollständige Datei,
- Schreibfehler bewahrt Original,
- Speicher bleibt bei größerem Asset begrenzt.

### 10.6 Manuelles Gate

- Segmentgrenzen mehrerer echter deutscher und englischer Sprachaufnahmen anhören,
- Pause und Fallback nachvollziehbar dokumentieren,
- exportierte Segmente einzeln abspielbar,
- keine hörbare Lücke außerhalb erlaubter Codec-Toleranz,
- kein proportionaler RAM-Anstieg mit Assetdauer,
- Main Actor bleibt während Planung und Export bedienbar.

## 11. Schritt 3.4.5 – Long-Form-Runner, Provider und Merge

### 11.1 LongFormTranscriptionRunner

Implementieren als Actor oder gleichwertig isolierte Komponente:

1. Manifest laden oder erstellen.
2. Plan und Fingerprint validieren.
3. erstes nicht erfolgreiches Segment wählen.
4. Segment bei Bedarf vorbereiten.
5. Status `uploading` atomar speichern.
6. Provider mit Audio, Sprache und Kontextprompt aufrufen.
7. Ergebnis prüfen und Segment `succeeded` atomar speichern.
8. History-Summary aktualisieren.
9. Arbeitsdatei nach sicherem Commit bereinigen.
10. mit nächstem Segment fortfahren.
11. alle Teiltexte mergen.
12. finalen Transkriptstatus in History speichern.

### 11.2 PromptBuilder

- nur vorheriges erfolgreiches Segment verwenden,
- begrenzten letzten Textausschnitt extrahieren,
- Leerraum und Steuerzeichen sicher bereinigen,
- Sprache unverändert übernehmen,
- leeren Kontext nicht senden,
- Prompt niemals loggen.

### 11.3 Segmentretry

- bestehende `DictationFailureClassifier`-Regeln wiederverwenden,
- automatische Maximalversuche pro Segment,
- Backoff testbar injizieren,
- permanente Fehler stoppen sofort,
- spätere Segmente werden nicht aufgerufen,
- Gesamtversuchszähler und Segmentversuche korrekt fortschreiben.

### 11.4 PartialTranscriptMerger

- strikt nach Index sortieren beziehungsweise unsortierten Input ablehnen,
- Originalteiltexte unverändert behalten,
- nur Suffix/Präfix-Grenzfenster vergleichen,
- Unicode und Whitespace für Vergleich normalisieren,
- ausreichend lange Übereinstimmungen konservativ entfernen,
- kurze oder unsichere Matches behalten,
- Mergeversion persistieren,
- Ergebnis muss bei erneutem Lauf identisch sein.

### 11.5 Tests

- drei Segmente erfolgreich und in Reihenfolge,
- Stubantworten kommen mit künstlich unterschiedlichen Verzögerungen, Ergebnis bleibt geordnet,
- Netzwerkparallelität überschreitet nie 1,
- Prompt 2 stammt aus Text 1, Prompt 3 aus Text 2,
- Fehler in Segment 2 ruft Segment 3 nicht auf,
- Retry ruft nur Segment 2 erneut auf,
- Persistenzfehler nach Providererfolg startet kein nächstes Segment,
- Restart mit erfolgreichen Segmenten 0/1 beginnt bei 2,
- exakte und normalisierte Grenzduplikate,
- kurze häufige Phrase wird nicht gelöscht,
- Satzzeichen- und Großschreibungsvarianten,
- Deutsch, Englisch, Bindestriche, Zahlen, URLs und Unicode,
- Mergefehler verhindert Smart Dictation und Inserter,
- Erfolg schreibt genau ein finales Originaltranskript.

### 11.6 Gate

- End-to-End-Test mit mindestens drei Segmenten besteht,
- erfolgreiche Segmente werden bei Resume nachweislich nicht erneut hochgeladen,
- Merge ist deterministisch und konservativ,
- Originalaufnahme und Teiltexte bleiben bei jedem simulierten Fehler vorhanden,
- kurzer Einzelpfad besteht unverändert.

## 12. Schritt 3.4.6 – Progress, Pause, History und Coordinator-Integration

### 12.1 Progressmodell

```swift
nonisolated enum LongFormProgress: Sendable, Equatable {
    case inspecting
    case planning
    case preparing(segment: Int, total: Int)
    case transcribing(segment: Int, total: Int, attempt: Int)
    case merging(total: Int)
    case paused(completed: Int, total: Int)
}
```

- Ereignisse sind monoton innerhalb einer Session.
- UI erhält höchstens zehn sichtbare Updates pro Sekunde.
- Segmentzahlen werden intern nullbasiert und in UI einsbasiert dargestellt.
- Progress enthält keinen Textinhalt.

### 12.2 Overlay

- Status aus dem PRD ergänzen,
- determinate Anzeige für Segmentfortschritt,
- kompakte Größe bleibt lesbar,
- Fehler zeigt Segment X von Y,
- Overlay stiehlt keinen Fokus,
- Reduced Motion respektieren,
- Erfolg weiterhin defensiv ausblenden.

### 12.3 DictationState und Coordinator

- Zustände für `preparingLongForm`, segmentiertes `transcribing` und `paused` ergänzen oder über ein klar typisiertes Submodell abbilden.
- Coordinator startet den Runner und übersetzt nur Progress in UI-State.
- Segmentzustände werden nicht im Coordinator gespeichert.
- neue Aufnahme bleibt während aktiver Verarbeitung gesperrt.
- Stop einer Aufnahme bestätigt weiter sofort `finalizing`.
- `Pause Processing` ist von `Cancel Recording` getrennt.
- Task-Cancellation wird an Runner weitergereicht.

### 12.4 History

- Summary `X of Y` anzeigen,
- partiellen Text klar kennzeichnen,
- Aktionen `Resume`, `Retry failed segment`, `Copy partial transcript`, `Reveal recording`,
- keine Aktion fügt partiellen Text automatisch ein,
- Retry-ID-Schutz verhindert doppelte Runner,
- abgeschlossener Record verhält sich wie bisher.

### 12.5 Tests

- monotone Progressereignisse,
- Overlay zeigt korrekte einsbasierte Segmentzahl,
- Pause während Planung, Export, Upload und Retry-Sleep,
- erfolgreiche Präfixsegmente bleiben nach Pause erhalten,
- zweimaliges Resume erzeugt nur eine Session,
- Settings/History-Aufruf beeinflusst Runner nicht,
- partielle Copy-Aktion, aber kein automatischer Inserteraufruf,
- vollständiger Erfolg startet Smart Dictation und Inserter genau einmal,
- Toggle und Press-and-Hold stoppen Aufnahme weiterhin genau einmal.

### 12.6 Gate

- Nutzer kann Segmentfortschritt nachvollziehen,
- Pause wird kurzfristig wirksam und ist nach App-Neustart sichtbar,
- Coordinator wächst nur um Integrationslogik, nicht um Segmentzustandsverwaltung,
- vorhandene Overlay-, Hotkey-, Preview- und Insertiontests bleiben grün.

## 13. Schritt 3.4.7 – Start-Recovery, Retention und Aufräumen

### 13.1 Reconciliation beim Start

- History laden und migrieren,
- Sessions katalogisieren,
- Record-/Session-IDs abgleichen,
- flüchtige Zustände `planning`, `preparing`, `uploading`, `merging` normalisieren,
- erfolgreiche Segmente behalten,
- keine automatische Cloudfortsetzung,
- Historyaktionen zum manuellen Resume anbieten.

### 13.2 Source-Fingerprint

Vor Resume prüfen:

- relativer Originalpfad,
- Bytezahl,
- Dauer in stabiler Einheit,
- Änderungsdatum soweit zuverlässig.

Bei Abweichung:

- kein stilles Resume,
- `sourceChanged` anzeigen,
- vorhandene Teiltexte exportierbar halten,
- bewusste Neuplanung als neue Session anbieten.

### 13.3 Retention

- aktive, pausierte, fehlgeschlagene und unterbrochene Sessions automatisch schützen,
- History-Limit verdrängt keine fortsetzbare Session,
- Audio-Retention löscht deren Original nicht,
- erfolgreiche Sessions gehen nach Cleanup in bestehende Regeln über,
- explizites Löschen entfernt zusammengehörige Dateien in sicherer Reihenfolge.

### 13.4 Orphans und Stale Cleanup

- originale `wav`, `m4a` und alle aktiv erzeugten Aufnahmeformate erkennen,
- Session-Work-Verzeichnis nie als Originalaufnahme importieren,
- Manifest ohne Historyreferenz sicher klassifizieren,
- History ohne Manifest verständlich behandeln,
- alte unreferenzierte Segment- und Multipart-Dateien nach dokumentierter Frist entfernen,
- beschädigte Manifeste nicht destruktiv überschreiben.

### 13.5 Tests

- Neustart in jedem flüchtigen Sessionstatus,
- zwei Erfolge plus unterbrochener dritter Upload,
- fehlende Segmentdatei wird regeneriert,
- fehlende Originaldatei blockiert Resume,
- geänderte Originaldatei blockiert Resume,
- Manifest ohne History und History ohne Manifest,
- beschädigtes Manifest plus gültige Backupkopie,
- Retention bei aktiv/pausiert/fehlgeschlagen/abgeschlossen,
- History-Maximum mit geschütztem Record,
- explizites Löschen mit und ohne Originalaudio,
- M4A-Orphan ja, Segmentarbeitsdatei nein.

### 13.6 Gate

- App-Neustart verliert keinen bestätigten Teiltext,
- kein Start-Recovery führt selbstständig eine Cloudanfrage aus,
- Retention erzeugt keine Session- oder Audiowaisen,
- destruktives Löschen betrifft nur den ausdrücklich gewählten Record und seine validierten Dateien.

## 14. Schritt 3.4.8 – Performanceoptimierung und Gesamtregression

### 14.1 Profilierung

Mit denselben Messfällen wie Baseline:

- 5 Minuten Mikrofon,
- 30, 60 und 120 Minuten Systemaudio,
- klare Pausen,
- durchgängige Sprache,
- Musik plus Sprache,
- langsamer Stub-Provider,
- CPU- und I/O-Last während Stop und Export.

Erfassen:

- Hotkey bis `finalizing`,
- `stopCapture` und Writer-Finalisierung,
- Main-Actor-Hitches,
- Segmentplanung und erster Progress,
- Exportdurchsatz,
- RAM-Hochwasser und Wachstum mit Dauer,
- Anzahl gleichzeitiger Arbeitsdateien,
- Cleanupzeit.

### 14.2 Optimierungsreihenfolge

1. Main-Actor-Arbeit und synchrone I/O entfernen.
2. Capture-Callback und Queue-Drain untersuchen.
3. Writer-Finalisierung isolieren und unnötige Arbeit nach hinten verschieben.
4. Silence-Analyse auf begrenzte Suchfenster beschränken.
5. M4A-Passthrough beziehungsweise unnötige Re-Encodes reduzieren.
6. Multipart und Segmentdateien nur bei Bedarf erzeugen.
7. Progress-/Historywrites sinnvoll bündeln, ohne Segmenterfolg zu verzögern.

Keine Optimierung darf atomare Persistenz, Dateivalidierung oder Originalschutz umgehen.

### 14.3 Performance-Gates

Ziele aus dem PRD:

- Hotkey → sichtbares `finalizing`: p95 ≤ 100 ms,
- keine zusammenhängende 3.4-Arbeit auf Main Actor > 50 ms,
- Finalisierung 60 Minuten Systemaudio: Ziel p95 ≤ 3 s, dokumentiertes Maximum ≤ 5 s,
- erster Fortschritt nach Writerende: Ziel ≤ 2 s,
- zusätzlicher stabiler RAM: Ziel ≤ 200 MB,
- RAM-Differenz 30 zu 120 Minuten im stabilen Zustand: Ziel ≤ 50 MB,
- höchstens zwei vorbereitete Segmente,
- genau ein Netzwerkrequest gleichzeitig.

Falls Hardware oder Frameworkverhalten ein Ziel verhindert:

- Messwert und Ursache dokumentieren,
- Nutzerwirkung beurteilen,
- sichere Gegenmaßnahme implementieren,
- Abweichung vor lokaler Freigabe ausdrücklich entscheiden; nicht still akzeptieren.

### 14.4 Automatisierte Gesamtregression

Ausführen:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project FlowDictate.xcodeproj \
  -scheme FlowDictate \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:FlowDictateTests
```

Zusätzlich:

- `git diff --check`,
- Debug-Build,
- Release-Build,
- Prüfung, dass UI-Tests im gemeinsamen Scheme weiterhin nicht versehentlich aktiviert wurden,
- keine realen OpenAI-Anfragen aus Unit-Tests,
- keine Testfixtures mit persönlichen Inhalten.

### 14.5 Regressionsmatrix

- kurze Mikrofonaufnahme mit Preview an/aus,
- kurze Systemaudioaufnahme,
- Smart Dictation Original und AI-Stil,
- gesprochenes Formatieren Deutsch/Englisch,
- persönliches Wörterbuch,
- App-Profile,
- direkte AX-Einfügung und Clipboard-Fallback,
- Toggle und Press-and-Hold,
- Cancel während Aufnahme,
- Restore Last Dictation,
- History Play, Export, Delete, Retry und Retention,
- Recovery alter nicht segmentierter Records,
- Systemaudio-Test ohne Netzwerk/History/Rückstand,
- lokale Statistik und GitHub-Updatehinweis.

### 14.6 Gate

- alle automatisierten Tests grün,
- keine ungeklärte Performanceverschlechterung gegenüber Baseline,
- alle Pflichtbudgets erreicht oder ausdrücklich als Releaseblocker markiert,
- keine Regression der bisherigen Produktfunktionen.

## 15. Schritt 3.4.9 – Dokumentation und finale Community-ZIP

### 15.1 Dokumentation aktualisieren

Nach erfolgreicher Implementierung, noch vor Versionsfreigabe:

- `README.md`: Long-Form-Funktion, Progress, Pause/Resume, Grenzen,
- `CHANGELOG.md`: Änderungen unter `[Unreleased]`,
- `PRIVACY.md`: segmentweise Uploads und lokaler Kontextprompt,
- `RELEASE.md`: Long-Form-ZIP-Test und Recoverytest,
- `COMMUNITY_INSTALLATION.md` und `_EN.md`: Update-/Berechtigungshinweise,
- neue Release Notes erst nach Festlegung der Zielversion,
- alte Empfehlung „15–20 Minuten maximal“ durch korrektes automatisches Verhalten ersetzen,
- keine dynamischen Preise oder instabilen API-Angaben ohne Datum/Quelle festschreiben.

### 15.2 Version und Build

Version und Build werden erst gesetzt, wenn:

- Implementierung vollständig ist,
- Tests grün sind,
- Zielversion ausdrücklich entschieden ist.

Versionsänderung und Release Notes erhalten einen separaten Release-Vorbereitungscommit. Sie bedeuten noch keine Veröffentlichung.

### 15.3 Community-Build

```sh
./scripts/build-community-release.sh
```

Danach:

- SHA-256 verifizieren,
- ZIP in frischen temporären Ordner entpacken,
- `lipo -info` beziehungsweise Architekturen prüfen,
- `codesign --verify --deep --strict` ausführen,
- Entitlements kontrollieren,
- sicherstellen, dass kein API-Key, `.env`, Scheme-Secret oder privates Audio enthalten ist,
- Installation der entpackten App durchführen.

### 15.4 Test ausschließlich der finalen ZIP-App

Pflichtfälle:

1. Start und Onboarding beziehungsweise Updatepfad.
2. Keychainzugriff ohne eingebettete Zugangsdaten.
3. kurze Mikrofonaufnahme mit Preview und Einfügung.
4. kurzer Systemaudio-Smoke ohne Videodaten.
5. lange, sicher mehrsegmentige Systemaudioaufnahme.
6. sichtbarer Fortschritt Segment X von Y.
7. absichtlicher temporärer Fehler in einem mittleren Segment.
8. App beenden und dieselbe Verarbeitung nach Neustart fortsetzen.
9. Nachweis, dass erfolgreiche Segmente nicht erneut hochgeladen wurden, soweit mit Stub-/Testendpoint oder kontrollierter Diagnose möglich.
10. vollständiger Merge, Smart Dictation, Clipboard-Verhalten und Einfügung.
11. History, Audio Playback, Restore und Retention.
12. Stop-Reaktionsfähigkeit während langer Aufnahme.
13. Test auf zweitem macOS-Konto oder zweitem Mac.

Die App aus DerivedData oder einem nicht identischen Archiv zählt nicht als Ersatz.

### 15.5 Freigabeprotokoll

Vor einem späteren Release werden dokumentiert:

- getesteter Commit,
- Version und Build,
- ZIP-Dateiname und SHA-256,
- macOS- und Hardwareversion des Referenz-Macs,
- Ergebnis der Unit-Tests,
- Ergebnis der Langzeit-/Recoveryfälle,
- Performancewerte,
- bekannte Einschränkungen,
- ausdrückliche Go/No-Go-Entscheidung.

### 15.6 Gate

- finale ZIP besteht alle Pflichtfälle,
- Prüfsumme und Signatur sind korrekt,
- Dokumentation entspricht exakt dem getesteten Verhalten,
- Arbeitsbaum enthält nur beabsichtigte Quell- und Dokumentationsänderungen,
- keine Veröffentlichung wurde vorgenommen.

Erst danach darf in einem getrennten, ausdrücklich beauftragten Schritt Commitfinalisierung, Tag und GitHub Release vorbereitet werden.

## 16. Testfallkatalog

### 16.1 Segmentplanung

| ID | Fall | Erwartung |
|---|---|---|
| SEG-01 | 5-Minuten-M4A | Einzelupload, keine Session-Arbeitsdatei |
| SEG-02 | 35 Minuten mit Pause bei Minute 15 | Grenze an Pause, vollständige Abdeckung |
| SEG-03 | 35 Minuten ohne Pause | Zeitfallback mit definierter Überlappung |
| SEG-04 | sehr kurze Restdauer | kein leeres letztes Segment |
| SEG-05 | Segment nach Export > 24,5 MB | vor Netzwerk deterministisch teilen |
| SEG-06 | Musik plus Sprache | Planner terminiert und erzeugt validen Fallback |
| SEG-07 | Cancellation während Pausensuche | keine unvollständige Arbeitsdatei |

### 16.2 Transkription und Retry

| ID | Fall | Erwartung |
|---|---|---|
| TRN-01 | drei Erfolge | 1→2→3, atomare Speicherung, finaler Merge |
| TRN-02 | temporärer Fehler Segment 2 | nur Segment 2 Retry, Segment 1 bleibt |
| TRN-03 | permanenter Fehler Segment 2 | Session stoppt, Segment 3 unberührt |
| TRN-04 | Persistencefehler nach Antwort | kein nächster Upload |
| TRN-05 | Pause während Upload | bestätigte Erfolge bleiben; Status pausiert/interrupted |
| TRN-06 | Resume nach Neustart | Start beim ersten offenen Segment |
| TRN-07 | zweimal Resume | nur ein aktiver Runner |
| TRN-08 | Prompt | vorheriger Textkontext, nie zukünftiger Text |

### 16.3 Merge

| ID | Fall | Erwartung |
|---|---|---|
| MRG-01 | identische Überlappung | genau einmal im Gesamttext |
| MRG-02 | Großschreibung/Satzzeichen abweichend | konservativ korrekt erkannt |
| MRG-03 | kurze Phrase „ja genau“ | nicht allein dedupliziert |
| MRG-04 | keine Überlappung | sauberer Separator, kein Verlust |
| MRG-05 | unsortierte Segmente | Validierungsfehler statt falscher Reihenfolge |
| MRG-06 | wiederholter Merge | bytegleiches Ergebnis |
| MRG-07 | URL, Zahl, Fachbegriff an Grenze | Inhalt bleibt erhalten |

### 16.4 Recovery und Retention

| ID | Fall | Erwartung |
|---|---|---|
| REC-01 | App endet bei `uploading` | Segment interrupted; frühere Erfolge bleiben |
| REC-02 | Arbeitssegment fehlt | aus Original regenerieren |
| REC-03 | Original fehlt | Resume blockiert, Teiltext exportierbar |
| REC-04 | Original verändert | `sourceChanged`, keine stille Verarbeitung |
| REC-05 | Manifest beschädigt | Backup versuchen, Original nicht überschreiben |
| REC-06 | Retention bei pausierter Session | Record und Audio geschützt |
| REC-07 | explizites Löschen | nur validierte zugehörige Dateien entfernen |
| REC-08 | M4A-Orphan | als Originalaufnahme wiederherstellen |
| REC-09 | Segmentdatei-Orphan | nicht als Diktat importieren |

### 16.5 UI und Performance

| ID | Fall | Erwartung |
|---|---|---|
| UI-01 | Stop langer Aufnahme | `Finalizing` innerhalb Budget |
| UI-02 | Segment 2 von 4 | Overlay und History zeigen 2/4 korrekt |
| UI-03 | Settings während Export | bedienbar; Verarbeitung bleibt korrekt |
| UI-04 | Reduced Motion | keine verpflichtende Animation |
| UI-05 | partielle Session | Copy möglich, keine Auto-Einfügung |
| PERF-01 | 30 vs. 120 Minuten | kein proportionaler RAM-Anstieg |
| PERF-02 | CPU-/I/O-Last beim Stop | Hotkey und Overlay bleiben responsiv |
| PERF-03 | langsamer Provider | Main Actor bleibt responsiv |

## 17. Akzeptanzcheckliste

- [ ] Baseline und Signposts dokumentiert
- [x] M4A-Orphan-Recovery korrigiert
- [x] Provider und Uploadvorbereitung nicht unnötig Main-Actor-isoliert
- [x] Historyschema 5 mit `dictations-pre-3.4.json`
- [x] Sessionmanifest atomar und validiert
- [x] Preflight verhindert unsichere Uploads
- [x] Einzelpfad für kurze Aufnahmen unverändert
- [x] pausensensitive Segmentplanung implementiert
- [x] Zeitfallback mit kontrollierter Überlappung
- [x] Segmentexport speicherbegrenzt und abbrechbar
- [x] jedes Segment unter 24,5 MB
- [x] Netzwerkparallelität genau 1
- [x] erfolgreicher Teiltext vor nächstem Upload gespeichert
- [x] Prompt verwendet nur vorherigen Erfolg
- [x] Merge geordnet, deterministisch und konservativ
- [x] segmentweiser Retry und Resume
- [x] App-Neustart lädt Erfolge nicht erneut hoch
- [x] Teiltext wird nie automatisch eingefügt
- [x] Smart Dictation und Einfügung genau einmal nach Gesamtabschluss
- [x] Progress im Overlay und in History
- [x] Pause von Recording-Cancel getrennt
- [x] Retention schützt fortsetzbare Sessions
- [x] Originalaudio und vorhandener Text bei Teilfehlern erhalten
- [x] beobachtete Stop-/Finalisierungszeiten und Responsiveness geprüft; fehlende vollständige Performance-Matrix als Restrisiko akzeptiert
- [x] alle Unit- und Regressionstests grün
- [x] README, CHANGELOG, PRIVACY und Release-Dokumentation aktuell
- [x] finale Community-ZIP erzeugt und SHA geprüft (`FlowDictate-3.4.0-Community-macOS.zip`, SHA-256 `749388f7437ed9e26194346173b363b93038079e860e5abb6175146640d172cb`)
- [x] exakt entpackte ZIP-App im kurzen Mikrofon-/Einfügungspfad getestet
- [ ] exakt entpackte letzte ZIP-App mit erneutem Long-Form-Lauf getestet
- [ ] Recoverytest mit exakt dieser ZIP-App bestanden
- [ ] zweites Konto oder zweiter Mac bestanden
- [x] keine Schlüssel, privaten Audios oder Buildartefakte in Git
- [x] separate Freigabe für Commit, Push, Tag und GitHub Release erteilt

### Lokaler Release-Kandidat vom 25. August 2026

- Version: 3.4.0
- Build: 8
- automatisierte Unit-Tests: 58 erfolgreich
- Release-Build: erfolgreich für `arm64` und `x86_64`
- Mindestversion: macOS 14.0
- Signatur: ad hoc, `codesign --verify --deep --strict` erfolgreich
- ZIP-Prüfsumme: erfolgreich gegen die erzeugte `.sha256`-Datei geprüft
- Archivinhalt: FlowDictate.app sowie deutsche und englische Installationsanleitung; keine offensichtlichen Secret- oder Entwicklungsdateien
- bereits vor dem Kandidaten gemeldeter manueller Long-Form-Test: zwei Segmente erfolgreich transkribiert und zusammengeführt
- exakt erzeugte Kandidaten-App: kurzer Mikrofontest, Live-Preview-Beschriftung, schnelle Einfügung und korrekt verschwindendes Overlay erfolgreich
- zuvor geprüft: Systemaudioaufnahme, Productivity-Zeiträume und Rückmeldung von „Check Now“
- bewusst akzeptierte Restrisiken: kein erneuter Long-Form-/Recoverylauf mit der letzten ZIP und kein Test auf einem zweiten Konto oder Mac

## 18. Risiken, Blocker und Go/No-Go

### 18.1 Harte Releaseblocker

- irgendein bestätigter Teiltext geht nach Neustart verloren,
- erfolgreiche Segmente werden beim normalen Resume erneut hochgeladen,
- ein Segment kann die harte Uploadgrenze überschreiten,
- Teiltext wird automatisch eingefügt,
- Originalaufnahme wird verändert oder bei Teilfehler gelöscht,
- Main Actor blockiert Stop/Overlay außerhalb des akzeptierten Budgets,
- Retention entfernt eine fortsetzbare Session,
- Migration beschädigt bestehende History oder Textstufen,
- finale Community-ZIP unterscheidet sich vom getesteten Artefakt,
- Community-ZIP enthält Zugangsdaten oder private Fixtures.

### 18.2 Go/No-Go-Fragen am Ende

1. Sind Mikrofon und Systemaudio im kurzen Pfad regressionsfrei?
2. Besteht mindestens eine 120-Minuten-Systemaudioaufnahme oder ein gleichwertig begründeter Langzeittest?
3. Besteht Fehler plus Neustart in einem mittleren Segment ohne Reupload früherer Erfolge?
4. Sind Merge-Grenzen in Deutsch und Englisch manuell geprüft?
5. Werden die Performanceziele erreicht oder ist jede Abweichung ausdrücklich akzeptiert?
6. Besteht die entpackte finale Community-ZIP auf Referenz- und zweitem Konto/Mac?

Abweichungen von diesen Gates müssen vor einer Veröffentlichung ausdrücklich dokumentiert und vom Projekteigentümer akzeptiert werden. Für 3.4.0 wurden der fehlende zweite Mac sowie der nicht erneut mit der letzten ZIP ausgeführte Long-Form-/Recoverylauf am 25. August 2026 als vertretbares Restrisiko akzeptiert.

## 19. Vorgeschlagene Commit-Struktur

1. `Add Phase 3.4 performance baseline instrumentation`
2. `Move transcription preparation off the main actor`
3. `Add resumable transcription session models`
4. `Add Phase 3.4 history migration`
5. `Add audio preflight and long-form mode selection`
6. `Add pause-aware audio segment planning`
7. `Export bounded transcription audio segments`
8. `Add sequential resumable segment transcription`
9. `Merge partial transcripts deterministically`
10. `Show long-form progress and resume actions`
11. `Recover and retain interrupted transcription sessions`
12. `Optimize long System Audio finalization`
13. `Complete Phase 3.4 regression and documentation`

Baseline-Fixes, Schemaänderung, Segmentierungslogik, UI und Releasevorbereitung werden nicht in einen einzigen Großcommit gepackt. Ein späterer Versions-/Buildcommit und ein Releasecommit bleiben getrennt und erfolgen erst nach ausdrücklicher Freigabe.

## 20. Abschluss

Dieser Arbeitsplan autorisierte zunächst nur die lokale Implementierung und Prüfung von Phase 3.4. Der getestete Stand wurde anschließend mit Prüfsumme und offenen Einschränkungen vorgelegt. Der separate Auftrag für Commit, Push, Tag, GitHub Release und Asset-Upload wurde am 25. August 2026 erteilt.
