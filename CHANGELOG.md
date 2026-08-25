# Changelog

All notable user-facing changes to FlowDictate are documented here.

## [Unreleased]

### Added

- Separate microphone and ScreenCaptureKit System Audio recording sources with source metadata in the overlay and History.
- System Audio permission guidance and a five-second local test that never uploads or writes History.
- App profiles keyed by bundle identifier for language, transcription model, writing style, spoken formatting and insertion preference.
- Direct Accessibility insertion with clipboard fallback and protected-field blocking.
- Toggle and press-and-hold shortcut activation modes.
- Optional local usage statistics and a disableable stable GitHub-release notice.

### Changed

- History schema upgraded to version 4 with microphone defaults for older records.
- Recorder lifecycle is asynchronous and source-independent; microphone remains the default for all migrations.
- System Audio asset writing runs off the main actor and limits level updates to ten per second.
- Development app version advanced to 3.3.0 (build 7); the public release remains pending manual validation.
- System Audio recording now displays the recommended 15–20 minute transcription limit together with the unavailable-Preview notice.
- The recording overlay now uses a compact black monitor-style layout with a narrow neon-green level meter and light-gray Preview text.

### Privacy

- System Audio capture registers no video output and persists no screen content.
- App profiles and usage statistics remain local; update checks send no user content.

### Fixed

- System Audio level metering now calculates RMS from the actual PCM samples instead of estimating a level from raw packet bytes.
- Completed System Audio transcripts remain in the clipboard, and the menu shows the exact saved recording path with a Finder shortcut.
- Failure messages for retained recordings now include the complete local file path.
- Stopping a long System Audio recording no longer synchronously blocks the main thread, and the overlay acknowledges the shortcut immediately.
- System Audio is stored as transcription-optimized mono AAC, reducing recording size and upload volume by roughly half.
- Completed System Audio recordings now show a compact clipboard confirmation and have a defensive 1.2-second maximum display time for the success overlay.

## [3.2.0] - 2026-08-21

### Added

- Optional on-device Apple Speech Live Preview with compact, standard and expanded recording overlays.
- Configurable overlay placement, Preview length and a five-second local Preview test.
- Spoken formatting commands for German and English.
- A local personal dictionary with whole-word, language and capitalization rules plus JSON import/export.
- Built-in and custom writing styles with optional OpenAI text enhancement.
- Separate Original, Formatted, Dictionary and Final stages in History.
- Enhancement retry, local/original fallbacks and style reprocessing without retranscribing audio.
- Independent retention limits for visible History and locally retained audio.
- A dedicated macOS app icon.

### Changed

- History schema upgraded to version 3 with backward-compatible decoding and a one-time pre-3.2 backup.
- Recording overlay and audio level presentation updated for clearer feedback and lower UI update frequency.
- Settings reorganized to explain Live Preview and Smart Dictation behavior.
- App version updated to 3.2.0 (build 4).

### Fixed

- Opening Settings during recording no longer hides or disconnects the Preview overlay and audio level.
- Preview audio uses immutable samples and starts only after the microphone engine is stable.
- Missing SF Symbols in the recording and Smart Dictation UI were replaced with supported symbols.
- Restore and insertion handling is more resilient when application focus changes.
- Community Keychain access no longer prompts after every recording once the credential is saved for the current build.

### Privacy

- Live Preview requires on-device recognition and does not persist provisional text.
- Spoken formatting and dictionary replacements remain entirely local.
- AI enhancement is opt-in by writing style, sends text but not audio, and requests `store: false`.

## [2.0.0] - 2026-08-18

### Added

- Standalone menu bar application with first-run onboarding.
- User-selectable recordings folder with `Documents/Recordings` as the recommended default.
- Per-installation OpenAI API key storage in macOS Keychain.
- Persistent History, recovery, retry, Restore Last Dictation and retention controls.
- Free ad hoc signed Community ZIP workflow with German and English installation guides.

[Unreleased]: https://github.com/Hank1210/FlowDictate/compare/v3.2.0...HEAD
[3.2.0]: https://github.com/Hank1210/FlowDictate/compare/v2.0.0...v3.2.0
[2.0.0]: https://github.com/Hank1210/FlowDictate/releases/tag/v2.0.0
