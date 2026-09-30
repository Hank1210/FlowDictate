# Product Requirements Document: FlowDictate Phase 4.1

**Phase:** 4.1 – Synchronized Meeting Capture
**Status:** Vorbereitungsentwurf nach Abschluss von 4.0.2; Implementierung erst nach finaler Scope-Freigabe
**Stand:** 10. September 2026
**Ausgangsversion:** FlowDictate 4.0.2
**Zielversion:** FlowDictate 4.1.0; Buildnummer erst vor dem Release festlegen
**Abhängigkeit:** `FlowDictate_PRD_Phase_4_0.md` und die Long-Form-/Recoveryverträge aus `FlowDictate_PRD_Phase_3_4.md`

## 1. Zweck

Phase 4.1 ergänzt eine echte kombinierte Aufnahme von Mikrofon und digitalem macOS-Systemaudio. Der Hauptanwendungsfall sind Meetings, Interviews, Schulungen und Gespräche, bei denen sowohl die eigene Stimme als auch die Wiedergabe anderer Anwendungen erhalten und transkribiert werden sollen.

Die beiden Quellen werden nicht während der Aufnahme destruktiv zu einer einzigen Datei summiert. FlowDictate speichert synchronisierte Originalspuren, eine gemeinsame Zeitachse und daraus abgeleitete Transkripte. Clipping, Drift, Aussetzer oder der Ausfall einer Quelle dürfen die jeweils andere Quelle nicht zerstören.

Ein externes Feature-Briefing vom 2. September 2026 hat zusätzlich Diktat-Übersetzung und Meeting-Transkription mit Diarization als mögliche Ausbaurichtungen vorgeschlagen. Da diese Bewertung nur auf dem öffentlichen README und nicht auf einer Codeprüfung basierte, wird sie in diesem PRD als Produktinput berücksichtigt, aber nicht als technische Implementierungsgrundlage übernommen. Die strategische Bewertung bestätigt den Schwerpunkt auf Meeting Capture; Übersetzung und Sprecher-Diarization bleiben bewusst von der 4.1-Pflichtumsetzung getrennt.

## 2. Produktziel

### 2.1 Leitsatz

Ein FlowDictate-Meeting ist eine lokal gesicherte, synchronisierte Mehrspur-Session – keine irreversible gemischte Audiodatei.

### 2.2 Ergebnis der Phase

Nach Abschluss von Phase 4.1 gilt:

1. Mikrofon und Systemaudio werden gleichzeitig aufgezeichnet.
2. Beide Quellen bleiben als getrennte Originalspuren erhalten.
3. Eine gemeinsame monotone Zeitbasis ermöglicht nachvollziehbare Ausrichtung und Driftkorrektur.
4. Clipping und Signalverlust werden pro Spur erkannt und sichtbar gemacht.
5. Abgeleitete Mix- oder Normalisierungsdateien verändern niemals die Originalspuren.
6. Beide Spuren können lokal oder über den in 4.0 gewählten Provider segmentiert und recoverbar transkribiert werden.
7. Das Ergebnis wird zeitlich geordnet und mit mindestens den Rollen `You` und `System Audio` dargestellt.
8. Überlappende Sprache wird erhalten statt willkürlich zu einem Satz vermischt.
9. Aufnahme, Stop, globale Hotkeys und UI bleiben auch bei langen Meetings responsiv.
10. Teilfehler, Crash und Neustart bewahren jede vorhandene Spur und jedes erfolgreiche Teiltranskript.
11. Vor kombinierten Aufnahmen bestätigt der Nutzer aktiv, dass er für Information und erforderliche Einwilligungen der Beteiligten verantwortlich ist.

## 3. Produktentscheidungen

### 3.1 Ausschließlich macOS

Phase 4.1 ist bewusst macOS-spezifisch. ScreenCaptureKit, macOS-Audiogeräte, globale Hotkeys und Accessibility werden nicht zugunsten einer hypothetischen mobilen App abstrahiert oder eingeschränkt.

### 3.2 Getrennte Tracks statt Live-Mix

Die veröffentlichten Originale bestehen aus mindestens:

- Mikrofontrack,
- Systemaudiotrack,
- Sessionmanifest mit Zeitachsen- und Qualitätsinformationen.

Ein hörbarer Gesamtmix ist ein optionales abgeleitetes Artefakt. Er ist nie die einzige oder maßgebliche Quelle für Transkription oder Recovery.

### 3.3 Selbst- und Remote-Rolle

Der Mikrofontrack erhält die Rolle `You`. Der Systemaudiotrack erhält die Rolle `System Audio`. Phase 4.1 versucht nicht, mehrere Personen innerhalb des Systemaudiotracks voneinander zu unterscheiden.

Diese Einschränkung ist produktseitig bewusst: Die erste 4.1-Version soll zuverlässig erfassen, synchronisieren, recovern und zeitlich zusammenführen. Session-lokale Sprechertrennung oder persistente Sprecheridentität sind keine Voraussetzung für den Erfolg von 4.1 und würden Datenschutz-, Consent-, Modell- und UX-Komplexität deutlich erhöhen.

### 3.4 Provider und persistierter Job aus 4.0

Jede Meeting-Session friert Provider, Engine, Modell, Sprache, Privacy-Modus und relevante Profiloptionen ein. Die Transkription läuft als persistierter 4.0-Dictation-Job. Während der Meetingverarbeitung wird keine weitere Aufnahme angenommen; eine fortlaufende Diktierkette wäre eine spätere, separat zu validierende Erweiterung.

### 3.5 Keine versteckte Aufnahme

Eine kombinierte Aufnahme besitzt immer einen sichtbaren Aufnahmestatus. FlowDictate bietet keine Funktion zum heimlichen Start, zum Verbergen der Aufnahme oder zum Umgehen von macOS-Berechtigungen.

### 3.6 Explizites Consent-Gate für Meetingaufnahmen

Bei `Microphone + System Audio` muss FlowDictate vor dem ersten Start eine klare, nicht versteckte Bestätigung verlangen. Der Nutzer bestätigt aktiv, dass er andere Beteiligte informiert hat beziehungsweise die erforderlichen Einwilligungen für die Aufnahme besitzt. Diese Bestätigung ist kein Ersatz für Rechtsberatung und macht keine pauschale Aussage zur Zulässigkeit in allen Ländern, Bundesstaaten, Unternehmen oder Meetingkontexten.

Produktentscheidung für 4.1:

- Das Consent-Gate erscheint spätestens beim ersten Start einer kombinierten Aufnahme.
- Der Hinweis ist kurz, verständlich und handlungsbezogen formuliert.
- Ohne aktive Bestätigung startet keine kombinierte Aufnahme.
- Die Bestätigung kann optional gemerkt werden, muss aber in Settings jederzeit zurückgesetzt werden können.
- Bei wesentlichen Änderungen am Aufnahmeumfang, zum Beispiel neu aktivierter Systemaudioaufnahme, darf FlowDictate erneut bestätigen lassen.
- FlowDictate bleibt sichtbar im Recordingstatus; das Pop-up darf nicht als einzige Transparenzmaßnahme verstanden werden.
- Der konkrete Text wird vor Release geprüft, damit er nicht wie eine Rechtsgarantie klingt.

### 3.7 Wettbewerbsabgrenzung

OpenWhispr wird für 4.1 als wichtigster Vergleichspunkt behandelt. FlowDictate konkurriert in dieser Phase nicht primär über maximale Plattformbreite oder möglichst viele Modelloptionen, sondern über:

- native macOS-Integration,
- klare Privacy-Modi,
- getrennte und recoverbare Originalspuren,
- robuste Langform- und Restart-Sicherheit,
- transparente History mit Zwischenständen,
- verlässliche lokale Verarbeitung auf Apple Silicon.

Der Release darf deshalb nicht nur funktional vorhanden sein, sondern muss besonders bei Stabilität, Recovery, Datenschutzverständlichkeit und Installation vertrauenswürdig wirken.

### 3.8 Übersetzung bleibt separater Backlog-Kandidat

Diktat-Übersetzung ist ein plausibles späteres Feature: Sprache X diktieren, Text in Zielsprache Y einfügen. Für 4.1 wird es nicht in den Scope aufgenommen.

Produktentscheidung für diesen Stand:

- Cloud-only-Übersetzung über OpenAI wäre technisch am naheliegendsten, passt aber nicht in den Fully-Offline-Modus.
- Lokale Übersetzung würde eine zusätzliche Modell-/OS-Strategie benötigen und darf 4.1 nicht fragmentieren.
- Wenn Übersetzung später umgesetzt wird, muss sie als eigener Privacy-gated Prompt-/Enhancement-Typ geplant werden.
- App-Profile oder Hotkeys pro Zielsprache sind sinnvolle spätere UX-Optionen, aber kein Bestandteil von 4.1.

## 4. Umfang

### 4.1 Pflichtumfang

- neue, echte Quelle `Microphone + System Audio`,
- explizites Consent-Gate vor kombinierter Aufnahme,
- gemeinsame Start-/Stop-Orchestrierung,
- getrennte lokale Originalspuren,
- monotone gemeinsame Timeline,
- Startversatz-, Gap- und Driftmessung,
- Offline-Korrektur nur für abgeleitete Tracks,
- Clipping- und Pegelerkennung je Quelle,
- sichtbare Dual-Level-Anzeige,
- lokale Speicherplatzschätzung vor langen Sessions,
- atomare Meeting-Session-Persistenz,
- Long-Form-Segmentierung je Track,
- persistierter Track- und Segmentfortschritt,
- Resume ohne erneute erfolgreiche Segmente,
- zeitbasierter Transcript-Merge,
- Rollenkennzeichnung `You`/`System Audio`,
- History-Detailansicht für Tracks, Qualität und Text,
- Recovery bei Ausfall einer Quelle,
- sichere Retention und explizites Löschen,
- inhaltsfreie Performance- und Qualitätsmetriken,
- vollständige Regression von 4.0 und 3.4,
- finale Community-ZIP-Abnahme.

### 4.2 Soll-Umfang mit eigenem Gate

- abgeleiteter normalisierter Gesamtmix für Wiedergabe/Export,
- Export eines Meetings als Markdown mit Zeitstempeln,
- automatische lokale Zusammenfassung, Entscheidungen und Aufgaben, sofern eine lokale Enhancement-Engine verfügbar ist,
- Providerzeitstempel auf Wort- oder Satzebene,
- manuelle Korrektur der Spurrollen oder Zeitachse,
- Erkennung und Kennzeichnung von Musik-/Nichtsprachpassagen.

### 4.3 Nicht Bestandteil

- Video-, Bildschirmbild- oder Fensteraufzeichnung,
- Umgehung von Screen-&-System-Audio-Berechtigungen,
- Aufnahme von Telefonaten oder geschützten Medien über nicht öffentliche APIs,
- versteckte oder ferngesteuerte Aufnahme,
- Sprechertrennung innerhalb des Systemaudiotracks,
- Speaker-Diarization mehrerer Remoteteilnehmer,
- Sprecheridentifikation anhand biometrischer Profile,
- persistente Sprecheridentität über mehrere Sessions hinweg,
- Diktat-Übersetzung in andere Zielsprachen,
- Cloud-Live-Streaming während der Aufnahme,
- Live-Finaltranskript für Systemaudio,
- destruktive automatische Lautheitsänderung der Originaltracks,
- automatische Veröffentlichung oder Freigabe eines Meetingtexts,
- Kalender-, Slack- oder MCP-Integration,
- iPhone-/iPad-Meetingaufnahme,
- Ersatz der JSON-/Manifestpersistenz durch SQLite.

## 5. Nutzerablauf

### 5.1 Start

1. Nutzer wählt `Microphone + System Audio`.
2. FlowDictate zeigt ausgewähltes Mikrofon, Systemaudioerlaubnis, Provider/Privacy-Modus und geschätzten Speicherbedarf pro Stunde.
3. FlowDictate zeigt vor dem ersten Start beziehungsweise nach zurückgesetzter Bestätigung ein Consent-Pop-up für Meetingaufnahmen.
4. Der Nutzer muss aktiv bestätigen, dass er für Information und erforderliche Einwilligungen der Beteiligten verantwortlich ist; ohne Bestätigung startet keine kombinierte Aufnahme.
5. Beide Berechtigungen werden vor Aufnahmebeginn geprüft.
6. Eine gemeinsame Session wird angelegt und atomar in Status `preparing` gespeichert.
7. Beide Recorder werden über eine Startbarriere gestartet.
8. Erst wenn mindestens eine Quelle valide Samples liefert, wechselt die Session zu `recording`; ein Ausfall der zweiten Quelle wird sofort sichtbar.

### 5.2 Aufnahme

- Overlay zeigt getrennte Pegel `Mic` und `System`.
- Clippingwarnungen sind spurbezogen.
- Verbindungs-/Gerätewechsel oder ein Gap wird sichtbar, aber die Session bleibt recoverbar.
- Stop und Cancel gelten für die gesamte Meeting-Session.
- Die bereits geschriebenen Originalspuren werden bei Cancel nicht vernichtet.

### 5.3 Stop und Verarbeitung

1. Overlay bestätigt Stop unverzüglich.
2. Beide Capturepfade werden unabhängig kontrolliert beendet.
3. Sessionmanifest wird mit finalen Trackmetadaten atomar gespeichert.
4. FlowDictate analysiert Dauer, Gap, Drift, Peaks und Speicherzustand außerhalb des Main Actors.
5. Die Session wird als 4.0-Dictation-Job persistiert und unmittelbar verarbeitet.
6. Tracksegmente werden in stabiler Zeitreihenfolge transkribiert.
7. Teiltexte werden persistiert und anschließend in eine Meeting-Timeline gemerged.
8. Erst nach vollständigem Merge dürfen Smart Dictation oder eine Meeting-Zusammenfassung laufen.

## 6. Zielarchitektur

```text
MixedRecordingSessionCoordinator actor
        │
        ├── MicrophoneTrackRecorder ──> microphone original
        │          └── timestamp anchors / peak / gaps
        │
        └── SystemAudioTrackRecorder ─> system-audio original
                   └── timestamp anchors / peak / gaps
                            │
                    MeetingSessionStore actor
                            │
                  SynchronizationAnalyzer
                     ├── offset model
                     ├── drift model
                     └── quality report
                            │
              per-track LongFormTranscriptionRunner
                            │
                 TimedTranscriptMerger
                            │
               History / playback / export
```

### 6.1 Komponenten

| Komponente | Verantwortung |
|---|---|
| `MixedRecordingSessionCoordinator` | gemeinsame Session, Startbarriere, Stop, Cancel und Fehler beider Recorder |
| `MicrophoneTrackRecorder` | Mikrofonaufnahme, Zeitanker, Peaks, Sample-/Geräteinformationen |
| `SystemAudioTrackRecorder` | digitale App-Audiowiedergabe ohne Video, Zeitanker, Peaks und Gaps |
| `MeetingSessionStore` | Manifest und Trackstatus atomar persistieren |
| `SynchronizationAnalyzer` | Offset, Gap und Drift aus Zeitankern bestimmen |
| `DerivedTrackRenderer` | optional normalisierte/ausgerichtete Arbeits- oder Mixdateien erzeugen |
| `TrackTranscriptionRunner` | 3.4-Long-Form-Verarbeitung je Track mit 4.0-Provider |
| `TimedTranscriptMerger` | Tracksegmente zeitlich ordnen und Überlappungen erhalten |
| `MeetingQualityReport` | inhaltsfreie Sync-, Clipping-, Gap- und Trackvollständigkeit zusammenfassen |

## 7. Audio- und Synchronisierungsstrategie

### 7.1 Gemeinsame Zeitbasis

- Alle Capturetimestamps werden auf eine monotone macOS-Hostzeit abgebildet.
- Wall-Clock-Zeit (`Date`) dient nur Anzeige und Sessionmetadaten, nicht Sampleausrichtung.
- Pro Spur werden mindestens Startanker, Endanker und periodische Zwischenanker persistiert.
- Rohcallbacks schreiben keine großen Timelineobjekte auf dem Main Actor.

### 7.2 Startversatz

Recorder können nicht garantiert im exakt gleichen Sample starten. Das Manifest speichert deshalb:

- angeforderte gemeinsame Startzeit,
- ersten gültigen Sampletimestamp je Track,
- beobachteten Startversatz,
- fehlende Anfangszeit als explizites Gap.

FlowDictate darf fehlende Samples nicht durch erfundenes Audio ersetzen. Eine abgeleitete Darstellung darf Stille zur Ausrichtung einfügen.

### 7.3 Drift

- Drift wird aus mindestens zwei, bei langen Aufnahmen mehreren Zeitankern geschätzt.
- Die Korrektur verwendet eine dokumentierte monotone Abbildung von Trackzeit auf Sessionzeit.
- Kleine Drift darf in abgeleiteten Dateien durch kontrolliertes Resampling korrigiert werden.
- Originaldateien werden nie resampled oder überschrieben.
- Nichtlineare Sprünge und Gerätewechsel werden als separate Zeitabschnitte/Gaps modelliert, nicht durch einen globalen Faktor versteckt.

### 7.4 Formatentscheidung

Die endgültigen Originalformate werden nach einem Capture-Spike festgelegt. Verbindlich sind:

- verlässliche Recovery nach Prozessabbruch,
- mindestens Mono pro Quelle,
- persistierte native Samplerate und Kanalzahl,
- kein Qualitätsverlust durch wiederholtes Re-Encoding,
- kontrollierter Speicherbedarf für 30–120 Minuten,
- AVFoundation-kompatible Segmentierung,
- keine Video- oder Bildtracks.

Mikrofon-WAV/CAF und Systemaudio-M4A dürfen als unterschiedliche Originalformate bestehen bleiben, sofern Timeline und Ableitungen sie reproduzierbar ausrichten.

## 8. Clipping- und Pegelschutz

### 8.1 Messung

Je Track werden inhaltsfrei erfasst:

- Peak-Amplitude,
- Anzahl beziehungsweise Dauer geclippter Samples/Frames,
- Dauer ohne verwertbares Signal,
- durchschnittlicher Pegel in groben Buckets,
- Anzahl Gaps oder verworfener Buffers.

Es werden keine Pegelzeitreihen gespeichert, aus denen Sprache rekonstruiert werden könnte.

### 8.2 Verhalten

- Mic-Clipping zeigt eine unmittelbare Warnung und verweist auf Eingangspegel/Mikrofonabstand.
- Systemaudio wird digital unverändert aufgezeichnet; FlowDictate erhöht dessen Originalpegel nicht.
- Eine Quelle wird nicht automatisch abgesenkt, weil die andere laut ist.
- Ein abgeleiteter Mix reserviert Headroom und verwendet höchstens einen transparenten Limiter.
- Ziel für abgeleiteten Mix: True Peak höchstens `-3 dBFS`.
- Limiter-/Gainwerte werden im Manifest der Ableitung gespeichert.
- Eine Clippingwarnung blockiert Stop oder Speicherung nie.

## 9. Session- und Dateimodell

### 9.1 Dateilayout

Konzeptionell:

```text
MeetingSessions/<session-id>/
├── session.json
├── tracks/
│   ├── microphone.<format>
│   └── system-audio.m4a
├── derived/
│   ├── aligned-microphone.m4a
│   ├── aligned-system-audio.m4a
│   └── mixed-preview.m4a
└── transcription/
    ├── microphone-session.json
    ├── system-audio-session.json
    └── merged-timeline.json
```

Konkrete Ablageorte müssen die bestehende Recording-Folder-Berechtigung, Application Support und das 3.4-Sessionlayout berücksichtigen. Nutzerlöschen entfernt zusammengehörige Dateien kontrolliert; fortsetzbare Sessions bleiben durch Retention geschützt.

### 9.2 Statusmodelle

```swift
enum MeetingSessionStatus: String, Codable, Sendable {
    case preparing
    case recording
    case finalizing
    case queued
    case transcribing
    case merging
    case completed
    case partial
    case paused
    case failed
    case cancelled
}

enum MeetingTrackRole: String, Codable, Sendable {
    case localSpeaker
    case systemAudio
}

enum MeetingTrackStatus: String, Codable, Sendable {
    case preparing
    case recording
    case finalized
    case unavailable
    case interrupted
    case transcriptionPending
    case transcribing
    case transcribed
    case failed
}
```

### 9.3 Trackrecord

```swift
struct MeetingAudioTrack: Codable, Sendable, Identifiable {
    var id: UUID
    var role: MeetingTrackRole
    var status: MeetingTrackStatus
    var audioRelativePath: String?
    var formatIdentifier: String?
    var sampleRate: Double
    var channelCount: Int
    var firstHostTime: UInt64?
    var lastHostTime: UInt64?
    var durationMilliseconds: Int64
    var byteCount: Int64
    var timestampAnchors: [TrackTimestampAnchor]
    var gaps: [TrackGap]
    var peakLevel: Float?
    var clippedFrameCount: Int64
    var transcriptionSessionID: UUID?
    var errorCategory: DictationErrorCategory?
    var errorMessage: String?
}
```

### 9.4 Meetingmanifest

```swift
struct MeetingSessionManifest: Codable, Sendable, Identifiable {
    var schemaVersion: Int
    var id: UUID
    var recordID: UUID
    var dictationJobID: UUID?
    var status: MeetingSessionStatus
    var createdAt: Date
    var updatedAt: Date
    var providerID: String
    var engineID: String
    var modelID: String
    var language: String?
    var tracks: [MeetingAudioTrack]
    var synchronization: SynchronizationReport?
    var mergedTimelineRelativePath: String?
    var finalTranscript: String?
    var lastErrorCategory: DictationErrorCategory?
    var lastErrorMessage: String?
}
```

### 9.5 Invarianten

- Eine Mixed Session enthält genau einen vorgesehenen Mikrofon- und einen Systemaudiotrack.
- Jede vorhandene Originaldatei wird durch Pfad, Größe und Dauer validiert.
- Ein Track gilt erst nach atomarem Manifestupdate als finalisiert.
- `completed` erfordert ein valides Endergebnis oder eine ausdrücklich akzeptierte Einspur-Degradierung.
- Ein ausgefallener Track löscht oder invalidiert den anderen nicht.
- Abgeleitete Dateien sind jederzeit aus Originals plus Manifest neu erzeugbar.
- Ein finaler Meetingtext wird höchstens einmal automatisch eingefügt.

## 10. Transkriptionsstrategie

### 10.1 Je Track getrennt

Mikrofon und Systemaudio werden separat transkribiert. Vorteile:

- die eigene Stimme besitzt eine sichere Rollenbezeichnung,
- gleichzeitige Sprecher zerstören nicht die Erkennung beider Quellen,
- Retry und Recovery bleiben je Track möglich,
- Pegel- oder Trackfehler bleiben isoliert,
- spätere Diarization kann additiv auf den Systemtrack aufsetzen.

### 10.2 Zeitstempel

- Providerzeitstempel werden verwendet, wenn die 4.0-Capabilities sie anbieten.
- Ohne feine Providerzeitstempel liefert jeder synchron geplante Audiobereich mindestens Start-/Endzeit des Segments als grobe Zeitgrenze.
- Ein Provider ohne Zeitstempel darf keine scheinbar wortgenaue Timeline erzeugen.
- Timestampqualität wird im Mergeergebnis gekennzeichnet (`word`, `segment`, `trackChunk`).

### 10.3 Merge

`TimedTranscriptMerger` erzeugt geordnete Einträge:

```swift
struct TimedTranscriptEntry: Codable, Sendable, Identifiable {
    var id: UUID
    var trackRole: MeetingTrackRole
    var startMilliseconds: Int64
    var endMilliseconds: Int64
    var text: String
    var timestampPrecision: TimestampPrecision
}
```

Regeln:

- primär nach Startzeit, sekundär stabil nach Trackrolle und Segmentindex sortieren,
- überlappende Einträge beider Tracks erhalten,
- keine wortweise Vermischung ohne geeignete Zeitstempel,
- Long-Form-Überlappungsduplikate zuerst innerhalb eines Tracks entfernen,
- keine Deduplizierung gleicher Sätze zwischen Mic und System, weil Echo oder echte Wiederholung nicht zuverlässig unterscheidbar sind,
- menschenlesbarer Export verwendet Rollen und optionale Zeitstempel,
- optionaler Fließtext darf Rollenmarken nicht verlieren, wenn Sprache überlappt.

## 11. Teilfehler und Recovery

### 11.1 Fehler vor Start

- Mikrofonberechtigung fehlt → Aufnahme startet nicht als Mixed Session.
- Systemaudioberechtigung fehlt → Aufnahme startet nicht als Mixed Session.
- Speicher reicht nicht für konfiguriertes Mindestbudget → Warnung/Abbruch vor Aufnahme.
- ein Recorder kann nicht vorbereitet werden → kein stiller Start mit nur einer Quelle.

### 11.2 Fehler während Aufnahme

Wenn eine Quelle nach erfolgreichem Start ausfällt:

- andere Quelle zeichnet weiter, solange technisch sicher,
- Overlay zeigt sofort `Microphone lost` oder `System Audio lost`,
- Manifest markiert Track und Zeitpunkt,
- Nutzer kann gesamte Session stoppen oder bewusst einspurig fortfahren,
- ohne Nutzerinteraktion darf eine sichere kurze Grace Period verwendet werden; danach bleibt der Warnstatus dauerhaft sichtbar,
- vorhandene Samples beider Tracks bleiben erhalten.

### 11.3 Fehler nach Stop

- Finalisierung eines Tracks fehlgeschlagen → anderer Track und alle geschriebenen Daten bleiben erhalten.
- Syncanalyse fehlgeschlagen → getrennte Tracktranskripte bleiben möglich; kein irreführender Merge.
- Transkription eines Tracks fehlgeschlagen → erfolgreiche Tracksegmente und anderer Track bleiben erhalten.
- Merge fehlgeschlagen → einzelne Tracktranskripte bleiben sichtbar/exportierbar; keine automatische Einfügung.
- Neustart normalisiert aktive Track-/Meetingzustände und bietet Resume aus History.

## 12. History und UX

### 12.1 Historyrecord

History zeigt mindestens:

- `Microphone + System Audio`,
- Gesamtdauer,
- Trackvollständigkeit,
- Provider/Engine/Modell,
- Transkriptionsfortschritt je Track,
- Syncqualität,
- Clipping-/Gapwarnungen,
- Rollen-Timeline und finalen Text,
- Wiedergabe je Track,
- Resume, Retry, Copy, Export und Löschen.

### 12.2 Overlay

- klarer Mixed-Quellenname,
- zwei unterscheidbare Pegel ohne Farbcodierung als einziges Merkmal,
- sichtbare Clipping-/Trackverlustwarnung,
- Stopbestätigung innerhalb des bestehenden Reaktionsbudgets,
- nach Stop `Finalizing tracks…`, danach Queue-/Trackfortschritt,
- Fortschritt zeigt `Microphone 2/4` und `System Audio 1/5` oder eine kompakte gleichwertige Darstellung,
- eine neue 4.0-Aufnahme darf durch Meetingprogress nicht verdeckt werden.

### 12.3 Speicherprognose

Settings zeigen eine konservative Schätzung pro Stunde für:

- beide Originaltracks,
- temporäre Segmente,
- optional abgeleiteten Mix,
- Sicherheitsreserve.

Vor Aufnahme wird kein hartes Dauerlimit behauptet. Bei sehr wenig Speicher wird Start blockiert oder eine verständliche Maximaldauer angeboten.

## 13. Datenschutz, Einwilligung und Sicherheit

- FlowDictate speichert keine Videoframes oder Screenshots.
- Systemaudiofilter schließen FlowDictates eigene Wiedergabe aus, soweit zuverlässig möglich.
- Vor der finalen 4.1-Architekturentscheidung wird geprüft, ob Systemaudio über einen echten audio-only Capture-Pfad statt über einen ScreenCaptureKit-Displaystream aufgenommen werden kann. Ziel ist eine möglichst präzise macOS-Berechtigung wie `Nur Aufnahme von System Audio`, sofern dies mit öffentlichen APIs, Sandbox, Stabilität und macOS-Zielversionen vereinbar ist.
- App-/Fensternamen, Meetingtitel und Teilnehmernamen werden nicht ohne eigene Produktfreigabe persistiert.
- Nutzer ist für Einwilligung und rechtmäßige Aufnahme verantwortlich; Onboarding/Settings weisen verständlich darauf hin.
- Vor Start einer kombinierten Meeting-Aufnahme muss FlowDictate ein explizites Consent-Pop-up anzeigen, sofern die Bestätigung noch nicht erteilt oder zurückgesetzt wurde.
- Ohne aktive Consent-Bestätigung startet `Microphone + System Audio` nicht.
- Die Consent-Bestätigung wird lokal gespeichert, enthält keine Meetinginhalte und kann in Settings zurückgesetzt werden.
- Der Hinweistext darf keine Rechtsberatung simulieren, sondern muss Verantwortung, Einwilligungspflicht und regionale/organisatorische Unterschiede klar benennen.
- Sichtbarer Recordingstatus darf nicht abschaltbar sein.
- Offline-/Cloudkennzeichnung aus 4.0 gilt je Meeting.
- Im Offline-Modus verlassen weder Tracks noch Texte das Gerät.
- Cloudmodus überträgt nur ausdrücklich zur Transkription bestimmte Tracksegmente.
- Teiltranskripte, Zeitlinien und Trackpfade erscheinen nicht in Logs.
- Löschen einer Session entfernt Originals, Ableitungen, Segmente und Manifeste kontrolliert; zuvor erfolgt eine klare Bestätigung.

## 14. Performanceziele

Vorläufige Budgets auf dokumentiertem Referenz-Mac:

| Messgröße | Ziel |
|---|---|
| Hotkey bis sichtbarer Mixed-Recordingstatus | p95 ≤ 150 ms nach erfüllten Berechtigungen |
| Stop bis sichtbares `Finalizing` | p95 ≤ 100 ms |
| längste zusammenhängende 4.1-Arbeit auf Main Actor | ≤ 50 ms |
| Pegelupdates | höchstens 10/s pro sichtbarem Track |
| Sample-/Bufferverlust | 0 in freigegebenen 30-/60-/120-Minuten-Referenzläufen |
| initialer korrigierter Trackversatz | Ziel p95 ≤ 50 ms |
| verbleibende Drift nach 60 Minuten | Ziel ≤ 100 ms |
| verbleibende Drift nach 120 Minuten | Ziel ≤ 200 ms |
| Finalisierung beider Tracks bei 60 Minuten | Ziel p95 ≤ 5 s; UI bleibt bedienbar |
| zusätzlicher stabiler Capture-RAM ohne Transkriptionsmodell | Ziel ≤ 250 MB |
| RAM-Wachstum 30 zu 120 Minuten | nicht proportional zur Audiodauer |
| Stop/Cancel/Hotkeys unter lokaler Inferenzlast | keine wahrnehmbaren Hitches außerhalb Budgets |

Syncziele werden mit reproduzierbaren Impuls-/Klatschtests und Timelineanalyse gemessen. Wahrgenommene Audioqualität allein ist kein ausreichender Nachweis.

## 15. Migration

### 15.1 Vorgesehene Schemata

- `historySchema`: 6 → 7,
- `dictationRecordSchema`: 6 → 7,
- neues `meetingSessionSchema`: 1,
- neues oder erweitertes Track-Timeline-Schema,
- Long-Form-Session nur additiv um Trackbezug erweitern.

### 15.2 Regeln

- Vor erstem Schema-7-Schreiben entsteht `dictations-pre-4.1.json`.
- Alte Mikrofon-/Systemaudiorecords bleiben Single-Track-Records.
- `.mixed` wird erst nach erfolgreicher 4.1-Migration und UI-Freigabe als auswählbare Quelle aktiviert.
- Bestehende Dateien werden nicht rückwirkend in Meetingordner verschoben.
- App-Profile, die keine Mixed-Option kennen, erben keine automatische Quellenänderung.
- Ein Upgrade aktiviert Combined Capture niemals automatisch.

## 16. Tests

### 16.1 Unit-Tests

- Meetingmanifest Roundtrip und Invarianten,
- Startbarriere und duale Recorderzustände,
- Hosttime-/Sessiontime-Konvertierung,
- Startversatz und lineares Driftmodell,
- segmentierte/nichtlineare Gaps,
- Ablehnung rückläufiger Zeitstempel,
- Peak-/Clippingzählung und Privacy-Buckets,
- abgeleiteter Mix respektiert Headroom,
- Originalpfade werden nie als Derived-Ziel verwendet,
- Timed Merge mit serieller und überlappender Sprache,
- stabile Reihenfolge gleicher Zeitstempel,
- keine Cross-Track-Deduplizierung,
- TimestampPrecision-Fallback,
- Trackausfall vor und nach Start,
- Meeting-/Track-Recoveryzustände,
- Retention schützt partielle Sessions,
- Migration Schema 6 → 7,
- vollständige 4.0-Queue- und Providerregression.

### 16.2 Integrationstests

- synthetische Mic-/Systemtracks mit bekanntem Offset,
- konstante positive und negative Drift,
- Geräte-/Sampleratenwechsel mit Gap,
- Mic-Ausfall bei Minute 10, System bleibt erhalten,
- Systemausfall bei Minute 10, Mic bleibt erhalten,
- unabhängige Long-Form-Segmente je Track,
- Neustart nach erfolgreichen Segmenten beider Tracks,
- Fehler nur in einem Track und anschließender Retry,
- Merge erst nach ausreichender Syncvalidierung,
- Offline-Meeting erzeugt keinen Netzwerkrequest,
- Cloud-Meeting sendet ausschließlich Audiodateien/Segmente, nie Video,
- gesperrter Aufnahmestart während Meetingtranskription und korrekte Freigabe danach,
- Löschen entfernt zusammengehörige Dateien ohne fremde Recordings zu berühren.

### 16.3 Performance- und Langzeittests

- 30, 60 und 120 Minuten Dual Capture,
- Stille, durchgängige Sprache, Musik und gleichzeitig sprechende Quellen,
- Bluetoothmikrofon und Wechsel der Ausgaberoute,
- hohe/zu hohe Mikrofonpegel und lautes Systemaudio,
- CPU-, Speicher- und I/O-Last während Capture,
- lokale Inferenz eines vorherigen Jobs während Meetingaufnahme,
- Stop über Toggle und Press-and-hold,
- wiederholtes Start/Stop von zehn kurzen Mixed Sessions,
- Instruments/Signposts für Main-Actor-Hitches, Writerfinalisierung und Bufferverluste.

### 16.4 Manuelle Tests

- Zoom, Teams, Meet oder gleichwertige Meetingquelle,
- Browseraudio, Musik, Video und reine Sprache,
- interne und externe Mikrofone,
- Lautsprecher, Kabelkopfhörer, Bluetooth und AirPlay soweit unterstützt,
- Erteilung, Ablehnung und Widerruf beider Berechtigungen,
- Gerät wird während Aufnahme entfernt,
- Sleep/Wake, Benutzerwechsel und Audio-Route-Wechsel,
- lange Session mit Appnavigation und mehreren Displays,
- Historywiedergabe einzeln und optional gemischt,
- Rollen-/Timelineverständlichkeit bei Überlappung,
- wenig Speicher und explizites Löschen,
- Crash/Force Quit während Aufnahme, Finalisierung, Transkription und Merge.

## 17. Community-ZIP- und Release-Gate

Vor Tag oder GitHub Release müssen:

1. alle 4.0- und 4.1-Tests erfolgreich sein,
2. Debug- und Release-Build erfolgreich sein,
3. keine Video- oder Bildtracks in erzeugten Dateien nachweisbar sein,
4. finale Community-ZIP und SHA-256 geprüft sein,
5. exakt die entpackte ZIP-App beide Berechtigungen und Mixed Capture bestehen,
6. exakt diese App mindestens eine 60-Minuten- und eine 120-Minuten-Mixed-Session bestehen,
7. Sync-/Driftziele mit reproduzierbarem Testsignal nachgewiesen sein,
8. Clippingwarnung und abgeleiteter Headroom geprüft sein,
9. Force-Quit plus Resume ohne Verlust erfolgreicher Tracksegmente bestanden sein,
10. Einspur-Ausfall bei Mic und System jeweils sicher degradiert sein,
11. Offline- und Cloudpfad jeweils geprüft sein,
12. bestehende Single-Mic-, Single-Systemaudio- und Diktierketten-Smokes bestanden sein.

## 18. Akzeptanzkriterien

Phase 4.1 ist produktseitig abgeschlossen, wenn:

- [ ] beide Quellen gleichzeitig und getrennt gespeichert werden,
- [ ] Originaltracks niemals durch Mix/Normalisierung verändert werden,
- [ ] Startversatz, Drift und Gaps messbar und persistiert sind,
- [ ] korrigierte Timeline die definierten Syncbudgets erreicht,
- [ ] Clipping je Track sichtbar und ein abgeleiteter Mix headroom-sicher ist,
- [ ] Trackausfall die andere Aufnahme nicht zerstört,
- [ ] beide Tracks segmentweise fortsetzbar transkribiert werden,
- [ ] erfolgreiche Segmente nach Neustart nicht wiederholt werden,
- [ ] Merge Rollen und echte Überlappungen erhält,
- [ ] kein Video gespeichert oder übertragen wird,
- [ ] Offline-Modus keinerlei Meetingdaten sendet,
- [ ] Stop, Overlay und globale Hotkeys responsiv bleiben,
- [ ] History, Retention und Löschen alle Sessionartefakte korrekt behandeln,
- [ ] 4.0 und 3.4 regressionsfrei bleiben,
- [ ] finale Community-ZIP vollständig abgenommen ist.

## 19. Risiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| zwei Audioclocks driften | periodische Hosttime-Anker und abgeleitete Driftkorrektur |
| Live-Mix clippt oder verdeckt Sprecher | getrennte Originalspuren, Mix nur abgeleitet mit Headroom |
| eine Quelle startet später | expliziter Offset/Gap statt erfundener Synchronität |
| Gerätewechsel erzeugt Zeitsprung | segmentiertes Zeitmodell und sichtbare Qualitätswarnung |
| lange Dualaufnahme wächst stark | komprimierte geeignete Formate, Vorabschätzung, dateibasiertes Processing |
| lokale Inferenz stört Capture | Queuepriorität für Recording, Belastungsgate, keine parallelen Jobs |
| fehlende Providerzeitstempel | ehrliche TrackChunk-Präzision statt falscher Worttimeline |
| Echo erscheint auf beiden Tracks | keine riskante Cross-Track-Deduplizierung in 4.1 |
| Nutzer erwartet Remotesprechertrennung | klare Rollenbezeichnung `You`/`System Audio`; keine Diarization in 4.1 versprechen |
| rechtlich unzulässige Aufnahme | sichtbarer Status, explizites Consent-Gate, lokal zurücksetzbare Bestätigung, keine Stealth-Funktion |
| Systemaudio erfordert breitere Screen-&-System-Audio-Berechtigung als Wettbewerber | CoreAudio/System-Audio-Tap als audio-only Alternative prüfen; falls nicht tragfähig, ScreenCaptureKit-Einsatz in UI und Privacy-Doku transparent erklären |
| Recoveryzustände explodieren in Komplexität | getrennte Trackstatus plus validierte Meetinginvarianten |
| Wettbewerber wirkt funktionsreicher | 4.1 auf macOS-native Stabilität, Recovery, Privacy und nachvollziehbare Meetingartefakte fokussieren |

## 20. Technische Referenzen

- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Apple AVFoundation](https://developer.apple.com/documentation/avfoundation)
- [Apple Core Audio](https://developer.apple.com/documentation/coreaudio)
- `FlowDictate_PRD_Phase_3_4.md` für Long-Form-, Segment-, Recovery- und Performanceverträge
- `FlowDictate_PRD_Phase_4_0.md` für Provider-, Privacy-, Queue- und Jobverträge

API-, Plattform- und Formatannahmen müssen zu Beginn der Implementierung und unmittelbar vor dem Release erneut gegen Apples Primärdokumentation geprüft werden.

## 21. Definition of Done

Phase 4.1 ist erst abgeschlossen, wenn Dual-Capture, Synchronisierung, Clipping-Schutz, Tracktranskription, Merge, Migration, Recovery, Datenschutzprüfung und Langzeitperformance mit der finalen Community-ZIP nachgewiesen sind. Ein Tag, Asset-Upload oder GitHub Release benötigt einen separaten ausdrücklichen Veröffentlichungsauftrag.
