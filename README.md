# FlowDictate

FlowDictate is a native macOS menu bar dictation utility built with Swift, SwiftUI and AppKit. The current repository implements Phase 2 as specified in `FlowDictate_PRD_Phase_2.md`.

FlowDictate is an independent open-source project. It is not affiliated with or endorsed by OpenAI or Apple.

## Phase 2 features

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
- first-run setup for storage, OpenAI credentials, permissions and hotkeys
- user-selected sandboxed recordings folder with `Documents/Recordings` as the recommended default
- persistent searchable history with audio playback and text export
- crash recovery and orphaned-recording detection
- manual retry plus bounded automatic retry for temporary provider failures
- configurable Restore Last Dictation hotkey
- configurable retention for successful audio while failed recordings remain protected

Writing styles, personal dictionary, local speech models, statistics and streaming remain reserved for later phases.

## Requirements

- Xcode 26.6 or a compatible Xcode version
- macOS 14 or later
- an OpenAI API key

## Configure and run

1. Open `FlowDictate.xcodeproj` and run the `FlowDictate` scheme.
2. Follow the first-run setup assistant.
3. Confirm `Documents/Recordings` or choose another recordings folder.
4. Enter and verify the owner's OpenAI API key; it is stored in macOS Keychain.
5. Grant Microphone and Accessibility permissions when prompted.
6. Place the cursor in another application and press Option + Space.
7. Speak, then press Option + Space again to transcribe and insert the text.

Option + Shift + Space cancels a recording without sending it for transcription. The recording remains local so cancellation never destroys captured audio.

During development only, `OPENAI_API_KEY` and `FLOWDICTATE_TRANSCRIPTION_MODEL` may be supplied through a local, unshared Xcode scheme. Never put credentials in **Arguments Passed On Launch**, source code, `.env.example`, or a shared scheme.

## Settings

- **General:** launch at login and permission status
- **Dictation:** start/stop, cancel and restore-last shortcuts
- **Audio:** input device and live level
- **Transcription:** Keychain credential, OpenAI model and automatic/German/English recognition
- **Storage:** recordings folder, retention and Phase 1 migration
- **Advanced:** clipboard restoration delay and automatic retries

If a selected microphone disappears, FlowDictate falls back to the current system input device. Recordings are stored before upload in the folder selected during setup. History metadata remains local in the app's Application Support container.

## Standalone release

For a free build intended for personal use and a trusted circle, run:

```sh
./scripts/build-community-release.sh
```

It creates an ad hoc signed universal ZIP for Apple Silicon and Intel Macs. No paid Apple Developer membership is required. Because the build is not notarized, recipients must approve its first launch manually as described in `COMMUNITY_INSTALLATION.md` (German) or `COMMUNITY_INSTALLATION_EN.md` (English).

`scripts/build-release.sh` remains available for a future Developer ID signed and notarized release. Both workflows are documented in `RELEASE.md`.

Prebuilt Community editions are published separately under [GitHub Releases](https://github.com/Hank1210/FlowDictate/releases). Release archives are not committed to the source repository.

## Privacy

FlowDictate contains no analytics, advertising or developer-operated backend. Recordings are stored in the folder selected by the user and are sent directly to OpenAI only when a dictation is submitted for transcription. The user's own API key is kept in macOS Keychain. See [PRIVACY.md](PRIVACY.md) for details.

## License

FlowDictate is available under the [MIT License](LICENSE). You may use, modify and redistribute it subject to that license.

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

Automated tests cover configuration, transcription request construction, state rules, start/stop/cancel orchestration, history persistence and recovery, retry classification, audio level normalization, login-item status mapping and clipboard snapshots. Microphone permissions, Accessibility, folder authorization, overlay placement and insertion into third-party applications require manual macOS testing.

The `FlowDictateUITests` target contains an optional menu bar launch test. It is skipped by the shared scheme because macOS requires separate UI-automation approval for the XCTest runner. After granting that permission, run it explicitly with `-only-testing:FlowDictateUITests`.

## Phase 2 manual verification

Test short, long, German, English and mixed-language dictation in Notes, Safari, Chrome, Mail, VS Code and Word or an equivalent editor. Also verify:

- rapid shortcut presses do not create overlapping recordings
- cancel does not call the transcription provider
- the overlay appears on the display containing the mouse and never steals focus
- microphone switching and default-device fallback
- text and non-text clipboard restoration
- invalid key and offline errors retain the audio file
- interrupted transcription is recoverable from History
- `Documents/Recordings` access survives an app restart
- Restore Last Dictation inserts at the current cursor
- launch at login works from an installed, consistently signed build; if macOS requires approval, follow the link to Login Items shown in Settings
