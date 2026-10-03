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

## Next work

1. Introduce stable endpoint UUIDs and a default endpoint without breaking the
   existing Keychain records.
2. Move pending voice launch requests into a small endpoint-aware coordinator.
3. Add `HermesEndpointEntity`, parameterized `StartHermesVoiceIntent`, and App
   Shortcut phrases for default/Linux/Mac.
4. Refactor the audio background transition; verify it on a physical device.
5. Add the ActivityKit target only after endpoint and session identity are stable.
