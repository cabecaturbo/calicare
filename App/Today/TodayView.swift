import Core
import SwiftUI

/// Today (UX.md §4). By day: the skin question until it's answered, then last
/// night, then today's logs. At night: tonight so far, a big Itchy, tonight's logs.
struct TodayView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    @State private var editing: LogEntry?
    @State private var changingSkin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(
                        title: "Today",
                        caption: palette.isNight ? nil : Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
                    )
                    if model.child != nil {
                        content
                    } else if model.hasLoaded {
                        noChild
                    }
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .refreshable { await model.load() }
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing, onDismiss: reload) { entry in
                EditLogSheet(entry: entry, model: model)
                    .presentationDetents([.medium, .large])
                    .nightAwarePalette()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let night = palette.isNight
        let skin = model.skin
        let asksSkin = !night && (changingSkin || TodayPrompts.asksSkin(at: .now, answered: skin != nil))
        let name = model.child?.name ?? "your child"

        if let hint = TodayPrompts.firstRunHint(hasEverLogged: model.hasEverLogged, isNight: night, asksSkin: asksSkin, childName: name) {
            Text(hint)
                .textStyle(.body)
                .foregroundStyle(palette.accent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
        }

        if asksSkin {
            SkinCheckIn(childName: model.child?.name ?? "their", selected: skin) { answer in
                changingSkin = false
                Task { await model.log(.skinToday, value: .skin(answer)) }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x7)
        }

        summary
            .padding(.horizontal, Spacing.margin)
            .padding(.top, asksSkin ? Spacing.x7 : Spacing.x5)

        if QuickLogCardRow.shows {
            QuickLogCardRow()
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
        }

        if !night, model.isDaytime, let report = model.lastNight, report.rating == nil, !report.isTonight {
            NightRatingChoices { rating in
                Task { await model.log(.nightRating, value: .night(rating)) }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x4)
        }

        if !night, let skin, !changingSkin {
            HStack {
                HStack(spacing: Spacing.x2) {
                    SkinSwatch(answer: skin, size: 16)
                    Text("Skin today: \(skin.words)")
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                }
                Spacer()
                Button("Change") { changingSkin = true }
                    .font(.body)
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: Size.touchTarget)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x4)
        }

        if night {
            Button {
                Task { await model.log(.itchEpisode) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Log", systemImage: "hand.raised.fill").textStyle(.title)
                    if let last = model.entries.first(where: { $0.type == .itchEpisode }) {
                        Text("Last at \(model.time(last.timestamp))")
                            .textStyle(.meta)
                            .opacity(0.8)
                    }
                }
                .foregroundStyle(palette.onButton)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                .padding(.horizontal, Spacing.x5)
                .background(palette.button, in: RoundedRectangle(cornerRadius: Corner.card))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log itching")
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x4)
        }

        TodaySoFar(entries: model.entries, isNight: night) { editing = $0 }
            .padding(.top, Spacing.x7)
    }

    /// "Last night: A good night" by day; "So far tonight: Two wake-ups" at night.
    private var summary: some View {
        let report = model.lastNight
        let wakeUps = report?.itchyWakeUps ?? 0
        let times = model.entries
            .filter { $0.type == .itchEpisode && CareDay.containing($0.timestamp).nightInterval().contains($0.timestamp) }
            .map { model.time($0.timestamp) }
        if palette.isNight {
            return SummaryCard(
                eyebrow: "So far tonight",
                title: wakeUps == 0 ? "A quiet night" : "\(wakeUps) wake-up\(wakeUps == 1 ? "" : "s")",
                caption: times.isEmpty ? nil : times.reversed().joined(separator: " and "),
                art: .moon
            )
        }
        let title = switch report?.rating {
        case .good?: "A good night"
        case .okay?: "An okay night"
        case .rough?: "A rough night"
        case nil: wakeUps > 0 ? "Not rated yet" : "Nothing logged"
        }
        let caption: String? = wakeUps == 0
            ? (report?.rating == nil ? nil : "No itchy wake-ups.")
            : "\(wakeUps == 1 ? "One itchy wake-up" : "\(wakeUps) itchy wake-ups")\(times.isEmpty ? "" : ", at \(times.reversed().joined(separator: " and "))")"
        return SummaryCard(eyebrow: "Last night", title: title, caption: caption, art: .sun)
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
        .padding(.top, Spacing.x7)
    }

    private func reload() {
        Task { await model.load() }
    }
}

/// "How was Cal's skin today?": four card buttons (DESIGN.md §5). The primary
/// element on Today until it's answered.
struct SkinCheckIn: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let childName: String
    let selected: SkinToday?
    let onAnswer: (SkinToday) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text("How was \(childName)’s skin today?")
                .textStyle(.title)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("One tap. You can change it later.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
            // One column at accessibility sizes, so the answers never cut off.
            let columns = typeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible(), spacing: Spacing.x2), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: Spacing.x2) {
                ForEach(SkinToday.allCases, id: \.self) { answer in
                    let isSelected = answer == selected
                    Button { onAnswer(answer) } label: {
                        HStack(spacing: Spacing.x4) {
                            SkinSwatch(answer: answer, size: 24)
                            Text(answer.title)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.x4)
                        .frame(minHeight: 64)
                        .background(isSelected ? palette.oat : palette.paper, in: RoundedRectangle(cornerRadius: Corner.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Corner.card)
                                .strokeBorder(isSelected ? palette.accent : palette.hairline, lineWidth: isSelected ? 2 : 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.paper)
                                    .frame(width: 22, height: 22)
                                    .background(palette.accent, in: Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(answer.title)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.top, Spacing.x4)
        }
    }
}

/// Good / Okay / Rough under the Last night card while last night isn't rated.
/// Same cards as the skin check-in; one tap logs it.
struct NightRatingChoices: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let onRate: (NightRating) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("How was the night?")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Spacing.x2))
                : AnyLayout(HStackLayout(spacing: Spacing.x2))
            layout {
                ForEach(NightRating.allCases, id: \.self) { rating in
                    Button { onRate(rating) } label: {
                        Text(rating.title)
                            .textStyle(.body)
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(palette.paper, in: RoundedRectangle(cornerRadius: Corner.card))
                            .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Last night was \(rating.title.lowercased())")
                }
            }
        }
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

/// Today's (or tonight's) logs, newest first, with 0.5pt dividers. Tap to
/// edit; swipe left to delete (Undo in the Logged line).
private struct TodaySoFar: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let entries: [LogEntry]
    let isNight: Bool
    let onEdit: (LogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack {
                Text(isNight ? "Tonight so far" : "Today so far")
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                // Flare, bowel movement, mood, note: the round Log button in the bar is itching only.
                MoreLogMenu {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: Size.touchTarget, height: Size.touchTarget)
                        .background(palette.oat, in: Circle())
                        .contentShape(Circle())
                }
            }
            .padding(.horizontal, Spacing.margin)
            if entries.isEmpty {
                Text(isNight ? "Nothing logged yet tonight." : "Nothing logged yet today. Tap Log whenever it itches.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .padding(.horizontal, Spacing.margin)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        SwipeToDelete { Task { await model.deleteWithUndo(entry) } } content: {
                        Button { onEdit(entry) } label: {
                            HStack {
                                Text(model.title(for: entry))
                                    .textStyle(.body)
                                    .foregroundStyle(palette.ink)
                                Spacer()
                                Text([model.time(entry.timestamp), model.byline(for: entry)].compactMap { $0 }.joined(separator: " · "))
                                    .textStyle(.meta)
                                    .foregroundStyle(palette.graphite)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit, or swipe left to delete")
                        }
                    }
                }
                .padding(.horizontal, Spacing.margin)
            }
        }
    }
}
