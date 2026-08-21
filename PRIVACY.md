# Privacy

FlowDictate does not include analytics, advertising, telemetry or a developer-operated backend.

## Data stored on the Mac

- The OpenAI API key is stored in the user's macOS Keychain.
- Recordings are stored in the folder selected during setup. The recommended default is `Documents/Recordings`.
- Dictation history and recovery metadata remain in the app's local Application Support container.
- Personal dictionary entries and custom writing styles are stored locally in the Application Support container.

## Data sent to OpenAI

When the user finishes a dictation, its audio is sent directly from FlowDictate to the OpenAI transcription API. OpenAI processes that request according to the terms and privacy policy applying to the user's own OpenAI account. FlowDictate never bundles or receives a shared API key.

Cancelled recordings are not sent for transcription. Users can review and delete locally retained recordings using Finder and FlowDictate's storage settings.

## Optional AI writing styles

Spoken formatting and personal-dictionary replacements run entirely on the Mac. The built-in **Original** style does not make an additional cloud request.

When the user explicitly selects an AI writing style, FlowDictate sends the locally processed transcript, the selected style instruction and language information directly to OpenAI through the Responses API. The enhancement request does not contain the audio file, target application, window title, clipboard content, personal-dictionary rule list or locally stored history. FlowDictate requests that OpenAI does not store the response through the API's `store: false` option. OpenAI's account terms and data policies still apply to the user's request.

If enhancement fails, all transcript stages remain local so the user can retry, use the locally processed text or use the original transcript.

## Local Live Preview

When Live Preview is enabled, FlowDictate can send in-memory audio buffers to Apple's Speech framework with on-device recognition required. There is no fallback to Apple's cloud recognition. The provisional Preview text exists only in memory: it is not saved in History, diagnostics or logs, is not inserted into another app and is not used as the final transcript.

Live Preview is optional. Existing installations keep it disabled until the user enables it. If it is disabled, FlowDictate neither starts Speech recognition nor requests Speech Recognition permission. If permission or an on-device recognizer is unavailable, normal recording and final OpenAI transcription continue without Preview.

## Independent project

FlowDictate is an independent open-source project and is not affiliated with or endorsed by OpenAI or Apple.
