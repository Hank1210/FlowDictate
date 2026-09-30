# FlowDictate 4.0.0 Community

FlowDictate 4.0 is the local-first transcription release. It adds optional final transcription on supported Apple-Silicon Macs without an API key while retaining the existing OpenAI BYOK path on Apple Silicon and Intel.

## Highlights

- Local final transcription with FluidAudio 0.15.5 and Parakeet TDT 0.6B v3.
- Explicit Fully offline, Local transcription and Cloud transcription privacy modes.
- No silent local-to-cloud fallback.
- Restart-safe persistent processing for one dictation at a time.
- A new recording becomes available after transcription, formatting and insertion complete.
- Restart-safe job manifests, frozen provider/profile settings and deferred insertion when the original target is no longer safe.
- Provider overrides in app profiles.
- German and English spoken replace, replace-all, delete and undo corrections before formatting.
- Corrected transcript, correction summary, queue sequence and job state in History.
- History schema 6 with a one-time `dictations-pre-4.0.json` backup.
- Automatic insertion uses direct Accessibility first and falls back to the clipboard only for unsupported target controls. A `Clipboard only` app-profile option remains available for applications that need it.
- AI writing styles remain selectable but are visibly inactive when the current privacy mode does not permit OpenAI improvement; the local transcript is still inserted instead of failing before insertion.
- Privacy & Provider separately identifies the audio-transcription location and optional OpenAI text improvement.
- History and job-manifest file operations plus local text formatting no longer execute on the Main Actor, keeping overlay timers and shortcuts responsive during slow storage or text processing.
- The short `Inserted` confirmation and active queue slot are released before the completed History snapshot is flushed. The recovery manifest remains until the background JSON write succeeds, so slow persistence cannot prolong the black overlay or block the next recording.
- Live Preview capability checks are cached, and stale preview resources are cancelled when the recording source changes.
- Changing the transcription provider, privacy mode or recognition model is saved immediately but requires `Quit & Restart` before another dictation can begin. App-profile provider/model changes follow the same rule. This deliberate gate prevents one app session from mixing previously loaded local and OpenAI resources.
- OpenAI dictations reuse one provider session across consecutive cloud recordings. Cleanup of temporary cloud-upload files occurs after the transcript result has returned, preventing slow filesystem removal from extending Processing after OpenAI has already responded.
- Repeated Smart Dictation stages no longer rewrite the complete JSON History during one job. Final writes are coalesced, and Microsoft Word uses the clipboard insertion path immediately, preventing the session-state slowdown that previously disappeared only after restarting FlowDictate.
- Optional OpenAI writing-style improvement reuses its network session across consecutive dictations, eliminating the local connection-setup buildup observed before the `Improving Text` request. `Quit & Restart FlowDictate` is also available directly in the menu after the regular Quit action.

## Compatibility

- macOS 14 or later.
- Universal Community app with arm64 and x86_64 slices.
- Local final transcription requires Apple Silicon.
- Intel Macs retain OpenAI transcription and all other supported FlowDictate features.
- The optional local model is downloaded after installation and is not included in the ZIP.

## Privacy

Local final transcription keeps recording audio on the Mac. Fully offline mode blocks cloud transcription, AI enhancement, credential validation and update checks. Optional cloud writing styles can send locally processed text only when explicitly enabled. FlowDictate has no analytics, telemetry or developer-operated backend.

## Validation

Build 24 passed the complete automated unit-test suite and manual microphone, System Audio, local, optional-enhancement and OpenAI performance tests using the final Community ZIP on Apple Silicon. The packaged app is ad hoc signed, contains verified `arm64` and `x86_64` slices and has SHA-256 `13c70752dcfa3ae0ec5795c0cccb624d8650c5a12fc588bad9577104da697cf6`. A physical Intel launch test was not available for this release; the universal Intel build remains an explicitly accepted residual risk.
