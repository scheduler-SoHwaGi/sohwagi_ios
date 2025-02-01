import SwiftUI
import AuthenticationServices
import FirebaseMessaging
import WebKit

struct ContentView: View {
    @State private var showSplash = true // 스플래시 화면 표시 여부
    @State private var showWebView = false // 자동 로그인 성공 시 웹뷰로 이동
        @State private var userInfo: [String: String] = [:] // 사용자 정보 저장
    

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
                            attemptAutoLogin()
                        }
                    }
            } else {
                LoginView(showWebView: $showWebView, userInfo: $userInfo) // 스플래시 이후 로그인 화면
            }
        }
    }
    private func attemptAutoLogin() {
        if let userID = UserDefaults.standard.string(forKey: "userID") {
            print("저장된 userID 확인됨: \(userID), 자동 로그인 시도")
            AppleSignInCoordinator.shared.performAutoLogin(userID: userID) { success, fetchedUserInfo in
                DispatchQueue.main.async {
                    if success {
                        print("자동 로그인 성공 → 웹뷰 열기")
                        self.userInfo = fetchedUserInfo
                        self.showWebView = true
                    } else {
                        print("자동 로그인 실패")
                    }
                }
            }
        } else {
            print("자동 로그인을 위한 userID가 저장되지 않음. 로그인 필요")
        }
    }


}



struct LoginView: View {
    @Binding var showWebView: Bool // ContentView에서 전달받은 바인딩 변수
    @Binding var userInfo: [String: String] // 사용자 정보 바인딩

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
        .onAppear {
                    print("LoginView appeared. showWebView: \(showWebView)")
                }
                .onChange(of: showWebView) { newValue in
                    print("showWebView 값 변경됨: \(newValue)")
                }
    }

    private func performAppleSignIn() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = AppleSignInCoordinator.shared
            AppleSignInCoordinator.shared.showWebViewCallback = { show, userInfo in
                DispatchQueue.main.async {
                    print("showWebViewCallback 실행됨 → 웹뷰 열기")
                    self.userInfo = userInfo
                    self.showWebView = show
                }
            }
            controller.presentationContextProvider = AppleSignInCoordinator.shared
            controller.performRequests()
        }
}

// 애플 로그인 코디네이터
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInCoordinator()
    var showWebViewCallback: ((Bool, [String: String]) -> Void)?
    
    // 자동 로그인 수행
    func performAutoLogin(userID: String, completion: @escaping (Bool, [String: String]) -> Void) {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: userID) { credentialState, error in
            DispatchQueue.main.async {
                if credentialState == .authorized {
                    print("자동 로그인 성공: \(userID)")

                    var userInfo: [String: String] = [:]
                    userInfo["userID"] = userID
                    userInfo["fullName"] = UserDefaults.standard.string(forKey: "fullName") ?? "Unknown"
                    userInfo["email"] = UserDefaults.standard.string(forKey: "email") ?? "Unknown"

                    // UI 업데이트
                    self.showWebViewCallback?(true, userInfo)  // 웹뷰 표시
                    completion(true, userInfo)
                } else {
                    print("자동 로그인 실패")
                    completion(false, [:])
                }
            }
        }
    }

    
    // 일반 로그인 수행
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            let authorizationCode = appleIDCredential.authorizationCode
            let identityToken = appleIDCredential.identityToken

            var userInfo: [String: String] = [:]
            
            // user id 저장
            UserDefaults.standard.set(userIdentifier, forKey: "userID")

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

                // UserDefaults에 저장
                UserDefaults.standard.set(fullNameString, forKey: "fullName")
            } else {
                print("Full Name not available.")
                userInfo["fullName"] = UserDefaults.standard.string(forKey: "fullName") ?? "Name Not Available"
            }

            // Email
            if let email = email {
                print("Email: \(email)")
                userInfo["email"] = email

                // UserDefaults에 저장
                UserDefaults.standard.set(email, forKey: "email")
            } else {
                print("Email not available.")
                userInfo["email"] = UserDefaults.standard.string(forKey: "email") ?? "Email Not Available"
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
        guard let url = URL(string: "https://sohwagi.site/oauth/apple/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "authorizationCode": authorizationCode,
            "userName": userName
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
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

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    // 서버 응답(JSON)에서 토큰 추출
                    if let accessToken = jsonResponse["accessToken"], let refreshToken = jsonResponse["refreshToken"] {
                        // UserDefaults에 저장
                        UserDefaults.standard.set(accessToken, forKey: "accessToken")
                        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
                        
                        // 토큰을 콜백으로 반환
                        completion(.success([
                            "accessToken": accessToken,
                            "refreshToken": refreshToken
                        ]))
                    } else {
                        completion(.failure(NSError(domain: "Tokens not found in response", code: -1, userInfo: nil)))
                    }
                } else {
                    completion(.failure(NSError(domain: "Invalid response format", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }


    func postFCMTokenToServer(fcmToken: String, accessToken: String, refreshToken: String) {
        guard let url = URL(string: "https://sohwagi.site/users/fcmTokens") else { return }

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

        guard let url = URL(string: "https://sohwagi.site/oauth/apple/revoke") else { return }

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
        webView.configuration.preferences.javaScriptEnabled = true
        let contentController = webView.configuration.userContentController

        // JavaScript 메시지 핸들러 추가
        contentController.add(context.coordinator, name: "webViewReady")
        contentController.add(context.coordinator, name: "logoutHandler")
        contentController.add(context.coordinator, name: "deleteAccountHandler")

        webView.navigationDelegate = context.coordinator
        webView.isInspectable = true
        webView.load(URLRequest(url: url))

        // Coordinator에 WebView 참조 전달
        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // updateUIView에서는 아무 작업도 하지 않습니다.
        // 토큰 전달은 웹뷰가 준비되었음을 확인한 뒤 Coordinator에서 수행됩니다.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewWrapper
        var isWebViewReady = false // 웹뷰 준비 상태 플래그
        weak var webView: WKWebView? // WebView 참조

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "webViewReady" {
                print("WebView is ready to receive data.")
                isWebViewReady = true

                // 토큰 전달
                sendTokensToWebView()
            } else if message.name == "logoutHandler", let messageBody = message.body as? String {
                if messageBody == "logout" {
                    print("User requested logout")
                    handleLogout()
                }
            } else if message.name == "deleteAccountHandler", let messageBody = message.body as? String {
                if messageBody == "deleteAccount" {
                    print("User requested account deletion")
                    AppleSignInCoordinator.shared.handleDeleteAccount()
                }
            }
        }

        func sendTokensToWebView() {
            guard isWebViewReady, let webView = webView else {
                print("WebView is not ready or unavailable.")
                return
            }

            guard
                let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
                let refreshToken = UserDefaults.standard.string(forKey: "refreshToken"),
                let jsonData = try? JSONSerialization.data(withJSONObject: ["accessToken": accessToken, "refreshToken": refreshToken], options: []),
                let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("Failed to prepare token JSON.")
                return
            }

            let script = """
            if (typeof window.receiveUserInfo === 'function') {
                window.receiveUserInfo(\(jsonString));
            }
            """

            // JavaScript 실행 및 결과 확인
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Error sending tokens to WebView: \(error.localizedDescription)")
                } else {
                    print("Tokens successfully sent to WebView.")
                    if let result = result {
                        print("JavaScript evaluation result: \(result)")
                    } else {
                        print("No result returned from JavaScript evaluation.")
                    }
                }
            }
        }
        
        func handleDeleteAccount() {
            guard let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
                  let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
                print("Access token or Refresh token not available.")
                return
            }

            guard let url = URL(string: "https://sohwagi.site/oauth/apple/revoke") else { return }

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


        func handleLogout() {
            guard let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
                  let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
                print("Access or Refresh token not available.")
                return
            }

            guard let url = URL(string: "https://sohwagi.site/users/logout") else { return }

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
