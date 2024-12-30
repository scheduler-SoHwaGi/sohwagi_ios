import SwiftUI
import AuthenticationServices
import FirebaseMessaging
import WebKit

struct ContentView: View {
    @State private var showSplash = true // 스플래시 화면 표시 여부

    var body: some View {
        ZStack {
            if showSplash {
                LaunchView() // SplashView 호출
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
    @State private var showWebView = false // 웹뷰 표시 여부
    @State private var userInfo: [String: String] = [:] // 사용자 정보 저장

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

            // 웹뷰
            if showWebView {
                WebViewWrapper(url: URL(string: "https://sohawgi-front.vercel.app/")!, userInfo: userInfo)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private func performAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator.shared
        AppleSignInCoordinator.shared.showWebViewCallback = { show, userInfo in
            self.userInfo = userInfo
            self.showWebView = show // 웹뷰 표시 여부 업데이트
        }
        controller.presentationContextProvider = AppleSignInCoordinator.shared
        controller.performRequests()
    }
}

// 애플 로그인 코디네이터
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInCoordinator()
    var showWebViewCallback: ((Bool, [String: String]) -> Void)?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email

            var userInfo: [String: String] = [:]

            // 최초 로그인 시 사용자 정보 저장
            if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                let fullNameString = "\(givenName) \(familyName)"
                userInfo["fullName"] = fullNameString
                UserDefaults.standard.set(fullNameString, forKey: "userFullName")
            } else {
                userInfo["fullName"] = UserDefaults.standard.string(forKey: "userFullName") ?? "Name Not Available"
            }

            if let email = email {
                userInfo["email"] = email
                UserDefaults.standard.set(email, forKey: "userEmail")
            } else {
                userInfo["email"] = UserDefaults.standard.string(forKey: "userEmail") ?? "Email Not Available"
            }

            userInfo["userID"] = userIdentifier

            print("User Info: \(userInfo)")

            // FCM 토큰 가져오기
            fetchFCMToken { fcmToken in
                userInfo["fcmToken"] = fcmToken

                // 웹뷰 열기와 사용자 정보 전달
                self.showWebViewCallback?(true, userInfo)
            }
        }
    }

    func fetchFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 토큰 가져오기 실패: \(error.localizedDescription)")
                completion(nil)
            } else if let token = token {
                print("FCM 토큰: \(token)")
                completion(token)
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

// WKWebView를 SwiftUI에서 사용하는 Wrapper
struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    let userInfo: [String: String]

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // 메시지 핸들러 추가
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "logoutHandler")
        contentController.add(context.coordinator, name: "deleteAccountHandler") // 회원탈퇴 핸들러 추가

        webView.navigationDelegate = context.coordinator
        webView.isInspectable = true

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }



    func updateUIView(_ uiView: WKWebView, context: Context) {
        // JSON 데이터 준비
        guard let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to serialize userInfo to JSON.")
            return
        }

        // JSON 문자열 출력 (디버깅용)
        print("Sending JSON to JavaScript: \(jsonString)")

        // WebView가 로드된 후 JavaScript 실행
        context.coordinator.pendingUserInfo = jsonString
        context.coordinator.injectUserInfoIfNeeded(webView: uiView)
    }



    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewWrapper
        var pendingUserInfo: String?

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // WebView 로드 완료 시 사용자 정보 전달
            injectUserInfoIfNeeded(webView: webView)
        }

        func injectUserInfoIfNeeded(webView: WKWebView) {
            guard let userInfo = pendingUserInfo else {
                print("No pending user info to send.")
                return
            }

            // JavaScript 코드에서 JSON 객체 전달
            let script = """
            if (typeof window.receiveUserInfo === 'function') {
                window.receiveUserInfo(\(userInfo));
            } else {
                console.error('receiveUserInfo function is not defined.');
            }
            """
            print("Sending JSON to JavaScript:", userInfo) // 로그 추가
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("JavaScript execution error: \(error.localizedDescription)")
                } else {
                    print("JavaScript executed successfully.")
                }
            }
        }

        // JavaScript -> Swift 메시지 처리
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logoutHandler", let messageBody = message.body as? String {
                print("JavaScript sent message: \(messageBody)")
                if messageBody == "logout" {
                    print("User requested logout")
                    // 로그아웃 처리 추가
                }
            } else if message.name == "deleteAccountHandler", let messageBody = message.body as? String {
                print("JavaScript sent message: \(messageBody)")
                if messageBody == "deleteAccount" {
                    print("User requested account deletion")
                    // 회원탈퇴 처리 추가
                }
            }
        }
    }

}


#Preview {
    ContentView()
}
