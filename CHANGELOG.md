# Changelog

All notable user-facing changes to FlowDictate are documented here.

## [Unreleased]

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
