# FlowDictate Community installieren

Diese Ausgabe ist kostenlos und ad hoc signiert. Sie wurde nicht von Apple notarisiert. macOS zeigt deshalb beim ersten Start eine Sicherheitswarnung an.

Diese Anleitung gilt für FlowDictate 3.3.0 Community.

## Download prüfen

Lade die ZIP-Datei und die gleichnamige `.sha256`-Datei aus demselben GitHub Release. Öffne anschließend Terminal, wechsle in den Download-Ordner und prüfe das Archiv:

```sh
shasum -a 256 -c FlowDictate-3.3.0-Community-macOS.zip.sha256
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
4. Erlaube Spracherkennung nur, wenn du die optionale lokale Live Preview verwenden möchtest.
5. Wenn du Systemaudio aufnehmen möchtest, erlaube FlowDictate unter `Systemeinstellungen → Datenschutz & Sicherheit → Bildschirm- & Systemaudioaufnahme` den Zugriff. Je nach macOS-Version kann die Berechtigung auch als `Bildschirmaufnahme` oder `Nur Systemaudio` bezeichnet sein.
6. Beende und öffne FlowDictate erneut, wenn macOS nach einer neuen Berechtigung dazu auffordert.
7. Lege die gewünschten Tastenkürzel fest.

Die ZIP-Datei enthält weder einen API-Key noch ein Sprachmodell oder Zugangsdaten des Erstellers. Der optionale Modelldownload wird in den Transkriptions-Einstellungen mit Quelle, Größe und Lizenz angezeigt.

## Aktualisierung

Community-Ausgaben sind ad hoc signiert. Da sich ihre Code-Identität mit einem neuen Build ändern kann, behandelt macOS eine Aktualisierung gelegentlich wie eine neue App. Dadurch können insbesondere **Bedienungshilfen** sowie **Bildschirm- & Systemaudioaufnahme** erneut freigegeben werden müssen. Das lässt sich bei einer kostenlosen, nicht notarisierten Community-Ausgabe nicht zuverlässig vermeiden.

Verwende zum Testen immer genau die Community-ZIP, die später veröffentlicht werden soll. Ein separat gebauter oder anders signierter Test-Build ist nicht identisch mit dem Release-Artefakt.

### Empfohlener Update-Ablauf

1. Beende FlowDictate vollständig über das Menüleistensymbol. Prüfe bei Bedarf in der Aktivitätsanzeige, dass FlowDictate nicht mehr läuft.
2. Entpacke die neue Community-ZIP.
3. Ziehe die neue `FlowDictate.app` nach `Programme` und bestätige `Ersetzen`. Behalte den Namen `FlowDictate.app` und den Speicherort `/Applications/FlowDictate.app` bei.
4. Öffne FlowDictate wie bei der Erstinstallation mit Rechtsklick und `Öffnen`.
5. Teste zunächst Mikrofonaufnahme, Texteinfügung und – falls verwendet – Systemaudio. Lösche funktionierende Berechtigungen nicht vorsorglich.
6. Erneuere nur die Berechtigung, deren Funktion tatsächlich nicht mehr arbeitet. Folge dazu dem Abschnitt **Berechtigungen reparieren** weiter unten.
7. Beende und starte FlowDictate nach Änderungen an den Berechtigungen einmal vollständig neu.

Wenn du von einer Version vor 3.2.0 aktualisierst, werden vorhandene History-Daten automatisch erweitert. Vor der ersten Speicherung im neuen Format legt FlowDictate einmalig eine Sicherung namens `dictations-pre-3.2.json` im lokalen History-Ordner an. Aufnahmen und der gewählte Aufnahmeordner werden nicht verschoben.

Live Preview ist optional und nutzt ausschließlich Apples lokale Spracherkennung. Lokale finale Transkription, gesprochene Korrekturen, Formatierung und das persönliche Wörterbuch arbeiten auf dem Mac. Im Modus `Fully offline` blockiert FlowDictate Transkriptions-, Enhancement- und Update-Netzwerkzugriffe. Nur ein bewusst gewählter Cloudpfad sendet Audio oder Text an OpenAI; ein lokaler Fehler löst niemals automatisch einen Cloud-Upload aus.

### Schlüsselbund nach einem Update

macOS kann beim ersten Start einer neuen Community-Ausgabe einmal nach dem Anmeldepasswort fragen, weil sich die ad-hoc Signatur geändert hat. Falls die Abfrage wiederholt erscheint, öffne `Settings → Transcription`, entferne dort den bisherigen API-Key und speichere ihn anschließend erneut. Dadurch wird der Schlüsselbund-Eintrag für die aktuell installierte Ausgabe neu angelegt. FlowDictate lädt ihn danach nur einmal pro App-Sitzung.

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
- Keine lokale Live Preview: **Spracherkennung**
- Keine Systemaudioaufnahme oder keine auswählbaren Audioquellen: **Bildschirm- & Systemaudioaufnahme**

Setze nicht alle Datenschutzrechte gleichzeitig zurück. So bleiben bereits funktionierende Freigaben erhalten und der Update-Aufwand bleibt möglichst gering.
