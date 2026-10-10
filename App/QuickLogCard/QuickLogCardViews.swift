import Core
import SwiftUI

/// Today: "Put Quick Log on the Lock Screen" (or, when it's there, a line
/// saying so with Remove). Picks the child first when there's more than one.
struct QuickLogCardRow: View {
    @Environment(\.palette) private var palette
    @Environment(Shell.self) private var shell
    @State private var running = QuickLogCard.isRunning

    var body: some View {
        Group {
            if running {
                HStack {
                    Text("Quick Log is on your Lock Screen.")
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: Spacing.x2)
                    Button("Remove") {
                        Task {
                            await QuickLogCard.endAll()
                            running = false
                        }
                    }
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: Size.touchTarget)
                }
            } else {
                Button {
                    shell.startingQuickLog = true
                } label: {
                    Label("Put Quick Log on the Lock Screen", systemImage: "hand.raised")
                        .font(TypeStyle.label.font)
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.ink, lineWidth: 1))
                }
                .accessibilityHint("Adds a Log button and today's or tonight's count to the Lock Screen.")
            }
        }
        .onAppear { running = QuickLogCard.isRunning }
        .onChange(of: shell.quickLogVersion) { _, _ in running = QuickLogCard.isRunning }
    }

    static var shows: Bool { QuickLogCardSettings().isEnabled }
}

/// Starts the card from the app (the Today button, the reminder, or the card
/// itself), asking which child when there's more than one.
struct QuickLogCardStarter: ViewModifier {
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell

    func body(content: Content) -> some View {
        @Bindable var shell = shell
        content
            .onChange(of: shell.startingQuickLog) { _, starting in
                guard starting else { return }
                if model.children.count > 1 {
                    shell.pickingQuickLogChild = true
                } else {
                    start(nil)
                }
            }
            .confirmationDialog("Quick Log for…", isPresented: $shell.pickingQuickLogChild, titleVisibility: .visible) {
                ForEach(model.children) { child in
                    Button(child.name) { start(child.id) }
                }
                Button("Cancel", role: .cancel) { shell.startingQuickLog = false }
            } message: {
                Text("The Lock Screen shows only how many times, never a name.")
            }
    }

    private func start(_ childID: UUID?) {
        shell.startingQuickLog = false
        Task {
            do {
                try await QuickLogCard.start(childID: childID ?? model.child?.id)
            } catch QuickLogCardError.activitiesOff {
                model.problem = "Live Activities are off for Cali Care. You can turn them on in the Settings app, under Cali Care."
            } catch QuickLogCardError.turnedOff {
                model.problem = "Quick Log is turned off in Settings."
            } catch {
                model.problem = "Couldn't add Quick Log. Please try again."
            }
            shell.quickLogVersion += 1
        }
    }
}

extension View {
    func quickLogCardStarter() -> some View { modifier(QuickLogCardStarter()) }
}

/// Last night: how many wake-ups and when, with Share. Opens from the card
/// once the night is over.
struct NightSummarySheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var night: LogPeriod?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.x5) {
                if let night {
                    let words = night.words
                    Text(words.count == 0 ? "No wake-ups logged." : words.amount)
                        .textStyle(.statement)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    if !night.itches.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.x2) {
                            ForEach(night.itches, id: \.self) { time in
                                Text(CardClock.time(time))
                                    .textStyle(.body)
                                    .foregroundStyle(palette.ink)
                            }
                        }
                    }
                    ShareLink(item: words.shareText { CardClock.time($0) }) {
                        Label("Share last night", systemImage: "square.and.arrow.up")
                            .font(TypeStyle.label.font)
                            .foregroundStyle(palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.ink, lineWidth: 1))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.margin)
            .paperBackground(.oat)
            .navigationTitle("Last night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
        .task { night = await LastNightLoader.load(child: model.child?.id) }
    }
}

/// "Share last night" in Progress: plain text, loaded when shown.
struct ShareLastNightLink: View {
    @Environment(\.palette) private var palette
    let child: UUID
    @State private var text: String?

    var body: some View {
        Group {
            if let text {
                ShareLink(item: text) {
                    Text("Share last night")
                        .textStyle(.body)
                        .foregroundStyle(palette.accent)
                        .frame(minHeight: Size.touchTarget)
                }
            }
        }
        .task(id: child) {
            text = await LastNightLoader.load(child: child)?.words.shareText { CardClock.time($0) }
        }
    }
}

enum LastNightLoader {
    static func load(child: UUID?, now: Date = .now) async -> LogPeriod? {
        guard let child, let container = try? CaliCareModelContainer.shared() else { return nil }
        let day = LogPeriod.lastNight(at: now)
        let events = (try? await LogStore(modelContainer: container).events(for: day, child: child)) ?? []
        return LogPeriod(kind: .night, day: day, events: events)
    }
}

/// Settings › Quick Log: one switch. Turning it off takes the card off the Lock Screen.
struct QuickLogCardSettingsSection: View {
    @Environment(\.palette) private var palette
    @State private var isOn = QuickLogCardSettings().isEnabled

    var body: some View {
        SettingsSection(
            "Quick Log",
            footnote: "A Log button on your Lock Screen, day or night. Your iPhone asks for Face ID before it logs. It shows only how many times, never your child's name, and lasts up to 8 hours after your last tap."
        ) {
            Toggle(isOn: $isOn) {
                SettingsLabel("Show Quick Log on the Lock Screen")
            }
            .tint(palette.accent)
            .onChange(of: isOn) { _, on in
                QuickLogCardSettings().isEnabled = on
                if !on { Task { await QuickLogCard.endAll() } }
            }
        }
    }
}
