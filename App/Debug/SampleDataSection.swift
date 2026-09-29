#if DEBUG
import Core
import SwiftUI

/// Settings › Debug: fill the current child with about eight weeks of sample
/// logs, or take them away again. Off while signed in, so nothing syncs.
struct SampleDataSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(AccountController.self) private var account
    @State private var working = false
    @State private var status: String?

    static let stepsKey = "sampleDataStepIDs"

    var body: some View {
        SettingsSection("Sample data", footnote: footnote) {
            Button { Task { await fill() } } label: {
                SettingsLabel("Fill with sample data (8 weeks)")
            }
            .disabled(working || isSignedIn || model.child == nil)
            Button { Task { await remove() } } label: {
                SettingsLabel("Remove sample data")
            }
            .disabled(working)
        }
    }

    private var isSignedIn: Bool {
        if case .signedOut = account.state { return false }
        return true
    }

    private var footnote: String {
        if let status { return status }
        if isSignedIn { return "Sign out of family sharing first, so sample logs never sync." }
        return "Debug builds only. Adds logs \"by Sample\" for \(model.child?.name ?? "your child"); your own logs stay."
    }

    private func fill() async {
        guard let child = model.child else { return }
        working = true
        defer { working = false }
        do {
            let container = try CaliCareModelContainer.shared()
            let steps = try await SampleData.fill(child: child.id, container: container)
            let saved = (UserDefaults.standard.stringArray(forKey: Self.stepsKey) ?? []) + steps.map(\.uuidString)
            UserDefaults.standard.set(saved, forKey: Self.stepsKey)
            await LogChanges.didChange()
            await model.load()
            status = "Added about eight weeks of sample logs."
        } catch {
            status = "Couldn't add sample data: \(error.localizedDescription)"
        }
    }

    private func remove() async {
        working = true
        defer { working = false }
        do {
            let ids = (UserDefaults.standard.stringArray(forKey: Self.stepsKey) ?? []).compactMap(UUID.init)
            let count = try await SampleData.remove(container: try CaliCareModelContainer.shared(), stepIDs: ids)
            UserDefaults.standard.removeObject(forKey: Self.stepsKey)
            await LogChanges.didChange()
            await model.load()
            status = "Removed \(count) sample logs."
        } catch {
            status = "Couldn't remove sample data: \(error.localizedDescription)"
        }
    }
}
#endif
