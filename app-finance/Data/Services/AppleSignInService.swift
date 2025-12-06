import AuthenticationServices
import Combine
import CryptoKit

class AppleSignInService: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private var currentNonce: String?
    private var completion: ((Result<AppleSignInResult, Error>) -> Void)?

    struct AppleSignInResult {
        let identityToken: String
        let authorizationCode: String
        let userId: String
        let email: String?
        let fullName: PersonNameComponents?
    }

    func signIn(completion: @escaping (Result<AppleSignInResult, Error>) -> Void) {
        self.completion = completion
        self.isLoading = true
        self.error = nil

        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isLoading = false

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion?(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Credencial inválida"])))
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            completion?(.failure(NSError(domain: "AppleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Token de identidade inválido"])))
            return
        }

        guard let authorizationCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            completion?(.failure(NSError(domain: "AppleSignIn", code: -3, userInfo: [NSLocalizedDescriptionKey: "Código de autorização inválido"])))
            return
        }

        let result = AppleSignInResult(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            userId: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: appleIDCredential.fullName
        )

        completion?(.success(result))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false

        let nsError = error as NSError
        if nsError.code == ASAuthorizationError.canceled.rawValue {
            self.error = nil // Usuário cancelou, não é erro
            completion?(.failure(NSError(domain: "AppleSignIn", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cancelado pelo usuário"])))
        } else {
            self.error = error.localizedDescription
            completion?(.failure(error))
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
