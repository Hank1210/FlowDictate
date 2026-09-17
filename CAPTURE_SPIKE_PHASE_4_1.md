# FlowDictate 4.1 – Capture- und Berechtigungs-Spike

**Status:** In Arbeit; Build-, API-, Kurzzeit-Signal-, Zehn-Zyklen-, Community-Packaging-, Erstberechtigungs- und ScreenCaptureKit-Kurzvergleichs-Gate bestanden
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

Ad-hoc signierte Builds besitzen als Designated Requirement nur ihren Code-Hash. Nach einer neu erzeugten Binärdatei kann deshalb ein sichtbarer alter TCC-Eintrag nicht mehr zum aktuellen Build passen; im manuellen ScreenCaptureKit-Test musste FlowDictate aus `Screen & System Audio Recording` entfernt, erneut hinzugefügt und anschließend neu gestartet werden. Da auch das Community-Paket ad-hoc signiert ist, gehört das Berechtigungsverhalten nach einem App-Update ausdrücklich zum Packaging- und Release-Gate.

Drei kontrollierte ScreenCaptureKit-Kurzläufe mit genau einer FlowDictate-Instanz lieferten 259, 250 und 253 Audio-Callbacks. Alle Präsentationszeitstempel waren monoton und vollständig. Der erste Lauf enthielt eine positive Lücke von 829 Frames beziehungsweise rund 17,3 ms bei 48 kHz; die beiden unmittelbaren Wiederholungen hatten keine Lücke. Der Core-Audio-Tap hatte im kontrollierten Zehn-Zyklen-Lauf ebenfalls keine Lücke. Die Abweichung ist damit sporadisch statt dauerhaft reproduzierbar; die Sessionarchitektur darf erkannte Lücken unabhängig davon nicht stillschweigend verdichten.

Ein erneuter, unmittelbar aufeinanderfolgender Kontrollvergleich mit dem für die Langzeitmatrix vorbereiteten Build verstärkte diesen Befund: ScreenCaptureKit lieferte in einem nominellen Fünf-Sekunden-Lauf nur 4,4 Sekunden Audiodaten, 219 Callbacks und eine Lücke von 38.400 Frames (rund 0,8 Sekunden). Der anschließende Core-Audio-Tap-Lauf lieferte 5,0 Sekunden, 469 Callbacks, 465 davon mit Signal, keine Lücke, monotone Zeitstempel und erfolgreiches Cleanup. Die fünfminütigen Vergleichsläufe sind der nächste Gate-Schritt.

Der erste nominelle Fünf-Minuten-Lauf des Core-Audio-Taps lieferte 310,869 Sekunden Audiodaten, 29.144 Callbacks, davon 29.143 mit Signal, keine Lücke, monotone Zeitstempel und erfolgreiches Cleanup. Lokale Core-Audio-Start-/Stop-Logs bestätigten dieselbe reale Laufzeit von rund 310,9 Sekunden; die Abweichung von 10,9 Sekunden ist daher kein Audio-Clock-Drift, sondern ein verspätet ausgeführter zeitgesteuerter Stop. Der unmittelbar folgende ScreenCaptureKit-Lauf mit demselben Zeitmechanismus dient zur Eingrenzung, ob das Verhalten backendunabhängig ist.

Der unmittelbar folgende ScreenCaptureKit-Fünf-Minuten-Lauf lieferte 300,040 Sekunden Audiodaten, 15.002 Callbacks, keine fehlenden oder regressiven Präsentationszeitstempel, keine Lücke, keine Sample-Rate-Änderung und eine temporäre M4A-Datei von 2.477.371 Bytes, die anschließend entfernt wurde. Die Timerabweichung ist damit nicht allgemein im Coordinator reproduzierbar. Ein zweiter Core-Audio-Fünf-Minuten-Lauf unter denselben Wachbedingungen muss klären, ob der verspätete Stop ein einmaliger Schedulingeffekt oder backendnah reproduzierbar ist.

Der zweite Core-Audio-Fünf-Minuten-Lauf endete erst nach 319,979 Sekunden Audiodaten mit 29.998 Callbacks, davon 29.991 mit Signal, erneut ohne Lücke, mit monotonen Zeitstempeln und erfolgreichem Cleanup. Core-Audio-Systemlogs bestätigten Start um 21:10:42,522 und Stop um 21:16:02,511, also dieselbe reale Laufzeit. Der verspätete Stop ist damit reproduzierbar. Der Diagnosepfad verwendet deshalb nicht länger die Wiederaufnahme eines Actor-Tasks als zeitkritischen Stop, sondern einen dedizierten hochpriorisierten Dispatch-Timer, der `AudioDeviceStop` direkt zum Sollzeitpunkt ausführt. Destruktives Cleanup bleibt separat timeout-isoliert. Neue Ergebnisse weisen Sollzeit, reale Stop-Laufzeit und Audiodauer getrennt aus; vor dem 30-Minuten-Gate wird der korrigierte Fünf-Minuten-Lauf wiederholt.

Der korrigierte Core-Audio-Fünf-Minuten-Lauf bestätigte die Änderung: 300,000 Sekunden Sollzeit, 300,001738 Sekunden reale Stop-Laufzeit und 300,010667 Sekunden Audiodaten. Die Stop-Abweichung betrug nur 1,738 ms. 28.126 Callbacks, davon 28.124 mit Signal, wurden ohne Host-/Sample-Time-Regression, ohne Gap und mit erfolgreichem Cleanup verarbeitet. Damit ist das Core-Audio-30-Minuten-Gate freigegeben.

Auch das Core-Audio-30-Minuten-Gate wurde bestanden: 1.800,000 Sekunden Sollzeit, 1.800,008087 Sekunden reale Stop-Laufzeit und 1.800,000 Sekunden Audiodaten. Die Stop-Abweichung betrug 8,087 ms. Von 168.750 Callbacks enthielten 165.486 ein Signal; Host- und Sample-Time blieben monoton, es gab keine erkannte Lücke und das Cleanup war vollständig erfolgreich. Als nächster Vergleichsschritt folgt ScreenCaptureKit mit 30 Minuten.

Der ScreenCaptureKit-30-Minuten-Gegenlauf wurde technisch vollständig beendet, bestand das Qualitätsgate aber nicht lückenfrei: 1.800 Sekunden Sollzeit, 1.800,253867 Sekunden Wall und 1.799,400 Sekunden Audiodaten bei 89.970 Callbacks. Die Präsentationszeitstempel waren vollständig und monoton, die Sample-Rate blieb stabil, aber es wurde eine einzelne Lücke von 31.680 Frames beziehungsweise 0,66 Sekunden bei 48 kHz erkannt. Die temporäre M4A-Datei war 14.847.963 Bytes groß und wurde anschließend entfernt. Das stärkt Core Audio Tap als bevorzugten Pfad; ScreenCaptureKit bleibt für macOS 14.0/14.1 ein gesondert zu behandelnder Kompatibilitätspfad mit sichtbarer Gap-Diagnostik.

Der Core-Audio-60-Minuten-Lauf bestätigte die Langzeitstabilität: 3.600,000 Sekunden Sollzeit, 3.600,010060 Sekunden reale Stop-Laufzeit und exakt 3.600,000 Sekunden Audiodaten. Die Stop-Abweichung betrug 10,060 ms. 337.500 Callbacks, davon 328.839 mit Signal, wurden ohne Host-/Sample-Time-Regression und ohne Gap verarbeitet; das Cleanup bestand vollständig. Damit sind die 5-, 30- und 60-Minuten-Dauergates des bevorzugten Core-Audio-Pfads auf diesem Testsystem erfüllt.

Der ScreenCaptureKit-60-Minuten-Lauf bestand im Gegensatz zum 30-Minuten-Lauf lückenfrei: 3.600 Sekunden Sollzeit, 3.600,487661 Sekunden Wall und 3.600,100000 Sekunden Audiodaten bei 180.005 Callbacks. Es gab keine fehlenden oder regressiven PTS, keine Discontinuity und keine Sample-Rate-Änderung. Die temporäre Datei umfasste 29.577.737 Bytes und wurde anschließend entfernt. Die 0,66-Sekunden-Lücke des 30-Minuten-Laufs ist damit sporadisch und nicht als dauerhafte Drift reproduziert, muss im Kompatibilitätspfad aber weiterhin erkannt und sichtbar behandelt werden.

Ein fünfminütiger Core-Audio-Routenwechseltest bestand ebenfalls. Während kontinuierlicher Wiedergabe wurde vom MacBook-Lautsprecher auf ein Plantronics-Headset und zurück gewechselt; zusätzlich wurde versehentlich sehr kurz ein AirPods-Ausgang gewählt. Der Lauf lieferte 300,000 Sekunden Sollzeit, 300,009434 Sekunden Wall und 300,010667 Sekunden Audio, 28.126 Callbacks, davon 26.746 mit Signal, keine Host-/Sample-Time-Regression, keine Discontinuity und erfolgreiches Cleanup. Der globale Tap blieb über alle drei Ausgaberoutenwechsel hinweg timelinekontinuierlich.

Der entsprechende ScreenCaptureKit-Routenwechsel MacBook-Lautsprecher → Plantronics-Headset → MacBook-Lautsprecher bestand ebenfalls: 300 Sekunden Sollzeit, 300,168522 Sekunden Wall, 300,020000 Sekunden Audio und 15.001 Callbacks. PTS blieben vollständig und monoton, es gab keine Discontinuity und keine Sample-Rate-Änderung. Die temporäre Datei umfasste 2.444.979 Bytes und wurde anschließend entfernt. Damit ist der kontrollierte Ausgaberoutenvergleich für beide Backends abgeschlossen.

Der Core-Audio-Cancel-/Recovery-Test bestand: Eine nominelle 30-Minuten-Probe wurde nach wenigen Sekunden über den sichtbaren Cancel-Button beendet; der Start-Button wurde anschließend wieder aktiv. Eine unmittelbar folgende Fünf-Sekunden-Probe lief mit 5,009100 Sekunden Wall, 5,002667 Sekunden Audio, 469 Callbacks, 465 davon mit Signal, ohne Gap, mit monotonen Zeitstempeln und erfolgreichem Cleanup durch. Der Abbruch hinterließ damit keinen blockierenden Tap-, Device- oder UI-Zustand.

ScreenCaptureKit bestand denselben Cancel-/Recovery-Ablauf. Nach Abbruch einer laufenden 30-Minuten-Probe wurde der Start-Button wieder aktiv; die unmittelbar folgende Fünf-Sekunden-Probe lieferte 5,182252 Sekunden Wall, 5,080000 Sekunden Audio, 254 Callbacks, vollständige monotone PTS, keine Discontinuity und keine Sample-Rate-Änderung. Die 45.194 Bytes große temporäre Datei wurde anschließend entfernt.

Core Audio Tap bestand außerdem einen echten Prozessabbruch/Neustart. Die App wurde während einer laufenden nominellen 30-Minuten-Probe ohne den Cancel- oder Cleanup-Pfad hart beendet und derselbe Debug-Build anschließend neu gestartet. Eine unmittelbar folgende Fünf-Sekunden-Probe erzeugte erfolgreich einen neuen Tap und ein neues Aggregate Device: 5,009794 Sekunden Wall, 5,013333 Sekunden Audio, 470 Callbacks, 466 davon mit Signal, keine Host-/Sample-Time-Regression, kein Gap und erfolgreiches Cleanup. macOS gab die prozessgebundenen Core-Audio-Ressourcen nach dem Crash frei.

Auch ScreenCaptureKit gab seine Capture-Ressourcen nach einem harten Prozessabbruch frei. Eine unmittelbar nach App-Neustart gestartete Fünf-Sekunden-Probe lieferte 5,3 Sekunden Wall, 5,1 Sekunden Audio, 257 Callbacks, vollständige monotone PTS, keine Discontinuity und keine Sample-Rate-Änderung. Der bisherige Diagnosepfad hinterließ beim Crash allerdings eine 403.755 Bytes große, nicht lesbare M4A-Datei im normalen Aufnahmeordner. Die Diagnose schreibt deshalb künftig ausschließlich in ein eigenes temporäres Probe-Verzeichnis. Clean Stop und Cancel entfernen das Artefakt direkt; beim nächsten Appstart werden nur eindeutig präfixierte Probe-Dateien gelöscht, deren eingebettete Besitzer-PID nicht mehr läuft. Reguläre Aufnahmeordner und Nutzerdateien sind ausdrücklich nicht Teil dieser Bereinigung. Der neue Startup-Cleanup bestand auch manuell: Nach `SIGKILL` blieb die aktive 279.536-Byte-Probedatei zunächst erhalten, wurde beim App-Neustart automatisch entfernt und eine direkte Fünf-Sekunden-Wiederholung bestand mit 5,2 Sekunden Wall, 5,0 Sekunden Audio, 252 Callbacks, vollständigen monotonen PTS, 0 Gaps und stabiler Sample-Rate. Nach dem sauberen Ende war das Probe-Verzeichnis wieder leer.

## Vorläufige Entscheidung

Core Audio Tap ist der bevorzugte 4.1-Kandidat für macOS 14.2 und neuer. ScreenCaptureKit bleibt vorerst der bestehende Single-System-Audio-Pfad und der Kompatibilitätskandidat für macOS 14.0/14.1.

Diese Entscheidung ist noch nicht final. Vor `GO` fehlen:

- optionaler AirPlay-Routenwechsel als zusätzlicher Kompatibilitätsfall,
- erneuter Universal-Release-/Community-Paketnachweis des finalen Spike-Codes.

## Go-/No-Go-Regel

`GO Core Audio Tap` wird erst gesetzt, wenn Release-/Community-Build reale Signalbuffer mit monotonen Hosttimes liefert, Cleanup deterministisch ist und die 30-/60-Minuten-Läufe keine nicht erklärten Aussetzer zeigen.

Bei `NO-GO` bleibt ScreenCaptureKit der transparent dokumentierte Capturepfad. Es gibt keinen Fallback auf einen destruktiven Live-Mix und keine Behauptung einer schmaleren Berechtigung, die macOS tatsächlich nicht zeigt.
