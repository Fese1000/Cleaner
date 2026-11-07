# Contributing to Cleaner

Thanks for helping! Bug reports, ideas and pull requests are welcome. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting bugs and ideas

Open an [issue](https://github.com/Fese1000/Cleaner/issues/new/choose) and use the template. For a bug, include your macOS version, chip (Apple silicon or Intel), the Cleaner version and which view is affected. Security problems: see [SECURITY.md](SECURITY.md), not a public issue.

## Development

Cleaner is a native SwiftUI app with no third-party dependencies. You only need the Xcode Command Line Tools.

```bash
swift build -c release     # compile
swift run                  # run without an app bundle (no self-update)
./make-app.sh arm64        # build Cleaner.app and a DMG (or: x86_64 | all)
```

Handy while developing: start the app on a specific view with `CLEANER_SECTION=duplicates swift run` (`overview`, `large`, `stale`, `downloads`, `duplicates`, `caches`, `apps`, `explorer`, `trash`, `settings`).

Layout: `Scanner.swift` (file, duplicate, cache and app scanners), `AppState.swift` (state, deleting), `Updater.swift` (GitHub self-update), `Theme.swift` (12 color schemes), the rest are views.

## Pull requests

- Keep a change focused; one topic per pull request.
- No new dependencies.
- Do not use `@State`: the macro needs Xcode plugins and breaks builds with only the Command Line Tools. Use a small `ObservableObject` instead (see `ListUI`).
- New or changed UI text needs German and English via `T("de", "en")`.
- Anything that deletes files must go through `Deleter` and respect `Safety.isProtected`. Moving to the Trash stays the default.
- Describe what you changed and why. Screenshots help for UI changes.
