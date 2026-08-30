# FlowDictate Release Guide

FlowDictate 4.0.0 runs as a standalone macOS menu bar app. A release contains neither API keys nor speech models. Each installation chooses local transcription or supplies its own OpenAI key during onboarding.

## Free Community release

The Community release is intended for personal Macs and a trusted circle. It does not require an Apple Developer account or paid membership.

```sh
./scripts/build-community-release.sh
```

The script performs an unsigned universal Release build, applies an ad hoc signature with the required sandbox entitlements, verifies that signature, and creates these files in `dist/`:

- `FlowDictate-4.0.0-Community-macOS.zip`
- `FlowDictate-4.0.0-Community-macOS.zip.sha256`

The ZIP contains the app plus German and English installation guides named `INSTALLATION-DE.md` and `INSTALLATION-EN.md`. Gatekeeper cannot establish an Apple developer identity for this build, so the recipient must use right-click → Open or approve it under Privacy & Security. Updates may require Microphone, Accessibility, Speech Recognition, Screen & System Audio Recording or Keychain permission to be granted again.

Verify the generated archive before uploading it:

```sh
cd dist
shasum -a 256 -c FlowDictate-4.0.0-Community-macOS.zip.sha256
```

## GitHub release checklist

1. Confirm `main` contains the intended source and documentation.
2. Run the automated tests and the manual Preview/recording smoke test.
3. Run `./scripts/build-community-release.sh` on a clean checkout.
4. Verify the SHA-256 checksum and test the ZIP on a second macOS account or Mac.
5. Create the annotated tag `v4.0.0` from the reviewed commit.
6. Create a GitHub Release for that tag using the reviewed 4.0 release notes.
7. Attach only the Community ZIP and its `.sha256` file. GitHub supplies source archives automatically.
8. Keep the release marked as a prerelease until the downloaded asset has passed the installation test; then publish it as the latest stable release.

Do not commit the generated `dist/` or `build/` directories. They are intentionally ignored by Git.

## Updating an existing installation

The 4.0.0 app keeps the stable bundle identifier `de.euler.FlowDictate`. Existing settings, the recordings bookmark and the Keychain credential are reused; existing installations remain on OpenAI until changed deliberately. History creates a one-time `dictations-pre-4.0.json` backup before writing schema 6. Because the Community signature changes between builds, macOS may nevertheless require permissions or the Keychain credential to be approved again.

The following sections describe the optional paid Developer ID workflow.

## Prerequisites

- Xcode with the macOS SDK
- the Apple Developer team configured for the FlowDictate target
- a Developer ID Application certificate for distribution outside the Mac App Store
- an optional `notarytool` Keychain profile for notarization

## Build

```sh
./scripts/build-release.sh
```

The versioned ZIP is written to `dist/`. The build uses the stable bundle identifier `de.euler.FlowDictate`, the Release configuration, App Sandbox, outgoing network access, microphone access, and user-selected read/write folder access.

## Notarize

Store notarization credentials once using Apple's `notarytool`, then pass the profile name:

```sh
FLOWDICTATE_NOTARY_PROFILE=FlowDictateNotary ./scripts/build-release.sh
```

The script submits the ZIP, waits for Apple's result, staples the ticket to the app, and recreates the final ZIP.

## Verification on another Mac

1. Copy and extract the ZIP.
2. Move `FlowDictate.app` to Applications.
3. Launch it and complete onboarding.
4. Confirm `Documents/Recordings` or choose another folder.
5. Add that person's OpenAI API key.
6. Grant Microphone and Accessibility permissions. Grant Speech Recognition only when testing Live Preview, and Screen & System Audio Recording only when testing System Audio.
7. Verify Live Preview, final OpenAI transcription, Smart Dictation, System Audio and insertion in TextEdit or Notes.
8. Interrupt processing, relaunch, and verify recovery in History.

Never distribute builds containing an `.env` file, Xcode Scheme secret, personal API key, or notarization credential.

## Additional Phase 3.4 gate

Before a Phase 3.4 release, test the exact generated Community ZIP with a recording that produces at least three segments. Pause after a successful segment, relaunch the packaged app and confirm that continuation does not upload the successful segment again. Also test one temporary segment failure, insufficient working storage guidance, ordered merged text, retained original audio and deletion of temporary segment files. Do not create a tag or GitHub Release until this packaged-app test and the existing checklist both pass.

## Additional Phase 4.0 gate

Before a Phase 4.0 release, verify the exact generated ZIP on Apple Silicon with no API key: install the local model, transcribe short German and English recordings, run a long segmented recording, and complete at least three consecutive dictations. Confirm that each new recording becomes available after the previous dictation finishes, safe deferred insertion after relaunch, Fully offline network blocking, inline correction commands and model removal protection. Verify that the x86_64 slice builds with the OpenAI path even though local transcription is unavailable; perform a physical Intel launch test when suitable hardware is available and otherwise document that residual risk explicitly. Do not tag or publish until the available packaged-app tests pass and any unavailable hardware gate has been consciously accepted.
