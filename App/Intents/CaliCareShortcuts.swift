import AppIntents
import Core

/// Pulls Core's intents into the app so Siri and Shortcuts can see them.
struct CaliCareAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [CoreIntentsPackage.self]
    }
}

/// Siri phrases that work with no setup. Each also shows in Shortcuts and the Action Button picker.
struct CaliCareShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogRoughNightIntent(),
            phrases: [
                "Log a rough night in \(.applicationName)",
                "Rough night in \(.applicationName)",
            ],
            shortTitle: "Rough Night",
            systemImageName: "moon.zzz"
        )
        AppShortcut(
            intent: LogItchIntent(),
            phrases: [
                "Log itching in \(.applicationName)",
                "Log an itch in \(.applicationName)",
            ],
            shortTitle: "Log Itching",
            systemImageName: "hand.raised"
        )
        AppShortcut(
            intent: LogBowelMovementIntent(),
            phrases: [
                "Log a bowel movement in \(.applicationName)",
            ],
            shortTitle: "Bowel Movement",
            systemImageName: "toilet"
        )
        AppShortcut(
            intent: LogSkinTodayIntent(),
            phrases: [
                "Log skin in \(.applicationName)",
                "Log skin today in \(.applicationName)",
            ],
            shortTitle: "Skin Today",
            systemImageName: "circle.lefthalf.filled"
        )
        AppShortcut(
            intent: UndoLastIntent(),
            phrases: [
                "Undo the last log in \(.applicationName)",
                "Undo in \(.applicationName)",
            ],
            shortTitle: "Undo Last Log",
            systemImageName: "arrow.uturn.backward"
        )
        AppShortcut(
            intent: GetWeeklyCardIntent(),
            phrases: [
                "Get the weekly card from \(.applicationName)",
            ],
            shortTitle: "Weekly Card",
            systemImageName: "rectangle.portrait.on.rectangle.portrait"
        )
        AppShortcut(
            intent: GetCareLogIntent(),
            phrases: [
                "Get the care log from \(.applicationName)",
            ],
            shortTitle: "Care Log",
            systemImageName: "doc.text"
        )
    }
}
