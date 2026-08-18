# FlowDictate Release Guide

FlowDictate 2.0 runs as a standalone macOS menu bar app. A release never contains an API key; every installation collects and stores the owner's key during onboarding.

## Free Community release

The Community release is intended for personal Macs and a trusted circle. It does not require an Apple Developer account or paid membership.

```sh
./scripts/build-community-release.sh
```

The script performs an unsigned universal Release build, applies an ad hoc signature with the required sandbox entitlements, verifies that signature, and creates these files in `dist/`:

- `FlowDictate-2.0-Community-macOS.zip`
- `FlowDictate-2.0-Community-macOS.zip.sha256`

The ZIP contains the app plus German and English installation guides named `INSTALLATION-DE.md` and `INSTALLATION-EN.md`. Gatekeeper cannot establish an Apple developer identity for this build, so the recipient must use right-click → Open or approve it under Privacy & Security. Updates may require Microphone and Accessibility permission to be granted again.

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
6. Grant Microphone and Accessibility permissions.
7. Dictate into Notes, interrupt processing, relaunch, and verify recovery in History.

Never distribute builds containing an `.env` file, Xcode Scheme secret, personal API key, or notarization credential.
