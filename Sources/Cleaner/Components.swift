import SwiftUI

struct PButtonStyle: ButtonStyle {
    enum Kind { case normal, primary, danger }
    var kind: Kind = .normal
    func makeBody(configuration: Configuration) -> some View { PButtonBody(configuration: configuration, kind: kind) }

    struct PButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let kind: Kind
        @Environment(\.pal) var pal
        @Environment(\.isEnabled) var enabled
        var body: some View {
            let bg: Color = kind == .primary ? pal.acc : (kind == .danger ? pal.bad : pal.card)
            let fg: Color = kind == .primary ? pal.accfg : (kind == .danger ? Color.white : pal.ink)
            let border: Color = kind == .normal ? pal.line : Color.clear
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundColor(fg)
                .background(bg)
                .overlay(Rectangle().stroke(border, lineWidth: 1))
                .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
                .contentShape(Rectangle())
        }
    }
}

struct PageHeader<Trailing: View>: View {
    @Environment(\.pal) var pal
    let title: String
    let lead: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.serif(28)).foregroundColor(pal.ink)
                Text(lead).foregroundColor(pal.mut).font(.system(size: 14))
            }
            Spacer()
            trailing
        }
    }
}
extension PageHeader where Trailing == EmptyView {
    init(title: String, lead: String) { self.title = title; self.lead = lead; self.trailing = EmptyView() }
}

struct Line: View {
    @Environment(\.pal) var pal
    var body: some View { Rectangle().fill(pal.line).frame(height: 1) }
}

struct Chip: View {
    @Environment(\.pal) var pal
    let text: String
    var active = false
    var body: some View {
        Text(text).font(.mono(11))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundColor(active ? pal.accfg : pal.mut)
            .background(active ? pal.acc : pal.paper2)
            .overlay(Rectangle().stroke(pal.line, lineWidth: 1))
    }
}

struct Check: View {
    @Environment(\.pal) var pal
    let on: Bool
    var locked = false
    var body: some View {
        Image(systemName: locked ? "lock.fill" : (on ? "checkmark.square.fill" : "square"))
            .font(.system(size: 15))
            .foregroundColor(locked ? pal.mut : (on ? pal.acc : pal.mut))
            .frame(width: 22)
    }
}

struct PField: View {
    @Environment(\.pal) var pal
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(pal.card)
            .overlay(Rectangle().stroke(pal.line, lineWidth: 1))
            .frame(maxWidth: 260)
    }
}

struct Card<Content: View>: View {
    @Environment(\.pal) var pal
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(pal.card).overlay(Rectangle().stroke(pal.line, lineWidth: 1))
    }
}

struct Toast: View {
    @Environment(\.pal) var pal
    let text: String
    var body: some View {
        Text(text).font(.system(size: 13)).foregroundColor(pal.accfg)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(pal.ink.opacity(0.92))
            .foregroundColor(pal.paper)
    }
}

/// Ersatz für @State (das Makro braucht Xcode-Plugins; so baut die App auch nur mit den Command Line Tools).
final class ListUI: ObservableObject {
    @Published var sortKey: SortKey = .size
    @Published var ascending = false
    @Published var query = ""
    @Published var tag: String? = nil
}

final class UninstallUI: ObservableObject {
    @Published var leftovers: [FileEntry] = []
    @Published var picked = Set<URL>()
    @Published var loading = true
}
