# FlowDictate 3.2.0 Community

FlowDictate 3.2.0 adds local Live Preview and Smart Dictation to the reliable standalone foundation introduced in 2.0.

## Highlights

- See provisional text while speaking through Apple's on-device Speech framework.
- Choose compact, standard, or expanded recording overlays and place them on the preferred screen edge.
- Use deterministic German and English spoken-formatting commands.
- Correct names and specialist terms with a local personal dictionary.
- Select built-in or custom writing styles, with optional OpenAI text enhancement.
- Inspect Original, Formatted, Dictionary, and Final text stages in History.
- Retry only the enhancement or fall back to local/original text without retranscribing the audio.
- Use the new FlowDictate app icon in Finder and macOS permission settings.

## Privacy and API usage

Live Preview requires Apple's on-device recognition and does not replace the final OpenAI transcription. Provisional text is kept only in memory. Spoken formatting and personal-dictionary replacements run locally.

The **Original** writing style makes no additional AI request. A style marked as using AI sends only the locally processed transcript, style instruction, and language—not the recording or dictionary rules—to OpenAI using the owner's API key. FlowDictate requests `store: false`.

## Updating from 2.0.0

1. Quit FlowDictate completely.
2. Replace the existing app in `Applications` with the 3.2.0 app.
3. Open it once using right-click → Open.
4. Reapprove macOS permissions if requested.

Existing settings, recordings, folder selection, and Keychain credentials remain local. History is migrated automatically; FlowDictate creates a one-time `dictations-pre-3.2.json` backup before saving the new schema.

## Installation

This free Community build is ad hoc signed and not notarized. No paid Apple Developer membership is used. Follow `INSTALLATION-DE.md` or `INSTALLATION-EN.md` inside the ZIP.

Required:

- macOS 14 or later
- an OpenAI API key belonging to the person using the app
- Microphone and Accessibility permissions

Speech Recognition permission is optional and required only for Live Preview.

## Assets

Attach these two files to the GitHub Release:

- `FlowDictate-3.2.0-Community-macOS.zip`
- `FlowDictate-3.2.0-Community-macOS.zip.sha256`

Verify the download before installation:

```sh
shasum -a 256 -c FlowDictate-3.2.0-Community-macOS.zip.sha256
```

## Validation

- 39 automated tests passed.
- Debug and Release builds completed successfully on the reference Mac.
- Recording, Live Preview, final transcription, Smart Dictation, insertion, and Settings-during-recording were manually smoke-tested.

Known distribution limitation: because the Community app is ad hoc signed, Gatekeeper requires manual first-launch approval and macOS may request permissions or Keychain approval again after an update.
