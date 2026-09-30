# Product Requirements Document: FlowDictate Phase 2

**Version:** 2.0 Draft 1  
**Datum:** 17. August 2026  
**Produkt:** FlowDictate  
**Phase:** Phase 2 – Standalone, Reliability & Recovery  
**Zielplattform:** macOS 14 oder neuer  
**Technologie:** Swift, SwiftUI, AppKit, AVFoundation, Accessibility APIs  
**Status:** Umsetzungsgrundlage

---

## 1. Zweck dieses Dokuments

Dieses Dokument definiert Phase 2 von FlowDictate so konkret, dass die Umsetzung ohne weitere grundlegende Produktentscheidungen begonnen werden kann.

Phase 2 entwickelt die bestehende Phase-1-Anwendung von einem funktionierenden Entwicklungsstand zu einer zuverlässigen, installierbaren Standalone-App weiter. Die App soll anschließend:

- auf mehreren Macs desselben Benutzers installiert werden können,
- an Freunde oder andere Testpersonen weitergegeben werden können,
- beim ersten Start vollständig eingerichtet werden,
- API-Zugangsdaten sicher speichern,
- einen benutzerbestimmten Speicherort für Aufnahmen verwenden,
- jede beendete Aufnahme dauerhaft registrieren,
- Diktate nach Fehlern oder Abstürzen wiederherstellen können,
- fehlgeschlagene Transkriptionen wiederholen können und
- die letzte erfolgreiche Diktierung erneut einfügen können.

Dieses PRD ersetzt nicht das allgemeine `FlowDictate_PRD_v1.1.md`, sondern präzisiert dessen Phase 2.

---

## 2. Aktueller Stand

Phase 1 enthält bereits:

- native macOS-Menüleisten-App,
- globalen Start-/Stop-Hotkey,
- separaten Abbruch-Hotkey,
- Mikrofonaufnahme und Pegelanzeige,
- Auswahl des Eingabegeräts,
- lokale WAV-Dateien,
- OpenAI-Transkription,
- API-Key-Ablage im macOS-Schlüsselbund,
- konfigurierbare Transkriptionssprache und Modellbezeichnung,
- Fokusaufnahme beim Start der Diktierung,
- clipboard-sichere Einfügung,
- nicht aktivierendes Status-Overlay,
- Berechtigungsprüfung für Mikrofon und Accessibility,
- Start bei Anmeldung und
- automatisierte Basistests.

### 2.1 Tatsächlicher aktueller Audiospeicherort

Der aktuelle Code speichert Audiodateien nicht im Git-Projektordner, sondern unter:

```text
~/Library/Application Support/FlowDictate/Recordings
```

Dieser Pfad ist technisch für App-Daten geeignet, für Benutzer jedoch schlecht sichtbar und nicht frei wählbar. Phase 2 führt deshalb einen sichtbaren und dauerhaft konfigurierbaren Aufnahmeordner ein.

### 2.2 Aktuelle Lücken

- Es gibt keinen Erststart-Assistenten.
- Ein fehlender API-Key wird erst beim Start einer Diktierung bemerkt.
- Der Aufnahmeordner ist nicht konfigurierbar.
- Es gibt keine persistente Diktathistorie.
- Zwischen Aufnahmeende und erfolgreicher Einfügung existiert kein dauerhaft gespeicherter Prozesszustand.
- Ein App-Absturz während der Transkription kann eine verwaiste Aufnahme hinterlassen.
- Fehlgeschlagene Transkriptionen können nicht aus der App wiederholt werden.
- Die letzte Diktierung kann nicht komfortabel erneut eingefügt werden.
- Fehler werden nicht ausreichend nach Ursache und Wiederholbarkeit unterschieden.
- Es gibt noch keinen verteilbaren, dokumentierten Release-Prozess.

---

## 3. Produktziel

Phase 2 macht FlowDictate zu einer verlässlichen persönlichen Standalone-Diktierlösung für macOS.

Der Benutzer soll die App auf einem neuen Mac installieren, einen kurzen Einrichtungsassistenten durchlaufen und anschließend ohne Xcode, Terminal, Umgebungsvariablen oder Zugriff auf das Projektverzeichnis diktieren können.

### 3.1 Phase-2-Leitsatz

> Sobald eine Aufnahme beendet wurde, darf sie durch Netzwerkfehler, API-Fehler, Einfügungsfehler oder einen App-Absturz nicht mehr verloren gehen.

### 3.2 Exit-Kriterium

Phase 2 ist abgeschlossen, wenn:

1. eine signierte Standalone-App auf einem zweiten Mac installiert und eingerichtet werden kann,
2. die Einrichtung API-Key, Aufnahmeordner und Berechtigungen abdeckt,
3. jede beendete Aufnahme sofort einen persistenten History-Eintrag besitzt,
4. fehlgeschlagene Diktate in der History auffindbar sind,
5. eine Transkription wiederholt werden kann,
6. ein erfolgreiches Diktat erneut eingefügt werden kann und
7. ein temporärer API-, Netzwerk- oder Einfügungsfehler keinen Verlust verursacht.

---

## 4. Zielgruppen

### 4.1 Primär

- Eigentümer und Entwickler von FlowDictate
- Nutzung auf mehreren eigenen Macs
- tägliche Diktierung auf Deutsch, Englisch und gemischt

### 4.2 Sekundär

- Freunde und private Testpersonen
- Personen ohne Xcode- oder Entwicklerkenntnisse
- Personen mit eigenem OpenAI-API-Key

### 4.3 Nicht vorgesehen in Phase 2

- öffentliche App-Store-Veröffentlichung,
- zentral verwaltete Benutzerkonten,
- von FlowDictate bereitgestellte oder gemeinsam genutzte API-Keys,
- Abonnement- oder Bezahlsystem,
- Cloud-Synchronisierung zwischen Macs,
- zentrale Speicherung von Audio oder History,
- Team- oder Organisationsverwaltung.

---

## 5. Produktprinzipien

### 5.1 Bring Your Own Key

Jede Installation verwendet den API-Key des jeweiligen Benutzers. FlowDictate liefert keinen eingebetteten oder gemeinsamen Schlüssel aus.

### 5.2 Local First

Audio, History, Einstellungen und Logs werden lokal gespeichert. Audio wird nur für die vom Benutzer ausgelöste Transkription an den ausgewählten Anbieter übertragen.

### 5.3 Recovery First

Die Aufnahme und der History-Eintrag werden vor externen API-Aufrufen dauerhaft gespeichert.

### 5.4 Explizite Kontrolle

Der Benutzer kennt und kontrolliert:

- den Aufnahmeordner,
- die Aufbewahrungsdauer,
- den verwendeten API-Key,
- Retry- und Löschaktionen und
- den Export eigener Daten.

### 5.5 Keine Entwicklerabhängigkeit

Die App darf im normalen Betrieb keine `.env`-Datei, Xcode-Scheme-Einstellung, Projektdatei oder Terminal-Konfiguration benötigen.

---

## 6. Umfang von Phase 2

### 6.1 Muss-Funktionen

- Erststart-Assistent
- API-Key-Erfassung und sichere Speicherung
- API-Key-Prüfung
- Wahl und dauerhafte Autorisierung des Aufnahmeordners
- empfohlener Standardordner `~/Documents/Recordings`
- nachträglicher Wechsel des Aufnahmeordners
- persistente Diktathistorie
- persistente Verarbeitungszustände
- Crash- und Orphan-Recovery
- Retry Transcription
- Restore Last Dictation
- Audio-Wiedergabe und Datei anzeigen
- verständliche Fehlerklassifizierung
- Aufbewahrungsregeln
- strukturierte lokale Logs
- Standalone-Release-Build
- Installations- und Update-fähige Versionsstruktur

### 6.2 Soll-Funktionen

- Suche und Filter in der History
- Export einzelner oder mehrerer Diktate
- Diagnosepaket ohne sensible Inhalte
- Menüleistenliste der letzten Diktate
- optionale Start-/Stop-/Erfolg-/Fehlertöne
- automatischer Retry für eindeutig temporäre Fehler

### 6.3 Nicht Bestandteil dieser Phase

- lokale Speech-to-Text-Modelle,
- Streaming-Transkription und Live-Text,
- Schreibstile und LLM-Nachbearbeitung,
- persönliches Wörterbuch,
- Per-App-Promptprofile,
- Command Mode,
- Rewrite Mode,
- Meeting-Transkription,
- Sprechererkennung,
- Statistiken über einfache History-Zähler hinaus,
- automatische Updates über einen externen Update-Feed.

Die Architektur darf diese späteren Funktionen nicht verhindern.

---

## 7. Erststart und Onboarding

### 7.1 Auslöser

Der Onboarding-Assistent wird angezeigt, wenn mindestens eine Bedingung erfüllt ist:

- Es wurde noch keine Onboarding-Version als abgeschlossen gespeichert.
- Es ist kein nutzbarer API-Key vorhanden.
- Es ist kein gültiger Aufnahmeordner autorisiert.
- Eine verpflichtende Migration für eine neue Hauptversion ist offen.

Ein vorhandener gültiger Schlüsselbund-Eintrag soll bei Neuinstallation erkannt werden. Der API-Key muss dann nicht erneut eingegeben werden; der Benutzer bestätigt nur, dass er diesen weiterverwenden möchte.

### 7.2 Ablauf

#### Schritt 1: Willkommen

Inhalt:

- kurze Erklärung des Workflows,
- Hinweis, dass FlowDictate im Hintergrund über die Menüleiste läuft,
- Hinweis auf lokale Speicherung und externe OpenAI-Transkription,
- Link zu Datenschutzinformationen.

Aktion: **Einrichtung starten**

#### Schritt 2: Aufnahmeordner

Anzeige:

- Empfehlung: `~/Documents/Recordings`
- Beschreibung, dass Aufnahmen und zugehörige Dateien dort lokal gespeichert werden
- aktueller freier Speicher, sofern einfach verfügbar

Aktionen:

- **Empfohlenen Ordner verwenden**
- **Anderen Ordner auswählen…**

Verhalten des empfohlenen Pfads:

1. Der Ordnerauswahldialog startet im Benutzerordner `Documents`.
2. Wenn `Recordings` noch nicht existiert, darf FlowDictate ihn nach Bestätigung anlegen.
3. Der Benutzer bestätigt den Ordner über den macOS-Systemdialog.
4. FlowDictate speichert ein Security-Scoped Bookmark.

Der Systemdialog ist erforderlich, weil die App sandboxed bleibt und keinen stillen dauerhaften Schreibzugriff auf beliebige Benutzerordner erhalten soll.

#### Schritt 3: OpenAI API-Key

Inhalt:

- SecureField für den Key,
- kurze Erklärung, wo der Key erstellt wird,
- Hinweis auf nutzungsabhängige OpenAI-Kosten,
- Hinweis, dass der Key ausschließlich im macOS-Schlüsselbund gespeichert wird,
- Hinweis, dass jeder Benutzer seinen eigenen Key benötigt.

Aktionen:

- **Verbindung prüfen und sicher speichern**
- **Vorhandenen Key verwenden**, wenn bereits einer im Schlüsselbund existiert

Validierung:

- leere oder nur aus Leerzeichen bestehende Werte ablehnen,
- offensichtliche Formatfehler lokal melden,
- anschließend über die Provider-Abstraktion eine authentifizierte, möglichst kostengünstige Validierung ausführen,
- bei Erfolg im Schlüsselbund speichern,
- bei Authentifizierungsfehler nicht als gültig markieren,
- bei Offline-/Timeout-Fehler eine erneute Prüfung anbieten; der Assistent darf nicht fälschlich „Key ungültig“ anzeigen.

Der Key darf niemals in UserDefaults, History, Logs, Exporten oder Diagnosepaketen gespeichert werden.

#### Schritt 4: Mikrofon

- Mikrofonberechtigung anfordern,
- Eingabegerät auswählen,
- Live-Pegel anzeigen,
- verständlichen Weg zu den Systemeinstellungen anbieten, wenn die Berechtigung abgelehnt wurde.

#### Schritt 5: Accessibility

- erklären, warum die Berechtigung benötigt wird,
- Berechtigungsdialog bzw. Systemeinstellungen öffnen,
- Status nach Rückkehr automatisch aktualisieren,
- keine zusätzliche Berechtigung anfordern, die für Phase 2 nicht gebraucht wird.

#### Schritt 6: Hotkeys und Test

- Start-/Stop-Hotkey anzeigen und änderbar machen,
- Abbruch-Hotkey anzeigen und änderbar machen,
- Restore-Last-Hotkey anzeigen und änderbar machen,
- kurze Testaufnahme durchführen,
- Ergebnis im Assistenten anzeigen,
- Testtext nur nach expliziter Aktion in ein Testfeld einfügen.

#### Schritt 7: Abschluss

- Zusammenfassung der Konfiguration,
- Schalter „Bei Anmeldung starten“,
- Schaltfläche **FlowDictate starten**.

### 7.3 Abbruch und Fortsetzung

- Der Assistent kann geschlossen werden.
- Nicht abgeschlossene Schritte bleiben gespeichert.
- Ohne API-Key oder gültigen Aufnahmeordner darf keine echte Diktierung gestartet werden.
- Das Menü zeigt in diesem Zustand gut sichtbar **Einrichtung fortsetzen…**.

### 7.4 Erneutes Öffnen

Unter **Settings → General** steht jederzeit **Einrichtungsassistent erneut öffnen…** zur Verfügung.

---

## 8. Aufnahmeordner und Dateiverwaltung

### 8.1 Benutzeranforderung

Der Aufnahmeordner ist bei der Erstinstallation frei wählbar. Als empfohlener Standard wird ein Ordner mit dem Namen `Recordings` im persönlichen Dokumente-Ordner verwendet:

```text
~/Documents/Recordings
```

„Standard“ bedeutet, dass dieser Ort im Onboarding vorausgewählt und empfohlen wird. Wegen der macOS-Sandbox muss der Benutzer ihn einmalig über den Systemdialog bestätigen.

### 8.2 Sandbox-Anforderungen

Die Release-App bleibt sandboxed.

Erforderlich:

- Berechtigung für benutzergewählte Dateien und Ordner mit Lese- und Schreibzugriff,
- `ENABLE_USER_SELECTED_FILES = readwrite`,
- persistentes Security-Scoped Bookmark für den ausgewählten Ordner,
- Aufruf von `startAccessingSecurityScopedResource()` nur für die notwendige Dauer,
- garantiertes `stopAccessingSecurityScopedResource()` nach Zugriff,
- Erneuerung eines veralteten Bookmarks,
- verständliche Reparaturaktion, wenn die Autorisierung verloren ging.

Das Bookmark wird in den lokalen Einstellungen gespeichert. Es enthält keinen API-Key und darf nicht in normale Support-Logs geschrieben werden.

### 8.3 Ordnerstruktur

Im ausgewählten Stammordner verwaltet FlowDictate:

```text
Recordings/
├── Audio/
│   └── 2026/
│       └── 08/
│           └── 2026-08-17T14-32-10Z_<UUID>.wav
├── Exports/
└── Recovery/
```

Entscheidung für Phase 2:

- Die History-Datenbank liegt nicht im frei gewählten Aufnahmeordner, sondern im App-Container unter Application Support.
- Im Aufnahmeordner liegen Audio und vom Benutzer erzeugte Exporte.
- `Recovery` ist für gefundene oder nicht eindeutig zuordenbare Aufnahmen vorgesehen.
- Die App darf ihre Datenbank nicht verlieren, wenn der Benutzer den Aufnahmeordner über Finder verschiebt oder zeitweise ein externes Laufwerk trennt.

### 8.4 Dateinamen

Dateinamen enthalten:

- UTC-Zeitstempel,
- unveränderliche UUID,
- Dateierweiterung.

Sie enthalten niemals:

- Transkripttext,
- App- oder Fensternamen,
- Benutzernamen,
- API-Anbieter oder
- andere sensible Inhalte.

### 8.5 Atomare Aufnahme

- Eine neue Aufnahme wird zunächst mit temporärer Erweiterung, beispielsweise `.recording`, angelegt.
- Nach erfolgreichem Schließen des Audiofiles wird sie atomar in `.wav` umbenannt.
- Unvollständige temporäre Dateien werden beim nächsten Start geprüft und im Recovery Center angezeigt oder als nicht lesbar markiert.

### 8.6 Wechsel des Speicherorts

Unter **Settings → Storage** stehen zur Verfügung:

- aktueller Pfad,
- **Im Finder anzeigen**,
- **Speicherort ändern…**,
- Aufbewahrungsregeln,
- aktuell belegter Speicher.

Beim Wechsel fragt FlowDictate:

- **Vorhandene Aufnahmen verschieben** oder
- **Vorhandene Aufnahmen am alten Ort belassen**.

Verschieben:

- läuft als nachvollziehbarer Hintergrundvorgang,
- kopiert zuerst und prüft anschließend Dateigröße beziehungsweise Lesbarkeit,
- aktualisiert danach die History-Pfade,
- löscht Quelldateien erst nach erfolgreicher Prüfung,
- ist nach Fehlern fortsetzbar,
- zeigt Fortschritt und Fehler an.

### 8.7 Nicht verfügbarer Speicherort

Beispiele:

- externes Laufwerk nicht verbunden,
- Ordner verschoben oder gelöscht,
- Bookmark ungültig,
- Schreibrechte entzogen,
- Datenträger voll.

Verhalten:

- keine Aufnahme starten, wenn keine sichere Dateiablage gewährleistet ist,
- konkrete Fehlermeldung anzeigen,
- Aktionen **Erneut versuchen** und **Ordner neu auswählen…** anbieten,
- niemals still auf einen anderen Ordner ausweichen,
- optional kann der Benutzer explizit einen temporären App-Container als neuen Speicherort bestätigen.

### 8.8 Migration des Phase-1-Ordners

Beim ersten Phase-2-Start wird geprüft:

```text
~/Library/Application Support/FlowDictate/Recordings
```

Wenn dort Audiodateien vorhanden sind:

- Anzahl und Gesamtgröße anzeigen,
- **In neuen Aufnahmeordner übernehmen** anbieten,
- jede Datei als vorhandenes Diktat oder Recovery-Eintrag registrieren,
- keine Datei ohne bestätigte und verifizierte Migration löschen,
- Migration protokollieren, jedoch ohne Transcriptinhalte.

---

## 9. Persistente Diktathistorie

### 9.1 Grundsatz

Für jede beendete Aufnahme wird ein History-Eintrag dauerhaft gespeichert, bevor Transkription oder Einfügung beginnen.

### 9.2 Datenmodell `DictationRecord`

Pflichtfelder:

| Feld | Typ | Beschreibung |
|---|---|---|
| `id` | UUID | Identisch mit der Aufnahme-ID |
| `createdAt` | Date | Erzeugung des Datensatzes |
| `recordingStartedAt` | Date | Aufnahmebeginn |
| `recordingEndedAt` | Date | Aufnahmeende |
| `duration` | Double | Dauer in Sekunden |
| `status` | Enum | Persistenter Verarbeitungsstatus |
| `audioRelativePath` | String | Relativer Pfad innerhalb des Aufnahmeordners |
| `audioFileSize` | Int64 | Größe zur Integritätsprüfung |
| `originalTranscript` | String? | Unverändertes Provider-Ergebnis |
| `finalText` | String? | In Phase 2 identisch zum Original, später verarbeitet |
| `providerID` | String | Beispielsweise `openai` |
| `modelID` | String | Verwendetes Modell |
| `language` | String? | Konfigurierte oder erkannte Sprache |
| `targetBundleIdentifier` | String? | Ziel-App, kein Fenstertitel |
| `targetApplicationName` | String? | Anzeigename der Ziel-App |
| `insertionStatus` | Enum | Einfügeergebnis |
| `attemptCount` | Int | Anzahl Transkriptionsversuche |
| `lastAttemptAt` | Date? | Letzter Versuch |
| `errorCategory` | Enum? | Normalisierte Fehlerklasse |
| `errorCode` | String? | Nicht sensibler technischer Code |
| `errorMessage` | String? | Nutzerverständliche Meldung |
| `cancelled` | Bool | Vom Benutzer abgebrochen |
| `updatedAt` | Date | Letzte Änderung |
| `schemaVersion` | Int | Datenmodellmigration |

Optionale spätere Felder werden bereits architektonisch berücksichtigt:

- Writing Style,
- verarbeitetes Transcript,
- geschätzte Kosten,
- Qualitäts-/Halluzinationsflags,
- Per-App-Profil,
- Cloud-/Local-Provider-Metadaten.

### 9.3 Persistente Statusmaschine

```text
recording
   ↓
recorded
   ↓
transcribing ─────────────→ transcriptionFailed
   ↓                              │
transcribed                       └── Retry → transcribing
   ↓
inserting ─────────────────→ insertionFailed
   ↓                              │
completed                         └── Reinsert → inserting
```

Zusätzliche End-/Sonderzustände:

- `cancelled`
- `audioMissing`
- `audioCorrupt`
- `recovered`

Regeln:

- Jeder Statuswechsel wird atomar gespeichert.
- `recorded` muss vor dem ersten Netzwerkanruf gespeichert sein.
- Ein Status darf nicht allein im UI-State existieren.
- Ein Retry überschreibt nicht das bereits vorhandene Audio.
- Eine erfolgreiche frühere Transkription wird nicht gelöscht, wenn eine spätere Einfügung fehlschlägt.

### 9.4 Persistenztechnologie

Die Implementierung verwendet eine lokale, versionierte Datenbank hinter einem Protokoll:

```swift
protocol DictationHistoryStoring {
    func create(_ record: DictationRecord) async throws
    func update(_ record: DictationRecord) async throws
    func record(id: UUID) async throws -> DictationRecord?
    func recent(limit: Int) async throws -> [DictationRecord]
    func search(_ query: HistoryQuery) async throws -> [DictationRecord]
    func delete(id: UUID) async throws
}
```

SwiftData ist wegen des Mindestziels macOS 14 zulässig. Alternativ ist SQLite zulässig, wenn Migrationen und Tests dadurch kontrollierbarer werden. UI und Coordinator dürfen nicht direkt von der gewählten Datenbanktechnologie abhängen.

### 9.5 History-Fenster

Das Fenster ist erreichbar über:

- Menüleiste → **History…**,
- Settings/Onboarding-Recovery-Hinweise,
- Fehlermeldungen mit Aktion **In History anzeigen**.

Liste zeigt:

- Datum und Uhrzeit,
- Textvorschau,
- Dauer,
- Ziel-App,
- Statussymbol,
- Fehlerhinweis,
- Audioverfügbarkeit.

Detailansicht bietet abhängig vom Status:

- Audio abspielen/pausieren,
- vollständiges Transcript anzeigen,
- Transcript kopieren,
- erneut am aktuellen Cursor einfügen,
- Transkription wiederholen,
- Audiodatei im Finder anzeigen,
- Audio/Text exportieren,
- Eintrag löschen.

### 9.6 Suche und Filter

Suche über:

- Originaltranskript,
- finalen Text,
- Datum,
- Ziel-App.

Filter:

- alle,
- erfolgreich,
- Transkription fehlgeschlagen,
- Einfügung fehlgeschlagen,
- abgebrochen,
- Recovery erforderlich.

---

## 10. Recovery und App-Neustart

### 10.1 Startprüfung

Bei jedem App-Start:

1. Datenbankmigration ausführen.
2. Aufnahmeordner-Berechtigung wiederherstellen.
3. Datensätze in nicht abgeschlossenen Zuständen prüfen.
4. Audioordner nach Dateien ohne History-Eintrag durchsuchen.
5. History-Einträge auf fehlende Audiodateien prüfen.
6. notwendige Recovery-Aktionen erzeugen.

### 10.2 Wiederaufnahmefähige Zustände

- `recorded`: Retry Transcription anbieten.
- `transcribing`: nach Absturz in `transcriptionFailed` mit Kategorie `interrupted` überführen.
- `transcribed`: erneute Einfügung anbieten.
- `inserting`: nach Absturz als `insertionUnknown` behandeln; nicht automatisch erneut einfügen, da eine Doppeleinfügung möglich ist.
- `.recording`-Temporärdatei: Integrität prüfen und als Recovery-Aufnahme registrieren.

### 10.3 Keine automatische Doppeleinfügung

Wenn unklar ist, ob Text vor dem Absturz bereits eingefügt wurde, darf FlowDictate nicht automatisch erneut einfügen. Der Benutzer entscheidet über **Kopieren** oder **Erneut einfügen**.

---

## 11. Retry Transcription

### 11.1 Manueller Retry

Verfügbar für Datensätze mit vorhandener, lesbarer Audiodatei und ohne laufenden Versuch.

Vor dem Retry:

- Aufnahmeordnerzugriff prüfen,
- Datei prüfen,
- API-Key-Verfügbarkeit prüfen,
- Provider und Modell anzeigen,
- Versuchszähler erhöhen.

### 11.2 Automatischer Retry

Standardmäßig maximal zwei automatische Wiederholungen bei:

- Netzwerkunterbrechung,
- Timeout,
- HTTP 429 unter Beachtung von `Retry-After`,
- temporären HTTP-5xx-Fehlern.

Kein automatischer Retry bei:

- fehlendem oder ungültigem API-Key,
- nicht unterstützter Audiodatei,
- beschädigter Datei,
- permanentem Clientfehler,
- explizitem Abbruch.

Der Benutzer kann automatische Retries in **Settings → Advanced** deaktivieren.

### 11.3 Idempotenz

- Es darf pro Dictat nur ein aktiver Transkriptionsversuch existieren.
- Mehrfachklicks erzeugen keine parallelen Requests.
- Das Ergebnis des letzten erfolgreichen Versuchs wird gespeichert.
- Vorherige Fehlermetadaten dürfen für Diagnosezwecke erhalten bleiben, sensible Serverantworten jedoch nicht.

---

## 12. Restore Last Dictation und erneute Einfügung

### 12.1 Hotkey

Vorgabe:

```text
Option + Shift + Z
```

Der Hotkey ist konfigurierbar und wird wie bestehende Hotkeys auf Konflikte geprüft.

### 12.2 Verhalten

- verwendet das letzte Diktat mit nicht leerem finalen Text,
- erfasst beim Auslösen das aktuell fokussierte Ziel,
- fügt nicht in FlowDictate selbst ein,
- verwendet die reguläre Textinserter-Abstraktion,
- verändert weder Audio noch Transcript,
- speichert den Einfügeversuch im History-Eintrag.

### 12.3 Zusätzliche Wege

- History → **Erneut einfügen**
- Menüleiste → letztes Diktat → **Erneut einfügen**
- History → **Kopieren** als sicherer Fallback

### 12.4 Einfügungsfehler

Bei Fehler:

- Transcript bleibt erhalten,
- Zwischenablage wird soweit sicher möglich wiederhergestellt,
- **Kopieren**, **Erneut versuchen** und **In History anzeigen** werden angeboten.

---

## 13. Clipboard- und Einfügungszuverlässigkeit

### 13.1 Bestehende Strategie

Die Phase-1-Strategie bleibt zunächst erhalten:

1. Clipboard vollständig sichern,
2. Transcript setzen,
3. Paste-Event senden,
4. konfigurierte Wartezeit einhalten,
5. Clipboard wiederherstellen.

### 13.2 Konfliktschutz

Phase 2 ergänzt:

- `NSPasteboard.changeCount` vor und nach FlowDictate-Änderungen verfolgen,
- Clipboard nur wiederherstellen, wenn es seit dem FlowDictate-Paste nicht durch Benutzer oder eine andere App verändert wurde,
- bei Konflikt den neuen Clipboard-Inhalt unangetastet lassen,
- den ursprünglichen Snapshot kurzzeitig im Speicher halten und optional eine manuelle Wiederherstellung anbieten,
- keine Clipboard-Inhalte in Logs oder History speichern.

### 13.3 Erweiterbare Einfügungsstrategie

```swift
protocol TextInsertionStrategy {
    func canInsert(into target: FocusTarget) async -> Bool
    func insert(_ text: String, into target: FocusTarget) async throws
}
```

Strategiereihenfolge:

1. direkte Accessibility-Einfügung, wenn zuverlässig unterstützt,
2. Clipboard/Paste-Fallback,
3. Transcript kopieren und Benutzer informieren.

Direkte Accessibility-Einfügung darf erst Standard werden, wenn sie in den Ziel-Apps manuell verifiziert wurde.

---

## 14. Fehlerbehandlung

### 14.1 Fehlerkategorien

| Kategorie | Beispiele | Nutzeraktion |
|---|---|---|
| `configuration` | Onboarding offen, kein Ordner | Einrichtung fortsetzen |
| `credentialMissing` | kein API-Key | Key hinterlegen |
| `authentication` | ungültiger/entzogener Key | Key ersetzen |
| `permission` | Mikrofon/Accessibility fehlt | Systemeinstellungen öffnen |
| `storageUnavailable` | Ordner fehlt, Bookmark ungültig | Ordner neu auswählen |
| `storageFull` | Datenträger voll | Speicher freigeben/Ordner wechseln |
| `audioDevice` | Mikrofon getrennt | Gerät auswählen/Retry |
| `audioCorrupt` | Datei nicht lesbar | Datei anzeigen/exportieren |
| `network` | offline, DNS, Verbindung | Retry |
| `timeout` | API antwortet nicht | Retry |
| `rateLimit` | HTTP 429 | später wiederholen |
| `providerTemporary` | HTTP 5xx | Retry |
| `providerPermanent` | ungültige Anfrage | Einstellungen prüfen |
| `insertion` | Ziel nicht verfügbar | kopieren/erneut einfügen |
| `clipboardConflict` | Clipboard extern geändert | neues Clipboard bewahren |
| `interrupted` | App-Absturz/Neustart | Recovery öffnen |

### 14.2 Fehlermeldungen

Jede Meldung enthält:

- eine kurze verständliche Überschrift,
- eine konkrete Ursache, soweit bekannt,
- Information, ob Audio und Transcript sicher gespeichert sind,
- mindestens eine passende Aktion,
- optional einen technischen Fehlercode für Support.

Schlechte Meldung:

```text
Error -1009
```

Gute Meldung:

```text
Keine Internetverbindung
Die Aufnahme wurde sicher gespeichert und kann später erneut transkribiert werden.
[Erneut versuchen] [In History anzeigen]
```

---

## 15. Aufbewahrung und Löschen

### 15.1 Standardeinstellungen

- History: unbegrenzt, bis der Benutzer eine Regel auswählt
- erfolgreiche Audiodateien: 30 Tage
- fehlgeschlagene/recovery-pflichtige Audiodateien: nicht automatisch löschen
- abgebrochene Aufnahmen: 7 Tage
- Logs: 14 Tage mit Größenlimit

Diese Defaults müssen im Onboarding nicht abgefragt werden, sind aber unter **Settings → Storage** sichtbar.

### 15.2 Optionen

Audioaufbewahrung:

- immer behalten,
- 7 Tage,
- 30 Tage,
- 90 Tage,
- nach erfolgreicher Transkription löschen.

Historyaufbewahrung:

- immer behalten,
- 30 Tage,
- 90 Tage,
- ein Jahr.

### 15.3 Schutzregeln

- Fehlgeschlagene und nicht zugeordnete Aufnahmen werden nicht automatisch gelöscht.
- Vor einer manuellen Massenlöschung werden Anzahl und Größe angezeigt.
- Löschen aus der History fragt, ob nur der Datensatz oder auch die Audiodatei gelöscht werden soll.
- API-Keys sind von History-Löschung unabhängig.

---

## 16. Logging und Diagnose

### 16.1 Logging

Zu protokollieren:

- App-Start und App-Version,
- Onboarding-Schrittstatus ohne eingegebene Inhalte,
- Wiederherstellung des Aufnahmeordnerzugriffs,
- Aufnahme Start/Stop mit UUID und Dauer,
- persistente Statuswechsel,
- Provider-Request Start/Ende ohne Audio/Transcript,
- Retry-Grund und Versuchszähler,
- Einfügestrategie und Ergebnis,
- Recovery-Funde,
- Migrationen,
- Fehlerkategorie und nicht sensibler Fehlercode.

Nie protokollieren:

- API-Key oder Fragmente davon,
- Authorization Header,
- vollständige Transkripte,
- Clipboard-Inhalte,
- Audioinhalte,
- Fenstertitel,
- Security-Scoped-Bookmark-Daten,
- vollständige Benutzerpfade in normalen Logs.

### 16.2 Diagnosepaket

Optionaler Export enthält:

- App-Version und Build,
- macOS-Version,
- anonymisierte relevante Einstellungen,
- Berechtigungsstatus,
- letzte strukturierte Logdateien,
- Datenbankschema-Version,
- Anzahl der History-Zustände.

Nicht enthalten:

- API-Key,
- Audio,
- Transcript,
- Clipboard,
- Bookmark-Daten,
- Benutzername.

Vor Export wird der Inhalt zusammengefasst und bestätigt.

---

## 17. Standalone-Distribution

### 17.1 Anforderungen

Die App muss ohne Xcode oder Repository funktionieren.

Release-Artefakt:

- `FlowDictate.app`,
- optional verpackt als signiertes DMG oder ZIP,
- stabile Bundle-ID,
- Release-Konfiguration,
- keine Entwicklungs-API-Keys,
- keine Abhängigkeit von `.env`,
- alle erforderlichen Assets und Frameworks eingebettet.

### 17.2 Signierung und Notarisierung

Für eine einfache Installation auf anderen Macs werden benötigt:

- Apple Developer ID Application Signing,
- Hardened Runtime, soweit kompatibel,
- Notarisierung durch Apple,
- Stapling des Notarisierungstickets,
- Prüfung mit Gatekeeper-Werkzeugen,
- dokumentierter Release-Prozess.

Falls zunächst nur ad-hoc oder Development-signierte Builds verteilt werden, muss dokumentiert werden, dass Gatekeeper- und Accessibility-Berechtigungen dadurch unzuverlässiger sein können. Das Phase-2-Ziel bleibt ein Developer-ID-signierter und notarisierter Build.

### 17.3 Stabile Identität

- Die Bundle-ID `de.euler.FlowDictate` bleibt für Release-Builds stabil, solange keine bewusste Produktmigration beschlossen wird.
- Keychain-Service, UserDefaults, Accessibility-Zulassung und App-Daten hängen an dieser Identität.
- Test-Bundles verwenden weiterhin getrennte Bundle-IDs.
- Release-Builds dürfen nicht versehentlich wechselnde Signaturen erhalten.

### 17.4 Mehrere Macs und mehrere Personen

Pro Installation beziehungsweise macOS-Benutzerkonto gelten separat:

- eigener API-Key im Schlüsselbund,
- eigener Aufnahmeordner,
- eigene History,
- eigene Hotkeys,
- eigene Berechtigungen,
- eigene Aufbewahrungsregeln.

Es gibt in Phase 2 keine Synchronisierung. Für einen zweiten Mac wird der Assistent erneut durchlaufen. Einstellungen können später über einen Export importiert werden; API-Keys werden grundsätzlich nicht exportiert.

### 17.5 Versions- und Migrationsstrategie

Zu speichern:

- `appVersionLastRun`,
- `onboardingSchemaVersion`,
- `historySchemaVersion`,
- `storageConfigurationVersion`.

Migrationen sind:

- wiederholbar oder eindeutig als abgeschlossen markiert,
- vor Datenänderungen gesichert,
- in Tests abgedeckt,
- bei Fehlern nicht destruktiv.

---

## 18. Einstellungen und Navigation

### 18.1 General

- Start bei Anmeldung
- Onboarding erneut öffnen
- App-Version
- Datenschutzinformation

### 18.2 Dictation

- Start-/Stop-Hotkey
- Abbruch-Hotkey
- Restore-Last-Hotkey
- optionale Sounds

### 18.3 Audio

- Eingabegerät
- Live-Pegel
- Mikrofontest

### 18.4 Transcription

- API-Key-Status
- API-Key ersetzen/löschen
- Verbindung prüfen
- Modell
- Sprache

Beim Löschen des Keys ist eine Bestätigung erforderlich. Bestehende Audio- und History-Daten bleiben erhalten.

### 18.5 Storage

- Aufnahmeordner
- Ordner ändern
- im Finder anzeigen
- Speicherverbrauch
- Audioaufbewahrung
- Historyaufbewahrung
- Phase-1-Aufnahmen migrieren

### 18.6 Advanced

- Clipboard-Wiederherstellungsdelay
- automatische Retries
- Log-Level
- Logs anzeigen
- Diagnosepaket exportieren

---

## 19. Menüleisten-UX

Vorgeschlagene Struktur:

```text
Status
Start/Stop Dictation
Cancel Dictation

Restore Last Dictation
Recent Dictations >
History…

Microphone >
Settings…
Setup fortsetzen…       (nur wenn erforderlich)

Quit FlowDictate
```

`Recent Dictations` zeigt maximal fünf Einträge und bietet:

- Textvorschau,
- kopieren,
- erneut einfügen,
- in History öffnen.

Fehlgeschlagene Einträge sind klar markiert.

---

## 20. Architekturänderungen

### 20.1 Neue Module

```text
FlowDictate
├── Onboarding
│   ├── OnboardingCoordinator
│   ├── OnboardingState
│   └── OnboardingViews
├── Storage
│   ├── RecordingLocationStore
│   ├── SecurityScopedBookmarkStore
│   ├── RecordingFileStore
│   ├── StorageMigrationService
│   └── RetentionService
├── History
│   ├── DictationRecord
│   ├── DictationHistoryStore
│   ├── HistoryRecoveryService
│   ├── HistoryViewModel
│   └── HistoryViews
├── Recovery
│   ├── RetryPolicy
│   ├── DictationRecoveryCoordinator
│   └── OrphanedRecordingScanner
├── Distribution
│   └── VersionMigrationService
└── Diagnostics
    ├── DiagnosticExportService
    └── RedactionPolicy
```

### 20.2 Coordinator-Aufteilung

Der bestehende `DictationCoordinator` darf nicht alle neuen Verantwortlichkeiten übernehmen.

Empfohlene Rollen:

- `DictationCoordinator`: Live-Aufnahmeablauf und UI-State
- `DictationPipeline`: persistente Schritte Aufnahme → Transkription → Einfügung
- `OnboardingCoordinator`: Erstinstallation
- `HistoryRepository`: Datenzugriff
- `RecordingFileStore`: Dateipfade und Schreibzugriff
- `RetryCoordinator`: Wiederholungen
- `RecoveryService`: Startprüfung und Reparatur
- `CredentialStore`: Schlüsselbund

### 20.3 Abhängigkeiten

Alle zentralen Services erhalten Protokolle und werden injizierbar gebaut. Dateisystem, Netzwerk, Zeit, UUID-Erzeugung und Datenbank sollen in Tests kontrollierbar sein.

### 20.4 Nebenläufigkeit

- Datenbank- und Dateizugriffe nicht auf dem Main Actor ausführen.
- UI-State auf dem Main Actor halten.
- Pro Diktat maximal eine Pipeline-Operation gleichzeitig.
- globale Aufnahme weiterhin gegen Doppelauslösung schützen.
- App-Beenden während einer Operation darf keinen inkonsistenten Datensatz erzeugen.

---

## 21. Datenschutz und Sicherheit

### 21.1 API-Key

- ausschließlich macOS Keychain,
- pro macOS-Benutzerkonto,
- nie im App-Bundle,
- nie im Git-Repository,
- nie in UserDefaults,
- nie in Exporten oder Logs,
- beim Anzeigen nur Status, nicht den vollständigen Wert zeigen.

### 21.2 Audio und Text

- lokal gespeichert,
- kein automatischer Upload außer zur angeforderten Transkription,
- keine Analytics mit Audio oder Text,
- keine Fenstertitel speichern,
- Ziel-App nur als Bundle-ID und Anzeigename speichern,
- Lösch- und Exportfunktionen bereitstellen.

### 21.3 Netzwerk

- ausschließlich HTTPS,
- keine Abschwächung der Transport Security,
- Secrets nur im Authorization Header,
- Serverantworten vor Logging redigieren,
- Timeouts definieren,
- Requests bei Benutzerabbruch abbrechen, soweit sicher möglich.

---

## 22. Nichtfunktionale Anforderungen

### 22.1 Zuverlässigkeit

- 0 verlorene erfolgreich geschlossene Aufnahmen
- 100 % der beendeten Aufnahmen erhalten vor API-Aufruf einen History-Eintrag
- Recovery erkennt nicht abgeschlossene Pipeline-Zustände beim nächsten Start
- ein Retry erzeugt keine parallelen Doppelrequests

### 22.2 Performance

- Aufnahmebeginn unter 300 ms nach Hotkey, sofern Berechtigungen und Speicher verfügbar sind
- History-Fenster mit 10.000 Einträgen innerhalb von 500 ms sichtbar
- History-Suche startet innerhalb von 200 ms nach Eingabe
- Idle CPU unter 1 %
- kein vollständiges Laden großer Audiodateien in den Main Thread

### 22.3 Barrierefreiheit

- alle Onboarding- und History-Bedienelemente besitzen zugängliche Labels,
- vollständige Keyboard-Bedienung,
- VoiceOver-kompatible Statusmeldungen,
- Status nicht nur über Farbe vermitteln,
- Systemschrift und Dynamic Type soweit unter macOS anwendbar respektieren.

### 22.4 Lokalisierung

Phase 2 darf zunächst englische UI-Texte behalten. Alle neuen sichtbaren Strings werden jedoch lokalisierbar angelegt. Deutsch soll als erste zusätzliche UI-Sprache ohne Architekturänderung ergänzt werden können.

---

## 23. Testanforderungen

### 23.1 Unit Tests

Mindestens:

- Onboarding-Zustandsübergänge,
- Erkennung vorhandener Keychain-Credentials,
- API-Key-Validierungsergebnisse,
- Bookmark speichern/wiederherstellen/veraltet/ungültig,
- Aufnahmeordner-Pfadbildung,
- Dateinamen ohne sensible Inhalte,
- atomare Dateifertigstellung,
- History CRUD,
- Statusmaschinenregeln,
- Datenbankschemamigration,
- Orphan-Datei-Erkennung,
- Recovery nicht abgeschlossener Zustände,
- Retry-Klassifizierung und Backoff,
- Verhinderung paralleler Retries,
- Restore-Last-Auswahl,
- Clipboard-ChangeCount-Konflikt,
- Aufbewahrungsregeln,
- Log-Redaktion,
- Phase-1-Audiomigration.

### 23.2 Integrationstests

- Aufnahme → History → Transkription → Einfügung → completed
- Netzwerkfehler → transcriptionFailed → manueller Retry → completed
- API-Key ungültig → Authentifizierungsfehler → Key ersetzen → Retry
- Einfügungsfehler → Transcript bleibt verfügbar → erneute Einfügung
- App-Neustart bei `transcribing` → Recovery-Eintrag
- App-Neustart bei `inserting` → keine automatische Doppeleinfügung
- Aufnahmeordner wird verschoben → Reparaturdialog
- externes Laufwerk wird getrennt → Aufnahme wird verhindert
- Ordnerwechsel mit erfolgreicher Migration
- Ordnerwechsel mit unterbrochener Migration

### 23.3 Manuelle macOS-Tests

Auf mindestens zwei Macs beziehungsweise zwei getrennten macOS-Benutzerkonten:

- frische Installation ohne vorhandene Einstellungen,
- Neuinstallation mit vorhandenem Keychain-Eintrag,
- Gatekeeper-Start des Release-Artefakts,
- Mikrofon- und Accessibility-Onboarding,
- Standardordner `Documents/Recordings`,
- benutzerdefinierter lokaler Ordner,
- externer Datenträger,
- Verlust und Erneuerung der Ordnerberechtigung,
- Launch at Login,
- Intel nur falls weiterhin offiziell unterstützt,
- Apple Silicon.

Ziel-Apps:

- Notes,
- Mail,
- Safari,
- Chrome,
- Microsoft Word oder vergleichbar,
- VS Code,
- Slack oder vergleichbar.

### 23.4 Fehler- und Belastungstests

- kein Internet,
- sehr langsames Internet,
- HTTP 429,
- Provider 5xx,
- ungültiger API-Key,
- volles Laufwerk,
- schreibgeschützter Ordner,
- Mikrofon während Aufnahme getrennt,
- schneller mehrfacher Hotkey,
- App Force Quit nach Aufnahmeende,
- 10.000 History-Einträge,
- lange Aufnahme,
- defekte oder leere Audiodatei.

---

## 24. Akzeptanzkriterien nach Funktionsbereich

### 24.1 Onboarding

- [ ] Eine frische Installation öffnet automatisch den Assistenten.
- [ ] Der Assistent kann nicht als abgeschlossen gelten, solange API-Key oder Aufnahmeordner fehlen.
- [ ] Ein gültiger vorhandener Keychain-Key wird erkannt.
- [ ] Der Benutzer kann einen neuen Key prüfen und speichern.
- [ ] Der Key erscheint in keiner lokalen Klartextdatei.
- [ ] Mikrofon- und Accessibility-Status werden korrekt aktualisiert.

### 24.2 Aufnahmeordner

- [ ] `Documents/Recordings` wird als empfohlener Standard angeboten.
- [ ] Ein anderer Ordner kann ausgewählt werden.
- [ ] Der Zugriff funktioniert nach einem App-Neustart.
- [ ] Die App besitzt Schreibzugriff über eine sichere Sandbox-Autorisierung.
- [ ] Ein ungültiger Speicherort erzeugt eine reparierbare Meldung.
- [ ] Phase-1-Aufnahmen können nicht-destruktiv migriert werden.

### 24.3 History und Recovery

- [ ] Jede beendete Aufnahme erzeugt vor dem API-Aufruf einen Datensatz.
- [ ] Audio kann aus der History abgespielt werden.
- [ ] Fehlerstatus und passende Aktion sind sichtbar.
- [ ] Ein App-Neustart erkennt unterbrochene Vorgänge.
- [ ] Dateien ohne History-Eintrag werden als Recovery-Fälle angeboten.
- [ ] Eine mögliche frühere Einfügung wird nicht automatisch dupliziert.

### 24.4 Retry und Restore Last

- [ ] Fehlgeschlagene Transkriptionen können manuell wiederholt werden.
- [ ] Nur temporäre Fehler werden automatisch wiederholt.
- [ ] Es läuft maximal ein Versuch pro Diktat.
- [ ] Restore Last funktioniert per Hotkey.
- [ ] Jede erfolgreiche Transkription kann kopiert oder erneut eingefügt werden.

### 24.5 Standalone

- [ ] Release-Build benötigt weder Xcode noch Repository noch `.env`.
- [ ] Der Build läuft auf einem zweiten unterstützten Mac.
- [ ] Bundle-ID und Signierung sind stabil.
- [ ] API-Key und Einstellungen sind pro macOS-Benutzer getrennt.
- [ ] Installations- und Berechtigungsschritte sind dokumentiert.

---

## 25. Umsetzungspakete

### Paket 2.1 – Storage Foundation

Umfang:

- RecordingLocationStore,
- Ordnerauswahl,
- Security-Scoped Bookmark,
- Schreibzugriff,
- neue Ordnerstruktur,
- Phase-1-Migrationsscanner,
- Storage Settings.

Abschluss:

Eine Aufnahme wird zuverlässig in einen vom Benutzer gewählten und nach Neustart weiterhin autorisierten Ordner geschrieben.

### Paket 2.2 – Durable History

Umfang:

- DictationRecord,
- HistoryStore,
- persistente Statusmaschine,
- Pipeline-Integration,
- History-Fenster,
- Audio-Wiedergabe.

Abschluss:

Jede beendete Aufnahme ist vor dem API-Aufruf in der History registriert.

### Paket 2.3 – Recovery & Retry

Umfang:

- Startprüfung,
- Orphan-Scanner,
- Recovery-Zustände,
- Fehlerklassifizierung,
- RetryPolicy,
- manueller und automatischer Retry,
- Restore Last.

Abschluss:

API-, Netzwerk-, Einfügungs- und App-Abbruchfälle sind ohne Verlust wiederherstellbar.

### Paket 2.4 – First-Run Experience

Umfang:

- kompletter Onboarding-Assistent,
- Key-Erfassung und Validierung,
- Berechtigungsführung,
- Hotkey-Test,
- Testdiktat,
- Setup-Fortsetzung.

Abschluss:

Eine Person ohne Entwicklerkenntnisse kann FlowDictate auf einem neuen Mac selbstständig einrichten.

### Paket 2.5 – Distribution & Hardening

Umfang:

- Release-Konfiguration,
- Signierung und Notarisierung,
- DMG/ZIP-Artefakt,
- Migrationstests,
- Aufbewahrung,
- Logs und Diagnoseexport,
- vollständige manuelle App-Matrix.

Abschluss:

FlowDictate kann als Standalone-App kontrolliert an andere Personen verteilt werden.

---

## 26. Reihenfolge und Abhängigkeiten

```text
Storage Foundation
        ↓
Durable History
        ↓
Recovery & Retry
        ↓
First-Run Experience
        ↓
Distribution & Hardening
```

Onboarding wird erst vollständig implementiert, nachdem Storage- und Credential-Services stabile Schnittstellen besitzen. Distribution wird fortlaufend vorbereitet, aber erst nach Abschluss der Recovery-Pipeline freigegeben.

---

## 27. Risiken und Gegenmaßnahmen

| Risiko | Auswirkung | Gegenmaßnahme |
|---|---|---|
| Security-Scoped Bookmark verliert Gültigkeit | keine Aufnahme möglich | Reparaturdialog, Bookmark-Erneuerung, Tests |
| Benutzer verschiebt Aufnahmeordner | Dateien scheinbar verloren | relative Pfade, Bookmark-Auflösung, Ordner neu zuordnen |
| App-Absturz nach Paste, vor Statusspeicherung | mögliche Doppeleinfügung | Status `insertionUnknown`, keine automatische Wiederholung |
| API-Key wird versehentlich geloggt | Sicherheitsvorfall | zentrale RedactionPolicy und Tests |
| History-Datenbank beschädigt | Recovery erschwert | Transaktionen, Backup vor Migration, Audio-Orphan-Scanner |
| Ordnerwechsel wird unterbrochen | doppelte/fehlende Dateien | Copy-Verify-Commit-Delete-Verfahren |
| wechselnde Signatur bei Testbuilds | Accessibility wird widerrufen | stabil signiertes Release-Artefakt |
| API-Anbieter ändert Fehlerantworten | falsche Retry-Entscheidung | Provider-spezifische Fehlernormalisierung |
| sehr große History | langsame UI | paginierte Queries, Indizes, keine Audiodaten in DB |

---

## 28. Definition of Done

Phase 2 gilt nur als abgeschlossen, wenn:

- alle Muss-Anforderungen implementiert sind,
- alle Akzeptanzkriterien erfüllt oder explizit mit Begründung verschoben wurden,
- Unit- und Integrationstests erfolgreich sind,
- der Release-Build ohne eingebettete Secrets geprüft wurde,
- Installation und Onboarding auf einem zweiten Mac erfolgreich waren,
- Aufnahmeordnerwahl und Bookmark-Persistenz nach Neustart funktionieren,
- ein erzwungener Absturz nach Aufnahmeende kein Audio verliert,
- Retry und Restore Last manuell verifiziert sind,
- Datenschutz- und Diagnoseexport geprüft sind,
- README und Installationsanleitung aktualisiert sind und
- bekannte Einschränkungen dokumentiert wurden.

---

## 29. Codex-Arbeitsregeln für die Umsetzung

Bei der Implementierung dieses PRD soll Codex:

1. jeweils nur ein Umsetzungspaket aktiv bearbeiten,
2. vorhandene Phase-1-Funktionen und Tests erhalten,
3. vor Strukturänderungen den aktuellen Git-Status prüfen,
4. zentrale Services über Protokolle testbar halten,
5. Datenmigrationen nie destruktiv beginnen,
6. keine echten API-Keys in Quellcode, Tests oder Logs verwenden,
7. jeden neuen persistenten Zustand testen,
8. Builds und Tests nach jedem abgeschlossenen Paket ausführen,
9. erforderliche manuelle macOS-Schritte präzise dokumentieren,
10. Sandbox, Signierung oder Entitlements nicht ohne dokumentierten Grund abschwächen,
11. Audio niemals löschen, bevor eine Migration oder Retention-Aktion verifiziert wurde, und
12. bei unklarer möglicher Doppeleinfügung immer die Entscheidung dem Benutzer überlassen.

---

## 30. Spätere Erweiterbarkeit

Nach Phase 2 soll die stabile Pipeline folgende spätere Funktionen aufnehmen können:

```text
Audio
  ↓
Transcription Provider (Cloud oder lokal)
  ↓
Original Transcript
  ↓
Optional Style / Dictionary / App Profile
  ↓
Final Text
  ↓
Insertion Strategy
  ↓
Durable History
```

Insbesondere dürfen History, Storage und Recovery nicht auf OpenAI als einzigen zukünftigen Provider fest verdrahtet werden.

---

## 31. Zusammenfassung der verbindlichen Produktentscheidungen

1. FlowDictate bleibt eine native sandboxed macOS-App.
2. Jede Person verwendet ihren eigenen API-Key.
3. Der API-Key wird beim Erststart abgefragt und im macOS-Schlüsselbund gespeichert.
4. Der empfohlene Aufnahmeordner ist `~/Documents/Recordings`.
5. Der Benutzer bestätigt diesen oder wählt einen anderen Ordner über den macOS-Systemdialog.
6. Der Ordnerzugriff wird über ein Security-Scoped Bookmark dauerhaft autorisiert.
7. Die History-Datenbank bleibt im Application-Support-Bereich der App.
8. Audio liegt im benutzergewählten Aufnahmeordner.
9. Jede beendete Aufnahme wird vor dem API-Aufruf persistent registriert.
10. Ein unklarer Einfügestatus führt niemals zu einer automatischen Doppeleinfügung.
11. Phase-1-Aufnahmen werden nicht-destruktiv erkannt und migriert.
12. Phase 2 endet mit einem signierten, notarisierten und auf einem zweiten Mac getesteten Standalone-Build.
