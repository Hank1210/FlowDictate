# FlowDictate 3.4.0 Community

FlowDictate 3.4.0 adds restart-safe transcription of long recordings and improves feedback in the recording overlay and Productivity settings.

## Highlights

- Automatically split long or oversized microphone and System Audio recordings into upload-safe local M4A segments.
- Transcribe segments sequentially, preserve each successful partial result and merge them in recording order.
- Continue an interrupted or failed long-form transcription without uploading completed segments again.
- Show segment progress in the overlay and History while keeping the original recording and available text after partial failures.
- Check upload size, source integrity and available working storage before transfer.
- View local Productivity statistics for Total, 30 days or 14 days and reset the statistics baseline without deleting History.
- See clear feedback when checking GitHub for a newer stable Community release.

## Overlay and Preview clarity

- Microphone recognition is labelled **Live Preview** because it is provisional and never replaces final OpenAI transcription.
- System Audio explicitly states that Live Preview is unavailable and that transcription starts after recording stops.
- The completed overlay changes to **Inserted** immediately after confirmed insertion and dismisses promptly.
- Accessibility insertion is time-bounded and displayed as **Inserting…**, preventing an unresponsive target application from leaving the overlay indefinitely on Processing.
- Starting another dictation cancels an older success-overlay timer so the new recording remains visible.

## Long-recording safety

Successful segment text is written to a local session manifest before FlowDictate advances to the next upload. The original recording is never modified by segmentation. Temporary segment files are removed after use, while resumable state and partial text remain protected after interruption, temporary provider failure or relaunch.

Network transcription remains intentionally sequential in this release. This limits memory and temporary-storage pressure and makes retry and recovery deterministic.

## Privacy and API usage

Audio is sent directly to OpenAI using the owner's API key only for final transcription. Segment files, manifests, History, app profiles and usage statistics remain local. Live Preview uses Apple's on-device recognizer and provisional Preview text is not persisted. FlowDictate contains no analytics, advertising, developer-operated backend or bundled API credentials.

## Updating

1. Quit FlowDictate completely.
2. Replace `/Applications/FlowDictate.app` with the app from this Community ZIP.
3. Open it once using right-click → **Open**.
4. Reapprove only those macOS permissions that no longer work.
5. Test a short microphone dictation and the selected System Audio workflow before removing the previous ZIP.

Existing settings, History, recordings, folder selection and Keychain credentials remain local. A one-time `dictations-pre-3.4.json` History backup is created when migration is required.

## Installation

This free Community build is ad hoc signed and not notarized. It requires macOS 14 or later and an OpenAI API key belonging to the user. Follow `INSTALLATION-DE.md` or `INSTALLATION-EN.md` from the ZIP for Gatekeeper and permission guidance.

## Release assets

- `FlowDictate-3.4.0-Community-macOS.zip`
- `FlowDictate-3.4.0-Community-macOS.zip.sha256`

Verify the archive with:

```sh
shasum -a 256 -c FlowDictate-3.4.0-Community-macOS.zip.sha256
```

The packaged build passed checksum, signature, architecture and short microphone/insertion smoke tests. A two-segment long-form transcription and System Audio were also tested during Phase 3.4 development. Testing on a second Mac and repeating recovery with the final ZIP remain documented limitations of this Community release.
