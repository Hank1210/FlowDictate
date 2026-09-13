# FlowDictate 4.1 – Capture- und Berechtigungs-Spike

**Status:** In Arbeit; Build-, API-, Kurzzeit-Signal- und Community-Packaging-Gate bestanden
**Stand:** 13. September 2026
**Bezug:** Schritt 4.1.1 aus `ARBEITSPLAN_PHASE_4_1.md`

## Fragestellung

Für `Microphone + System Audio` wird ein öffentlicher, audio-only Systemaudiopfad gesucht, der getrennte Originalspuren, monotone Zeitanker und kontrolliertes Cleanup ermöglicht. Er wird mit dem vorhandenen ScreenCaptureKit-Pfad verglichen. Dieser Spike aktiviert noch keinen produktiven Mixed-Recording-Start.

## Verifizierte Apple-Verträge

### Core Audio Process Tap

- `AudioHardwareCreateProcessTap` ist laut installiertem Apple-SDK ab macOS 14.2 verfügbar.
- Apple beschreibt einen Tap als Quelle ausgehenden Prozessaudios, die über ein HAL Aggregate Device wie ein Audioeingang gelesen wird.
- Für die erste Aufnahme von einem Aggregate Device mit Tap verlangt Apple `NSAudioCaptureUsageDescription`; macOS zeigt dabei eine Systemaudio-Aufnahmefreigabe.
- Ein Tap kann privat, ungemutet, mono oder stereo und als globaler Tap mit ausgeschlossenen Prozessen konfiguriert werden.
- Das Aggregate Device kann ebenfalls privat sein und eine Tapliste mit Driftkompensation führen.
- Der IOProc liefert `AudioTimeStamp` und `AudioBufferList` ohne Screen- oder Videostream.

Primärquellen:

- [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [NSAudioCaptureUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription)
- [AudioHardwareCreateProcessTap](https://developer.apple.com/documentation/coreaudio/audiohardwarecreateprocesstap(_:_:))

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
6. misst Callbackanzahl, nichtleere Signalbuffer, Frames, Format sowie erste/letzte Hosttime,
7. stoppt IO und entfernt IOProc, Aggregate Device und Tap in jedem Erfolgs- und Fehlerpfad,
8. speichert weder PCM-Daten noch History- oder Meetingdateien.

Die Probe ist in Settings nur bei ausgewähltem `Microphone + System Audio` sichtbar. Sie ersetzt keinen Recorder und entfernt die bestehende `captureNotAvailable`-Sperre nicht.

Debug-Builds unterstützen zusätzlich den Startschalter `--run-core-audio-tap-probe`. Er ruft exakt dieselbe Probe einmalig beim App-Start auf und schreibt nur den Messbericht ins lokale Diagnoseprotokoll. Release-Builds enthalten diesen Startpfad nicht.

## Automatischer Nachweis

- vollständige Unit-Testsuite mit 113 von 113 erfolgreichen Tests grün,
- Strategiegrenze macOS 14.1 → ScreenCaptureKit und macOS 14.2+ → Core Audio Tap getestet,
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

Der macOS-Berechtigungsdialog erschien bei diesen Läufen nicht erneut. Die bestehende FlowDictate-Bundle-ID war auf dem Test-Mac bereits für Systemaudio freigegeben. Ein sauberer Erststart nach nicht erteilter, abgelehnter und widerrufener Berechtigung bleibt daher ausdrücklich offen.

## Vorläufige Entscheidung

Core Audio Tap ist der bevorzugte 4.1-Kandidat für macOS 14.2 und neuer. ScreenCaptureKit bleibt vorerst der bestehende Single-System-Audio-Pfad und der Kompatibilitätskandidat für macOS 14.0/14.1.

Diese Entscheidung ist noch nicht final. Vor `GO` fehlen:

- sauberer Erststart mit dem macOS-Berechtigungsdialog sowie Ablehnungs-/Widerrufstest,
- zehn statt bisher vier kurze Start-/Stop-Zyklen,
- Vergleich der Timestampkontinuität mit ScreenCaptureKit,
- 5-, 30- und 60-Minuten-Messungen,
- Prüfung von Bluetooth-, AirPlay- und Ausgaberoutenwechseln.

## Go-/No-Go-Regel

`GO Core Audio Tap` wird erst gesetzt, wenn Release-/Community-Build reale Signalbuffer mit monotonen Hosttimes liefert, Cleanup deterministisch ist und die 30-/60-Minuten-Läufe keine nicht erklärten Aussetzer zeigen.

Bei `NO-GO` bleibt ScreenCaptureKit der transparent dokumentierte Capturepfad. Es gibt keinen Fallback auf einen destruktiven Live-Mix und keine Behauptung einer schmaleren Berechtigung, die macOS tatsächlich nicht zeigt.
