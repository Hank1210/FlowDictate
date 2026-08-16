# FlowDictate

FlowDictate is a native macOS dictation utility. The repository is currently limited to the Phase 0 technical spike described in `FlowDictate_PRD_v1.1.md`.

## Phase 0 scope

The current prototype provides:

- a menu bar application with no permanent Dock icon
- a configurable native global shortcut (default: Option + Space)
- microphone and event-posting permission checks
- microphone recording to a durable local WAV file
- an abstract `TranscriptionProvider` with an initial OpenAI implementation
- focus preservation and insertion through a clipboard-safe Command-V operation
- local structured logging and retained audio after failures

It intentionally does not include the recording overlay, history UI, writing styles, dictionary, launch at login, statistics, or other Phase 1+ features.

## Requirements

- Xcode 26.6 or a compatible Xcode version
- macOS 14 or later
- an OpenAI API key for the Phase 0 transcription provider

## Configure Xcode

1. Open `FlowDictate.xcodeproj`.
2. Select **Product → Scheme → Manage Schemes…** and duplicate `FlowDictate` as `FlowDictate Local`.
3. Leave **Shared** unchecked for the local duplicate, select it, then choose **Edit…**.
4. Under **Run → Arguments → Environment Variables** (the lower table), add:
   - `OPENAI_API_KEY` with your API key.
   - Optionally, `FLOWDICTATE_TRANSCRIPTION_MODEL`. The default is `gpt-4o-mini-transcribe`.
5. Ensure the variable is enabled. Do **not** add `OPENAI_API_KEY=...` to **Arguments Passed On Launch**.
6. Run the app with the `FlowDictate Local` scheme. Choose a Development Team under the FlowDictate target's **Signing & Capabilities** tab if Xcode requires one.

Never place a real API key in source code, `.env.example`, or the shared `FlowDictate` scheme. The local, unshared scheme keeps this machine-specific value out of the repository.

## Build from the command line

If `xcode-select` already points to Xcode:

```sh
xcodebuild clean build \
  -project FlowDictate.xcodeproj \
  -scheme FlowDictate \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64'
```

If it points to Command Line Tools, invoke the full Xcode toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild clean build \
  -project FlowDictate.xcodeproj \
  -scheme FlowDictate \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64'
```

## Run the Phase 0 manual test

1. Build and run FlowDictate from Xcode so it has a stable signed application identity.
2. Grant Microphone permission when requested.
3. Grant FlowDictate permission under **System Settings → Privacy & Security → Accessibility** when requested. If macOS asks you to relaunch the app, do so from Xcode.
4. Open TextEdit or Notes and place the cursor in an editable text field.
5. Press Option + Space and speak a sentence.
6. Press Option + Space again.
7. Confirm that the transcription appears at the original cursor and the previous clipboard contents are restored.

Recordings are written before upload under the app's Application Support container in `FlowDictate/Recordings`. If transcription or insertion fails, open the menu bar item and choose **Show Retained Recording**.

## Tests

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project FlowDictate.xcodeproj \
  -scheme FlowDictate \
  -destination 'platform=macOS,arch=arm64'
```

UI tests do not automate microphone, Accessibility, or cross-application insertion because those checks require macOS TCC approval and a foreground target application.
