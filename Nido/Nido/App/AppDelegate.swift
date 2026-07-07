import CloudKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Set by NidoApp at launch so system callbacks can reach the store.
    @MainActor static var store: FamilyStore?

    /// Share metadata that arrived before the store existed (cold launch from
    /// tapping an invitation link); drained by NidoApp right after bootstrap.
    @MainActor static var pendingShareMetadata: CKShare.Metadata?

    @MainActor
    static func deliverShare(_ metadata: CKShare.Metadata) async {
        if let store {
            await store.handleIncomingShare(metadata)
        } else {
            pendingShareMetadata = metadata
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - CloudKit share acceptance

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await Self.deliverShare(cloudKitShareMetadata)
        }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // MARK: - Remote notifications (silent CloudKit pushes)

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            return .noData
        }
        await Self.store?.refresh(silent: true)
        return .newData
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Push is a nice-to-have; the app still syncs on foreground.
    }

    // MARK: - Foreground notification presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Scene delegate used only to catch CloudKit share acceptance callbacks;
/// SwiftUI keeps managing the window itself.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Task { @MainActor in
                await AppDelegate.deliverShare(metadata)
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await AppDelegate.deliverShare(cloudKitShareMetadata)
        }
    }
}
