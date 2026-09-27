import Core
import SwiftUI

/// The child's day at a glance: last night, one-tap logging, today's timeline, and the week.
struct TodayView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    @State private var editing: LogEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: Spacing.titleToLede) {
                        TodayHeader()
                        if model.child != nil, let report = model.lastNight {
                            LastNightLede(report: report)
                        }
                    }
                    .padding(.horizontal, Spacing.margin)

                    if model.child != nil {
                        VStack(alignment: .leading, spacing: Spacing.section) {
                            LogButtons(isDaytime: model.isDaytime, entries: model.entries, lastNight: model.lastNight) { type, value in
                                Task { await model.log(type, value: value) }
                            }
                            TodayTimeline(model: model, isDaytime: model.isDaytime) { editing = $0 }
                            Button { shell.tab = .progress } label: {
                                WeekStrip(days: model.week)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens Progress.")
                        }
                        .padding(.top, Spacing.ledeToSection)
                    } else if model.hasLoaded {
                        noChild
                            .padding(.top, Spacing.ledeToSection)
                    }
                }
                .padding(.bottom, Spacing.section)
            }
            .paperBackground()
            .refreshable { await model.load() }
            .logConfirmation(on: .today)
            .shellToolbar(showsSwitcher: false)
            .sheet(item: $editing, onDismiss: reload) { entry in
                EditLogSheet(entry: entry, model: model)
                    .presentationDetents([.medium, .large])
                    .nightAwarePalette()
            }
        }
    }

    private var noChild: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("Add your child to start logging.")
                .textStyle(.body)
                .foregroundStyle(palette.ink)
            Button("Add a child") { shell.showingAddChild = true }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.margin)
    }

    private func reload() {
        Task { await model.load() }
    }
}

#Preview("Day") {
    TodayView()
        .environment(TodayModel())
        .environment(Shell())
        .environment(\.palette, .day)
        .onAppear { FontRegistry.registerAll() }
}

#Preview("Night") {
    TodayView()
        .environment(TodayModel())
        .environment(Shell())
        .environment(\.palette, .night)
        .onAppear { FontRegistry.registerAll() }
}
