import Core
import SwiftUI

/// A running plan (canvas "Plan v4", softer): the star (where you are and the
/// next visit), Coming up, Supplements as tiles, Skin care as one card, then
/// one row each for the rest. Everything opens its own page; nothing here
/// changes data.
struct PlanV4View: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let plan: CarePlanInfo
    let onAdd: () -> Void

    var body: some View {
        let entries = model.planEntries
        let comingUp = model.comingUp
        VStack(alignment: .leading, spacing: 0) {
            PlanStarCard(plan: plan)
                .padding(.top, Spacing.x4)

            if !comingUp.all.isEmpty {
                PlanSectionTitle("Coming up").padding(.top, Spacing.section)
                VStack(alignment: .leading, spacing: Spacing.x4) {
                    ForEach(Array(comingUp.shown.enumerated()), id: \.element.id) { index, item in
                        ComingUpLink(item: item).arrive(index: index)
                    }
                    if comingUp.hasMore {
                        NavigationLink { ComingUpScreen() } label: {
                            Text("See all \(comingUp.all.count)")
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                                .frame(minHeight: Size.touchTarget)
                                .padding(.leading, 44 + Spacing.x4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Spacing.x4)
            }

            let supplements = entries.sections.first { $0.section == .supplements }?.entries ?? []
            if !supplements.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    PlanSectionTitle("Supplements")
                    Spacer()
                    Text("\(supplements.filter(\.isActive).count) giving")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
                .padding(.top, Spacing.section)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(supplements.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink { PlanItemScreen(id: entry.id) } label: { SupplementTile(entry: entry) }
                            .buttonStyle(.pressable)
                            .arrive(index: index)
                    }
                }
                .padding(.top, Spacing.x4)
            }

            if let skin = entries.sections.first(where: { $0.section == .skin })?.entries, !skin.isEmpty {
                SkinCareCard(entries: skin, often: often(skin))
                    .padding(.top, Spacing.section)
            }

            VStack(spacing: 0) {
                ForEach(entries.sections.filter { [.baths, .food, .home, .notes].contains($0.section) }, id: \.section) { section, list in
                    NavigationLink { PlanSectionScreen(section: section) } label: {
                        QuietRow(title: section.title, detail: list.count == 1 ? "1 note" : "\(list.count) notes")
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink { VisitsScreen() } label: {
                    QuietRow(title: "Visits and journal",
                             detail: model.providerTracker.lastVisit.map { "Last visit \(PlanWords.day($0.date))" })
                }
                .buttonStyle(.plain)
                NavigationLink { PatchTestsScreen() } label: { QuietRow(title: "Patch tests", detail: nil) }
                    .buttonStyle(.plain)
                NavigationLink { ProductListView() } label: { QuietRow(title: "Products", detail: nil) }
                    .buttonStyle(.plain)
                Button(action: onAdd) { QuietRow(title: "Add a new plan", detail: nil) }
                    .buttonStyle(.plain)
            }
            .padding(.top, Spacing.x6)
        }
    }

    /// "3 to 4 times a day", said once for the card, from the steps' meta.
    private func often(_ skin: [PlanEntries.Entry]) -> String? {
        skin.lazy.compactMap { $0.meta?.components(separatedBy: " · ").last }.first { $0.contains("time") || $0.contains("once") }
    }
}

// MARK: - The star

/// "Week 2 of 12", a thin line for weeks done, and the next visit. Soft:
/// surface color, no border; nothing else on the screen is this size.
private struct PlanStarCard: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let plan: CarePlanInfo

    var body: some View {
        // The model's copy is reloaded after a change (like setting the length).
        let star = PlanStar(plan: model.activePlan ?? plan, visits: model.visits, now: .now)
        VStack(alignment: .leading, spacing: Spacing.x4) {
            HStack(alignment: .firstTextBaseline) {
                Text(star.title)
                    .textStyle(.statement)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.x3)
                NavigationLink { PlanDocumentScreen(plan: plan) } label: {
                    Text("Full plan").textStyle(.meta).fontWeight(.medium).foregroundStyle(palette.accent)
                        .frame(minHeight: Size.touchTarget)
                }
                .buttonStyle(.plain)
            }
            if let progress = star.progress {
                GeometryReader { proxy in
                    Capsule().fill(palette.hairline)
                        .overlay(alignment: .leading) {
                            Capsule().fill(palette.accent).frame(width: max(proxy.size.width * progress, progress > 0 ? 4 : 0))
                        }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
            }
            if let next = star.nextVisit {
                Text(next).textStyle(.body).foregroundStyle(palette.graphite)
            }
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.star))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Coming up

/// A dated item: month small, day in serif, one line, and the plan's reason.
private struct ComingUpLink: View {
    let item: ComingUp.Item

    var body: some View {
        if let id = item.itemID {
            NavigationLink { PlanItemScreen(id: id) } label: { ComingUpRow(item: item) }
                .buttonStyle(.plain)
        } else {
            ComingUpRow(item: item)
        }
    }
}

struct ComingUpRow: View {
    @Environment(\.palette) private var palette
    let item: ComingUp.Item

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x4) {
            VStack(spacing: 0) {
                Text(item.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                Text(item.date.formatted(.dateTime.day()))
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text).textStyle(.body).foregroundStyle(palette.ink)
                if let reason = item.reason {
                    Text(reason).textStyle(.meta).foregroundStyle(palette.graphite)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([item.date.formatted(.dateTime.month(.wide).day()), item.text, item.reason].compactMap { $0 }.joined(separator: ", "))
    }
}

/// Plan › Coming up › See all.
struct ComingUpScreen: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        PlanPage(title: "Coming up") {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                ForEach(model.comingUp.all) { ComingUpLink(item: $0) }
            }
        }
    }
}

// MARK: - Supplements

/// White tile: name, today's amount, small sun and moon for when. Not
/// started: dashed border and "Not started yet", no button.
private struct SupplementTile: View {
    @Environment(\.palette) private var palette
    let entry: PlanEntries.Entry

    var body: some View {
        let notStarted = !entry.isActive
        VStack(alignment: .leading, spacing: Spacing.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label.replacingOccurrences(of: "Give ", with: "", options: .anchored))
                    .textStyle(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(palette.ink)
                    .lineLimit(2)
                Text(notStarted ? (entry.meta ?? "Not started yet") : (entry.amount ?? "Not in plan. Refer to label."))
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if !notStarted {
                HStack(spacing: 6) {
                    ForEach(entry.times.filter(\.isOn)) { time in
                        Image(systemName: Self.symbol(time.block))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(palette.graphite)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(notStarted ? Color.clear : palette.tile, in: RoundedRectangle(cornerRadius: Corner.tile))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.tile)
                .strokeBorder(palette.hairline, style: StrokeStyle(lineWidth: 1, dash: notStarted ? [4, 3] : []))
        )
        .contentShape(RoundedRectangle(cornerRadius: Corner.tile))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([entry.label, notStarted ? entry.meta : entry.amount,
                             entry.isActive ? PlanWords.blocks(entry.times.filter(\.isOn).map(\.block)) : nil]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    static func symbol(_ block: TodoBlock) -> String {
        switch block {
        case .morning: "sun.horizon"
        case .afternoon: "sun.max"
        case .bedtime: "moon"
        }
    }
}

// MARK: - Skin care

/// One soft card: "Skin care · 3 to 4 times a day", then the steps numbered.
private struct SkinCareCard: View {
    @Environment(\.palette) private var palette
    let entries: [PlanEntries.Entry]
    let often: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                PlanSectionTitle("Skin care")
                if let often {
                    Text(often).textStyle(.meta).foregroundStyle(palette.graphite)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink { PlanItemScreen(id: entry.id) } label: {
                        HStack(spacing: Spacing.x3) {
                            Text("\(index + 1)")
                                .textStyle(.section)
                                .foregroundStyle(palette.graphite)
                                .frame(width: 20, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.label).textStyle(.body).foregroundStyle(palette.ink)
                                if !entry.isActive, let meta = entry.meta {
                                    Text(meta).textStyle(.meta).foregroundStyle(palette.graphite)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.graphite.opacity(0.7))
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .arrive(index: index)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Step \(index + 1), \(entry.label)")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.star))
    }
}

// MARK: - Rows and pages

/// A quiet row: a name, a muted count, a light chevron. No hairlines.
private struct QuietRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String?

    var body: some View {
        HStack {
            Text(title).textStyle(.body).foregroundStyle(palette.ink)
            Spacer(minLength: Spacing.x3)
            if let detail { Text(detail).textStyle(.meta).foregroundStyle(palette.graphite) }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.graphite.opacity(0.7))
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}

/// Plan › Food (or Home, Baths, Plan notes): that section's items, each to its page.
struct PlanSectionScreen: View {
    @Environment(TodayModel.self) private var model
    let section: PlanEntries.Section

    var body: some View {
        PlanPage(title: section.title) {
            VStack(spacing: 0) {
                ForEach(model.planEntries.sections.first { $0.section == section }?.entries ?? []) { entry in
                    NavigationLink { PlanItemScreen(id: entry.id) } label: {
                        PlanListRow(label: entry.label, meta: entry.meta)
                    }
                    .buttonStyle(.plain)
                }
                if section == .food {
                    NavigationLink { FoodListView() } label: {
                        PlanListRow(label: "Your food list", meta: "Safe, paused, and trying")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Section titles on Plan: serif, quieter than the star.
struct PlanSectionTitle: View {
    @Environment(\.palette) private var palette
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(.section)
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)
    }
}
