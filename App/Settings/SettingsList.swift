import Core
import SwiftUI

/// A Settings group: a native List section on paper, with the header in section
/// style (sentence case, graphite) and an optional footnote in meta.
struct SettingsSection<Content: View>: View {
    @Environment(\.palette) private var palette
    private let title: String
    private let footnote: String?
    private let content: Content

    init(_ title: String, footnote: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footnote = footnote
        self.content = content()
    }

    var body: some View {
        Section {
            content
                .listRowBackground(palette.paper)
                .listRowInsets(settingsRowInsets)
        } header: {
            Text(title)
                .textStyle(.section)
                .foregroundStyle(palette.graphite)
                .textCase(nil)
                .accessibilityAddTraits(.isHeader)
                .listRowInsets(settingsRowInsets)
        } footer: {
            if let footnote {
                Text(footnote)
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .listRowInsets(settingsRowInsets)
            }
        }
    }
}

/// The screen margin, same as every ledger.
private let settingsRowInsets = EdgeInsets(top: 0, leading: Spacing.margin, bottom: 0, trailing: Spacing.margin)

/// A row's label in row style and ink.
struct SettingsLabel: View {
    @Environment(\.palette) private var palette
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .textStyle(.control)
            .foregroundStyle(palette.ink)
    }
}

extension View {
    /// Paper instead of the grouped gray, hairline separators, ledger row heights.
    func settingsListStyle(_ palette: Palette) -> some View {
        listStyle(.grouped)
            .scrollContentBackground(.hidden)
            .listRowSeparatorTint(palette.hairline)
            .listSectionSeparator(.hidden)
            .listSectionSpacing(Spacing.section)
            .environment(\.defaultMinListRowHeight, Size.row(isNight: palette.isNight))
            .paperBackground()
    }
}

/// A setup guide on its own page, pushed from Settings → Widgets and Siri.
struct GuidePage<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(.vertical, Spacing.x4)
        }
        .paperBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
