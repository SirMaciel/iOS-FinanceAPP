import Foundation

struct CategoryResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let colorHex: String
    let iconName: String
    let isActive: Bool
}

struct CreateCategoryRequest: Codable {
    let name: String
    let colorHex: String
    let iconName: String?
}

struct UpdateCategoryRequest: Codable {
    let name: String?
    let colorHex: String?
    let iconName: String?
    let isActive: Bool?
}

class CategoriesAPI {
    static let shared = CategoriesAPI()
    private let client = APIClient.shared

    private init() {}

    func getAll() async throws -> [CategoryResponse] {
        return try await client.request("/categories")
    }

    func create(name: String, colorHex: String, iconName: String = "tag") async throws -> CategoryResponse {
        let request = CreateCategoryRequest(name: name, colorHex: colorHex, iconName: iconName)
        return try await client.request("/categories", method: "POST", body: request)
    }

    func update(id: String, name: String?, colorHex: String?, iconName: String?, isActive: Bool?) async throws -> CategoryResponse {
        let request = UpdateCategoryRequest(name: name, colorHex: colorHex, iconName: iconName, isActive: isActive)
        return try await client.request("/categories/\(id)", method: "PATCH", body: request)
    }

    func delete(id: String) async throws {
        try await client.requestVoid("/categories/\(id)", method: "DELETE")
    }
}
