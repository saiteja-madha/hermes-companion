# JARVIS-like Hermes iOS foundation research

Last updated: 2026-10-03

## Decision

Use **HermesCompanion**, forked from `chibitek/HermesCompanion` `main` at
`bfe8cad73abb8c99cdf227f81b2e2d82668d1146`.

It is the shortest path because the app already combines the four pieces that
would otherwise be the largest body of work:

1. Direct Hermes gateway chat and session APIs (`Sources/HermesAPIClient.swift`).
2. A continuous listen → transcribe → Hermes → speak loop
   (`Sources/VoiceConversationManager.swift`, `Sources/ChatView.swift`).
3. Multiple saved gateways with Keychain-backed credentials
   (`Sources/KeychainManager.swift`, `Sources/AppStore.swift`).
4. Per-gateway active-session restoration (`Sources/ActiveSessionPersistence.swift`).

The recommended MVP endpoint model is a user-selected default plus two explicit
Siri shortcuts: **Start Hermes on Linux** and **Start Hermes on Mac**. A generic
**Start Hermes** shortcut should use the stored default and announce/display the
target. Voice sessions are pinned to the chosen endpoint for their entire life;
switching endpoint ends the active voice session and requires explicit restart.

The strongest alternative is the maintained Hermex repository at
`uzairansaruzi/hermex`. It has the best existing App Intents, multi-server
isolation, direct-Hermes protocol coverage, and agent-run Live Activity. However,
its microphone controller is composer dictation: it writes transcript into a
draft and does not implement a continuous TTS conversation loop. Adding that loop
would duplicate the central feature HermesCompanion already has.

## Scope and method

The comparison below is based on source inspection, not project descriptions.
The inspected heads were:

| Project | Inspected commit | Last commit in inspected clone |
| --- | --- | --- |
| HermesCompanion | `bfe8cad73abb8c99cdf227f81b2e2d82668d1146` | 2026-10-02 |
| Hermes iOS | `359e6e37c149592cb107f4bbb96d9e4957cb211f` | 2026-10-02 |
| Hermex (`DMelisena`) | `e39447d165ee6be384b528a175f8cf9944cbe129` | 2026-07-03 |
| Hermex (`uzairansaruzi`) | `209e09874575985b27820a02b7960bb02a9bd108` | 2026-10-02 |
| Herald | `09f672a47e21cd742509667b371a48520387019f` | 2026-08-03 |
| Additional candidate: `Molliex05/hermes-ios` | `51636eb0dd0a3f2836c2d8e939efddd28baf5cab` | 2026-09-14 |

The `DMelisena/hermex-iOS` head is the exact commit `e39447d` in the
`uzairansaruzi/hermex` history and is an ancestor of its current head. Their root
commits and early history also match. They are an older checkout and maintained
continuation of the same application, not two independent implementations. Only
the maintained repository should be considered for new work.

Status legend:

- **Verified**: implementation exists and the repository contains focused tests
  or the inspected project records a relevant passing verification.
- **Untested**: source implementation exists, but this audit did not execute it.
- **Partial**: some of the requested behavior exists, but not the complete flow.
- **Missing**: the needed implementation is absent or the code explicitly does
  something incompatible with the requirement.
- **Unknown**: source inspection was insufficient to establish behavior.

## Evidence-based comparison

| Feature | HermesCompanion | Hermex (maintained) | Hermes iOS | Herald | Hermex (`DMelisena`) |
| --- | --- | --- | --- | --- | --- |
| Direct Hermes connectivity | **Verified** — gateway REST/SSE in `Sources/HermesAPIClient.swift`; contract and live tests in `Tests/HermesModelContractTests.swift`, `Tests/LiveGatewayTests.swift` | **Verified** — direct WebUI/Hermes transports in `Networking/APIClient*.swift` and `Networking/Hermes/*`; extensive endpoint tests | **Missing** for the requested topology — app targets `RelayAPIClient`; connector/relay is mandatory | **Missing** for direct topology — `RelayAPIClient` and connector/relay mediate requests | Same as maintained Hermex at its older head |
| Existing Hermes sessions and memory | **Verified** for gateway sessions; models/tools/skills remain server-owned. Extended workspace features can require the included Companion bridge | **Verified** — server sessions, memory, skills, models are first-class clients | **Partial** — relay maps conversations and commands to a paired host | **Partial** — relay maps Hermes jobs/conversations; native Talk submits Hermes turns | Same older implementation |
| Multiple Hermes endpoints | **Implemented, untested in fork** — stable endpoint UUIDs, picker, health checks, independent voice default, `switchToConnection` | **Verified** — `AuthManager.servers`, active-server routing, per-server view identity | **Missing** — one active relay/pairing configuration | **Partial/unknown** — profile support exists, but one active relay/host topology dominates | Older multi-server implementation; less complete |
| Separate endpoint credentials | **Verified** — configs including API keys are stored in Keychain | **Verified** — `Auth/KeychainStore.swift`, server account registry, isolated cookie jars | **Partial** — paired relay token in Keychain, but no two-Hermes endpoint registry | **Partial** — relay session/profile credentials, not two direct Hermes endpoints | Same older design |
| Separate session state per endpoint | **Implemented, untested in fork** — active session pointers use stable endpoint UUIDs with one-time URL-key migration; server sessions remain remote | **Verified** — caches and views are keyed by server URL; source comments explicitly tear down views on switch | **Missing/unknown** | **Missing/unknown** | Partial at old head |
| Safe endpoint switching | **Implemented, untested in fork** — immutable voice endpoint binding, mismatch rejection, and exact-request/no-fallback Siri routing | **Verified** for chat/server routing; no continuous voice session to protect | **Missing** | **Missing** for two independent Hermes endpoints | Partial at old head |
| Continuous two-way voice | **Verified in source; device retest required** — on-device STT, Hermes turn, AVSpeechSynthesizer, auto-resume | **Missing** — `ComposerVoiceInputController` is dictation into a draft; no response TTS loop | **Partial** — substantial Realtime voice mode, but it uses relay/OpenAI Realtime rather than the existing Hermes voice/session path | **Untested** — `HermesTalkCoordinator` has VAD, Hermes turn streaming, TTS, auto-turn-taking, and barge-in | Missing at old head |
| VAD / endpointing | **Partial** — speech partials plus a 1.5-second silence timer, not a dedicated VAD model | **Partial** — dictation endpointing only | **Implemented, untested** in Realtime voice stack | **Implemented, untested** — `TalkAudioCapture.startListeningWithVAD()` | Partial dictation only |
| Interruptible responses | **Partial** — stop/tap and level-based barge-in machinery exist; physical-device reliability remains to verify | **Missing** | **Implemented, untested** | **Implemented, untested** | Missing |
| Background voice | **Implemented, device-unverified in fork** — explicit conversations retain audio I/O; wake listening remains foreground-only | **Missing** — recorder policy requires active/unlocked app | **Unknown/partial** | **Unknown/partial** | Missing |
| Locked-screen voice | **Implemented by documented audio configuration, device-unverified** — `.playAndRecord` plus `audio` background mode and foreground recovery | **Missing** by recording policy | **Unknown** | **Unknown** | Missing |
| Siri activation | **Implemented, device-unverified in fork** — App Shortcut opens directly into the preferred endpoint’s voice page | **Verified for dictation** — `NewChatVoiceIntent` plus `HermexShortcuts`; does not continue into conversational voice | **Missing** in inspected Swift sources | **Missing for Talk** — App Intents control gateway/model operations, not start Talk | Older New Chat intents; not conversational |
| Siri endpoint selection | **Implemented, device-unverified in fork** — endpoint entity plus explicit server intent; removed endpoints never fall through | **Partial** — profile intent and server-aware routing exist, but the voice intent is not server-parameterized and is dictation | **Missing** | **Missing** | Partial profile selection only |
| Dynamic Island / Lock Screen | **Implemented, device-unverified in fork** — all ActivityKit presentations share the existing widget extension | **Verified** for agent runs; `AgentRunActivityAttributes` records server and session and widget declares expanded regions | **Implemented, untested** for relay voice state | **Implemented, untested** for relay/host activity state | Implemented at older feature level |
| Active endpoint in Live Activity | **Implemented, device-unverified in fork** — bounded endpoint label in compact, expanded and Lock Screen views | **Partial** — server URL is in attributes for routing; UI is agent-run-centric, not voice-target-centric | **Missing** for multiple endpoints | **Missing** for multiple endpoints | Partial at old head |
| Interactive Dynamic Island controls | **Implemented, device-unverified in fork** — exact conversation+endpoint mute/resume/end intents; locked actions require authentication | **Partial** — deep-link/activity interactions exist, not voice mute/resume/end | **Partial/unknown** | **Partial/unknown** | Partial at old head |
| Tool-execution status | **Implemented, device-unverified in fork** — generic tool phase and count; sensitive details stay in app | **Verified** in chat and agent-run Live Activity | **Partial** through relay activity states | **Implemented, untested** — Talk coordinator emits tool activity and Live Activity has phases | Verified in chat/Live Activity at old head |
| Modern voice UI | **Verified in source** — full-screen animated Matrix/CRT/orb interface | **Missing** — polished chat/dictation UI only | **Implemented, untested** | **Implemented, untested** | Missing |
| Additional backend | Optional for core chat/voice; included bridge/patches are needed for some extended workspace/run features | Hermes WebUI/Hermes server; push updates may require server pairing | **Required** relay plus connector | **Required** relay plus connector; Mimo services for native Talk | Same WebUI-oriented backend |
| Additional paid voice API | **None introduced by iPhone voice path**; Hermes model/provider can still have its own cost | None for on-device dictation; server STT may use configured service | **Yes/likely** — OpenAI Realtime voice session | **Potentially** — Mimo ASR/TTS; legacy OpenAI Realtime remains behind a flag | Same as old Hermex |
| Offline endpoint handling | **Partial** — parallel health status, connection errors and reconnect path; voice fail path returns to listening | **Verified/strong** — connection identity, errors, server registry, cached state | **Partial** — relay/host health state | **Partial** — relay and gateway health/control state | Older, less complete handling |

### Key source evidence

HermesCompanion evidence is in this repository:

- Gateway configuration and API key model: `Sources/Models.swift` (`ConnectionConfig`).
- Keychain persistence: `Sources/KeychainManager.swift`.
- Multi-server selection/reset: `Sources/AppStore.swift` (`switchToConnection`).
- Per-server session restore: `Sources/ActiveSessionPersistence.swift` and
  `AppStore.restoreActiveSessionIfAvailable()`.
- Voice loop and audio lifecycle: `Sources/VoiceConversationManager.swift`.
- Hermes routing for each spoken turn: `Sources/ChatView.swift`
  (`handleVoiceTranscription`).
- Voice UI: `Sources/VoiceConversationPage.swift`.
- Existing App Intent: `ControlWidget/VoiceActivationControl.swift`.
- Existing extension declaration: `project.yml`; it contains a Control Widget
  target and no ActivityKit target.

External candidates were inspected at the commits listed above. Important paths:

- Hermes iOS: `HermesMobile/Stores/AppContainer.swift` constructs one
  `RelayAPIClient`; `HermesMobile/Services/Live/LiveVoiceSessionService.swift`
  performs OpenAI Realtime setup; `HermesMobileWidgets/HermesLiveActivity.swift`
  implements ActivityKit.
- Hermex: `HermesMobile/Features/Chat/ComposerVoiceInputController.swift` owns
  dictation; `HermesMobile/AppIntents/HermexAppIntents.swift` implements Siri
  shortcuts and profile selection; `HermesMobile/ContentView.swift` and
  `Auth/KeychainStore.swift` implement active-server routing and credential
  isolation; `HermesMobile/LiveActivities/AgentLiveActivityManager.swift` and
  `HermesLiveActivityWidget/AgentRunLiveActivityWidget.swift` implement the run
  activity.
- Herald: `Herald/Services/Live/HermesTalkCoordinator.swift` implements the
  native Talk state machine; `MimoASRService.swift` and `MimoTTSService.swift`
  provide speech services; `RelayAPIClient.swift` and the `connector/` and
  `relay/` directories establish required infrastructure;
  `HeraldWidgets/HeraldLiveActivity.swift` implements ActivityKit.

## Recommended architecture

```text
Siri / App Shortcut
        |
        v
StartVoiceIntent(endpoint = default | Linux | Mac)
        |
        v
EndpointResolver -----> EndpointRegistry
        |                 |-- Linux URL + capabilities
        |                 |-- Mac URL + capabilities
        |                 `-- credentials in Keychain
        v
Pinned VoiceSessionContext
  endpointID + sessionID + generation
        |
        +------> ActivityCoordinator ------> Lock Screen / Dynamic Island
        |          listening / thinking / speaking / tool / reconnecting
        |
        v
VoiceConversationManager
  mic -> on-device STT -> endpoint-bound HermesAPIClient
                              |
                    +---------+---------+
                    |                   |
              Linux Hermes          Mac Hermes
              session A             session B
                    |                   |
                    +---------+---------+
                              v
                   assistant response -> TTS

On reachability failure:
  keep endpoint binding -> show/announce offline -> bounded reconnect
  -> never fail over to the other endpoint automatically
```

The endpoint registry should retain HermesCompanion's existing Keychain storage
for credentials, but evolve `ConnectionConfig` to have a stable UUID. URL is not
a durable identity because users can change DNS names, ports, or profile paths.
Non-secret display metadata and a default endpoint UUID may live in app-group
defaults so the widget and App Intents can resolve labels. Secrets must remain in
Keychain and must never be copied into ActivityKit attributes.

Each endpoint owns its own active session ID. A voice session captures endpoint
UUID, normalized URL, API client identity, and the active session ID/generation.
An endpoint switch during voice mode ends voice mode. There is no automatic
Linux-to-Mac failover, because availability is not authorization to run a command
on the other machine.

## Exact implementation plan

### 1. Fork safety and endpoint identity — small, 1–2 developer-days

Reuse unchanged: saved connections, Keychain storage, health checks,
`switchToConnection`, per-URL session persistence.

Change:

- Add stable endpoint UUID and an explicit default endpoint.
- Migrate existing URL-keyed records without losing credentials.
- Pin every voice session to an immutable endpoint binding.
- Display endpoint identity in chat and voice UI.
- Stop voice safely if the endpoint changes.

Verification: unit tests with Linux and Mac configurations must prove a captured
Linux voice turn cannot match or use the Mac configuration. This phase has begun
in this fork; see `JARVIS_IMPLEMENTATION_LOG.md`.

### 2. Endpoint-aware App Intents — medium, 2–4 developer-days

Reuse Hermex's pattern from `ProfileEntity.swift` and `HermexAppIntents.swift`,
adapting it to HermesCompanion's endpoint registry rather than copying its auth
architecture.

Add `HermesEndpointEntity`, `StartHermesVoiceIntent`, and an
`AppShortcutsProvider`. Expose:

- “Start Hermes” (uses the preferred default).
- “Start Hermes on Linux”.
- “Start Hermes on Mac”.

The intent writes a pending endpoint UUID into app-group defaults, opens the app,
connects that exact endpoint, then starts voice only after health and session
restore succeed. If the phone is locked or iOS declines microphone activation,
the app should surface a notification/UI state instead of claiming success.

Verification requires physical-device tests for warm launch, cold launch, locked
screen, denied permission, endpoint offline, and Siri phrase disambiguation.

### 3. Background-capable audio lifecycle — high, 4–8 developer-days

Reuse the current STT/TTS loop, route-change logic, interruption handling, and
existing `audio` background mode.

Implemented in source in this fork: `VoiceConversationManager` no longer ends an
explicit conversation on backgrounding, uses `.playAndRecord` / `.voiceChat`,
retains audio input (but not speech recognition) during a remote turn, and has
generation-safe foreground/interruption recovery. `ChatView` still pauses the
separate wake-word listener in the background and prevents it from racing the
active conversation on foreground return.

This phase is device-dependent. Apple's scheduler, Speech framework behavior,
lock state, Bluetooth routes, phone calls, and Siri handoff cannot be proven in a
simulator. If continuous `SFSpeechRecognizer` proves unreliable while locked,
the fallback is server streaming STT—not an additional LLM—but that adds backend
and maintenance cost and should not be chosen pre-emptively.

### 4. Voice Live Activity / Dynamic Island — medium-high, 4–7 developer-days

Implemented in source using the existing widget extension. The fork adapts only
the privacy/state-machine lessons from the inspected candidates; it does not
import their WebUI/relay coordinators or require their infrastructure:

- immutable attributes: endpoint UUID and safe display label;
- content state: connecting, listening, thinking, tool activity, speaking,
  muted, reconnecting, ended;
- exact endpoint/conversation `LiveActivityIntent` controls: mute/resume and end;
- expanded endpoint identity and a deliberate “switch” action that opens the app
  and ends the current voice session before selecting another endpoint.

The activity coordinator observes `VoiceConversationManager` and generic
`AppStore.toolEvents`, coalesces equal states, and never includes credentials,
endpoint URLs, prompts, transcripts, response text, tool names or tool output.

### 5. Reliability and endpoint recovery — medium, 3–5 developer-days

Add endpoint-scoped reachability state and bounded backoff. An offline selected
endpoint remains selected. Offer “Retry Linux”, “End session”, and “Open endpoint
picker”; never silently send to Mac. Preserve unsent transcription locally only
long enough to allow explicit retry and label it with endpoint UUID/session ID.

Test concurrency: switch endpoint before transcription finalizes, while a request
is streaming, during TTS, and during reconnect. Assert requests received by two
stub servers and verify zero cross-routing.

### 6. Polish — optional after MVP, 2–5 developer-days

Improve voice animation, response interruption thresholds, tool-progress copy,
and endpoint color/icon customization only after the device reliability matrix
passes.

## Minimum viable implementation

The MVP is complete only when all of the following work on a physical iPhone:

1. Linux and Mac are both saved with isolated credentials and active sessions.
2. An in-app selector chooses a visible default endpoint.
3. generic and endpoint-specific Siri shortcuts open the app and begin listening
   after connecting to the intended endpoint.
4. voice continues during ordinary background/lock use within documented iOS
   constraints and recovers from supported interruptions.
5. a voice Live Activity shows endpoint plus listening/thinking/speaking state and
   offers mute/resume/end.
6. an offline endpoint produces a clear endpoint-specific error and never falls
   through to the other endpoint.
7. integration tests prove Linux-bound messages reach only the Linux stub and
   Mac-bound messages reach only the Mac stub.

## Swift versus Expo

Remain in Swift. Expo would help only with familiar React component iteration and
some secure-storage/UI work. The required differentiators—App Intents with entity
parameters, ActivityKit and interactive Live Activities, precise AVAudioSession
ownership, background microphone behavior, real-time audio capture, lock-screen
lifecycle, and native state synchronization—require Swift targets/modules and
native entitlement work. A migration would preserve little of HermesCompanion's
most valuable implementation and introduce a cross-language lifecycle boundary
at exactly the highest-risk point.

An Expo app can call custom native modules for these capabilities, but building
and maintaining those modules is effectively maintaining the Swift solution plus
the React Native layer. There is no net reduction in work for this project.

## Risks and restrictions

- **License:** the repository badge says MIT, but the authoritative `LICENSE`
  file is a personal, non-commercial license. This is compatible with the stated
  personal fork, but upstream contribution or any commercial/internal-business
  use needs deliberate review.
- **Siri and lock screen:** `openAppWhenRun` can foreground/navigate the app, but
  successful hands-free microphone start after Siri dismisses—especially while
  locked—requires physical-device validation. Do not represent it as guaranteed.
- **Background speech recognition:** declaring audio background mode is necessary
  but does not guarantee indefinite Speech recognition. Current source actively
  stops voice on background, so this remains real work.
- **Two endpoints:** endpoint URLs can change, session IDs can collide across
  servers, and one server may be much newer than the other. Use stable endpoint
  IDs and scope every cache, session, activity and pending request by endpoint.
- **No automatic failover:** sending a Linux command to Mac because Linux is down
  is unsafe. Recovery must remain endpoint-pinned.
- **Authentication/network:** HTTP over a private VPN currently relies on broad
  ATS allowance. Prefer HTTPS or a private network such as Tailscale; never place
  API keys in defaults, logs, App Intent entities, URLs, or Live Activity state.
- **Protocol drift:** HermesCompanion may require its gateway compatibility
  patches/bridge for advanced APIs. Both independently maintained Hermes devices
  must advertise and be tested against the features this fork uses.
- **Upstream churn:** the chosen upstream is active. Keep changes in focused
  commits, avoid reformatting unrelated files, and regularly merge/rebase the
  upstream branch after tests pass.

## Development checklist

- [ ] Configure a personal fork remote; retain `chibitek/HermesCompanion` as `upstream`.
- [ ] Add the real Linux endpoint URL, display name, credentials and capabilities on device.
- [ ] Add the real Mac endpoint URL, display name, credentials and capabilities on device.
- [ ] Store each API key in Keychain and keep widget/App Intent metadata secret-free.
- [x] Add stable endpoint UUIDs with backward-compatible Keychain migration.
- [x] Keep API keys in Keychain and publish only UUID/label to App Intents.
- [x] Add a preferred/default endpoint and explicit in-app endpoint selector.
- [x] Capture and display an immutable endpoint binding when voice mode starts.
- [x] Reject/stop a voice turn when the active endpoint no longer matches.
- [x] Migrate per-URL active sessions to per-endpoint-UUID session records.
- [x] Pin voice routing to endpoint UUID and API client identity.
- [ ] Add an explicit voice-session generation token shared with ActivityKit controls.
- [x] End voice before endpoint switching; require explicit restart on the new target.
- [x] Add endpoint-aware App Entity and Siri/App Shortcut intents.
- [x] Add a generic default shortcut plus an endpoint-parameterized shortcut.
- [ ] Configure and device-test separate Linux and Mac Siri phrases.
- [ ] Preserve an explicit voice audio session in supported background/lock states.
- [ ] Add ActivityKit target and endpoint-aware Live Activity attributes/state.
- [ ] Synchronize listening/thinking/tool/speaking/muted/reconnecting states.
- [ ] Add mute/resume/end controls; make endpoint switch open the app safely.
- [ ] Add offline state, bounded reconnect and explicit retry for the same endpoint.
- [x] Never automatically fail over a command to the other Hermes endpoint.
- [ ] Add two-server integration tests proving each command reaches only its target.
- [ ] Test cold/warm Siri activation, lock screen, Bluetooth, interruption and offline cases on device.
