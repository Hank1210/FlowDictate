# FlowDictate – Arbeitsplan Phase 4.1

**Phase:** 4.1 – Synchronized Meeting Capture
**Status:** Aktiver Umsetzungsplan; Grundlagen abgeschlossen, Capture noch nicht implementiert
**Stand:** 15. September 2026
**Ausgangsbasis:** FlowDictate 4.0.2, Build 27, Tag `v4.0.2`, Release-Commit `5bfc957`
**Arbeitsbranch:** `codex/phase-4-1-prep`, Basis-Commit `5095b38`
**Anforderungsgrundlage:** `FlowDictate_PRD_Phase_4_1.md`
**Private Testnotizen:** `TESTING_4_1.md`, nicht versionieren
**Ablage:** öffentlich und versioniert; die Ausnahme in `.gitignore` gilt ausschließlich für diesen Plan

## 1. Zweck des Arbeitsplans

Dieser Plan übersetzt das 4.1-PRD in eine prüfbare Implementierungsreihenfolge. Das PRD bleibt die Produkt- und Anforderungsquelle. Dieser Arbeitsplan beantwortet dagegen für jedes Arbeitspaket:

- welche Entscheidung oder Funktion geliefert wird,
- welche Dateien voraussichtlich betroffen sind,
- welche Tests vor dem Weitergehen grün sein müssen,
- welches Exit-Kriterium den Schritt abschließt,
- welche Risiken eine ausdrückliche Go-/No-Go-Entscheidung verlangen.

Phase 4.1 wird nicht als großer UI-Umbau begonnen. Zuerst werden Daten- und Recoveryverträge festgelegt, danach wird der Capturepfad in einem technischen Spike verifiziert. Erst auf dieser Grundlage folgen Orchestrierung, Synchronisierung, Verarbeitung und die vollständige UX.

## 2. Statuslegende und Arbeitsregel

| Status | Bedeutung |
|---|---|
| `OFFEN` | noch nicht begonnen |
| `IN ARBEIT` | lokale Änderungen vorhanden, Exit noch nicht erreicht |
| `GATE` | Entscheidung oder Messnachweis ist vor dem Folgeschritt erforderlich |
| `ERLEDIGT` | Implementierung, Tests und Reviewkriterien des Schritts sind erfüllt |
| `BLOCKIERT` | ein dokumentierter externer oder technischer Blocker verhindert den nächsten Schritt |

Ein Arbeitspaket wird erst `ERLEDIGT`, wenn Code, Tests und sein Exit-Kriterium erfüllt sind. Ein lokal grüner Zwischenstand ohne Review beziehungsweise Commit wird als `IN ARBEIT` geführt.

Für jeden abgeschlossenen Schritt gilt:

1. Scope des Schritts nicht still erweitern.
2. Bestehende Single-Microphone- und Single-System-Audio-Pfade regressionsfrei halten.
3. Private Aufnahmen, Transkripte und `TESTING_4_1.md` nicht committen.
4. Keine Versions-, Release- oder Funktionsbehauptung vor bestandenem End-to-End-Gate.
5. Relevante Architekturentscheidungen und bekannte Einschränkungen im Plan oder PRD aktualisieren.

## 3. Verbindliches Ziel und Nicht-Ziele

### 3.1 Pflichtziel

FlowDictate 4.1 zeichnet bei der Quelle `Microphone + System Audio` beide Quellen gleichzeitig auf, hält ihre Originaldateien getrennt und richtet sie über eine gemeinsame monotone Timeline aus. Jede Spur bleibt bei Fehlern der anderen Spur recoverbar. Transkription, Retry und Recovery erfolgen je Track; erst danach wird eine rollenmarkierte Timeline erzeugt.

### 3.2 Verbindliche Produktregeln

- Der Mikrofontrack ist `You`, der Systemaudiotrack ist `System Audio`.
- Originaltracks werden niemals durch Mix, Normalisierung oder Driftkorrektur überschrieben.
- Abgeleitete Audiodateien sind reproduzierbare Artefakte und dürfen jederzeit neu erzeugt werden.
- Vor der ersten kombinierten Aufnahme ist eine aktive Consent-Bestätigung erforderlich.
- Bestätigung des Consent-Pop-ups startet nie automatisch eine Aufnahme.
- Bei Press & Hold wird der erste Hotkeyzyklus vollständig durch das Consent-Gate verbraucht; erst ein neuer Tastendruck darf aufnehmen.
- Ohne beide Berechtigungen startet keine Mixed Session einspurig.
- Fällt eine Quelle nach erfolgreichem Start aus, bleibt die andere erhalten und der Teilfehler wird sichtbar persistiert.
- Es gibt keinen stillen Local-to-Cloud-Fallback.
- Es werden keine Videoframes oder Screenshots gespeichert oder übertragen.
- Während der Aufnahme bleibt ein sichtbarer Recordingstatus aktiv.

### 3.3 Nicht Bestandteil von 4.1

- Sprecher-Diarization innerhalb des Systemtracks,
- persistente Sprecheridentität,
- Übersetzung,
- Video- oder Bildschirmbildaufnahme,
- versteckte oder ferngesteuerte Aufnahme,
- Kalender-, Slack- oder Meeting-Plattform-Integration,
- Live-Finaltranskript des Systemaudios,
- automatische Cross-Track-Echounterdrückung oder Satzdeduplizierung,
- SQLite-Migration,
- iPhone-/iPad-Meetingaufnahme.

## 4. Ausgangslage am 13. September 2026

### 4.1 Releasebasis

- 4.0.2 ist veröffentlicht und bildet die unveränderte Releasebasis.
- `main` und `origin/main` zeigen auf `5bfc957`.
- Die 4.1-Arbeit findet auf `codex/phase-4-1-prep` statt.
- Die 4.0-Provider-, Queue-, Long-Form-, History- und Recoveryverträge müssen erhalten bleiben.

### 4.2 Abgeschlossene Grundlagen

Status: `ERLEDIGT` – implementiert, als zusammenhängender Diff geprüft und mit der vollständigen Testsuite verifiziert.

- `MixedRecordingSession` mit Schema 1, Trackrollen, Trackstatus, Zeitankern, Gaps und Qualitätsmetriken.
- Invarianten für exakt einen Mikrofon- und einen Systemaudiotrack.
- sichere relative Pfade sowie Validierung monotoner Zeitanker und Trackmetadaten.
- Restart-Normalisierung aktiver Sessions und Tracks ohne Löschen vorhandener Dateien.
- actor-basierter `MeetingSessionStore` mit atomarem Manifestwrite und festem Sessionlayout.
- versionierter, lokal persistierter Consent-State mit Reset in Settings.
- optionaler Consent nur für die aktuelle App-Session.
- Consent-Pop-up und Presenter-Grenze für testbare Coordinator-Logik.
- Auswahl `Microphone + System Audio` in Menü und Settings.
- Press-&-Hold-Vertrag: Zustimmung verbraucht den ersten Hotkeyzyklus; Bestätigung startet nicht selbsttätig.
- explizite technische Sperre des echten Mixed-Starts, solange der Capture-Coordinator fehlt.
- Unit-Tests für Consent, Sessionmodell, Store, Recovery und Cancel-Erhalt.

Letzter verifizierter Teststand: 111 Tests erfolgreich am 13. September 2026.

### 4.3 Noch nicht implementiert

- simultaner Capture beider Quellen,
- Captureentscheidung Audio-Tap versus ScreenCaptureKit,
- gemeinsame Startbarriere und Stop-/Cancel-Orchestrierung,
- periodische monotone Sampleanker,
- Gap-, Drift- und Clippinganalyse aus realem Capture,
- Dual-Level-Overlay,
- Tracktranskription und persistierter Trackfortschritt,
- zeitbasierter Transcript-Merge,
- Historyschema 7 und Meeting-Detailansicht,
- reale Langzeit-, Performance- und Recoverynachweise.

Die sichtbare Auswahl `.mixed` ist deshalb derzeit kein Versprechen funktionierender Aufnahme: Der Coordinator bricht den Start absichtlich mit `captureNotAvailable` ab.

## 5. Zielarchitektur und Abhängigkeiten

```text
Recording Source / Consent / Permission Preflight
                       │
                       ▼
       MixedRecordingSessionCoordinator actor
          ├── MicrophoneTrackRecorder
          └── SystemAudioTrackRecorder
                       │
                       ▼
              MeetingSessionStore actor
                       │
            SynchronizationAnalyzer
              ├── offset / gaps
              ├── drift sections
              └── quality report
                       │
              DerivedTrackRenderer
                       │
          TrackTranscriptionRunner (per track)
                       │
              TimedTranscriptMerger
                       │
       History / playback / copy / export / delete
```

### 5.1 Reihenfolge

| Schritt | Status | Voraussetzung | Entsperrt |
|---|---|---|---|
| 4.1.0 Grundlagen und Consent | `ERLEDIGT` | 4.0.2 | stabiler Sessionvertrag |
| 4.1.1 Capture-Spike | `IN ARBEIT` | Grundlagen | verbindliche Captureentscheidung |
| 4.1.2 Dual-Capture-Coordinator | `OFFEN` | Spike-Go | echte Mixed-Aufnahme |
| 4.1.3 Timeline, Sync und Qualität | `OFFEN` | reale Trackanker | ausgerichtete Arbeitsdaten |
| 4.1.4 Track-Processing und Recovery | `OFFEN` | finale Trackverträge | recoverbare Transkripte |
| 4.1.5 Timed Merge | `OFFEN` | Tracktranskripte + Sync | Meeting-Timeline |
| 4.1.6 UX, History und Migration | `OFFEN` | stabile Zustände | vollständiger Nutzerablauf |
| 4.1.7 Hardening und Langzeittests | `OFFEN` | End-to-End-Pfad | Releasekandidat |
| 4.1.8 Dokumentation und Release-Gate | `OFFEN` | alle Gates grün | Freigabeentscheidung |

## 6. Schritt 4.1.0 – Grundlagen, Sessionstore und Consent

**Status:** `ERLEDIGT`

### 6.1 Lieferumfang

- stabiles, versioniertes Meetingmanifest,
- Trackrollen und Capture-/Processingstatus,
- Zeitanker-, Gap-, Clipping- und Qualitätsdatentypen,
- atomarer Store mit unveränderlichem Sessionverzeichnis,
- Recoverynormalisierung ohne Datenverlust,
- versioniertes Consent-Gate und Settings-Reset,
- UX-Vertrag für Toggle und Press & Hold,
- sichtbare, aber technisch gesperrte Mixed-Quellenauswahl.

### 6.2 Dateien

Neu:

- `FlowDictate/Meetings/MixedRecordingSession.swift`
- `FlowDictate/Meetings/MeetingSessionStore.swift`
- `FlowDictate/Meetings/MeetingRecordingConsentView.swift`

Angepasst:

- `FlowDictate/App/DictationCoordinator.swift`
- `FlowDictate/Audio/RecordingAudioSource.swift`
- `FlowDictate/MenuBar/FlowDictateMenu.swift`
- `FlowDictate/Settings/AppSettings.swift`
- `FlowDictate/Storage/RecordingLocationStore.swift`
- `FlowDictateTests/FlowDictateTests.swift`

### 6.3 Abschlussnachweis

- [x] lokale Änderungen als zusammenhängenden Diff reviewt,
- [x] Benennungen mit PRD und späterem Track-Processing abgeglichen,
- [x] zulässige Completion-Fälle durch einen expliziten `MeetingCompletionMode` begrenzt,
- [x] vollständige Testsuite mit 111 erfolgreichen Tests ausgeführt,
- [x] `git diff --check` ohne Befund ausgeführt,
- [x] Grundlagen für einen klar abgegrenzten Commit freigegeben.

### 6.4 Tests

- Manifest-Roundtrip und Schema-Grenzen,
- exakt eine Spur je Rolle,
- monotone Anker und sichere relative Pfade,
- Completed-/Partial-Invarianten,
- atomare Storeanlage ohne Überschreiben,
- beschädigtes oder zukünftiges Manifest bleibt unangetastet,
- Restart bewahrt Originaltracks,
- Cancel bewahrt bereits geschriebene Tracks,
- Consent ist explizit, versioniert und zurücksetzbar,
- Cancel im Dialog ändert die Aufnahmequelle nicht,
- session-only Consent wird nicht persistiert,
- Press & Hold startet nach Dialogbestätigung nicht automatisch.

### 6.5 Exit

Das Sessionmodell lässt sich unabhängig von echtem Capture erzeugen, validieren, atomar speichern und nach einem simulierten Neustart verlustfrei normalisieren. Consent ist in allen Aktivierungsmodi deterministisch testbar. Mixed Capture bleibt bis Schritt 4.1.2 ausdrücklich gesperrt.

## 7. Schritt 4.1.1 – Capture- und Berechtigungs-Spike

**Status:** `IN ARBEIT` – API-/Build-, Kurzzeit-Signal-, Zehn-Zyklen-, Community-Packaging-, Erstberechtigungs- und ScreenCaptureKit-Kurzvergleichs-Gate bestanden; Langzeitnachweis ausstehend

### 7.1 Ziel

Vor dem produktiven Coordinator wird mit öffentlichen Apple-APIs entschieden, wie digitales Systemaudio auf der unterstützten macOS-Matrix zuverlässig und ausschließlich als Audio erfasst wird.

Zu vergleichen sind mindestens:

1. Core-Audio-/System-Audio-Tap, soweit auf Zielsystemen öffentlich verfügbar und für Distribution geeignet.
2. der bestehende audio-only konfigurierte ScreenCaptureKit-Pfad.

Der Spike muss nicht die spätere UI oder Verarbeitung enthalten. Er muss belastbare Antworten zu Berechtigung, Format, Timestamps, Recovery, Stabilität und Packaging liefern.

Am 15. September 2026 wurde der echte Core-Audio-Erstberechtigungsdialog manuell in beiden Richtungen sowie der nachträgliche Widerruf vor und nach App-Neustart geprüft. Ablehnung liefert stumme Callbacks und darf deshalb weder als `Allowed` noch als sichere technische Diagnose `Denied` ausgegeben werden. Nur tatsächlich empfangenes Systemaudiosignal verifiziert den Zugriff für die laufende App-Sitzung. Der Widerruf wirkt erst nach Prozessende. Ein während eines Wiederholungsversuchs beobachteter blockierender Core-Audio-Cleanup-Aufruf wird durch einen begrenzten, vom UI isolierten Cleanup-Pfad abgefangen. Ein anschließender Lauf bestand 10/10 Start-/Stop-Zyklen mit 975 Callbacks, 0 Gaps und erfolgreichem Cleanup; die Langzeitnachweise bleiben Teil des Spike-Gates.

Drei kontrollierte ScreenCaptureKit-Vergleichsläufe mit einer einzelnen App-Instanz lieferten 259, 250 und 253 Callbacks sowie durchgehend monotone, vollständige Zeitstempel. Nur der erste Lauf enthielt eine erkannte Lücke von 829 Frames (rund 17,3 ms bei 48 kHz); die beiden unmittelbaren Wiederholungen hatten keine Lücke. Die sichtbare Ergebnisanzeige im Audio-Tab ist damit manuell bestätigt. Die Langzeitmessungen entscheiden, wie sporadische Abweichungen in Gap-Metrik und Timeline-Recovery eingehen.

### 7.2 Prüfmatrix

Für jeden Kandidaten dokumentieren:

- minimale unterstützte macOS-Version gegenüber aktuellem Deployment Target macOS 14,
- erforderliche Entitlements und `Info.plist`-Texte,
- genaue System-Settings-Kategorie und sichtbarer macOS-Berechtigungsdialog,
- Verhalten bei erstmaliger Erteilung, Ablehnung und nachträglichem Widerruf,
- ob ein Appneustart erforderlich ist,
- garantierte Audio-only-Ausgabe ohne Video-/Bildtrack,
- Timestamps beziehungsweise Hosttime-Bezug jedes Samplebuffers,
- native Samplerate, Kanalzahl und Formatwechsel,
- Ausschluss von FlowDictates eigenem Audio,
- Geräte-, Ausgabe- und Displaywechsel,
- Stop-, Cancel- und Prozessabbruchverhalten,
- Verhalten bei Stille und wenn keine Systemaudiosamples eintreffen,
- CPU, RAM, File-I/O und Dateigröße,
- Universal-Build-Kompatibilität für `arm64` und `x86_64`,
- Verhalten in ad-hoc signierter Community-App.
- TCC-Verhalten nach Austausch eines ad-hoc signierten Builds, einschließlich Entfernen/erneutem Hinzufügen eines veralteten Berechtigungseintrags.

### 7.3 Spike-Artefakte

- kleine isolierte Recorderprobe oder eng begrenzter interner Feature-Flag-Pfad,
- reproduzierbare Testschritte ohne private Aufnahmeinhalte,
- zwei getrennte Testdateien mit Start-/End- und Zwischenankern,
- Messprotokoll für mindestens 5, 30 und 60 Minuten,
- dokumentierte Entscheidung mit verworfenem Kandidaten und Gründen,
- festgelegte Originalformate und erwartete Speichergröße pro Stunde,
- klarer Permission-Text für Settings und Preflight.

### 7.4 Mindesttests

- Mic und Systemaudio liefern gleichzeitig lesbare Dateien,
- beide Dateien enthalten ausschließlich ihre vorgesehene Quelle,
- mindestens Start-, End- und periodische monotone Anker sind auslesbar,
- Stop finalisiert beide Pfade unabhängig,
- Fehler eines Writers löscht die andere Datei nicht,
- keine Video- oder Bilddaten werden erzeugt,
- Ablehnung jeder erforderlichen Berechtigung startet keine Mixed Session,
- zehn kurze Start-/Stop-Zyklen hintereinander,
- 30-Minuten-Smoke ohne verlorene Buffer,
- Community-Build-Smoke auf mindestens einem unterstützten Mac.

### 7.5 Go-/No-Go-Gate

Vor Schritt 4.1.2 liegt eine eindeutige Entscheidung vor:

- gewählte Capture-API und Mindest-macOS-Version,
- exakte Berechtigungs-UX,
- Originalformat je Track,
- Timestampstrategie und Ankerintervall,
- bekannte Einschränkungen bei Geräten/Routen,
- gemessener Ressourcen- und Speicherbedarf,
- nachgewiesenes audio-only Verhalten,
- begründete Entscheidung, ob Universal-Support erhalten bleibt.

`NO-GO` gilt, wenn kein öffentlicher API-Pfad getrennte, recoverbare Audiospuren ohne Videodaten und ohne unvertretbare Berechtigungs- oder Stabilitätsprobleme liefert. In diesem Fall wird Scope oder Mindest-macOS-Version ausdrücklich neu entschieden; es gibt keinen stillen Fallback auf einen destruktiven Live-Mix.

## 8. Schritt 4.1.2 – MixedRecordingSessionCoordinator und Dual Capture

**Status:** `OFFEN`

### 8.1 Voraussichtliche Dateien

- `FlowDictate/Meetings/MixedRecordingSessionCoordinator.swift`
- `FlowDictate/Meetings/MicrophoneTrackRecorder.swift`
- `FlowDictate/Meetings/SystemAudioTrackRecorder.swift`
- gegebenenfalls gemeinsame `TrackCaptureEvent`- und Writer-Typen,
- `FlowDictate/App/DictationCoordinator.swift`
- `FlowDictate/Overlay/RecordingOverlayController.swift`

Bestehende Single-Track-Recorder werden wiederverwendet oder durch Adapter eingebunden, aber nicht ungeprüft dupliziert.

### 8.2 Umsetzung

- Session und Trackdateien vor Capturestart vorbereiten.
- Queue-/Processing-Voraussetzungen aus 4.0 vor dem Start prüfen.
- Consent und beide Berechtigungen vor Dateicapture abschließen.
- beide Recorder hinter einer gemeinsamen Startbarriere vorbereiten.
- einen angeforderten gemeinsamen monotonic start anchor persistieren.
- Status erst zu `recording` setzen, wenn mindestens ein valider Samplepfad bestätigt ist.
- fehlt eine Quelle bereits beim Start, beide Pfade kontrolliert stoppen und Start als fehlgeschlagen persistieren.
- fällt eine Quelle nach erfolgreichem Start aus, andere Quelle erhalten und Warnzustand setzen.
- Trackereignisse rate-limitiert und ohne große Buffers auf den Main Actor projizieren.
- Stop im UI sofort bestätigen, beide Recorder unabhängig finalisieren und Manifest atomar aktualisieren.
- Cancel stoppt beide Recorder, verwirft aber keine bereits geschriebenen Originaldaten.
- späte Callbacks nach Stop/Cancel über Session-/Generation-ID ignorieren.
- zweiter Start während `preparing`, `recording` oder `finalizing` wird abgewiesen.

### 8.3 Zustandsinvarianten

- `recording` ohne persistiertes Manifest ist unzulässig.
- Ein Trackwriter schreibt ausschließlich in seinen vorab validierten Originalpfad.
- Eine Writerstörung darf nie die andere Originaldatei entfernen.
- `finalizing` ist wiederanlaufbar und bewahrt unvollständige Dateien zur Prüfung.
- Stop und Cancel sind idempotent gegenüber doppelten UI-/Hotkeyereignissen.
- der bestehende `.microphone`- und `.systemAudio`-Ablauf bleibt unverändert nutzbar.

### 8.4 Tests

- gemeinsame Startbarriere mit unterschiedlich schnellen Fake-Recordern,
- Fehler von Mic/System jeweils vor dem ersten Sample,
- Ausfall von Mic/System jeweils nach erfolgreichem Start,
- Stop während `preparing`, `recording` und Writerfinalisierung,
- Cancel und doppelter Stop,
- Press & Hold sowie Toggle erzeugen genau eine Session,
- Consentdialog verbraucht weiterhin den ersten Press-&-Hold-Zyklus,
- späte Samples verändern keine finalisierte Session,
- teilweise Finalisierung bleibt recoverbar,
- bestehende Single-Track- und Queue-Tests bleiben grün.

### 8.5 Exit

Eine kurze reale Mixed Session erzeugt genau zwei getrennte, lesbare Originaldateien und ein valides Manifest. Start-, Stop-, Cancel- und Einspur-Ausfalltests sind grün. Erst dann wird die bisherige `captureNotAvailable`-Sperre entfernt.

## 9. Schritt 4.1.3 – Timeline, Synchronisierung und Qualitätsbericht

**Status:** `OFFEN`

### 9.1 Voraussichtliche Dateien

- `FlowDictate/Meetings/SynchronizationAnalyzer.swift`
- `FlowDictate/Meetings/DerivedTrackRenderer.swift`
- `FlowDictate/Meetings/MeetingQualityAnalyzer.swift`
- Audiofixture- und Testhilfen für Offset, Drift, Gap und Clipping.

### 9.2 Umsetzung

- Capturetimestamps auf eine gemeinsame monotone Sessionzeit abbilden.
- ersten gültigen Sampletimestamp pro Track als Startoffset persistieren.
- periodische Anker gegen Frameposition und native Trackzeit validieren.
- verworfene Buffer, Timestamp-Sprünge und Gerätewechsel als explizite Gaps beziehungsweise Abschnitte modellieren.
- lineare Drift nur innerhalb valider Abschnitte schätzen.
- nichtlineare Sprünge nicht durch einen globalen Faktor verstecken.
- Peak, geclippte Frames und Stilledauer in inhaltsfreien Metriken erfassen.
- Qualitätsreport mit verständlichen Severity-Stufen erzeugen.
- ausgerichtete Arbeitsdateien ausschließlich unter `derived/` schreiben.
- kontrolliertes Resampling nur auf Derived Tracks anwenden.
- optionalen Mix erst nach separatem Headroomtest erzeugen; Ziel True Peak höchstens `-3 dBFS`.

### 9.3 Tests

- Null-, positiver und negativer Startoffset,
- konstante positive und negative Drift,
- mehrere lineare Abschnitte mit Gap,
- rückläufige oder doppelte Anker werden abgelehnt,
- Stille wird nicht als fehlende Datei bewertet,
- Clippingzählung je Track,
- abgeleitete Ausrichtung verändert keine Originalbytes,
- Derived-Ziel darf nie einem Originalpfad entsprechen,
- reproduzierbarer Impuls-/Klatschtest,
- Qualitätsreport unterscheidet vollständig, degradiert und unbrauchbar.

### 9.4 Exit

Synthetische Fixtures mit bekanntem Offset, Drift und Gaps werden innerhalb der definierten Toleranz rekonstruiert. Originaldateien bleiben bitweise unverändert. Der Report erklärt jede Degradierung ohne Audio- oder Textinhalt zu loggen.

## 10. Schritt 4.1.4 – Track-Transkription, Persistenz und Recovery

**Status:** `OFFEN`

### 10.1 Voraussichtliche Dateien

- `FlowDictate/Meetings/TrackTranscriptionRunner.swift`
- `FlowDictate/Jobs/DictationJob.swift`
- `FlowDictate/Jobs/DictationJobStore.swift`
- `FlowDictate/Jobs/DictationProcessingQueue.swift`
- `FlowDictate/Transcription/TranscriptionRunner.swift`
- `FlowDictate/Transcription/LongForm/*`

### 10.2 Umsetzung

- Provider, Engine, Modell, Sprache, Privacy-Modus und Profiloptionen je Meeting einfrieren.
- eine persistierte Meeting-Jobidentität mit zwei eindeutigen Track-Workflows verbinden.
- Long-Form-Session je Track anlegen und Fortschritt getrennt persistieren.
- Segmentgrenzen aus der ausgerichteten Timeline ableiten, Originale jedoch unangetastet lassen.
- erfolgreiche Segmente bei Retry oder Neustart niemals erneut transkribieren.
- Local und OpenAI über die bestehende Providerabstraktion nutzen.
- Offline-Policy vor jedem möglichen Netzwerkpfad erzwingen.
- Trackfehler isolieren und erfolgreichen Track weiterverarbeiten.
- Merge erst einplanen, wenn beide Tracks terminal oder eine explizite Einspur-Degradierung akzeptiert ist.
- während Meetingverarbeitung gemäß PRD keine neue Aufnahme annehmen.

### 10.3 Tests

- je Track unabhängige Segmentierung und Fortschritt,
- identische Providerkonfiguration für alle Segmente einer Session,
- Neustart nach erfolgreichen Segmenten beider Tracks,
- Retry nur des fehlerhaften Tracks,
- fehlendes lokales Modell pausiert ohne Cloudfallback,
- Offline-Meeting erzeugt keinen Netzwerkrequest,
- Cloudmeeting sendet nur freigegebene Audiosegmente und keine Videodaten,
- Cancellation bewahrt Originale und erfolgreiche Teiltexte,
- Queue- und Retentionregeln schützen aktive/partielle Meetings,
- vollständige 4.0-Long-Form-Regression.

### 10.4 Exit

Beide Tracks einer mehrsegmentigen Testsession können lokal und über einen OpenAI-Testdouble unabhängig verarbeitet und nach Neustart fortgesetzt werden. Kein erfolgreiches Segment wird wiederholt und kein Teilfehler löscht Daten des anderen Tracks.

## 11. Schritt 4.1.5 – Zeitbasierter Transcript-Merge

**Status:** `OFFEN`

### 11.1 Voraussichtliche Dateien

- `FlowDictate/Meetings/TimedTranscriptEntry.swift`
- `FlowDictate/Meetings/TimedTranscriptMerger.swift`
- persistiertes `merged-timeline.json`-Modell.

### 11.2 Umsetzung

- Timestamppräzision `word`, `segment` und `trackChunk` explizit führen.
- Providerzeitstempel nur verwenden, wenn die Capability sie tatsächlich liefert.
- Segmentzeiten über die Syncabbildung in Sessionzeiten überführen.
- innerhalb jedes Tracks bestehende Long-Form-Überlappungsduplikate entfernen.
- Einträge primär nach Startzeit und sekundär deterministisch nach Rolle und Segmentindex sortieren.
- echte Überlappungen beider Tracks erhalten.
- keine wortweise Vermischung ohne geeignete Timestamppräzision.
- keine Cross-Track-Deduplizierung gleicher Sätze.
- Rollenmarken in Timeline, Fließtext und Export erhalten.
- Smart Dictation oder spätere Zusammenfassung erst auf das vollständige Mergeergebnis anwenden.
- automatische Einfügung nur bei validem Endzustand und höchstens einmal.

### 11.3 Tests

- serielle Sprache Mic → System und umgekehrt,
- gleichzeitig beginnende Einträge,
- vollständig und teilweise überlappende Sprache,
- gleiche Texte auf beiden Tracks bleiben erhalten,
- stabile Ausgabe bei identischen Timestamps,
- Fallback von Wort- zu Segment- beziehungsweise Chunkpräzision,
- Drift-/Gap-Abbildung auf Sessionzeit,
- Retry verändert Reihenfolge erfolgreicher Einträge nicht,
- Mergefehler bewahrt beide Tracktranskripte,
- Exactly-once-Einfügung und Deferred Insertion.

### 11.4 Exit

Der Merger erzeugt aus reproduzierbaren Trackfixtures eine deterministische, rollenmarkierte Timeline, erhält Überlappungen und behauptet keine höhere Zeitgenauigkeit als die Eingabedaten liefern.

## 12. Schritt 4.1.6 – Vollständige UX, History und Migration

**Status:** `OFFEN`

### 12.1 Recording Source und Start

- `Microphone + System Audio` bleibt eine explizite dritte Recording Source.
- Settings zeigen Mikrofon, Systemaudioberechtigung, Provider/Privacy und konservativen Speicherbedarf pro Stunde.
- ein Permission-Preflight erklärt die tatsächlich gewählte Capture-API und öffnet die korrekte Systemeinstellung.
- Auswahl der Quelle und Start einer Aufnahme bleiben getrennte Handlungen.
- Reset des Consent führt vor dem nächsten Start erneut zum Dialog.
- Consent-Wording wird vor Release sprachlich und rechtlich vorsichtig geprüft, ohne Rechtsberatung zu simulieren.

### 12.2 Overlay

- klarer Titel `Microphone + System Audio`,
- getrennte Pegel `Mic` und `System`,
- Textlabels/Symbole zusätzlich zu Farbe,
- spurbezogene Clipping- und Trackverlustwarnung,
- sofortiger sichtbarer Wechsel zu `Finalizing tracks…` nach Stop,
- kompakter Trackfortschritt bei Verarbeitung,
- Meetingprogress verdeckt keine wichtigere aktive Recordinganzeige.

### 12.3 History und Schema 7

- Historyrecord additiv um Meetingreferenz, Trackvollständigkeit und Syncqualität erweitern.
- vor erstem Schema-7-Schreiben einmaliges Backup `dictations-pre-4.1.json` erzeugen.
- bestehende Schema-6-Records bleiben unveränderte Single-Track-Einträge.
- alte Profile erben niemals automatisch `.mixed`.
- Detailansicht zeigt beide Tracks, Qualitätsbericht, Rollen-Timeline und Processingstatus.
- Aktionen: Trackwiedergabe, Copy, Resume, Retry, Export und explizites Löschen.
- Löschen entfernt nur nach Bestätigung die zugehörigen Originals, Derived Files, Segmente und Manifeste.

### 12.4 Tests

- Consentdialog mit VoiceOver, Tastatur und Escape/Cancel,
- Press & Hold und Toggle jeweils mit akzeptiertem/nicht akzeptiertem Consent,
- Permission denied/revoked und Settingsnavigation,
- Dual-Level-Anzeige ohne reine Farbbedeutung,
- Warnungen für Mic-/Systemausfall und Clipping,
- Schema 6 → 7 mit einmaligem Backup,
- unbekanntes neueres Schema wird nicht überschrieben,
- 1.000 Records einschließlich Meetingzusammenfassungen,
- Löschen trifft keine fremden Recordings oder Jobs,
- bestehende Single-Track-History bleibt lesbar und bedienbar.

### 12.5 Exit

Ein Nutzer kann Quelle, Consent, Berechtigungen, Aufnahme, Verarbeitung, Teilfehler, Ergebnis und Löschen ohne Kenntnis interner Trackzustände sicher verstehen. Alle alten Historyfixtures bleiben lesbar.

## 13. Schritt 4.1.7 – Performance, Recovery und Langzeittests

**Status:** `OFFEN`

### 13.1 Signposts und inhaltsfreie Diagnostik

Mindestens:

- Consent-/Permission-Preflight ohne Antwortinhalt,
- Session vorbereitet und atomar persistiert,
- Recorder vorbereitet, erstes Sample und letzter Sampleanker je Track,
- Gap, Writerfehler und Trackverlust,
- Stop angefordert und Writer finalisiert,
- Syncanalyse und Derived Rendering,
- Segmentstart/-ende je Track,
- Merge und finale Historypersistenz,
- Recoverynormalisierung.

Logs enthalten nur IDs, Zustände, Zeiten, Größen und grobe Qualitätswerte; keine Texte, Audiopfade, App-/Fensternamen oder Teilnehmerdaten.

### 13.2 Verbindliche automatisierte Szenarien

- zehn kurze Mixed Sessions hintereinander,
- Start-/Stop-Rennen und doppelte Hotkeyevents,
- Mic-only- und System-only-Ausfall vor/nach Start,
- Crash/Restart in jedem Session- und Trackstatus,
- Crash nach erfolgreichen Segmenten beider Tracks,
- Mergefehler und anschließender Retry,
- Offline und OpenAI jeweils mit vollständiger Policyprüfung,
- wenig Speicher vor Start und während Verarbeitung,
- lokale Inferenzlast während Dual Capture,
- 4.0-Queue-, Single-Track-, Preview- und Insertionregression.

### 13.3 Manuelle und private Langzeittests

Ergebnisse, reale Meetingbeobachtungen und sensible Umgebungsdetails werden ausschließlich in `TESTING_4_1.md` gesammelt. Der öffentliche Plan hält nur anonymisierte Gateergebnisse fest.

Pflichtmatrix:

- 5, 30, 60 und 120 Minuten,
- Stille, Sprache, Musik und Überlappung,
- internes und externes Mikrofon,
- Lautsprecher, Kabelkopfhörer, Bluetooth und AirPlay soweit freigegeben,
- Zoom, Teams, Meet oder gleichwertige Quellen,
- Geräteentfernung und Audio-Route-Wechsel,
- Berechtigung erteilt, abgelehnt und widerrufen,
- Toggle und Press & Hold,
- Cancel, Force Quit, Restart und Resume,
- lokale sowie OpenAI-Transkription,
- Smart-Dictation-/Enhancement-Kombinationen,
- wenig Speicher und explizites Löschen.

### 13.4 Performancebudgets

| Messgröße | Gate |
|---|---|
| Hotkey → sichtbarer Mixed-Status | p95 ≤ 150 ms nach erfüllten Preflights |
| Stop → sichtbares `Finalizing` | p95 ≤ 100 ms |
| längste zusammenhängende Main-Actor-Arbeit | ≤ 50 ms |
| Pegelupdates | höchstens 10/s je sichtbarem Track |
| Sample-/Bufferverlust | 0 in freigegebenen 30-/60-/120-Minuten-Läufen |
| korrigierter Startversatz | Ziel p95 ≤ 50 ms |
| verbleibende Drift nach 60 Minuten | Ziel ≤ 100 ms |
| verbleibende Drift nach 120 Minuten | Ziel ≤ 200 ms |
| Finalisierung beider Tracks bei 60 Minuten | Ziel p95 ≤ 5 s |
| zusätzlicher stabiler Capture-RAM | Ziel ≤ 250 MB ohne Transkriptionsmodell |
| RAM-Wachstum 30 → 120 Minuten | nicht proportional zur Audiodauer |

Eine Abweichung benötigt Messwert, Ursache, Produktwirkung und ausdrückliche Entscheidung. Budgets werden nicht still entfernt oder umdefiniert.

### 13.5 Exit

Alle Pflichtszenarien sind bestanden oder mit freigegebener, öffentlich dokumentierbarer Einschränkung versehen. Der finale 120-Minuten-Test zeigt keine verlorenen Originaltracks, kein unkontrolliertes RAM-Wachstum und eine recoverbare Verarbeitung.

## 14. Schritt 4.1.8 – Dokumentation, Packaging und Release-Gate

**Status:** `OFFEN`

### 14.1 Dokumentation

Vor Release aktualisieren:

- `README.md`,
- `CHANGELOG.md`,
- `PRIVACY.md`,
- `RELEASE.md`,
- Community-Installationshinweise,
- Settings-, Permission- und Consenttexte,
- Release Notes für 4.1.0,
- gegebenenfalls `THIRD_PARTY_NOTICES.md`.

Dokumentieren:

- getrennte Originaltracks und abgeleitete Artefakte,
- genaue macOS-Berechtigung und deren Zweck,
- sichtbaren Recordingstatus und Consent-Verantwortung,
- Local-/Cloudverhalten pro Track,
- Speicherbedarf und unterstützte Hardware/macOS-Versionen,
- Rollen `You` und `System Audio`, aber keine Diarization,
- Recovery, Partial Sessions und Löschen,
- bekannte Geräte-/Routenbeschränkungen,
- ad-hoc Signatur und Installationsschritte der Community-App.

### 14.2 Versions- und Packagingregel

- Marketingversion erst nach technischer Freigabe auf `4.1.0` setzen.
- Buildnummer erst vor dem Release monoton erhöhen.
- keine Aufnahme-, Transkript-, Model-, Credential- oder private Testdatei in App oder ZIP.
- keine Video-/Bildtracks in Original- oder Derived-Artefakten.
- exakt die entpackte finale ZIP-App testen; kein Neu-Build zwischen Abnahme und Upload.
- Tag, GitHub Release und Asset-Upload benötigen einen separaten ausdrücklichen Auftrag.

### 14.3 Finale Gates

- [ ] vollständige Unit- und Integrationstests grün,
- [ ] Debug- und Release-Build grün,
- [ ] Single-Mic und Single-Systemaudio regressionsfrei,
- [ ] Local- und OpenAI-Mixed-Pfad bestanden,
- [ ] Offline-Mixed-Pfad ohne Netzwerkrequest nachgewiesen,
- [ ] 60- und 120-Minuten-Test mit exakt der ZIP-App bestanden,
- [ ] Sync-, Drift-, Gap- und Clippingziele nachgewiesen,
- [ ] Mic- und Systemausfall jeweils sicher degradiert,
- [ ] Force-Quit plus Resume ohne Wiederholung erfolgreicher Segmente,
- [ ] Consent, Permission und sichtbarer Status manuell abgenommen,
- [ ] Migration Schema 6 → 7 und Backup geprüft,
- [ ] Löschung aller Sessionartefakte ohne Fremddatenverlust geprüft,
- [ ] Architekturen und Signatur der ZIP verifiziert,
- [ ] SHA-256 erzeugt und dokumentiert,
- [ ] öffentliche Dokumentation entspricht dem getesteten Verhalten.

### 14.4 Exit

Ein vollständig geprüftes, reproduzierbares Community-ZIP liegt mit Testprotokoll, Architekturen, Signaturstatus und SHA-256 vor. Erst danach kann die separate Freigabe für Commit auf `main`, Tag und GitHub Release eingeholt werden.

## 15. Commit- und Reviewstrategie

Die Arbeit soll in fachlich trennbaren, jeweils grünen Commits erfolgen. Vorgesehene Grenzen:

1. Sessionmodell, Store und Consent-Grundlagen.
2. Capture-Spike und dokumentierte API-Entscheidung.
3. Dual-Capture-Coordinator und Recorderintegration.
4. Synchronisierung, Qualitätsmetriken und Derived Tracks.
5. Track-Processing und Recovery.
6. Timed Merge.
7. Historyschema, Migration und vollständige UX.
8. Hardening, Dokumentation und Releasevorbereitung.

Ein Spike darf verworfenen Produktionscode nicht unbemerkt in späteren Commits belassen. Temporäre Debugausgaben, Testaufnahmen und lokale Messdateien werden vor jedem Commit entfernt oder bleiben außerhalb des Repositories.

## 16. Harte Blocker

Phase 4.1 ist nicht freigabefähig, wenn einer dieser Punkte gilt:

- Mixed Capture erzeugt nur einen destruktiven Mix oder überschreibt Originaltracks.
- eine vermeintliche Audioaufnahme speichert oder überträgt Video-/Bilddaten.
- Consent kann umgangen werden oder Dialogbestätigung startet nach einem beendeten Press-&-Hold-Zyklus selbsttätig.
- Recordingstatus kann während einer Mixed Session verborgen werden.
- fehlende Berechtigung startet still eine einspurige Aufnahme.
- Fehler, Cancel oder Crash löschen bereits geschriebene Originaldaten.
- Writer, Stop oder Finalisierung blockiert Main Actor oder Hotkeys außerhalb der Budgets.
- Timeline verwendet Wall Clock statt monotone Capturezeit zur Ausrichtung.
- Driftkorrektur verändert Originaldateien.
- erfolgreiche Tracksegmente werden beim Resume erneut übertragen oder transkribiert.
- ein Trackfehler invalidiert den erfolgreichen anderen Track.
- Merge verwirft echte Überlappungen oder behauptet nicht vorhandene Wortgenauigkeit.
- Offline-Modus sendet Meetingaudio oder -text.
- fehlendes lokales Modell löst still OpenAI aus.
- Migration verliert oder verändert bestehende 4.0-History.
- Löschen einer Meeting-Session kann fremde Aufnahmen oder Jobs treffen.
- finale ZIP unterscheidet sich vom getesteten Artefakt.
- erforderliche Apple-API-, Berechtigungs-, Architektur- oder Lizenzannahmen sind ungeklärt.

## 17. Definition of Done

Phase 4.1 ist abgeschlossen, wenn:

- beide Quellen real gleichzeitig und getrennt aufgezeichnet werden,
- Originaltracks in allen getesteten Fehlerpfaden erhalten bleiben,
- Offset, Gaps, Drift und Clipping je Track messbar und persistiert sind,
- abgeleitete Ausrichtung die Syncbudgets erreicht, ohne Originale zu verändern,
- Tracktranskription lokal und über OpenAI segmentiert und recoverbar funktioniert,
- erfolgreiche Segmente nach Neustart nicht wiederholt werden,
- der Merge Rollen, Reihenfolge und Überlappungen deterministisch erhält,
- Consent, Permissions und sichtbarer Status den definierten UX-Vertrag erfüllen,
- History, Migration, Retention und Löschen vollständig geprüft sind,
- die vollständige Regression von 4.0.2 bestanden ist,
- die entpackte finale Community-ZIP alle Release-Gates besteht,
- bekannte Einschränkungen korrekt dokumentiert sind.

Die Fertigstellung dieses Arbeitsplans ist kein Release. Sie autorisiert weder Push noch Merge nach `main`, Tag, GitHub Release oder Asset-Upload.

## 18. Unmittelbar nächster Schritt

Nach Review und Commit der bereits vorhandenen Grundlagen beginnt ausschließlich Schritt 4.1.1:

1. aktuelle Apple-API- und Permissionannahmen für macOS 14+ gegen Primärdokumentation prüfen,
2. einen isolierten Core-Audio-/System-Audio-Tap-Prototyp mit dem bestehenden ScreenCaptureKit-Pfad vergleichen,
3. Timestamp-, Format-, Recovery- und Ressourcenmessungen durchführen,
4. Captureentscheidung als Go-/No-Go festhalten,
5. erst danach den produktiven `MixedRecordingSessionCoordinator` bauen.
