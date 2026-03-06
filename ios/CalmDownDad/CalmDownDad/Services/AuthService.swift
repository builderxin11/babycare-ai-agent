import Foundation
import CryptoKit

// MARK: - AuthService (Cognito Authentication)

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var currentUser: AuthUser?
    @Published var isLoading = false
    @Published var error: AuthError?

    private let userPoolId: String
    private let clientId: String
    private let region: String
    private let session: URLSession

    // Token storage keys
    private let accessTokenKey = "cognito_access_token"
    private let refreshTokenKey = "cognito_refresh_token"
    private let idTokenKey = "cognito_id_token"
    private let userIdKey = "cognito_user_id"
    private let userEmailKey = "cognito_user_email"

    private init() {
        // Load from amplify_outputs.json or use defaults
        self.userPoolId = "us-west-2_74ZgBPACM"
        self.clientId = "536dddrl7ju962f8bb5qe5b4rn"
        self.region = "us-west-2"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: config)

        // Check for existing session
        loadStoredSession()
    }

    // MARK: - Public API

    /// Sign up a new user with email and password
    func signUp(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let endpoint = cognitoEndpoint

        let payload: [String: Any] = [
            "ClientId": clientId,
            "Username": email,
            "Password": password,
            "UserAttributes": [
                ["Name": "email", "Value": email]
            ]
        ]

        let response: SignUpResponse = try await cognitoRequest(
            endpoint: endpoint,
            action: "AWSCognitoIdentityProviderService.SignUp",
            payload: payload
        )

        if !response.UserConfirmed {
            throw AuthError.confirmationRequired
        }
    }

    /// Confirm sign up with verification code
    func confirmSignUp(email: String, code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let payload: [String: Any] = [
            "ClientId": clientId,
            "Username": email,
            "ConfirmationCode": code
        ]

        let _: EmptyResponse = try await cognitoRequest(
            endpoint: cognitoEndpoint,
            action: "AWSCognitoIdentityProviderService.ConfirmSignUp",
            payload: payload
        )
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let payload: [String: Any] = [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": clientId,
            "AuthParameters": [
                "USERNAME": email,
                "PASSWORD": password
            ]
        ]

        let response: AuthResponse = try await cognitoRequest(
            endpoint: cognitoEndpoint,
            action: "AWSCognitoIdentityProviderService.InitiateAuth",
            payload: payload
        )

        guard let result = response.AuthenticationResult else {
            if response.ChallengeName == "NEW_PASSWORD_REQUIRED" {
                throw AuthError.newPasswordRequired
            }
            throw AuthError.authenticationFailed("No authentication result")
        }

        // Store tokens
        storeTokens(
            accessToken: result.AccessToken,
            refreshToken: result.RefreshToken,
            idToken: result.IdToken
        )

        // Get user info
        try await fetchUserInfo()

        isAuthenticated = true
    }

    /// Sign out the current user
    func signOut() {
        clearStoredSession()
        isAuthenticated = false
        currentUser = nil
    }

    /// Resend confirmation code
    func resendConfirmationCode(email: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let payload: [String: Any] = [
            "ClientId": clientId,
            "Username": email
        ]

        let _: EmptyResponse = try await cognitoRequest(
            endpoint: cognitoEndpoint,
            action: "AWSCognitoIdentityProviderService.ResendConfirmationCode",
            payload: payload
        )
    }

    /// Get the current access token (refreshes if needed)
    func getAccessToken() async throws -> String {
        guard let accessToken = UserDefaults.standard.string(forKey: accessTokenKey) else {
            throw AuthError.notAuthenticated
        }

        // TODO: Check if token is expired and refresh if needed
        return accessToken
    }

    // MARK: - Private Methods

    private var cognitoEndpoint: URL {
        URL(string: "https://cognito-idp.\(region).amazonaws.com")!
    }

    private func cognitoRequest<T: Decodable>(
        endpoint: URL,
        action: String,
        payload: [String: Any]
    ) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue(action, forHTTPHeaderField: "X-Amz-Target")

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            // Parse Cognito error
            if let errorResponse = try? JSONDecoder().decode(CognitoError.self, from: data) {
                throw AuthError.cognitoError(errorResponse.message ?? errorResponse.__type)
            }
            throw AuthError.networkError("HTTP \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func fetchUserInfo() async throws {
        guard let accessToken = UserDefaults.standard.string(forKey: accessTokenKey) else {
            throw AuthError.notAuthenticated
        }

        let payload: [String: Any] = [
            "AccessToken": accessToken
        ]

        let response: GetUserResponse = try await cognitoRequest(
            endpoint: cognitoEndpoint,
            action: "AWSCognitoIdentityProviderService.GetUser",
            payload: payload
        )

        let email = response.UserAttributes.first { $0.Name == "email" }?.Value ?? ""
        let userId = response.Username

        currentUser = AuthUser(id: userId, email: email)

        UserDefaults.standard.set(userId, forKey: userIdKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)
    }

    private func storeTokens(accessToken: String, refreshToken: String?, idToken: String) {
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(idToken, forKey: idTokenKey)
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        }
    }

    private func loadStoredSession() {
        guard let accessToken = UserDefaults.standard.string(forKey: accessTokenKey),
              let userId = UserDefaults.standard.string(forKey: userIdKey),
              let email = UserDefaults.standard.string(forKey: userEmailKey),
              !accessToken.isEmpty else {
            return
        }

        currentUser = AuthUser(id: userId, email: email)
        isAuthenticated = true
    }

    private func clearStoredSession() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: idTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
    }
}

// MARK: - Models

struct AuthUser: Identifiable {
    let id: String
    let email: String
}

// MARK: - Cognito Response Models

private struct SignUpResponse: Decodable {
    let UserConfirmed: Bool
    let UserSub: String
}

private struct AuthResponse: Decodable {
    let AuthenticationResult: AuthenticationResult?
    let ChallengeName: String?
}

private struct AuthenticationResult: Decodable {
    let AccessToken: String
    let RefreshToken: String?
    let IdToken: String
    let ExpiresIn: Int
    let TokenType: String
}

private struct GetUserResponse: Decodable {
    let Username: String
    let UserAttributes: [UserAttribute]
}

private struct UserAttribute: Decodable {
    let Name: String
    let Value: String
}

private struct EmptyResponse: Decodable {}

private struct CognitoError: Decodable {
    let __type: String
    let message: String?
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case confirmationRequired
    case newPasswordRequired
    case notAuthenticated
    case authenticationFailed(String)
    case networkError(String)
    case cognitoError(String)

    var errorDescription: String? {
        switch self {
        case .confirmationRequired:
            return L10n.confirmationRequired
        case .newPasswordRequired:
            return L10n.newPasswordRequired
        case .notAuthenticated:
            return L10n.notAuthenticated
        case .authenticationFailed(let msg):
            return "\(L10n.authenticationFailed): \(msg)"
        case .networkError(let msg):
            return "\(L10n.networkError): \(msg)"
        case .cognitoError(let msg):
            return msg
        }
    }
}
