# FlowDictate – Arbeitsplan Phase 3.3

**Phase:** 3.3 – App Integration, Audio Capture & Delivery
**Status:** Implementiert; automatisierte und manuelle Abnahme läuft
**Stand:** 23. August 2026
**Grundlage:** `FlowDictate_PRD_Phase_3.md`, veröffentlichte Version 3.2.0 und aktueller Code auf `main`

## 1. Ziel

### Umsetzungsstand

Der Pflichtumfang ist im Arbeitsstand implementiert: getrennte Mikrofon- und Systemaudioaufnahme, Quellenmetadaten, App-Profile, direkte Einfügung mit Fallback, Press-and-Hold, lokale Statistik und GitHub-Release-Hinweis. Build und automatisierte Regressionstests sind Bestandteil der technischen Abnahme.

Vor der Freigabe von 3.3.0 stehen die macOS-Hardwaretests aus Abschnitt 15 noch aus, insbesondere Systemaudio mit mehreren Ausgabegeräten, 30-Minuten-Aufnahme, Einfügung in verschiedene Apps und ein zweiter Mac. Der kombinierte Mischmodus, fortlaufende Diktierkette, Bulk-Export und Profilimport/-export bleiben wie geplant Soll- beziehungsweise Folgeumfang.

Phase 3.3 macht FlowDictate flexibler für unterschiedliche Ziel-Apps und Audioquellen. Neben der vorhandenen Mikrofonaufnahme wird digitales Systemaudio unterstützt. App-Profile, direkte Accessibility-Einfügung, Press-and-Hold, lokale Statistik und ein unaufdringlicher GitHub-Release-Hinweis vervollständigen die Phase.

Nach Abschluss gilt:

- Mikrofon und Systemaudio sind getrennt auswählbare, zuverlässige Aufnahmequellen,
- bestehende Installationen bleiben nach der Migration im Mikrofonmodus,
- Aufnahmequelle, Pegel und Status sind in Settings, Overlay und History eindeutig sichtbar,
- App-Profile wenden Einstellungen anhand der Bundle-ID der Ziel-App an,
- Text wird nach Möglichkeit direkt per Accessibility und ansonsten über den sicheren Clipboard-Fallback eingefügt,
- Toggle und Press-and-Hold funktionieren ohne doppelte Sessions,
- Statistik wird ausschließlich lokal aus der History berechnet,
- die App kann auf eine neuere stabile GitHub-Version hinweisen, installiert aber nichts selbst,
- Restore, Retry, Recovery, Live Preview und Smart Dictation funktionieren weiterhin.

## 2. Umfang und Prioritäten

### 2.1 Pflichtumfang

1. Audioquellen **Microphone** und **System Audio**
2. App-spezifische Profile
3. Direkte Accessibility-Einfügung mit Clipboard-Fallback
4. Press-and-Hold-Aufnahmemodus
5. Lokale Nutzungsstatistik
6. GitHub-Release-Hinweis
7. Vollständige, rückwärtskompatible Migration
8. Dokumentation, Datenschutzprüfung und Release-Vorbereitung

### 2.2 Soll-Umfang mit eigenem Freigabe-Gate

- **Microphone + System Audio** als kombinierte Aufnahme
- fortlaufende Diktierkette
- Bulk-Export von History, Text und optional Audio
- Import und Export von App-Profilen
- manuelle AX-Kompatibilitätsausnahmen für problematische Apps

Soll-Funktionen dürfen Phase 3.3 nicht verzögern, wenn ihre Zuverlässigkeits-Gates nicht erfüllt sind.

### 2.3 Nicht Bestandteil

- Umgehung geschützter oder von macOS blockierter Audioquellen
- Speicherung von Bildschirminhalten oder Video
- Cloud-Live-Streaming der laufenden Aufnahme
- vollständig lokale finale Transkription
- automatische Installation von Updates
- Cloud-Synchronisation von Profilen oder Statistiken
- Analyse von Fenstertiteln, Dokumentinhalten oder Clipboard-Inhalten zur Profilwahl

## 3. Lieferstrategie

Phase 3.3 wird in sieben einzeln prüfbare Schritte geteilt:

| Schritt | Ergebnis |
|---|---|
| 3.3.0 | stabile 3.2-Baseline und technische Verträge |
| 3.3.1 | Audioquellenmodell, Migration und Recorder-Abstraktion |
| 3.3.2 | Systemaudioaufnahme, Berechtigung, Testablauf und Recovery |
| 3.3.3 | Audioquellen-UI, Preview, History und optionaler Mischmodus |
| 3.3.4 | App-Profile und effektive Konfiguration |
| 3.3.5 | direkte Einfügung und Press-and-Hold |
| 3.3.6 | lokale Statistik, Update-Hinweis und Soll-Funktionen |
| 3.3.7 | Gesamtregression, Dokumentation und Release 3.3.0 |

Jeder Schritt endet mit Build, automatisierten Tests, einem kurzen manuellen Test und einem separaten Commit. Ein Schritt beginnt erst, wenn das vorherige Gate erfüllt ist.

## 4. Festgelegte Produktentscheidungen

### 4.1 Sichere Audioquelle

- `.microphone` bleibt für neue und bestehende Installationen der Default.
- Systemaudio wird nur nach expliziter Auswahl verwendet.
- Ein Quellenwechsel während einer Aufnahme ist gesperrt.
- Bei fehlender Systemaudiofreigabe erfolgt kein stiller Wechsel zum Mikrofon.
- Jede Aufnahme wird von Beginn an fortlaufend in eine lokale Datei geschrieben.

### 4.2 Systemaudio ohne Bilddaten

- ScreenCaptureKit liefert ausschließlich einen Audio-Output an FlowDictate.
- Es wird kein Video-Output registriert und kein Screenshot gespeichert.
- Namen von Apps, Fenstern, Meetings oder Medien werden nicht protokolliert oder persistiert.
- FlowDictates eigene Audioausgabe wird soweit technisch möglich ausgeschlossen.

### 4.3 Bestehende Pipeline wiederverwenden

Alle freigegebenen Recorder erzeugen dasselbe `AudioRecordingResult`. Danach bleiben Transkription, Smart Dictation, Einfügung, History, Retry, Recovery und Retention unabhängig von der Aufnahmequelle.

### 4.4 Mischmodus nur bei nachgewiesener Stabilität

Der kombinierte Modus wird nur freigegeben, wenn Synchronisierung, Resampling, Clipping-Schutz, Gerätewechsel und Langzeitaufnahme zuverlässig funktionieren. Andernfalls bleibt er hinter einem Feature-Schalter oder wird auf eine spätere Version verschoben.

## 5. Zielarchitektur

```text
RecordingAudioSource
        ↓
AudioRecordingFactory
        ├── MicrophoneRecorder
        ├── SystemAudioRecorder (ScreenCaptureKit)
        └── MixedAudioRecorder / AudioMixer (Soll)
                    ↓
          AudioRecordingResult + AudioSourceMetadata
                    ↓
     bestehende Transkriptions- und Smart-Dictation-Pipeline
                    ↓
        InsertStrategy → AX Direct Insert → Clipboard Fallback
                    ↓
          History, Statistik und Recovery
```

### 5.1 Neue beziehungsweise erweiterte Komponenten

| Komponente | Verantwortung |
|---|---|
| `RecordingAudioSource` | stabile, codierbare Quellenwerte |
| `AudioSourceMetadata` | Quelle, Sample-Rate und Kanalzahl der Aufnahme |
| `AudioRecordingFactory` | passenden Recorder für die effektive Konfiguration liefern |
| `SystemAudioRecorder` | ScreenCaptureKit-Stream in eine lokale Audiodatei schreiben |
| `SystemAudioPermissionService` | Freigabestatus, Anfrage und Link zu Systemeinstellungen |
| `AudioFormatNormalizer` | Sample-Rate und Kanalformat außerhalb des Capture-Callbacks normalisieren |
| `AudioMixer` | optional Mikrofon und Systemaudio synchronisieren und begrenzen |
| `AppProfileStore` | versionierte lokale Profilpersistenz |
| `EffectiveDictationConfigurationResolver` | globale Werte und Profilüberschreibungen zusammenführen |
| `AccessibilityTextInserter` | direkte, sichere Einfügung in editierbare AX-Elemente |
| `FallbackTextInserter` | AX-Versuch und kontrollierter Clipboard-Fallback |
| `UsageStatisticsCalculator` | lokale Kennzahlen aus History berechnen |
| `GitHubReleaseChecker` | stabile Releases gedrosselt prüfen und semantisch vergleichen |

## 6. Schritt 3.3.0 – Baseline und technische Vorbereitung

### Aufgaben

- Aktuelle 3.2-Regressionskorrekturen für Formatierung, History und Restore abschließen und separat committen.
- Alle vorhandenen Unit-Tests und einen manuellen Mikrofon-/Preview-Test ausführen.
- Aktuelles History- und Settings-Schema dokumentieren.
- `AudioRecording` so erweitern, dass Quelle und Metadaten transportiert werden können, ohne den Coordinator an ScreenCaptureKit zu koppeln.
- Test-Doubles für Recorder, Berechtigungen und Audioquellenwahl vorbereiten.
- Feature-Schalter für Systemaudio und Mischmodus vorsehen.

### Gate

- Mikrofonaufnahme, Preview, Transkription, Smart Dictation, Restore und History funktionieren wie in 3.2.
- Keine 3.3-Funktion verändert vor ihrer Aktivierung das bestehende Verhalten.

## 7. Schritt 3.3.1 – Audioquellenmodell und Migration

### 7.1 Datenmodell

Einführen:

```swift
enum RecordingAudioSource: String, Codable, CaseIterable, Sendable {
    case microphone
    case systemAudio
    case mixed
}

struct AudioSourceMetadata: Codable, Sendable, Equatable {
    var source: RecordingAudioSource
    var sampleRate: Double
    var channelCount: Int
}
```

Erweitern:

- `AudioRecordingResult` um `sourceMetadata`,
- `DictationRecord` um `audioSource`, Sample-Rate und Kanalzahl,
- `AppSettings` um `recordingAudioSource`,
- History-Dekodierung mit `.microphone` als Default für alte Einträge,
- Diagnoseexport ausschließlich um technische Quellenwerte.

### 7.2 Recorder-Auswahl

- `AudioRecordingFactory` oder gleichwertige Strategie einführen.
- Coordinator wählt Recorder anhand der zu Aufnahmestart eingefrorenen Konfiguration.
- Mikrofoneinstellung ist nur im Mikrofon- oder Mischmodus relevant.
- Quellenwahl während `recording`, `transcribing`, `enhancing` oder `inserting` sperren.
- Unbekannte gespeicherte Enum-Werte sicher auf Mikrofon zurückführen.

### Tests

- neue und bestehende Settings starten mit Mikrofon,
- alte History-Dateien dekodieren ohne Datenverlust,
- Quelle wird beim Start eingefroren,
- Quellenwechsel während einer Aufnahme bleibt wirkungslos,
- MicrophoneRecorder liefert korrekte Metadaten.

### Gate

- Bestehende Mikrofonfunktion ist unverändert verwendbar.
- Migration aktiviert niemals selbstständig Systemaudio.

## 8. Schritt 3.3.2 – Systemaudioaufnahme

### 8.1 ScreenCaptureKit-Prototyp

- Verfügbarkeit und Mindest-macOS-Version prüfen.
- `SCShareableContent` ausschließlich zur technischen Stream-Konfiguration verwenden.
- `SCStreamConfiguration.capturesAudio = true` setzen.
- Keinen Video-Output registrieren.
- Aktuellen Prozess nach Möglichkeit über `excludesCurrentProcessAudio` ausschließen.
- Streamformat und tatsächlich gelieferte Buffer protokollieren, jedoch niemals Audioinhalte oder App-Namen.

Der Prototyp gilt erst als erfolgreich, wenn eine lokal gespeicherte Datei durch die bestehende Upload-Vorbereitung akzeptiert und von OpenAI transkribiert werden kann.

### 8.2 Produktionsfähiger `SystemAudioRecorder`

- Lebenszyklus `start`, `stop`, `cancel` und Unterbrechung implementieren.
- Audio-Callbacks minimal halten und Buffer über eine begrenzte Queue weitergeben.
- Datei fortlaufend und atomar abschließbar schreiben.
- Formatkonvertierung außerhalb des ScreenCaptureKit-Callbacks ausführen.
- Dauer, Pegel und technische Metadaten liefern.
- Leere oder zu kurze Dateien erkennen und als Fehler behandeln.
- Ausgabegerätewechsel und Stream-Ende als definierte Fehlerzustände behandeln.

### 8.3 Berechtigung

- Systemaudio-/Bildschirmaufnahmefreigabe getrennt vom Mikrofonstatus darstellen.
- Freigabe erst bei Auswahl oder Test von Systemaudio anfragen.
- Aktionen **Open System Settings** und **Check Again** anbieten.
- Verweigerte oder entzogene Freigabe verhindert nur Systemaudio, nicht den Mikrofonmodus.
- Vor der ersten Aufnahme einen kurzen Datenschutz- und Einwilligungshinweis anzeigen.

### 8.4 Fünfsekündiger Test

**Test System Audio for 5 Seconds…** muss:

- den Pegel sichtbar machen,
- eine temporäre Audiodatei erzeugen und technisch validieren,
- keine OpenAI-Anfrage auslösen,
- keinen History-Eintrag anlegen,
- die Testdatei auch bei Abbruch oder Fehler löschen.

### 8.5 Recovery

- `systemAudioPermission`, `systemAudioUnavailable` und `systemAudioInterrupted` ergänzen.
- Bei Unterbrechung bereits geschriebene Audiodaten sicher abschließen.
- Eine verwertbare Teilaufnahme als Recovery-Datensatz erhalten.
- Eine leere Datei nicht als erfolgreiche Aufnahme darstellen.

### Tests und Gate

- Unit-Tests für Berechtigungs- und Recorderzustände,
- Integrationstest Stream → Datei → Upload-Vorbereitung,
- Testablauf ohne Netzwerk-, History- oder Dateirückstand,
- manuell mit Lautsprecher, kabelgebundenen Kopfhörern und Bluetooth,
- mindestens 30 Minuten ohne ungebremsten Speicheranstieg,
- keinerlei persistierte Bild- oder Videodaten.

## 9. Schritt 3.3.3 – Audioquellen-UI, Preview und History

### Settings

Unter **Settings → Audio → Recording source**:

- Microphone,
- System Audio,
- Mixed nur bei aktiviertem und freigegebenem Feature,
- verständliche Kurzbeschreibung je Quelle,
- Berechtigungsstatus und Systemaudio-Test,
- Quellenwahl während einer Aufnahme deaktivieren.

### Overlay und Menü

- aktive Quelle textlich und über ein verfügbares SF Symbol anzeigen,
- Systemaudiopegel wie den Mikrofonpegel auf höchstens zehn UI-Updates pro Sekunde begrenzen,
- Mischmodus mit zwei unterscheidbaren Pegeln darstellen,
- Recording-Indikator während der gesamten Aufnahme erhalten,
- Farbe nie als einzigen Informationsträger verwenden.

### Live Preview

- normalisierte Systemaudiobuffer an den vorhandenen Preview-Coordinator weiterreichen,
- keine Formatkonvertierung im Capture-Callback,
- Preview-Fehler vom Recorder entkoppeln,
- bei Mixed eine feste Preview-Quelle definieren und anzeigen.

### History und Recovery

- verwendete Quelle und technisches Format anzeigen,
- keine App-/Mediennamen des Systemaudios speichern,
- Play, Retry, Restore, Export und Retention quellenunabhängig halten,
- History-Ansicht weiterhin nur auf benötigte Published-Werte abonnieren.

### Optionaler Mischmodus

- monotone Zeitstempel beider Quellen verwenden,
- Sample-Raten außerhalb der Echtzeit-Callbacks angleichen,
- Drift messen und begrenzen,
- Clipping durch Summierung vermeiden,
- Queue-Größen begrenzen,
- Ausfall einer Quelle ohne Beschädigung der vorhandenen Aufnahme behandeln.

### Gate

- Mikrofon und Systemaudio bestehen die vollständige Diktierpipeline.
- Mixed wird nur aktiviert, wenn alle Kriterien aus Abschnitt 19.3.3 des PRD nachgewiesen sind.

## 10. Schritt 3.3.4 – App-spezifische Profile

### Daten und Auflösung

- `AppDictationProfile` und versionierten `AppProfileStore` implementieren.
- Zuordnung ausschließlich über Bundle-ID.
- Globale Werte bleiben Grundlage; `nil` bedeutet Vererbung.
- Effektive Konfiguration bei Aufnahmestart berechnen und für die Session einfrieren.
- Sprache, Modell, Schreibstil, Formatierung und Einfügungspräferenz überschreibbar machen.
- Gelöschte oder deaktivierte Stile sicher auf globale Werte zurückführen.

### Oberfläche

Unter **Settings → App Profiles**:

- zuletzt verwendete Ziel-Apps ohne Fenstertitel anzeigen,
- Profil hinzufügen, bearbeiten, duplizieren, deaktivieren und löschen,
- geerbte und überschriebene Werte klar unterscheiden,
- effektive Konfiguration zusammenfassen,
- optional Import/Export nach validiertem JSON-Schema.

### Tests und Gate

- Vererbungs- und Prioritätsregeln vollständig testen,
- zwei unterschiedliche Ziel-Apps manuell prüfen,
- Profilwechsel während einer laufenden Aufnahme beeinflusst die Session nicht,
- FlowDictate selbst kann kein Zielprofil sein.

## 11. Schritt 3.3.5 – Einfügung und Hotkey-Modi

### 11.1 Direkte Accessibility-Einfügung

Strategie:

```text
AX Direct Insert
    ↓ nicht unterstützt oder sicher fehlgeschlagen
Clipboard Paste mit Wiederherstellung
    ↓ fehlgeschlagen
Text im Clipboard belassen und Benutzer informieren
```

Aufgaben:

- fokussiertes AX-Element unmittelbar vor der Einfügung neu bestimmen,
- editierbare Rollen und aktuelle Auswahl erkennen,
- Auswahl korrekt ersetzen und Cursorposition nachvollziehbar setzen,
- Passwortfelder und geschützte Eingaben ablehnen,
- Größenlimit für direkte AX-Werte definieren,
- unbekanntes Ergebnis niemals automatisch ein zweites Mal einfügen,
- verwendete Strategie ohne Textinhalt in History/Diagnose ablegen,
- optional Kompatibilitätsausnahmen pro Bundle-ID anbieten.

### 11.2 Press-and-Hold

- Hotkey-Key-down startet genau eine Session,
- Key-up stoppt und verarbeitet,
- Mindesthaltedauer gegen versehentliche Auslösung,
- Key-repeat erzeugt keine zweite Aufnahme,
- Cancel/Escape verwendet den vorhandenen Abbruchpfad,
- Toggle bleibt als Standardmodus erhalten,
- fehlendes Key-up-Ereignis über einen sicheren Zustandsreset behandeln.

### Testmatrix und Gate

Mindestens Notes, Mail, Safari, Chrome, TextEdit, Word oder gleichwertig, VS Code, Xcode und Slack oder vergleichbar prüfen. Pro App: Auswahlersetzung, Mehrzeiler, Sonderzeichen, Fokus, AX-Einfügung und Clipboard-Fallback dokumentieren.

Press-and-Hold wird mit kurzem Tippen, langem Halten, Repeat, schnellem Wiederholen und Abbruch getestet.

## 12. Schritt 3.3.6 – Statistik, Update-Hinweis und Soll-Funktionen

### 12.1 Lokale Statistik

- heute, Woche und Gesamtzeit,
- erfolgreiche Diktate, Wörter und Zeichen,
- durchschnittliche Länge, Retry- und Erfolgsquote,
- geschätzte Tippzeit und Zeitersparnis,
- konfigurierbare Tippgeschwindigkeit, Default 40 Wörter/Minute,
- ausschließlich aus lokaler History berechnen,
- vollständig ausblendbar und nach History-Löschung sofort konsistent.

### 12.2 GitHub-Release-Hinweis

- `Hank1210/FlowDictate` über öffentliche GitHub-Releases prüfen,
- stabilen semantischen Versionsvergleich implementieren,
- Prereleases standardmäßig ignorieren,
- automatisch höchstens einmal täglich und zusätzlich manuell prüfen,
- Version, Kurzbeschreibung und Link anzeigen,
- **Release Page öffnen** und **Later** anbieten,
- keine automatische Installation und keinen GitHub-API-Key verwenden,
- Netzwerkfehler unaufdringlich behandeln.

### 12.3 Soll-Funktionen

Jede Soll-Funktion erhält eine einzelne Go/No-Go-Entscheidung:

- Mixed Audio nach dem Gate aus Schritt 3.3.3,
- fortlaufende Diktierkette mit getrennten History-Einträgen,
- Bulk-Export mit Manifest und optionalen Audiodateien,
- Profilimport/-export,
- AX-Kompatibilitätsausnahmen.

Nicht freigegebene Funktionen werden dokumentiert und nicht halb sichtbar ausgeliefert.

## 13. Schritt 3.3.7 – Gesamtregression und Release

### Automatisierte Prüfung

- vollständige Unit- und Integrationstests,
- `git diff --check`, Debug- und Release-Build,
- Schema- und Migrationstests mit 2.x-, 3.1- und 3.2-Testdaten,
- kein Netzwerkzugriff bei deaktiviertem Update-Check,
- keine OpenAI-Anfrage beim Systemaudio-Test,
- keine doppelten Einfügungen in allen Fallback-Szenarien.

### Manueller Referenz-Mac-Test

- frische Installation und Update von 3.2.0,
- Mikrofon- und Systemaudioaufnahme mit Preview an/aus,
- Berechtigungen erlaubt, verweigert, entzogen und erneut erteilt,
- kurze, fünfminütige und 30-minütige Aufnahme,
- Ausgabegerätewechsel vor und während Systemaudioaufnahme,
- Restore, Retry, Recovery und History für beide Pflichtquellen,
- Settings/History während und nach Aufnahme,
- Ziel-App- und Einfügungsmatrix,
- Toggle und Press-and-Hold,
- Statistik nach Aufnahme und Löschung,
- Updateprüfung online und offline,
- Light/Dark Mode, Reduced Motion und mehrere Displays.

### Dokumentation und Veröffentlichung

- `README.md`, `CHANGELOG.md`, `PRIVACY.md` und Installationsanleitungen DE/EN aktualisieren,
- Berechtigungen und Systemaudio-Einwilligung verständlich erklären,
- Release Notes und bekannte Einschränkungen erstellen,
- Community-ZIP und SHA-256-Datei erzeugen und prüfen,
- Version/Build erhöhen,
- Commit, Tag und GitHub Release erst nach manueller Freigabe.

## 14. Abnahmekriterien

Phase 3.3 ist abgeschlossen, wenn:

1. Mikrofon und Systemaudio jeweils eine valide, transkribierbare lokale Datei erzeugen.
2. Bestehende Installationen nach Migration im Mikrofonmodus bleiben.
3. Fehlende Systemaudiofreigabe keine stille oder scheinbar erfolgreiche Aufnahme erzeugt.
4. Keine Bild- oder Videodaten aus ScreenCaptureKit gespeichert werden.
5. Quelle, Pegel und Status in Settings, Overlay und History eindeutig sind.
6. Der Systemaudio-Test kein Netzwerk, keine History und keine dauerhafte Datei hinterlässt.
7. Preview-Ausfälle Aufnahme und finale Transkription nicht gefährden.
8. Restore, Retry und Recovery für beide Pflichtquellen funktionieren.
9. Mindestens zwei App-Profile unterschiedliche effektive Einstellungen anwenden.
10. AX-Einfügung und Clipboard-Fallback in der Ziel-App-Matrix dokumentiert sind.
11. Passwortfelder nicht beschrieben und unbekannte Ergebnisse nicht doppelt eingefügt werden.
12. Press-and-Hold keine parallelen oder doppelten Sessions erzeugt.
13. Statistik ausschließlich lokal berechnet und vollständig ausblendbar ist.
14. Updateprüfung stabile Versionen korrekt erkennt und Fehler die App nicht blockieren.
15. Alle 3.1- und 3.2-Kernfunktionen die Gesamtregression bestehen.

## 15. Risiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| ScreenCaptureKit-Freigabe ist für Community-Builds instabil | früher Prototyp, Mikrofon bleibt Default, klare Reparaturanleitung |
| Systemaudio liefert leere oder geschützte Streams | Pegel-/Dateivalidierung und verständlicher Fehler statt Stummaufnahme |
| Formatkonvertierung blockiert Capture-Callback | begrenzte Queue und Worker außerhalb des Callbacks |
| Mixed Audio driftet oder clippt | eigenes Gate; nicht veröffentlichen, wenn Langzeittest scheitert |
| History-/Settings-Migration beschädigt Nutzerdaten | additive Felder, sichere Defaults, Fixture-Tests und Backup vor Schemawechsel |
| AX-Einfügung verhält sich je App unterschiedlich | Strategiekette, App-Matrix, keine automatische Doppeleinfügung |
| Profile machen Verhalten schwer nachvollziehbar | effektive Konfiguration sichtbar machen und bei Start einfrieren |
| Statistik belastet große History | aggregiert und außerhalb häufiger UI-Updates berechnen |
| Updateprüfung wirkt wie Telemetrie | deaktivierbar, maximal täglich, Datenschutztext und kein versteckter Download |
| Umfang von 3.3 wird zu groß | Pflichtumfang zuerst; Soll-Funktionen mit getrennten Go/No-Go-Gates |

## 16. Vorgeschlagene Commit-Struktur

1. `Stabilize Phase 3.2 baseline`
2. `Add audio source models and migration`
3. `Add ScreenCaptureKit system audio recording`
4. `Integrate audio sources with preview and history`
5. `Add app-specific dictation profiles`
6. `Add direct accessibility insertion`
7. `Add press-and-hold dictation mode`
8. `Add local usage statistics`
9. `Add GitHub release notifications`
10. `Complete Phase 3.3 documentation and release`

Optionale Funktionen erhalten eigene Commits und werden nicht mit den Pflichtpaketen vermischt.
