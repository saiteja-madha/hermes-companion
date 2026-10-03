# JARVIS fork implementation log

This is a living log for the endpoint-aware, Siri-started voice assistant work.
The design and candidate audit are in `JARVIS_FOUNDATION_RESEARCH.md`.

## Fork baseline

- Upstream repository: `https://github.com/chibitek/HermesCompanion.git`
- Baseline branch/commit: `main` at
  `bfe8cad73abb8c99cdf227f81b2e2d82668d1146`
- Working branch: `jarvis/multi-endpoint-voice-foundation`
- Baseline worktree: clean before the first change
- Personal fork remote: not configured in this environment

When the personal fork URL is available, use this topology:

```bash
git remote rename origin upstream
git remote add origin <personal-fork-url>
git fetch --all --prune
git push -u origin jarvis/multi-endpoint-voice-foundation
```

Do not run the rename until the personal fork URL is known; leaving the only
configured remote reachable is safer than creating an incomplete remote setup.

## 2026-10-03 — Phase 1 started: endpoint-pinned voice safety

### Existing behavior reused

- Multiple `ConnectionConfig` values and API keys already persist in Keychain.
- `AppStore.switchToConnection` replaces the API client and clears session/UI
  state before connecting to the selected gateway.
- Active sessions already persist separately by normalized base URL.
- The continuous voice manager already performs on-device STT, sends to the
  active Hermes session, speaks the response, and returns to listening.

### Changes

- Added `VoiceEndpointBinding` in `Sources/VoiceActivationLogic.swift`.
  It captures the normalized endpoint URL and safe display label at voice start.
- `ChatView.openVoiceConversation` now requires a connected endpoint and captures
  its binding before presenting voice mode.
- Every spoken turn verifies that the current `AppStore.connectionConfig` still
  matches the captured endpoint. A mismatch stops the voice session and shows an
  explicit error instead of using the new global endpoint.
- `VoiceConversationPage` displays `TARGET: <endpoint>` and ends automatically if
  the endpoint changes.
- The ordinary chat connection status now includes the active endpoint label.
- Added unit coverage for matching, cross-endpoint rejection, slash
  normalization, nil configuration, and display-name fallback.

### Safety invariant

For a voice session bound to Linux, no transcription may be submitted after the
global connection becomes Mac. Endpoint failure never authorizes use of another
endpoint.

### Verification state

- Source edits: complete for this slice.
- Static patch validation: `git diff --check` passed.
- Unit test execution: not available in this Linux workspace because neither
  Xcode nor the Swift toolchain is installed. The tests must be run on macOS.
- Physical-device behavior: not yet tested.
- Linux/Mac live integration: not yet configured in this environment.

## Plan recorded after phase 1

1. Introduce stable endpoint UUIDs and a default endpoint without breaking the
   existing Keychain records.
2. Move pending voice launch requests into a small endpoint-aware coordinator.
3. Add `HermesEndpointEntity`, parameterized `StartHermesVoiceIntent`, and App
   Shortcut phrases for default/Linux/Mac.
4. Refactor the audio background transition; verify it on a physical device.
5. Add the ActivityKit target only after endpoint and session identity are stable.

## 2026-10-03 — Phase 2 implemented: stable endpoints and Siri routing

### Changes

- Added `ConnectionConfig.endpointID`, a persisted UUID that is independent of
  URL, label and credentials.
- Added one-time Keychain migration for old `active_config` and `all_configs`
  records. The canonical saved-list ID is reconciled back into the active record;
  credentials remain in Keychain throughout.
- Changed active-session persistence to endpoint UUID keys. Existing URL-scoped
  session pointers migrate on first read and are removed after successful copy.
- Address edits preserve endpoint identity but clear the old active-session
  pointer, preventing a session ID from being assumed valid at a new address.
- Added an independent **Default Voice Server** picker and visible
  `VOICE DEFAULT` badge. Changing the current chat server does not silently alter
  the voice default.
- Added a secret-free app-group endpoint catalog containing UUID and display
  label only. URLs and API keys are not exposed to App Intents.
- Added `HermesEndpointEntity`, a generic `StartHermesVoiceIntent`, an
  endpoint-parameterized intent, and App Shortcut phrases including
  “Start Hermes” and “Start Hermes on <server>”.
- Cold and warm intent launches now resolve and connect the exact requested
  endpoint before opening voice mode. Failure remains pinned to that endpoint
  and explicitly states that no command was sent elsewhere.
- Updated the existing Control Widget voice action to target the preferred
  endpoint through the same handoff.
- Corrected the upstream README badge and source header to match the actual
  personal/non-commercial `LICENSE` file.

### Tests added or updated

- Legacy connection records gain a stable ID that survives re-encoding.
- URL-scoped active sessions migrate to UUID scope and remain isolated.
- Voice binding requires both stable endpoint identity and address.
- Reusing the same URL with a different endpoint identity is rejected.
- Preferred endpoint, public endpoint catalog and pending launch handoff round
  trip through isolated defaults without serializing URL or API-key fields.

### Verification state

- `git diff --check`: passed.
- Stale URL-keyed session API call-site search: clean.
- iOS compile/unit tests: still require macOS/Xcode; not executed here.
- Siri indexing, cold launch, locked-screen launch and microphone handoff:
  require physical-device testing before being called verified.

### Next work after this slice

1. Run the full unit suite on macOS and correct any App Intents compiler or
   metadata diagnostics.
2. Exercise default, Linux-specific and Mac-specific Siri phrases on device.
3. Refactor background audio lifecycle without weakening endpoint pinning.
4. Add the endpoint-aware ActivityKit target and state coordinator.

## 2026-10-03 — Phase 3 implemented in source: background voice continuity

### Existing behavior reused

- The app already declares the `audio` background mode in both `project.yml`
  and the generated `Sources/Info.plist`.
- Voice mode already owns a `.playAndRecord` audio session, an `AVAudioEngine`
  input tap, on-device `SFSpeechRecognizer`, system TTS, route-change recovery,
  and audio-interruption observation.
- `AppStore.beginBackgroundKeepAlive()` supplies the ordinary finite background
  task window for an in-flight Hermes network turn without changing audio.

### Changes

- Removed the deliberate `stopConversation()` on
  `UIApplication.didEnterBackgroundNotification`. Only an explicitly active
  conversation is preserved; idle voice mode gains no background microphone.
- Kept the optional “Hey Hermes” listener foreground-only and prevented it from
  reclaiming the shared audio session when an active conversation returns from
  the background.
- Added a per-conversation UUID. Delayed recovery work verifies this generation
  before restarting the microphone, preventing an old interruption callback
  from attaching itself to a newly started conversation.
- Added foreground recovery when iOS returns with a stopped audio engine and no
  listening, thinking, or speaking phase still active.
- Changed the conversation session to `.playAndRecord` / `.voiceChat`, retaining
  speaker routing and ducking behavior.
- During a remote Hermes turn, speech recognition now stops but the existing
  audio input engine remains active. This keeps legitimate audio I/O alive while
  the app is backgrounded and also makes the pre-existing TTS barge-in level
  monitor receive actual samples. No second transcription is accepted while the
  first turn is in flight.
- Interruption recovery now respects `shouldResume`; otherwise the conversation
  remains explicitly paused and tells the user how to resume.
- Corrected the microphone permission copy: “Hey Hermes” is supported only in
  the foreground, while a conversation the user explicitly starts may continue.
- Added pure policy tests proving that background preservation requires an
  active conversation and that foreground recovery cannot race listening,
  thinking, or speaking.

### Platform evidence and limits

Apple documents that `.playAndRecord` audio can continue while the screen is
locked when the app declares the `audio` background mode, and that interruption
recovery should inspect the system resumption recommendation. Apple also
documents recognition availability and duration limits. These establish the
intended configuration, not device-level proof:

- <https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord>
- <https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions>
- <https://developer.apple.com/documentation/speech/sfspeechrecognizer>

### Verification state

- `git diff --check`: passed during implementation.
- Source search confirms no background handler still ends an explicit voice
  conversation.
- iOS compile/unit tests: unavailable in this Linux workspace because Xcode and
  the Swift toolchain are not installed.
- Background, lock-screen, Bluetooth, Siri-handoff, phone-call interruption,
  echo cancellation and barge-in behavior remain **implemented but unverified**
  until the matrix in `VOICE_DEVICE_TEST_PLAN.md` passes on a physical iPhone.

### Next work after this slice

1. Add endpoint-aware ActivityKit state and a Dynamic Island/Lock Screen UI.
2. Add safe interactive mute/resume/end controls without exposing credentials.
3. Execute the macOS compile/unit gate and physical-device test matrix.
4. Tune audio policy only from measured device failures; do not add a paid STT
   service or another backend pre-emptively.

## 2026-10-03 — Phase 4 implemented in source: voice Live Activity

### Existing behavior reused

- The existing `HermesControlWidget` extension now hosts the ActivityKit widget;
  no second extension, backend, APNs integration, or relay was added.
- The endpoint-pinned `VoiceEndpointBinding`, per-conversation UUID, App Group,
  and App Intents foundation from phases 1–3 provide the identity and process
  handoff needed by the Live Activity.
- Generic `AppStore.toolEvents` drive tool progress without exposing tool input,
  output, commands, paths, prompts, or response text on the Lock Screen.

### Changes

- Added `HermesVoiceActivityAttributes`, shared byte-for-byte by the app and
  widget targets. Immutable attributes contain only conversation UUID, endpoint
  UUID, a bounded display name and start time. Dynamic state contains only a
  phase, tool count, mute flag and update time.
- Added `VoiceLiveActivityCoordinator` to start, coalesce, update and end exactly
  one activity for the active voice conversation. A new app launch removes
  orphaned cards because an in-process microphone session cannot survive process
  death.
- Added Lock Screen, compact, minimal and expanded Dynamic Island layouts with
  endpoint identity and listening, thinking, generic tool-use, speaking, paused,
  reconnecting, failure and ended presentation states.
- Added interactive mute/resume and end buttons using `LiveActivityIntent`,
  which Apple documents as executing in the main app process. Every action must
  match both the conversation UUID and endpoint UUID and expires after 30
  seconds; mismatches are consumed and discarded rather than reaching a later
  session.
- Added real microphone mute/resume behavior to `VoiceConversationManager` and
  mirrored it in the full-screen voice UI. Muting stops input and recognition;
  it does not cut off Hermes TTS already in progress.
- Added an endpoint-scoped `hermes-companion://voice?endpoint=<UUID>` deep link.
  Tapping an activity uses the existing exact endpoint resolver and therefore
  never falls back from an unavailable Linux endpoint to Mac or vice versa.
- Enabled `NSSupportsLiveActivities`, added the URL scheme, and updated both
  `project.yml` and the checked-in Xcode project. This runner has no XcodeGen, so
  keeping both representations synchronized is intentional.

### Tests added

- Phase precedence and nonnegative tool counts.
- Endpoint display-name bounding and single-line sanitization.
- Endpoint deep-link round-trip and foreign-scheme rejection.
- Exact conversation/endpoint action matching, stale-action rejection, and
  destructive consumption of mismatched actions.
- Muted conversations cannot be restarted by foreground recovery.

### Verification state

- `git diff --check`: passed during implementation.
- Static project membership checks confirm shared ActivityKit files are in both
  the app and widget targets and the coordinator is app-only.
- No endpoint URL, credential, prompt, transcript, response body, tool name,
  command or tool output is present in ActivityKit state.
- iOS compilation, App Intents metadata extraction, widget rendering and button
  execution remain unverified because this Linux runner has no Xcode/Swift SDK.
- Apple documents that `LiveActivityIntent` runs in the app process, but locked
  devices require authentication before interactive buttons execute. Exact
  lock-screen behavior remains a physical-device gate.

### Next work after this slice

1. Compile and run tests on macOS; correct any ActivityKit/App Intents metadata
   diagnostics before adding polish.
2. Execute the endpoint, Siri, background audio and Dynamic Island device matrix.
3. Add bounded reconnect state only if device/network tests expose a gap; never
   auto-fail over to the other Hermes endpoint.
