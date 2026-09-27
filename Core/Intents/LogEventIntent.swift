import AppIntents

/// Logs any event type from Siri or Shortcuts without opening the app.
public struct LogEventIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log an Event"
    public static let description = IntentDescription("Logs something for your child without opening CaliCare.")
    public static let openAppWhenRun = false

    @Parameter(title: "Event")
    public var eventType: LogEventKind

    @Parameter(title: "Night", requestValueDialog: "How was the night?")
    public var night: NightRating?

    @Parameter(title: "Bowel movement", requestValueDialog: "How was it?")
    public var bowel: BowelMovement?

    @Parameter(title: "Mood", requestValueDialog: "How's their mood?")
    public var mood: Mood?

    @Parameter(title: "Skin today", requestValueDialog: "How was their skin today?")
    public var skin: SkinToday?

    @Parameter(title: "Child")
    public var child: ChildEntity?

    public static var parameterSummary: some ParameterSummary {
        Switch(\.$eventType) {
            Case(.nightRating) {
                Summary("Log \(\.$eventType) as \(\.$night) for \(\.$child)")
            }
            Case(.bowelMovement) {
                Summary("Log \(\.$eventType) as \(\.$bowel) for \(\.$child)")
            }
            Case(.mood) {
                Summary("Log \(\.$eventType) as \(\.$mood) for \(\.$child)")
            }
            Case(.skinToday) {
                Summary("Log \(\.$eventType) as \(\.$skin) for \(\.$child)")
            }
            DefaultCase {
                Summary("Log \(\.$eventType) for \(\.$child)")
            }
        }
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let value = try resolvedValue()
        let dialog = try await IntentSupport.log(eventType.logType, value: value, child: child)
        return .result(dialog: dialog)
    }

    /// The value that fits the chosen type. Asks for it when one is needed; ignores the others.
    private func resolvedValue() throws -> LogValue? {
        switch eventType {
        case .nightRating:
            guard let night else { throw $night.needsValueError("How was the night?") }
            return .night(night)
        case .bowelMovement:
            return bowel.map { .bowel($0) }
        case .mood:
            guard let mood else { throw $mood.needsValueError("How's their mood?") }
            return .mood(mood)
        case .skinToday:
            guard let skin else { throw $skin.needsValueError("How was their skin today?") }
            return .skin(skin)
        case .itchEpisode, .flare, .routineDone:
            return nil
        }
    }
}
