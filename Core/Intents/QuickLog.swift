import Foundation
import SwiftData

/// Why a quick log couldn't be saved, worded for Siri to say out loud.
public enum QuickLogError: Error, Equatable, Sendable, CustomLocalizedStringResourceConvertible {
    /// No children yet, so there's no one to log for.
    case noChild
    /// The chosen child was removed.
    case childNotFound

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noChild: "Add your child in CaliCare first, then try again."
        case .childNotFound: "That child isn't in CaliCare anymore."
        }
    }
}

/// The work behind the logging intents: pick the child, save the log, and
/// word a short confirmation. Kept apart from AppIntents so it can be tested.
public struct QuickLog: Sendable {
    /// Undo only reaches logs made this recently.
    public static let undoWindow: TimeInterval = 10 * 60

    private let logs: LogStore
    private let children: ChildStore
    private let setting: CurrentChildSetting
    private let phrases: LogPhrases

    public init(
        container: ModelContainer,
        setting: CurrentChildSetting = CurrentChildSetting(),
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.logs = LogStore(modelContainer: container, calendar: calendar, now: now)
        self.children = ChildStore(modelContainer: container, now: now)
        self.setting = setting
        self.phrases = LogPhrases(calendar: calendar, locale: locale)
    }

    /// Uses the shared App Group database.
    public static func live() throws -> QuickLog {
        QuickLog(container: try CaliCareModelContainer.shared())
    }

    /// What was saved, and for whom.
    public struct Saved: Sendable {
        public let entry: LogEntry
        public let child: ChildInfo
    }

    /// Logs for `childID`, or the current child when nil. Returns the confirmation.
    @discardableResult
    public func log(_ type: LogType, value: LogValue? = nil, childID: UUID? = nil) async throws -> String {
        let saved = try await record(type, value: value, childID: childID, source: .intent)
        return phrases.logged(saved.entry, childName: saved.child.name)
    }

    /// Logs for `childID`, or the current child when nil, and returns what was saved.
    /// `at` defaults to now.
    @discardableResult
    public func record(
        _ type: LogType,
        value: LogValue? = nil,
        childID: UUID? = nil,
        source: EntrySource,
        at timestamp: Date? = nil
    ) async throws -> Saved {
        let child = try await resolveChild(childID)
        do {
            let entry = try await logs.log(type, value: value, child: child.id, source: source, at: timestamp)
            return Saved(entry: entry, child: child)
        } catch LogStoreError.childNotFound {
            throw QuickLogError.childNotFound
        }
    }

    /// Undoes the newest log if it's from the last 10 minutes. Says what happened either way.
    public func undoRecent() async throws -> String {
        guard let entry = try await logs.undoLast(within: Self.undoWindow) else {
            return LogPhrases.nothingToUndo
        }
        return phrases.removed(entry)
    }

    /// The child an intent means: the one picked, or the current child.
    public func child(_ id: UUID?) async throws -> ChildInfo {
        try await resolveChild(id)
    }

    private func resolveChild(_ id: UUID?) async throws -> ChildInfo {
        guard let id else {
            guard let current = try await children.currentChild(setting: setting) else {
                throw QuickLogError.noChild
            }
            return current
        }
        guard let match = try await children.activeChildren().first(where: { $0.id == id }) else {
            throw QuickLogError.childNotFound
        }
        return match
    }
}
