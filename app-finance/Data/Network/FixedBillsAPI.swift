import Foundation

// MARK: - Request/Response Models

struct CategorizeBillRequest: Codable {
    let name: String
    let amount: Double?
    let existingCategories: [ExistingCategoryRequest]?
}

struct ExistingCategoryRequest: Codable {
    let name: String
    let icon: String?
}

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

// MARK: - API

class FixedBillsAPI {
    static let shared = FixedBillsAPI()
    private let client = APIClient.shared

    private init() {}

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
