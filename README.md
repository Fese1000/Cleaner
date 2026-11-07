# Cleaner

[![Latest release](https://img.shields.io/github/v/release/Fese1000/Cleaner)](https://github.com/Fese1000/Cleaner/releases/latest)
[![Build](https://github.com/Fese1000/Cleaner/actions/workflows/build.yml/badge.svg)](https://github.com/Fese1000/Cleaner/actions/workflows/build.yml)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A native Mac app (SwiftUI) that shows what is eating your disk: outdated documents, large files, duplicates, caches, apps and more – all sorted by size and deletable right from the app. A storage manager with the catalog look of [HomebrUI](https://github.com/Fese1000/HomebrUI): paper, ink, square edges, monospace names.

Everything runs locally. The only network access is the update check against GitHub when you trigger it.

> Deutsche Version: [README.de.md](README.de.md)

## Download

Get the app from the [latest release](https://github.com/Fese1000/Cleaner/releases/latest), open the DMG and drag Cleaner to Applications.

- **Cleaner-AppleSilicon.dmg** for Macs with Apple silicon (M1 and later)
- **Cleaner-Intel.dmg** for Intel Macs

The app is not notarized (ad-hoc signed only), so macOS asks once on the first start: right-click the app and choose Open, or on macOS 15 and later go to System Settings → Privacy & Security and click "Open Anyway".

## Features

- **Overview** – disk usage, cleanup potential per category, history and the total space freed so far.
- **Large files** – everything above an adjustable size, sorted by size.
- **Outdated documents** – PDF, Office, Pages, Numbers, Keynote … not opened or changed for N days (uses Spotlight's "last opened").
- **Downloads** – your Downloads folder by size and age.
- **Duplicates** – identical files (size → partial hash → SHA-256). Hard links are not counted as copies. "Auto-select" keeps the oldest copy of each group and warns if every copy of a group is selected.
- **Caches & logs** – app caches, logs, Xcode (DerivedData, DeviceSupport, archives), iOS backups, npm/Gradle/Cargo/Maven caches.
- **Apps** – installed apps by size and last use; "Uninstall" also removes leftovers in `~/Library`.
- **Explorer** – browse folder by folder, sorted by size, with hidden files and external volumes.
- **Trash** – look at it and empty it.
- Search, sorting, filters, multi-select, Quick Look, "Show in Finder", an ignore list.
- **Safe deleting** – the default is the Trash (recoverable); "Delete permanently" always asks. Important folders (home, Documents, the main Library folders, photo libraries, system paths) are locked. Software folders such as `node_modules`, `venv` or `miniconda3` count as one block, not thousands of files.
- **Settings** – German and English, 12 color schemes (default light/dark/system, Solarized, Gruvbox, Nord, Dracula, Monokai, Tokyo Night, One Dark, Catppuccin), thresholds, scanned folders, ignored paths.
- **Updates** – on request Cleaner asks GitHub, downloads the matching DMG, verifies checksum, code signature and bundle identifier, replaces itself and restarts.

## Full Disk Access

For the Trash, Mail downloads and protected folders, Cleaner needs *Full Disk Access* under System Settings → Privacy & Security. Because the app is ad-hoc signed, macOS may ask again after an update.

## Build from source

You only need the Xcode Command Line Tools (no Xcode):

```bash
./make-app.sh all     # or: arm64 | x86_64
```

This builds `dist/Cleaner-AppleSilicon.dmg` and `dist/Cleaner-Intel.dmg` (macOS 13+). For a proper signature use `CODESIGN_ID="Developer ID Application: …" ./make-app.sh all` and notarize the DMG with `notarytool`. For development, `swift run` starts the app without a bundle (no self-update).

## Releasing

1. Bump `VERSION` and commit.
2. `git tag v0.1.1 && git push --tags` – `.github/workflows/release.yml` builds both DMGs and attaches them to the release.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: [SECURITY.md](SECURITY.md).

## License

MIT, see [LICENSE](LICENSE).
