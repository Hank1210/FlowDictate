# Installing FlowDictate Community

This is the free, ad hoc signed edition. It has not been notarized by Apple, so macOS displays a security warning the first time it is opened.

## Installation

1. Extract the ZIP file.
2. Drag `FlowDictate.app` into the `Applications` folder.
3. In `Applications`, right-click FlowDictate and select `Open`.
4. Confirm the next dialog by clicking `Open` again.
5. If macOS only offers `Cancel`, open `System Settings → Privacy & Security` and click `Open Anyway` next to FlowDictate.

Only approve FlowDictate if you received the ZIP file directly from someone you trust.

## First-time setup

1. Choose the recordings folder. `Documents/Recordings` is recommended.
2. Enter your own OpenAI API key. It is stored exclusively in the macOS Keychain.
3. Grant Microphone and Accessibility permissions.
4. Configure your preferred keyboard shortcuts.

The ZIP file does not contain an API key or any credentials belonging to the person who created it.

## Updating

Quit FlowDictate completely, then replace the app in the `Applications` folder. Because Community editions do not have a permanent Apple Developer signature, macOS may ask you to grant Microphone or Accessibility permissions again after an update.

### Keychain access after an update

The first launch of a new Community edition may ask for your macOS login password once because its ad hoc signature has changed. If the prompt keeps appearing, open `Settings → Transcription`, remove the existing API key, and then save it again. This recreates the Keychain entry for the currently installed edition. FlowDictate will then load it only once per app session.
