//
//  AppDelegate.swift
//  Finder 
//
//  Created by minzhe on 2026/3/18.
//

import Foundation
import UIKit
import CloudKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LaunchEventReporter.shared.beginAnalyticsSession()
        LaunchEventReporter.shared.uploadLaunchEventIfNeeded(isPurchased: false)
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

private final class LaunchEventReporter {
    static let shared = LaunchEventReporter()

    private let publicDatabase = CKContainer.default().publicCloudDatabase
    private let userDefaults = UserDefaults.standard
    private let analyticsLaunchCountKey = "finder.analytics.launchCount"

    private init() {}

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var userId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }

    private var regionCode: String {
        Locale.current.regionCode ?? "Unknown"
    }

    private var isCurrentUserNew: Bool {
        max(userDefaults.integer(forKey: analyticsLaunchCountKey), 1) == 1
    }

    func beginAnalyticsSession() {
        let launchCount = userDefaults.integer(forKey: analyticsLaunchCountKey) + 1
        userDefaults.set(launchCount, forKey: analyticsLaunchCountKey)
    }

    func uploadLaunchEventIfNeeded(isPurchased: Bool) {
        let record = CKRecord(recordType: "AppLaunchEvent")
        record["userId"] = userId as CKRecordValue
        record["appVersion"] = appVersion as CKRecordValue
        record["isPurchased"] = NSNumber(value: isPurchased)
        record["isNewUser"] = NSNumber(value: isCurrentUserNew)
        record["regionCode"] = regionCode as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue

        publicDatabase.save(record) { _, _ in }
    }
}

