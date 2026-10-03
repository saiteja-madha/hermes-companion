#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$repo_dir/HermesCompanion.xcodeproj"
scheme="HermesCompanion"
destination="${JARVIS_DESTINATION:-platform=iOS Simulator,OS=latest,name=iPhone 17 Pro}"
derived_data="$(mktemp -d "${TMPDIR:-/tmp}/hermes-jarvis-verification.XXXXXX")"
result_bundle="$repo_dir/JARVIS-Verification.xcresult"

cleanup() {
  rm -rf "$derived_data"
}
trap cleanup EXIT

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required; run this script on macOS with Xcode installed" >&2
  exit 1
fi

if [[ ! -d "$project" ]]; then
  echo "error: missing $project" >&2
  exit 1
fi

if [[ -e "$result_bundle" ]]; then
  echo "error: $result_bundle already exists; archive or remove it before rerunning" >&2
  exit 1
fi

echo "Verifying Hermes JARVIS foundation"
echo "Destination: $destination"

xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  CODE_SIGNING_ALLOWED=NO \
  test

app_path="$(find "$derived_data/Build/Products" -type d -name HermesCompanion.app -print -quit)"
if [[ -z "$app_path" ]]; then
  echo "error: test succeeded but HermesCompanion.app was not found" >&2
  exit 1
fi

plist="$app_path/Info.plist"
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :NSSupportsLiveActivities' "$plist")" != "true" ]]; then
  echo "error: built app does not enable Live Activities" >&2
  exit 1
fi

background_modes="$(/usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' "$plist")"
if ! grep -q "audio" <<<"$background_modes"; then
  echo "error: built app is missing the audio background mode" >&2
  exit 1
fi

if ! find "$app_path/PlugIns" -maxdepth 1 -type d -name '*.appex' -print -quit | grep -q .; then
  echo "error: built app does not contain its widget extension" >&2
  exit 1
fi

echo "PASS: build, unit tests, Live Activities, background audio, and widget embedding"
echo "Result bundle: $result_bundle"
echo "Next: execute docs/VOICE_DEVICE_TEST_PLAN.md on a physical iPhone."
