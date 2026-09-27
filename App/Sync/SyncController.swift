import BackgroundTasks
import Core
import Foundation
import Observation

/// Decides when to sync: on open, a few seconds after a change, on sign-in,
/// and in the background. Errors retry quietly with backoff and never
/// interrupt logging; Settings shows "Last synced" and nothing more.
@MainActor
@Observable
final class SyncController {
    static let backgroundTaskID = "com.cursorkittens.calicare.sync"

    private(set) var lastSyncedAt: Date?
    private(set) var isSyncing = false

    private let account: AccountController
    private let settings = SyncSettings()
    /// A sync waiting for its delay. Replacing it never touches a running sync.
    private var scheduled: Task<Void, Never>?
    /// A request came in while syncing; run once more when this one ends.
    private var syncAgain = false
    private var failures = 0
    private var listening = false

    init(account: AccountController) {
        self.account = account
        lastSyncedAt = settings.lastSyncedAt
    }

    /// Starts listening for local changes. Safe to call more than once.
    func start() {
        guard !listening else { return }
        listening = true
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .caliCareLocalDataChanged) {
                self?.requestSync(after: .seconds(3))
            }
        }
        requestSync(after: .zero)
    }

    /// Syncs after `delay`, replacing anything already waiting. Bursts of taps
    /// become one sync. Only the wait is cancelled, never a sync in progress:
    /// cancelling mid-sync would cut off its network requests.
    func requestSync(after delay: Duration = .seconds(3)) {
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            Task { [weak self] in await self?.syncNow() }
        }
    }

    /// Runs one sync if signed in with a name. Returns true if it finished.
    @discardableResult
    func syncNow() async -> Bool {
        guard case .signedIn(let info) = account.state, let name = info.displayName,
              let client = Backend.client
        else { return false }
        guard !isSyncing else {
            syncAgain = true
            return false
        }
        isSyncing = true
        defer {
            isSyncing = false
            if syncAgain {
                syncAgain = false
                requestSync(after: .zero)
            }
        }
        do {
            let engine = SyncEngine(
                modelContainer: try CaliCareModelContainer.shared(),
                remote: SupabaseSyncRemote(client: client),
                settings: settings
            )
            let report = try await engine.sync(userID: info.userID, displayName: name)
            failures = 0
            lastSyncedAt = settings.lastSyncedAt
            if report.changedLocalData { await LogChanges.didReceiveRemoteChanges() }
            scheduleBackgroundSync()
            return true
        } catch is CancellationError {
            return false
        } catch {
            // Offline or a hiccup: try again later, quietly. The logs are safe here.
            #if DEBUG
            print("CaliCare sync failed: \(error)")
            #endif
            failures += 1
            requestSync(after: Self.backoff(failures: failures))
            return false
        }
    }

    /// Forgets the household after signing out. Everything on the phone stays.
    func accountSignedOut() {
        scheduled?.cancel()
        settings.reset()
        lastSyncedAt = nil
    }

    /// 30s, 1m, 2m, 4m… up to 15 minutes.
    static func backoff(failures: Int) -> Duration {
        let seconds = min(30 * pow(2, Double(max(failures - 1, 0))), 15 * 60)
        return .seconds(seconds)
    }

    /// Asks iOS to wake the app in about an hour to sync.
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
