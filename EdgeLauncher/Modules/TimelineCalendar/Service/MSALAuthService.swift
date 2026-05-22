import Foundation
import AuthenticationServices
import AppKit
import CryptoKit

enum MSALAuthError: Error, LocalizedError {
    case applicationInitFailed(Error)
    case interactionRequired
    case noActiveAccount
    case acquireFailed(Error)
    case userCancelled
    case invalidResponse(String)
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .applicationInitFailed(let e): return "OAuth 초기화 실패: \(e.localizedDescription)"
        case .interactionRequired: return "로그인이 필요합니다."
        case .noActiveAccount: return "로그인된 Microsoft 365 계정이 없습니다."
        case .acquireFailed(let e): return "토큰 획득 실패: \(e.localizedDescription)"
        case .userCancelled: return "사용자가 로그인을 취소했습니다."
        case .invalidResponse(let m): return "응답 오류: \(m)"
        case .tokenExchangeFailed(let m): return "토큰 교환 실패: \(m)"
        }
    }
}

struct OutlookSignInResult: Sendable {
    let accessToken: String
    let homeAccountId: String
    let username: String
    let expiresOn: Date?
}

/// Light "Account" surface so call sites that previously used `MSALAccount` keep working.
struct OutlookAccount {
    let identifier: String
    let username: String
}

@MainActor
final class MSALAuthService: NSObject {
    private let tokenStore: KeychainTokenStore
    private let scopes: [String]
    private var cachedAccessToken: String?
    private var cachedAccessTokenExpiry: Date?

    init(tokenStore: KeychainTokenStore? = nil) throws {
        self.tokenStore = tokenStore ?? KeychainTokenStore()
        self.scopes = OutlookConfig.scopes
        super.init()
    }

    func currentAccount() -> OutlookAccount? {
        guard let id = tokenStore.homeAccountId,
              let name = tokenStore.username else { return nil }
        return OutlookAccount(identifier: id, username: name)
    }

    func isSignedIn() -> Bool {
        return tokenStore.refreshToken != nil && tokenStore.homeAccountId != nil
    }

    func signIn() async throws -> OutlookSignInResult {
        let codeVerifier = Self.generateCodeVerifier()
        let codeChallenge = Self.codeChallenge(for: codeVerifier)
        let state = UUID().uuidString
        let scopeString = (scopes + ["offline_access"]).joined(separator: " ")

        var components = URLComponents(string: "https://login.microsoftonline.com/\(OutlookConfig.tenantId)/oauth2/v2.0/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: OutlookConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: OutlookConfig.redirectUri),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: scopeString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let authURL = components.url else {
            throw MSALAuthError.invalidResponse("authorize URL 생성 실패")
        }
        NSLog("[MSALAuthService] signIn scopes=%@", scopeString)
        NSLog("[MSALAuthService] authorize URL=%@", authURL.absoluteString)

        let callbackURL = try await runAuthSession(authURL: authURL)

        let callbackComps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let items = callbackComps?.queryItems ?? []
        if let errorVal = items.first(where: { $0.name == "error" })?.value {
            let desc = items.first(where: { $0.name == "error_description" })?.value ?? ""
            throw MSALAuthError.acquireFailed(NSError(
                domain: "OutlookOAuth", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "\(errorVal): \(desc)"]
            ))
        }
        guard items.first(where: { $0.name == "state" })?.value == state else {
            throw MSALAuthError.invalidResponse("state 불일치")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw MSALAuthError.invalidResponse("code 없음")
        }

        let tokenResponse = try await exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
        let userInfo = try await fetchUserInfo(accessToken: tokenResponse.accessToken)

        tokenStore.refreshToken = tokenResponse.refreshToken
        tokenStore.homeAccountId = userInfo.id
        tokenStore.username = userInfo.username
        cachedAccessToken = tokenResponse.accessToken
        cachedAccessTokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

        return OutlookSignInResult(
            accessToken: tokenResponse.accessToken,
            homeAccountId: userInfo.id,
            username: userInfo.username,
            expiresOn: cachedAccessTokenExpiry
        )
    }

    func signOut() async throws {
        tokenStore.refreshToken = nil
        tokenStore.homeAccountId = nil
        tokenStore.username = nil
        cachedAccessToken = nil
        cachedAccessTokenExpiry = nil
    }

    func acquireAccessToken(forceInteractive: Bool = false) async throws -> OutlookSignInResult {
        if !forceInteractive,
           let token = cachedAccessToken,
           let exp = cachedAccessTokenExpiry,
           Date() < exp.addingTimeInterval(-60) {
            return OutlookSignInResult(
                accessToken: token,
                homeAccountId: tokenStore.homeAccountId ?? "",
                username: tokenStore.username ?? "",
                expiresOn: exp
            )
        }
        if !forceInteractive, let refresh = tokenStore.refreshToken {
            do {
                let tokenResponse = try await refreshAccessToken(refreshToken: refresh)
                cachedAccessToken = tokenResponse.accessToken
                cachedAccessTokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
                if let newRefresh = tokenResponse.refreshToken {
                    tokenStore.refreshToken = newRefresh
                }
                return OutlookSignInResult(
                    accessToken: tokenResponse.accessToken,
                    homeAccountId: tokenStore.homeAccountId ?? "",
                    username: tokenStore.username ?? "",
                    expiresOn: cachedAccessTokenExpiry
                )
            } catch {
                // fall through to interactive sign-in
            }
        }
        return try await signIn()
    }

    // MARK: - HTTP

    private struct TokenResponse {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
    }

    private struct UserInfo {
        let id: String
        let username: String
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://login.microsoftonline.com/\(OutlookConfig.tenantId)/oauth2/v2.0/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": OutlookConfig.clientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": OutlookConfig.redirectUri,
            "code_verifier": codeVerifier,
            "scope": (scopes + ["offline_access"]).joined(separator: " "),
        ]
        req.httpBody = Self.formEncode(body).data(using: .utf8)
        return try await postToken(request: req)
    }

    private func refreshAccessToken(refreshToken: String) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://login.microsoftonline.com/\(OutlookConfig.tenantId)/oauth2/v2.0/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": OutlookConfig.clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": (scopes + ["offline_access"]).joined(separator: " "),
        ]
        req.httpBody = Self.formEncode(body).data(using: .utf8)
        return try await postToken(request: req)
    }

    private func postToken(request: URLRequest) async throws -> TokenResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status >= 400 {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw MSALAuthError.tokenExchangeFailed("HTTP \(status): \(bodyStr.prefix(400))")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = obj["access_token"] as? String,
              let expiresIn = obj["expires_in"] as? Int else {
            throw MSALAuthError.tokenExchangeFailed("응답 파싱 실패")
        }
        let refresh = obj["refresh_token"] as? String
        return TokenResponse(accessToken: accessToken, refreshToken: refresh, expiresIn: expiresIn)
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var req = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me?$select=id,userPrincipalName,mail,displayName")!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status >= 400 {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw MSALAuthError.invalidResponse("HTTP \(status): \(bodyStr.prefix(400))")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["id"] as? String else {
            throw MSALAuthError.invalidResponse("/me 응답 파싱 실패")
        }
        let upn = obj["userPrincipalName"] as? String
        let mail = obj["mail"] as? String
        let displayName = obj["displayName"] as? String
        let username = upn ?? mail ?? displayName ?? id
        return UserInfo(id: id, username: username)
    }

    // MARK: - PKCE & helpers

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return params.map { k, v in
            let ek = k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k
            let ev = v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v
            return "\(ek)=\(ev)"
        }.joined(separator: "&")
    }

    // MARK: - Browser session

    private func runAuthSession(authURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "msauth.com.jyp.EdgeLauncher"
            ) { callback, error in
                if let nsErr = error as NSError?,
                   nsErr.domain == ASWebAuthenticationSessionErrorDomain,
                   nsErr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    cont.resume(throwing: MSALAuthError.userCancelled)
                    return
                }
                if let error {
                    cont.resume(throwing: MSALAuthError.acquireFailed(error))
                    return
                }
                guard let callback else {
                    cont.resume(throwing: MSALAuthError.invalidResponse("콜백 URL 없음"))
                    return
                }
                cont.resume(returning: callback)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                cont.resume(throwing: MSALAuthError.acquireFailed(NSError(
                    domain: "ASWebAuthenticationSession", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "세션 시작 실패"]
                )))
            }
        }
    }
}

extension MSALAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.mainWindow ?? NSApp.windows.first ?? NSWindow()
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        var s = base64EncodedString()
        s = s.replacingOccurrences(of: "+", with: "-")
        s = s.replacingOccurrences(of: "/", with: "_")
        s = s.replacingOccurrences(of: "=", with: "")
        return s
    }
}
