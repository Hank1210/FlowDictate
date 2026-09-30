# FlowDictate Community installieren

Diese Ausgabe ist kostenlos und ad hoc signiert. Sie wurde nicht von Apple notarisiert. macOS zeigt deshalb beim ersten Start eine Sicherheitswarnung an.

Diese Anleitung gilt für FlowDictate 4.1.0 Community.

## Download prüfen

Lade die ZIP-Datei und die gleichnamige `.sha256`-Datei aus demselben GitHub Release. Öffne anschließend Terminal, wechsle in den Download-Ordner und prüfe das Archiv:

```sh
shasum -a 256 -c FlowDictate-4.1.0-Community-macOS.zip.sha256
```

Terminal muss `OK` melden. Installiere die App nicht, wenn die Prüfung fehlschlägt.

## Installation

1. Entpacke die ZIP-Datei.
2. Ziehe `FlowDictate.app` in den Ordner `Programme`.
3. Klicke in `Programme` mit der rechten Maustaste auf FlowDictate und wähle `Öffnen`.
4. Bestätige im nächsten Dialog erneut mit `Öffnen`.
5. Falls macOS nur `Abbrechen` anbietet, öffne `Systemeinstellungen → Datenschutz & Sicherheit` und klicke bei FlowDictate auf `Dennoch öffnen`.

Gib FlowDictate nur frei, wenn du die ZIP-Datei direkt von einer Person erhalten hast, der du vertraust.

## Ersteinrichtung

1. Wähle den Aufnahmeordner. Empfohlen wird `Dokumente/Recordings`.
2. Wähle die Transkription: Auf einem Apple-Silicon-Mac kannst du das lokale Parakeet-Modell herunterladen und ohne API-Key arbeiten. Alternativ trägst du deinen eigenen OpenAI API-Key ein; er wird ausschließlich im macOS-Schlüsselbund gespeichert. Auf Intel-Macs bleibt OpenAI der verfügbare finale Transkriptionsweg.
3. Erlaube Mikrofonzugriff und Bedienungshilfen.
4. Erlaube Spracherkennung nur, wenn du die optionale lokale Live Preview verwenden möchtest. Wenn die Preview trotz Freigabe `Siri and Dictation are disabled` meldet, aktiviere zusätzlich die macOS-Diktierfunktion unter `Systemeinstellungen → Tastatur → Diktierfunktion`. Die finale Transkription funktioniert auch ohne Live Preview.
5. Für einzelne Systemaudio-Diktate benötigt FlowDictate die Freigabe unter `Bildschirm- & Systemaudioaufnahme`. Für kombinierte Mikrofon- und Systemaudioaufnahmen auf macOS 14.2 oder neuer verwende den getrennten Schalter `Nur Systemaudioaufnahme`/`System Audio Recording Only`; auf macOS 14.0/14.1 wird der ScreenCaptureKit-Pfad verwendet. FlowDictate nimmt dabei nur Audio und kein Video auf.
6. Beende und öffne FlowDictate erneut, wenn macOS nach einer neuen Berechtigung dazu auffordert.
7. Lege die gewünschten Tastenkürzel fest.

Die ZIP-Datei enthält weder einen API-Key noch ein Sprachmodell oder Zugangsdaten des Erstellers. Der optionale Modelldownload wird in den Transkriptions-Einstellungen mit Quelle, Größe und Lizenz angezeigt.

Für `Microphone + System Audio` musst du die Quelle ausdrücklich auswählen und vor der ersten Aufnahme einen gesonderten Hinweis zu Information und nötiger Zustimmung aller Beteiligten bestätigen. Die Bestätigung startet noch keine Aufnahme. Im gewählten Aufnahmeordner legt FlowDictate pro Meeting zwei getrennte Originalspuren sowie Arbeits- und Transkriptdateien im Unterordner `MeetingSessions` ab. Bei 48 kHz benötigen allein die Originale ungefähr 1,4 GB pro Stunde; plane für Arbeitsdateien zusätzlichen Platz ein. Kurze Systemaudio-Lücken sind möglich und werden in History als Qualitätswarnung angezeigt. `You` bezeichnet die Mikrofonspur, nicht eine Sprechererkennung.

## Aktualisierung

**Wichtig beim Wechsel von einer älteren Installation:** FlowDictate 4.1.0 verwendet `de.mcc.FlowDictate` statt `de.euler.FlowDictate`. macOS behandelt das als neue App. Einstellungen, History, lokales Modell, Aufnahmeordner-Freigabe und API-Key werden nicht automatisch übernommen. Sichere oder exportiere benötigte alte History, bevor du die bisherige App ersetzt, und lösche den alten App-Container nicht vorsorglich. Dateien im separat gewählten Aufnahmeordner werden durch den Identitätswechsel nicht gelöscht; wähle diesen Ordner bei der erneuten Einrichtung wieder aus.

Community-Ausgaben sind ad hoc signiert. Da sich ihre Code-Identität mit einem neuen Build ändern kann, behandelt macOS eine Aktualisierung gelegentlich wie eine neue App. Dadurch können insbesondere **Bedienungshilfen** sowie **Bildschirm- & Systemaudioaufnahme** erneut freigegeben werden müssen. Das lässt sich bei einer kostenlosen, nicht notarisierten Community-Ausgabe nicht zuverlässig vermeiden.

Verwende zum Testen immer genau die Community-ZIP, die später veröffentlicht werden soll. Ein separat gebauter oder anders signierter Test-Build ist nicht identisch mit dem Release-Artefakt.

### Empfohlener Update-Ablauf

1. Beende FlowDictate vollständig über das Menüleistensymbol. Prüfe bei Bedarf in der Aktivitätsanzeige, dass FlowDictate nicht mehr läuft.
2. Entpacke die neue Community-ZIP.
3. Ziehe die neue `FlowDictate.app` nach `Programme` und bestätige `Ersetzen`. Behalte den Namen `FlowDictate.app` und den Speicherort `/Applications/FlowDictate.app` bei.
4. Öffne FlowDictate wie bei der Erstinstallation mit Rechtsklick und `Öffnen`.
5. Nach dem Wechsel der Bundle-ID durchlaufe die Ersteinrichtung erneut: Aufnahmeordner wählen, lokales Modell laden oder eigenen API-Key neu eingeben und Berechtigungen erteilen. Teste dann Mikrofonaufnahme, Texteinfügung und – falls verwendet – Systemaudio. Lösche funktionierende Berechtigungen nicht vorsorglich.
6. Erneuere nur die Berechtigung, deren Funktion tatsächlich nicht mehr arbeitet. Folge dazu dem Abschnitt **Berechtigungen reparieren** weiter unten.
7. Beende und starte FlowDictate nach Änderungen an den Berechtigungen einmal vollständig neu.

Der Identitätswechsel importiert die History des alten App-Containers nicht. Der separat gewählte Aufnahmeordner wird weder verschoben noch gelöscht; die neue App benötigt aber eine neue Ordnerfreigabe. Lösche den alten Container nicht, solange du seine History noch benötigst.

Live Preview ist optional und nutzt ausschließlich Apples lokale Spracherkennung. Lokale finale Transkription, gesprochene Korrekturen, Formatierung und das persönliche Wörterbuch arbeiten auf dem Mac. Im Modus `Fully offline` blockiert FlowDictate Transkriptions-, Enhancement- und Update-Netzwerkzugriffe. Nur ein bewusst gewählter Cloudpfad sendet Audio oder Text an OpenAI; ein lokaler Fehler löst niemals automatisch einen Cloud-Upload aus.

### Schlüsselbund nach einem Update

Beim Wechsel von `de.euler.FlowDictate` zu `de.mcc.FlowDictate` ist der alte API-Key für die neue App nicht eingerichtet; gib deinen eigenen Key bei Bedarf erneut ein. Bei späteren Updates innerhalb derselben Bundle-ID kann macOS wegen der geänderten ad-hoc Signatur einmal nach dem Anmeldepasswort fragen. Falls die Abfrage wiederholt erscheint, öffne `Settings → Transcription`, entferne dort den bisherigen API-Key und speichere ihn anschließend erneut. Dadurch wird der Schlüsselbund-Eintrag für die aktuell installierte Ausgabe neu angelegt. FlowDictate lädt ihn danach nur einmal pro App-Sitzung.

### Berechtigungen reparieren

Gehe nur für die nicht funktionierende Funktion wie folgt vor:

1. Öffne `Systemeinstellungen → Datenschutz & Sicherheit`.
2. Öffne den betroffenen Bereich: **Mikrofon**, **Bedienungshilfen**, **Spracherkennung** oder **Bildschirm- & Systemaudioaufnahme**.
3. Falls FlowDictate dort vorhanden ist, schalte die Freigabe zunächst aus und wieder ein. Starte FlowDictate danach neu und teste erneut.
4. Funktioniert es weiterhin nicht, beende FlowDictate, markiere den alten Eintrag und entferne ihn mit der Minustaste. Falls keine Minustaste angezeigt wird, deaktiviere den Eintrag.
5. Füge über die Plustaste exakt `/Applications/FlowDictate.app` hinzu und aktiviere die Freigabe. Alternativ starte die entsprechende FlowDictate-Funktion erneut und bestätige die neue macOS-Abfrage.
6. Beende FlowDictate vollständig und öffne es erneut. Wenn macOS `Beenden & erneut öffnen` anbietet, verwende diese Schaltfläche.

Zuordnung der Funktionen:

- Keine Mikrofonaufnahme: **Mikrofon**
- Aufnahme startet, aber Tastenkürzel oder Texteinfügung funktionieren nicht: **Bedienungshilfen**
- Keine lokale Live Preview: **Spracherkennung** prüfen; bei `Siri and Dictation are disabled` zusätzlich `Tastatur → Diktierfunktion` aktivieren.
- Keine einzelne Systemaudioaufnahme: **Bildschirm- & Systemaudioaufnahme**
- Keine kombinierte Systemaudiospur: unter macOS 14.2+ **Nur Systemaudioaufnahme**; unter 14.0/14.1 **Bildschirm- & Systemaudioaufnahme**

Bei einer **einzelnen Systemaudioaufnahme** zeigt macOS gegebenenfalls eine Abfrage für Bildschirm- & Systemaudioaufnahme, obwohl FlowDictate nur Audio verarbeitet. Der Schalter kann nach einem neuen ad-hoc signierten Build noch eingeschaltet aussehen, obwohl macOS die alte Code-Identität nicht mehr akzeptiert. Entferne in diesem Fall FlowDictate aus **Bildschirm- & Systemaudioaufnahme**, füge exakt `/Applications/FlowDictate.app` wieder hinzu und starte die App vollständig neu. Dies ist eine andere Freigabe als **Bedienungshilfen**.

Setze nicht alle Datenschutzrechte gleichzeitig zurück. So bleiben bereits funktionierende Freigaben erhalten und der Update-Aufwand bleibt möglichst gering.
