//
//  ContentView.swift
//  sohwagi_ios
//
//  Created by 구나연 on 12/25/24.
//

//

//

import SwiftUI
import AuthenticationServices
import FirebaseMessaging

struct ContentView: View {
    @State private var showSplash = true // 스플래시 화면 표시 여부

    var body: some View {
        ZStack {
            if showSplash {
                LaunchView() // SplashView를 호출
                    .onAppear {
                        // 1초 후 스플래시 화면 종료
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                LoginView() // 스플래시 이후 로그인 화면
            }
        }
    }
}

struct LoginView: View {
    var body: some View {
        ZStack {
            // 배경 이미지 설정
            Image("background") // Assets에 추가된 이미지 이름
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // 메인 콘텐츠
            VStack {
                Spacer()
                    .frame(height: 500)

                Button(action: {
                    performAppleSignIn()
                }) {
                    HStack(spacing: 8) {
                        Image("appleicon") // 로고 아이콘
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                        Text("Apple로 로그인")
                            .font(Font.custom("Pretendard", size: 16).weight(.medium))
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .frame(width: 335, height: 60)
                    .background(Color.black)
                    .cornerRadius(12)
                }
                .padding(.bottom, 50) // 하단 여백
            }
        }
    }

    private func performAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator.shared
        controller.presentationContextProvider = AppleSignInCoordinator.shared
        controller.performRequests()
    }
}

// 애플 로그인 코디네이터
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInCoordinator()

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email

            // 최초 로그인 시 사용자 정보 저장
            if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                let fullNameString = "\(givenName) \(familyName)"
                print("Full Name: \(fullNameString)")
                UserDefaults.standard.set(fullNameString, forKey: "userFullName")
            } else {
                // 저장된 이름 불러오기
                let savedFullName = UserDefaults.standard.string(forKey: "userFullName") ?? "Name Not Available"
                print("Full Name: \(savedFullName)")
            }

            if let email = email {
                print("Email: \(email)")
                UserDefaults.standard.set(email, forKey: "userEmail")
            } else {
                // 저장된 이메일 불러오기
                let savedEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "Email Not Available"
                print("Email: \(savedEmail)")
            }

            print("User ID: \(userIdentifier)")

            // FCM 토큰 가져오기
            fetchFCMToken()
        }
    }

    func fetchFCMToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 토큰 가져오기 실패: \(error.localizedDescription)")
            } else if let token = token {
                print("FCM 토큰: \(token)")
            } else {
                print("FCM 토큰: Not Available")
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Authorization failed: \(error.localizedDescription)")
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}


#Preview {
    ContentView()
}
