# FlowDictate — Arbeitsplan vor Phase 3.1

**Status:** Technisch umgesetzt; manuelle Geräte- und Berechtigungsprüfung ausstehend
**Stand:** 20. August 2026
**Bezug:** `FlowDictate_PRD_Phase_3.md`
**Ziel:** Die Phase-2-Basis technisch auf Phase 3.1 vorbereiten, ohne bereits die vollständige Live-Preview-Oberfläche zu implementieren.

## Umsetzungsstand vom 20. August 2026

- Arbeitspakete A bis D sind implementiert und durch Unit-Tests abgedeckt.
- Der Einzel-Tap-, Deep-Copy- und Backpressure-Unterbau aus Arbeitspaket E ist implementiert; Apple Speech bleibt bis Phase 3.1 bewusst ohne UI-Aktivierung.
- Debug-Test-Build, Release-Build und 21 Unit-Tests sind erfolgreich.
- Der 1.000-Record-Test benötigt auf dem Entwicklungs-Mac rund 60 ms für Laden plus einen atomaren Upsert und liegt damit innerhalb der vorläufigen Grenze.
- Vor Freigabe der vollständigen Phase 3.1 bleiben die in Abschnitt 5 genannten manuellen Mikrofon-, Berechtigungs-, Langzeit- und Ziel-App-Tests durchzuführen.

---

## 1. Ergebnis dieses Arbeitspakets

Nach Abschluss dieses Plans soll FlowDictate:

- große Aufnahmen ohne vollständige Audio- und Multipart-Kopie im Arbeitsspeicher hochladen,
- zu große Uploads vor dem Netzwerkzugriff verständlich ablehnen,
- Persistenzfehler zuverlässig protokollieren und kritische Fehler sichtbar behandeln,
- eine begrenzbare JSON-History ohne SQLite verwenden,
- History- und Audioaufbewahrung widerspruchsfrei ausführen,
- `DictationRecord` über sichere, benannte Konstruktionen erzeugen,
- Ersttranskription und Retry über denselben Ablauf ausführen,
- einen technisch verifizierten Einzel-Tap-Audiopfad für die spätere Live Preview besitzen,
- alle bestehenden Phase-2-Funktionen weiterhin erfüllen.

## 2. Festgelegte Leitentscheidungen

1. **Kein SQLite vor Phase 3.1.** Der bestehende JSON-Store bleibt erhalten und wird gemessen sowie gezielt optimiert.
2. **Keine Debounce-Verzögerung für Statusübergänge.** Recovery-relevante Zustände werden weiterhin unmittelbar atomar gespeichert.
3. **Audio und History besitzen getrennte Regeln.** Eine History-Bereinigung darf keine Audiodatei unkontrolliert löschen.
4. **Keine konkurrierenden Mikrofon-Sessions.** Ein Audio-Tap schreibt die Aufnahme und verteilt Kopien an optionale Preview-Konsumenten.
5. **Live Preview bleibt optional.** Jeder Fehler im Preview-Pfad degradiert auf das Phase-2-Verhalten.
6. **Kleine, überprüfbare Refactorings.** Der `DictationCoordinator` wird nur entlang klarer Verantwortlichkeiten aufgeteilt; kein Komplettumbau vor der Feature-Arbeit.

## 3. Nicht Bestandteil

- vollständige Live-Preview-UI,
- Schreibstile, Wörterbuch oder AI-Nachbearbeitung,
- direkte AX-Einfügung,
- Realtime-Cloud-Transkription,
- vollständige lokale Finaltranskription,
- SQLite-, SwiftData- oder GRDB-Migration,
- Änderung der Lizenz oder des Release-Modells.

---

# Arbeitspaket A — Audio-Upload absichern

## A1. Ziel

Uploadgröße, Arbeitsspeicherverbrauch und Fehlerverhalten werden vor Phase 3.1 robust gemacht. Die vom Benutzer gespeicherte Originalaufnahme bleibt zunächst das Recovery-Original. Für den Upload wird bei Bedarf eine temporäre, komprimierte Ableitung verwendet.

## A2. Betroffene Bereiche

- `FlowDictate/Audio/MicrophoneRecorder.swift`
- `FlowDictate/Audio/AudioStore.swift`
- `FlowDictate/Transcription/OpenAITranscriptionProvider.swift`
- `FlowDictate/Transcription/TranscriptionProvider.swift`
- `FlowDictate/Recovery/DictationFailureClassifier.swift`
- neue Hilfskomponente, zum Beispiel `FlowDictate/Audio/AudioUploadPreparer.swift`

## A3. Umsetzungsschritte

1. Tatsächliches Aufnahmeformat, Sample-Rate, Kanalzahl und Dateiwachstum für internes Mikrofon, USB und – soweit verfügbar – Bluetooth diagnostisch erfassen.
2. `AudioUploadPreparer` als injizierbare Abstraktion einführen.
3. Nach Aufnahmeende eine temporäre M4A/AAC-Datei für den Upload erzeugen.
4. Die Originalaufnahme bis zum abgeschlossenen Upload und entsprechend der bestehenden Audioaufbewahrung behalten.
5. Vor dem Netzwerkzugriff die Größe der Uploaddatei prüfen.
6. Einen eigenen Fehler `audioFileTooLarge` mit tatsächlicher Größe und verständlicher Handlungsempfehlung ergänzen.
7. Den Multipart-Body stückweise in eine temporäre Datei schreiben.
8. Mit `URLSession.upload(for:fromFile:)` statt mit einem vollständigen `Data`-Body hochladen.
9. Temporäre M4A- und Multipart-Dateien in jedem Erfolgs-, Fehler- und Abbruchpfad entfernen.
10. Explizite Request- und Resource-Timeouts festlegen.
11. MIME-Type und Dateiname aus dem vorbereiteten Uploadformat ableiten; nicht mehr fest `audio/wav` verwenden.
12. Wenn die Komprimierung fehlschlägt:
    - WAV dateibasiert hochladen, falls es innerhalb der Größenbegrenzung liegt,
    - andernfalls Aufnahme behalten und einen lokalen, wiederholbaren Fehler anzeigen.

## A4. Sicherheits- und Fehlerregeln

- Die gespeicherte Originalaufnahme wird durch einen Uploadfehler niemals gelöscht.
- API-Key, Audiopfade und Transkriptinhalt erscheinen nicht in Logs.
- Abbruch beendet Konvertierung und Upload kontrolliert.
- Unvollständige temporäre Dateien werden beim nächsten Start bereinigt.
- Der Größencheck verwendet eine zentrale Konstante und einen kleinen Sicherheitsabstand zur Providergrenze.

## A5. Tests

- kleine WAV-Datei wird in eine gültige Uploaddatei überführt,
- Dateigröße wird vor dem Provideraufruf geprüft,
- zu große Datei erzeugt die erwartete Fehlerklasse,
- Multipart-Datei enthält Felder, Datei und Abschlussgrenze,
- MIME-Type entspricht dem tatsächlichen Dateiformat,
- kein `Data(contentsOf:)` für die vollständige Audiodatei oder den vollständigen Multipart-Body,
- temporäre Dateien werden nach Erfolg, Fehler und Cancellation entfernt,
- Timeout wird korrekt klassifiziert,
- Retry verwendet dieselbe bereits vorbereitete oder neu reproduzierbare Uploadlogik,
- Originalaudio bleibt nach jedem simulierten Fehler vorhanden.

## A6. Abnahme

- Eine Aufnahme nahe der Providergrenze verursacht keinen proportionalen doppelten RAM-Anstieg.
- Eine zu große Datei wird ohne API-Aufruf abgelehnt.
- Eine normale Aufnahme wird weiterhin erfolgreich transkribiert und eingefügt.
- Recovery und Retry funktionieren mit der ursprünglichen Audiodatei.

---

# Arbeitspaket B — JSON-History stabilisieren und begrenzen

## B1. Ziel

Die JSON-Lösung bleibt bestehen, erhält aber messbare Leistungsgrenzen, eine sichere Aufbewahrungsstrategie und vollständige Fehlerbeobachtung.

## B2. Betroffene Bereiche

- `FlowDictate/History/DictationHistoryStore.swift`
- `FlowDictate/History/DictationRecord.swift`
- `FlowDictate/Settings/AppSettings.swift`
- `FlowDictate/MenuBar/FlowDictateMenu.swift`
- `FlowDictate/App/DictationCoordinator.swift`
- optional neue Komponente `FlowDictate/History/HistoryRetentionService.swift`

## B3. Persistenzoptimierung

1. `prettyPrinted` aus dem produktiven History-Encoder entfernen.
2. Atomisches Schreiben und sofortige Speicherung der Zustandsübergänge beibehalten.
3. History-Schema-Version über eine zentrale Konstante verwalten.
4. Einen Benchmark-/Performance-Test mit 1.000, 5.000 und 10.000 realistisch großen Phase-3-Datensätzen ergänzen.
5. Dateigröße, Ladezeit und Upsert-Zeit als Testergebnis dokumentieren.
6. Erst bei Überschreitung der festgelegten Schwellen erneut über SQLite entscheiden.

Vorläufige Prüfschwellen auf einem unterstützten Entwicklungs-Mac:

- Laden von 1.000 Datensätzen: Ziel unter 200 ms,
- einzelner Upsert bei 1.000 Datensätzen: Ziel unter 100 ms,
- keine sichtbare Blockade des Menüs oder der Aufnahme,
- beschädigte oder inkompatible Datei führt nicht zu stiller Datenüberschreibung.

## B4. Aufbewahrungsmodell

Einzuführen sind zwei voneinander getrennte Einstellungen:

- `historyRetentionDays`: unbegrenzt, 30, 90 oder 365 Tage,
- `historyMaximumRecordCount`: unbegrenzt, 250, 500 oder 1.000 Einträge.

Empfohlener Default für Neuinstallationen:

- maximal 1.000 History-Einträge,
- zusätzlich maximal 365 Tage,
- bestehende Installationen behalten zunächst ihre bisherige unbegrenzte Einstellung, bis eine Migration beziehungsweise bewusste Produktentscheidung erfolgt.

Die Bereinigung wendet Zeit- und Mengenregel gemeinsam an. Die strengere erreichte Grenze gewinnt, soweit Schutzregeln dies erlauben.

## B5. Schutz vor wiederkehrenden Orphan-Einträgen

Die aktuelle Recovery erzeugt für unbekannte Audiodateien erneut History-Einträge. Deshalb gelten folgende Regeln:

1. Ein History-Eintrag mit noch vorhandener Audiodatei wird nicht allein wegen der History-Grenze physisch entfernt.
2. Wenn ein Eintrag aus der sichtbaren History verschwinden soll, während Audio erhalten bleibt, wird er archiviert statt gelöscht.
3. Archivierte Einträge werden von der normalen Liste und Statistik ausgeschlossen, bleiben aber der Audio-Recovery bekannt.
4. Alternativ darf ein Eintrag endgültig entfernt werden, sobald seine Audiodatei gemäß der separaten Audioaufbewahrung bereits gelöscht wurde.
5. Fehlgeschlagene, unterbrochene, unbekannt eingefügte oder recovery-pflichtige Datensätze werden weder zeit- noch mengenbasiert automatisch entfernt.
6. Manuelles Löschen behält die bestehende Auswahl „nur Datensatz“ oder „Datensatz und Audio“, muss aber einen Tombstone beziehungsweise eine gleichwertige Recovery-Markierung anlegen, wenn Audio erhalten bleibt.

Die konkrete Repräsentation – Archivstatus im Record oder kompakter Tombstone-Index – wird vor Umsetzung anhand der einfacheren Migration gewählt. Sie muss selbst versioniert und begrenzbar sein.

## B6. Persistenzfehler

1. Jedes bisherige `try?` bei `historyStore.upsert` oder `delete` wird durch eine bewusste Fehlerbehandlung ersetzt.
2. Recovery-kritische Speicherfehler werden geloggt und führen zu einem sichtbaren, nicht irreführenden Fehlerzustand.
3. Nicht kritische Fehler, etwa das Aktualisieren einer Ansicht, werden geloggt, ohne eine Aufnahme zu verwerfen.
4. Das Löschen einer Audiodatei und Aktualisieren ihres History-Eintrags wird als kontrollierter Ablauf behandelt:
   - Datei löschen,
   - Record aktualisieren,
   - Fehlerzustand protokollieren, falls nur ein Teilschritt gelingt,
   - beim nächsten Start reparierbar bleiben.

## B7. Tests

- alte JSON-History bleibt lesbar,
- kompakte JSON-Ausgabe wird atomar gespeichert,
- Zeitlimit entfernt beziehungsweise archiviert nur zulässige Datensätze,
- Mengenlimit behält die neuesten zulässigen Datensätze,
- geschützte Fehler- und Recovery-Datensätze bleiben erhalten,
- vorhandenes Audio wird nicht versehentlich gelöscht,
- archiviertes Audio wird nicht als verwaist wiederhergestellt,
- manuell ohne Audio gelöschter Eintrag erscheint nach Neustart nicht erneut,
- simulierte Schreibfehler werden geloggt und korrekt an den Aufrufer gemeldet,
- Benchmarks decken realistische Phase-3-Textfelder ab.

## B8. Abnahme

- History bleibt bei täglicher Nutzung größenmäßig kontrollierbar.
- Es existiert kein Wiederauftauchen absichtlich entfernter Einträge.
- Audioaufbewahrung und Historyaufbewahrung können keine unbemerkte Datenlöschung verursachen.
- SQLite ist für Phase 3.1 nicht erforderlich oder wird nur aufgrund dokumentierter Messergebnisse neu bewertet.

---

# Arbeitspaket C — Datenmodell und Versionskonstanten

## C1. Ziel

Lange, duplizierte `DictationRecord`-Initialisierungen werden vor der Phase-3-Erweiterung beseitigt. Schema- und Produktversionen erhalten eindeutige Quellen.

## C2. Umsetzungsschritte

1. Benannte Konstruktionen einführen:
   - `DictationRecord.newRecording(...)`,
   - `DictationRecord.recoveredAudio(...)`,
   - `DictationRecord.migratedLegacyRecording(...)`.
2. Gemeinsame Defaults nur in diesen Konstruktionen definieren.
3. Bestehende Aufrufstellen im Coordinator auf die neuen Konstruktionen umstellen.
4. Eine zentrale Struktur, beispielsweise `FlowDictateVersion`, ergänzen:
   - aktuelle History-Schema-Version,
   - aktuelle Record-Schema-Version,
   - aktuelle Onboarding-Version.
5. Logmeldung aus Bundle-Version und Buildnummer erzeugen; keine fest codierte Meldung „Phase 2 started“.
6. Decoding-Migrationen explizit testen, bevor Phase-3-Felder hinzukommen.
7. Optionalen Phase-3-Feldern sichere Defaults geben, ohne bestehende Records unlesbar zu machen.

## C3. Tests und Abnahme

- jede Factory setzt Status, Fehlerfelder, Zeitstempel und Pfad korrekt,
- Migration und Recovery erzeugen semantisch identische Records wie zuvor,
- Phase-2-JSON lässt sich weiterhin laden,
- es gibt keine produktive direkte Konstruktion mit einer langen Parameterliste,
- App-Startlog zeigt reale Version und Buildnummer.

---

# Arbeitspaket D — Transkriptionspipeline entkoppeln

## D1. Ziel

Neue Aufnahme und Retry verwenden dieselbe getestete Transkriptionslogik. Der Coordinator bleibt für den sichtbaren Diktat-Lebenszyklus zuständig, nicht für Providerdetails und wiederholte Statusmutation.

## D2. Zielkomponenten

### `TranscriptionRunner`

Verantwortet:

- Uploadvorbereitung,
- Provideraufruf,
- Retry-Regeln und Backoff,
- Versuchszähler und Zeitstempel,
- normalisierte Ergebnisse und Fehler,
- sichere Statuspersistenz bis `transcribed` beziehungsweise `transcriptionFailed`.

### `HistoryController` beziehungsweise `HistoryService`

Zunächst nur extrahieren, was unmittelbar benötigt wird:

- Laden und Refresh,
- Retry eines bestehenden Records,
- Aufbewahrung und Recovery,
- Fehlerprotokollierung.

Fensterdarstellung, Audio-Playback und Export dürfen in einem späteren kleinen Schritt folgen, wenn dadurch keine unnötige UI-Umschreibung entsteht.

## D3. Umsetzungsschritte

1. Aktuelle Zustandsübergänge von `stopAndTranscribe` und `retryTranscription` tabellarisch festhalten.
2. Gemeinsames Ergebnisobjekt für Erfolg, endgültigen Providerfehler und Cancellation definieren.
3. `TranscriptionRunner` vollständig injizierbar implementieren.
4. Retry-Pfad zuerst umstellen und testen.
5. Hauptpfad anschließend umstellen.
6. Einfügung und Overlay bleiben zunächst beim Coordinator.
7. Nur nach grünen Regressionstests History-/Setup-Verantwortlichkeiten weiter extrahieren.
8. Keine öffentliche UI-Funktion während des Refactorings verändern.

## D4. Tests

- Ersttranskription und manueller Retry verwenden denselben Runner,
- automatische Retries erfolgen nur für retryfähige Fehler,
- Versuchszähler stimmen bei automatischem und manuellem Retry,
- Cancellation startet keine Einfügung,
- Transkriptionsfehler behält Originalaudio,
- Persistenzfehler werden nicht als Providerfehler fehlklassifiziert,
- erfolgreiche Transkription wird genau einmal eingefügt,
- Recovery-Statusfolge bleibt unverändert.

## D5. Abnahme

- Duplizierte Transkriptions- und Retry-Logik ist entfernt.
- `DictationCoordinator` orchestriert Start, Stop, Cancel, Overlay und Einfügung.
- Provider, Uploadvorbereitung und Retry sind unabhängig testbar.
- Alle bestehenden Phase-2-Tests bleiben grün.

---

# Arbeitspaket E — Live-Preview-Audio-Spike

## E1. Ziel

Vor dem UI-Ausbau wird nachgewiesen, dass eine einzige Mikrofonaufnahme gleichzeitig eine verlustfreie Datei schreibt und einen nachrangigen Preview-Konsumenten versorgt.

## E2. Technischer Versuchsaufbau

1. `MicrophoneRecorder` erhält eine optionale, begrenzte Buffer-Ausgabe.
2. Der bestehende Tap bleibt die einzige Quelle der Mikrofonbuffer.
3. Dateischreiben geschieht zuerst und darf nicht auf Preview-Verarbeitung warten.
4. Preview erhält kopierte beziehungsweise sicher übertragene Buffer über eine begrenzte Queue.
5. Bei voller Queue werden ausschließlich alte Preview-Buffer verworfen.
6. Ein `LivePreviewProvider`-Protokoll wird definiert.
7. Ein Fake-Provider simuliert normale, langsame, fehlerhafte und abbrechende Verarbeitung.
8. Danach wird ein minimaler Apple-Speech-Adapter ohne fertige Overlay-UI angeschlossen.
9. macOS-14-Verfügbarkeit und neuere Speech-APIs werden über klare Availability-Grenzen getrennt.
10. Preview-Text wird weder persistiert noch in Logs geschrieben.

## E3. Messungen

- Zeit bis zum ersten Preview-Ergebnis,
- Anzahl verworfener Preview-Buffer,
- maximale Queue-Länge,
- Aufnahmegröße und -dauer,
- erkannte Audio-Dropouts,
- Speicherentwicklung bei 1, 5, 15 und 30 Minuten,
- Verhalten bei schnellem Start/Stop,
- Verhalten bei fehlender Speech-Berechtigung,
- Verhalten bei Providerfehler und Mikrofonwechsel.

## E4. Abbruchkriterien

Der Spike gilt als nicht bestanden, wenn:

- Preview die Aufnahme blockiert oder beschädigt,
- zwei Mikrofon-Sessions erforderlich wären,
- Stop oder Cancel Recognition-Tasks zurücklässt,
- Preview-Fehler die finale Transkription verhindern,
- Speicher oder Queue mit der Aufnahmedauer unbegrenzt wachsen.

Bei Nichtbestehen bleibt Phase-2-Aufnahme unverändert aktiv. Die Preview-Architektur wird angepasst, bevor UI-Arbeit beginnt.

## E5. Tests und Abnahme

- Datei enthält trotz langsamem Preview-Konsumenten die erwartete Audiodauer,
- Queue bleibt begrenzt,
- Preview kann deaktiviert werden, ohne Speech-Berechtigung anzufragen,
- Preview-Fehler beendet die Aufnahme nicht,
- Stop und Cancel räumen Tasks und Buffer auf,
- ein dokumentierter manueller Test mit mindestens internem Mikrofon und einem weiteren Eingabegerät ist bestanden.

---

# 4. Ausführungsreihenfolge und Gates

## Gate 0 — Ausgangszustand

- sauberer Build des aktuellen `main`,
- alle Unit-Tests grün,
- bekannte manuelle Phase-2-Kernabläufe dokumentiert,
- keine ungesicherten Änderungen überschreiben.

## Reihenfolge

1. **A:** Audio-Upload absichern.
2. **B:** History-Fehlerbehandlung und kompakte Persistenz.
3. **C:** Record-Factories und Versionskonstanten.
4. **D:** Transkriptionsrunner und kleine Coordinator-Entkopplung.
5. **B fortsetzen:** History-Begrenzung, Archiv-/Tombstone-Strategie und Benchmarks.
6. **E:** Live-Preview-Spike.
7. Gesamter Regressionstest und Dokumentationsabgleich.

## Gate 1 — Nach A

- große Datei erzeugt keinen speicherbasierten Multipart-Upload,
- Größenlimit, Timeout und temporäre Dateien sind getestet,
- normale Transkription funktioniert.

## Gate 2 — Nach B bis D

- Recovery-relevante Fehler werden nicht verschluckt,
- History-Bereinigung ist verlustsicher,
- Transkriptionslogik ist zentralisiert,
- Phase-2-Regressionstests sind grün.

## Gate 3 — Nach E

- Einzel-Tap-Konzept ist technisch bestätigt,
- Preview-Ausfall gefährdet Aufnahme nicht,
- Entscheidung „Phase 3.1 UI implementieren“ ist freigegeben.

---

# 5. Verifikation des Gesamtpakets

## Automatisiert

- alle bestehenden Unit-Tests,
- neue Upload- und Cleanup-Tests,
- History-Migrations-, Begrenzungs- und Benchmarktests,
- Factory-Tests,
- Runner-Tests,
- Buffer-Fan-out-, Backpressure- und Cancellation-Tests,
- `git diff --check`,
- Debug- und Release-Build.

## Manuell

1. Neuinstallation mit API-Key und frei gewähltem Aufnahmeordner.
2. Kurzes Diktat mit erfolgreicher Einfügung.
3. Längeres Diktat mit kontrolliertem Speicherverbrauch.
4. Netzwerkfehler mit erhaltenem Audio und anschließendem Retry.
5. Cancel während Aufnahme und während vorbereitender Verarbeitung.
6. History-Aufbewahrung mit alten, neuen und geschützten Records.
7. Löschen nur des History-Eintrags bei weiterhin vorhandenem Audio.
8. App-Neustart und Prüfung, dass gelöschte beziehungsweise archivierte Records nicht ungewollt wiederkehren.
9. Preview-Spike mit deaktivierter, verweigerter und fehlerhafter Speech-Erkennung.
10. Bestehende Clipboard-Wiederherstellung und Restore-Hotkey.

---

# 6. Definition of Done

Der vorbereitende Schritt ist abgeschlossen, wenn:

1. kein vollständiges Audio plus vollständiger Multipart-Body gleichzeitig im RAM aufgebaut wird,
2. Uploadgröße und Timeouts lokal behandelt werden,
3. temporäre Uploaddateien zuverlässig bereinigt werden,
4. History-Persistenzfehler beobachtbar sind,
5. History ohne SQLite begrenzbar und benchmarkgestützt vertretbar ist,
6. History- und Audioaufbewahrung keine Records wiederauferstehen lassen und keine geschützten Audios löschen,
7. lange direkte `DictationRecord`-Initialisierungen durch benannte Konstruktionen ersetzt sind,
8. Ersttranskription und Retry denselben Runner verwenden,
9. der Einzel-Tap-Preview-Spike alle Abnahmekriterien erfüllt,
10. bestehende Phase-2-Funktionen und Tests unverändert funktionieren,
11. relevante Architektur- und Datenschutzdokumentation aktualisiert ist,
12. erst danach die vollständige Implementierung von Phase 3.1 beginnt.

---

# 7. Noch zu treffende Implementierungsentscheidungen

Diese Entscheidungen werden jeweils zu Beginn des betreffenden Arbeitspakets anhand eines kleinen Tests getroffen und im Commit dokumentiert:

1. AVFoundation-Exportweg für AAC/M4A und kompatible Qualitätsstufe.
2. Exakte Upload-Sicherheitsgrenze unterhalb der Providergrenze.
3. Archivstatus im `DictationRecord` oder separater Tombstone-Index.
4. Performance-Schwellen auf dem Referenz-Mac nach erstem Benchmarklauf.
5. macOS-14-kompatibler Apple-Speech-Adapter und optionale Nutzung neuerer Speech-APIs.

Keine dieser Entscheidungen erweitert den Produktscope; sie bestimmt nur die sicherste technische Umsetzung.
