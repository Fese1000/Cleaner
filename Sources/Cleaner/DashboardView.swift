import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var settings: Settings
    @Environment(\.pal) var pal

    private struct Info: Identifiable {
        let section: Section; let count: Int; let bytes: Int64; let hint: String
        var id: String { section.rawValue }
    }

    private func sum(_ l: [FileEntry]) -> Int64 { l.reduce(0) { $0 + $1.size } }

    private var infos: [Info] {
        [
            Info(section: .large, count: state.large.count, bytes: sum(state.large), hint: T("ab \(settings.largeMB) MB", "from \(settings.largeMB) MB")),
            Info(section: .stale, count: state.stale.count, bytes: sum(state.stale), hint: T("seit \(settings.staleDays) Tagen unberührt", "untouched for \(settings.staleDays) days")),
            Info(section: .downloads, count: state.downloads.count, bytes: sum(state.downloads), hint: T("Ordner Downloads", "Downloads folder")),
            Info(section: .duplicates, count: state.dups.count, bytes: state.dups.reduce(0) { $0 + $1.wasted }, hint: T("Gruppen, sparbarer Platz", "groups, recoverable space")),
            Info(section: .caches, count: state.caches.count, bytes: sum(state.caches), hint: T("Caches, Logs, Xcode, Backups", "caches, logs, Xcode, backups")),
            Info(section: .apps, count: state.apps.count, bytes: sum(state.apps), hint: T("installierte Apps", "installed apps")),
            Info(section: .trash, count: state.trash.count, bytes: sum(state.trash), hint: T("wartet aufs Leeren", "waiting to be emptied")),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: T("Übersicht", "Overview"), lead: T("Was dein Mac an Platz belegt – und was du loswerden kannst.", "What takes up space on your Mac – and what you can get rid of.")) {
                    if state.scanning {
                        Button(T("Abbrechen", "Cancel")) { state.cancelScan() }.buttonStyle(PButtonStyle())
                    } else {
                        Button(T("Neu scannen", "Rescan")) { state.startScan() }.buttonStyle(PButtonStyle(kind: .primary))
                    }
                }
                diskCard
                if state.scanning { scanCard }
                if state.permissionIssues && !state.scanning { permissionCard }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    ForEach(infos) { i in
                        Button { state.section = i.section } label: {
                            Card {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(i.section.title).font(.serif(16))
                                    Text(formatBytes(i.bytes)).font(.mono(24, .semibold)).foregroundColor(pal.acc)
                                    Text("\(i.count) · \(i.hint)").font(.system(size: 12)).foregroundColor(pal.mut)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                historyCard
            }.padding(.horizontal, 36).padding(.top, 28).padding(.bottom, 40)
        }
    }

    private var diskCard: some View {
        let used = max(0, state.diskTotal - state.diskFree)
        let frac = state.diskTotal > 0 ? Double(used) / Double(state.diskTotal) : 0
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(T("Festplatte", "Disk")).font(.serif(16))
                    Spacer()
                    Text(T("\(formatBytes(state.diskFree)) frei", "\(formatBytes(state.diskFree)) free")).font(.mono(13, .semibold)).foregroundColor(pal.ok)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(pal.paper2)
                        Rectangle().fill(frac > 0.9 ? pal.bad : pal.acc).frame(width: g.size.width * frac)
                    }.overlay(Rectangle().stroke(pal.line, lineWidth: 1))
                }.frame(height: 14)
                Text(T("\(formatBytes(used)) belegt von \(formatBytes(state.diskTotal))", "\(formatBytes(used)) used of \(formatBytes(state.diskTotal))"))
                    .font(.system(size: 12)).foregroundColor(pal.mut)
                if settings.totalFreed > 0 {
                    Text(T("Mit Cleaner bisher freigegeben: ", "Freed with Cleaner so far: ") + formatBytes(settings.totalFreed))
                        .font(.system(size: 12)).foregroundColor(pal.mut)
                }
            }
        }
    }

    private var scanCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack { ProgressView().controlSize(.small); Text(T("Scan läuft … \(state.scanCount) Dateien", "Scanning … \(state.scanCount) files")).font(.mono(13)) }
                Text(state.scanProgress).font(.mono(11)).foregroundColor(pal.mut).lineLimit(1).truncationMode(.middle)
            }
        }
    }

    private var permissionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(T("Einige Ordner waren nicht lesbar.", "Some folders could not be read.")).font(.system(size: 14, weight: .semibold)).foregroundColor(pal.warn)
                Text(T("Für vollständige Ergebnisse braucht Cleaner „Voller Festplattenzugriff“.", "For complete results Cleaner needs “Full Disk Access”.")).foregroundColor(pal.mut)
                Button(T("Systemeinstellungen öffnen", "Open System Settings")) { openFullDiskAccess() }.buttonStyle(PButtonStyle())
            }
        }
    }

    private var historyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(T("Verlauf", "History")).font(.serif(16))
                if settings.history.isEmpty {
                    Text(T("Noch nichts gelöscht.", "Nothing deleted yet.")).foregroundColor(pal.mut)
                } else {
                    ForEach(settings.history.prefix(8)) { h in
                        HStack {
                            Text(h.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundColor(pal.mut).frame(width: 150, alignment: .leading)
                            Text(h.count > 1 ? "\(h.sample) +\(h.count - 1)" : h.sample).font(.mono(12)).lineLimit(1)
                            Spacer()
                            Chip(text: h.permanent ? T("gelöscht", "deleted") : T("Papierkorb", "Trash"))
                            Text(formatBytes(h.bytes)).font(.mono(12)).frame(width: 80, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}
