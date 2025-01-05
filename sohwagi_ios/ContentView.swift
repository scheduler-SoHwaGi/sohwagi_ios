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
            let authorizationCode = appleIDCredential.authorizationCode
            let identityToken = appleIDCredential.identityToken

            var userInfo: [String: String] = [:]

            // Authorization Code
            if let authorizationCode = authorizationCode,
               let authCodeString = String(data: authorizationCode, encoding: .utf8) {
                print("Authorization Code: \(authCodeString)")
                userInfo["authorizationCode"] = authCodeString
            } else {
                print("Authorization Code not available.")
            }

            // Full Name
            if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                let fullNameString = "\(givenName) \(familyName)"
                print("Full Name: \(fullNameString)")
                userInfo["fullName"] = fullNameString
            } else {
                print("Full Name not available.")
                userInfo["fullName"] = "Name Not Available"
            }

            // Email
            if let email = email {
                print("Email: \(email)")
                userInfo["email"] = email
            } else {
                print("Email not available.")
                userInfo["email"] = "Email Not Available"
            }

            // User Identifier
            print("User Identifier: \(userIdentifier)")
            userInfo["userID"] = userIdentifier

            // 가져온 정보를 확인
            print("Fetched User Info: \(userInfo)")

            // API 호출
            if let authCode = userInfo["authorizationCode"], let userName = userInfo["fullName"] {
                print("Preparing to call API with:")
                print("Authorization Code: \(authCode)")
                print("User Name: \(userName)")

                postToAppleLoginAPI(authorizationCode: authCode, userName: userName) { result in
                    switch result {
                    case .success(let tokens):
                        print("Access Token: \(tokens["accessToken"] ?? "N/A")")
                        print("Refresh Token: \(tokens["refreshToken"] ?? "N/A")")
                        UserDefaults.standard.set(tokens["accessToken"], forKey: "accessToken")
                        UserDefaults.standard.set(tokens["refreshToken"], forKey: "refreshToken")
                        UserDefaults.standard.set(userInfo["authorizationCode"], forKey: "authorizationCode")

                        // FCM 토큰을 가져온 후 추가 API 호출
                        self.fetchFCMToken { fcmToken in
                            guard let fcmToken = fcmToken else {
                                print("No FCM Token available.")
                                return
                            }
                            self.postFCMTokenToServer(fcmToken: fcmToken,
                                                      accessToken: tokens["accessToken"] ?? "",
                                                      refreshToken: tokens["refreshToken"] ?? "")
                        }
                    case .failure(let error):
                        print("API Error: \(error.localizedDescription)")
                    }
                }
            } else {
                print("Required user information is missing. API call aborted.")
            }
        }
    }

    func postToAppleLoginAPI(authorizationCode: String, userName: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        guard let url = URL(string: "https://9b79-122-36-149-213.ngrok-free.app/oauth/apple/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "authorizationCode": authorizationCode,
            "userName": userName
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            print("Preparing to send request:")
            print("Request URL: \(url)")
            print("Request Body: \(body)")
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1, userInfo: nil)))
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("Server Response: \(responseString)")
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    completion(.success(jsonResponse))
                } else {
                    completion(.failure(NSError(domain: "Invalid response format", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func postFCMTokenToServer(fcmToken: String, accessToken: String, refreshToken: String) {
        guard let url = URL(string: "https://9b79-122-36-149-213.ngrok-free.app/users/fcmTokens") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-ACCESS-TOKEN")
        request.setValue(refreshToken, forHTTPHeaderField: "X-REFRESH-TOKEN")

        let body: [String: String] = [
            "fcmToken": fcmToken
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            print("Preparing to send FCM Token to server:")
            print("Request URL: \(url)")
            print("Request Headers: [X-ACCESS-TOKEN: \(accessToken), X-REFRESH-TOKEN: \(refreshToken)]")
            print("Request Body: \(body)")
        } catch {
            print("Failed to serialize FCM Token request body.")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to send FCM Token: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response from server.")
                return
            }

            if httpResponse.statusCode == 200 {
                print("Successfully sent FCM Token to server.")

                // 웹뷰 열기
                DispatchQueue.main.async {
                    self.showWebViewCallback?(true, ["fcmToken": fcmToken]) // 웹뷰를 표시하며 필요한 정보를 전달
                }
            } else {
                print("Failed to send FCM Token. Status code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseString)")
                }
            }
        }.resume()
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

    func handleDeleteAccount() {
        guard let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
              let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
            print("Access token or Refresh token not available.")
            return
        }

        guard let url = URL(string: "https://9b79-122-36-149-213.ngrok-free.app/oauth/apple/revoke") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-ACCESS-TOKEN")
        request.setValue(refreshToken, forHTTPHeaderField: "X-REFRESH-TOKEN")

        print("Preparing to send delete account request:")
        print("Request URL: \(url)")
        print("Request Headers: [X-ACCESS-TOKEN: \(accessToken), X-REFRESH-TOKEN: \(refreshToken)]")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to delete account: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response from server.")
                return
            }

            if httpResponse.statusCode == 200 {
                print("Successfully deleted account.")
                
                // 상태 초기화
                DispatchQueue.main.async {
                    // UserDefaults 초기화
                    UserDefaults.standard.removeObject(forKey: "accessToken")
                    UserDefaults.standard.removeObject(forKey: "refreshToken")
                    UserDefaults.standard.removeObject(forKey: "authorizationCode")
                    
                    // 다른 API 호출을 차단할 플래그 설정
                    UserDefaults.standard.set(true, forKey: "accountDeleted")
                    
                    // ContentView로 돌아가기
                    UIApplication.shared.windows.first?.rootViewController = UIHostingController(rootView: ContentView())
                }
            } else {
                print("Failed to delete account. Status code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseString)")
                }
            }
        }.resume()
    }



    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Authorization failed: \(error.localizedDescription)")
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}

struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    var userInfo: [String: String]

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "logoutHandler")
        contentController.add(context.coordinator, name: "deleteAccountHandler") // 회원탈퇴 핸들러 추가
        webView.navigationDelegate = context.coordinator
        webView.isInspectable = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let script = """
        if (typeof window.receiveUserInfo === 'function') {
            window.receiveUserInfo(\(jsonString));
        }
        """
        uiView.evaluateJavaScript(script, completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewWrapper

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logoutHandler", let messageBody = message.body as? String {
                if messageBody == "logout" {
                    print("User requested logout")
                    self.handleLogout()
                }
            } else if message.name == "deleteAccountHandler", let messageBody = message.body as? String {
                if messageBody == "deleteAccount" {
                    print("User requested account deletion")
                    AppleSignInCoordinator.shared.handleDeleteAccount()
                }
            }
        }

        func handleLogout() {
            guard let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
                  let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
                print("Access or Refresh token not available.")
                return
            }

            guard let url = URL(string: "https://9b79-122-36-149-213.ngrok-free.app/users/logout") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(accessToken, forHTTPHeaderField: "X-ACCESS-TOKEN")
            request.setValue(refreshToken, forHTTPHeaderField: "X-REFRESH-TOKEN")

            print("Preparing to send logout request:")
            print("Request URL: \(url)")
            print("Request Headers: [X-ACCESS-TOKEN: \(accessToken), X-REFRESH-TOKEN: \(refreshToken)]")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to log out: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response from server.")
                    return
                }

                if httpResponse.statusCode == 200 {
                    print("Successfully logged out.")
                    DispatchQueue.main.async {
                        UIApplication.shared.windows.first?.rootViewController = UIHostingController(rootView: ContentView())
                    }
                } else {
                    print("Failed to log out. Status code: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response Body: \(responseString)")
                    }
                }
            }.resume()
        }
    }
}

#Preview {
    ContentView()
}
