import Foundation

struct CreateTransactionRequest: Codable {
    let type: String
    let amount: Double
    let date: String
    let description: String
    let categoryId: String?
}

struct TransactionResponse: Codable {
    let id: String
    let userId: String?
    let categoryId: String?
    let type: String
    let amount: Double
    let date: String
    let description: String
    let aiConfidence: Double?
    let aiJustification: String?
    let needsUserReview: Bool?
    let category: CategoryDTO?
}

struct CategoryDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
}

struct UpdateTransactionCategoryRequest: Codable {
    let categoryId: String
}

class TransactionsAPI {
    static let shared = TransactionsAPI()
    private let client = APIClient.shared

    private init() {}

    func getByMonth(month: String) async throws -> [TransactionResponse] {
        return try await client.request("/transactions?month=\(month)")
    }

    func create(
        type: TransactionType,
        amount: Decimal,
        date: Date,
        description: String,
        categoryId: String? = nil
    ) async throws -> TransactionResponse {
        let dateString = ISO8601DateFormatter().string(from: date).prefix(10)
        let request = CreateTransactionRequest(
            type: type.rawValue,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            date: String(dateString),
            description: description,
            categoryId: categoryId
        )
        return try await client.request("/transactions", method: "POST", body: request)
    }

    func updateCategory(transactionId: String, categoryId: String) async throws -> TransactionResponse {
        let request = UpdateTransactionCategoryRequest(categoryId: categoryId)
        return try await client.request(
            "/transactions/\(transactionId)/category",
            method: "PATCH",
            body: request
        )
    }

    func delete(transactionId: String) async throws {
        try await client.requestVoid("/transactions/\(transactionId)", method: "DELETE")
    }
}
