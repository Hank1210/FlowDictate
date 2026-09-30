# FlowDictate – Arbeitsplan Phase 4.1

**Phase:** 4.1 – Synchronized Meeting Capture
**Status:** Releasevorbereitung; Testphase abgeschlossen, bekannte Gate-Abweichungen in 14.3 dokumentiert, Veröffentlichung nicht autorisiert
**Stand:** 30. September 2026
**Ausgangsbasis:** FlowDictate 4.0.2, Build 27, Tag `v4.0.2`, Release-Commit `5bfc957`
**Arbeitsbranch:** `codex/phase-4-1-prep`, Basis-Commit `5095b38`
**Anforderungsgrundlage:** [FlowDictate PRD Phase 4.1](../requirements/FlowDictate_PRD_Phase_4_1.md)
**Private Testnotizen:** `TESTING_4_1.md`, nicht versionieren
**Ablage:** öffentlich und versioniert unter `docs/engineering/`; die Ausnahme in `.gitignore` gilt ausschließlich für diesen Plan

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

### 4.3 Noch offen

- reale Langzeit-, Performance- und weitere Recoverynachweise für vollständige End-to-End-Sessions.

Der produktive Mixed-Ablauf ist für Toggle und Press & Hold freigeschaltet. Dual-Level-Overlay, History-Synchronisierung, Restart-Resume, getrennte Originalspurwiedergabe, bestätigtes vollständiges Löschen sowie Retention und Archivierung sind implementiert und abgenommen. Schritt 4.1.6 ist damit geschlossen; als Nächstes folgt das Hardening von Schritt 4.1.7.

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
| 4.1.2 Dual-Capture-Coordinator | `ERLEDIGT` | Spike-Go | echte Mixed-Aufnahme |
| 4.1.3 Timeline, Sync und Qualität | `ERLEDIGT` | reale Trackanker | ausgerichtete Arbeitsdaten |
| 4.1.4 Track-Processing und Recovery | `ERLEDIGT` | finale Trackverträge | recoverbare Transkripte |
| 4.1.5 Timed Merge | `IN ARBEIT` | Tracktranskripte + Sync | Meeting-Timeline |
| 4.1.6 UX, History und Migration | `ERLEDIGT` | stabile Zustände | vollständiger Nutzerablauf |
| 4.1.7 Hardening und Langzeittests | `IN ARBEIT` | End-to-End-Pfad | Releasekandidat |
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

**Status:** `ERLEDIGT` – persistierter Track-Runner, bestehende Single-File-/Long-Form-Pipeline, Provider-/Privacy-Vertrag und exklusive 4.0-Queue-Anbindung sind integriert und durch Mehrsegment-Recoverytests abgesichert

Der erste Teilstand friert Provider, Engine, Modell, Sprache, Privacy-Modus und Profil im Meetingmanifest ein und vergibt pro Track eine stabile Transkriptions-ID. `TrackTranscriptionRunner` verarbeitet beide Spuren unabhängig, persistiert jeden Zustandswechsel atomar, bewahrt erfolgreiche Trackresultate bei Fehler, Abbruch und Retry und schreibt validierte Transcript-Artefakte ausschließlich unter `transcription/`. Ein Teilfehler löscht weder Originalaudio noch das Ergebnis der anderen Spur; der Merge wird erst nach zwei erfolgreichen Trackabschlüssen freigegeben. Ältere 4.1-Testmanifeste ohne Privacy-Feld werden anhand des eingefrorenen Providers konservativ migriert.

`LongFormTrackTranscriptionExecutor` bindet die Trackjobs an den vorhandenen `TranscriptionRunner` und dessen segmentierbare, wiederaufnehmbare Long-Form-Session an. Die internen Track-Workflow-Records liegen innerhalb der Meeting-Session und erscheinen nicht als künstliche Einträge in der normalen Nutzer-History. Offline-Policy wird vor der Providerauflösung erzwungen; es gibt keinen stillen Cloudfallback. Ein fehlendes lokales Modell pausiert die Session fortsetzbar, startet den zweiten Track nicht zwecklos und gibt den Processing-Slot kontrolliert frei.

Meetingverarbeitung verwendet exklusiv dieselbe persistente Processing-Lane wie normale 4.0-Diktate. Währenddessen werden neue Recording-Reservierungen abgewiesen; ein Meeting startet seinerseits nicht neben einem aktiven, reservierten oder wartenden Diktat. Slotfreigabe ist bei Erfolg, Teilfehler, Pause und Cancellation abgesichert. Ein realer Zwei-Track-Mehrsegment-Test erzeugt je Spur ein erfolgreiches und ein fehlgeschlagenes Segment, erstellt anschließend neue Runner-/Executor-Instanzen wie nach einem App-Neustart und bestätigt für Local sowie OpenAI-Testdouble, dass nur das jeweils fehlende Segment erneut verarbeitet wird. Vollständige serielle Regression am 21. September 2026: 149/149 Tests bestanden; Debug-Builds für `arm64` und `x86_64` waren erfolgreich. Die produktive Mixed-Hotkey-Freischaltung bleibt absichtlich bis zum validierten Timed Merge und der vollständigen UX gesperrt.

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

**Status:** `ERLEDIGT` – persistierte rollenmarkierte Timeline, ehrliche Zeitpräzision, deterministischer Merge und Recovery implementiert; die chronologische Position eigener Beiträge im realen 120-Minuten-Take vom Nutzer bestätigt, ohne eine allgemeine Erkennungsgenauigkeit zu behaupten

`TimedTranscriptMerger` bildet beide validierten Tracktranskripte über ihre monotone Startanker-, Gap- und Driftinformation auf eine gemeinsame Sessionzeit ab. Sortiert wird deterministisch nach Startzeit, Rolle und Quellindex; echte Überlappungen und identischer Text auf beiden Tracks bleiben erhalten. Eine automatische Zusammenführung wird bei fehlender oder unzuverlässiger Synchronisation abgewiesen. Das Ergebnis wird atomar als `transcription/merged-timeline.json` gespeichert, bevor die Session mit einem rollenmarkierten Finaltext abgeschlossen wird. Ein Mergefehler pausiert recoverbar und erhält beide Trackartefakte.

**Lesbarkeits-Nachtrag 23. September 2026:** Ein kurzer privater Mixed-Realtest zeigte, dass die wortgenaue Timeline bei gleichzeitiger Sprache im Finaltext zu häufigen Rollenwechseln führte. Die persistierten Worteinträge bleiben unverändert; nur die lesbare Projektion gruppiert nahe Worte je Originalspur zu begrenzten Sprecherabschnitten und markiert belastbar wortgenaue Überlappung. Synthetische Merge-Regression und vollständige serielle Testsuite bestehen, der universelle Debug-Build ist erfolgreich. Die manuelle Bestätigung mit einer neuen kurzen Mixed-Session bleibt offen; bis dahin ist die Rollen-/Timelineverständlichkeit nicht abgenommen.

**Weiterer Lesbarkeitsbefund 23. September 2026:** Ein beaufsichtigter Fast-5-Minuten-Lauf zeigte weiterhin Systemaudio-Satzabbrüche durch zwischengeschobene Mikrofonblöcke: Die bisherige 15-Sekunden-Grenze konnte mitten im Satz trennen. Der Renderer behandelt 15 Sekunden nun als weiche Grenze und trennt bevorzugt am nächsten Satzende, mit einer harten 45-Sekunden-Grenze. Die wortgenaue Timeline und Originalspuren bleiben unverändert. Ein gezielter Überlappungs-/Langsatztest und die vollständige serielle Suite bestehen (202/202); universeller Debug-Build `arm64 x86_64` erfolgreich. Bestehende persistierte Transkripte werden nicht still umgeschrieben. Die manuelle Lesbarkeitsabnahme mit dem neuen Build bleibt offen.

Die Zeitgenauigkeit wird pro Eintrag explizit als `word`, `segment` oder `trackChunk` gespeichert. FluidAudio-Wortzeiten werden bei direkter lokaler Tracktranskription bis ins Meeting-Artefakt weitergereicht. Der damalige Stand ordnete Long-Form-Ergebnisse ohne übernommene Zeitmarken als einen Track-Chunk ein; die Korrektur nach dem 120-Minuten-Lauf persistiert jetzt echte Wortzeiten je Segment und verwendet bei Providern ohne Wortzeiten nur die bekannten Segmentintervalle. Wortzeiten werden nicht künstlich geschätzt; die Long-Form-Pipeline entfernt interne Textüberlappungen vor dem Merge.

Das persistente `MeetingTranscriptInsertionGate` autorisiert eine automatische Einfügung höchstens einmal. Ein nicht verfügbares Ziel führt zu Deferred Insertion; ein Neustart nach bereits begonnenem, aber nicht sicher bestätigtem Einfügeversuch markiert den Zustand als unklar und verhindert eine mögliche Doppelinsertion. Die eigentliche UI-Anbindung dieses Gates gehört zu Schritt 4.1.6.

Vollständige serielle Regression am 21. September 2026: 156/156 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen. Debug-Builds für `arm64` und `x86_64` waren erfolgreich. Die produktive Mixed-Hotkey-Freischaltung bleibt bis zur vollständigen UX- und History-Integration weiterhin gesperrt.

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

**Status:** `ERLEDIGT` – Schema 7, Meeting-History-Synchronisierung, getrennte Live-Pegel, produktiver Mixed-Hotkey-Pfad, Restart-Resume, Trackwiedergabe, bestätigtes Löschen, Partial-/Retry-UX, Warnzustände sowie Retention und Archivierung sind implementiert und abgenommen

**Zwischenstand 21. September 2026:** `DictationRecord` enthält optional eine kompakte, inhaltsfreie Meetingzusammenfassung mit Sessionreferenz, beiden Trackzuständen, Dauer, Dateigröße, Gap-/Clippingzählung, Synchronisationsqualität und Insertion-State. Das Sessionmanifest bleibt die alleinige Quelle für Pfade, Tracktranskripte und Recovery. Beim ersten Schreiben aus Schema 6 entsteht einmalig `dictations-pre-4.1.json`; Single-Track-Einträge werden ohne automatische `.mixed`-Umdeutung weitergelesen. Die History-Detailansicht kennzeichnet Meetings mit Text und Symbol, zeigt beide Tracks, Qualitätswarnungen und eine gemeinsame Rollen-Timeline und bietet Finder, Copy, Export sowie Insert. Restart-Resume ist im fünften Zwischenstand und die vollständige Trackwiedergabe-/Löschgrenze im sechsten Zwischenstand ergänzt.

Vollständige serielle Regression: 158/158 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen. Der 1.000-Record-Test enthält 100 Meetingzusammenfassungen. Debug-Builds für `arm64` und `x86_64` waren erfolgreich.

**Zweiter Zwischenstand 21. September 2026:** Ein eigener `MeetingProcessingWorkflow` verbindet die bereits recoverbare Tracktranskription und den deterministischen Merge mit der Nutzer-History an dauerhaften Stufengrenzen. Fehler synchronisieren den zuletzt persistierten Manifestzustand, statt einen optimistischen UI-Status zu behaupten. Beim App-Start werden ausschließlich Sessions normalisiert, die bereits über eine Meetingreferenz mit der aktiven History verbunden sind. Dadurch bleiben der fünfsekündige Capture-Test und andere nicht verknüpfte Diagnosemanifeste weiterhin bewusst außerhalb der Nutzer-History. Ziel-App-Metadaten bleiben bei späteren Manifestupdates erhalten; kompakt archivierte Transkripte werden beim Neustart nicht aus dem Manifest rehydriert. Drei neue Tests sichern die vollständige Workflow-Synchronisierung, die Trennung zwischen produktiven und diagnostischen Sessions sowie die Archivgrenze. Vollständige serielle Regression: 161/161 Tests bestanden.

**Dritter Zwischenstand 21. September 2026:** Beide Mixed-Trackrecorder veröffentlichen nun unabhängig berechnete und auf zehn Aktualisierungen pro Sekunde begrenzte RMS-Pegel. Das Recording-Overlay zeigt sie als getrennte, text- und symbolbeschriftete Zeilen `Mic` und `System`; VoiceOver erhält je Spur einen Namen und Prozentwert, Reduced Motion bleibt berücksichtigt. Der technische Mixed-Test führt denselben produktiven Pegelpfad aus, während die Originalspuren weiterhin getrennt geschrieben werden. Automatisierte Regression: 161/161 Tests bestanden. Ein realer Fünf-Sekunden-Lauf finalisierte Mikrofon mit 5,4 Sekunden, 0 Gaps und Peak 0,152 sowie Systemaudio mit 5,5 Sekunden, 0 Gaps und Peak 0,675. Zwei Originalspuren und Manifest wurden gespeichert; Transkription blieb erwartungsgemäß aus. Die manuelle Sichtprüfung bestätigte außerdem beide beschrifteten Overlayzeilen und ihre unabhängig unterschiedlichen Reaktionen. Damit ist der Dual-Level-Nachweis vollständig bestanden.

**Vierter Zwischenstand 21. September 2026:** Die technische Mixed-Sperre ist entfernt und der produktive Ablauf ist an Toggle sowie Press & Hold angeschlossen. Eine gestartete Session wird sofort mit der Nutzer-History verknüpft, damit ein Prozessabbruch bereits während der Aufnahme recoverbar bleibt. Stop finalisiert beide Originalspuren, synchronisiert die Qualitätsdaten, übergibt die Session an die exklusive Meeting-Processing-Lane, transkribiert die Tracks mit der eingefrorenen Provider-/Privacy-Konfiguration, merged die Timeline und führt automatische Einfügung ausschließlich über das persistierte Exactly-once-Gate aus. Ein nicht mehr verfügbares Ziel bleibt als Deferred Insertion in History; es gibt keinen Mixed-zu-Mikrofon- oder Local-zu-Cloud-Fallback. Cancel bewahrt finalisierbare Originalspuren und startet weder Processing noch Insertion. Drei neue Coordinator-Tests prüfen Toggle bis zur genau einmaligen Einfügung, Press-&-Hold-Release und Cancel. Vollständige Regression: 164/164 Tests bestanden, 0 Fehler, 0 übersprungen und 0 Runtime-Warnungen; Debug-Builds für `arm64` und `x86_64` waren erfolgreich. Die erste reale produktive End-to-End-Session bestand anschließend Dual Capture, Verarbeitung, Merge und die erfolgreiche Einfügung eines rollenmarkierten Transkripts. Separate manuelle Press-&-Hold-, Cancel- und Recovery-Abnahmen bleiben Teil der folgenden UX-/Hardening-Gates.

**Fünfter Zwischenstand 22. September 2026:** Restart-Resume ist produktiv geschlossen. Nach einem harten Prozessabbruch während Mixed Capture normalisiert FlowDictate die verknüpfte Session auf `paused` und die aktiven Tracks auf `interrupted`, ohne Originaldateien zu verändern. `Continue Processing` in History liest die erhaltenen CAF-Dateien nur zur Wiederherstellung von Dauer, Dateigröße und PCM-Format, stuft die wegen des Crashs unvollständige Capture-Timeline konservativ als `degraded` ein und setzt Tracktranskription sowie Merge mit der im Manifest eingefrorenen Provider-/Privacy-Konfiguration fort. Da nach einem Neustart kein verlässliches altes Fokusziel existiert, wird das fertige Transkript stets als `deferred` in History abgelegt und nie automatisch eingefügt. Die manuelle Abnahme bestand mit zwei lesbaren rund 30-sekündigen Originalspuren, OpenAI `gpt-4o-mini-transcribe`, zwei transkribierten Tracks und fertiger Rollen-Timeline. Zwei neue Regressionstests sichern byte-identischen Originalerhalt und die ausbleibende automatische Einfügung; vollständige Regression: 169/169 Tests bestanden. Universal-Debug-Build: `x86_64 arm64`.

**Sechster Zwischenstand 22. September 2026:** Jede Meeting-Trackzeile besitzt eine eigene Wiedergabeaktion, die den Originalpfad ausschließlich aus dem validierten Sessionmanifest auflöst und auf den jeweiligen `tracks/`-Ordner begrenzt. Die manuelle Abnahme bestätigte, dass Mikrofon- und Systemaudiospur separat und hörbar unterschiedlich wiedergegeben werden. `Archive History Entry` bleibt eine nichtdestruktive, getrennte Aktion. `Delete Meeting and Files…` verlangt eine ausdrückliche Bestätigung und löscht danach exakt den UUID-Sessionordner mit beiden Originals, Derived Files, Segmenten, Timeline und Manifest sowie nur den verknüpften History-/Jobdatensatz. Abbrechen bewahrt die Session vollständig; beide Dialogpfade wurden manuell bestanden. Drei neue Tests sichern sichere Originalpfadauflösung, Ablehnung von Pfaden außerhalb `tracks/`, idempotentes UUID-begrenztes Löschen sowie den Erhalt einer Nachbarsession, einer fremden Datei und eines fremden Jobs. Vollständige serielle Regression: 172/172 Tests bestanden; Universal-Debug-Build: `x86_64 arm64`. Ein bestehender Mixed-Cancel-Test überschritt im ersten parallelen Gesamtlauf einmal sein Zeitbudget, bestand isoliert und in der vollständigen seriellen Suite; kein reproduzierbarer Produktionsfehler.

**Siebter Zwischenstand 22. September 2026:** Die Partial-/Retry-UX unterscheidet jetzt eine partielle Transkription von einer partiellen Aufnahme. Nur bei mindestens einem bereits transkribierten und mindestens einem fehlgeschlagenen Track zeigt History `Partial transcription`, den Hinweis, dass fertige Trackarbeit erhalten bleibt, und die Aktion `Retry Failed Track`. Ein ausschließlich im Debug-Build vorhandener Einmal-Testschalter lässt den ersten Systemaudio-Transkriptionsversuch kontrolliert vor dem Provideraufruf scheitern; Release-Builds enthalten weder Schalter noch Beschriftung. Die reale Abnahme bestand: zunächst Mikrofon `Transcribed`, Systemaudio `Failed`, 1/2 Tracks fertig und keine Einfügung; nach Retry wurde ausschließlich Systemaudio verarbeitet, anschließend standen Session auf `Completed`, beide Tracks auf `Transcribed`, Completion Mode auf `allTracks`, Timeline vorhanden und Insertion auf `deferred`. Beide internen Trackjobs dokumentieren genau einen echten Provideraufruf. Eine 14-ms-Lücke im Systemaudio blieb korrekt als Qualitätswarnung sichtbar, bei 0 Clipping-Frames und trotzdem vollständigem Ergebnis. Zwei neue Tests sichern UX-Abgrenzung und Einmalfehler/Retry ohne Wiederholung der erfolgreichen Spur. Vollständige serielle Regression: 174/174 Tests bestanden; universelle Debug- und Release-Builds enthalten `x86_64 arm64`.

**Achter Zwischenstand 22. September 2026:** Die produktiven Mikrofon-, Core-Audio- und ScreenCaptureKit-Recorder melden spurbezogene Clipping- und explizite Capturefehler an den Mixed-Coordinator. Das Recording-Overlay zeigt diese Warnungen dauerhaft mit orangefarbenem Symbol, Text und betroffener Spur, ohne die verbleibende Aufnahme oder den Erhalt der Originalspuren abzubrechen. Clipping und Trackverlust werden je Spur und Aufnahme nur einmal gemeldet; Writer-, Konvertierungs- und Streamfehler werden als Trackverlust sichtbar. History benennt Clipping und unvollständige Capturezustände ebenfalls ausdrücklich. Zwei ausschließlich im Debug-Build enthaltene Anzeigeaktionen erlauben die deterministische manuelle Overlay-Abnahme, ohne Audiodateien oder Manifestzustände künstlich zu verändern; der universelle Release-Build enthält weder Aktionen noch Beschriftungen. Die manuelle Abnahme bestand: Mikrofon-Clipping- und Systemaudio-Verlustwarnung waren gleichzeitig sichtbar, während beide Live-Pegel weiterliefen. Zwei neue Tests sichern die typisierte Warnweitergabe und die Historyhinweise bei Trackverlust und Clipping. Vollständige serielle Regression: 176/176 Tests bestanden; universeller Release-Build erfolgreich mit `x86_64 arm64`. Das Warn-UX-Gate ist damit abgeschlossen.

**Neunter Zwischenstand 22. September 2026:** Retention und Archivierung der sichtbaren Meeting-History sind geschlossen. Die Prüfung fand eine falsche Einzeldatei-Annahme: Der synthetische Meeting-History-Pfad wurde zuvor über den normalen `Audio`-Store aufgelöst, sodass die Retention den Datensatz auf null Bytes setzen konnte, ohne den außerhalb dieses Ordners liegenden Sessionordner zu entfernen. Abgelaufene, vollständig abgeschlossene Meetings werden nun als eine UUID-begrenzte Retentionseinheit behandelt; Originalspuren, Derived Files, Tracktranskripte, Timeline und Manifest werden gemeinsam entfernt. Der sichtbare History-Eintrag und seine fertige Rollen-Timeline bleiben bis zum separaten History-Limit erhalten, während Track-Bytewerte auf null gesetzt und nicht mehr vorhandene Wiedergabe-/Finder-Aktionen deaktiviert werden. Partielle beziehungsweise recoverbare Meetings bleiben automatisch geschützt. Die explizite Aktion `Archive History Entry` bleibt nichtdestruktiv, entfernt private Text- und Zielmetadaten aus dem sichtbaren Verlauf, bewahrt aber Sessionreferenz und Dateien; ein späterer Manifest-Sync rehydriert den archivierten Text nicht. Erreicht die Audio-Retention später einen bereits archivierten Eintrag, entfernt sie dessen Sessionordner und der anschließend leere Tombstone wird kontrolliert verworfen. Vier neue Retentiontests und der erweiterte Archivtest sichern diese Grenzen. Vollständige serielle Regression: 180/180 Tests bestanden; universeller Debug-Build erfolgreich mit `x86_64 arm64`. Schritt 4.1.6 ist damit abgeschlossen.

**Grenzfall-Nachtrag 22. September 2026:** Ein abgeschlossenes Meeting mit `ready`, `attempting`, `deferred`, `unknown` oder fehlendem Einfügungsstatus gilt weiterhin als recoverbar. Solche Einträge und ihre Originalspuren werden weder durch automatische History-/Audio-Retention entfernt noch manuell archiviert; die Aktion ist in History deaktiviert und der Store erzwingt dieselbe Regel. Auch abgebrochene Meetings mit bewahrten Originalspuren bleiben sichtbar: Die Audio-Retention für erfolgreiche Aufnahmen würde ihre Dateien sonst nach einer Archivierung nicht bereinigen. Nur bestätigte Einfügung (`completed`) erlaubt die Archivierung; vollständiges Löschen bleibt eine getrennte, bestätigte Aktion. Vor einer Audio-Löschung wird zusätzlich das autoritative Sessionmanifest auf Record-ID, Terminalstatus und bestätigte Einfügung geprüft, damit ein veralteter History-Snapshot keine inzwischen recoverbare Session löscht. Das manuelle Anwenden der Retention aktualisiert sichtbare History-Snapshots zuvor aus ihren Manifesten, ohne laufendes Capture als Unterbrechung zu normalisieren. Die nachträglichen Tests prüfen alle vier explizit offenen Einfügungszustände gegen beide Retentionpfade und die Archiv-API sowie den Schutz vor veralteter History.

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

**Status:** `TESTPHASE ABGESCHLOSSEN MIT ABWEICHUNGEN` – Langläufe, Recovery und Sicherheitsnachweise vorhanden; Nullverlustziel verfehlt und mehrere Performancebudgets unbelegt (14.3)

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

**Zwischenstand 22. September 2026:** Inhaltsfreie OS-Signposts markieren Mixed-Preflight, Sessionstart/-stop, Manifest- und Historypersistenz, Trackvorbereitung, erste/letzte Sampleanker, Writer-Finalisierung, Gaps, Trackverlust, Synchronisierung, Derived Rendering, Tracktranskription, Segmentintervalle der gemeinsamen Long-Form-Pipeline, Merge und verknüpfte Recovery-Normalisierung. Sie enthalten nur UUIDs, Rollen, Zustände, Hostzeiten, Größen und grobe Qualitätszähler; weder Text noch Audio-/Transkriptpfade oder Zielanwendungen. Die Events unterscheiden einen erkannten Trackverlust noch nicht zuverlässig nach Writer-, Geräte- und Quellenfehler. Die Signposts liefern erste Messpunkte; die Performancebudgets aus 13.4 sind noch nicht mit realen Langläufen nachgewiesen.

**Diagnostik-Nachtrag 23. September 2026:** Trackverlust-Signposts tragen nun bei Start- und Stopfehlern zusätzlich zur bestehenden Kategorie eine feste, inhaltsfreie Herkunft: `writer`, `device`, `source` oder konservativ `other`. Die Klassifikation nutzt ausschließlich typisierte Recorder-/Gerätefehler und Out-of-Space-Codes, nie Fehlermeldungen oder Pfade. Ein Regressionstest deckt beide Recorder, alle vier Herkunftswerte und POSIX-Platzmangel ab; vollständige serielle Regression: 200/200 bestanden. Die tatsächliche Signpost-Auswertung und die Performancebudgets benötigen weiterhin reale Läufe.

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

**Automatisierter Zwischenstand 22. September 2026:** Zehn aufeinanderfolgende Mixed Sessions mit getrennten Originalspuren, persistiertem Manifest und wiederholten Start-/Stop-Aufrufen sind als Regressionstest ergänzt. Ein kontrolliert angehaltener Stop prüft konkurrierende Stop-/Cancel-/Start-Aufrufe im Zustand `finalizing`; Mikrofon-Prepare- und Mikrofon-Stopfehler ergänzen die vorhandenen Systemaudio-Fehlerfälle und prüfen den Erhalt des jeweils noch verfügbaren Zustands beziehungsweise Originals. Eine persistierte Restart-Matrix deckt alle elf Sessionstatus und alle Trackstatus ab: Nur aktive Arbeit wird normalisiert, beide Originale bleiben bytegleich und ein zweiter Recovery-Lauf ist idempotent. Zusammen mit den Retention-Grenzfällen: vollständige serielle Regression 189/189 bestanden, Universal-Debug-Build `arm64 x86_64` erfolgreich. Ein Bestehen ersetzt weder echte Capture-Last noch die übrigen Fehler-, Segment- und Policy-Matrizen.

**Speicher-Nachtrag 22. September 2026:** Die Long-Form-Pipeline prüft freien Festplattenspeicher nun vor jedem noch nicht erfolgreichen Segment, auch beim Resume eines vorhandenen Manifests. Ein deterministischer Test deckt Platzmangel vor der ersten Segmentplanung, nach einem erfolgreichen Segment sowie beim erneuten Resume ab: Kein Provideraufruf ohne ausreichendes Budget, das abgeschlossene Segment und das Original bleiben erhalten, der Fehler wird als `insufficientWorkingStorage` klassifiziert. Serielle Regression: 190/190 bestanden. Die Speicherprüfung vor dem eigentlichen Mixed-Capture-Start und der reale Low-Disk-Lauf bleiben offen; diese Verarbeitungstests ersetzen sie nicht.

**Capture-Speicher-Nachtrag 22. September 2026:** Vor dem Anlegen einer Meeting-Session und vor der Vorbereitung beider Recorder prüft Mixed Capture auf dem gewählten Aufnahmevolume ein Mindestbudget von 500 MB. Das deckt rechnerisch mindestens fünf Minuten zweier 96-kHz-Mono-Float32-Originalspuren samt Reserve ab; es ist keine Zusage einer maximalen Aufnahmedauer. Bei Unterschreitung wird der Start mit verständlichem Fehler abgewiesen, ohne einen Sessionordner oder eine Recorder-Vorbereitung anzulegen. Der Grenzfall ist injizierbar und automatisiert geprüft; serielle Regression 191/191 bestanden. Dynamische Warnungen bei Platzverlust während einer laufenden Aufnahme, die Settings-Prognose pro Stunde und ein realer Low-Disk-Lauf bleiben offen.

**Produktentscheidung 22. September 2026:** Die pauschale 500-MB-Startsperre wird nach Review zurückgenommen. Bei 50–500 MB freiem Platz startet Mixed Capture mit sichtbarer Warnung, weil kurze Aufnahmen möglich bleiben sollen; nur unter 50 MB blockiert ein minimales Sicherheitsbudget vor Session- und Recorder-Vorbereitung. Das entspricht grob 30 Sekunden zweier 96-kHz-Mono-Float32-Spuren plus Reserve, nicht einer garantierten Aufnahmedauer. Statt laufender freier-Speicher-Abfragen werden echte Writerfehler sofort als solche, getrennt von Quellenverlust, gewarnt; die andere Spur und bereits geschriebene Dateien werden nicht gelöscht. Settings erklären als erste Größenordnung 1,4 GB pro Stunde für beide 48-kHz-Originale und den möglichen zusätzlichen Bedarf aus Arbeitskopien. Serielle Regression 192/192 bestanden. Offen bleiben eine geräte- und sample-rate-spezifische Prognose, reale Low-Disk-/Langläufe und die präzisere Persistenz-Klassifizierung von Writerfehlern.

**Writerfehler-Nachtrag 23. September 2026:** Beim Start- und Stop-Pfad bleibt die Fehlerart nun typisiert bis zum Meeting-Manifest erhalten. Ein Writerfehler wird je Track und auf Sessionebene als `storageFull` klassifiziert, wenn der zugrunde liegende Cocoa-/POSIX-Fehler fehlenden Speicherplatz meldet, sonst als `storageUnavailable`; Geräte- und Quellenfehler behalten ihre bisherigen Kategorien. Die Warnung bleibt sofort sichtbar, und keine der beiden Originaldateien wird wegen des Trackfehlers gelöscht. Drei neue Tests prüfen die persistierten Kategorien beider Rollen beim Stop, den Startfehler, die intakte Gegenspur und verschachtelte Out-of-Space-Fehler. Serielle Regression: 195/195 bestanden. Ein realer Low-Disk-Lauf bleibt erforderlich.

**Policy-Matrix-Nachtrag 23. September 2026:** Für lokale und OpenAI-Tracktranskription sind alle drei Privacy-Modi als sechs Kombinationen automatisiert geprüft. Beide Meeting-Rollen erhalten den eingefrorenen Provider und Privacy-Modus; OpenAI wird in `offline` und `localWithOptionalCloudEnhancement` vor der Providerauflösung blockiert, während nur `cloudTranscription` den Cloudpfad zulässt. Lokale Transkription bleibt in allen Modi lokal gewählt. Der Test nutzt einen Mock-Provider und beweist daher die Policy-Grenze, nicht das Ausbleiben realer HTTP-Requests; dieses Netzwerkgate bleibt für die manuelle/Integration-Abnahme offen. Serielle Regression: 196/196 bestanden.

**Recovery-Grenzfall 23. September 2026:** Ist nach einem Prozessabbruch eine Originalspur beschädigt oder nicht mehr vorhanden, wird sie nun spurbezogen als `unavailable` mit `audioCorrupt` beziehungsweise `storageUnavailable` persistiert; die lesbare Gegenspur wird unabhängig finalisiert und kann weiter transkribiert werden. Der partielle Sessionfehler bleibt bis zur History sichtbar. Der Regressionstest prüft beide Rollen, unveränderte Originalbytes, idempotente Wiederherstellung und die Verarbeitung nur der intakten Spur. Unsichere Originalpfade bleiben ein harter Abbruch. Vollständige serielle Regression: 197/197 bestanden; universeller Debug-Build `arm64 x86_64` erfolgreich. Ein realer Force-Quit-Lauf mit beschädigter beziehungsweise fehlender Spur bleibt als End-to-End-Gate offen.

**HTTP-Policy-Integration 23. September 2026:** Der produktive Meeting-Track-Runner wurde mit dem echten OpenAI-Transkriptionsclient und einem ausschließlich lokalen URL-Protocol-Testdouble für alle drei Privacy-Modi geprüft. `offline` und `localWithOptionalCloudEnhancement` erzeugten jeweils null HTTP-Uploads; `cloudTranscription` erzeugte genau einen Upload je Track und beide Transkripte wurden persistiert. Keine Testdaten gingen an einen externen Dienst. Vollständige serielle Regression: 198/198 bestanden. Die Beobachtung gegen den realen Netzwerkdienst und die Prüfung der freigegebenen Payloads bleiben getrennte Abnahme-Gates.

**Multipart-Payload-Nachtrag 23. September 2026:** Ein weiterer Test inspiziert die vom echten OpenAI-Client für zwei getrennte synthetische Audiodateien erzeugten Multipart-Bodys vor ihrer lokalen Entfernung. Jeder Body enthält genau die ausgewählte Audiodatei, nicht die andere Spur oder eine benachbarte synthetische Videodatei; neben `model` und `file` werden ohne Eingabe keine `language`-, `prompt`- oder `video`-Felder geschrieben. Die HTTP-Antwort kommt weiterhin nur von einem lokalen Testdouble. Serielle Regression: 199/199 bestanden. Die Prüfung beweist die getestete Payload-Konstruktion, nicht das Verhalten einer realen Providerverbindung oder sämtlicher Meetinginhalte.

### 13.3 Manuelle und private Langzeittests

Ergebnisse, reale Meetingbeobachtungen und sensible Umgebungsdetails werden ausschließlich in `TESTING_4_1.md` gesammelt. Der öffentliche Plan hält nur anonymisierte Gateergebnisse fest.

**Anonymisierter Zwischenstand 23. September 2026:** Ein beaufsichtigter Mixed-/Offline-/Lokal-Lauf erreichte 298,4 Sekunden Originalaudio je Spur und wurde mit beiden lesbaren, transkribierten Tracks abgeschlossen. Das Manifest meldet null Gaps, null Clipping, null verlorene Buffer und gute Synchronisierung; die Projektion enthält Sprecherblöcke beider Rollen, deren Lesbarkeit bei Überlappung jedoch manuell beanstandet wurde. Sechs lesende Prozess-Stichproben während des Laufs zeigten keinen RAM-Anstieg (rund 28–41 MB RSS), belegen aber noch kein isoliertes Capture-RAM-Budget. Wegen 1,6 Sekunden Abstand zur 300-Sekunden-Schwelle bleibt das formale 5-Minuten-Zeit-Gate offen. Ein beobachteter Headset-Routing-Unterschied ist noch nicht reproduziert und bleibt als separates Geräte-Gate offen. Es wurden keine Transkript- oder Audioinhalte in den Plan übernommen.

**Headset-Nachtrag 24. September 2026:** Zwei Starts mit explizit ausgewähltem USB-Headset-Eingang lieferten innerhalb des Zwei-Sekunden-Startfensters keine Mikrofonbuffer; die Systemspur wurde jeweils als Folge abgebrochen. Nach einem sauber neu gestarteten, regulär signierten Debug-Build wurde ein kurzer Mixed-/Offline-/Lokal-Lauf mit demselben gespeicherten Eingang vollständig abgeschlossen: beide Tracks transkribiert, null Gaps, null Clipping, null verlorene Buffer, gute Synchronisierung. Ein weiterer kurzer Start scheiterte danach identisch, der unmittelbar folgende Take wurde wieder mit beiden Tracks abgeschlossen. Der Mikrofonstartfehler ist somit intermittierend; ein Zusammenhang mit dem Wechsel des Ausgabegeräts ist noch nicht bewiesen. Headset-Langlauf und Geräte-Gate bleiben bis zur Eingrenzung offen. Für reale Test-Builds die Projekt-Signierung beibehalten; ein zwischendurch ohne App-Signierung gebauter Debug-Build trug nicht die vorgesehene ausführbare App-Kennung und erkannte den gespeicherten Aufnahmeordner nicht.

**Routing-Gegenprobe 24. September 2026:** Bei fest ausgewähltem USB-Headset-Mikrofon meldet der manuelle A/B-Test einen erfolgreichen Mixed-Start mit Mac-Lautsprechern, aber wiederholte Startfehler mit AirPods beziehungsweise Headset als Wiedergabe. Das Manifest bestätigt für die fehlgeschlagenen Starts `audioDevice`/keinen ersten Mikrofonbuffer und für die Gegenprobe beide transkribierten Tracks. Da Mixed Capture Mikrofon-Engine und System-Tap gleichzeitig startet, muss ein Mikrofon-only-Test bei externer Ausgabe noch zwischen isoliertem Eingabeproblem und Wechselwirkung beider Recorder unterscheiden. Bis dahin kein Headset-Langlauf und keine Änderung der Start-Timeouts auf Verdacht.

**Mikrofon-only-Gegenprobe 24. September 2026:** Mit demselben Headset-Eingang und externer Ausgabe startete die alleinige Mikrofonaufnahme scheinbar, schrieb jedoch nur einen WAV-Header (0 Audiobytes, 0 Sekunden Audio). Erst der lokale Provider meldete anschließend „mindestens 300 ms Audio“. Damit ist die Wechselwirkung mit dem System-Tap als notwendige Ursache ausgeschlossen: Schon der gemeinsame AVAudioEngine-Eingabepfad liefert bei dieser Route keine Buffer. Der 4.0-Mikrofonpfad muss fehlende Samples vor der Transkription erkennen; die eigentliche externe Ausgabe-/Eingabe-Kompatibilität benötigt eine gesondert getestete Capture-Korrektur. Das Headset-Geräte-Gate und alle darauf aufbauenden Langläufe bleiben offen.

**Capture-Korrektur, reale Abnahme noch offen:** Bei explizit gewähltem Eingabegerät verwenden Mikrofon-only und Mixed-Mikrofonspur nun eine input-only Core-Audio-HAL-Unit statt eines an die Ausgaberoute gekoppelten AVAudioEngine-Graphen. Der Systemaudiopfad bleibt unverändert; ohne explizite Mikrofonwahl bleibt der bisherige Engine-Pfad. Mikrofon-only verlangt vor dem erfolgreichen Start einen tatsächlich geschriebenen Audiobuffer und berechnet die Aufnahmedauer aus geschriebenen PCM-Frames statt aus Wall Clock. So gelangt eine leere Datei nicht mehr als scheinbar ausreichend lange Aufnahme zum lokalen Modell. Ein neuer Regressionstest für Null-Frames und exakte Audiodauer besteht; die vollständige serielle Suite besteht mit 203/203 Tests. Der regulär signierte universelle Debug-Build (`arm64 x86_64`, `de.euler.FlowDictate`) kompiliert. Ob die neue Eingaberoute mit AirPods und Headset-Ausgabe tatsächlich funktioniert, muss am Test-Build manuell nachgewiesen werden; das Geräte-Gate bleibt bis dahin offen.

**HAL-Nachkorrektur:** Der erste reale AirPods-Gegenversuch erreichte den input-only Callback, aber `AudioUnitRender` wies die übergebene Bufferliste mit Core-Audio-Status `-50` (ungültiger Parameter) ab. Der neu angelegte `AVAudioPCMBuffer` hatte vor dem Renderaufruf `mDataByteSize = 0`; die Frame-Länge wird nun vor dem Rendern gesetzt. Ein gezielter Test prüft die Bytezahl für mono und stereo; die vollständige serielle Suite besteht mit 204/204 Tests. Ein erneuter realer Gegenversuch ist weiterhin erforderlich; weder AirPods- noch Headset-Ausgabe ist damit bereits freigegeben.

**Zweite HAL-Nachkorrektur:** Nach der Pufferkorrektur meldete der reale Start `-10863` (`kAudioUnitErr_CannotDoInCurrentContext`). Eine lesende Gerätekonfigurationsprüfung zeigte den konkreten Formatwiderspruch: Die gewählte Plantronics-Eingabespur läuft mit 48 kHz/Mono, während der vor der Konfiguration abgefragte HAL-Ausgabebus 44,1 kHz/Stereo meldete. Der HAL-Aufnahmepfad liest nun das Format vom Eingabebus und stellt damit den Render-Ausgabebus ein. Ein einzelner vorübergehend nicht ausführbarer Renderzyklus wird ohne Warten im Echtzeit-Callback ausgelassen; der vorhandene First-Buffer-Timeout fängt anhaltenden Audioausfall ab. Vollständige serielle Suite: 204/204 Tests bestanden. Reale AirPods-/Headset-Abnahme noch offen.

**Reale Mikrofon-Gegenprobe und Einfügefolge:** Mit dem korrigierten input-only HAL-Pfad gelangen mehrere kurze Mikrofonaufnahmen bei externer Ausgabe: die letzte enthielt 6,603 Sekunden mono Float32 bei 48 kHz, war lokal transkribiert und als Audio vollständig lesbar. Die Einfügung in Word gelang über den vorhandenen Clipboard-Pfad. Beim ChatGPT-Ziel (`com.openai.codex`) meldete die direkte Accessibility-Schreiboperation dagegen Erfolg, ohne Text im Composer anzuzeigen; auch `Restore Last Dictation` lief über denselben Pfad und zeigte nichts. Manuelles `Copy Final` plus Einfügen per Tastatur wurde vom Nutzer bestätigt. Die automatische Zielauswahl verwendet nun nur für ChatGPT wie für Word den Clipboard-Pfad; andere Anwendungen behalten Accessibility zuerst. Ein Routingtest sichert ChatGPT-Clipboard und unverändertes TextEdit-Verhalten, vollständige serielle Suite 205/205 bestanden. Die reale ChatGPT-Einfügung mit neuem Build sowie Mixed mit externer Ausgabe stehen noch aus.

**ChatGPT-Restore-Nachtrag:** Der erste reale Menü-Restore mit ChatGPT-Clipboard-Routing zeigte weiterhin keinen Text. Das Log bestätigte Zielkennung, Clipboard-Schreibvorgang, gesendeten Paste-Shortcut und Wiederherstellung der Zwischenablage nach rund 0,7 Sekunden, aber keinen Nachweis, dass der Editor Paste verarbeitet hatte. Der zuletzt gespeicherte Diktatinhalt stammte aus Mail; Restore hatte dennoch ChatGPT als aktuelles Ziel gewählt, was korrekt ist. Ein separater Versuch mit dem voreingestellten Restore-Kürzel ⌥⇧Z schrieb nur ein macOS-Zeichen in den Chat; das normale Diktierkürzel Option + Space funktioniert. Der Menü-Paste-Pfad wartet nun ausschließlich für ChatGPT kurz auf stabilen Fokus, richtet den Paste-Tastendruck direkt an dessen Prozess und hält den Text mindestens zwei Sekunden in der Zwischenablage. Andere Ziele bleiben unverändert. Die vollständige serielle Suite besteht weiter mit 205/205 Tests; reale Menü-Restore-Abnahme mit neuem Build bleibt offen.

**Restore-Kürzel-Nachtrag:** Der Nutzer hat die neue Diktat-Einfügung in ChatGPT und anschließend `Restore Last Dictation` über das Menü real bestätigt. Das Kürzel ⌥⇧Z löste Restore dagegen nicht aus und schrieb ein Zeichen. Die Ursache ist das aktive deutsche Tastaturlayout: Der bisherige feste Keycode `kVK_ANSI_Z` steht dort für die physische Y-Taste; die sichtbare Z-Taste hat Keycode 16. Die eingebauten Z-Presets werden nun aus dem aktiven Tastaturlayout ermittelt; gespeicherte eingebaute Presets werden beim Start entsprechend normalisiert, selbst aufgezeichnete Kürzel bleiben unverändert. Die reale Kürzel-Abnahme nach neuem Test-Build steht noch aus.

Der Nutzer bestätigte Restore mit ⌥⇧Y im alten Build und damit die physische Tastenverwechslung. Mit der Korrektur bestanden 206/206 Tests ohne Fehler, Skips oder Runtime-Warnungen; der signierte universelle Debug-Build (`x86_64 arm64`) wurde sauber als einzelne Instanz neu gestartet. Die Hotkey-Registrierung belegt nun die sichtbare deutsche Z-Taste und gibt die bisher verwendete physische Y-Taste frei. Nach erneutem sauberem Start bestätigte der Nutzer die tatsächliche Restore-Einfügung per ⌥⇧Z. Voraussetzung dafür ist eine gültige macOS-Accessibility-Freigabe für diesen Test-Build: Das Kürzel löst Restore aus, die anschließende ChatGPT-Einfügung sendet jedoch ein simuliertes Cmd+V-Ereignis und benötigt dafür die Berechtigung.

**Live-Preview-Nachtrag:** Bei einer normalen Mikrofonaufnahme erschien trotz aktivierter Einstellung und Standard-Overlay kein Vorschautext. Die reale Diagnose zeigte verfügbare lokale Erkennung (`de-DE`, Speech-Berechtigung vorhanden), aber in mehreren Aufnahmen jeweils `audioBuffers=0`. Ursache: Der neue Mikrofon-Sink übernahm den Preview-Callback beim Recorder-Start, während `startRecorderWithPreview()` ihn absichtlich erst nach stabilem Audio-Start setzte; die spätere Änderung erreichte den laufenden Sink nicht. Der Callback wird nun beim Setzen oder Entfernen threadsicher an den aktiven Sink weitergegeben. Ein Regressionstest deckt genau das nachträgliche Aktivieren und Entfernen ab; vollständige Suite 207/207 bestanden, 0 Fehler, 0 Skips, 0 Runtime-Warnungen. Der signierte universelle Debug-Build läuft als einzelne neue Instanz. Die reale Vorschau bei einer erneuten Mikrofonaufnahme steht noch aus.

**Nachweis und Performance-Nachtrag:** Der Nutzer bestätigte Live Preview bei normaler Mikrofonaufnahme. Bei den zwei darauffolgenden Vorgängen war die Verarbeitung ungewöhnlich langsam: Vorletztes Diktat 7,7 Sekunden Audio und rund 42 Sekunden bis „Inserted“; letztes Diktat 10,1 Sekunden Audio, rund 69,6 Sekunden Wartezeit bis zum Jobstart, danach 0,47 Sekunden lokale Transkription. Dessen automatischer Insert scheiterte mit „Ziel-App nicht verfügbar“; der Nutzer erklärte, dass der Cursor nicht mehr im Eingabefeld war. Der spätere Restore benötigte rund 24 Sekunden bis zum Paste-Ereignis. Ein um 20 Sekunden verspäteter Overlay-Timer deutete zusätzlich auf blockierte oder stark verzögerte UI-Ausführung; ein Mac-Ruhezustand war nicht erkennbar. Die Preview-Zufuhr zu Apples Spracherkennung läuft nun auf einem eigenen Actor statt auf dem Main Actor; History- und Job-Dateizugriffe erhalten für den interaktiven Pfad `userInitiated`-Priorität. Neue Zeitmarken trennen nach Aufnahmeende History-Persistenz, Joberstellung, Queue-Commit und beim Paste Modifikatorfreigabe, Aktivierung und Fokus-Settle. Die vollständige Suite besteht mit 207/207 Tests; der signierte universelle Debug-Test-Build wurde als einzelne Instanz neu gestartet. Die reale Latenz-Abnahme mit fokussiertem Zieleingabefeld steht noch aus.

**Latenz-Gegenprobe:** Zwei normale Mikrofon-Diktate mit aktivierter Vorschau und fokussiertem ChatGPT-Ziel wurden eingefügt. Beim ersten waren Aufnahmefinalisierung (0,07 s), History/Queue-Übergabe (0,15 s), Queue-Wartezeit (0,42 s) und lokale Transkription (1,37 s) schnell; der Clipboard-Insert selbst dauerte jedoch 23,20 s. Modifikatorfreigabe, Zielaktivierung und Fokus-Settle benötigten zusammen nur rund 0,27 s. Beim zweiten lag derselbe Insert bei 0,30 s und die gesamte Jobinteraktion bei 0,84 s. Entgegen dem UI-Eindruck war der erste „Inserted“-Banner laut Zeitstempeln nur 0,36 s sichtbar; der Hänger lag davor. Die aktuelle Zwischenablage hatte lediglich einen kurzen Text, der beim separaten Nachlesen in rund 10 ms verfügbar war. Der verbliebene sporadische Hänger wird nun zusätzlich direkt um Snapshot, Clipboard-Schreiben und Paste-Event-Posting gemessen; das enthält keine Textinhalte. 207/207 Tests bestanden, neuer signierter universeller Debug-Build als einzelne Instanz gestartet. Der nächste reale Vorgang muss zeigen, welche Unteroperation gegebenenfalls blockiert.

**Dreifach-Gegenprobe:** Der Nutzer führte drei weitere Aufnahmen aus; die zweite war zu kurz und wird für die Latenzbewertung ignoriert. Erste gültige Aufnahme: 8,06 s Audio, 0,09 s History/Queue-Übergabe, Jobstart rund 0,12 s nach Stopp, 0,70 s lokale Transkription, 0,34 s Insert; vom Stopp bis zum gesendeten Paste-Ereignis rund 1,20 s. Dritte gültige Aufnahme: 5,78 s Audio, 0,12 s History/Queue-Übergabe, Jobstart rund 0,09 s nach Stopp, 0,24 s Transkription, 0,30 s Insert; vom Stopp bis Paste rund 0,66 s. Die differenzierten Clipboard-Phasen lagen bei beiden im Millisekundenbereich, und der „Inserted“-Banner wurde jeweils nach rund 0,37 s ausgeblendet. Die `started after waiting`-Meldung überschätzt sub-sekündige Queue-Zeiten, weil persistierte ISO-8601-Jobzeitstempel die Nachkommastellen verlieren; hier gelten die tatsächlichen Log-Zeitstempel. Die frühere 23-s-Spitze trat nicht erneut auf. Intermittierende Insert-Latenz bleibt bis zu weiterer realer Beobachtung offen; die Zeitmarken erlauben beim nächsten Auftreten eine eindeutige Unterphasen-Zuordnung.

**Kurze Mixed-Gegenprobe nach Capture-Fixes:** Der Nutzer bestätigte einen kurzen Mixed-Lauf mit Plantronics-Mikrofon und externer Ausgabe sowie lesbaren Sprecherabschnitten einschließlich markierter Überlappung. Das autoritative Sessionmanifest hält `offline`/`local`, Status `completed`, beide transkribierten 48-kHz-Mono-Originalspuren mit 5,10 s und 5,14 s, null Gaps, null verlorenen Buffern, null Clipping und gute Synchronisierung fest. Ein vorheriger nur 0,38 s langer Mixed-Take wurde für die Geräteabnahme nicht gewertet. Die kurze Geräte-Gegenprobe ist bestanden; das formale 300-s-Mixed-Gate und längere Performance-/Recovery-Nachweise bleiben offen.

**Realer Mixed-Fünf-Minuten-Lauf 24. September 2026:** Der Nutzer nahm mit externer Mikrofoneingabe und externer Audioausgabe auf; die App wurde dabei nur lesend beobachtet. Die Offline-/Lokal-Session wurde vollständig abgeschlossen und eingefügt. Beide getrennten 48-kHz-Mono-Originalspuren wurden transkribiert; ihre Dauer beträgt 339,008 s (Mikrofon) und 339,051 s (Systemaudio). Es gab auf beiden Spuren null Gaps und null verlorene Buffer; die Synchronisierung ist `good` bei 0 ms initialem Versatz. Der beobachtete App-RSS lag während des Laufs zwischen rund 30 und 42 MB, ohne sichtbaren Anstieg proportional zur Aufnahmedauer; daraus allein folgt noch kein Langzeit-Performancebestehen. Die Mikrofonspur meldete früh Clipping und im Abschlussmanifest 659 geclippte Frames (bei 48 kHz rund 13,7 ms), die Systemspur null. Damit sind die 300-s-Dauer und der Zwei-Spur-Erhalt real nachgewiesen. Das Null-Clipping-Ziel wurde nicht erreicht; Produktwirkung ist ein potenziell kurzer hörbarer Artefakt in der Mikrofonspur, nicht Trackverlust oder Sync-Ausfall. Der Nutzer hat diese gemessene Abweichung für den Fünf-Minuten-Test ausdrücklich akzeptiert und keinen Wiederholungslauf gewünscht. Das ist eine dokumentierte Ausnahme, kein stillschweigendes Bestehen des Null-Clipping-Ziels; 30-/60-/120-Minuten-, Netzwerk-, Low-Disk- und weitere Performance-Gates bleiben offen. Es wurden keine Audio- oder Transkriptinhalte dokumentiert.

**Pegel-Gegentest:** Ein weiterer Offline-/Lokal-Mixed-Take mit 22,09 s Mikrofon- und 22,14 s Systemaudiodauer wurde mit beiden transkribierten Spuren und abgeschlossener Einfügung beendet. Der angepasste Mikrofonpegel erzeugte 0 Clipping-Frames und 0 verlorene Buffer; der Peak lag jedoch nur bei 0,107 und die Verständlichkeit muss vom Nutzer beurteilt werden. Die Systemspur hatte ebenfalls 0 Clipping-Frames, aber einen verlorenen Buffer beziehungsweise eine 21-ms-Lücke bei 20,555–20,576 s; die Synchronisierung wurde deshalb als `degraded` eingestuft. Der kurze Test belegt, dass das Mikrofon ohne Clipping betrieben werden kann, ist aber wegen der Systemlücke kein vollständiger Qualitätsnachweis. Der Nutzer akzeptiert den vorangegangenen Fünf-Minuten-Lauf ausdrücklich ohne Wiederholung; die kurze Systemlücke bleibt als separater Befund für spätere Langläufe. Es wurden keine Audio- oder Transkriptinhalte gelesen oder dokumentiert.

**Clipping-Warnungs-UX:** Der Nutzer meldete, dass die Mikrofon-Clipping-Warnung im Fünf-Minuten-Lauf trotz nur früher Übersteuerung dauerhaft sichtbar blieb. Ursache waren eine einmalige Clipping-Meldung pro Recorder und eine bis zum Stop persistierende Overlay-Liste. Mikrofon- und Systemaudio-Recorder melden Clipping jetzt während tatsächlicher neuer geclippter Frames höchstens einmal pro Sekunde; die sichtbare Warnung verschwindet fünf Sekunden nach dem letzten Ereignis. Erneutes oder anhaltendes Clipping verlängert beziehungsweise erneuert sie. Trackverlust-, Writer- und Speichermangelwarnungen bleiben dauerhaft sichtbar; die im Manifest und in der History gespeicherte Clipping-Metrik wird nicht gelöscht. Der deterministische Zustands-/Ablauftest und die vollständige Suite bestanden mit 208/208 Tests, 0 Fehlern und 0 Skips. Nach erneutem kontrolliertem Start des signierten universellen Debug-Builds bestätigte der Nutzer auch die reale Overlay-Abnahme: Die eingeblendete Clipping-Warnung verschwand während der laufenden Mixed-Aufnahme wie vorgesehen. Die Debug-Anzeigeaktion verändert keine Audio- oder Qualitätsmetriken; erneutes beziehungsweise dauerhaftes echtes Clipping ist durch die Ereignis- und Ablaufregression abgesichert, nicht durch diesen Anzeigeversuch.

**Realer Offline-Netzwerk-Gegenlauf 24. September 2026:** Bei bestehender Internetverbindung schloss ein kurzer Mixed-Take mit eingefrorenem `offline`-/`local`-Profil beide getrennten Spuren, lokale Transkription und Einfügung erfolgreich ab (rund 15,2 s je Spur). Im auf den App-Prozess begrenzten Logfenster erschien kein OpenAI-Upload-Marker; die automatisierte HTTP-Policy-Integration blockiert Uploads für diesen Modus bereits vor der Providerauflösung. Die zusätzliche prozessbezogene externe Byte-Zählung lieferte beim Beenden keine verwertbaren Messzeilen und wird deshalb ausdrücklich **nicht** als OS-seitiger Null-Traffic-Nachweis gewertet. Das formale reale Netzwerkgate bleibt bis zu einem belastbaren Gegenlauf mit positiver Cloud-Kontrolle offen. Qualitätsmetadaten: null Clipping, zwei kurze Systemaudio-Gaps mit insgesamt 33 ms und zwei verlorene Systemaudio-Buffer; das ist unabhängig vom Netzwerkbefund. Keine Inhalte oder Zugangsdaten wurden gelesen oder dokumentiert.

**Realer Cloud-Netzwerk-Gegenlauf:** Nach kontrolliertem Test-Build-Neustart schloss ein neuer kurzer Mixed-Take mit eingefrorenem `cloudTranscription`-/`openai`-Profil beide Spuren und die Einfügung erfolgreich ab (23,3 s je Spur, gute Synchronisierung, null Gaps, null Clipping und null verlorene Buffer). Das App-Log dokumentiert genau zwei Audio-Uploads mit 293.278 und 348.969 vorbereiteten Audiobytes sowie für beide eine erfolgreiche Transkriptionsantwort. Die auf genau diesen App-Prozess und externe Interfaces begrenzte Byte-Zählung zeigte dazu zwei deutliche ausgehende Datenbursts von 330.834 und 354.342 Bytes sowie kleine Protokoll-/Antwortmengen. Damit ist der reale Cloudpfad positiv nachgewiesen; die Messung enthält weder Zieladressen noch Audio-/Textinhalt oder Zugangsdaten. Dieser Lauf dient zugleich als positive Kontrolle für die nachfolgende Offline-Messung.

**Realer Offline-Netzwerknachweis mit positiver Kontrolle:** Nach erneutem kontrolliertem Start des signierten Debug-Builds schloss ein weiterer Mixed-Take mit `offline`/`local` beide Spuren, lokale Transkription und Einfügung ab (11,9 s je Spur, gute Synchronisierung, null Gaps, null Clipping und null verlorene Buffer). Bei weiterhin erreichbarem Netzwerk wurde genau der App-Prozess auf externen Interfaces über 90 natürliche Ein-Sekunden-Messintervalle beobachtet: Es gab keinen externen Prozess-Socket und keinen Byte-Zähler. Im zugehörigen App-Log gab es keinen Upload-Marker. Derselbe Monitor hatte unmittelbar zuvor beim `cloudTranscription`-/`openai`-Gegenlauf zwei korrespondierende ausgehende Upload-Bursts erfasst. Zusammen mit dem Policy-Integrationstest ist der reale Netzwerkpfad des Debug-Builds für diese beiden Modi damit **bestanden**. Die Beobachtung gilt für die getesteten kurzen Sessions und ersetzt nicht die erneute Release-Abnahme mit der finalen ZIP-App oder eine absolute Aussage über sämtliche künftigen Codepfade. Keine Inhalte, Zieladressen oder Zugangsdaten wurden gelesen oder dokumentiert.

**Isolierter Real-Low-Disk-Nachweis:** Auf einem eigens erstellten, auf 128 MB begrenzten und anschließend vollständig entfernten Test-Volume wurde die produktive Mixed-Startsicherung mit echten Dateisystemwerten geprüft: Unter 500 MB erschien die Warnung, ein erster Start über 50 MB gelang, unter 50 MB wurde der nächste Start vor dem Anlegen von Trackartefakten blockiert. Danach füllte ein echter CAF-Writer ausschließlich dieses Volume bis zum Schreibfehler; die angelegte Originaldatei blieb erhalten und die spurbezogene Writerwarnung wurde gemeldet. Der erste Lauf zeigte einen Produktfehler in der Fehlerklassifikation: `AVAudioFile` gab auf dem vollen Volume einen generischen Core-Audio-Fehler `-40` statt eines verschachtelten POSIX-`ENOSPC` zurück, weshalb `storageFull` zunächst nicht erkannt wurde. Die Klassifikation prüft nun bei einem Writerfehler zusätzlich den freien Platz **auf dessen eigenem Volume** und leitet Platzmangel nur unter 1 MiB ab; ein generischer Fehler auf einem gesunden Volume bleibt unverändert. Der erneute reale Lauf bestand zusammen mit der gesamten Suite: 209/209 Tests, 0 Fehler, 0 Skips. Das normale Aufnahme-Volume wurde weder gefüllt noch umgestellt. Der regulär signierte universelle Debug-Build (`arm64 x86_64`, `de.euler.FlowDictate`) wurde mit der Korrektur gebaut und als einzelne Instanz kontrolliert neu gestartet.

**Realer 30-Minuten-Mixed-Lauf 24. September 2026 — beendet, ohne Wiederholung:** Der Nutzer schloss eine Offline-/Lokal-Aufnahme mit beiden getrennten Originalspuren nach 30:44 Minuten erfolgreich ab; beide Spuren wurden transkribiert und die Einfügung abgeschlossen. Die Mikrofonspur hatte null Gaps und null verlorene Buffer, aber 127 Clipping-Frames (rund 2,6 ms). Die Systemspur hatte vier kurze Gaps und vier verlorene Buffer mit zusammen 65 ms (27/13/13/12 ms), ohne Clipping. Zeitlich korrespondierende Core-Audio-Overload-Meldungen wurden beobachtet; eine Ursache ist damit nicht bewiesen. Die Synchronisierungsqualität ist wegen der Gaps `degraded`, und ein Driftwert wurde nicht ermittelt. Der Nutzer hat den 30-Minuten-Test ausdrücklich als beendet erklärt und wünscht weder Wiederholung noch zusätzliche Untersuchungsschleife an dieser Stelle. Damit ist der Dauer- und Zwei-Spur-Erhalt nachgewiesen, **nicht** das Null-Bufferverlust-Ziel oder ein vollständiger 30-Minuten-RAM-Nachweis. Die realen 60- und 120-Minuten-Läufe bleiben vorgesehen. Es wurden keine Audio- oder Transkriptinhalte dokumentiert.

**Realer 60-Minuten-Mixed-Lauf 25. September 2026 — durchgeführt:** Die Offline-/Lokal-Aufnahme erreichte 61:59 Minuten je getrennter 48-kHz-Mono-Originalspur; beide Spuren wurden transkribiert, die Einfügung wurde abgeschlossen und kein Track ging verloren. Die Mikrofonspur meldet null Gaps, null verlorene Buffer und null Clipping. Die Systemspur meldet zwei Gaps und zwei verlorene Buffer bei 27:28 und 28:08 Minuten mit zusammen 33 ms (15/18 ms), ebenfalls null Clipping. Jeweils zeitgleiche Core-Audio-Meldungen über ausgelassene I/O-Zyklen durch Überlastung korrelieren mit den Lücken, beweisen aber noch keine Ursache. Deshalb ist die Synchronisierung `degraded`; ein Driftwert wurde nicht ermittelt. Die minutengenauen, inhaltsfreien Prozess-Stichproben zeigten während Capture rund 29–62 MB RSS ohne mit der Aufnahmedauer wachsendes Muster; beim Übergang zur lokalen Transkription stieg RSS auf rund 180 MB. Der Dauer- und Zwei-Spur-Erhalt sowie der unauffällige Capture-RAM-Verlauf sind damit nachgewiesen, **nicht** das Null-Bufferverlust-Ziel. Für diese Abweichung liegt noch keine ausdrückliche Freigabe als Release-Einschränkung vor. Es wird kein zusätzlicher Wiederholungstest angesetzt; der geplante 120-Minuten-Lauf bleibt der nächste Langzeitschritt. Es wurden keine Audio- oder Transkriptinhalte dokumentiert.

**Kurze Sprechertrennungs-Gegenprobe nach geändertem Aufbau:** Der Nutzer meldete im 60-Minuten-Transkript zeitweise unsaubere Zuordnung und nahm anschließend einen 36,4-s-Mixed-/Offline-/Lokal-Take mit anderem Aufbau auf. Beide Originalspuren wurden ohne Gaps, Bufferverlust oder Clipping transkribiert und eingefügt; die Synchronisierung ist `good`. Die kurzen eigenen Äußerungen wurden ausschließlich dem Mikrofon-/`You`-Track zugeordnet, die Wiedergabesprache ausschließlich dem Systemaudio-Track; die tatsächliche zeitliche Überlappung wurde markiert. Ein Pegelvergleich in getrennten Sprechfenstern zeigte auf der Mikrofonspur ungefähr −35 dB Mittelpegel bei eigener Sprache gegenüber −82 dB bei alleiniger Systemwiedergabe; auf der Systemspur ungefähr −30 dB bei Wiedergabe gegenüber −91 dB bei alleiniger eigener Sprache. Dieser kurze Lauf belegt eine saubere **Trackzuordnung** mit dem neuen Aufbau, aber weder die Ursache der vorherigen Beanstandung noch die Qualität eines längeren Laufs. Die lesbare Textprojektion hat einen separaten Befund: Ein Systemaudio-Block reicht über rund 24,4 s und wird vor einer darin zeitlich liegenden `You`-Äußerung ausgegeben; am Ende steht nach einer rund viersekündigen Pause ein einzelnes Systemaudio-Wort als eigener Block. Die Überlappungsmarkierung gilt für den ganzen Block, obwohl nur ein Teil gleichzeitig gesprochen wurde. Die Wort-Zeitachse ist korrekt sortiert, aber diese blockweise Darstellung kann die wahrgenommene Sprecherreihenfolge verzerren und wirkt unterschiedlich kleinteilig. Ursache ist die aktuelle Turn-Gruppierung mit 800-ms-Pausengrenze, 15-s-Satzgrenzenpräferenz und 45-s-Hardlimit, nicht eine nachgewiesene falsche Audioquelle. Audio- und Transkriptinhalte wurden nicht in den Plan übernommen.

**Realer 120-Minuten-Mixed-Lauf 25. September 2026 — Capture abgeschlossen, Verarbeitung partiell:** Der Nutzer wählte Plantronics auch als Ausgabegerät; das Sessionmanifest speichert die physische Ausgaberoute nicht separat. Die Offline-/Lokal-Aufnahme erreichte 121:17 Minuten je getrennter 48-kHz-Mono-Originalspur; beide Dateien sind erhalten. Die inhaltsfreien Minuten-Stichproben zeigten während Capture rund 26–54 MB App-RSS ohne mit der Audiodauer wachsendes Muster. Die Mikrofonspur hatte null Gaps und null verlorene Buffer, jedoch 138 Clipping-Frames (rund 2,9 ms). Die Systemspur hatte elf Gaps und elf verlorene Buffer mit zusammen 422 ms; die Synchronisierung ist `degraded`, ein Driftwert wurde nicht ermittelt. Mehrere Core-Audio-Überlastmeldungen liegen zeitlich bei den Lücken, ohne eine Ursache zu beweisen. Alle acht Systemaudio-Segmente wurden lokal transkribiert. Auf der Mikrofonspur blieb Segment 1/8 erfolgreich persistiert; Segment 2/8 (ungefähr Minute 15–30) lieferte keinen Text und wurde als `providerPermanent` fehlklassifiziert, die übrigen sechs Segmente wurden deshalb nicht versucht. Die originale Mikrofonspur ist intakt. Im betroffenen Segment betrug der Mittelpegel rund −85,5 dB und der Spitzenpegel nur rund −61,1 dB; die Leerstelle ist damit plausibel, aber der Abbruch der gesamten Restverarbeitung ist ein Produktfehler. Die Session steht auf `partial`, ohne vollständige Merge-/Einfügefreigabe. Die 120-Minuten-Dauer, der Zwei-Spur-Erhalt und der unauffällige Capture-RAM-Verlauf sind nachgewiesen; **Null-Bufferverlust und vollständige End-to-End-Verarbeitung sind nicht bestanden**. Eine erneute zweistündige Aufnahme wird daraus nicht angesetzt; Wiederaufnahme aus den erhaltenen Originalen nach Korrektur der Leersegmentbehandlung bleibt offen. Audio- und Transkriptinhalte wurden nicht dokumentiert.

**Korrektur der Leersegment- und Textblockbehandlung:** Nach einer leeren Providerantwort wird ein Long-Form-Segment nur dann als `silent` abgeschlossen, wenn alle Samples des zugehörigen Originalabschnitts unter der bereits für Capture verwendeten Stille-Schwelle liegen. Dieser Zustand wird persistiert, zählt zum Fortschritt und wird nach Restart nicht erneut transkribiert; hörbare Abschnitte mit leerer Antwort bleiben sichtbare Fehler. Der Merge lässt stille Segmente aus, ohne Sprache vor und nach einer Stille zu deduplizieren; eine ganz stille Mikrofonspur blockiert vorhandene Systemaudiosprache nicht. Die lesbare Meeting-Projektion trennt lange wortpräzise Sprecherblöcke an Einsätzen und Enden der Gegenspur, erhält sehr kurze Äußerungen zusammen und begrenzt diese Blöcke auf höchstens 20 s; die präzise Wort-Zeitachse bleibt unverändert. Das letzte isolierte Wort einer Quelle darf nach einer echten mehrsekündigen Pause weiterhin als eigener Block erscheinen, damit die zeitliche Reihenfolge nicht verfälscht wird. Vollständige serielle Regression: 212/212 Tests bestanden, 0 Fehler, 0 Skips, keine Runtime-Warnungen. Der regulär signierte universelle Debug-Build (`arm64 x86_64`, `de.euler.FlowDictate`) wurde als einzelne Instanz kontrolliert neu gestartet. Die reale Wiederaufnahme der erhaltenen 120-Minuten-Session und die sichtbare Abnahme der neuen Blockdarstellung stehen noch aus; ein neuer Langlauf ist dafür nicht angesetzt.

**120-Minuten-Recovery und neuer Timeline-Befund:** Der Nutzer setzte die erhaltene Session erfolgreich fort; beide Spuren und der Meeting-Merge standen zunächst auf `completed`. Die fertigen Trackartefakte enthielten jedoch jeweils null `timedEntries`; der Merge musste deshalb beide vollständigen Spuren als je einen `trackChunk` über die gesamte Dauer behandeln. So erschienen alle `You`-Beiträge vor dem Systemaudio-Block. Das war eine fehlende Zeitachse, keine nachgewiesene falsche Trackzuordnung. Ursache: Die lokale Transkription liefert Wort-Zeitmarken pro 15-Minuten-Segment, aber die Long-Form-Strecke übernahm sie nicht und löschte nach erfolgreichem Merge ihr Segmentmanifest. Korrektur: Segment-Zeitmarken werden nun persistiert, auf die Originalspurzeit abgebildet, beim Meeting in wortpräzise Einträge übernommen und für Crash-/Restart-Recovery bis zum Speichern des Trackartefakts erhalten. Provider ohne Wortzeiten erhalten nur echte Segmentintervalle, keine erfundenen Wortzeiten. Die vollständige serielle Suite bestand zu diesem Zeitpunkt mit 213/213 Tests, 0 Fehlern und 0 Skips. Die chronologische Neubildung des erhaltenen Takes erfordert eine erneute Verarbeitung der Originalspuren, aber keine neue Aufnahme.

**Reale chronologische Neuverarbeitung:** Nach ausdrücklicher Zustimmung des Nutzers wurden die fünf bisherigen JSON-Ergebnisse bitgleich und ohne Audioduplikate separat gesichert. Die Originalspuren blieben unverändert. Die Mikrofonspur wurde erfolgreich neu verarbeitet und enthält 207 echte Wort-Zeitmarken. Alle acht Systemaudio-Segmente wurden ebenfalls neu transkribiert und samt Wortzeiten persistiert; beim Übernehmen in das Trackartefakt fiel eine einzelne rückwärts laufende Zeitmarke an einer 1,5-s-Segmentüberlappung auf. Der Sessionstatus ist daher derzeit `partial`, nicht abgeschlossen. Die Filterung übernimmt nun nur Wörter, die auf der neuen Seite der Segmentgrenze beginnen. Am realen gespeicherten Manifest ergeben sich damit 22.309 gültige Systemaudio-Wortzeiten, null rückwärts laufende und null außerhalb der Spur. Die serielle Suite besteht mit 214/214 Tests, 0 Fehlern und 0 Skips; der signierte universelle Debug-Build wurde als einzige Instanz kontrolliert neu gestartet. Die erneute Finalisierung des bereits transkribierten Systemtracks über `Retry Failed Track` und die sichtbare Lesbarkeitsabnahme stehen noch aus; keine neue Transkription oder Aufnahme ist dafür nötig.

**Erster Remerge und Feinbefund:** Nach `Retry Failed Track` erreichte dieselbe Session `completed` mit 18.920 Timeline-Einträgen beider Rollen und 315 lesbaren Blöcken statt der früheren zwei Ganzspur-Blöcke. Ein Systemaudio-Segment blieb jedoch als ein grober `segment`-Block stehen, weil genau eine Provider-Wort-Endzeit das reale Segmentende um 47 ms überschritt; der bisherige Alles-oder-nichts-Validator verwarf dadurch die übrigen 3.598 gültigen Wortzeiten dieses Segments. Die Übernahme begrenzt jetzt kleine End-Rundungsüberhänge auf das echte Segmentende und behält die übrigen gültigen Worteinträge. Regression und vollständige Suite bestehen mit 214/214 Tests, 0 Fehlern und 0 Skips. Der bereits abgeschlossene Zwischenstand wurde separat bitgleich gesichert; die Session ist gezielt für einen erneuten gecachten Systemtrack-Remerge auf `partial` gesetzt und der neue signierte universelle Debug-Build läuft als einzige Instanz. Der Nutzer muss `Retry Failed Track` noch auslösen; erst danach ist die sichtbare Enddarstellung zu bewerten. Originalaudio und acht persistierte Systemaudio-Transkriptionssegmente bleiben unverändert.

**Finaler gecachter Remerge:** Der Nutzer löste `Retry Failed Track` erneut aus. Session und History stehen wieder auf `completed`, beide Tracks auf `transcribed`, ohne Fehlermeldung. Die neu gespeicherte Timeline enthält 22.516 ausschließlich wortpräzise Einträge (207 Mikrofon, 22.309 Systemaudio), null `segment`- oder `trackChunk`-Einträge und 368 lesbare Blöcke. Davon sind 14 `You`- und 354 Systemaudio-Blöcke; die Rollen wechseln 22-mal über den Take statt einmal zwischen zwei Ganzspur-Blöcken. Der finale Sessiontext stimmt mit dem gerenderten Timeline-Text überein. Die technische Ursache der ursprünglichen Darstellungsreihenfolge ist damit für diesen erhaltenen Take behoben. Der Nutzer bestätigte anschließend in der App, dass seine Beiträge an den passenden Stellen zwischen den Systemaudio-Blöcken erscheinen. Damit ist die sichtbare chronologische Sprecherreihenfolge dieses Takes abgenommen; die allgemeine Wort- und Sprechererkennungsgenauigkeit folgt daraus nicht. Die zwei privaten JSON-Sicherungen und beide Originalspuren wurden nicht entfernt.

**4.1.7-Qualitätsbilanz nach den Langläufen:** Die drei erhaltenen Sessionmanifeste zeigen positive Sample-Zeitsprünge ausschließlich auf der Systemspur: vier Gap-Ereignisse/65 ms bei 30 Minuten, zwei/33 ms bei 60 Minuten und elf/422 ms bei 120 Minuten; das längste einzelne Ereignis dauerte 137 ms. Die Zählung erfasst Diskontinuitäten, nicht zwingend die genaue Zahl der ausgefallenen Core-Audio-Callback-Buffer. Im 120-Minuten-Lauf entsprechen 422 ms rund 0,006 % der Systemspurzeit; ein einzelner 137-ms-Ausfall kann dennoch Sprache hörbar oder im Transkript relevant beschädigen. Beide Originalspuren blieben erhalten, Capture-RSS wuchs in den 60-/120-Minuten-Proben nicht proportional und die 120-Minuten-Verarbeitung war aus den Originalen wiederherstellbar. Das Nullverlust-Budget aus 13.4 ist damit **nicht bestanden**; Driftwerte und mehrere p95-/Main-Actor-Budgets bleiben **unbelegt**. Der Systemaudio-Callback konvertiert, schreibt und analysiert Buffer synchron; zeitnahe Core-Audio-Überlastmeldungen wurden während der Läufe beobachtet, aber weder diese Code-Stelle noch eine bestimmte Geräte-/Systemlast ist als Ursache nachgewiesen. Die alten OS-Logzeilen waren bei der Nachprüfung nicht mehr abrufbar. Vorläufige Engineering-Entscheidung: keine spekulative Umstellung des Echtzeitpfads und keine weitere lange Aufnahme allein wegen dieser kleinen, aber realen Lücken. Die Abweichung wird nicht als Release-Einschränkung freigegeben; Produktwirkung, Rest-Risiko und das finale ZIP-Gate benötigen vor Release eine ausdrückliche Entscheidung.

**Produktentscheidung zu den Systemaudio-Lücken:** Der Nutzer bewertet die kurzen Lücken der bisherigen 30-/60-/120-Minuten-Takes als vertretbare bekannte Einschränkung und nicht als Blocker für die weitere 4.1-Arbeit. Das gemessene Nullverlust-Budget bleibt formal verfehlt; die Einschränkung muss vor einer Freigabe öffentlich nachvollziehbar beschrieben werden. Es wird deswegen weder ein weiterer Langlauf noch ein spekulativer Umbau des Capture-Callbacks angesetzt. Als Nächstes folgen kurze Recovery- und Performance-Nachweise. Vor der finalen ZIP möchte der Nutzer einen installierten Build einige Tage im Alltag prüfen. Ob und wie dieser Praxistest das bisherige Gate „60/120 Minuten mit exakt der ZIP-App“ ersetzt, wird vor der Release-Abnahme ausdrücklich entschieden; das Gate ist bis dahin offen.

**Kurzer automatisierter Recovery-/Performance-Nachweis 25. September 2026:** Die vollständige serielle macOS-Testsuite bestand erneut mit 214/214 Tests, null Fehlern, null Skips und null Runtime-Warnungen. Darin bestanden die persistierte Restart-/Statusmatrix, Wiederherstellung einer intakten Spur bei beschädigter Gegenspur, History-Recovery, Restart nach erfolgreichen Segmenten beider Tracks für lokale und OpenAI-Verarbeitung, Merge-Artefakt-Retry sowie Stop-/Start-Rennen. Die Tests bestätigen außerdem, dass ein Stop-Befehl vor einer künstlich verzögerten Recorder-Finalisierung sichtbar `finalizing` setzt, und dass der Pegel-Gate höchstens zehn Updates pro Sekunde durchlässt. Das sind deterministische Funktionsnachweise, **keine** realen p95-Latenz-, Main-Actor- oder Force-Quit-End-to-End-Messungen. Die gespeicherten Sessionmanifeste enthalten keine Stop-/Finalisierungszeitpunkte; diese Werte lassen sich daraus nicht seriös nachträglich ableiten. Der anschließende kurze Realnachweis ist im nächsten Absatz beschrieben.

**Realer kurzer Force-Quit-/Restart-/Resume-Lauf 26. September 2026:** Der Nutzer startete eine neue Mixed-Aufnahme; während des Zustands `recording` wurde ausschließlich der laufende signierte Debug-App-Prozess gezielt beendet. Vor dem Neustart waren beide CAF-Originale vorhanden und lesbar (48 kHz, Mono, jeweils rund 45,9 s). Nach Start genau einer Instanz desselben Builds normalisierte Recovery die Session auf `paused` und beide Tracks auf `interrupted`. Der Nutzer löste `Continue Processing` in der History aus und bestätigte einen plausiblen generierten Text. Danach standen Session und verknüpfter History-Eintrag auf `completed`, beide Tracks auf `transcribed`; die Originale blieben erhalten, die gespeicherten Trackmetriken melden null Gaps und null Clipping. Die Einfügung ist nach dem Prozessabbruch erwartungsgemäß `deferred`, weil ein Ziel-Cursor nicht sicher wiederhergestellt werden kann. Die Synchronisierung ist konservativ `degraded`: Force Quit verhindert finale Timinganker und vollständige Capture-Qualitätszähler; daraus darf kein lückenloser Capture-Nachweis abgeleitet werden. Der reale Recovery-Pfad mit zwei lesbaren Originalen und erneuter Verarbeitung ist damit bestanden. Die nachträglich mit expliziter Signpost-Ausgabe gelesenen, inhaltsfreien OS-Ereignisse zeigten für diesen einen Lauf rund 1,1 s Restart-Recovery über die vorhandene History und rund 1,5 s `Meeting Track Processing` nach `Continue Processing`; der Merge selbst dauerte rund 7 ms. Diese Einzelwerte sind keine p95-Werte. Start-/Stop-UI-Latenzen, Main-Actor-Arbeit und Writer-Finalisierung sind durch die Force-Quit-Probe weiterhin nicht gemessen. Es wurde kein Transkriptinhalt dokumentiert.

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

**Status:** `RELEASEVORBEREITUNG` – Testphase auf Nutzerwunsch abgeschlossen; Veröffentlichung separat freizugeben

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

**Installierbarer Preview-Build 26. September 2026 — noch keine Release-Abnahme:** Aus dem damaligen 4.1-Arbeitsstand wurde separat ein universeller Release-Konfigurations-Build (`arm64 x86_64`) erzeugt und als `FlowDictate-4.1-preview-20260926-macOS.zip` ad-hoc signiert verpackt. Die interne Version bleibt planmäßig 4.0.2 (Build 27), die Bundle-ID `de.euler.FlowDictate`. Die frisch aus genau diesem ZIP entpackte App bestand die strenge Codesign-Prüfung; Sandbox-, Mikrofoneingabe-, benutzergewählte-Dateien- und Netzwerk-Entitlements sowie `NSAudioCaptureUsageDescription` wurden geprüft. Das Paket enthält eine Preview-Installationsnotiz und keine Aufnahme-, Transkript-, Modell-, Credential- oder private Testdatei. SHA-256: `0ce1db83fb0f1c4d0003e1a1f5a50f4537da562266ad712eec701345262cbf89`. Zum Zeitpunkt der Paketerstellung waren die laufende Debug-Instanz und die bestehende `/Applications/FlowDictate.app` noch unverändert; der spätere Installations- und Bugbefund steht im Nachtrag. Das Paket ist ausdrücklich nicht die finale Community-ZIP.

**Nachtrag Hotkey-Neustart 26. September 2026:** Der zuerst erstellte Preview-Build wurde später installiert. Beim Modellwechsel trat nach dem ersten `Quit & Restart` die Carbon-Meldung `-9878` auf; nach einem zweiten Neustart war der Hotkey wieder verfügbar. Ursache war die Reihenfolge im App-Restart: Die neue Instanz startete, während die alte ihre exklusiven globalen Hotkeys noch hielt. Der Restart gibt nun alle drei Hotkeys vor dem Öffnen der neuen Instanz frei und registriert sie bei einem fehlgeschlagenen Start in der alten Instanz erneut. Doppelte Restart-Anfragen werden während des Übergangs ignoriert. Die vollständige macOS-Suite bestand mit 216/216 Tests, inklusive neuer Handoff- und Fehlerfalltests. Ein separater universeller, ad-hoc signierter Preview-Build liegt als `FlowDictate-4.1-preview-20260926-hotkeyfix-macOS.zip` vor; die frisch entpackte App bestand die strenge Signaturprüfung und enthält `x86_64 arm64`. SHA-256: `371028e989191f33ea46ef663f6599e841f66c9c88ce2bc9519b93648c6f770b`. Die nun installierte App stimmt binär mit diesem ZIP-Build überein; genau eine Instanz läuft. Der Nutzer meldet, dass das Neustartproblem gelöst ist. Ein unabhängiger Log-Nachweis für die genaue Anzahl der Neustarts wurde nicht erhoben. Die Preview ersetzt nicht die finale Release-ZIP.

**Overlay-Abnahme 29. September 2026:** Der Größen-/Positions-Observer verwendet die neu publizierten Werte direkt. Zusätzlich startet die lokale Mikrofon-Live-Preview nach einem Wechsel von `Compact` zu `Standard` oder `Expanded` innerhalb derselben Aufnahme wieder; reine Positionswechsel starten sie nicht erneut. Die erweiterte Regression und die vollständige serielle macOS-Suite bestanden mit 217/217 Tests, 0 Fehlern, 0 Skips und 0 Runtime-Warnungen. Ein separater universeller Release-Konfigurations-Test-Build (`arm64 x86_64`) wurde ad hoc signiert und streng verifiziert. Der Nutzer bestätigte im Live-Test, dass Größen- und Positionswechsel während der Aufnahme sofort korrekt sichtbar waren. Die installierte Preview wurde nicht ersetzt; diese Abnahme gilt für den Test-Build und nicht automatisch für die noch zu erzeugende finale ZIP.

**4.1.0-ZIP-Kandidat in Vorbereitung:** Nach der manuellen Overlay-Abnahme werden die öffentlichen 4.1-Texte, die Marketingversion `4.1.0` und die monotone Buildnummer `28` für einen installierbaren Kandidaten vorbereitet. Der Nutzer hat weitere 60-/120-Minuten-Wiederholungen ausdrücklich abgelehnt und möchte die exakt gebaute ZIP anschließend als Erstnutzer und mehrere Tage im Alltag testen. Die vorhandenen Langläufe und ihre Systemaudio-Lücken bleiben der Langzeitnachweis; die bisherige Forderung nach neuen 60/120 Minuten mit exakt dieser ZIP ist damit eine offen zu genehmigende Gate-Abweichung, kein bestandenes Kästchen. Unbelegte p95-/Driftziele werden ebenfalls nicht still als erfüllt markiert. Kein Tag, Release oder Upload vor separater Freigabe.

**Optischer Overlay-Nachtrag 29. September 2026:** Ein Nutzerscreenshot zeigte im Standard-Overlay einen Umbruch von `RECORDING` vor dem letzten Buchstaben, wenn Live-Badge, Quellenlabel und Pegelmeter gleichzeitig sichtbar waren. Die Breite während einer Standard-Aufnahme steigt deshalb von 390 auf 420 Punkte; das Recording-Statuswort darf horizontal nicht umbrechen. Compact, Expanded und Nichtaufnahmebreiten bleiben unverändert. Die vollständige serielle macOS-Suite bestand mit 217/217 Tests ohne Fehler, Skips oder Runtime-Warnungen. Ein neuer universeller, ad-hoc signierter 4.1.0/28-Test-Build läuft als einzelne Instanz am bekannten temporären Pfad. Die vor dem Fix erstellte ZIP wurde ausgesondert; die Sichtprüfung dieser Statuszeile und eine anschließend neu erzeugte ZIP stehen noch aus.

**Sichtbestätigung:** Der Nutzer bestätigte nach Neustart genau dieses korrigierten Test-Builds, dass `RECORDING` im Standard-Overlay nicht mehr umbricht und die Darstellung gut aussieht. Das visuelle Gate ist damit bestanden. Der aus dem alten Stand erzeugte ZIP-Kandidat bleibt ausgesondert; nur eine danach aus dem korrigierten Stand neu erzeugte und entpackt geprüfte ZIP kommt für den Erstnutzer-Test infrage.

### 14.3 Finale Gate-Bewertung für 4.1.0/32

Die Testphase ist nach Bestätigung des Nutzers abgeschlossen. Die folgende Bewertung unterscheidet Nachweis, bekannte Abweichung und noch ausstehende **Releaseentscheidung**; nicht durchgeführte Tests werden nicht als bestanden gezählt.

| Gate | Bewertung |
|---|---|
| Vollständige Unit-/Integrationstests | Bestanden: isolierte serielle macOS-Suite 222/222, keine Fehler, Skips oder Runtime-Warnungen. |
| Debug- und Universal-Release-Build | Bestanden; Release-App enthält `arm64 x86_64`. |
| Single-Mic, Single-Systemaudio und Mixed-Grundpfad | Nutzerbestätigte Realtests; Build 32 besteht auch Mixed mit nur Mikrofonsprachsignal. |
| Local-/OpenAI-Mixed-Pfad | Lokal real und beide Provider automatisiert einschließlich kontrollierter OpenAI-HTTP-Uploads geprüft; ein separater realer OpenAI-Mixed-Lauf exakt mit Build 32 ist nicht dokumentiert. Kein weiterer Test gewünscht, Restrisiko für Releaseentscheidung. |
| Fully-offline-Mixed ohne Netzwerk | Reale Offline-/Cloud-Gegenläufe mit Debug-Build und automatisierte Provider-Policy-/HTTP-Tests bestanden. |
| 60/120 Minuten mit exakt der Build-32-ZIP | Nicht wiederholt, auf ausdrücklichen Nutzerwunsch. Frühere reale 60-/120-Minuten-Läufe sind vorhanden; die Abweichung bleibt vor Veröffentlichung als solche zu akzeptieren. |
| Sync, Drift, Gaps, Clipping und Performancebudgets | Qualitätsmetriken und Recovery nachgewiesen; Null-Bufferverlust verfehlt, mehrere Drift-/p95-/Main-Actor-Ziele nicht gemessen. Kurze Systemaudio-Lücken öffentlich dokumentiert. Kein weiterer Test gewünscht; Restrisiko vor Veröffentlichung entscheiden. |
| Mic-/Systemausfall, Force Quit und Resume | Deterministische Regression und realer Force-Quit-/Resume-Lauf bestanden; erfolgreiche Segmente werden nicht wiederholt. |
| Consent, Permissions und sichtbarer Status | In Setup-, Overlay- und Mixed-Realtests abgenommen; ad-hoc-Builds können macOS-Freigaben nach Update erneut benötigen. |
| Migration Schema 6 → 7 und Backup | Automatisiert geprüft; bestehende Einzelspur-History blieb bei den Installations-/Update-Tests erhalten. |
| Sessionlöschung ohne Fremddatenverlust | Manuelle Löschabnahme und pfadbegrenzte Regression bestanden. |
| ZIP-Architekturen, Signatur, SHA-256 und Privatausschluss | Build 32 aus Commit `7804e30` verifiziert; SHA-256 `c18e5d29d5cafcfcabfa877e039bd89d39f2b273ffa79db1e3d56edbe73adc1c`. Die installierte App stimmt in ausführbarer Datei, Info.plist, Assets und Signaturressourcen byteweise mit der entpackten ZIP-App überein. |
| Öffentliche Dokumentation und Release Notes | README, Privacy, Installationshinweise und Changelog beschreiben Verhalten und bekannte Lücken; `docs/releases/RELEASE_NOTES_4.1.0.md` vorbereitet. |

Ein separater mehrtägiger Praxistest *genau* von Build 32 wurde nicht mit Dauer und Ergebnis protokolliert. Der Nutzer beendet die Testphase dennoch; dies ist eine Abweichung vom früheren Soll, keine nachträglich bestandene Prüfung. Vor Publikation sind diese Restrisiken bewusst freizugeben. Änderungen an der gebündelten App oder den ZIP-Dateien würden die exakte Artefaktabnahme erneuern.

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

Die Testphase wurde auf Wunsch des Nutzers nach dem real bestätigten Silent-Track-Fix beendet. Der Build-32-Kandidat und die noch nicht als Tests bestandenen Gate-Abweichungen sind in 14.3 bewertet. Nächster Schritt ist die bewusste Releaseentscheidung über diese dokumentierten Restrisiken; erst ein separater Auftrag autorisiert Merge nach `main`, Tag, Push, GitHub Release und Asset-Upload. Bis dahin bleibt die geprüfte ZIP unverändert.
