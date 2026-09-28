import Core
import SwiftUI

/// Settings, as a large sheet over every tab. Grouped as UX.md section 7:
/// children, family, reminders, quick logging, account, about. Groups for
/// things that aren't built yet (exporting your data) are simply absent.
struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(ReminderController.self) private var reminders
    @Environment(TodayModel.self) private var model
    @State private var addingChild = false
    @State private var guide: GuidePath?

    var body: some View {
        NavigationStack {
            List {
                childrenSection
                FamilySection()
                ReminderSettingsSection()
                quickLoggingSection
                AccountSettingsSection()
                aboutSection
                #if DEBUG
                debugSection
                #endif
            }
            .settingsListStyle(palette)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(palette.indigo)
        .task { await reminders.reload() }
        .sheet(isPresented: $addingChild, onDismiss: { Task { await model.load() } }) {
            AddChildSheet()
                .nightAwarePalette()
        }
        .fullScreenCover(item: $guide) { path in
            SetupGuide(path: path)
                .nightAwarePalette()
        }
        .sheet(isPresented: toggleOffer) {
            ReminderOfferSheet(
                onTurnOn: { Task { await reminders.acceptOffer() } },
                onNotNow: { reminders.declineOffer() }
            )
        }
    }

    private var childrenSection: some View {
        SettingsSection("Children") {
            ForEach(model.children) { child in
                HStack(spacing: Spacing.x3) {
                    if model.children.count > 1 {
                        ChildDot(color: ChildColor(tag: child.colorTag), size: 12)
                    }
                    SettingsLabel(child.name)
                }
            }
            Button { addingChild = true } label: {
                SettingsLabel("Add a child")
            }
        }
    }

    private var quickLoggingSection: some View {
        SettingsSection("Quick logging", footnote: "Log without opening the app.") {
            ForEach(GuidePath.allCases) { path in
                Button { guide = path } label: {
                    SettingsLabel(path.title)
                }
            }
            // The Action Button guide returns once it's recorded on a real iPhone.
            NavigationLink {
                GuidePage("Siri") { SiriSetupGuide() }
            } label: {
                SettingsLabel("Siri")
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection("About") {
            Text("Cali Care organizes the plan your provider gave you. Not medical advice.")
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            LabeledContent {
                Text(Self.version)
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            } label: {
                SettingsLabel("Version")
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Group {
            SettingsSection(
                "Debug",
                footnote: "Debug builds only. See what widgets, Siri, Control Center, and notifications saved."
            ) {
                NavigationLink {
                    RecentLogsView()
                } label: {
                    SettingsLabel("Recent logs")
                }
            }
            TryNotificationSection()
        }
    }
    #endif

    /// "1.0 (12)"
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// Shown when a reminder is switched on before notifications were ever allowed.
    private var toggleOffer: Binding<Bool> {
        Binding(
            get: {
                if case .toggle = reminders.offer { return true }
                return false
            },
            set: { isShowing in
                if !isShowing, case .toggle = reminders.offer { reminders.declineOffer() }
            }
        )
    }
}

/// A ledger row that opens another page.
struct NavigationRow: View {
    @Environment(\.palette) private var palette
    let title: String

    var body: some View {
        LedgerRow {
            Text(title)
                .textStyle(.control)
                .foregroundStyle(palette.ink)
        } trailing: {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.regular))
                .foregroundStyle(palette.graphite)
                .accessibilityHidden(true)
        }
    }
}
