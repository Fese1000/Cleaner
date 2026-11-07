import SwiftUI

struct ThemedRoot: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let pal = settings.palette(system: scheme)
        RootView()
            .environment(\.pal, pal)
            .foregroundColor(pal.ink)
            .background(pal.paper)
            .preferredColorScheme(settings.forcedScheme)
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var updater: Updater
    @Environment(\.pal) var pal

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ZStack(alignment: .bottom) {
                pal.paper
                content
                if let t = state.toast { Toast(text: t).padding(.bottom, 70).transition(.opacity) }
                if state.busy { ProgressView().controlSize(.small).padding(10).background(pal.card).padding(.bottom, 24) }
            }
        }
        .animation(.easeOut(duration: 0.15), value: state.toast)
        .alert(alertTitle, isPresented: Binding(get: { state.confirm != nil }, set: { if !$0 { state.confirm = nil } }), presenting: state.confirm) { req in
            Button(req.permanent ? T("Endgültig löschen", "Delete permanently") : T("In den Papierkorb", "Move to Trash"), role: req.permanent ? .destructive : nil) {
                state.performDelete(req)
            }
            Button(T("Abbrechen", "Cancel"), role: .cancel) {}
        } message: { req in
            Text(alertMessage(req))
        }
        .sheet(item: $state.uninstallTarget) { app in
            UninstallSheet(app: app).environmentObject(state).environment(\.pal, pal)
        }
        .onAppear {
            state.startScan()
            if settings.autoCheckUpdates { updater.check() }
        }
    }

    private var alertTitle: String {
        guard let r = state.confirm else { return "" }
        return r.permanent ? T("\(r.entries.count) Element(e) endgültig löschen?", "Delete \(r.entries.count) item(s) permanently?")
                           : T("\(r.entries.count) Element(e) in den Papierkorb?", "Move \(r.entries.count) item(s) to Trash?")
    }

    private func alertMessage(_ r: DeleteRequest) -> String {
        var s = formatBytes(r.totalSize) + ". "
        s += r.permanent ? T("Das lässt sich nicht rückgängig machen.", "This cannot be undone.")
                         : T("Du kannst sie aus dem Papierkorb zurücklegen.", "You can put them back from the Trash.")
        if let w = r.warning { s += "\n\n⚠️ " + w }
        return s
    }

    @ViewBuilder private var content: some View {
        switch state.section {
        case .overview: DashboardView()
        case .large: LargeView()
        case .stale: StaleView()
        case .downloads: DownloadsView()
        case .duplicates: DuplicatesView()
        case .caches: CachesView()
        case .apps: AppsView()
        case .explorer: ExplorerView()
        case .trash: TrashView()
        case .settings: SettingsView()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("🧹").font(.system(size: 24))
                (Text("Clean").foregroundColor(pal.sidefg) + Text("er").foregroundColor(pal.acc))
                    .font(.mono(19, .semibold))
            }
            .padding(.horizontal, 20).padding(.top, 38).padding(.bottom, 18)
            Rectangle().fill(pal.sidehover).frame(height: 1).padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Section.nav) { s in navButton(s) }
                }
            }
            Rectangle().fill(pal.sidehover).frame(height: 1)
            HStack {
                footButton("gearshape", T("Einstellungen", "Settings"), active: state.section == .settings) { state.section = .settings }
                    .keyboardShortcut(",", modifiers: .command)
                footButton("arrow.clockwise", T("Neu scannen", "Rescan"), active: false) { state.startScan() }
                footButton("power", T("Beenden", "Quit"), active: false) { NSApp.terminate(nil) }
            }.padding(.vertical, 8).padding(.horizontal, 14)
        }
        .frame(width: 220).frame(maxHeight: .infinity)
        .background(pal.side)
    }

    private func navButton(_ s: Section) -> some View {
        let on = state.section == s
        return Button { state.section = s } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(s.title).fontWeight(on ? .semibold : .regular)
                Spacer()
                if let b = state.badge(s) { Text(b).font(.mono(11)).foregroundColor(pal.acc) }
            }
            .font(.system(size: 14))
            .foregroundColor(on ? pal.sidefg : pal.sidemut)
            .padding(.vertical, 8).padding(.leading, 17).padding(.trailing, 20)
            .frame(maxWidth: .infinity)
            .background(on ? pal.sidehover : Color.clear)
            .overlay(alignment: .leading) { Rectangle().fill(on ? pal.acc : Color.clear).frame(width: 3) }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func footButton(_ icon: String, _ help: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).foregroundColor(active ? pal.acc : pal.sidemut).frame(width: 40, height: 34)
        }.buttonStyle(.plain).help(help).frame(maxWidth: .infinity)
    }
}
