# Changelog

All notable user-facing changes to FlowDictate are documented here.

## [Unreleased]

## [4.0.2] - 2026-09-10

### Fixed

- Spoken Formatting now consumes automatic sentence punctuation after spoken formatting commands such as `Neue Zeile.`, `new line.`, `Doppelpunkt.` and `colon.` so punctuation no longer appears at the beginning of the next line or after inserted punctuation.
- German `Absatz` is now accepted as an alias for `neuer Absatz`.
- AI writing styles now protect user-requested line and paragraph breaks with explicit layout markers during enhancement and restore them before insertion. If an enhancement drops a protected layout marker, the result is rejected instead of silently flattening the dictated structure.
- AI writing styles now explicitly treat dictated questions and requests as transcript content, not as instructions to answer. Assistant-like enhancement responses are rejected locally so FlowDictate can fall back to the local transcript instead of inserting an answer.
- Smart Dictation validation errors now identify the missing protected number, URL, dictionary term or layout marker instead of returning only a generic rejection reason.
- Very short recordings now fail during preflight with a clear "recording too short" message. This avoids starting local transcription for sub-300 ms press-and-hold captures and prevents the underlying FluidAudio `Invalid audio data` error from surfacing to users.
- The Live Preview character slider is now labeled more clearly, hidden for the Compact overlay, explains its relationship to the overlay size and applies changes to active preview sessions without requiring a new recording.
- The standard Live Preview overlay now keeps the newest preview text visible once the preview exceeds three lines, avoiding misleading end ellipses that made active recognition look stalled.
- The standard Live Preview overlay now caps the configurable Preview character range at 200 characters while keeping the newest visible text in view once the preview exceeds three lines.
- The Compact overlay no longer starts or displays Live Preview text; it remains a minimal recording/status indicator.
- Live Preview now emits privacy-safe diagnostics for preview-event cadence, audio-buffer drops and stalled partial recognition without logging dictated text.
- The Inserted overlay auto-hide now uses a dedicated deadline timer and logs late callbacks so success banners do not depend solely on a delayed Main Actor sleep.

### Changed

- Processing diagnostics now split the pre-transcription persistence span into manifest update, overlay update and History staging measurements to make intermittent slow-path analysis actionable.

## [4.0.1] - 2026-09-01

### Fixed

- Press-and-hold shortcut activation now stops and processes the recording when the dictation hotkey is released. The release callback is part of the registrar protocol contract and is covered by a coordinator regression test.

## [4.0.0] - 2026-08-30

### Added

- Optional fully local final transcription on Apple Silicon using FluidAudio and Parakeet TDT 0.6B v3; OpenAI remains available as a BYOK cloud provider and Intel fallback.
- Explicit Fully offline, Local transcription and Cloud transcription privacy modes with a central network-policy gate and no silent local-to-cloud fallback.
- A persistent dictation-job manifest that preserves frozen provider/profile/target configuration, supports restart recovery and defers unsafe post-restart insertion.
- Local model download, validation, staged activation, removal and hardware/storage availability feedback.
- German and English inline correction commands for replace, replace all, last word/sentence deletion, undo and literal escape.
- Provider overrides in app profiles plus queue/correction metadata and a corrected-transcript stage in History.

### Changed

- History and dictation-record schemas upgraded to version 6 with a one-time `dictations-pre-4.0.json` backup; unknown future schemas are never overwritten.
- First-run onboarding now offers Local or OpenAI and requires an API key only for the cloud path.
- Local inference and upload preparation are isolated from the Main Actor; the model manager is reused across jobs and processing never automatically inserts into an unknown target after restart.
- Continuous dictation queueing is disabled in 4.0. A new recording starts only after the current dictation has completed, matching the predictable 3.4 interaction model.
- FluidAudio is pinned to 0.15.5. The Community app remains universal; local inference is available only on Apple Silicon while Intel retains OpenAI and all non-local features.
- Processing diagnostics now separate queue wait, transcription, local correction, writing-style enhancement and insertion duration; AI styles also identify their additional cloud request in Settings and in the overlay.
- Changing the transcription provider, privacy mode or recognition model now requires `Quit & Restart` before another dictation can begin. This also applies when an app profile would change provider or model. The selection is saved, but a single app session never mixes previously loaded local and OpenAI transcription resources.

### Fixed

- Optional OpenAI text improvement now reuses one enhancer and network session across consecutive dictations instead of rebuilding the connection for every `Improving Text` stage. API-key changes invalidate both OpenAI runtimes, and the menu now offers `Quit & Restart FlowDictate` directly beside the normal Quit action.
- Session-long processing and `Inserted` delays no longer accumulate: queued Smart Dictation stages remain in memory until one final History flush, completion flushes are coalesced, and Microsoft Word goes directly through the reliable clipboard path instead of its occasionally blocking Accessibility probe.
- OpenAI transcription now reuses its provider and URL session across consecutive cloud dictations, and temporary multipart/audio cleanup runs asynchronously after the response. A slow filesystem cleanup can therefore no longer turn an already completed cloud response into several additional seconds of Processing.
- Successful insertion no longer awaits the `Inserted` display timer before releasing the interaction and enabling the next dictation. The confirmation now dismisses independently, preventing an occasional delayed Main Actor wake-up from holding the completed job. General and Transcription settings also provide a clearly explained `Quit & Restart` recovery action for exceptional post-configuration slowdowns.
- Changing privacy mode or transcription provider now applies one normalized settings transition and is blocked during an active dictation. A mandatory restart gate prevents further recording until all previously loaded transcription resources have been reset.
- Live Preview availability is cached instead of constructing a new macOS speech recognizer during every Settings redraw. Changing the recording source also cancels stale preview resources.
- The short `Inserted` confirmation and active queue slot now finish before the completed History record is flushed. The recovery manifest is retained until the background JSON write succeeds, so slow atomic persistence cannot keep the black overlay visible or delay the next recording without sacrificing restart recovery.
- History JSON and dictation-job manifest reads, encoding and atomic writes now run on dedicated serial background queues, so slow local storage cannot hold the Main Actor, hotkeys or overlay dismissal.
- Spoken formatting and personal-dictionary processing now run outside the Main Actor. Diagnostics split both transformations, their in-memory History stages and post-completion queue cleanup into separate timings.
- Automatic app profiles again insert directly through Accessibility first, matching the 3.4 behavior and avoiding unnecessary macOS clipboard privacy notices. The direct request runs off the Main Actor with a short messaging timeout; unsupported targets use the clipboard as a bounded fallback, while `Clipboard only` remains an explicit per-app option.
- Selecting an AI writing style no longer blocks insertion when Fully offline mode is active or optional OpenAI improvement is disabled. FlowDictate keeps the selected style, clearly marks it inactive and inserts the locally formatted transcript without making a network request.
- Privacy & Provider now distinguishes where audio transcription runs from whether an optional AI writing-style improvement can send text to OpenAI.
- Processing diagnostics now measure record lookup, state persistence and provider resolution separately, making delays before the provider request visible instead of attributing them to transcription.
- Accessibility insertion runs outside the Main Actor and applies its timeout
  to both the target application and focused text element before using the
  clipboard fallback.
- Successful short dictations no longer rewrite the complete JSON History at
  every intermediate stage; the final record is persisted after visible text
  insertion while the durable job manifest retains recovery state.
- Duplicate shortcut events during a recording transition no longer produce an unintended immediate start-stop cycle, including an early release in press-and-hold mode.
- Global shortcuts use a deduplicated NSEvent fallback when macOS does not deliver the registered Carbon hotkey event reliably.
- Newly committed dictations begin processing immediately instead of waiting behind a stale background queue drain.
- Successful insertion is confirmed and dismissed immediately after the paste; delayed History persistence can no longer leave the overlay visibly stuck on Inserting.
- Empty or silent recordings release the processing state after failure so recording source and profile controls remain available.
- Local model installation promotes FluidAudio's actual downloaded repository instead of a temporary anchor folder and safely handles repeated install requests.

## [3.4.0] - 2026-08-25

### Added

- Automatic local segmentation of long or oversized recordings, with silence-sensitive boundaries and a short overlap between adjacent segments.
- Sequential segment transcription with ordered merging, per-segment retry, atomic session manifests and resumable partial results.
- Segment progress in the recording overlay and History, including a Continue Transcription action after pause, failure or app restart.
- Preflight checks for source integrity, estimated upload size, actual segment size and available working storage.
- Productivity statistics with Total, 30-day and 14-day views, additional averages and a non-destructive statistics reset.

### Changed

- History schema upgraded to version 5 with migration-safe long-form summary fields and a one-time `dictations-pre-3.4.json` backup.
- Audio inspection, boundary detection and segment export run outside the Main Actor; stop, export, transcription and merge durations are logged locally for profiling.
- Long-form transcription uses one network request at a time and removes temporary segment audio after each successful segment.
- App version advanced to 3.4.0 (build 8) for the local Community release candidate.

### Fixed

- Successful segments are not uploaded again after retry, pause or relaunch.
- Original recordings and completed partial transcripts remain local after segment-level failures.
- M4A recordings without History entries are included in startup orphan recovery.
- System Audio no longer suggests that a Live Transcript is being created; microphone recognition is labelled accurately as Live Preview.
- Community update checks now show checking, current-version and error feedback directly in Productivity settings.
- The success overlay dismisses promptly, cannot hide a newly started recording and no longer remains on Processing while completed History metadata is written.
- Accessibility insertion uses a bounded messaging timeout so an unresponsive target cannot hold a short dictation in Processing; the overlay identifies this stage as Inserting.

## [3.3.0] - 2026-08-25

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
- App version advanced to 3.3.0 (build 7).
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

[Unreleased]: https://github.com/Hank1210/FlowDictate/compare/v3.3.0...HEAD
[3.3.0]: https://github.com/Hank1210/FlowDictate/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/Hank1210/FlowDictate/compare/v2.0.0...v3.2.0
[2.0.0]: https://github.com/Hank1210/FlowDictate/releases/tag/v2.0.0
