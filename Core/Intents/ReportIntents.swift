import AppIntents
import Foundation
import UniformTypeIdentifiers

/// "Get Weekly Card": this week's report card as a picture, so a Shortcuts
/// automation can send it (for example every Sunday evening to a partner).
public struct GetWeeklyCardIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Weekly Card"
    public static let description = IntentDescription("This week's card for a child, as a picture you can send.")
    public static let openAppWhenRun = false

    @Parameter(title: "Child", description: "Leave empty for the child you're logging for.")
    public var child: ChildEntity?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let container = try CaliCareModelContainer.shared()
        let info = try await QuickLog.live().child(child?.id)
        let report = try await WeeklyReport.load(child: info, weekEnding: CareDay.containing(.now), container: container)
        let url = try WeeklyCardRenderer.file(for: report)
        return .result(value: IntentFile(fileURL: url, filename: url.lastPathComponent, type: .png))
    }
}

/// "Get Care Log": the doctor report PDF for the last few weeks.
public struct GetCareLogIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Care Log"
    public static let description = IntentDescription("The care log PDF for a child's provider, covering the last few weeks. Not medical advice.")
    public static let openAppWhenRun = false

    @Parameter(title: "Child", description: "Leave empty for the child you're logging for.")
    public var child: ChildEntity?

    @Parameter(title: "Days", default: 28, inclusiveRange: (7, 365))
    public var days: Int

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let container = try CaliCareModelContainer.shared()
        let info = try await QuickLog.live().child(child?.id)
        let today = CareDay.containing(.now)
        let range = DoctorReport.Range(first: today.adding(days: -(days - 1)), last: today)
        let report = try await DoctorReport.load(child: info, range: range, container: container)
        let url = try DoctorReportPDF.file(for: report)
        return .result(value: IntentFile(fileURL: url, filename: url.lastPathComponent, type: .pdf))
    }
}
