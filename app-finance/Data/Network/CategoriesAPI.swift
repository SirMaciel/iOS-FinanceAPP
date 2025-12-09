import Foundation

// MARK: - Response Models

struct CategoryResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let colorHex: String
    let iconName: String
    let isActive: Bool
    let displayOrder: Int?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Request Models

struct CreateCategoryRequest: Codable {
    let name: String
    let colorHex: String
    let iconName: String?
    let displayOrder: Int?
}

struct UpdateCategoryRequest: Codable {
    let name: String?
    let colorHex: String?
    let iconName: String?
    let isActive: Bool?
    let displayOrder: Int?
}

// MARK: - API

class CategoriesAPI {
    static let shared = CategoriesAPI()
    private let client = APIClient.shared

    private init() {}

    // MARK: - Read Operations

    func getAll() async throws -> [CategoryResponse] {
        return try await client.request("/categories")
    }

    func getById(_ id: String) async throws -> CategoryResponse {
        return try await client.request("/categories/\(id)")
    }

    // MARK: - Create Operations

    func create(
        name: String,
        colorHex: String,
        iconName: String = "tag",
        displayOrder: Int? = nil
    ) async throws -> CategoryResponse {
        let request = CreateCategoryRequest(
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            displayOrder: displayOrder
        )
        return try await client.request("/categories", method: "POST", body: request)
    }

    /// Create a category from a local Category model
    func create(from category: Category) async throws -> CategoryResponse {
        return try await create(
            name: category.name,
            colorHex: category.colorHex,
            iconName: category.iconName,
            displayOrder: category.displayOrder
        )
    }

    // MARK: - Update Operations

    func update(
        id: String,
        name: String? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        isActive: Bool? = nil,
        displayOrder: Int? = nil
    ) async throws -> CategoryResponse {
        let request = UpdateCategoryRequest(
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            isActive: isActive,
            displayOrder: displayOrder
        )
        return try await client.request("/categories/\(id)", method: "PATCH", body: request)
    }

    /// Update a category from a local Category model
    func update(from category: Category) async throws -> CategoryResponse {
        guard let serverId = category.serverId else {
            throw APIError.invalidURL
        }
        return try await update(
            id: serverId,
            name: category.name,
            colorHex: category.colorHex,
            iconName: category.iconName,
            isActive: category.isActive,
            displayOrder: category.displayOrder
        )
    }

    // MARK: - Delete Operations

    func delete(id: String) async throws {
        try await client.requestVoid("/categories/\(id)", method: "DELETE")
    }
}
