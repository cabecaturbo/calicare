import Foundation

/// One reminder: on or off, and its time of day.
public struct ReminderSlot: Codable, Hashable, Sendable {
    public var isOn: Bool
    public var hour: Int
    public var minute: Int

    public init(isOn: Bool, hour: Int, minute: Int) {
        self.isOn = isOn
        self.hour = hour
        self.minute = minute
    }
}

/// All reminder settings. Everything starts off until the parent says yes.
public struct ReminderSettings: Codable, Hashable, Sendable {
    public var checkIn = ReminderSlot(isOn: false, hour: 7, minute: 0)
    public var skinCheckIn = ReminderSlot(isOn: false, hour: 18, minute: 30)
    public var morningRoutine = ReminderSlot(isOn: false, hour: 7, minute: 30)
    public var afternoonRoutine = ReminderSlot(isOn: false, hour: 12, minute: 30)
    public var eveningRoutine = ReminderSlot(isOn: false, hour: 19, minute: 0)

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case checkIn, skinCheckIn, morningRoutine, afternoonRoutine, eveningRoutine
    }

    /// Missing reminders keep their defaults, so settings saved by an older
    /// version (before the skin check-in) still load instead of resetting.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReminderSettings()
        checkIn = try container.decodeIfPresent(ReminderSlot.self, forKey: .checkIn) ?? defaults.checkIn
        skinCheckIn = try container.decodeIfPresent(ReminderSlot.self, forKey: .skinCheckIn) ?? defaults.skinCheckIn
        morningRoutine = try container.decodeIfPresent(ReminderSlot.self, forKey: .morningRoutine) ?? defaults.morningRoutine
        afternoonRoutine = try container.decodeIfPresent(ReminderSlot.self, forKey: .afternoonRoutine) ?? defaults.afternoonRoutine
        eveningRoutine = try container.decodeIfPresent(ReminderSlot.self, forKey: .eveningRoutine) ?? defaults.eveningRoutine
    }

    public subscript(kind: ReminderKind) -> ReminderSlot {
        get {
            switch kind {
            case .checkIn: checkIn
            case .skinCheckIn: skinCheckIn
            case .morningRoutine: morningRoutine
            case .afternoonRoutine: afternoonRoutine
            case .eveningRoutine: eveningRoutine
            }
        }
        set {
            switch kind {
            case .checkIn: checkIn = newValue
            case .skinCheckIn: skinCheckIn = newValue
            case .morningRoutine: morningRoutine = newValue
            case .afternoonRoutine: afternoonRoutine = newValue
            case .eveningRoutine: eveningRoutine = newValue
            }
        }
    }

    public mutating func turnAllOn() {
        for kind in ReminderKind.allCases {
            self[kind].isOn = true
        }
    }
}

/// Reminder settings, shared by the app, widgets, and intents through the App Group.
public struct ReminderSettingsStore: @unchecked Sendable {
    // UserDefaults is thread-safe; @unchecked covers SDKs where it isn't marked Sendable.
    private let defaults: UserDefaults
    static let settingsKey = "reminderSettings"
    static let offeredKey = "hasOfferedReminders"

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public var settings: ReminderSettings {
        get {
            defaults.data(forKey: Self.settingsKey)
                .flatMap { try? JSONDecoder().decode(ReminderSettings.self, from: $0) }
                ?? ReminderSettings()
        }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.settingsKey)
            }
        }
    }

    /// Whether we've already offered reminders once. We never offer on our own again.
    public var hasOfferedReminders: Bool {
        get { defaults.bool(forKey: Self.offeredKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.offeredKey) }
    }
}
