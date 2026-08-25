# Product Requirements Document: FlowDictate Phase 3.4

**Phase:** 3.4 – Long-Form Transcription & Responsiveness
**Status:** Implementierung lokal in Prüfung; Community-ZIP- und manuelle Abnahme noch offen
**Stand:** 25. August 2026
**Ausgangsversion:** FlowDictate 3.3.0, Build 7, Tag `v3.3.0`, Commit `174a88b`
**Zielversion:** erst nach lokaler Abnahme festlegen
**Grundlagen:** `FlowDictate_PRD_Phase_3.md`, `ARBEITSPLAN_PHASE_3_3.md`, aktueller Code auf `main`

## 1. Zweck

Phase 3.4 macht lange Mikrofon- und Systemaudioaufnahmen zuverlässig transkribierbar. Aufnahmen, die nicht sicher in eine einzelne Transkriptionsanfrage passen, werden lokal in geordnete Segmente zerlegt. Erfolgreiche Teiltranskripte werden sofort lokal und crashfest gespeichert. Nach Fehler, Pause oder App-Neustart setzt FlowDictate nur die noch offenen Segmente fort.

Gleichzeitig wird die Reaktionsfähigkeit langer Systemaudioaufnahmen gemessen und verbessert. Stop-Tastenkürzel, Overlay, Pegelanzeige und App-Navigation dürfen weder durch Capture-Finalisierung noch durch Segmentvorbereitung, Audioexport, Multipart-Erzeugung oder Netzwerkverarbeitung blockiert werden.

Dieses Dokument definiert Produktumfang, Architekturverträge, Datenmodell, Segmentierung, Zusammenführung, Recovery, Migration, Performanceziele und Abnahmekriterien. Der umsetzbare Lieferablauf steht in `ARBEITSPLAN_PHASE_3_4.md`.

## 2. Ausgangslage

FlowDictate 3.3.0 bietet bereits:

- getrennte Mikrofon- und Systemaudioaufnahme,
- transkriptionsoptimiertes Systemaudio als Mono-AAC/M4A,
- kompakte M4A-Uploadvorbereitung für Mikrofonaufnahmen,
- dateibasierten Multipart-Upload mit Prüfung vor Netzwerkzugriff,
- automatische und manuelle Wiederholungsversuche für eine gesamte Transkription,
- JSON-basierte History, Recovery, Retention und Orphan-Erkennung,
- Smart Dictation nach der finalen Transkription,
- direkte Accessibility-Einfügung mit Clipboard-Fallback,
- sofortige visuelle Bestätigung des Stop-Befehls,
- Audioverarbeitung und Systemaudio-Asset-Writing weitgehend außerhalb des Main Actors,
- auf etwa zehn Aktualisierungen pro Sekunde begrenzte Pegelanzeige.

Aktuelle Einschränkungen:

- Eine Aufnahme entspricht genau einer Transkriptionsanfrage.
- Die lokale Einzeldateigrenze liegt bei 24,5 MB, während die Transcriptions API derzeit Dateien bis 25 MB akzeptiert.
- Ein fehlgeschlagener später Abschnitt erzwingt die erneute Übertragung der gesamten Aufnahme.
- History kennt nur den Status der Gesamttranskription.
- Unterbrechung oder Neustart während der Transkription verliert den Fortschritt der laufenden Anfrage.
- Der Coordinator enthält Aufnahme-, Transkriptions-, Smart-Dictation- und Einfügungssteuerung in einer Main-Actor-isolierten Klasse.
- Segmentfortschritt, Pause und segmentweises Fortsetzen existieren nicht.
- Orphan-Recovery berücksichtigt bisher nicht alle von FlowDictate erzeugten M4A-Dateien.
- Lange Systemaudioaufnahmen zeigten in manuellen Tests verzögerte Reaktion beim Stoppen und Finalisieren; belastbare Messwerte fehlen noch.

Referenz der API-Grenze: [OpenAI Speech-to-text Guide](https://developers.openai.com/api/docs/guides/speech-to-text). API-Verhalten ist vor der Implementierung und vor jeder Veröffentlichung erneut gegen die offizielle Dokumentation zu prüfen.

## 3. Produktziel

### 3.1 Leitsatz

Eine lange Aufnahme ist eine lokal gesicherte, fortsetzbare Verarbeitungssession – keine einzelne, alles-oder-nichts arbeitende Uploadanfrage.

### 3.2 Ergebnis der Phase

Nach Abschluss von Phase 3.4 gilt:

1. Kurze Aufnahmen nutzen unverändert den schnellen Einzelupload.
2. Lange oder zu große Aufnahmen werden automatisch in uploadfähige Segmente zerlegt.
3. Segmentgrenzen liegen bevorzugt an Sprechpausen.
4. Segmente werden in stabiler Reihenfolge transkribiert.
5. Jedes erfolgreiche Teiltranskript wird vor dem nächsten Upload atomar gespeichert.
6. Wiederaufnahme lädt erfolgreiche Segmente nicht erneut hoch.
7. Teiltranskripte werden deterministisch und in der richtigen Reihenfolge zusammengeführt.
8. Smart Dictation und automatische Einfügung beginnen erst nach vollständigem Merge.
9. Originalaufnahme und vorhandener Text bleiben bei jedem Teilfehler lokal erhalten.
10. Stoppen und Verarbeitung blockieren Main Actor, Overlay oder globale Tastenkürzel nicht wahrnehmbar.

## 4. Umfang

### 4.1 Pflichtumfang

- gemeinsame Long-Form-Pipeline für Mikrofon und Systemaudio,
- unveränderter Einzelupload-Pfad für kurze Aufnahmen,
- lokale Segmentplanung anhand von Dauer und Dateigröße,
- pausensensitive Grenzwahl mit kontrolliertem Fallback,
- größenbegrenzter Segmentexport,
- sequenzielle Transkription mit begrenzter lokaler Vorausverarbeitung,
- segmentweiser Fortschritt in Overlay und History,
- separate, atomare Transcription-Session-Persistenz,
- Pause, Fortsetzen, Retry und Recovery auf Segmentebene,
- deterministische Merge- und Deduplizierungslogik,
- Speicherplatz-, Datei- und Uploadprüfung vor Netzwerkzugriff,
- Performanceinstrumentierung und definierte Budgets,
- M4A-Orphan-Recovery,
- additive History-Migration von Schema 4 auf Schema 5,
- vollständige Regression der vorhandenen Funktionen,
- Test der finalen Community-ZIP vor jeder Veröffentlichung.

### 4.2 Soll-Umfang mit eigenem Gate

- ein lokaler Export darf Segment N+1 vorbereiten, während Segment N hochgeladen wird,
- History-Detailansicht zeigt einzelne Segmentstatus und Fehlermeldungen,
- manuelles „Retry failed segment“ zusätzlich zu „Resume remaining segments“,
- Diagnoseansicht für lokale, inhaltsfreie Performancekennzahlen.

Soll-Funktionen dürfen den Pflichtumfang nicht verzögern oder dessen Recoverygarantien schwächen.

### 4.3 Nicht Bestandteil

- parallele Netzwerktranskription mehrerer Segmente im Releasepfad,
- Mikrofon und Systemaudio gleichzeitig,
- Speaker-Diarization,
- Live Preview für Systemaudio,
- Cloud-Streaming während der Aufnahme,
- lokale finale Transkription,
- SQLite oder eine andere History-Datenbank,
- Bulk-Export, Profilimport/-export oder AX-Kompatibilitätscache,
- automatische Installation von Updates,
- automatische Kostenabfrage oder hart codierte Modellpreise,
- Veröffentlichung, Tag oder GitHub Release vor vollständiger ZIP-Abnahme.

## 5. Produktprinzipien

### 5.1 Original bleibt unverändert

Die lokale Originalaufnahme wird weder überschrieben noch durch Segmente ersetzt. Segmentdateien sind abgeleitete, reproduzierbare Arbeitsdateien.

### 5.2 Persistieren vor Fortschreiten

Ein Segment gilt erst als erfolgreich, wenn sein vollständiges Teiltranskript atomar auf Datenträger geschrieben wurde. Erst danach darf das nächste Segment hochgeladen werden.

### 5.3 Keine partielle automatische Einfügung

Teiltranskripte dürfen sichtbar und exportierbar sein, werden aber niemals automatisch in die Ziel-App eingefügt. Smart Dictation und Einfügung starten erst nach vollständigem, validiertem Merge.

### 5.4 Sichere Degradierung

- Segmentplanung schlägt fehl → Original behalten, verständlichen Fehler anzeigen.
- Speicher reicht nicht → vor Netzwerkzugriff abbrechen, Original behalten.
- einzelner Upload schlägt fehl → erfolgreiche Segmente behalten, Session fortsetzbar machen.
- Merge schlägt fehl → Teiltranskripte behalten, keine Einfügung auslösen.
- Sessiondatei beschädigt → Original und History nicht überschreiben; kontrollierte Rekonstruktion oder sichere Neuplanung anbieten.

### 5.5 Begrenzte Ressourcen

Gesamtdauer darf nicht zu proportional wachsendem Arbeitsspeicher führen. Audio wird in begrenzten Buffern gelesen und höchstens ein Segment lokal voraus vorbereitet.

### 5.6 Bestehendes Verhalten schützen

Für kurze Mikrofon- und Systemaudioaufnahmen bleiben Providerergebnis, Smart Dictation, Einfügung, Clipboard-Verhalten, History und Restore funktional unverändert.

## 6. Produktentscheidungen

### 6.1 Beide Aufnahmequellen

Die Orchestrierung ist quellenunabhängig. Phase 3.4 wird für Mikrofon und Systemaudio implementiert. Systemaudio bildet wegen des beobachteten Langzeitproblems den Schwerpunkt der manuellen Performance- und Community-ZIP-Abnahme.

### 6.2 Sequenzielle Netzwerkverarbeitung

Die freigegebene Parallelität für Transkriptionsrequests ist `1`. Gründe:

- Der Prompt des nächsten Segments verwendet Kontext des vorherigen Teiltranskripts.
- Reihenfolge und Recovery bleiben eindeutig.
- Rate-Limit- und Retry-Verhalten bleiben kontrollierbar.
- Speichern vor dem nächsten Upload ist einfach nachweisbar.

Lokale Segmentvorbereitung darf mit einer Kapazität von höchstens einem Segment vorauslaufen. Netzwerkparallelität größer als `1` benötigt später ein eigenes Qualitäts- und Belastungsgate.

### 6.3 JSON-History plus separate Sessiondateien

History bleibt JSON-basiert. Detaillierte, häufig wechselnde Segmentzustände werden nicht vollständig in `dictations.json` gespeichert. Pro Long-Form-Aufnahme existiert eine separate, versionierte Sessiondatei. History enthält nur eine additive Zusammenfassung und Referenz.

### 6.4 Kein vollständiger Coordinator-Umbau als Voraussetzung

Phase 3.4 führt eine eigene Long-Form-Orchestrierung außerhalb des `DictationCoordinator` ein. Eine komplette Extraktion des gesamten Aufnahme-bis-Einfügungs-Lebenszyklus ist kein Gate dieser Phase.

## 7. Zielarchitektur

```text
AudioRecordingResult
        ↓
TranscriptionModeResolver
        ├── Single-file path (kurz und sicher uploadfähig)
        └── LongFormTranscriptionRunner actor
                    ↓
           AudioSegmentPlanner
                    ↓
           AudioSegmentExporter
                    ↓
        TranscriptionSessionStore actor
                    ↓
     Segment 1 → persist → Segment 2 → persist → …
                    ↓
          PartialTranscriptMerger
                    ↓
      finales Originaltranskript in History
                    ↓
        bestehende Smart-Dictation-Pipeline
                    ↓
       bestehende Einfügung und Recovery
```

### 7.1 Komponenten

| Komponente | Verantwortung |
|---|---|
| `TranscriptionModeResolver` | Einzelupload oder Long-Form-Pipeline anhand technischer Preflightdaten wählen |
| `AudioAssetInspector` | Dauer, Format, Größe, Lesbarkeit und geschätzten Arbeitsbedarf bestimmen |
| `AudioSegmentPlanner` | stabile, vollständige und überlappende Zeitbereiche erzeugen |
| `SilenceBoundaryDetector` | in einem begrenzten Suchfenster eine energiearme Schnittstelle finden |
| `AudioSegmentExporter` | ein uploadfähiges Segment mit begrenztem Speicher erzeugen und prüfen |
| `TranscriptionSessionStore` | Manifest atomar laden, validieren, sichern und aktualisieren |
| `LongFormTranscriptionRunner` | Zustandsmaschine, Retry, Pause, Progress und Provideraufrufe koordinieren |
| `PartialTranscriptMerger` | geordnete Teiltexte zusammenführen und Grenzduplikate konservativ entfernen |
| `TranscriptionPerformanceRecorder` | inhaltsfreie Zeiten, Größen und Ressourcenkennzahlen erfassen |
| `TranscriptionRunner` | gemeinsame Fassade für Single- und Long-Form-Verarbeitung bilden |

### 7.2 Concurrency-Verträge

- Audioanalyse, Segmentexport, Multipart-Erzeugung und Netzwerkzugriff laufen nicht auf dem Main Actor.
- Der Main Actor erhält nur kompakte Status- und Fortschrittsereignisse.
- `DictationHistoryStore` und `TranscriptionSessionStore` bleiben Actor-isoliert.
- Providerinstanzen dürfen nicht pauschal Main-Actor-isoliert sein.
- AVFoundation-Objekte werden nicht unsicher zwischen Executoren geteilt.
- Cancellation wird an Analyse, Export, Upload und Retry-Sleep weitergegeben.
- Es existiert höchstens eine aktive Verarbeitungssession pro DictationRecord.

## 8. Entscheidung Einzelupload oder Long Form

### 8.1 Preflight

Vor dem ersten Netzwerkzugriff bestimmt FlowDictate:

- Existenz und Lesbarkeit der Originaldatei,
- Audiodauer,
- Container und Codec,
- aktuelle Dateigröße,
- erwartete Größe nach kompakter Vorbereitung,
- freien Speicher am Arbeitsort,
- sichere Einzeluploadfähigkeit.

### 8.2 Einzelupload

Der bestehende Pfad bleibt aktiv, wenn die vorbereitete Datei:

- unter dem konfigurierten weichen Uploadziel liegt,
- unter der harten lokalen Providergrenze liegt,
- valide Audiosamples enthält.

Einzelupload muss dieselben Fehler- und Persistenzverträge wie bisher erfüllen.

### 8.3 Long-Form-Pfad

Segmentierung wird aktiviert, wenn mindestens eine Bedingung zutrifft:

- erwartete Uploadgröße überschreitet das weiche Ziel,
- vorbereitete Datei überschreitet die harte Grenze,
- Dauer überschreitet die konfigurierte Long-Form-Schwelle,
- Export- oder Formatrisiko verhindert eine sichere Größenprognose.

Defaultwerte sind Implementierungsparameter und keine Benutzeroptionen:

- Zieldauer: 15 Minuten,
- zulässiges Zielfenster: ungefähr 12 bis 17 Minuten,
- weiches Größenziel: höchstens 20.000.000 Bytes,
- harte lokale Grenze: 24.500.000 Bytes,
- Größenreserve zur externen 25-MB-Grenze: mindestens 500.000 Bytes.

Die Grenzwerte sind zentral konfigurierbar und vor Release gegen die aktuelle Providerdokumentation zu prüfen.

## 9. Segmentierungsstrategie

### 9.1 Anforderungen an den Plan

Ein Segmentplan muss:

- die vollständige Audiodauer abdecken,
- eine lückenlose, monoton steigende Reihenfolge besitzen,
- nur die definierte Grenzüberlappung doppelt abdecken,
- positive Segmentdauern besitzen,
- deterministisch aus derselben Quelle und Konfiguration entstehen,
- eine stabile nullbasierte interne und verständliche einsbasierte UI-Reihenfolge besitzen,
- vor dem ersten Upload vollständig validiert werden.

### 9.2 Pausensensitive Grenze

Für jede geplante Grenze:

1. Berechne den nominalen Zielzeitpunkt.
2. Dekodiere nur ein begrenztes Suchfenster um diesen Zeitpunkt.
3. Erzeuge geglättete Energie-/RMS-Werte in kleinen Zeitfenstern.
4. Suche eine ausreichend lange energiearme Passage nahe dem Ziel.
5. Bewerte Kandidaten anhand Lautstärke, Pausenlänge und Abstand zum Ziel.
6. Wähle den besten stabilen Kandidaten.
7. Existiert kein geeigneter Kandidat, verwende den nominalen Zeitpunkt.

Schwellwerte müssen durch Tests und echte deutsche, englische, stille und musikbehaftete Systemaudiofixtures kalibriert werden. „Stille“ darf nicht als Annahme verwendet werden, dass das Audio ausschließlich Sprache enthält.

### 9.3 Überlappung

- Bei sicher erkannter Sprechpause ist keine oder nur minimale Codec-Sicherheitsüberlappung erforderlich.
- Beim Zeitfallback wird standardmäßig eine kurze Überlappung von ungefähr 1,5 Sekunden verwendet.
- Die Überlappung darf nie zu einem Segment über der harten Uploadgrenze führen.
- Start und Ende der Gesamtaufnahme werden auf den realen Assetbereich geklemmt.

### 9.4 Export

- Bereits kompaktes Systemaudio-M4A wird bevorzugt ohne unnötige vollständige Neukodierung zeitbereichsbasiert exportiert.
- Nicht kompakte Quellen werden streamingartig beziehungsweise mit begrenzten PCM-Buffern in Mono-AAC/M4A überführt.
- Nie wird die gesamte Aufnahme in RAM geladen.
- Segmentdateien erhalten stabile Namen mit Record-ID, Index und Sessionversion, aber keinen transkribierten Inhalt.
- Nach Export werden Größe, Dauer und Lesbarkeit geprüft.
- Ein zu großes Segment wird vor Netzwerkzugriff deterministisch geteilt und der Plan atomar aktualisiert.
- Die Originaldatei bleibt in allen Fällen unverändert.

### 9.5 Speicherstrategie

Bevor Arbeitsdateien entstehen, wird geprüft:

```text
benötigt = geschätzte größte gleichzeitige Segmentdatei
         + Multipart-Arbeitsdatei
         + Sicherheitsreserve
```

Default-Sicherheitsreserve: mindestens 250 MB. Die konkrete Berechnung berücksichtigt Dateisystemwerte und darf nicht nur auf der nominellen Audiodauer beruhen.

Erfolgreich transkribierte Segmentdateien dürfen nach atomarer Speicherung ihres Textes gelöscht werden. Sie sind aus Originaldatei und Segmentplan reproduzierbar. Es liegen höchstens das aktuelle und optional das nächste vorbereitete Segment vor.

## 10. Transkriptionsstrategie

### 10.1 Reihenfolge

Segmente werden streng nach `index` verarbeitet. Ein späteres Segment darf nicht als erfolgreich persistiert werden, bevor alle früheren Segmente erfolgreich sind.

### 10.2 Prompt-Kontext

`TranscriptionRequest` erhält einen optionalen `prompt`.

- Segment 0 verwendet keinen vorherigen Teiltext als Kontext.
- Jedes weitere Segment erhält einen begrenzten Endausschnitt des vorherigen erfolgreichen Teiltranskripts.
- Prompt und Audio müssen dieselbe Sprache verwenden.
- Promptinhalt wird ausschließlich lokal aus bereits vorhandenem Text erzeugt und zusammen mit dem nächsten Audiosegment direkt an den gewählten Provider gesendet.
- Der Prompt ersetzt keine Audioüberlappung und wird nicht blind in das Ergebnis kopiert.
- Länge und Bereinigung sind zentral begrenzt und durch Tests abgedeckt.

### 10.3 Retry

- Automatische Retries gelten pro Segment.
- Temporäre Fehler verwenden begrenztes Backoff mit Jitter beziehungsweise deterministisch injizierbarem Test-Sleeper.
- Permanente Fehler stoppen die Session ohne Upload späterer Segmente.
- Versuchszähler der Gesamt-History und des Segments bleiben nachvollziehbar.
- Manuelles Fortsetzen setzt beim ersten nicht erfolgreichen Segment an.
- Modell- oder Sprachwechsel während einer begonnenen Session ist nicht erlaubt; eine bewusste Neuverarbeitung erzeugt eine neue Session und verwirft erfolgreiche Texte niemals ohne Bestätigung.

### 10.4 Pause und Abbruch

- „Cancel Recording“ beendet weiterhin nur eine laufende Aufnahme ohne Cloudanfrage.
- Während Vorbereitung oder Transkription bietet FlowDictate „Pause Processing“.
- Pause bricht laufende lokale Arbeit oder den Upload soweit möglich ab und persistiert `paused`.
- Bereits erfolgreiche Segmente bleiben erhalten.
- Fortsetzen ist aus History möglich.
- „Delete dictation and audio“ bleibt eine getrennte, explizite destruktive Aktion.

## 11. Zusammenführung

### 11.1 Grundregel

Teiltranskripte werden ausschließlich nach Segmentindex zusammengeführt. Netzwerkabschlusszeit oder Dateisystemreihenfolge dürfen das Ergebnis nicht beeinflussen.

### 11.2 Normalisierung für Grenzvergleich

Für die Erkennung einer Grenzduplikation darf eine temporäre Vergleichsdarstellung verwenden:

- Unicode-Normalisierung,
- vereinheitlichte Whitespace-Zeichen,
- kontrollierte Groß-/Kleinschreibung,
- Trennung in Wörter und Satzzeichen.

Die gespeicherten Originalteiltexte werden nicht normalisiert oder überschrieben.

### 11.3 Konservative Deduplizierung

- Verglichen werden nur ein begrenztes Suffix des bisherigen Textes und Präfix des nächsten Textes.
- Entfernt wird nur eine ausreichend lange, zusammenhängende Übereinstimmung.
- Kurze Standardphrasen allein reichen nicht für eine Löschung.
- Satzzeichenabweichungen dürfen toleriert werden, dürfen aber keine frei erfundene Übereinstimmung erzeugen.
- Bei Unsicherheit werden beide Textteile erhalten.
- Jede Merge-Entscheidung ist deterministisch und über eine `mergeAlgorithmVersion` reproduzierbar.

### 11.4 Abschluss

Nach erfolgreichem Merge:

1. Speichere den zusammengesetzten Text im Sessionmanifest.
2. Aktualisiere den History-Record atomar auf `transcribed`.
3. Starte die bestehende Smart-Dictation-Pipeline genau einmal.
4. Führe den finalen Text genau einmal ein.
5. Markiere die Session als `completed`.
6. Bereinige temporäre Segment- und Multipart-Dateien.
7. Entferne die Sessiondatei erst, nachdem History das Endergebnis sicher enthält; optional bleibt eine inhaltsarme Abschlussreferenz bis zum nächsten erfolgreichen Start bestehen.

## 12. Datenmodell

### 12.1 History-Zusammenfassung

Additive Felder in `DictationRecord`:

```swift
nonisolated struct DictationRecord: Codable, Sendable {
    // bestehende Felder
    var transcriptionSessionID: UUID? = nil
    var transcriptionSegmentCount: Int? = nil
    var completedTranscriptionSegmentCount: Int = 0
    var hasPartialTranscript: Bool = false
}
```

Der primäre Gesamtstatus bleibt kompatibel. `transcribing` kann Segmentfortschritt besitzen; `transcriptionFailed` kann eine fortsetzbare Session referenzieren.

### 12.2 Sessionstatus

```swift
nonisolated enum LongFormSessionStatus: String, Codable, Sendable {
    case planning
    case ready
    case transcribing
    case paused
    case failed
    case merging
    case completed
}
```

### 12.3 Segmentstatus

```swift
nonisolated enum TranscriptionSegmentStatus: String, Codable, Sendable {
    case pending
    case preparing
    case ready
    case uploading
    case succeeded
    case failed
    case interrupted
}
```

### 12.4 Sessionmanifest

```swift
nonisolated struct TranscriptionSessionManifest: Codable, Sendable {
    var schemaVersion: Int
    var id: UUID
    var recordID: UUID
    var source: TranscriptionSourceFingerprint
    var providerID: String
    var modelID: String
    var language: String?
    var status: LongFormSessionStatus
    var segments: [TranscriptionSegment]
    var mergedTranscript: String?
    var mergeAlgorithmVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var lastErrorCategory: DictationErrorCategory?
    var lastErrorMessage: String?
}

nonisolated struct TranscriptionSourceFingerprint: Codable, Sendable, Equatable {
    var audioRelativePath: String
    var byteCount: Int64
    var durationMilliseconds: Int64
    var modificationDate: Date?
}

nonisolated struct TranscriptionSegment: Codable, Sendable, Identifiable {
    var id: UUID
    var index: Int
    var startMilliseconds: Int64
    var endMilliseconds: Int64
    var overlapBeforeMilliseconds: Int64
    var status: TranscriptionSegmentStatus
    var preparedRelativePath: String?
    var preparedByteCount: Int64?
    var transcript: String?
    var attemptCount: Int
    var lastAttemptAt: Date?
    var errorCategory: DictationErrorCategory?
    var errorMessage: String?
}
```

Zeitbereiche werden als ganzzahlige Millisekunden oder eine ebenso stabile rationale Darstellung persistiert, nicht als unkontrolliert verglichene Gleitkommawerte.

### 12.5 Invarianten

- `segments` ist nach `index` sortiert und besitzt keine doppelten Indizes.
- `start < end` für jedes Segment.
- Segment 0 beginnt bei 0 innerhalb der definierten Codec-Toleranz.
- Das letzte Segment endet an der Assetdauer innerhalb der Toleranz.
- `succeeded` erfordert ein nicht leeres `transcript`.
- `completedTranscriptionSegmentCount` entspricht der Zahl erfolgreicher Präfixsegmente.
- `completed` erfordert erfolgreiche Segmente und nicht leeren Merge.
- Session und Record referenzieren dieselbe ID.
- Source-Fingerprint muss vor Fortsetzen übereinstimmen.

## 13. Persistenz und Dateilayout

Empfohlenes Layout:

```text
Application Support/FlowDictate/
├── History/dictations.json
├── History/dictations-pre-3.4.json
└── TranscriptionSessions/
    └── <record-id>/
        ├── manifest.json
        └── work/
            ├── segment-000.m4a
            └── segment-001.m4a
```

Wenn der sandboxbedingte Zugriff auf die Originalaufnahme ein Security-Scoped Bookmark benötigt, wird weiterhin ausschließlich der bestehende Recording-Location-Vertrag verwendet. Sessiondateien speichern keine absoluten Benutzerpfade, sofern ein stabiler relativer Pfad möglich ist.

Manifeständerungen werden atomar geschrieben. Eine letzte gültige Backupkopie darf während des Schreibens vorgehalten werden. Temporäre Schreibdateien werden nach erfolgreichem Replace entfernt und beim Start bereinigt.

## 14. Recovery-Konzept

### 14.1 Start-Recovery

Beim App-Start:

1. History laden und migrieren.
2. Sessionverzeichnis katalogisieren.
3. Record-/Sessionreferenzen abgleichen.
4. `planning`, `preparing`, `uploading`, `transcribing` und `merging` als unterbrochen klassifizieren.
5. Bereits erfolgreiche Segmente unverändert lassen.
6. Flüchtige Zustände zu `interrupted`, `paused` oder `failed` normalisieren.
7. temporäre Dateien ohne Manifestreferenz kontrolliert entfernen oder quarantänisieren.
8. fortsetzbare Records in History anzeigen.

Keine Cloudanfrage startet automatisch beim App-Start. Der Benutzer setzt die Verarbeitung explizit fort.

### 14.2 Fortsetzen

Vor Fortsetzen:

- Originaldatei existiert und ist lesbar,
- Source-Fingerprint stimmt überein,
- Providerkonfiguration ist verfügbar,
- freier Speicher reicht,
- Segmentplan erfüllt die Invarianten.

Dann wird das erste Segment ohne `succeeded` gewählt. Eine fehlende Arbeitsdatei wird nur für dieses Segment aus dem Original regeneriert. Erfolgreiche Segmente werden nicht erneut übertragen.

### 14.3 Beschädigte Sessiondatei

- Beschädigte Datei nicht überschreiben.
- Letzte gültige atomare Backupversion versuchen.
- History und Originalaufnahme schützen.
- Ist keine sichere Rekonstruktion möglich, neue Planung als separate Session anbieten.
- Bereits lesbare Teiltranskripte aus der beschädigten Session dürfen exportiert, aber nicht ungeprüft in einen neuen Merge übernommen werden.

### 14.4 Verwaiste Dateien

Orphan-Recovery berücksichtigt mindestens `wav`, `m4a` und alle weiteren aktiv erzeugten Aufnahmeformate. Arbeitssegmente unter `TranscriptionSessions` werden nicht als neue Diktate importiert. Die Erkennung unterscheidet Originalaufnahmen von reproduzierbaren Arbeitsdateien.

### 14.5 Retention und Löschen

- Records mit aktiver, pausierter, fehlgeschlagener oder unterbrochener Session sind automatisch geschützt.
- History-Limit verdrängt keine fortsetzbare Session.
- Audio-Retention löscht kein Original einer fortsetzbaren Session.
- Nach erfolgreichem Abschluss gelten die bestehenden Retentionregeln.
- Explizites Löschen mit Audio entfernt nach Bestätigung Record, Original, Manifest und Arbeitsdateien.
- Löschen nur aus sichtbarer History darf keine unkontrollierte Sessionwaise erzeugen.

## 15. Fortschritt und UX

### 15.1 Overlay

Neue verständliche Zustände:

- `Finalizing recording…`
- `Preparing long recording…`
- `Transcribing segment X of Y…`
- `Retrying segment X of Y…`
- `Merging Y segments…`
- `Processing text…`
- `Paused after X of Y segments`

Fortschritt wird mindestens als Text und optional als determinate ProgressView dargestellt. Farbe ist nie einziger Statusträger. Das Overlay bleibt nicht aktivierend.

### 15.2 History

History zeigt:

- Gesamtstatus,
- `X of Y segments completed`,
- partiellen Text als klar gekennzeichnete Vorschau,
- fehlgeschlagenes Segment und verständliche Fehlerkategorie,
- Aktionen `Resume`, `Retry failed segment`, `Copy partial transcript`, `Reveal recording`,
- keine automatische partielle Einfügung.

### 15.3 Verhalten nach Stop

Die Stop-Eingabe wird sofort bestätigt. Aufnahmefinalisierung, Preflight und Segmentierung folgen asynchron. Die App darf währenddessen Settings und History öffnen. Eine neue parallele Aufnahme bleibt bis zu einer bewussten späteren Multi-Session-Entscheidung gesperrt.

## 16. Fehlerkategorien

Zusätzliche Kategorien:

| Kategorie | Bedeutung | Verhalten |
|---|---|---|
| `transcriptionPreflight` | Quelldatei oder Metadaten nicht sicher prüfbar | kein Upload; Original behalten |
| `insufficientWorkingStorage` | freier Speicher reicht nicht | kein Upload; Speicherbedarf erklären |
| `segmentPlanning` | valider Plan nicht erzeugbar | Session fehlgeschlagen; Original behalten |
| `segmentExport` | Arbeitssegment nicht erzeugbar | nur betroffenes Segment fehlgeschlagen |
| `segmentValidation` | Segment leer, beschädigt oder zu groß | neu teilen oder gezielt fehlschlagen |
| `segmentTranscription` | Providerfehler eines Segments | segmentweiser Retry/Resume |
| `transcriptMerge` | Teiltexte nicht sicher zusammenführbar | Teiltexte behalten; keine Einfügung |
| `sessionPersistence` | Manifest nicht atomar speicherbar | Verarbeitung stoppen; keine weitere Cloudanfrage |
| `sourceChanged` | Original seit Planung verändert | Fortsetzen blockieren; Neuplanung anbieten |

Bestehende Netzwerk-, Timeout-, Rate-Limit-, Provider- und Credentialkategorien bleiben wirksam.

## 17. Performance und Messung

### 17.1 Messpunkte

Inhaltsfreie Signposts messen mindestens:

- Hotkey empfangen,
- Overlay auf `finalizing`,
- `SCStream.stopCapture` Start/Ende,
- Capture-Queue geleert,
- `AVAssetWriter.finishWriting` Start/Ende,
- Audio-Preflight Start/Ende,
- Segmentplanung Start/Ende,
- Export je Segment Start/Ende,
- Multipart-Erzeugung Start/Ende,
- Upload je Segment Start/Ende,
- Manifest-Persistenz Start/Ende,
- Merge Start/Ende,
- Smart Dictation und Einfügung Start/Ende.

Logs enthalten keine Audioinhalte, Transkripte, Prompts, API-Keys, App-/Mediennamen oder absolute private Pfade.

### 17.2 Vorläufige Budgets

Die Baseline aus Schritt 3.4.0 darf Ziele begründet schärfen, aber nicht ersatzlos entfernen.

| Messgröße | Ziel auf Referenz-Mac |
|---|---|
| Hotkey bis sichtbares `Finalizing` | p95 ≤ 100 ms |
| längste zusammenhängende 3.4-Arbeit auf Main Actor | ≤ 50 ms |
| Pegel-/Fortschritts-UI | höchstens 10 Updates/s je Anzeige |
| Finalisierung einer 60-Minuten-Systemaudioaufnahme | Ziel p95 ≤ 3 s, dokumentiertes Maximum ≤ 5 s |
| erste Fortschrittsanzeige nach Writer-Finalisierung | Ziel ≤ 2 s |
| zusätzlicher stabiler RAM-Bedarf der Long-Form-Verarbeitung | Ziel ≤ 200 MB |
| RAM-Wachstum 30 zu 120 Minuten bei gleicher Verarbeitung | nicht proportional zur Dauer; Ziel ≤ 50 MB Differenz im stabilen Zustand |
| vorbereitete Audiosegmente gleichzeitig | höchstens 2 |
| parallele Netzwerktranskriptionen | genau 1 |

Netzwerkdauer selbst erhält wegen externer Schwankung kein hartes Latenzziel. UI-Reaktion, Timeout, Pause und Recovery bleiben trotzdem messbar.

### 17.3 Referenzfälle

- 5 Minuten Mikrofon,
- 30, 60 und 120 Minuten Systemaudio,
- stille Passagen, durchgängige Sprache und Musik-/Sprache-Mischung,
- Lautsprecher, kabelgebundene Ausgabe und Bluetooth,
- Öffnen von Settings/History während Aufnahme und Finalisierung,
- Stop über Toggle und Press-and-Hold,
- Offline, 429 und simulierte langsame Providerantwort.

## 18. Migration

### 18.1 Versionsstände

- `historySchema`: 4 → 5,
- `dictationRecordSchema`: 4 → 5,
- neues `transcriptionSessionSchema`: 1,
- Settingsänderungen nur additiv und mit sicheren Defaults.

### 18.2 History-Migration

- Vor dem ersten Schreiben von Schema 5 wird einmalig `dictations-pre-3.4.json` erzeugt.
- Bestehende Backups wie `dictations-pre-3.2.json` werden nicht überschrieben.
- Alte Records erhalten `transcriptionSessionID = nil`, keine Segmente und keinen partiellen Text.
- Bestehende Statuswerte und Texte bleiben unverändert.
- Migration aktiviert niemals automatisch eine Cloudanfrage oder Systemaudioquelle.
- Ein Fehler lässt die originale Historydatei und Sicherung unangetastet.

### 18.3 Laufende 3.3-Fehlerzustände

Bestehende Records mit `recorded`, `transcriptionFailed` oder `recovered` können bei manuellem Retry durch den neuen ModeResolver laufen. Eine alte große Aufnahme darf dadurch erstmalig segmentiert werden. Bereits abgeschlossene Records werden nicht rückwirkend verändert.

### 18.4 Sessionmigration

Sessionmanifeste prüfen ihre eigene Schema-Version. Eine unbekannte neuere Version wird nicht überschrieben. Für zukünftige Änderungen gelten additive Felder, sichere Defaults und Fixture-Tests.

## 19. Datenschutz und Sicherheit

- API-Key bleibt im macOS-Schlüsselbund und flüchtigen Sessioncache.
- Originalaufnahme, Arbeitssegmente, Manifest und Teiltexte bleiben lokal, bis ein Segment bewusst an den Transkriptionsprovider gesendet wird.
- Pro Request wird nur das aktuelle Segment plus begrenzter Kontextprompt übertragen.
- Keine Segmentdatei enthält Bildschirmvideo oder Bilddaten.
- Sessiondateien enthalten keine Namen der im Systemaudio erfassten Apps, Fenster, Meetings oder Medien.
- Teiltranskripte werden nicht in Logs geschrieben.
- Temporäre Multipart- und Segmentdateien werden nach Erfolg und bei Stale-Cleanup kontrolliert entfernt.
- Diagnosemetriken sind inhaltsfrei und lokal.
- Keine Zugangsdaten, persönlichen Aufnahmefixtures oder Release-Artefakte werden in Git aufgenommen.

## 20. Tests

### 20.1 Unit-Tests

Mindestens:

- ModeResolver für kleine, große und nicht prognostizierbare Dateien,
- Segmentplan für 0, 1, 2 und viele Grenzen,
- vollständige Abdeckung und erlaubte Überlappung,
- Pausensuche mit Stille, Sprache, Musik und ohne Kandidat,
- Größenlimit und deterministisches Teilen übergroßer Segmente,
- stabile Segmentnamen und Zeitdarstellung,
- Sessionmanifest Roundtrip und atomare Ersetzung,
- Invarianten und Ablehnung beschädigter Manifeste,
- Source-Fingerprint gleich/geändert,
- Zustandsübergänge einschließlich Pause und Unterbrechung,
- Retry nur des fehlgeschlagenen Segments,
- erfolgreiche Präfixsegmente werden nicht erneut angefordert,
- Prompt entsteht aus dem unmittelbar vorherigen Erfolg,
- Merge in richtiger Reihenfolge,
- exakte, normalisierte, zu kurze und unsichere Grenzüberlappung,
- Merge ist idempotent und versionsstabil,
- History-Schema-4-Fixture migriert auf 5 mit Backup,
- Retention schützt fortsetzbare Sessions,
- Orphan-Recovery erkennt M4A, aber keine Arbeitssegmente,
- Cancellation während Planung, Export, Retry-Sleep und Upload,
- Progressereignisse sind monoton und begrenzt.

### 20.2 Integrationstests

- Original → drei lokale Segmente → Stub-Provider → geordneter Merge,
- Fehler in Segment 1, 2 und letztem Segment,
- App-Neustart nach zwei Erfolgen; nur Rest wird aufgerufen,
- Unterbrechung bei `uploading`; Segment wird korrekt wiederholbar,
- fehlende Arbeitsdatei wird aus Original regeneriert,
- zu großes exportiertes Segment wird vor Netzwerkzugriff geteilt,
- zu wenig Speicher verhindert jeden Provideraufruf,
- Manifest-Persistenzfehler stoppt vor dem nächsten Upload,
- Mergefehler verhindert Smart Dictation und Einfügung,
- erfolgreicher Merge startet Smart Dictation und Einfügung genau einmal,
- kurzer Einzelupload bleibt unverändert,
- Systemaudio-M4A und Mikrofon-WAV durchlaufen beide Pfade,
- Recovery, History und Retention über einen simulierten Neustart.

### 20.3 Performance-Tests

- synthetische beziehungsweise datenschutzfreie 30-, 60- und 120-Minuten-Assets,
- Main-Actor-Hitch-Messung beim Stoppen und Finalisieren,
- Speicherprofil Segmentplanung und Export,
- Anzahl gleichzeitig vorhandener Arbeitsdateien,
- Zeit bis zum ersten Progressereignis,
- Callback- und Pegelverhalten während langer Aufnahme,
- wiederholtes Stoppen unter CPU- und I/O-Last.

Zeitbasierte CI-Assertions dürfen nur für grobe Regressionen verwendet werden. Verbindliche Performanceabnahme erfolgt auf dem dokumentierten Referenz-Mac mit Instruments/Signposts.

### 20.4 Manuelle Tests

- kurze, 30-, 60- und mindestens 120-minütige Systemaudioaufnahme,
- lange Mikrofonaufnahme,
- Deutsch, Englisch und gemischte Fachbegriffe,
- Pause an sauberer Sprechpause und durchgehende Sprache ohne Pause,
- Offline/Online-Wechsel zwischen Segmenten,
- API-Rate-Limit und temporärer Serverfehler,
- App während Segment 2 beenden und neu starten,
- Pause und Resume aus History,
- Clipboard und Ziel-App bleiben bis zum Gesamtabschluss unverändert,
- Settings/History während Aufnahme, Finalisierung und Transkription,
- globale Stop- und Cancel-Tastenkürzel,
- Lautsprecher, Kabelkopfhörer und Bluetooth,
- wenig freier Speicher,
- beschädigte oder extern veränderte Originaldatei,
- Retention und explizites Löschen einer pausierten Session,
- Notes, Safari, Chrome, Mail, VS Code und Word oder gleichwertige Ziel-App,
- Light/Dark Mode, Reduced Motion und mehrere Displays.

### 20.5 Community-ZIP-Gate

Die veröffentlichungsfähige App ist ausschließlich die Ausgabe von:

```sh
./scripts/build-community-release.sh
```

Vor Tag oder GitHub Release müssen:

1. Unit-Tests vollständig erfolgreich sein.
2. Debug- und Release-Build erfolgreich sein.
3. `git diff --check` sauber sein.
4. Community-ZIP und SHA-256 erzeugt und verifiziert sein.
5. ZIP in einen frischen Ort entpackt werden.
6. Architektur, Ad-hoc-Signatur und Entitlements der entpackten App geprüft werden.
7. Genau diese entpackte App kurze Mikrofon- und Systemaudio-Smokes bestehen.
8. Genau diese App mindestens eine segmentierte lange Systemaudioaufnahme inklusive Merge, History und Einfügung bestehen.
9. Recovery durch Beenden und Neustart derselben entpackten App bestehen.
10. Installation beziehungsweise Update auf einem zweiten macOS-Konto oder Mac geprüft werden.

Tests einer DerivedData-App ersetzen dieses Gate nicht. UI-Tests bleiben optional, solange der XCTest-Runner keine separate Bedienungshilfenfreigabe besitzt; die entsprechende manuelle Abnahme bleibt Pflicht.

## 21. Akzeptanzkriterien

Phase 3.4 ist lokal abgenommen, wenn:

1. Eine kurze Aufnahme ohne unnötige Segmentdateien den bestehenden Einzelupload verwendet.
2. Eine lange Mikrofon- und eine lange Systemaudioaufnahme automatisch in valide Segmente geteilt werden.
3. Kein Segment die lokale harte Uploadgrenze überschreitet.
4. Kein Netzwerkzugriff vor erfolgreichem Datei-, Größen- und Speicherpreflight erfolgt.
5. Segmentgrenzen bevorzugt an geeigneten Pausen liegen und der Zeitfallback kontrolliert überlappt.
6. Alle Teiltranskripte in Segmentreihenfolge persistiert und zusammengeführt werden.
7. Prompt-Kontext die Segmentreihenfolge nicht verändert und keine gespeicherten Teiltexte überschreibt.
8. Grenzduplikate konservativ entfernt werden, ohne unsichere Inhalte zu löschen.
9. Ein Fehler in Segment N erfolgreiche Segmente 0 bis N−1 erhält.
10. Resume nach Fehler oder Neustart kein erfolgreiches Segment erneut hochlädt.
11. Eine fehlende Arbeitsdatei für ein offenes Segment aus dem Original reproduziert werden kann.
12. Originalaufnahme und alle vorhandenen Textstufen bei jedem Teilfehler erhalten bleiben.
13. Partielle Texte niemals automatisch eingefügt werden.
14. Smart Dictation und Einfügung nach vollständigem Merge genau einmal laufen.
15. Overlay und History korrekten, monotonen Segmentfortschritt zeigen.
16. Pause kurzfristig wirksam wird und die Session fortsetzbar bleibt.
17. Retention keine aktive, pausierte oder fehlgeschlagene Session entfernt.
18. M4A-Orphans erkannt und Segmentarbeitsdateien nicht fälschlich als Diktat importiert werden.
19. Migration aus Schema 4 alle vorhandenen Daten bewahrt und `dictations-pre-3.4.json` anlegt.
20. Die Performancebudgets erreicht oder Abweichungen vor Freigabe ausdrücklich als Blocker dokumentiert werden.
21. Alle bestehenden Mikrofon-, Preview-, Smart-Dictation-, Profile-, Einfügungs-, History-, Retry-, Recovery- und Restore-Tests bestehen.
22. Die finale Community-ZIP das vollständige Gate aus Abschnitt 20.5 besteht.
23. Vor diesem Gate weder Tag noch GitHub Release erstellt wird.

## 22. Risiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| Schnitt mitten im Wort | begrenzte Pausensuche, kurze Fallback-Überlappung, konservativer Merge |
| Textverlust durch aggressive Deduplizierung | Mindestübereinstimmung, nur Grenzfenster, bei Unsicherheit nichts löschen |
| erneute Kosten nach Crash | Erfolg vor nächstem Upload atomar speichern |
| Manifest und History widersprechen sich | klare Commit-Reihenfolge, IDs und Start-Reconciliation |
| Segment über Providerlimit | weiches Ziel, harte Reserve, Post-Export-Prüfung und deterministisches Teilen |
| doppelter Speicherbedarf | höchstens aktuelles plus nächstes Segment; Erfolge nach Persistenz bereinigen |
| langer Export blockiert UI | Actor/Worker außerhalb Main Actor, Progress und Cancellation |
| `AVAssetWriter` finalisiert langsam | Signposts, Capture-Queue-Drain messen, Writerlebenszyklus isolieren |
| Source-Datei extern geändert | Fingerprint vor Resume, keine stille Weiterverarbeitung |
| History-Retention erzeugt Waise | Sessions automatisch schützen und gemeinsam löschen |
| zu großer Coordinator | Long-Form-Orchestrierung in dedizierten Komponenten |
| Parallelität erzeugt Reihenfolge-/Rate-Limitfehler | Netzwerkparallelität in 3.4 fest auf 1 |
| API-Grenze ändert sich | zentraler Grenzwert und offizielle Prüfung vor Release |
| Community-Signatur verändert Berechtigungen | finale ZIP auf frischem Konto/Mac testen und Guides aktualisieren |

## 23. Observability und Datenschutzprüfung

Zulässige lokale Diagnosewerte:

- Record-/Session-ID,
- Segmentindex und Anzahl,
- Dauer, Format und Bytezahl,
- technische Status- und Fehlerkategorie,
- Laufzeit einzelner Phasen,
- Retryanzahl,
- anonymfreie Geräteklasse des Referenztests, sofern manuell dokumentiert.

Verboten:

- Transkript- oder Promptinhalt,
- Audiobuffer,
- API-Key oder Authorization-Header,
- Namen abgespielter Apps, Fenster, Meetings oder Medien,
- absolute private Benutzerpfade,
- automatisch versendete Telemetrie.

## 24. Rollout und Definition of Done

Phase 3.4 ist erst „Done“, wenn:

- alle Pflichtfunktionen implementiert und code-reviewed sind,
- automatisierte Tests und dokumentierte manuelle Langzeittests bestehen,
- Performanceprofil und Messwerte dem Repository beigefügt oder im Arbeitsplan protokolliert sind,
- Migration und Recovery mit realistischen Fixtures geprüft sind,
- README, CHANGELOG, PRIVACY, Release Guide und Installationsanleitungen aktualisiert sind,
- keine Schlüssel, privaten Audiodaten oder Buildartefakte im Repository liegen,
- die finale Community-ZIP vollständig getestet ist,
- der Arbeitsbaum vor Release sauber ist,
- Version, Build, Tag und Release Notes erst nach der lokalen Freigabe festgelegt beziehungsweise finalisiert werden,
- GitHub-Veröffentlichung eine getrennte, ausdrücklich freigegebene Aktion bleibt.
