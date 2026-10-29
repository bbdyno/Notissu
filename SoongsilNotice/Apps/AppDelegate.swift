//
//  AppDelegate.swift
//  Notissu
//
//  Copyright © 2019 Notissu. All rights reserved.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().delegate = self
        // 처음 쓰는 사람은 게시판을 고른 뒤 첫 화면에서 묻는다.
        if UserDefaults.standard.bool(forKey: AppModel.Key.onboarded) {
            NotificationPermission.request()
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

}

/// 알림 허락을 묻고 원격 알림에 등록한다. 이미 답한 사람에게는 창이 다시 뜨지 않는다.
enum NotificationPermission {
    static func request() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        UIApplication.shared.registerForRemoteNotifications()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // 앱을 켜 둔 채 알림이 와도 배너로 보여 준다. 2.x는 완료 핸들러를 부르지 않아 알림이 사라졌다.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            let dataDict:[String: String] = ["token": token]
            NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        }
    }
}
