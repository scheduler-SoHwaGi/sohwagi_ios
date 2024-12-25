//
//  sohwagi_iosApp.swift
//  sohwagi_ios
//
//  Created by 구나연 on 12/25/24.12
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase 초기화
        FirebaseApp.configure()
        
        // 푸시 알림 권한 요청
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { granted, error in
                    if let error = error {
                        print("알림 권한 요청 에러: \(error)")
                    } else if granted {
                        print("알림 권한이 승인되었습니다.")
                    }
                }
            )
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        // 원격 알림 등록
        application.registerForRemoteNotifications()
        
        // Firebase 메시징 델리게이트 설정
        Messaging.messaging().delegate = self
        
        // FCM 토큰 가져오기
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 등록 토큰 가져오기 오류: \(error)")
            } else if let token = token {
                print("FCM 등록 토큰: \(token)")
            }
        }
        
        return true
    }
    
    // APNs 토큰이 성공적으로 등록되었을 때 호출되는 메서드
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // APNs 토큰을 Firebase에 설정
        Messaging.messaging().apnsToken = deviceToken
        print("APNs 토큰 등록 성공: \(deviceToken)")
    }
    
    // APNs 토큰 등록 실패 시 호출되는 메서드
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs 토큰 등록 실패: \(error)")
    }
    
    // FCM 토큰 업데이트 시 호출되는 메서드
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("업데이트된 FCM 토큰: \(fcmToken ?? "")")
        
        // 필요한 경우, 서버에 FCM 토큰을 업로드하는 로직을 여기에 추가할 수 있습니다.
    }
    
    // 포그라운드 상태에서 알림 수신 시 호출되는 메서드
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("알림 수신: \(notification.request.content.userInfo)")
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    // 알림을 클릭했을 때 호출되는 메서드
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("알림 클릭: \(response.notification.request.content.userInfo)")
        completionHandler()
    }
}

@main
struct sohwagiApp: App {
    // Firebase 설정을 위한 AppDelegate 등록
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }
    }
}
