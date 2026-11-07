import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var state: AppState
    @Environment(\.pal) var pal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: T("Einstellungen", "Settings"), lead: T("Sprache, Farbschema, Schwellwerte, Ordner und Updates.", "Language, color scheme, thresholds, folders and updates."))

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(T("Darstellung", "Appearance")).font(.serif(16))
                        row(T("Sprache", "Language")) {
                            Picker("", selection: $settings.lang) { ForEach(Lang.allCases) { Text($0.label).tag($0) } }.labelsHidden().frame(width: 200)
                        }
                        row(T("Farbschema", "Color scheme")) {
                            Picker("", selection: $settings.themeID) { ForEach(Theme.all) { Text($0.name).tag($0.id) } }.labelsHidden().frame(width: 240)
                        }
                        HStack(spacing: 0) {
                            ForEach([settings.palette(system: .light).paper, settings.palette(system: .light).card, settings.palette(system: .light).acc, settings.palette(system: .light).side, settings.palette(system: .light).ok, settings.palette(system: .light).bad], id: \.self) { c in
                                Rectangle().fill(c).frame(width: 36, height: 18)
                            }
                        }.overlay(Rectangle().stroke(pal.line, lineWidth: 1))
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(T("Schwellwerte", "Thresholds")).font(.serif(16))
                        row(T("„Veraltet“ nach (Tagen)", "“Outdated” after (days)")) { Stepper(value: $settings.staleDays, in: 30...3650, step: 30) { Text("\(settings.staleDays)").font(.mono(13)) } }
                        row(T("Große Dateien ab (MB)", "Large files from (MB)")) { Stepper(value: $settings.largeMB, in: 10...10000, step: 50) { Text("\(settings.largeMB)").font(.mono(13)) } }
                        row(T("Duplikate ab (MB)", "Duplicates from (MB)")) { Stepper(value: $settings.dupMinMB, in: 1...1000, step: 1) { Text("\(settings.dupMinMB)").font(.mono(13)) } }
                        Text(T("Änderungen gelten ab dem nächsten Scan.", "Changes apply from the next scan.")).font(.system(size: 12)).foregroundColor(pal.mut)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(T("Gescannte Ordner", "Scanned folders")).font(.serif(16))
                            Spacer()
                            Button(T("Ordner hinzufügen …", "Add folder …")) { addFolder() }.buttonStyle(PButtonStyle())
                            Button(T("Zurücksetzen", "Reset")) { settings.roots = Settings.defaultRoots() }.buttonStyle(PButtonStyle())
                        }
                        ForEach(settings.roots, id: \.self) { p in
                            HStack {
                                Text((p as NSString).abbreviatingWithTildeInPath).font(.mono(12))
                                Spacer()
                                Button { settings.roots.removeAll { $0 == p } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundColor(pal.mut)
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(T("Ignorierte Pfade", "Ignored paths")).font(.serif(16))
                        if settings.ignored.isEmpty {
                            Text(T("Nichts ignoriert. Rechtsklick auf eine Zeile → „Ignorieren“.", "Nothing ignored. Right-click a row → “Ignore”.")).foregroundColor(pal.mut)
                        }
                        ForEach(settings.ignored, id: \.self) { p in
                            HStack {
                                Text((p as NSString).abbreviatingWithTildeInPath).font(.mono(12))
                                Spacer()
                                Button { settings.ignored.removeAll { $0 == p } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundColor(pal.mut)
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(T("Berechtigungen", "Permissions")).font(.serif(16))
                        Text(T("Für Papierkorb, Mail-Downloads und geschützte Ordner braucht Cleaner „Voller Festplattenzugriff“.", "Trash, Mail downloads and protected folders need “Full Disk Access”.")).foregroundColor(pal.mut)
                        Button(T("Systemeinstellungen öffnen", "Open System Settings")) { openFullDiskAccess() }.buttonStyle(PButtonStyle())
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(T("Updates", "Updates")).font(.serif(16))
                        Text(T("Version ", "Version ") + Updater.current).font(.mono(13))
                        Toggle(T("Beim Start nach Updates suchen", "Check for updates on launch"), isOn: $settings.autoCheckUpdates).toggleStyle(.checkbox)
                        HStack(spacing: 10) {
                            Button(T("Nach Updates suchen", "Check for updates")) { updater.check() }.buttonStyle(PButtonStyle())
                            if case .available(let v) = updater.phase {
                                Button(T("Version \(v) installieren", "Install version \(v)")) { updater.install() }.buttonStyle(PButtonStyle(kind: .primary))
                            }
                        }
                        statusText
                        Text(T("Es wird nur eine Anfrage an GitHub gesendet. Das Update wird per Prüfsumme und Code-Signatur verifiziert.", "Only a request to GitHub is sent. The update is verified by checksum and code signature.")).font(.system(size: 12)).foregroundColor(pal.mut)
                    }
                }
            }.padding(.horizontal, 36).padding(.top, 28).padding(.bottom, 40)
        }
    }

    @ViewBuilder private var statusText: some View {
        switch updater.phase {
        case .idle: EmptyView()
        case .checking: Text(T("Suche …", "Checking …")).foregroundColor(pal.mut)
        case .upToDate: Text(T("Cleaner ist aktuell.", "Cleaner is up to date.")).foregroundColor(pal.ok)
        case .available(let v): Text(T("Neue Version \(v) verfügbar.", "New version \(v) available.")).foregroundColor(pal.acc)
        case .downloading(let p): HStack { ProgressView(value: p).frame(width: 200); Text("\(Int(p * 100)) %").font(.mono(12)) }
        case .installing: Text(T("Installiere … die App startet gleich neu.", "Installing … the app restarts shortly.")).foregroundColor(pal.mut)
        case .error(let m): Text(m).foregroundColor(pal.bad)
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack { Text(label).frame(width: 220, alignment: .leading); c(); Spacer() }
    }

    private func addFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = true
        if p.runModal() == .OK {
            for u in p.urls where !settings.roots.contains(u.path) { settings.roots.append(u.path) }
        }
    }
}
