# FlowDictate

FlowDictate is a native macOS menu bar dictation utility built with Swift, SwiftUI and AppKit. The current repository implements Phase 1 of `FlowDictate_PRD_v1.1.md`.

## Phase 1 features

- global start/stop and cancel shortcuts
- microphone recording with local WAV backup
- selectable audio input and live level metering
- OpenAI transcription with model and language settings
- clipboard-safe insertion into the application that originally had focus
- a non-activating recording and processing overlay on the display containing the mouse
- API credentials stored in macOS Keychain
- microphone and Accessibility permission guidance
- configurable clipboard restoration delay
- launch at login enabled on first installed start, with a Settings toggle to disable it

History, retry transcription, restore-last, writing styles, dictionary, statistics and streaming are intentionally reserved for later phases.

## Requirements

- Xcode 26.6 or a compatible Xcode version
- macOS 14 or later
- an OpenAI API key

## Configure and run

1. Open `FlowDictate.xcodeproj` and run the `FlowDictate` scheme.
2. Open the menu bar item and choose **Settings → Transcription**.
3. Enter the OpenAI API key and choose **Save in Keychain**.
4. Grant Microphone and Accessibility permissions when prompted.
5. Place the cursor in another application and press Option + Space.
6. Speak, then press Option + Space again to transcribe and insert the text.

Option + Shift + Space cancels a recording without sending it for transcription. The recording remains local so cancellation never destroys captured audio.

During development only, `OPENAI_API_KEY` and `FLOWDICTATE_TRANSCRIPTION_MODEL` may be supplied through a local, unshared Xcode scheme. Never put credentials in **Arguments Passed On Launch**, source code, `.env.example`, or a shared scheme.

## Settings

- **General:** launch at login and permission status
- **Dictation:** start/stop and cancel shortcuts
- **Audio:** input device and live level
- **Transcription:** Keychain credential, OpenAI model and automatic/German/English recognition
- **Advanced:** clipboard restoration delay and recordings folder

If a selected microphone disappears, FlowDictate falls back to the current system input device. Recordings are stored before upload under the app's Application Support container in `FlowDictate/Recordings`.

## Build from the command line

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild clean build \
  -project FlowDictate.xcodeproj \
  -scheme FlowDictate \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64'
```

## Tests

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project FlowDictate.xcodeproj \
  -scheme FlowDictate \
  -destination 'platform=macOS,arch=arm64'
```

The scheme's Test action uses the dedicated `DebugTests` configuration and the bundle identifier `de.euler.FlowDictate.TestHost`. This prevents XCTest builds in temporary DerivedData folders from invalidating the Accessibility permission of the normal `de.euler.FlowDictate` app. Do not override the test command with `-configuration Debug`.

Automated tests cover configuration, transcription request construction, state rules, start/stop/cancel orchestration, audio level normalization, login-item status mapping and clipboard snapshots. Microphone permissions, Accessibility, overlay placement and insertion into third-party applications require manual macOS testing.

The `FlowDictateUITests` target contains an optional menu bar launch test. It is skipped by the shared scheme because macOS requires separate UI-automation approval for the XCTest runner. After granting that permission, run it explicitly with `-only-testing:FlowDictateUITests`.

## Phase 1 manual verification

Test short, long, German, English and mixed-language dictation in Notes, Safari, Chrome, Mail, VS Code and Word or an equivalent editor. Also verify:

- rapid shortcut presses do not create overlapping recordings
- cancel does not call the transcription provider
- the overlay appears on the display containing the mouse and never steals focus
- microphone switching and default-device fallback
- text and non-text clipboard restoration
- invalid key and offline errors retain the audio file
- launch at login works from an installed, consistently signed build; if macOS requires approval, follow the link to Login Items shown in Settings
