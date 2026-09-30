# FlowDictate 4.1.0 Community

FlowDictate 4.1 adds opt-in meetings with separate microphone and System Audio originals, a chronological transcript labelled `You` and `System Audio`, and restart-safe processing. The labels identify audio sources, not individual remote speakers.

## Highlights

- Record microphone and System Audio together after an explicit consent reminder. The recording overlay shows both sources and their levels.
- Review, play and export each original track from History. An interrupted or partially transcribed meeting can be resumed without repeating successful track work.
- Keep local transcription and Fully offline operation, or explicitly select OpenAI with your own API key. The ZIP contains neither a key nor a speech model.
- Archive completed History entries without deleting their recordings, or use the separate confirmed action to delete a meeting and its files.

## Fixes in the release candidate

- A completely silent System Audio track no longer turns an otherwise successful microphone-only mixed recording into a partial failure. A previously failed silent track can be retried without retranscribing the microphone.
- First-run local model installation and provider selection work without requiring an OpenAI API key when the local model is selected.
- The setup identifies the microphone permission action clearly and explains that optional Live Preview also needs macOS Dictation enabled.
- The model-change restart releases the global hotkeys before launching the replacement app; overlay size and position changes update during recording.

## Known limitation

The 30-, 60- and 120-minute mixed tests preserved both original tracks but observed short System Audio gaps: 65 ms, 33 ms and 422 ms in total, respectively, with a longest individual gap of 137 ms. A gap can omit part of a word. FlowDictate reports capture-quality warnings and keeps the originals for review and recovery; zero-loss capture is not claimed for every Mac or audio route.

Build 33 passed six recording-source/provider smoke tests on the existing macOS account. Installation in an independently fresh account with this exact build, and some long-duration performance targets, were not re-tested before release; these are accepted verification gaps, not passed tests.

## Installation and privacy

Version 4.1.0 uses the new bundle identifier `de.mcc.FlowDictate` instead of `de.euler.FlowDictate`. This is a fresh macOS app identity: complete setup and permissions again, reselect the recordings folder, and reinstall the local model or re-enter your own OpenAI key. The old app's settings and History are not imported automatically; back up or export any old History you need before replacing it. Existing recordings in the separately selected folder are not deleted by the identifier change.

FlowDictate 4.1.0 supports macOS 14 or later. Local final transcription requires Apple Silicon and an approximately 650 MB model download; OpenAI transcription is available with the user's own API key. Mixed originals alone can require roughly 1.4 GB per hour, plus working files. This Community build is ad hoc signed and not notarized, so macOS may require manual first-launch approval or renewed permissions after an update. Follow the installation guide included in the ZIP.

No video is captured or saved. Local transcription does not upload audio; the explicitly selected OpenAI path sends the selected audio to OpenAI when the privacy mode permits it. Meeting recording consent remains the user's responsibility.
