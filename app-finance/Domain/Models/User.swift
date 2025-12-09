import Foundation

struct User: Codable {
    let id: String
    let name: String
    let lastName: String?
    let email: String

    var fullName: String {
        if let lastName = lastName, !lastName.isEmpty {
            return "\(name) \(lastName)"
        }
        return name
    }
}

struct UserSession {
    let user: User
    let token: String
}
