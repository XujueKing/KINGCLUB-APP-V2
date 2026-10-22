#!/bin/bash
# Xcode Cloud owns archiving, signing and TestFlight delivery after this hook.
set -euo pipefail

if [[ "${CI_XCODE_CLOUD:-}" != "TRUE" ]]; then
  echo "Run this hook in Xcode Cloud, or in an isolated CI smoke-test checkout." >&2
  exit 1
fi

repo="${CI_PRIMARY_REPOSITORY_PATH:?Missing CI_PRIMARY_REPOSITORY_PATH}"
workspace="${CI_WORKSPACE_PATH:?Missing CI_WORKSPACE_PATH}"
cd "$repo"

# Validate before downloading an SDK or resolving dependencies.
python3 ios/ci_scripts/configure_cloud_build.py --validate-only

sdk="${KINGCLUB_FLUTTER_ROOT:-$workspace/kingclub-flutter}"
revision="6655482ec06e547f90abf8ae7590466f4415978d"
if [[ ! -d "$sdk/.git" ]]; then
  git clone --depth 1 --branch 3.47.1 https://github.com/flutter/flutter.git "$sdk"
fi
if [[ "$(git -C "$sdk" rev-parse HEAD)" != "$revision" ]]; then
  echo "Flutter SDK does not match the reviewed 3.47.1 revision." >&2
  exit 1
fi
export PATH="$sdk/bin:$PATH"
export COCOAPODS_DISABLE_STATS=true
export HOMEBREW_NO_AUTO_UPDATE=1

xcodebuild -version
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
if (( ${sdk_version%%.*} < 26 )); then
  echo "Select Xcode 26 or later in the Xcode Cloud workflow." >&2
  exit 1
fi

flutter config --no-analytics
flutter precache --ios
flutter pub get --enforce-lockfile
python3 scripts/patch_ios_avatar_cropper.py

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi
pod --version

# Do not echo client keys or pass them directly in shell command arguments.
umask 077
defines_file="$(mktemp "${TMPDIR:-/tmp}/kingclub-cloud-defines.XXXXXX")"
trap 'rm -f "$defines_file"' EXIT
python3 ios/ci_scripts/configure_cloud_build.py --output "$defines_file"

flutter build ios --release --config-only --no-codesign --no-pub \
  --build-name="${KINGCLUB_BUILD_NAME:-1.2.0}" \
  --build-number="$CI_BUILD_NUMBER" \
  --dart-define-from-file="$defines_file"

(cd ios && pod install --deployment)
echo "Flutter configuration and native dependencies ready for Xcode Cloud archive."
