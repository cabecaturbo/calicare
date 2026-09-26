import Core
import Foundation
import SwiftData
import Synchronization

enum TestTime {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// A time in September 2026, Los Angeles.
    static func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        date(2026, 9, day, hour, minute)
    }
}

/// A clock tests can move forward.
final class TestClock: Sendable {
    private let current: Mutex<Date>

    init(_ start: Date) {
        current = Mutex(start)
    }

    var now: Date {
        current.withLock { $0 }
    }

    func set(_ date: Date) {
        current.withLock { $0 = date }
    }

    func advance(minutes: Int) {
        advance(seconds: minutes * 60)
    }

    func advance(seconds: Int) {
        current.withLock { $0 = $0.addingTimeInterval(TimeInterval(seconds)) }
    }
}

extension CurrentChildSetting {
    /// A setting backed by its own throwaway defaults suite.
    static func isolated() -> CurrentChildSetting {
        CurrentChildSetting(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }
}

/// A fresh in-memory database with one child, plus stores wired to a test clock.
struct TestHarness {
    let container: ModelContainer
    let clock: TestClock
    let logs: LogStore
    let children: ChildStore
    let child: ChildInfo

    init(start: Date = TestTime.date(26, 9)) async throws {
        let container = try CaliCareModelContainer.make(inMemory: true)
        let clock = TestClock(start)
        let children = ChildStore(modelContainer: container, now: { clock.now })
        self.container = container
        self.clock = clock
        self.children = children
        self.logs = LogStore(modelContainer: container, calendar: TestTime.calendar, now: { clock.now })
        self.child = try await children.addChild(name: "Ada", colorTag: "sage")
    }

    /// Every stored log, including soft-deleted ones, copied out of a throwaway context.
    func allStoredEvents() throws -> [StoredEvent] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<LogEvent>()).map(StoredEvent.init)
    }
}

/// The raw row fields tests check, including sync bookkeeping.
struct StoredEvent {
    let id: UUID
    let childID: UUID?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let needsSync: Bool
    let entrySource: EntrySource?

    init(_ event: LogEvent) {
        id = event.id
        childID = event.child?.id
        createdAt = event.createdAt
        updatedAt = event.updatedAt
        deletedAt = event.deletedAt
        needsSync = event.needsSync
        entrySource = event.entrySource
    }
}
