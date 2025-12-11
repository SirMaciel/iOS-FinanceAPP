import Foundation

struct User: Codable {
    let id: String
    let name: String
    let lastName: String?
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case lastName = "last_name"
        case email
    }

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
