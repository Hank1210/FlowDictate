# FlowDictate 4.0.2 Community

FlowDictate 4.0.2 is a focused maintenance update for Spoken Formatting, AI writing-style layout preservation and processing diagnostics.

## Fixed

- Spoken Formatting now handles automatic sentence punctuation after spoken commands such as `Neue Zeile.`, `new line.`, `Doppelpunkt.` and `colon.`.
- German `Absatz` is now accepted as an alias for `neuer Absatz`.
- AI writing styles preserve user-requested line and paragraph breaks by protecting them with layout markers during enhancement and restoring them before insertion.
- Enhancements that drop protected layout markers are rejected instead of silently flattening dictated structure.
- AI writing styles no longer treat dictated questions or requests as instructions to answer. Assistant-like enhancement responses are rejected locally and can fall back to the local transcript.
- Smart Dictation validation errors now report which protected token or layout marker is missing.
- Very short recordings, for example when releasing a press-and-hold shortcut too early, now fail during preflight with a clear message instead of starting local transcription and surfacing a FluidAudio `Invalid audio data` error.
- The Live Preview character slider is clearer, hidden for the Compact overlay and now updates active preview sessions immediately. Standard allows up to 200 and Expanded up to 800 characters.
- The standard Live Preview overlay keeps the newest preview text visible when the preview exceeds three lines, avoiding misleading end-of-text ellipses that looked like a stalled preview.
- The standard Live Preview overlay now caps the configurable Preview character range at 200 characters while keeping the newest visible text in view once the preview exceeds three lines.
- The Compact overlay no longer starts or displays Live Preview text; it remains a minimal recording/status indicator.
- Live Preview now writes privacy-safe diagnostics for preview cadence, audio-buffer drops and stalled partial recognition without logging transcript content.
- The Inserted overlay auto-hide now uses a dedicated deadline timer and logs late callbacks, reducing cases where the success banner stays visible long after insertion has completed.

## Changed

- The pre-transcription persistence log span is now split into manifest update, overlay update and History staging measurements for better diagnosis of intermittent slow processing.

## Notes

This release keeps the stable bundle identifier `de.euler.FlowDictate`. The Community ZIP does not include API keys or local speech models.
