# Purchase State Inspector v0.2

Read-only local-state inspector for jailbroken iOS 15+ (rootless / Dopamine-style environments).

## What changed in v0.2

- **Full data-container snapshot** instead of keyword-only snapshots.
- Captures a manifest for every readable file (size, mtime and FNV-1a content hash; large files are safety-limited).
- Parses **XML/binary plist** files even when the extension is unusual.
- Parses **JSON** by extension or content sniffing.
- Reads **SQLite / CoreData SQLite** databases in read-only mode and records rows/cells up to safety limits.
- **Compare After** reports exact added / removed / changed local values and file changes.
- Static local-state scan ranks purchase/entitlement-like keys and highlights values that currently look disabled/locked.
- **StoreKit / Product Clues** scans app bundle + data files for receipt paths, StoreKit-related strings and possible product identifiers.
- Clear fallback message when no local state change is detected instead of claiming that no purchase state exists.

## Important scope

The inspector does not write to the selected app, alter receipts, forge transactions, or change entitlements. Static findings are candidates, not proof. The strongest evidence comes from Snapshot Before → authorized purchase/restore/test action → Compare After.

## Build

The included GitHub Actions workflow builds on macOS with Theos and uploads the rootless `.deb` artifact.

Path: `.github/workflows/build.yml`
