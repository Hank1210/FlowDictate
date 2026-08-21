# Installing FlowDictate Community

This is the free, ad hoc signed edition. It has not been notarized by Apple, so macOS displays a security warning the first time it is opened.

This guide applies to FlowDictate 3.2.0 Community.

## Verify the download

Download the ZIP and the matching `.sha256` file from the same GitHub Release. Open Terminal, change to the download folder, and verify the archive:

```sh
shasum -a 256 -c FlowDictate-3.2.0-Community-macOS.zip.sha256
```

Terminal must report `OK`. Do not install the app if verification fails.

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
4. Grant Speech Recognition only if you want to use the optional local Live Preview.
5. Configure your preferred keyboard shortcuts.

The ZIP file does not contain an API key or any credentials belonging to the person who created it.

## Updating

Quit FlowDictate completely, then replace the app in the `Applications` folder. Because Community editions do not have a permanent Apple Developer signature, macOS may ask you to grant Microphone or Accessibility permissions again after an update.

On the first launch of 3.2.0, existing History data is extended automatically. Before saving the new format for the first time, FlowDictate creates a one-time `dictations-pre-3.2.json` backup in the local History folder. Recordings and the selected recordings folder are not moved.

Live Preview is optional and requires Apple's on-device speech recognition. Spoken formatting and the personal dictionary run locally. Only a writing style that explicitly uses AI sends the already transcribed text to OpenAI in an additional request.

### Keychain access after an update

The first launch of a new Community edition may ask for your macOS login password once because its ad hoc signature has changed. If the prompt keeps appearing, open `Settings → Transcription`, remove the existing API key, and then save it again. This recreates the Keychain entry for the currently installed edition. FlowDictate will then load it only once per app session.

### Permissions after an update

If recording, insertion, or Live Preview does not work after replacing the app, remove the old FlowDictate entry under `System Settings → Privacy & Security` from **Microphone**, **Accessibility**, or **Speech Recognition**, as applicable, and grant access to the newly installed app again.
