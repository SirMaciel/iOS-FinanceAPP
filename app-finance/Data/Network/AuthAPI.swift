import Foundation

// MARK: - Request Models

struct RegisterRequest: Codable {
    let name: String
    let email: String
    let password: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct VerifyEmailRequest: Codable {
    let userId: String
    let code: String
}

struct ResendCodeRequest: Codable {
    let userId: String
}

struct AppleAuthRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let appleUserId: String
    let email: String?
    let fullName: String?
}

struct GoogleAuthRequest: Codable {
    let idToken: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct VerifyResetCodeRequest: Codable {
    let email: String
    let code: String
}

struct VerifyResetCodeResponse: Codable {
    let resetToken: String
}

struct ResetPasswordRequest: Codable {
    let email: String
    let token: String
    let newPassword: String
}

// MARK: - Profile Request Models

struct UpdateProfileRequest: Codable {
    let name: String
    let lastName: String
}

struct RequestPasswordChangeRequest: Codable {
    let email: String
}

struct VerifyPasswordChangeCodeRequest: Codable {
    let email: String
    let code: String
}

struct ChangePasswordRequest: Codable {
    let token: String
    let newPassword: String
}

struct RequestEmailChangeRequest: Codable {
    let currentEmail: String
}

struct VerifyCurrentEmailCodeRequest: Codable {
    let email: String
    let code: String
}

struct SetNewEmailRequest: Codable {
    let token: String
    let newEmail: String
}

struct VerifyNewEmailCodeRequest: Codable {
    let token: String
    let code: String
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct RegisterResponse: Codable {
    let userId: String
    let message: String
}

struct VerifyEmailResponse: Codable {
    let token: String
    let user: User
}

struct MessageResponse: Codable {
    let message: String
}

struct UpdateProfileResponse: Codable {
    let user: User
}

struct PasswordChangeTokenResponse: Codable {
    let token: String
}

struct EmailChangeTokenResponse: Codable {
    let token: String
}

struct NewEmailSetResponse: Codable {
    let token: String
    let message: String
}

struct EmailChangeCompleteResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Login Result

enum LoginResult {
    case success(AuthResponse)
    case requiresVerification(userId: String, email: String)
}

// Response that can be either auth or verification required
struct LoginRawResponse: Codable {
    let token: String?
    let user: User?
    let requiresVerification: Bool?
    let userId: String?
    let email: String?
    let message: String?
}

// MARK: - Auth Errors

enum AuthError: Error {
    case emailAlreadyExists
    case invalidCredentials
    case invalidCode
    case codeExpired
    case emailNotVerified
    case userNotFound
    case networkError(Error)
    case unknown
}

// MARK: - Auth API

class AuthAPI {
    static let shared = AuthAPI()
    private let client = APIClient.shared

    private init() {}

    func register(name: String, email: String, password: String) async throws -> RegisterResponse {
        let request = RegisterRequest(name: name, email: email, password: password)
        do {
            return try await client.request("/auth/register", method: "POST", body: request)
        } catch APIError.httpError(let code, let message) {
            if code == 409 || message.contains("already") {
                throw AuthError.emailAlreadyExists
            }
            throw AuthError.unknown
        }
    }

    func login(email: String, password: String) async throws -> LoginResult {
        let request = LoginRequest(email: email, password: password)
        do {
            let response: LoginRawResponse = try await client.request("/auth/login", method: "POST", body: request)

            // Check if requires verification
            if response.requiresVerification == true,
               let userId = response.userId,
               let email = response.email {
                return .requiresVerification(userId: userId, email: email)
            }

            // Normal login success
            guard let token = response.token, let user = response.user else {
                throw AuthError.unknown
            }
            return .success(AuthResponse(token: token, user: user))
        } catch APIError.httpError(let code, _) {
            if code == 401 {
                throw AuthError.invalidCredentials
            }
            throw AuthError.unknown
        }
    }

    func verifyEmail(userId: String, code: String) async throws -> VerifyEmailResponse {
        let request = VerifyEmailRequest(userId: userId, code: code)
        do {
            return try await client.request("/auth/verify-email", method: "POST", body: request)
        } catch APIError.httpError(let code, let message) {
            if code == 400 {
                if message.contains("expired") {
                    throw AuthError.codeExpired
                }
                throw AuthError.invalidCode
            }
            throw AuthError.unknown
        }
    }

    func resendVerificationCode(userId: String) async throws -> MessageResponse {
        let request = ResendCodeRequest(userId: userId)
        return try await client.request("/auth/resend-code", method: "POST", body: request)
    }

    func loginWithApple(identityToken: String, authorizationCode: String, appleUserId: String, email: String?, fullName: String?) async throws -> AuthResponse {
        let request = AppleAuthRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            appleUserId: appleUserId,
            email: email,
            fullName: fullName
        )
        return try await client.request("/auth/apple", method: "POST", body: request)
    }

    func loginWithGoogle(idToken: String) async throws -> AuthResponse {
        let request = GoogleAuthRequest(idToken: idToken)
        return try await client.request("/auth/google", method: "POST", body: request)
    }

    func forgotPassword(email: String) async throws -> MessageResponse {
        let request = ForgotPasswordRequest(email: email)
        do {
            return try await client.request("/auth/forgot-password", method: "POST", body: request)
        } catch APIError.httpError(let code, _) {
            if code == 404 {
                throw AuthError.userNotFound
            }
            throw AuthError.unknown
        }
    }

    func verifyResetCode(email: String, code: String) async throws -> String {
        let request = VerifyResetCodeRequest(email: email, code: code)
        do {
            let response: VerifyResetCodeResponse = try await client.request("/auth/verify-reset-code", method: "POST", body: request)
            return response.resetToken
        } catch APIError.httpError(let code, let message) {
            if code == 400 {
                if message.contains("expired") || message.contains("expirado") {
                    throw AuthError.codeExpired
                }
                throw AuthError.invalidCode
            }
            throw AuthError.unknown
        }
    }

    func resetPassword(email: String, token: String, newPassword: String) async throws -> MessageResponse {
        let request = ResetPasswordRequest(email: email, token: token, newPassword: newPassword)
        do {
            return try await client.request("/auth/reset-password", method: "POST", body: request)
        } catch APIError.httpError(let code, _) {
            if code == 400 {
                throw AuthError.invalidCode
            }
            throw AuthError.unknown
        }
    }

    // MARK: - Profile Operations

    /// Atualiza nome e sobrenome do usuário
    func updateProfile(name: String, lastName: String) async throws -> UpdateProfileResponse {
        let request = UpdateProfileRequest(name: name, lastName: lastName)
        return try await client.request("/auth/profile", method: "PATCH", body: request)
    }

    /// Busca dados do usuário atual
    func getProfile() async throws -> User {
        return try await client.request("/auth/profile")
    }

    // MARK: - Change Password (with verification code)

    /// Solicita código de verificação para trocar senha
    func requestPasswordChange(email: String) async throws -> MessageResponse {
        let request = RequestPasswordChangeRequest(email: email)
        return try await client.request("/auth/change-password/request", method: "POST", body: request)
    }

    /// Verifica código e retorna token para trocar senha
    func verifyPasswordChangeCode(email: String, code: String) async throws -> String {
        let request = VerifyPasswordChangeCodeRequest(email: email, code: code)
        do {
            let response: PasswordChangeTokenResponse = try await client.request("/auth/change-password/verify", method: "POST", body: request)
            return response.token
        } catch APIError.httpError(let code, let message) {
            if code == 400 {
                if message.contains("expired") || message.contains("expirado") {
                    throw AuthError.codeExpired
                }
                throw AuthError.invalidCode
            }
            throw AuthError.unknown
        }
    }

    /// Troca a senha usando o token de verificação
    func changePassword(token: String, newPassword: String) async throws -> MessageResponse {
        let request = ChangePasswordRequest(token: token, newPassword: newPassword)
        return try await client.request("/auth/change-password/confirm", method: "POST", body: request)
    }

    // MARK: - Change Email (with dual verification)

    /// Solicita código de verificação no email atual
    func requestEmailChange(currentEmail: String) async throws -> MessageResponse {
        let request = RequestEmailChangeRequest(currentEmail: currentEmail)
        return try await client.request("/auth/change-email/request", method: "POST", body: request)
    }

    /// Verifica código do email atual e retorna token
    func verifyCurrentEmailCode(email: String, code: String) async throws -> String {
        let request = VerifyCurrentEmailCodeRequest(email: email, code: code)
        do {
            let response: EmailChangeTokenResponse = try await client.request("/auth/change-email/verify-current", method: "POST", body: request)
            return response.token
        } catch APIError.httpError(let code, let message) {
            if code == 400 {
                if message.contains("expired") || message.contains("expirado") {
                    throw AuthError.codeExpired
                }
                throw AuthError.invalidCode
            }
            throw AuthError.unknown
        }
    }

    /// Define novo email e envia código de verificação para ele
    func setNewEmail(token: String, newEmail: String) async throws -> String {
        let request = SetNewEmailRequest(token: token, newEmail: newEmail)
        do {
            let response: NewEmailSetResponse = try await client.request("/auth/change-email/set-new", method: "POST", body: request)
            return response.token
        } catch APIError.httpError(let code, let message) {
            if code == 409 || message.contains("already") {
                throw AuthError.emailAlreadyExists
            }
            throw AuthError.unknown
        }
    }

    /// Verifica código do novo email e completa a troca
    func verifyNewEmailCode(token: String, code: String) async throws -> EmailChangeCompleteResponse {
        let request = VerifyNewEmailCodeRequest(token: token, code: code)
        do {
            return try await client.request("/auth/change-email/verify-new", method: "POST", body: request)
        } catch APIError.httpError(let code, let message) {
            if code == 400 {
                if message.contains("expired") || message.contains("expirado") {
                    throw AuthError.codeExpired
                }
                throw AuthError.invalidCode
            }
            throw AuthError.unknown
        }
    }
}
