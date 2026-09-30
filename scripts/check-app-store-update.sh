#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
if command -v xcrun >/dev/null 2>&1; then
  compiler=(xcrun --sdk macosx swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)")
elif command -v swiftc >/dev/null 2>&1; then
  compiler=(swiftc)
else
  echo 'Swift compiler is required. Run on macOS with Xcode or Linux with Swift installed.' >&2
  exit 1
fi
"${compiler[@]}" -swift-version 5 \
  "$repo_dir/Sources/Core/AppIdentity.swift" \
  "$repo_dir/Sources/Services/AppStoreUpdateService.swift" \
  "$repo_dir/Sources/Services/AppStoreCountryCodes.swift" \
  "$repo_dir/Sources/Services/AppStoreUpdateReminder.swift" \
  "$repo_dir/Tests/AppStoreUpdateChecks.swift" \
  -o "$check_dir/app-store-update-checks"
"$check_dir/app-store-update-checks"
