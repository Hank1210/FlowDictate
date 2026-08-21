# FlowDictate Community installieren

Diese Ausgabe ist kostenlos und ad hoc signiert. Sie wurde nicht von Apple notarisiert. macOS zeigt deshalb beim ersten Start eine Sicherheitswarnung an.

Diese Anleitung gilt für FlowDictate 3.2.0 Community.

## Download prüfen

Lade die ZIP-Datei und die gleichnamige `.sha256`-Datei aus demselben GitHub Release. Öffne anschließend Terminal, wechsle in den Download-Ordner und prüfe das Archiv:

```sh
shasum -a 256 -c FlowDictate-3.2.0-Community-macOS.zip.sha256
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
2. Trage deinen eigenen OpenAI API-Key ein. Er wird ausschließlich im macOS-Schlüsselbund gespeichert.
3. Erlaube Mikrofonzugriff und Bedienungshilfen.
4. Erlaube Spracherkennung nur, wenn du die optionale lokale Live Preview verwenden möchtest.
5. Lege die gewünschten Tastenkürzel fest.

Die ZIP-Datei enthält keinen API-Key und keine Zugangsdaten des Erstellers.

## Aktualisierung

Beende FlowDictate vollständig und ersetze anschließend die App im Ordner `Programme`. Da Community-Ausgaben keine dauerhafte Apple-Developer-Signatur besitzen, kann macOS nach einem Update erneut nach Mikrofon- oder Bedienungshilfen-Berechtigungen fragen.

Beim ersten Start von 3.2.0 werden vorhandene History-Daten automatisch erweitert. Vor der ersten Speicherung im neuen Format legt FlowDictate einmalig eine Sicherung namens `dictations-pre-3.2.json` im lokalen History-Ordner an. Aufnahmen und der gewählte Aufnahmeordner werden nicht verschoben.

Live Preview ist optional und nutzt ausschließlich Apples lokale Spracherkennung. Gesprochene Formatierung und das persönliche Wörterbuch arbeiten lokal. Nur ein bewusst ausgewählter AI-Schreibstil sendet den bereits transkribierten Text in einer zusätzlichen Anfrage an OpenAI.

### Schlüsselbund nach einem Update

macOS kann beim ersten Start einer neuen Community-Ausgabe einmal nach dem Anmeldepasswort fragen, weil sich die ad-hoc Signatur geändert hat. Falls die Abfrage wiederholt erscheint, öffne `Settings → Transcription`, entferne dort den bisherigen API-Key und speichere ihn anschließend erneut. Dadurch wird der Schlüsselbund-Eintrag für die aktuell installierte Ausgabe neu angelegt. FlowDictate lädt ihn danach nur einmal pro App-Sitzung.

### Berechtigungen nach einem Update

Falls Aufnahme, Einfügung oder Live Preview nach dem Austausch nicht funktionieren, entferne den alten FlowDictate-Eintrag unter `Systemeinstellungen → Datenschutz & Sicherheit` aus **Mikrofon**, **Bedienungshilfen** beziehungsweise **Spracherkennung** und erteile der neu installierten App die jeweilige Freigabe erneut.
