# FlowDictate 3.3.0 Community

FlowDictate 3.3.0 adds System Audio capture, app-specific profiles and local productivity features while keeping microphone dictation, Live Preview and Smart Dictation fully available.

## Highlights

- Record either the microphone or digital System Audio with a dedicated five-second source test.
- See the active source, recording level and processing status in the compact monitor-style overlay.
- Keep completed System Audio transcripts in the clipboard and open the saved recording directly from FlowDictate.
- Apply app-specific language, transcription model, writing style, spoken-formatting and insertion settings.
- Insert text directly through Accessibility where supported, with a safe clipboard fallback.
- Choose toggle or press-and-hold shortcut activation.
- Review optional local usage statistics calculated from History.
- Receive an optional daily notice when a newer stable GitHub release is available.
- Use clearer spoken formatting for automatic commas, new lines and numbered items.

## System Audio notes

System Audio capture stores audio only and registers no video output. Live Preview is unavailable for System Audio recordings. Keep individual recordings to approximately 15–20 minutes for reliable single-request transcription; automatic chunking is planned for Phase 3.4.

macOS requires **Screen & System Audio Recording** permission for this feature. Because the Community edition is ad hoc signed, an update may require this permission or Accessibility access to be granted again. The German and English installation guides inside the ZIP contain a targeted repair procedure that avoids resetting permissions that still work.

## Privacy and API usage

Microphone and System Audio recordings are stored in the folder selected by the user. A recording is sent directly to OpenAI only when it is submitted for transcription. The five-second source test is deleted locally and never uploaded.

App profiles and usage statistics remain local. The update check sends no user content and never installs software automatically. Optional AI writing styles send the already transcribed text, not the recording, in a separate request using the owner's API key.

## Updating

1. Quit FlowDictate completely.
2. Replace `/Applications/FlowDictate.app` with the app from this Community ZIP; keep its name and location unchanged.
3. Open it once using right-click → `Open`.
4. Test microphone dictation, insertion and System Audio before removing any existing permission.
5. If one feature fails, renew only its corresponding macOS permission as described in `INSTALLATION-DE.md` or `INSTALLATION-EN.md`.

Existing settings, recordings, folder selection, History and Keychain credentials remain local.

## Installation

This free Community build is ad hoc signed and not notarized. No paid Apple Developer membership is used.

Required:

- macOS 14 or later
- an OpenAI API key belonging to the person using the app
- Microphone and Accessibility permissions for microphone dictation and automatic insertion
- Screen & System Audio Recording permission only for System Audio capture
- Speech Recognition permission only for the optional local Live Preview

## Assets

Download both files from this GitHub Release:

- `FlowDictate-3.3.0-Community-macOS.zip`
- `FlowDictate-3.3.0-Community-macOS.zip.sha256`

Verify the download before installation:

```sh
shasum -a 256 -c FlowDictate-3.3.0-Community-macOS.zip.sha256
```

## Validation

- All 46 automated unit tests passed.
- The Release build completed successfully for Apple Silicon and Intel Macs.
- Microphone recording, Live Preview, final transcription, Smart Dictation, insertion, Settings during recording and System Audio were manually tested on the reference Mac.

Known distribution limitation: Gatekeeper requires manual first-launch approval, and macOS may request individual permissions or Keychain approval again after an update because the Community app is ad hoc signed.
