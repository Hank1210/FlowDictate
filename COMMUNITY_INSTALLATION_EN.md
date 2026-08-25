# Installing FlowDictate Community

This is the free, ad hoc signed edition. It has not been notarized by Apple, so macOS displays a security warning the first time it is opened.

This guide applies to FlowDictate 3.3.0 Community.

## Verify the download

Download the ZIP and the matching `.sha256` file from the same GitHub Release. Open Terminal, change to the download folder, and verify the archive:

```sh
shasum -a 256 -c FlowDictate-3.3.0-Community-macOS.zip.sha256
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
5. To record system audio, allow FlowDictate under `System Settings → Privacy & Security → Screen & System Audio Recording`. Depending on your macOS version, the permission may be labelled `Screen Recording` or `System Audio Only`.
6. Quit and reopen FlowDictate if macOS asks you to do so after granting a new permission.
7. Configure your preferred keyboard shortcuts.

The ZIP file does not contain an API key or any credentials belonging to the person who created it.

## Updating

Community editions are signed ad hoc. Because their code identity can change with a new build, macOS may occasionally treat an update as a new app. In particular, **Accessibility** and **Screen & System Audio Recording** may need to be granted again. This cannot be avoided reliably for a free, non-notarized Community edition.

Always test the exact Community ZIP that will be published. A separately built or differently signed test build is not identical to the release artifact.

### Recommended update procedure

1. Quit FlowDictate completely from its menu bar icon. If necessary, use Activity Monitor to confirm that FlowDictate is no longer running.
2. Extract the new Community ZIP.
3. Drag the new `FlowDictate.app` into `Applications` and confirm `Replace`. Keep the name `FlowDictate.app` and the location `/Applications/FlowDictate.app` unchanged.
4. Open FlowDictate as described for the initial installation by right-clicking it and selecting `Open`.
5. First test microphone recording, text insertion, and system audio if you use it. Do not remove permissions that are still working.
6. Renew only the permission for the feature that is actually failing. Follow **Repairing permissions** below.
7. After changing permissions, quit FlowDictate completely and open it again.

When updating from a version earlier than 3.2.0, existing History data is extended automatically. Before saving the new format for the first time, FlowDictate creates a one-time `dictations-pre-3.2.json` backup in the local History folder. Recordings and the selected recordings folder are not moved.

Live Preview is optional and requires Apple's on-device speech recognition. Spoken formatting and the personal dictionary run locally. Only a writing style that explicitly uses AI sends the already transcribed text to OpenAI in an additional request.

### Keychain access after an update

The first launch of a new Community edition may ask for your macOS login password once because its ad hoc signature has changed. If the prompt keeps appearing, open `Settings → Transcription`, remove the existing API key, and then save it again. This recreates the Keychain entry for the currently installed edition. FlowDictate will then load it only once per app session.

### Repairing permissions

Use the following procedure only for the feature that is not working:

1. Open `System Settings → Privacy & Security`.
2. Open the affected section: **Microphone**, **Accessibility**, **Speech Recognition**, or **Screen & System Audio Recording**.
3. If FlowDictate is listed, first switch its permission off and back on. Restart FlowDictate and test again.
4. If the problem remains, quit FlowDictate, select the old entry, and remove it using the minus button. If no minus button is available, disable the entry.
5. Use the plus button to add exactly `/Applications/FlowDictate.app` and enable it. Alternatively, trigger the relevant feature in FlowDictate again and approve the new macOS prompt.
6. Quit FlowDictate completely and reopen it. If macOS offers `Quit & Reopen`, use that button.

Feature-to-permission reference:

- No microphone recording: **Microphone**
- Recording starts, but keyboard shortcuts or text insertion do not work: **Accessibility**
- No local Live Preview: **Speech Recognition**
- No system audio recording or no selectable audio sources: **Screen & System Audio Recording**

Do not reset every privacy permission at once. This preserves permissions that still work and keeps the update process as short as possible.
