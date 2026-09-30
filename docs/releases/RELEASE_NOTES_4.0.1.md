# FlowDictate 4.0.1 Community

FlowDictate 4.0.1 is a focused maintenance update for the keyboard-shortcut activation modes introduced in 4.0.

## Fixed

- Press-and-hold activation now stops the active recording when the dictation shortcut is released.
- Toggle, Cancel and Restore Last shortcut behavior remains unchanged.
- A regression test verifies that pressing starts recording and releasing stops, transcribes and inserts exactly once.

## Compatibility

- macOS 14 or later.
- Universal Community app with `arm64` and `x86_64` slices.
- Local final transcription requires Apple Silicon.
- Intel Macs retain OpenAI transcription and all other supported non-local features.
- The optional local model is downloaded after installation and is not included in the ZIP.

## Distribution

The Community ZIP is ad hoc signed and intentionally not notarized. It contains no API key and no local speech model. Existing FlowDictate settings, History, recordings-folder selection and Keychain credential remain local and are reused after replacing the app.
