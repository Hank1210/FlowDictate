# FlowDictate – Arbeitsplan Phase 4.1

**Phase:** 4.1 – Synchronized Meeting Capture
**Status:** Aktiver Umsetzungsplan; Capture-Spike abgeschlossen, Dual-Capture-Orchestrierung in Arbeit
**Stand:** 17. September 2026
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

Letzter verifizierter Teststand: 122 Tests erfolgreich am 17. September 2026.

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
- reale Langzeit-, Performance- und Recoverynachweise für vollständige Mixed Sessions.

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
| 4.1.1 Capture-Spike | `ERLEDIGT` | Grundlagen | verbindliche Captureentscheidung |
| 4.1.2 Dual-Capture-Coordinator | `IN ARBEIT` | Spike-Go | echte Mixed-Aufnahme |
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

**Status:** `ERLEDIGT` – `GO Core Audio Tap` für macOS 14.2+, ScreenCaptureKit-Kompatibilitätspfad für macOS 14.0/14.1; alle verpflichtenden Spike-Gates bestanden

### 7.1 Ziel

Vor dem produktiven Coordinator wird mit öffentlichen Apple-APIs entschieden, wie digitales Systemaudio auf der unterstützten macOS-Matrix zuverlässig und ausschließlich als Audio erfasst wird.

Zu vergleichen sind mindestens:

1. Core-Audio-/System-Audio-Tap, soweit auf Zielsystemen öffentlich verfügbar und für Distribution geeignet.
2. der bestehende audio-only konfigurierte ScreenCaptureKit-Pfad.

Der Spike muss nicht die spätere UI oder Verarbeitung enthalten. Er muss belastbare Antworten zu Berechtigung, Format, Timestamps, Recovery, Stabilität und Packaging liefern.

Am 15. September 2026 wurde der echte Core-Audio-Erstberechtigungsdialog manuell in beiden Richtungen sowie der nachträgliche Widerruf vor und nach App-Neustart geprüft. Ablehnung liefert stumme Callbacks und darf deshalb weder als `Allowed` noch als sichere technische Diagnose `Denied` ausgegeben werden. Nur tatsächlich empfangenes Systemaudiosignal verifiziert den Zugriff für die laufende App-Sitzung. Der Widerruf wirkt erst nach Prozessende. Ein während eines Wiederholungsversuchs beobachteter blockierender Core-Audio-Cleanup-Aufruf wird durch einen begrenzten, vom UI isolierten Cleanup-Pfad abgefangen. Ein anschließender Lauf bestand 10/10 Start-/Stop-Zyklen mit 975 Callbacks, 0 Gaps und erfolgreichem Cleanup; die Langzeitnachweise bleiben Teil des Spike-Gates.

Drei kontrollierte ScreenCaptureKit-Vergleichsläufe mit einer einzelnen App-Instanz lieferten 259, 250 und 253 Callbacks sowie durchgehend monotone, vollständige Zeitstempel. Nur der erste Lauf enthielt eine erkannte Lücke von 829 Frames (rund 17,3 ms bei 48 kHz); die beiden unmittelbaren Wiederholungen hatten keine Lücke. Die sichtbare Ergebnisanzeige im Audio-Tab ist damit manuell bestätigt. Die Langzeitmessungen entscheiden, wie sporadische Abweichungen in Gap-Metrik und Timeline-Recovery eingehen.

Der Langzeitdiagnose-Build bietet ohne erneute Kompilierung 5 Sekunden sowie 5, 30 und 60 Minuten für beide Backends, expliziten Abbruch und sichtbare Dauer-, Gap-, Zeitstempel-, Sample-Rate- und temporäre Dateigrößenmetriken. Sein Kontrollvergleich ergab für ScreenCaptureKit 4,4 Sekunden erfasste Audiodaten mit einer 38.400-Frame-Lücke, direkt danach für Core Audio Tap 5,0 Sekunden ohne Lücke und mit erfolgreichem Cleanup. Normale Diktation und Quellenwechsel bleiben während einer Probe gesperrt.

Der erste Core-Audio-Fünf-Minuten-Lauf war qualitativ lückenfrei und cleanup-stabil, lief jedoch real und audiobasiert 310,9 statt 300 Sekunden. Da Start-/Stop-Systemlogs und erfasste Frames übereinstimmen, ist dies als verspäteter Diagnose-Timer-Stop und nicht als Audio-Clock-Drift zu behandeln. Der folgende ScreenCaptureKit-Lauf grenzt den gemeinsamen Zeitmechanismus ein.

Der ScreenCaptureKit-Gegenlauf erfasste 300,040 Sekunden, 15.002 Callbacks, 0 Gaps, monotone vollständige PTS, 0 Sample-Rate-Änderungen und 2.477.371 Bytes temporäre M4A-Daten. Damit bestand ScreenCaptureKit das Fünf-Minuten-Qualitätsgate in diesem Lauf; der Core-Audio-Timer-Ausreißer wird mit einem zweiten gleich kontrollierten Lauf eingegrenzt.

Der zweite Core-Audio-Lauf bestätigte den backendnahen Stop-Ausreißer: 319,979 Sekunden Audiodaten, 29.998 Callbacks, 0 Gaps, monotone Zeitstempel und erfolgreiches Cleanup; die Systemlogs zeigten ebenfalls rund 320 Sekunden zwischen Start und Stop. Vor längeren Gates wird `AudioDeviceStop` deshalb durch einen dedizierten hochpriorisierten Timer direkt ausgelöst und vom potentiell blockierenden Destroy-Cleanup getrennt. Die Diagnose zeigt anschließend Sollzeit, reale Stop-Laufzeit und Audiodauer separat an. Erst ein korrigierter Fünf-Minuten-Lauf gibt das 30-Minuten-Gate frei.

Der korrigierte Fünf-Minuten-Lauf bestand dieses Gate mit 300,000 Sekunden Sollzeit, 300,001738 Sekunden realer Stop-Laufzeit und 300,010667 Sekunden Audiodaten. Er lieferte 28.126 Callbacks, 0 Gaps, monotone Zeitstempel und erfolgreiches Cleanup. Der nächste Langzeitschritt ist damit der 30-Minuten-Core-Audio-Lauf; erst nach dessen Bewertung folgt der entsprechende ScreenCaptureKit-Vergleich.

Der Core-Audio-30-Minuten-Lauf bestand ebenfalls: 1.800,000 Sekunden Sollzeit, 1.800,008087 Sekunden Wall, 1.800,000 Sekunden Audio, 168.750 Callbacks, 0 Gaps, monotone Zeitstempel und erfolgreiches Cleanup. Das 30-Minuten-Gate für den bevorzugten Core-Audio-Pfad ist damit erfüllt. Nächster Schritt ist der gleich lange ScreenCaptureKit-Gegenlauf.

Der ScreenCaptureKit-30-Minuten-Gegenlauf endete mit 1.800,253867 Sekunden Wall, 1.799,400 Sekunden Audio und 89.970 Callbacks. PTS und Sample-Rate blieben stabil, jedoch trat eine Lücke von 31.680 Frames beziehungsweise 0,66 Sekunden auf. Der Lauf ist damit technisch abgeschlossen, aber nicht lückenfrei bestanden. Core Audio Tap bleibt der klare Vorzugspfad; für ScreenCaptureKit als macOS-14.0/14.1-Kompatibilitätspfad sind Gap-Warnung und Recovery zwingend.

Der Core-Audio-60-Minuten-Lauf bestand mit 3.600,000 Sekunden Sollzeit, 3.600,010060 Sekunden Wall, 3.600,000 Sekunden Audio, 337.500 Callbacks, 0 Gaps, monotonen Zeitstempeln und erfolgreichem Cleanup. Damit sind die Dauergates 5, 30 und 60 Minuten für Core Audio Tap auf dem aktuellen Testsystem erfüllt. Für die finale Spike-Entscheidung bleiben insbesondere der 60-Minuten-ScreenCaptureKit-Vergleich, Ausgaberoutenwechsel und der Release-/Community-Paketnachweis offen.

Der ScreenCaptureKit-60-Minuten-Vergleich bestand mit 3.600,487661 Sekunden Wall, 3.600,100000 Sekunden Audio, 180.005 Callbacks, vollständigen monotonen PTS, 0 Gaps und 0 Sample-Rate-Änderungen. Die im 30-Minuten-Lauf erkannte 0,66-Sekunden-Lücke ist damit sporadisch statt dauerhafte Drift. Die reine 5-/30-/60-Minuten-Matrix ist abgeschlossen; offen bleiben Ausgaberoutenwechsel, Recovery und der Release-/Community-Paketnachweis.

Der fünfminütige Core-Audio-Ausgaberoutenwechsel MacBook-Lautsprecher → Plantronics-Headset → MacBook-Lautsprecher, mit kurzem zusätzlichen AirPods-Wechsel, bestand mit 300,009434 Sekunden Wall, 300,010667 Sekunden Audio, 28.126 Callbacks, 0 Gaps, monotonen Zeitstempeln und erfolgreichem Cleanup. Als Vergleich folgt derselbe Routenwechsel mit ScreenCaptureKit.

Auch ScreenCaptureKit bestand den fünfminütigen Wechsel MacBook-Lautsprecher → Plantronics-Headset → MacBook-Lautsprecher: 300,168522 Sekunden Wall, 300,020000 Sekunden Audio, 15.001 Callbacks, vollständige monotone PTS, 0 Gaps und 0 Sample-Rate-Änderungen. Der Ausgaberoutenvergleich ist damit abgeschlossen; nächster Gate-Bereich ist Cancel/Recovery.

Core Audio Tap bestand Cancel/Recovery: Eine laufende 30-Minuten-Probe wurde nach wenigen Sekunden abgebrochen, der Start-Button sofort wieder freigegeben und ein direkt folgender Fünf-Sekunden-Lauf mit 469 Callbacks, 0 Gaps, monotonen Zeitstempeln und erfolgreichem Cleanup beendet. Als Gegenprobe folgt derselbe Ablauf mit ScreenCaptureKit.

ScreenCaptureKit bestand Cancel/Recovery ebenfalls: Nach Abbruch wurde der Button wieder aktiv; der direkte Fünf-Sekunden-Wiederholungslauf endete mit 5,182252 Sekunden Wall, 5,080000 Sekunden Audio, 254 Callbacks, vollständigen monotonen PTS, 0 Gaps und 0 Sample-Rate-Änderungen. Als nächstes folgt kontrollierter Prozessabbruch/Neustart zur Prüfung der OS-Ressourcenfreigabe.

Core Audio Tap bestand den kontrollierten Prozessabbruch/Neustart: Die laufende Probe wurde per hartem Prozessende ohne Cleanup unterbrochen, der Debug-Build neu gestartet und unmittelbar danach eine Fünf-Sekunden-Probe mit 470 Callbacks, 0 Gaps, monotonen Zeitstempeln und erfolgreichem Cleanup abgeschlossen. macOS gab Tap und Aggregate Device prozessgebunden frei. Als Gegenprobe folgt ScreenCaptureKit einschließlich Prüfung auf verwaiste temporäre Dateien.

ScreenCaptureKit bestand die Ressourcen-Recovery nach demselben harten Prozessabbruch: Nach Neustart lief eine unmittelbare Fünf-Sekunden-Probe mit 5,3 Sekunden Wall, 5,1 Sekunden Audio, 257 Callbacks, vollständigen monotonen PTS, 0 Gaps und 0 Sample-Rate-Änderungen durch. Der Abbruch hinterließ jedoch im bisherigen Diagnosepfad eine 403.755 Bytes große, unlesbare M4A-Datei im normalen Aufnahmeordner. Probe-Artefakte werden deshalb nun in einem eigenen temporären Verzeichnis erzeugt; reguläres Ende und Cancel entfernen sie direkt, beim Appstart werden ausschließlich eindeutig als Probe markierte Dateien nicht mehr laufender Prozesse entfernt. Normale Nutzeraufnahmen liegen außerhalb dieses Bereichs und werden von dieser Bereinigung nie angefasst. Der manuelle Nachweis des neuen Pfads bestand: Nach `SIGKILL` blieb das 279.536-Byte-Probe-Artefakt zunächst bestehen, wurde beim Neustart automatisch entfernt und eine direkte Fünf-Sekunden-Wiederholung lief mit 5,2 Sekunden Wall, 5,0 Sekunden Audio, 252 Callbacks, 0 Gaps und stabiler Sample-Rate durch. Auch nach dem regulären Ende blieb kein Probe-Artefakt zurück.

Der finale Community-Paketnachweis bestand am 17. September 2026 mit dem aus dem ZIP entpackten, sandboxed und ad-hoc signierten Universal-Release-Build. Das 12-MB-Testpaket enthielt App-Version 4.0.2, Build 27 und die Architekturen `x86_64 arm64`; Signatur, Sandbox-/Audio-Input-Entitlements, `NSAudioCaptureUsageDescription` und SHA-256 `70dc7fcd68e04d1c27db82db5cb3b75ab2daffa147d49f5451f2597420906ae6` wurden unabhängig geprüft. Die reale Audio-only-Probe lieferte 5,0 Sekunden Soll-, Wall- und Audiodauer, 469 Callbacks, davon 229 mit Signal, 0 Gaps, monotone Zeitstempel und vollständiges Cleanup. Universal-Support bleibt erhalten. Ein zusätzlicher AirPlay-Routenwechsel ist ein nicht blockierender Hardeningfall.

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

**Entscheidung:** `GO Core Audio Tap`. Ab macOS 14.2 verwendet Mixed Recording den öffentlichen Core-Audio-Process-Tap als Systemaudiospur. Auf macOS 14.0/14.1 bleibt ScreenCaptureKit der ausdrücklich gekennzeichnete Kompatibilitätspfad. Mikrofon- und Systemaudiodatei bleiben getrennte Originale. Für den produktiven Startvertrag werden beide Mixed-Originale als segmentierbares CAF mit mono Float32 Linear PCM geschrieben; die native Samplerate wird je Track persistiert, für den nachgewiesenen Systemtap sind das 48 kHz beziehungsweise rund 691,2 MB pro Stunde. Abgeleitete M4A-Dateien dürfen später Speicher und Verarbeitung optimieren, ersetzen aber nie die Originale. Periodische monotone Anker werden in Schritt 4.1.2 gemeinsam mit den Writern implementiert. Universal-Support für `arm64` und `x86_64` bleibt verbindlich.

## 8. Schritt 4.1.2 – MixedRecordingSessionCoordinator und Dual Capture

**Status:** `ERLEDIGT` – Orchestrierung, beide produktiven Trackrecorder, Recovery und reale gemeinsame Kurzabnahme bestanden; die produktive Freischaltung bleibt bis zur Processing-Integration gesperrt

Der erste Teilstand enthält den actor-basierten Session-Coordinator, die Recorder-/Store-Schnittstellen, eine gemeinsame monotone Startbarriere sowie unabhängige Stop-, Cancel- und Teilfehlerbehandlung. Manifest und Originalpfade werden vor Capturebeginn angelegt; ein zweiter Start wird abgewiesen und Startfehler stoppen beide Recorder. Vier Fake-Recorder-Tests decken Startbarriere, Startausfall, partielle Finalisierung und Cancel mit anschließendem Neustart ab.

Der echte `MicrophoneTrackRecorder` schreibt die lokale Spur als mono Float32 Linear PCM in ein segmentierbares CAF bei nativer Samplerate. Er bestätigt den Start erst nach dem ersten Sample, erzeugt monotone Start-, Fünf-Sekunden- und Endanker und persistiert Gap-, Peak-, Clipping-, Stille- und Dropped-Buffer-Metriken. Stop und Cancel entfernen den Tap vor der Finalisierung und erhalten bereits geschriebene Originaldaten. Ein echter CAF-Writer-Test prüft vollständige Stereo-zu-Mono-Konvertierung ohne verlorene Restframes; ein separater Metriktest deckt Gap, Clipping und Stille ab. Vollständige Regression am 17. September 2026: 128/128 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen. Die bestehende `captureNotAvailable`-Sperre bleibt bestehen, bis auch der Systemaudio-Trackrecorder angeschlossen und beide Spuren real gemeinsam abgenommen sind.

Der produktive Core-Audio-Trackrecorder übernimmt für macOS 14.2+ den im Spike freigegebenen Process-Tap. Er schließt FlowDictate selbst aus, erzeugt ein privates Aggregate Device mit Drift Compensation, wartet vor der Startbestätigung auf den ersten Sampleanker und schreibt die Systemspur als mono Float32 Linear PCM in CAF. Stop und Cancel frieren den Writer vor der Finalisierung ein, ignorieren verspätete Callbacks, erhalten vorhandene Daten und führen den bereits erprobten begrenzten Tap-/IOProc-/Aggregate-Cleanup mit UID-Nachprüfung aus. Beide Trackwriter verwenden jetzt denselben `PCMTrackMetrics`-Vertrag. Ein echter CAF-Test bestätigt 4.800 vollständig geschriebene Frames, Timeline-/Peak-Metadaten und das Ignorieren eines späten Callbacks. Vollständige Regression dieses Teilstands: 129/129 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen; separate Debug-Builds für `arm64` und `x86_64` waren erfolgreich.

Der stabile `SystemAudioTrackRecorder` wählt den Backendvertrag genau einmal je Recorder-Lebensdauer: ScreenCaptureKit auf macOS 14.0/14.1, Core Audio Tap ab macOS 14.2. Der ScreenCaptureKit-Adapter registriert ausschließlich Audioausgabe, schließt FlowDictates eigenen Ton aus und schreibt die Originalspur über denselben CAF-, Timeline- und Qualitätsmetrikvertrag wie der Core-Audio-Pfad; Bild- oder Videoframes werden weder angefordert noch gespeichert. Stop, Cancel und Streamfehler lassen bereits finalisierbare Originaldaten erhalten. Auswahl- und Formatvertrag sind durch zwei neue Tests abgesichert. Vollständige Regression: 131/131 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen; Debug-Builds für `arm64` und `x86_64` waren erfolgreich. Als nächste Stufe folgen App-Integration und die reale gemeinsame Mikrofon-/Systemaudio-Abnahme; bis dahin bleibt die produktive Mixed-Sperre aktiv.

Für die reale Abnahme steht im Audio-Tab nun ein eng begrenzter Fünf-Sekunden-Test zur Verfügung. Er ist nur bei gewählter Mixed-Quelle und bestätigtem Consent verfügbar, verwendet die produktiven Recorder und den produktiven Session-Coordinator, zeigt während Capture und Finalisierung das Recording-Overlay und speichert zwei getrennte CAF-Originale plus Manifest. Er erzeugt keinen History-Eintrag, startet keine Transkription und führt keinen Netzwerkzugriff aus. Ein injizierter Coordinator-Test bestätigt, dass genau eine Mixed Session gestartet und gestoppt wird, während die bisherigen Single-Track-Recorder, Provider und Textinsertion unberührt bleiben. Vollständige Regression: 132/132 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen; Debug-Builds für `arm64` und `x86_64` waren erfolgreich. Die produktive Hotkey-Diktation bleibt bis zum manuellen Dual-Capture-Nachweis und der späteren Processing-Integration weiterhin gesperrt.

Der erste reale Mixed-Test am 18. September 2026 scheiterte beim Vorbereiten der Systemspur, weil `AVAudioFormat.isStandard` den gültigen interleaved Float32-Stream des Core-Audio-Taps ablehnte. Diese Eigenschaft bezeichnet bei AVFAudio ausschließlich nicht-interleaved Float32 und ist deshalb kein allgemeines PCM-Gültigkeitskriterium. Der produktive Recorder akzeptiert nun jeden konvertierbaren PCM-Tap-Stream mit positiver Samplerate und Kanalzahl; die bestehende Konvertierung normalisiert ihn weiterhin auf mono Float32 CAF. Ein Regressionstest führt interleaved Stereo-PCM durch denselben Capture-Sink und prüft Dauer, Peak, Zielformat und alle 4.800 Frames. Vollständige Regression: 133/133 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen; Debug-Builds für `arm64` und `x86_64` waren erfolgreich. Die reale Dual-Capture-Abnahme wird mit dem korrigierten Build wiederholt.

Die korrigierte reale Dual-Capture-Abnahme bestand am 20. September 2026. Mikrofon und Systemaudio wurden gleichzeitig als getrennte Originale mit 5,3 beziehungsweise 5,4 Sekunden, jeweils 0 Gaps und Peaks von 0,123 beziehungsweise 0,636 finalisiert. Die Artefaktprüfung bestätigte für beide Spuren lesbares mono Float32 Linear PCM bei 48 kHz, vollständige Framezahlen, 0 verworfene Buffer und 0 geclippte Frames. Das Manifest ist konsistent, bewahrt beide relativen Originalpfade und bildet den realen Startversatz des Mikrofons von rund 70 ms über monotone Trackanker ab. Damit ist das kurze reale Capture-Gate von Schritt 4.1.2 bestanden; als nächstes folgen robuste trackweise Verarbeitung und zeitbasierter Transcript-Merge. Die produktive Mixed-Hotkey-Diktation bleibt bis zu dieser Integration gesperrt.

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

Eine kurze reale Mixed Session erzeugt genau zwei getrennte, lesbare Originaldateien und ein valides Manifest. Start-, Stop-, Cancel- und Einspur-Ausfalltests sind grün. Dieses Capture-Gate ist erfüllt; die bisherige `captureNotAvailable`-Sperre bleibt bewusst bis zur vollständigen Processing- und Merge-Integration bestehen.

## 9. Schritt 4.1.3 – Timeline, Synchronisierung und Qualitätsbericht

**Status:** `ERLEDIGT` – Offset-, Drift- und Qualitätsanalyse sowie sicherer Derived-Renderer mit synthetischer Impulsabnahme implementiert; optionaler Preview-Mix bleibt ein separates Soll-Gate

Der erste Teilstand definiert den Startversatz eindeutig als `Mikrofon minus Systemaudio`, schätzt relative lineare Clock-Drift erst über mindestens 30 Sekunden und berechnet die maximale Residualabweichung aus den periodischen Ankern. Sessions mit Gaps erhalten absichtlich keinen globalen Driftwert, damit fehlende oder nichtlineare Abschnitte nicht durch Resampling kaschiert werden. Konfigurierbare Grenzwerte unterscheiden `good`, `degraded` und `unreliable`; unvollständige Sessions bleiben `notAnalyzed`. Der `MeetingQualityAnalyzer` aggregiert vollständige Rollen, Gapanzahl/-dauer und geclippte Frames ohne Inhaltsdaten. Stop und Cancel persistieren beide Reports zusammen mit den finalisierten Originalspuren. Synthetische Tests decken positive und negative Offsets, positive und negative Drift, Gaps, nichtlineare Sprünge und Einspur-Ausfall ab. Vollständige Regression am 20. September 2026: 136/136 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen; Debug-Builds für `arm64` und `x86_64` waren erfolgreich.

Der `DerivedTrackRenderer` erzeugt die beiden ausgerichteten Arbeitsdateien streamend und atomar ausschließlich unter `derived/`. Er schreibt verlustfreies mono Float32 CAF bei 48 kHz, bildet den signierten Startversatz durch vorangestellte Stille ab, setzt bekannte Gaps als Stille ein und korrigiert lineare Drift nur in der Mikrofonableitung. Sobald eine Session Gaps enthält, wird auch bei einem inkonsistent importierten Manifest kein globaler Driftfaktor angewendet. Unzuverlässige Synchronisation, Quellen außerhalb von `tracks/`, Ziele außerhalb von `derived/` und jedes Überschreiben eines Originals werden abgewiesen. Eine synthetische Impulsfixture bestätigt die Ausrichtung beider Spuren; weitere Tests sichern Gap-Einfügung, Driftresampling und bitweise unveränderte Originaldateien. Vollständige Regression: 140/140 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen; Debug-Builds für `arm64` und `x86_64` waren erfolgreich. Der optionale hörbare Preview-Mix mit `-3 dBFS`-Headroom gehört weiterhin zum separaten Soll-Gate und blockiert Schritt 4.1.4 nicht.

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
