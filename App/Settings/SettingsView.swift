import Core
import SwiftUI

/// Settings, as a large sheet over every tab. Grouped as UX.md section 7:
/// children, family, reminders, quick logging, your data, account, about.
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
                QuickLogCardSettingsSection()
                AppearanceSection()
                yourDataSection
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
        .tint(palette.accent)
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
                NavigationLink {
                    EditChildView(child: child)
                } label: {
                    HStack(spacing: Spacing.x4) {
                        if model.children.count > 1 {
                            ChildDot(color: ChildColor(tag: child.colorTag), size: 12)
                        }
                        SettingsLabel(child.name)
                    }
                }
            }
            Button { addingChild = true } label: {
                SettingsLabel("Add a child")
            }
        }
    }

    private var yourDataSection: some View {
        SettingsSection("Your data", footnote: "Everything stays on this phone unless you share with family.") {
            NavigationLink {
                YourDataView()
            } label: {
                SettingsLabel("Export and what's stored where")
            }
        }
    }

    private var quickLoggingSection: some View {
        SettingsSection("Quick logging", footnote: "Log without opening the app.") {
            ForEach(GuidePath.allCases) { path in
                Button { guide = path } label: {
                    HStack {
                        SettingsLabel(path.title)
                        Spacer()
                        // Matches the navigation rows' chevron; opens full screen.
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.graphite.opacity(0.6))
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
            }
            // The Action Button guide returns once it's recorded on a real iPhone.
            NavigationLink {
                GuidePage("Siri") { SiriSetupGuide() }
            } label: {
                SettingsLabel("Siri")
            }
            NavigationLink {
                AutoSendGuide()
            } label: {
                SettingsLabel("Send the weekly card on its own")
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection("About", footnote: "Cali Care keeps the plan your provider gave you. Not medical advice.") {
            NavigationLink {
                AboutView()
            } label: {
                SettingsLabel("How Cali Care works")
            }
            Link(destination: Self.privacyURL) {
                SettingsLabel("Privacy policy")
            }
            Link(destination: Self.supportURL) {
                SettingsLabel("Contact support")
            }
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
            SampleDataSection()
            SettingsSection(
                "Debug",
                footnote: "Debug builds only. See what widgets, Siri, Control Center, and notifications saved."
            ) {
                NavigationLink {
                    RecentLogsView()
                } label: {
                    SettingsLabel("Recent logs")
                }
                NavigationLink {
                    LockScreenTestView()
                } label: {
                    SettingsLabel("Lock Screen test")
                }
            }
            TryNotificationSection()
        }
    }
    #endif

    /// The privacy policy on the landing page (web/privacy.html).
    static let privacyURL = URL(string: "https://calicare.vercel.app/privacy")!

    /// Support email for now (owner, October 2, 2026); a support address comes with the landing page.
    static let supportURL = URL(string: "mailto:msmccartin@gmail.com?subject=Cali%20Care")!

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
