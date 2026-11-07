# Security Policy

## Supported versions

Only the latest [release](https://github.com/Fese1000/Cleaner/releases/latest) is supported.

## Reporting a vulnerability

Please do not open a public issue. Report it privately with GitHub's [private vulnerability reporting](https://github.com/Fese1000/Cleaner/security/advisories/new) ("Security" tab → "Report a vulnerability").

Include what you found, how to reproduce it and which version you tested. You will get an answer as soon as possible; this is a hobby project, so please allow a few days.

## What is in scope

Cleaner runs locally, has no server and sends no data anywhere. The only network request is the update check against the GitHub API and the download of a release DMG, which is verified by SHA-256 checksum, code signature and bundle identifier before the app replaces itself. Interesting reports include: deleting files outside what the user confirmed, bypassing the protection of important folders (`Safety.isProtected`), and a way to make the updater install something other than the official release.
