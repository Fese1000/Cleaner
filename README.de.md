# Cleaner

> English version: [README.md](README.md)

Eine native Mac-App (SwiftUI), die dir zeigt, was auf deinem Mac Platz frisst: veraltete Dokumente, große Dateien, Duplikate, Caches, Apps und mehr – alles nach Größe sortiert und direkt aus der App löschbar. Design und Einstellungen sind an [HomebrUI](https://github.com/Fese1000/HomebrUI) angelehnt (Katalog-Look: Papier, Tinte, eckige Kanten, Monospace für Namen).

Alles läuft lokal. Das einzige Netzwerk ist die Update-Abfrage bei GitHub, wenn du sie auslöst.

## Download

Aus dem [neuesten Release](https://github.com/Fese1000/Cleaner/releases/latest) das passende DMG laden, öffnen und Cleaner in „Programme“ ziehen:

- **Cleaner-AppleSilicon.dmg** für Macs mit Apple Silicon (M1 und neuer)
- **Cleaner-Intel.dmg** für Intel-Macs

Die App ist nicht notarisiert (nur ad-hoc signiert). Beim ersten Start: Rechtsklick → Öffnen, oder ab macOS 15 unter Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“.

## Funktionen

- **Übersicht** – Festplattenbelegung, Aufräum-Potenzial je Kategorie, Verlauf und insgesamt freigegebener Platz.
- **Große Dateien** – alles ab einer einstellbaren Größe, nach Größe sortiert.
- **Veraltete Dokumente** – PDF, Office, Pages, Numbers, Keynote, Text … die seit N Tagen nicht geöffnet oder geändert wurden (nutzt Spotlights „zuletzt geöffnet“).
- **Downloads** – der Downloads-Ordner nach Größe und Alter.
- **Duplikate** – identische Dateien (Größe → Teil-Hash → SHA-256), „Automatisch markieren“ behält die älteste Kopie; Warnung, wenn alle Kopien einer Gruppe ausgewählt sind.
- **Caches & Logs** – App-Caches, Protokolle, Xcode (DerivedData, DeviceSupport, Archive), iOS-Backups, npm/Gradle/Cargo/Maven-Caches.
- **Apps** – Programme nach Größe und letzter Nutzung; „Deinstallieren“ räumt Reste in `~/Library` mit auf.
- **Explorer** – Ordner für Ordner nach Größe durchsuchen, inklusive versteckter Dateien und externer Volumes.
- **Papierkorb** – ansehen und leeren.
- Suche, Sortierung, Filter, Mehrfachauswahl, Quick Look, „Im Finder zeigen“, Ignorieren-Liste.
- **Sicher löschen** – Standard ist der Papierkorb (rückholbar); „Endgültig löschen“ fragt immer nach. Wichtige Ordner (Home, Dokumente, Library-Hauptordner, Foto-Mediathek, Systempfade) sind gesperrt.
- **Einstellungen** – Deutsch/Englisch, 12 Farbschemata (Standard, Solarized, Gruvbox, Nord, Dracula, Monokai, Tokyo Night, One Dark, Catppuccin), Schwellwerte, Scan-Ordner, Ignorierte Pfade.
- **Updates** – Cleaner prüft auf Wunsch GitHub, lädt das passende DMG, verifiziert Prüfsumme und Code-Signatur, ersetzt sich selbst und startet neu.

## Voller Festplattenzugriff

Für Papierkorb, Mail-Downloads und geschützte Ordner braucht Cleaner unter Systemeinstellungen → Datenschutz & Sicherheit → *Voller Festplattenzugriff* die Berechtigung. Da die App ad-hoc signiert ist, kann macOS sie nach einem Update erneut danach fragen.

## Selbst bauen

Nötig sind nur die Xcode Command Line Tools (kein Xcode):

```bash
./make-app.sh all     # oder: arm64 | x86_64
```

Das erzeugt `dist/Cleaner-AppleSilicon.dmg` und `dist/Cleaner-Intel.dmg` (macOS 13+). Für eine echte Signatur: `CODESIGN_ID="Developer ID Application: …" ./make-app.sh all` und das DMG mit `notarytool` notarisieren.

Zum Entwickeln: `swift run` (ohne App-Bundle, daher ohne Updater-Installation).

> Hinweis: `@State` wird bewusst nicht verwendet (das Makro braucht Xcode-Plugins); Zustand liegt in kleinen `ObservableObject`s.

## Release veröffentlichen

1. `VERSION` erhöhen und committen.
2. `git tag v0.1.0 && git push --tags` – der Workflow `.github/workflows/release.yml` baut beide DMGs und hängt sie ans Release.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
