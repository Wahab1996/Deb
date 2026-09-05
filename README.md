# Purchase State Inspector v0.1

A standalone, read-only jailbreak utility for inspecting installed iOS app containers during authorized testing.

## What it does
- Lists installed user apps and their Bundle IDs.
- Shows bundle and data-container paths.
- Scans `Documents`, `Library/Preferences`, and `Library/Application Support`.
- Parses `.plist` and `.json` and flags purchase/subscription-like key paths.
- Opens SQLite databases read-only and samples columns whose names look purchase-state-related.
- `Snapshot Before` / `Compare After` reports exact structured values that changed.
- Displays the exact file path and key/table location for each finding.

## Safety boundary
This build is intentionally read-only: it contains no feature for changing another app's purchase state, receipts, entitlements, or subscription status. Use it on apps you own or are authorized to test.

## Build on GitHub
The included `.github/workflows/build.yml` builds a rootless `.deb` using a macOS GitHub runner and Theos.

1. Upload the project contents to the repository root.
2. Open **Actions** > **Build Rootless DEB**.
3. Run the workflow or push to `main`.
4. Download the `PurchaseStateInspector-rootless-DEB` artifact.

## Device target
- iOS 15+
- rootless jailbreak (e.g. Dopamine)
- arm64
