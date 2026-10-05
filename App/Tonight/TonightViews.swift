import Core
import SwiftUI

/// Today, in the evening: "Start Tonight" (or, when it's running, a line
/// saying so with End). Picks the child first when there's more than one.
struct TonightRow: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    @State private var running = Tonight.isRunning

    var body: some View {
        Group {
            if running {
                HStack {
                    Text("Tonight is on your Lock Screen.")
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: Spacing.x2)
                    Button("End") {
                        Task {
                            await Tonight.endAll()
                            running = false
                        }
                    }
                    .foregroundStyle(palette.indigo)
                    .frame(minHeight: Size.touchTarget)
                }
            } else {
                Button {
                    shell.startingTonight = true
                } label: {
                    Label("Start Tonight on the Lock Screen", systemImage: "moon")
                        .font(TypeStyle.label.font)
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.ink, lineWidth: 1))
                }
                .accessibilityHint("Puts a Log button and tonight's wake-ups on the Lock Screen.")
            }
        }
        .onAppear { running = Tonight.isRunning }
        .onChange(of: shell.tonightVersion) { _, _ in running = Tonight.isRunning }
    }

    /// From 6 PM until the 7 AM morning, when Tonight is turned on.
    static func shows(at date: Date = .now) -> Bool {
        guard TonightSettings().isEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 18 || hour < CareDay.morningHour
    }
}

/// Starts Tonight from the app (a button, the bedtime reminder, or the card's
/// "keep logging" link), asking which child when there's more than one.
struct TonightStarter: ViewModifier {
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell

    func body(content: Content) -> some View {
        @Bindable var shell = shell
        content
            .onChange(of: shell.startingTonight) { _, starting in
                guard starting else { return }
                if model.children.count > 1 {
                    shell.pickingTonightChild = true
                } else {
                    start(nil)
                }
            }
            .confirmationDialog("Start Tonight for…", isPresented: $shell.pickingTonightChild, titleVisibility: .visible) {
                ForEach(model.children) { child in
                    Button(child.name) { start(child.id) }
                }
                Button("Cancel", role: .cancel) { shell.startingTonight = false }
            } message: {
                Text("The Lock Screen shows only the number of wake-ups, never a name.")
            }
    }

    private func start(_ childID: UUID?) {
        shell.startingTonight = false
        Task {
            do {
                try await Tonight.start(childID: childID ?? model.child?.id)
            } catch TonightError.activitiesOff {
                model.problem = "Live Activities are off for Cali Care. You can turn them on in the Settings app, under Cali Care."
            } catch TonightError.turnedOff {
                model.problem = "Tonight is turned off in Settings."
            } catch {
                model.problem = "Couldn't start Tonight. Please try again."
            }
            shell.tonightVersion += 1
        }
    }
}

extension View {
    func tonightStarter() -> some View { modifier(TonightStarter()) }
}

/// Last night: how many wake-ups and when, with Share. Opens from the
/// morning Tonight card.
struct NightSummarySheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var night: TonightNight?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.x5) {
                if let night {
                    Text(night.count == 0 ? "No wake-ups logged." : (night.count == 1 ? "1 wake-up" : "\(night.count) wake-ups"))
                        .textStyle(.statement)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    if !night.wakeUps.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.x2) {
                            ForEach(night.wakeUps, id: \.self) { time in
                                Text(TonightClock.time(time))
                                    .textStyle(.body)
                                    .foregroundStyle(palette.ink)
                            }
                        }
                    }
                    ShareLink(item: night.words.shareText { TonightClock.time($0) }) {
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
        .tint(palette.indigo)
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
                        .foregroundStyle(palette.indigo)
                        .frame(minHeight: Size.touchTarget)
                }
            }
        }
        .task(id: child) {
            text = await LastNightLoader.load(child: child)?.words.shareText { TonightClock.time($0) }
        }
    }
}

enum LastNightLoader {
    static func load(child: UUID?, now: Date = .now) async -> TonightNight? {
        guard let child, let container = try? CaliCareModelContainer.shared() else { return nil }
        let day = TonightNight.lastNight(at: now)
        let events = (try? await LogStore(modelContainer: container).events(for: day, child: child)) ?? []
        return TonightNight(day: day, events: events)
    }
}
