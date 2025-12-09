import Foundation

// MARK: - Request Models

struct CategorizeBillRequest: Codable {
    let name: String
    let amount: Double?
    let existingCategories: [ExistingCategoryRequest]?
}

struct ExistingCategoryRequest: Codable {
    let name: String
    let icon: String?
}

struct CreateFixedBillRequest: Codable {
    let name: String
    let amount: Double
    let dueDay: Int
    let category: String
    let isActive: Bool
    let notes: String?
    let customCategoryName: String?
    let customCategoryIcon: String?
    let customCategoryColorHex: String?
    let totalInstallments: Int?
    let paidInstallments: Int?
}

struct UpdateFixedBillRequest: Codable {
    let name: String?
    let amount: Double?
    let dueDay: Int?
    let category: String?
    let isActive: Bool?
    let notes: String?
    let customCategoryName: String?
    let customCategoryIcon: String?
    let customCategoryColorHex: String?
    let totalInstallments: Int?
    let paidInstallments: Int?
}

// MARK: - Response Models

struct CategorizeBillResponse: Codable {
    let category: String
    let confidence: Double
    let reasoning: String?
    let icon: String?
    let isCustom: Bool?
    let alternativeCategories: [AlternativeCategoryResponse]?
}

struct AlternativeCategoryResponse: Codable {
    let category: String
    let confidence: Double
}

struct FixedBillResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let amount: Double
    let dueDay: Int
    let category: String
    let isActive: Bool
    let notes: String?
    let customCategoryName: String?
    let customCategoryIcon: String?
    let customCategoryColorHex: String?
    let totalInstallments: Int?
    let paidInstallments: Int?
    let createdAt: String
    let updatedAt: String
}

// MARK: - API

class FixedBillsAPI {
    static let shared = FixedBillsAPI()
    private let client = APIClient.shared

    private init() {}

    // MARK: - CRUD Operations

    /// Get all fixed bills for the current user
    func getAll() async throws -> [FixedBillResponse] {
        return try await client.request("/fixed-bills")
    }

    /// Get a single fixed bill by ID
    func getById(_ id: String) async throws -> FixedBillResponse {
        return try await client.request("/fixed-bills/\(id)")
    }

    /// Create a new fixed bill
    func create(
        name: String,
        amount: Double,
        dueDay: Int,
        category: String,
        isActive: Bool = true,
        notes: String? = nil,
        customCategoryName: String? = nil,
        customCategoryIcon: String? = nil,
        customCategoryColorHex: String? = nil,
        totalInstallments: Int? = nil,
        paidInstallments: Int? = nil
    ) async throws -> FixedBillResponse {
        let request = CreateFixedBillRequest(
            name: name,
            amount: amount,
            dueDay: dueDay,
            category: category,
            isActive: isActive,
            notes: notes,
            customCategoryName: customCategoryName,
            customCategoryIcon: customCategoryIcon,
            customCategoryColorHex: customCategoryColorHex,
            totalInstallments: totalInstallments,
            paidInstallments: paidInstallments
        )
        return try await client.request("/fixed-bills", method: "POST", body: request)
    }

    /// Create a fixed bill from a local FixedBill model
    func create(from bill: FixedBill) async throws -> FixedBillResponse {
        return try await create(
            name: bill.name,
            amount: NSDecimalNumber(decimal: bill.amount).doubleValue,
            dueDay: bill.dueDay,
            category: bill.category.apiValue,
            isActive: bill.isActive,
            notes: bill.notes,
            customCategoryName: bill.customCategoryName,
            customCategoryIcon: bill.customCategoryIcon,
            customCategoryColorHex: bill.customCategoryColorHex,
            totalInstallments: bill.totalInstallments,
            paidInstallments: bill.paidInstallments
        )
    }

    /// Update a fixed bill
    func update(
        id: String,
        name: String? = nil,
        amount: Double? = nil,
        dueDay: Int? = nil,
        category: String? = nil,
        isActive: Bool? = nil,
        notes: String? = nil,
        customCategoryName: String? = nil,
        customCategoryIcon: String? = nil,
        customCategoryColorHex: String? = nil,
        totalInstallments: Int? = nil,
        paidInstallments: Int? = nil
    ) async throws -> FixedBillResponse {
        let request = UpdateFixedBillRequest(
            name: name,
            amount: amount,
            dueDay: dueDay,
            category: category,
            isActive: isActive,
            notes: notes,
            customCategoryName: customCategoryName,
            customCategoryIcon: customCategoryIcon,
            customCategoryColorHex: customCategoryColorHex,
            totalInstallments: totalInstallments,
            paidInstallments: paidInstallments
        )
        return try await client.request("/fixed-bills/\(id)", method: "PATCH", body: request)
    }

    /// Update a fixed bill from a local FixedBill model
    func update(from bill: FixedBill) async throws -> FixedBillResponse {
        guard let serverId = bill.serverId else {
            throw APIError.invalidURL
        }
        return try await update(
            id: serverId,
            name: bill.name,
            amount: NSDecimalNumber(decimal: bill.amount).doubleValue,
            dueDay: bill.dueDay,
            category: bill.category.apiValue,
            isActive: bill.isActive,
            notes: bill.notes,
            customCategoryName: bill.customCategoryName,
            customCategoryIcon: bill.customCategoryIcon,
            customCategoryColorHex: bill.customCategoryColorHex,
            totalInstallments: bill.totalInstallments,
            paidInstallments: bill.paidInstallments
        )
    }

    /// Delete a fixed bill
    func delete(id: String) async throws {
        try await client.requestVoid("/fixed-bills/\(id)", method: "DELETE")
    }

    // MARK: - AI Categorization

    /// Sugere categoria usando IA do servidor (GPT-5-nano, reasoning_effort: minimal)
    func suggestCategory(
        name: String,
        amount: Double? = nil,
        existingCategories: [ExistingCategoryRequest]? = nil
    ) async throws -> CategorizeBillResponse {
        let request = CategorizeBillRequest(
            name: name,
            amount: amount,
            existingCategories: existingCategories
        )
        return try await client.request("/fixed-bills/categorize", method: "POST", body: request)
    }
}

// MARK: - Category Mapping

extension CategorizeBillResponse {
    /// Converte a categoria string da API para o enum local
    var fixedBillCategory: FixedBillCategory {
        let normalized = category.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        switch normalized {
        case "moradia", "housing", "aluguel", "rent":
            return .housing
        case "utilidades", "utilities", "contas":
            return .utilities
        case "saude", "health":
            return .health
        case "educacao", "education":
            return .education
        case "transporte", "transport":
            return .transport
        case "entretenimento", "entertainment":
            return .entertainment
        case "assinatura", "subscription", "streaming":
            return .subscription
        case "seguro", "insurance":
            return .insurance
        case "financiamento", "financing":
            return .financing
        case "emprestimo", "loan":
            return .loan
        case "outros", "other":
            return .other
        default:
            return .other
        }
    }
}
