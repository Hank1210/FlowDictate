# FlowDictate 4.1 – Capture- und Berechtigungs-Spike

**Status:** In Arbeit; Build-, API-, Kurzzeit-Signal-, Zehn-Zyklen-, Community-Packaging- und Erstberechtigungs-Gate bestanden
**Stand:** 15. September 2026
**Bezug:** Schritt 4.1.1 aus `ARBEITSPLAN_PHASE_4_1.md`

## Fragestellung

Für `Microphone + System Audio` wird ein öffentlicher, audio-only Systemaudiopfad gesucht, der getrennte Originalspuren, monotone Zeitanker und kontrolliertes Cleanup ermöglicht. Er wird mit dem vorhandenen ScreenCaptureKit-Pfad verglichen. Dieser Spike aktiviert noch keinen produktiven Mixed-Recording-Start.

## Verifizierte Apple-Verträge

### Core Audio Process Tap

- `AudioHardwareCreateProcessTap` ist laut installiertem Apple-SDK ab macOS 14.2 verfügbar.
- Apple beschreibt einen Tap als Quelle ausgehenden Prozessaudios, die über ein HAL Aggregate Device wie ein Audioeingang gelesen wird.
- Für die erste Aufnahme von einem Aggregate Device mit Tap verlangt Apple `NSAudioCaptureUsageDescription`; macOS zeigt dabei eine Systemaudio-Aufnahmefreigabe.
- Apple dokumentiert keine öffentliche Core-Audio-API, mit der FlowDictate diese Freigabe vorab abfragen oder separat anfordern kann. Der Systemdialog entsteht erst beim ersten Aufnahmestart vom Tap-Aggregate-Device.
- Die Berechtigung wird in macOS unter `Privacy & Security → Screen & System Audio Recording` verwaltet. Dort kann macOS reinen Systemaudiozugriff getrennt vom Bildschirmzugriff ausweisen.
- Ein Tap kann privat, ungemutet, mono oder stereo und als globaler Tap mit ausgeschlossenen Prozessen konfiguriert werden.
- Das Aggregate Device kann ebenfalls privat sein und eine Tapliste mit Driftkompensation führen.
- Der IOProc liefert `AudioTimeStamp` und `AudioBufferList` ohne Screen- oder Videostream.

Primärquellen:

- [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [NSAudioCaptureUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription)
- [AudioHardwareCreateProcessTap](https://developer.apple.com/documentation/coreaudio/audiohardwarecreateprocesstap(_:_:))
- [Allow apps to record your system audio](https://support.apple.com/guide/mac-help/mchl2844ecab/mac)

### ScreenCaptureKit

- Der vorhandene FlowDictate-Recorder setzt `capturesAudio = true` und registriert ausschließlich `.audio` als Streamoutput.
- Er registriert keinen `.screen`-Output und speichert deshalb keine Videoframes.
- `excludesCurrentProcessAudio = true` schließt FlowDictates eigenes Audio aus.
- Der Pfad benötigt derzeit die breiter benannte Screen-&-System-Audio-Berechtigung und fragt zuvor `SCShareableContent` ab.
- Er bleibt der Kompatibilitätskandidat für macOS 14.0 und 14.1.

Primärquelle:

- [SCStreamConfiguration](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration)

## Implementierte Probe

`CoreAudioTapCaptureProbe`:

1. prüft macOS 14.2 und `NSAudioCaptureUsageDescription`,
2. übersetzt den eigenen Prozess in ein Core-Audio-Prozessobjekt,
3. erstellt einen privaten, ungemuteten Mono-Global-Tap unter Ausschluss des eigenen Prozesses,
4. erstellt ein privates Aggregate Device mit aktivierter Subtap-Driftkompensation,
5. installiert einen IOProc auf einer eigenen Dispatch Queue,
6. misst Callbackanzahl, nichtleere Signalbuffer, Frames, Format, Host- und Sample-Time jedes Callbacks,
7. zählt fehlende oder rückwärts laufende Timestamps sowie Sample-Diskontinuitäten und die größte positive Lücke,
8. stoppt IO und entfernt IOProc, Aggregate Device und Tap in jedem Erfolgs- und Fehlerpfad,
9. prüft alle Cleanup-Statuswerte, begrenzt blockierende Core-Audio-Cleanup-Aufrufe und wartet danach begrenzt auf die UID-Abmeldung aus dem HAL,
10. kann zehn vollständig getrennte Start-/Stop-Zyklen automatisiert ausführen,
11. speichert weder PCM-Daten noch History- oder Meetingdateien.

Die Probe ist in Settings nur bei ausgewähltem `Microphone + System Audio` sichtbar. Sie ersetzt keinen Recorder und entfernt die bestehende `captureNotAvailable`-Sperre nicht.

Die Berechtigungsanzeige folgt dem tatsächlich ausgewählten Backend:

- `System Audio` nutzt weiterhin ScreenCaptureKit und zeigt dessen öffentlich abfragbaren Preflightstatus.
- `Microphone + System Audio` zeigt auf macOS 14.2+ vor dem ersten erfolgreichen Tap-Lauf `Checked when recording starts` statt einer nicht belegbaren Freigabe.
- Nach einem erfolgreichen Audio-only-Lauf zeigt FlowDictate `Allowed` nur für die laufende App-Sitzung. Nach einem Neustart wird erneut kein persistenter Status behauptet.
- Nur ein Lauf mit tatsächlich empfangenem Systemaudiosignal gilt als erfolgreicher Berechtigungsnachweis. Stumme Callbacks bleiben `inconclusive`, weil Apple keine öffentliche API zur Unterscheidung zwischen Ablehnung und legitimer digitaler Stille bereitstellt.
- Der alte ScreenCaptureKit-Test wird in der Mixed-Ansicht nicht angeboten, damit er nicht unbeabsichtigt die breitere Capturefreigabe anfragt.

Debug-Builds unterstützen zusätzlich die Startschalter `--run-core-audio-tap-probe` und `--run-core-audio-tap-cycle-probe`. Sie rufen exakt dieselben Einzel- beziehungsweise Zehn-Zyklen-Proben einmalig beim App-Start auf und schreiben nur den Messbericht ins lokale Diagnoseprotokoll. Release-Builds enthalten diese Startpfade nicht.

## Automatischer Nachweis

- vollständige Unit-Testsuite mit 115 von 115 erfolgreichen Tests grün,
- Strategiegrenze macOS 14.1 → ScreenCaptureKit und macOS 14.2+ → Core Audio Tap getestet,
- backendabhängige Berechtigungsanzeige einschließlich des nicht vorab abfragbaren Tap-Zustands getestet,
- Probe kompiliert bei Deployment Target macOS 14.0 hinter Availability-Gate,
- Universal-Release-Build erfolgreich für `x86_64 arm64`,
- Release-`Info.plist` enthält `NSAudioCaptureUsageDescription`,
- bestehende Mikrofon-, ScreenCaptureKit-, Provider-, Long-Form- und Recoverytests bleiben grün,
- `git diff --check` ohne Befund.

## Reale Kurzzeitmessung

Getestet am 13. September 2026 auf macOS 26.6.2, Apple Silicon:

| Build/Pfad | Dauer | Callbacks | Callbacks mit Signal | Format | Ergebnis |
|---|---:|---:|---:|---|---|
| Debug, ohne Wiedergabe | 5,088 s | 477 | 0 | 48 kHz, Mono | Callback- und Cleanup-Pfad erfolgreich |
| Debug, leiser macOS-Systemton | 4,992 s | 468 | 322 | 48 kHz, Mono | reales Systemaudiosignal erfolgreich |
| ad-hoc signiert und sandboxed, ohne überlappende Wiedergabe | 5,291 s | 496 | 0 | 48 kHz, Mono | Packaging-, Callback- und Cleanup-Pfad erfolgreich |
| ad-hoc signiert und sandboxed, leiser macOS-Systemton | 5,227 s | 490 | 410 | 48 kHz, Mono | Community-Packaging mit realem Signal erfolgreich |

Alle vier Läufe verwendeten neue private Tap-/Aggregate-IDs und konnten direkt nacheinander gestartet und beendet werden. Es wurden keine Audio-, Bildschirm-, History- oder Meetingdateien erzeugt. Die regulär installierte FlowDictate-App blieb während des Tests unverändert aktiv.

Am 14. September 2026 bestand zusätzlich ein ad-hoc signierter, sandboxed Community-Build zehn automatisierte Start-/Stop-Zyklen hintereinander:

- 10 von 10 Zyklen abgeschlossen,
- 968 Audio-Callbacks, davon 750 mit Systemaudiosignal,
- 0 Hosttime-Regressionen,
- 0 Sample-Time-Regressionen,
- 0 Sample-Diskontinuitäten und 0 positive Gap-Frames,
- Stop, IOProc-Entfernung, Aggregate-Device- und Tap-Destroy jeweils erfolgreich,
- Tap- und Aggregate-UID nach jedem Zyklus nicht mehr im HAL registriert.

Die UID-Abmeldung kann nach einem erfolgreichen Destroy-Aufruf kurz verzögert sichtbar werden. Die Probe wartet deshalb asynchron höchstens eine Sekunde auf die HAL-Konsistenz und meldet danach einen echten Cleanup-Fehler.

## Reale Berechtigungsmatrix

Am 15. September 2026 wurde die `AudioCapture`-Freigabe für die FlowDictate-Bundle-ID gezielt zurückgesetzt und der native macOS-Erstdialog im sichtbaren Debug-Testfenster geprüft:

| Entscheidung | Ergebnis | UI-Status | Cleanup |
|---|---|---|---|
| Nicht erlauben | 5,216 s, 489 Callbacks, 0 mit Signal | `inconclusive`; weiterhin `Checked when recording starts` | bestanden |
| Erlauben bei laufendem Systemton | 5,2 s, 489 Callbacks, 489 mit Signal, 0 Gaps | Probe erfolgreich; `Allowed` für die App-Sitzung | bestanden |
| Zugriff in `System Audio Recording Only` widerrufen, laufende App | 5,1 s, 476 Callbacks, 472 mit Signal, 0 Gaps | bestehender Prozess behält Zugriff bis zum Ende | bestanden |
| gleicher Widerruf nach App-Neustart | laufender Systemton, kein Signal empfangen | `inconclusive`; `Checked when recording starts` bleibt unverifiziert | bestanden |
| zehn Start-/Stop-Zyklen nach erneuter Freigabe | 10/10 Zyklen, 975 Callbacks, 0 Gaps | Probe vollständig beendet; Button wieder aktiv | bestanden |

Die Ablehnung darf nicht aus stummen Callbacks allein abgeleitet werden. Der Nutzer erhält deshalb einen sichtbaren, direkt bei den Probe-Buttons angezeigten Hinweis, dass kein Systemaudiosignal empfangen wurde und Zugriff beziehungsweise Wiedergabe geprüft werden sollen.

Bei einem zusätzlichen Wiederholungsversuch mit verweigertem Zugriff blockierte macOS synchron in `AudioDeviceDestroyIOProcID`. Ein Prozess-Sample bestätigte, dass die fünfsekündige Aufnahme bereits beendet war und ausschließlich das Cleanup wartete. Der Spike führt die synchronen Destroy-Aufrufe deshalb auf einem isolierten Hintergrundpfad aus und gibt die UI nach einem Drei-Sekunden-Limit mit einem Neustarthinweis frei. Der normale Ablehnungs- und der anschließende Erlauben-Lauf räumten vollständig auf. Ein anschließender kontrollierter Lauf mit zehn Start-/Stop-Zyklen beendete alle Zyklen mit 975 Callbacks, 0 Gaps und vollständig erfolgreichem Cleanup. Berechtigungstests werden künftig nicht parallel mit einer zweiten FlowDictate-Instanz derselben Bundle-ID ausgeführt.

Der manuelle Widerrufstest zeigte außerdem, dass ScreenCaptureKit und Core Audio Tap getrennte TCC-Dienste besitzen. `Privacy_ScreenCapture` widerruft nicht den Tap-Zugriff. Mixed Recording muss deshalb die Untersektion `Privacy_AudioCapture` (`System Audio Recording Only`) ansteuern; Single System Audio bleibt bei `Privacy_ScreenCapture`. macOS 26.6.2 (Build 25G83) zeigt beide Schaltergruppen gemeinsam in der Ansicht `Screen & System Audio Recording`, deshalb benennt die FlowDictate-UX ausdrücklich den unteren Bereich `System Audio Recording Only`. Ein Widerruf des richtigen Schalters wirkt beim bereits laufenden Prozess nicht rückwirkend, nach Prozessneustart jedoch zuverlässig.

## Vorläufige Entscheidung

Core Audio Tap ist der bevorzugte 4.1-Kandidat für macOS 14.2 und neuer. ScreenCaptureKit bleibt vorerst der bestehende Single-System-Audio-Pfad und der Kompatibilitätskandidat für macOS 14.0/14.1.

Diese Entscheidung ist noch nicht final. Vor `GO` fehlen:

- Vergleich der Timestampkontinuität mit ScreenCaptureKit,
- 5-, 30- und 60-Minuten-Messungen,
- Prüfung von Bluetooth-, AirPlay- und Ausgaberoutenwechseln.

## Go-/No-Go-Regel

`GO Core Audio Tap` wird erst gesetzt, wenn Release-/Community-Build reale Signalbuffer mit monotonen Hosttimes liefert, Cleanup deterministisch ist und die 30-/60-Minuten-Läufe keine nicht erklärten Aussetzer zeigen.

Bei `NO-GO` bleibt ScreenCaptureKit der transparent dokumentierte Capturepfad. Es gibt keinen Fallback auf einen destruktiven Live-Mix und keine Behauptung einer schmaleren Berechtigung, die macOS tatsächlich nicht zeigt.
