import Foundation

struct User: Codable {
    let id: String
    let name: String
    let email: String
}

struct UserSession {
    let user: User
    let token: String
}
