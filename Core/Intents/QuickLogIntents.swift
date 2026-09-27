import AppIntents

/// One-tap itch log for Siri, the Action Button, and Control Center.
public struct LogItchIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Itching"
    public static let description = IntentDescription("Logs an itchy moment for your child without opening CaliCare.")
    public static let openAppWhenRun = false

    @Parameter(title: "Child")
    public var child: ChildEntity?

    public static var parameterSummary: some ParameterSummary {
        Summary("Log itching for \(\.$child)")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await IntentSupport.log(.itchEpisode, child: child)
        return .result(dialog: dialog)
    }
}

/// "Log a rough night" from Siri.
public struct LogRoughNightIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log a Rough Night"
    public static let description = IntentDescription("Logs last night as rough without opening CaliCare.")
    public static let openAppWhenRun = false

    @Parameter(title: "Child")
    public var child: ChildEntity?

    public static var parameterSummary: some ParameterSummary {
        Summary("Log a rough night for \(\.$child)")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await IntentSupport.log(.nightRating, value: .night(.rough), child: child)
        return .result(dialog: dialog)
    }
}

/// "Log a bowel movement" from Siri. Asks what kind.
public struct LogBowelMovementIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log a Bowel Movement"
    public static let description = IntentDescription("Logs a bowel movement without opening CaliCare.")
    public static let openAppWhenRun = false

    @Parameter(title: "Kind", requestValueDialog: "How was it?")
    public var movement: BowelMovement

    @Parameter(title: "Child")
    public var child: ChildEntity?

    public static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$movement) bowel movement for \(\.$child)")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await IntentSupport.log(.bowelMovement, value: .bowel(movement), child: child)
        return .result(dialog: dialog)
    }
}

/// "Log skin in Cali Care": the daily skin answer from Siri or Shortcuts.
/// Siri asks which answer if it wasn't said. Answering again the same day replaces it.
public struct LogSkinTodayIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Skin Today"
    public static let description = IntentDescription("Logs how your child's skin was today (calm, a little itchy, flaring, or very rough) without opening CaliCare.")
    public static let openAppWhenRun = false

    @Parameter(title: "Skin today", requestValueDialog: "How was their skin today?")
    public var answer: SkinToday

    @Parameter(title: "Child")
    public var child: ChildEntity?

    public static var parameterSummary: some ParameterSummary {
        Summary("Log skin today as \(\.$answer) for \(\.$child)")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await IntentSupport.log(.skinToday, value: .skin(answer), child: child)
        return .result(dialog: dialog)
    }
}
