import Foundation

/// The one-page report a parent brings to a visit: skin by week, how the plan
/// is going, notes and questions. Pure once built: counts and plain words,
/// never a cause or a recommendation.
public struct VisitReport: Equatable, Sendable {
    /// One week row: seven days of skin, wake-ups and good nights.
    public struct Week: Equatable, Sendable {
        public let startLabel: String
        /// Seven days; nil skin means not logged. `inRange` is false for days
        /// past the report's last day (the last row can be short).
        public let skin: [SkinToday?]
        public let inRange: [Bool]
        public let itchyWakeUps: Int
        public let goodNights: Int
        public let nights: Int
        /// The plan started during this week: a ruled line above it.
        public let planStarts: Bool
    }

    /// One active step or supplement, how often, and how it's gone since the plan started.
    public struct PlanLine: Equatable, Sendable {
        public let name: String
        public let often: String?
        public let done: String

        public init(name: String, often: String?, done: String) {
            self.name = name
            self.often = often
            self.done = done
        }
    }

    public struct Note: Equatable, Sendable {
        public let date: String
        public let text: String
        public let skin: SkinToday?
    }

    public let child: ChildInfo
    /// "For Dr. Rivera · visit Oct 30", or nil with neither.
    public let header: String?
    /// "Cal's skin, Sep 14 – Oct 11"
    public let title: String
    /// "Age 3 · 4 weeks, logged by Matt"
    public let subtitle: String
    public let summary: String
    public let weeks: [Week]
    public let following: [PlanLine]
    public let notStarted: [String]
    public let notes: [Note]
    public let questions: String?
    /// "Logged by Cal's parent in Cali Care. Not medical advice."
    public let footer: String
    public let fileName: String

    /// Past this many weeks, the report continues onto a second page.
    public static let weeksOnFirstPage = 6
    /// Notes shown, newest first.
    public static let maxNotes = 6
}

extension VisitReport {
    public init(
        child: ChildInfo,
        range: DoctorReport.Range,
        events: [LogEntry],
        plan: CarePlanInfo? = nil,
        items: [PlanItemInfo] = [],
        steps: [RoutineStepInfo] = [],
        visits: [VisitInfo] = [],
        parentName: String? = nil,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        let short = Self.formatter("MMM d", calendar: calendar, locale: locale)
        let mine = events.filter { $0.childID == child.id }.sorted { $0.timestamp < $1.timestamp }
        let days = range.days(calendar: calendar)
        let summaries = Dictionary(uniqueKeysWithValues: days.map { ($0, DaySummary(day: $0, events: mine, calendar: calendar)) })
        let planStart = plan?.startedAt.map { CareDay.containing($0, calendar: calendar) }
        let next = visits.filter { $0.date > now }.min { $0.date < $1.date }

        self.child = child

        // Header: who the report is for and when.
        let provider = (next?.provider.isEmpty == false ? next?.provider : nil) ?? (plan?.provider.isEmpty == false ? plan?.provider : nil)
        var parts: [String] = []
        if let provider { parts.append("For " + Self.doctor(provider)) }
        if let next { parts.append("visit " + short.string(from: next.date)) }
        header = parts.isEmpty ? nil : parts.joined(separator: " · ")

        title = "\(child.name)’s skin, \(short.string(from: range.first.noon(calendar: calendar))) – \(short.string(from: range.last.noon(calendar: calendar)))"
        let span = days.count >= 14 ? "\(Int((Double(days.count) / 7).rounded())) weeks" : "\(days.count) days"
        let age = child.birthDate.flatMap { Self.age(born: $0, now: now, calendar: calendar) }
        let by = parentName.flatMap { $0.isEmpty || $0 == "You" ? nil : $0 } ?? "a parent"
        subtitle = [age, "\(span), logged by \(by)"].compactMap { $0 }.joined(separator: " · ")

        // Weeks, from the first day of the range.
        var weeks: [Week] = []
        for start in stride(from: 0, to: days.count, by: 7) {
            let first = days[start]
            let slots = (0..<7).map { first.adding(days: $0, calendar: calendar) }
            let inRange = slots.map { $0 <= range.last }
            let logged = slots.compactMap { summaries[$0] }
            weeks.append(Week(
                startLabel: short.string(from: first.noon(calendar: calendar)),
                skin: slots.map { summaries[$0]?.skinToday },
                inRange: inRange,
                itchyWakeUps: logged.reduce(0) { $0 + $1.nightItchEpisodes },
                goodNights: logged.filter { $0.nightRating == .good }.count,
                nights: inRange.filter { $0 }.count,
                planStarts: planStart.map { start in slots.contains(start) } ?? false
            ))
        }
        self.weeks = weeks

        summary = Self.summary(days: days, summaries: summaries, planStart: planStart, range: range,
                               short: short, calendar: calendar)

        // Following the plan, since it started (or the range's start, if later).
        let since = max(planStart ?? range.first, range.first)
        let countedDays = days.filter { $0 >= since }
        let inWindow = mine.filter { entry in countedDays.contains { $0.contains(entry.timestamp, calendar: calendar) } }
        var lines: [PlanLine] = []
        let active = steps.filter(\.isActive)
        for name in Self.unique(active.map(\.displayName)) {
            let group = active.filter { $0.displayName == name }
            let ids = Set(group.map(\.id))
            let done = inWindow.filter { $0.type == .routineDone && $0.routineStepID.map(ids.contains) == true }.count
            let times = Self.unique(group.map { $0.time == .morning ? "Morning" : "Bedtime" }.sorted { $0 == "Morning" && $1 != "Morning" })
            let often = times.joined(separator: " and ")
            lines.append(PlanLine(name: name, often: often.prefix(1) + often.dropFirst().lowercased(),
                                  done: "\(done) of \(countedDays.count * group.count)"))
        }
        let supplements = items.filter { $0.kind == .supplement }
        for item in supplements where item.isGiving == true {
            let taken = inWindow.filter {
                $0.type == .supplement && $0.routineStepID == item.id && $0.value == .supplement(.taken)
            }.count
            let perDay = countedDays.isEmpty ? 0 : Double(taken) / Double(countedDays.count)
            lines.append(PlanLine(
                name: SupplementDisplay(item).name,
                often: PlanWords.timesADay(item.frequency) ?? item.frequency,
                done: taken == 0 ? "Not logged" : String(format: "%.1f× a day", perDay)
            ))
        }
        following = lines
        notStarted = supplements.filter { $0.isGiving == false }.map { SupplementDisplay($0).name }

        // Notes from home, newest first, each with that day's skin.
        notes = mine
            .filter { ($0.type == .note || $0.type == .flare) && !($0.note ?? "").isEmpty }
            .reversed()
            .prefix(Self.maxNotes)
            .map { entry in
                let day = CareDay.containing(entry.timestamp, calendar: calendar)
                return Note(date: short.string(from: day.noon(calendar: calendar)), text: entry.note ?? "",
                            skin: summaries[day]?.skinToday)
            }
        questions = next?.questions.flatMap { $0.isEmpty ? nil : $0 }
        footer = "Logged by \(child.name)’s parent in Cali Care. Not medical advice."
        fileName = "\(child.name) visit report \(short.string(from: range.last.noon(calendar: calendar)))"
    }

    /// One plain sentence from the skin answers (or the nights). Counts only.
    static func summary(days: [CareDay], summaries: [CareDay: DaySummary], planStart: CareDay?,
                        range: DoctorReport.Range, short: DateFormatter, calendar: Calendar) -> String {
        func flaringPerWeek(_ slice: [CareDay]) -> Int? {
            let answered = slice.compactMap { summaries[$0]?.skinToday }
            guard answered.count >= 3 else { return nil }
            let flaring = answered.filter { $0 == .flaring || $0 == .veryRough }.count
            return Int((Double(flaring) / Double(answered.count) * 7).rounded())
        }
        func change(_ before: Int, _ after: Int) -> String {
            before == after
                ? "flaring days held at about \(after) a week."
                : "flaring days went from \(before) a week to \(after)."
        }
        if let planStart, planStart > range.first,
           let before = flaringPerWeek(days.filter { $0 < planStart }),
           let after = flaringPerWeek(days.filter { $0 >= planStart }) {
            let date = short.string(from: planStart.noon(calendar: calendar))
            return after < before
                ? "Calmer since the plan started \(date): \(change(before, after))"
                : "Since the plan started \(date), \(change(before, after))"
        }
        if days.count >= 14, let first = flaringPerWeek(Array(days.prefix(7))), let last = flaringPerWeek(Array(days.suffix(7))) {
            return first == last
                ? "Flaring days held at about \(last) a week."
                : "Flaring days went from \(first) in the first week to \(last) in the last."
        }
        let answered = days.compactMap { summaries[$0]?.skinToday }
        if !answered.isEmpty {
            let gentle = answered.filter { $0 == .calm || $0 == .littleItchy }.count
            return "\(gentle) of \(answered.count) logged days were calm or a little itchy."
        }
        let rated = days.compactMap { summaries[$0]?.nightRating }
        if !rated.isEmpty {
            return "\(rated.filter { $0 == .good }.count) of \(rated.count) rated nights were good."
        }
        return "Not much was logged in these weeks."
    }

    /// "Dr. Rivera" stays as it is; "Rivera" becomes "Dr. Rivera".
    static func doctor(_ provider: String) -> String {
        let name = provider.trimmingCharacters(in: .whitespaces)
        return name.lowercased().hasPrefix("dr") ? name : "Dr. \(name)"
    }

    /// "Age 3", or "Age 18 months" under two.
    static func age(born: Date, now: Date, calendar: Calendar) -> String? {
        let parts = calendar.dateComponents([.year, .month], from: born, to: now)
        guard let years = parts.year, let months = parts.month, years >= 0 else { return nil }
        if years < 2 {
            let total = years * 12 + months
            return total >= 1 ? "Age \(total) month\(total == 1 ? "" : "s")" : nil
        }
        return "Age \(years)"
    }

    static func unique(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        return names.filter { seen.insert($0).inserted }
    }

    private static func formatter(_ template: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
