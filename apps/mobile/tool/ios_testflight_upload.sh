#!/usr/bin/env bash
# TestFlight 업로드 — Xcode·Apple Developer 계정이 있는 Mac에서 실행하세요.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode가 필요합니다. App Store에서 Xcode 설치 후:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -runFirstLaunch"
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods 설치: sudo gem install cocoapods"
  exit 1
fi

flutter pub get
cd ios && pod install && cd ..

echo "→ Archive & IPA (서명은 Xcode 팀 설정 필요)"
flutter build ipa --release

IPA="$(find build/ios/ipa -name '*.ipa' 2>/dev/null | head -1)"
if [[ -z "$IPA" ]]; then
  echo "IPA를 찾지 못했습니다. Xcode에서 ios/Runner.xcworkspace → Product → Archive 후 Distribute App을 사용하세요."
  exit 1
fi

echo "IPA: $IPA"
if command -v xcrun >/dev/null 2>&1 && xcrun altool --help >/dev/null 2>&1; then
  echo "App Store Connect 업로드 (API Key 또는 Apple ID 필요):"
  echo "  xcrun altool --upload-app -f \"$IPA\" -t ios --apiKey <KEY> --apiIssuer <ISSUER>"
  echo "또는 Transporter 앱으로 $IPA 를 드래그하세요."
else
  echo "Transporter 앱으로 IPA를 업로드하세요: $IPA"
fi
