# Product Requirements Document: FlowDictate

**Version:** 1.1\
**Target platform:** macOS\
**Primary IDE:** Xcode\
**AI development agent:** OpenAI Codex\
**Language:** Swift\
**UI framework:** SwiftUI with AppKit where required\
**Build system:** Xcode / Swift Package Manager where appropriate\
**Product type:** Native macOS desktop application\
**Working name:** FlowDictate

## 1. Product Vision

Build a lightweight native macOS application that allows the user to
dictate text from anywhere in macOS and automatically inserts the
transcribed and optionally improved text into the currently active
application at the cursor position.

The application should provide the core user experience of products such
as Wispr Flow without depending on a subscription-based dictation
service.

The core workflow is:

**Voice → Speech-to-Text → optional text processing → insertion at
cursor**

The experience must be fast and reliable enough that voice input can
realistically replace typing for emails, documents, ChatGPT prompts,
browser forms, notes, messaging applications and other everyday use
cases.

The application is initially intended for personal use, but the
architecture should allow later development into a distributable macOS
application.

## 2. Product Principles

### 2.1 Minimal interaction

Starting and stopping dictation should require only one global shortcut
or, in a later version, a configurable mouse action.

### 2.2 Works across macOS

Dictation should work independently of the foreground application
whenever macOS accessibility permissions allow it.

Target applications include:

-   Safari
-   Chrome
-   Mail
-   Notes
-   Microsoft Word
-   Outlook
-   VS Code
-   Slack
-   ChatGPT
-   other native macOS text fields

### 2.3 Fast

Minimize the time between stopping a recording and text appearing.

Target:

**\< 2 seconds after the transcription API response**

The architecture should support future streaming transcription.

### 2.4 Reliable

No recording should be lost because of API errors, network problems,
application crashes, clipboard problems or transcription failures.

### 2.5 Local-first

Recordings, settings, dictionary and history should be stored locally
unless an external API explicitly requires transmission.

### 2.6 Provider-independent

Speech-to-text and language-processing providers must be abstracted so
they can later be replaced without redesigning the application.

## 3. Development Workflow

The project will use **Xcode as the primary native macOS development,
build, debugging and testing environment**.

OpenAI Codex will act as the primary AI development agent and work
directly on the same project repository and source files used by Xcode.

The intended workflow is:

``` text
OpenAI Codex
     ↓
creates and modifies Swift / SwiftUI code
     ↓
FlowDictate Git repository
     ↓
Xcode
     ↓
Build + Run + Debug + Signing + Permissions
     ↓
FlowDictate.app
```

Codex should use command-line tooling such as `xcodebuild`,
`swift test`, `git status` and `git diff` where useful.

Xcode should be used for tasks where Apple's native tooling provides a
clear advantage, including:

-   project configuration
-   entitlements
-   signing
-   provisioning
-   SwiftUI previews
-   debugging
-   macOS permission testing
-   application lifecycle testing
-   `.app` packaging

The user should not be required to manually copy code between Codex and
Xcode.

## 4. Primary User Flow

1.  User works in any macOS application.
2.  User places the cursor in a text field.
3.  User presses the global dictation shortcut.
4.  Recording starts.
5.  A floating recording indicator appears.
6.  The indicator shows microphone activity.
7.  User speaks.
8.  User presses the shortcut again.
9.  Recording stops.
10. Audio is stored locally.
11. Audio is sent to the configured speech-to-text provider.
12. Transcript is returned.
13. Optional text processing is applied.
14. Text is inserted at the cursor position.
15. Recording and transcript are added to history.
16. The floating indicator disappears.

The interaction should feel like a system-level dictation function
rather than opening a separate application.

## 5. MVP Scope

The first usable version must provide:

-   native macOS application
-   menu bar operation
-   global keyboard shortcut
-   start/stop recording
-   microphone capture
-   speech-to-text API integration
-   insertion at cursor
-   clipboard-safe text insertion
-   floating recording indicator
-   microphone level visualization
-   settings
-   transcription history
-   local audio backup
-   basic error handling
-   configurable microphone
-   launch at login

Mouse shortcuts and advanced writing styles should follow after the
keyboard-based workflow is stable.

## 6. macOS Architecture

Build a native macOS application using:

-   Swift
-   SwiftUI
-   AppKit where SwiftUI does not expose required functionality
-   Xcode as the primary project and build environment

Relevant Apple frameworks may include:

-   SwiftUI
-   AppKit
-   AVFoundation
-   ApplicationServices / Accessibility APIs
-   NSPasteboard
-   ServiceManagement
-   Security / Keychain APIs

Avoid Electron unless a compelling technical reason emerges.

The application should run primarily as a **menu bar application**.

A permanent Dock icon should not be necessary during normal operation.

## 7. Application Components

Keep major functionality modular.

Suggested logical structure:

``` text
FlowDictate
│
├── App
├── MenuBar
├── Recording
├── AudioStorage
├── Transcription
├── TextProcessing
├── TextInsertion
├── History
├── Dictionary
├── Overlay
├── Hotkeys
├── Settings
├── Providers
└── Utilities
```

Codex may adapt the physical Xcode project structure if a different
organization better follows current Swift/Xcode conventions.

Provider-specific logic must not leak into the rest of the application.

## 8. Global Dictation Shortcut

Support a global keyboard shortcut.

Default suggestion:

`Option + Space`

The shortcut must work when another application has focus.

State behavior:

``` text
Idle → Recording
Recording → Processing
Processing → Idle
```

The shortcut must be configurable.

Prevent accidental repeated triggering.

Before automatically inserting text, ensure modifier keys from the
shortcut have been released.

## 9. Recording

Use native macOS audio APIs to capture microphone input.

Requirements:

-   configurable input device
-   microphone permission handling
-   reliable recording start/stop
-   microphone level measurement
-   local audio file
-   timestamp
-   unique recording ID

Recommended format:

AAC/M4A or another efficient format supported natively by macOS.

Audio should initially be preserved until successful transcription.

The user should later be able to configure automatic deletion.

## 10. Recording Overlay

While recording, display a small floating overlay.

Suggested position:

bottom-right corner of the active display.

The overlay should contain:

-   microphone/recording icon
-   animated audio level indicator
-   recording state

States:

``` text
Recording
Processing
Success
Error
```

The overlay must:

-   stay above normal windows
-   not steal keyboard focus
-   not interfere with the current application

## 11. Multi-Monitor Support

Determine the screen containing the mouse pointer when dictation starts.

Display the recording overlay on that screen.

A later implementation may dynamically follow the mouse to another
display.

Minimum requirement:

**New recording → overlay appears on the display containing the mouse
pointer.**

## 12. Menu Bar Application

Provide a macOS menu bar icon.

Menu options should include:

``` text
Start Dictation
Stop Dictation

History
Settings

Microphone >
Writing Style >

Launch at Login

Quit
```

The menu bar icon may change state during recording or processing.

## 13. Speech-to-Text Provider

Speech recognition should initially use an external API.

Evaluate providers based on:

-   transcription quality
-   German recognition
-   English recognition
-   mixed German/English
-   latency
-   price per audio minute
-   punctuation
-   API simplicity
-   privacy
-   streaming capability

Potential providers may include OpenAI, Deepgram, AssemblyAI or
equivalent services available at implementation time.

Do not hard-code application logic to one provider.

Conceptual interface:

``` swift
protocol TranscriptionProvider {
    func transcribe(audioURL: URL) async throws -> TranscriptionResult
}
```

## 14. API Credentials

API keys must never be committed to Git.

During development, credentials may initially be loaded from environment
variables or an Xcode Scheme environment configuration.

For the installed application, credentials should be stored in:

**macOS Keychain**

The repository may contain:

``` text
.env.example
```

but never real credentials.

`.gitignore` must explicitly exclude credentials and local secret files.

## 15. Text Insertion

After transcription, insert text into the currently active application.

Initial preferred strategy:

1.  preserve existing clipboard contents
2.  place transcript into clipboard
3.  trigger Paste
4.  wait sufficiently long for the target application to consume
    clipboard
5.  restore previous clipboard

Do not restore the clipboard immediately.

Some applications process paste operations asynchronously.

Use a safe delay and make the mechanism configurable if necessary.

Investigate whether macOS Accessibility APIs provide a more reliable
direct insertion mechanism for supported applications.

Text insertion must be encapsulated behind a dedicated interface so the
implementation strategy can later change.

## 16. Focus Preservation

Recording and overlay interactions must not steal focus from the
application into which the user is dictating.

Remember the foreground application when dictation begins.

If focus changes because of internal processing, attempt to restore the
original application before inserting text.

## 17. Dictation History

Store each dictation locally.

Each history entry should contain:

``` text
ID
Timestamp
Original transcript
Processed transcript
Audio file
Duration
Transcription provider
Writing style
Processing status
Estimated API cost
```

History must be searchable across transcript, processed text and date.

## 18. Restore Last Dictation

Provide a global shortcut:

`Option + Shift + Z`

Behavior:

Insert the last successful dictation again at the current cursor
position.

This provides a recovery mechanism if automatic insertion failed.

The shortcut must be configurable.

## 19. Audio Recovery

Every recording must be saved locally before external transcription.

If transcription fails:

-   keep audio
-   mark entry as failed
-   show error state
-   allow retry

History should provide:

**Retry transcription**

A network or API failure must never destroy the original recording.

## 20. Cancel Dictation

Provide a configurable cancel shortcut.

Cancellation should:

1.  stop recording
2.  not send audio to transcription
3.  not insert text
4.  mark or delete recording according to settings

Avoid globally intercepting Escape in a way that interferes with normal
macOS usage.

## 21. Writing Styles

Support four initial writing modes.

### Spoken

Return transcription essentially unchanged.

### Clean

Correct punctuation, obvious filler words, sentence structure and
repetitions while preserving meaning.

### Formal

Transform into polished professional language.

### Casual

Produce natural informal language.

Architecture:

``` text
Audio
 ↓
Speech-to-Text
 ↓
Raw Transcript
 ↓
Style Processor
 ↓
Final Text
 ↓
Insertion
```

## 22. Personal Style

Later version:

**My Style**

Use previous dictations and corrections to approximate the user's
writing style.

Do not train a model initially.

Instead, use contextual examples retrieved from local history.

Conceptually:

``` text
Current transcript
+
selected relevant previous examples
+
style instructions
→
LLM
→
processed text
```

Personal style processing must be optional.

If style processing fails, always fall back to the original
transcription.

A style API failure must never cause loss of a valid transcription.

## 23. Personal Dictionary

Maintain a local dictionary for frequently misrecognized terms.

Examples:

-   names
-   company names
-   product names
-   abbreviations
-   technical terminology

Dictionary entries may contain:

``` text
Expected spelling
Possible spoken/misrecognized forms
Notes
```

Apply dictionary correction after transcription or pass vocabulary hints
to the provider if supported.

## 24. Silence and Hallucination Protection

Speech recognition systems may generate text from silence or background
noise.

Implement safeguards using signals such as:

-   very low average audio level
-   extremely short recordings
-   repeated phrases
-   provider confidence where available
-   suspicious transcript repetition

If the system suspects a hallucination, avoid automatic insertion and
preserve the transcription/audio for recovery or review.

Do not silently discard audio.

## 25. Statistics

Track locally:

-   number of dictations
-   total audio minutes
-   estimated API cost
-   words dictated
-   characters dictated
-   estimated typing time saved

Example:

``` text
This month

Dictations           186
Audio                74 min
Words                9,420
Estimated cost       $0.48
Estimated time saved 3h 12m
```

Cost calculation must be configurable because API prices may change.

## 26. Settings

### General

-   launch at login
-   history retention
-   audio retention

### Dictation

-   start/stop shortcut
-   cancel shortcut
-   restore-last shortcut

### Audio

-   microphone selection
-   input level

### Transcription

-   provider
-   model
-   language / auto detect
-   API credentials

### Writing

-   default writing style
-   personal dictionary
-   personal style

### Advanced

-   clipboard restore delay
-   debugging
-   log location

## 27. Privacy

Default behavior:

-   history stored locally
-   audio stored locally
-   credentials stored securely
-   audio transmitted only to the selected transcription provider
-   transcript transmitted to an LLM only when text processing is
    enabled

Clearly distinguish between:

**Speech recognition**

and

**AI text processing**

because these may involve different external services.

## 28. Logging

Create structured local logs.

Log:

-   application startup
-   recording start/stop
-   audio file creation
-   API request state
-   transcription completion
-   processing completion
-   insertion
-   errors

Never log API keys or authentication tokens.

Prefer not to log complete transcripts by default.

## 29. Error Handling

Handle at least:

``` text
No microphone permission
No Accessibility permission
No microphone available
Recording failure
Network unavailable
API authentication failure
API rate limit
Transcription failure
LLM processing failure
Clipboard failure
Text insertion failure
Corrupted recording
```

Errors should be understandable without requiring the user to inspect
source code.

## 30. macOS Permissions

The application will likely require:

### Microphone

For recording.

### Accessibility

For system-wide interaction and text insertion.

Potentially investigate:

### Input Monitoring

Only request this if actually required by the selected global shortcut
implementation.

Do not request unnecessary permissions.

Provide clear onboarding instructions for:

`System Settings → Privacy & Security`

Xcode project capabilities and entitlements must be configured
explicitly and documented.

## 31. Launch at Login

Provide an option:

**Launch FlowDictate at Login**

Use the current supported macOS mechanism, preferably ServiceManagement
APIs rather than legacy startup mechanisms.

## 32. Xcode Project Requirements

Codex should create and maintain a valid native Xcode project.

Requirements:

-   macOS application target
-   SwiftUI application lifecycle unless AppKit lifecycle is technically
    preferable
-   unit test target
-   clear bundle identifier placeholder
-   appropriate deployment target
-   required entitlements
-   no hard-coded developer-specific signing identity
-   buildable from Xcode
-   buildable from the command line using `xcodebuild`

Codex must avoid unnecessary manual changes to `.pbxproj` where safer
Xcode-compatible alternatives exist.

If project-file changes are required, make them incrementally and verify
the project still opens and builds.

## 33. Repository Structure

Suggested structure:

``` text
flowdictate/
│
├── README.md
├── PRD.md
├── .gitignore
├── .env.example
│
├── FlowDictate.xcodeproj
│
├── FlowDictate/
│   ├── App/
│   ├── Audio/
│   ├── Hotkeys/
│   ├── Overlay/
│   ├── Transcription/
│   ├── Processing/
│   ├── Insertion/
│   ├── History/
│   ├── Dictionary/
│   ├── Settings/
│   └── Utilities/
│
├── FlowDictateTests/
│
├── scripts/
│
└── docs/
```

Codex may modify this structure when current Xcode conventions suggest a
better approach.

## 34. Testing Requirements

Testing is part of implementation, not a final optional step.

Create unit tests where useful for:

-   provider abstraction
-   dictionary replacement
-   history storage
-   configuration
-   style processing
-   hallucination/repetition detection

Manual integration tests must cover:

-   Safari
-   Chrome
-   Mail
-   Notes
-   Microsoft Word or equivalent editor
-   VS Code

Test scenarios:

-   short dictation
-   long dictation
-   German
-   English
-   mixed German/English
-   silence
-   network failure
-   invalid API key
-   rapid shortcut activation
-   two monitors
-   clipboard containing text
-   clipboard containing non-text content

Codex should run automated builds/tests itself where possible.

For interactions that require a human, Codex must provide concise manual
test instructions.

## 35. Implementation Phases

### Phase 0: Technical Spike

Validate the highest-risk macOS capabilities before building the full
UI:

``` text
Global shortcut
Audio recording
Speech-to-text integration
Reliable insertion into another application's active text field
```

Create the smallest possible prototype.

**Exit criterion:** Speak a sentence and successfully insert the
transcription into TextEdit or Notes.

### Phase 1: Core MVP

Build:

``` text
Menu bar application
Global shortcut
Audio recording
Local audio storage
One transcription provider
Text insertion
Basic overlay
Permissions
Basic settings
```

**Exit criterion:** Reliable everyday dictation into common macOS
applications.

### Phase 2: Reliability

Add:

``` text
History
Restore last dictation
Audio recovery
Retry transcription
Better error handling
Clipboard preservation
Logging
```

**Exit criterion:** A temporary API or insertion failure cannot cause
loss of a dictation.

### Phase 3: Intelligence

Add:

``` text
Clean style
Formal style
Casual style
Personal dictionary
Hallucination protection
```

**Exit criterion:** Processed text consistently improves usability
without changing intended meaning.

### Phase 4: Advanced UX

Add:

``` text
My Style
Statistics
Multi-monitor improvements
Mouse shortcut
Streaming transcription evaluation
Performance optimization
```

## 36. Performance Targets

  Metric                                                           Target
  --------------------------------- -------------------------------------
  Recording startup                                             \< 300 ms
  Overlay appearance                                            \< 300 ms
  UI response                                                   \< 100 ms
  Text insertion after API result                               \< 500 ms
  Idle CPU usage                                                    \< 1%
  Lost recordings                                                       0
  Successful insertion                \> 99% under supported applications

API latency is excluded from local insertion timing.

## 37. Definition of Done

A feature is complete only when:

1.  implementation exists
2.  application builds without errors
3.  relevant automated tests pass
4.  feature has been manually tested where necessary
5.  errors are handled
6.  logs provide enough information for debugging
7.  README/documentation is updated

Do not mark functionality complete based only on successful compilation.

## 38. Codex Operating Instructions

Codex should act as the lead implementation agent for this project.

Before implementing a phase:

1.  inspect the existing Xcode project and repository
2.  understand the current implementation
3.  identify dependencies
4.  identify architectural decisions and technical risks
5.  create a concise implementation plan
6.  implement incrementally

During implementation:

-   work directly in the Xcode project repository
-   keep components modular
-   prefer native Apple frameworks
-   avoid unnecessary third-party dependencies
-   do not hard-code credentials
-   preserve working functionality
-   run `xcodebuild` after meaningful changes
-   run available automated tests
-   inspect build errors and fix them before reporting completion
-   keep compiler warnings to a reasonable minimum
-   document architectural decisions
-   use Git-friendly incremental changes

Codex should not assume that the user will manually fix routine compiler
or project errors.

After each phase report:

``` text
Implemented
Files changed
Build result
Tests performed
Manual tests required
Known issues
Next recommended step
```

If a requirement is technically problematic on macOS, do not silently
implement a fragile workaround. Explain the limitation and propose the
simplest robust alternative.

## 39. Human vs. Codex Responsibilities

### Codex should handle

-   source-code creation
-   source-code modification
-   project structure
-   unit tests
-   API integrations
-   build commands
-   compiler error analysis
-   routine debugging
-   documentation
-   Git-aware changes

### User/Xcode interaction may be required for

-   granting macOS permissions
-   selecting an Apple Development Team
-   signing configuration
-   visually testing overlays
-   testing global shortcuts in real applications
-   testing cursor insertion
-   approving macOS security prompts

Whenever manual interaction is required, Codex should state exactly what
the user needs to do and what result should be observed.

## 40. Initial Codex Assignment

Start with **Phase 0 only**.

Do not build the complete application immediately.

Your first task is to validate the technical architecture for a native
macOS dictation utility built with Swift/SwiftUI and Xcode.

Specifically:

1.  Inspect the repository and existing Xcode project.
2.  Verify that the project builds before making significant changes.
3.  Determine the best architecture for a Swift/SwiftUI macOS menu bar
    application.
4.  Implement a minimal menu bar application.
5.  Implement a system-wide configurable keyboard shortcut.
6.  Request and verify microphone permission.
7.  Record microphone audio to a temporary/local file.
8.  Create a `TranscriptionProvider` abstraction.
9.  Implement one initial speech-to-text provider.
10. Request the required macOS Accessibility permission.
11. Insert the returned transcription into the active text field of
    another application.
12. Preserve and restore the clipboard safely.
13. Add sufficient logging to diagnose failures.
14. Add a minimal README explaining how to build, run and test the
    application in Xcode.
15. Verify the project with `xcodebuild`.
16. Run all available automated tests and fix failures.

Before writing substantial production code, explicitly identify
architectural choices that would make later implementation of history,
writing styles, multiple providers or streaming transcription difficult.

Do not proceed to Phase 1 until Phase 0 has been validated.

## 41. Phase 0 Success Criterion

Phase 0 is successful when the following workflow works:

> Open FlowDictate in Xcode, build and run the application, place the
> cursor in another macOS application, press the global shortcut,
> dictate a sentence, press the shortcut again, and have the transcribed
> text appear at the cursor position.

The Phase 0 result must also satisfy:

-   the Xcode project builds successfully
-   microphone permission works
-   Accessibility permission works
-   the global shortcut works while another application has focus
-   the original clipboard is restored after insertion
-   the recording is not lost if transcription fails
-   API credentials are not committed to source control
-   Codex can reproduce the build using `xcodebuild`

Only after this workflow is confirmed should development proceed to
Phase 1.
