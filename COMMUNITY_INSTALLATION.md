# FlowDictate Community installieren

Diese Ausgabe ist kostenlos und ad hoc signiert. Sie wurde nicht von Apple notarisiert. macOS zeigt deshalb beim ersten Start eine Sicherheitswarnung an.

## Installation

1. Entpacke die ZIP-Datei.
2. Ziehe `FlowDictate.app` in den Ordner `Programme`.
3. Klicke in `Programme` mit der rechten Maustaste auf FlowDictate und wähle `Öffnen`.
4. Bestätige im nächsten Dialog erneut mit `Öffnen`.
5. Falls macOS nur `Abbrechen` anbietet, öffne `Systemeinstellungen → Datenschutz & Sicherheit` und klicke bei FlowDictate auf `Dennoch öffnen`.

Gib FlowDictate nur frei, wenn du die ZIP-Datei direkt von einer Person erhalten hast, der du vertraust.

## Ersteinrichtung

1. Wähle den Aufnahmeordner. Empfohlen wird `Dokumente/Recordings`.
2. Trage deinen eigenen OpenAI API-Key ein. Er wird ausschließlich im macOS-Schlüsselbund gespeichert.
3. Erlaube Mikrofonzugriff und Bedienungshilfen.
4. Lege die gewünschten Tastenkürzel fest.

Die ZIP-Datei enthält keinen API-Key und keine Zugangsdaten des Erstellers.

## Aktualisierung

Beende FlowDictate vollständig und ersetze anschließend die App im Ordner `Programme`. Da Community-Ausgaben keine dauerhafte Apple-Developer-Signatur besitzen, kann macOS nach einem Update erneut nach Mikrofon- oder Bedienungshilfen-Berechtigungen fragen.

### Schlüsselbund nach einem Update

macOS kann beim ersten Start einer neuen Community-Ausgabe einmal nach dem Anmeldepasswort fragen, weil sich die ad-hoc Signatur geändert hat. Falls die Abfrage wiederholt erscheint, öffne `Settings → Transcription`, entferne dort den bisherigen API-Key und speichere ihn anschließend erneut. Dadurch wird der Schlüsselbund-Eintrag für die aktuell installierte Ausgabe neu angelegt. FlowDictate lädt ihn danach nur einmal pro App-Sitzung.
