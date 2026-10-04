import Core
import SwiftUI

/// Today (Today v2 on the canvas). By day: one big statement about last night,
/// the week in skin colors, and the four skin bands. At night: how many
/// wake-ups so far tonight; Itchy is the biggest thing on screen (the dock).
struct TodayView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    @State private var changingSkin = false
    @State private var showingLogs = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Today", why: why)
                    if model.child != nil {
                        content
                    } else if model.hasLoaded {
                        noChild
                    }
                }
                .padding(.bottom, Spacing.x5)
            }
            .paperBackground()
            .refreshable { await model.load() }
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingLogs, onDismiss: reload) {
                TodayLogsSheet(isNight: palette.isNight)
                    .nightAwarePalette()
            }
        }
    }

    private var name: String { model.child?.name ?? "your child" }

    private var why: String? {
        guard model.child != nil else { return nil }
        return palette.isNight ? "Tap Itchy when \(name) wakes up." : "Tap how \(name)’s skin is doing."
    }

    @ViewBuilder
    private var content: some View {
        let night = palette.isNight
        let statement = TodayStatement(
            isNight: night,
            hasEverLogged: model.hasEverLogged,
            report: model.lastNight,
            wakeUpTimes: wakeUpTimes
        )
        BigStatement(text: statement.text, line: statement.line)
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x6)

        if !night {
            if model.hasEverLogged, !model.week.isEmpty {
                WeekStrip(days: model.week)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x6)
            }
            skinSection
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x6)
        }

        if !model.entries.isEmpty {
            Button { showingLogs = true } label: {
                HStack(spacing: Spacing.x2) {
                    Text(night ? "Tonight’s logs" : "Today’s logs")
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: 0)
                    Text("\(model.entries.count)")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(palette.graphite)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 56)
                .contentShape(Rectangle())
                .overlay(alignment: .top) { palette.hairline.frame(height: Rule.width) }
                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
            }
            .buttonStyle(.plain)
            .accessibilityHint("See, change, or delete what you logged.")
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x6)
        }
    }

    /// "How is Cal's skin today?" with the four bands, or the one band with Change.
    @ViewBuilder
    private var skinSection: some View {
        let skin = model.skin
        let answered = skin != nil && !changingSkin
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text(answered ? "\(name)’s skin today" : "How is \(name)’s skin today?")
                .textStyle(.title)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if answered, let skin {
                AnsweredBand(answer: skin) { changingSkin = true }
            } else {
                SkinBands(selected: skin) { answer in
                    changingSkin = false
                    Task { await model.log(.skinToday, value: .skin(answer)) }
                }
            }
        }
    }

    /// Itchy wake-up times for the statement: last night by day, tonight at night.
    private var wakeUpTimes: [String] {
        model.entries
            .filter { $0.type == .itchEpisode && CareDay.containing($0.timestamp).nightInterval().contains($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
            .map { model.time($0.timestamp) }
    }

    private var noChild: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("Add your child to start.")
                .textStyle(.body)
                .foregroundStyle(palette.ink)
            Button("Add a child") { shell.showingAddChild = true }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x6)
    }

    private func reload() {
        Task { await model.load() }
    }
}

/// The words for Today's big statement and its one line.
struct TodayStatement {
    let text: String
    let line: String?

    init(isNight: Bool, hasEverLogged: Bool, report: LastNightReport?, wakeUpTimes: [String]) {
        let count = wakeUpTimes.count
        let times = Self.list(wakeUpTimes)
        if isNight {
            if count == 0 {
                text = "Nothing logged tonight."
                line = "Each tap of Itchy shows up here."
            } else {
                text = count == 1 ? "1 wake-up tonight." : "\(count) wake-ups tonight."
                line = "At \(times)."
            }
            return
        }
        guard hasEverLogged else {
            text = "Start with one tap."
            line = "One tap a day is all it takes."
            return
        }
        let wakeUps = max(report?.itchyWakeUps ?? 0, count)
        switch report?.rating {
        case .good?: text = "Last night was good."
        case .okay?: text = "Last night was okay."
        case .rough?: text = "Last night was rough."
        case nil: text = wakeUps == 0 ? "Last night was quiet." : (wakeUps == 1 ? "1 wake-up last night." : "\(wakeUps) wake-ups last night.")
        }
        switch wakeUps {
        case 0: line = "No itchy wake-ups logged."
        case 1: line = count == 1 ? "Woke up once, at \(times)." : "Woke up once."
        default: line = count == wakeUps && count <= 3 ? "Woke up \(wakeUps) times, at \(times)." : "Woke up \(wakeUps) times."
        }
    }

    /// "2:14 AM", "1:10 AM and 3:20 AM", "11:40 PM, 1:52 AM, and 2:14 AM".
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }
}

/// The skin scale as the answer: four full-width bands in their own colors.
/// The picked one gets a check and a 2pt ink outline just outside it.
struct SkinBands: View {
    @Environment(\.palette) private var palette
    let selected: SkinToday?
    let onAnswer: (SkinToday) -> Void

    var body: some View {
        let all = SkinToday.allCases
        VStack(spacing: 0) {
            ForEach(Array(all.enumerated()), id: \.element) { index, answer in
                let isSelected = answer == selected
                let shape = UnevenRoundedRectangle(
                    topLeadingRadius: index == 0 ? Corner.control : 0,
                    bottomLeadingRadius: index == all.count - 1 ? Corner.control : 0,
                    bottomTrailingRadius: index == all.count - 1 ? Corner.control : 0,
                    topTrailingRadius: index == 0 ? Corner.control : 0
                )
                Button { onAnswer(answer) } label: {
                    HStack {
                        Text(answer.title)
                            .textStyle(.band)
                            .fontWeight(isSelected ? .semibold : .medium)
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark").font(.title3.weight(.bold))
                        }
                    }
                    .foregroundStyle(palette.text(onSkin: answer))
                    .padding(.horizontal, Spacing.x5)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(palette.color(for: answer), in: shape)
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Corner.control + 2)
                            .stroke(palette.ink, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .zIndex(isSelected ? 1 : 0)
                .accessibilityLabel(answer.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Corner.control).strokeBorder(palette.graphite, lineWidth: 1))
    }
}

/// After answering: one band with the answer and "Change".
struct AnsweredBand: View {
    @Environment(\.palette) private var palette
    let answer: SkinToday
    let onChange: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Corner.control)
        HStack(spacing: Spacing.x2) {
            Image(systemName: "checkmark").font(.body.weight(.bold)).accessibilityHidden(true)
            Text(answer.title).textStyle(.band).fontWeight(.semibold)
            Spacer(minLength: 0)
            Button("Change", action: onChange)
                .font(.body)
                .underline()
                .frame(minWidth: Size.touchTarget, minHeight: Size.touchTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("Change skin answer")
        }
        .foregroundStyle(palette.text(onSkin: answer))
        .padding(.leading, Spacing.x5)
        .padding(.trailing, Spacing.x2)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(palette.color(for: answer), in: shape)
        .overlay(shape.strokeBorder(palette.graphite, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

/// A mark on the one skin scale, with its 1pt muted border (DESIGN.md §3).
struct SkinSwatch: View {
    @Environment(\.palette) private var palette
    let answer: SkinToday
    var size: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(palette.color(for: answer))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(palette.graphite, lineWidth: 1))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
