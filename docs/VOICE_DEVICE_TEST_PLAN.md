# Voice device verification plan

Source implementation is not proof of iOS background behavior. Run this matrix
on the minimum supported physical iPhone before calling background or locked
voice verified. Use two distinguishable test gateways named **Linux** and
**Mac**, and configure each to answer with its endpoint name.

## Build gate on macOS

Run `scripts/verify-jarvis-ios.sh`. Override its simulator when necessary with,
for example, `JARVIS_DESTINATION='platform=iOS Simulator,OS=latest,name=iPhone 17'`.
The script preserves `JARVIS-Verification.xcresult` for inspection and refuses
to overwrite an existing result bundle.

- [ ] Regenerate the Xcode project from `project.yml` and confirm the diff is
  expected.
- [ ] Build the app and widget targets with the intended signing team.
- [ ] Run all `HermesCompanionTests`; preserve the `.xcresult` artifact.
- [ ] Confirm the built app contains `UIBackgroundModes = audio, fetch` and the
  app-group entitlement shared with the widget extension.
- [ ] Resolve all App Intents metadata/indexing diagnostics.

## Endpoint and Siri routing

- [ ] “Start Hermes” opens the configured default endpoint from a terminated
  app, a warm backgrounded app, and an already-open app.
- [ ] “Start Hermes on Linux” and “Start Hermes on Mac” each show the named
  target before the microphone begins listening.
- [ ] With Linux offline, a Linux-specific request reports Linux unavailable
  and sends zero traffic to Mac.
- [ ] Remove a saved endpoint, then invoke its previously indexed shortcut;
  confirm no fallback command is sent.
- [ ] Switch the in-app endpoint during listening, thinking, and speaking;
  each case must end voice mode before another endpoint can receive audio.

## Background and lock screen

- [ ] Start voice mode in the foreground, press the side button while listening,
  speak a command, hear the complete response, and complete a second turn.
- [ ] Repeat by switching to another application instead of locking.
- [ ] Lock while Hermes is thinking for 5, 30, and 90 seconds; confirm the
  response is spoken or record the exact suspension/failure behavior.
- [ ] Leave listening idle for more than one minute. Confirm recognition
  restarts without changing endpoints after the framework duration limit.
- [ ] End voice mode, lock the phone, and confirm the microphone privacy
  indicator and audio session both stop.
- [ ] Enable “Hey Hermes,” background the app without opening voice mode, and
  confirm wake listening does not continue.

## Live Activity and Dynamic Island

- [ ] Confirm one Live Activity begins only after an explicit voice conversation
  starts and disappears immediately when that conversation ends.
- [ ] Verify Lock Screen, compact, minimal and expanded Dynamic Island layouts on
  devices with and without Dynamic Island; endpoint identity must remain visible
  wherever space permits.
- [ ] Observe listening → thinking → using tools → speaking → listening and
  confirm the phase never displays prompts, transcript text, response text, tool
  names, commands, paths, URLs or credentials.
- [ ] Mute and resume from the expanded island and Lock Screen. Confirm only the
  matching conversation on the displayed endpoint changes microphone state.
- [ ] End from the expanded island and Lock Screen. Confirm audio input, TTS and
  the Live Activity all stop. Record when iOS requires device authentication.
- [ ] Tap a Linux activity while Mac is selected in the app; the app must route
  back to Linux or show Linux unavailable, never silently open voice on Mac.
- [ ] End voice, start a new conversation, then invoke a stale action captured
  from the prior activity; it must not affect the new conversation.
- [ ] Force-quit during voice mode and relaunch. Confirm the orphaned activity is
  removed before a new conversation starts.
- [ ] Disable Live Activities in Settings. Voice must continue normally without
  a card, crash, or repeated authorization prompt.

## Audio routes and interruptions

- [ ] Repeat a two-turn locked-screen conversation on the built-in microphone,
  wired audio (if available), AirPods, and a Bluetooth car/headset route.
- [ ] Connect and disconnect Bluetooth while listening and while speaking;
  confirm bounded recovery without duplicate turns.
- [ ] Receive and decline a phone/FaceTime call; resume only when iOS recommends
  it and confirm the pending transcript is not submitted twice.
- [ ] Accept and end a call; foreground Hermes and verify the explicit recovery
  path or clear paused-state guidance.
- [ ] Invoke Siri while Hermes is speaking. Confirm Siri’s interruption does not
  cause Hermes to resume against the system recommendation.
- [ ] Speak over TTS. Confirm barge-in stops the response without false triggers
  from the device speaker at normal and maximum volume.

## Network and session isolation

- [ ] Capture requests at both gateways. For 20 alternating Linux/Mac launches,
  assert each transcript appears exactly once at only the named endpoint.
- [ ] Confirm Linux and Mac restore different active Hermes session IDs after
  app termination and endpoint switching.
- [ ] Disable Wi-Fi/Tailscale during a turn, restore it, and confirm retries stay
  pinned to the original endpoint.
- [ ] Confirm an availability failure shows `RECONNECTING` in-app and in the
  Live Activity, performs no more than three health probes, and never resends
  the failed transcript automatically.
- [ ] Keep Linux offline through all probes, tap `RETRY LINUX`, and confirm every
  request still targets Linux while Mac receives zero traffic.
- [ ] Cause a 401/validation failure and confirm it does not masquerade as an
  endpoint reconnect or trigger health-probe traffic.
- [ ] Leave one endpoint offline while conversing with the other; health checks
  for the offline endpoint must not disrupt the active voice session.
- [ ] Rotate one endpoint credential and confirm the other endpoint’s Keychain
  record and active session remain unchanged.

## Evidence to record

For each failure, record the device model, iOS build, audio route, app commit,
endpoint, foreground/background/locked state, and relevant `FileLogger` lines.
Do not classify a row as passed from simulator behavior alone.
