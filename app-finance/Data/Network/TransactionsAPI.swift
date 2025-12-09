import Foundation

// MARK: - Request Models

struct CreateTransactionRequest: Codable {
    let type: String
    let amount: Double
    let date: String
    let description: String
    let categoryId: String?
    let creditCardId: String?
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let cityName: String?
    let installments: Int?
    let startingInstallment: Int?
    let notes: String?
    let paymentMethod: String?
}

struct UpdateTransactionRequest: Codable {
    let type: String?
    let amount: Double?
    let date: String?
    let description: String?
    let categoryId: String?
    let creditCardId: String?
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let cityName: String?
    let installments: Int?
    let startingInstallment: Int?
    let notes: String?
    let paymentMethod: String?
}

struct UpdateTransactionCategoryRequest: Codable {
    let categoryId: String
}

// MARK: - Response Models

struct TransactionResponse: Codable {
    let id: String
    let userId: String?
    let categoryId: String?
    let creditCardId: String?
    let type: String
    let amount: Double
    let date: String
    let description: String
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let cityName: String?
    let installments: Int?
    let startingInstallment: Int?
    let notes: String?
    let paymentMethod: String?
    let aiConfidence: Double?
    let aiJustification: String?
    let needsUserReview: Bool?
    let category: CategoryDTO?
    let createdAt: String?
    let updatedAt: String?
}

struct CategoryDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
}

// MARK: - API

class TransactionsAPI {
    static let shared = TransactionsAPI()
    private let client = APIClient.shared

    private init() {}

    // MARK: - Read Operations

    func getAll() async throws -> [TransactionResponse] {
        return try await client.request("/transactions")
    }

    func getByMonth(month: String) async throws -> [TransactionResponse] {
        return try await client.request("/transactions?month=\(month)")
    }

    func getById(_ id: String) async throws -> TransactionResponse {
        return try await client.request("/transactions/\(id)")
    }

    // MARK: - Create Operations

    func create(
        type: TransactionType,
        amount: Decimal,
        date: Date,
        description: String,
        categoryId: String? = nil,
        creditCardId: String? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        cityName: String? = nil,
        installments: Int? = nil,
        startingInstallment: Int? = nil,
        notes: String? = nil,
        paymentMethod: String? = nil
    ) async throws -> TransactionResponse {
        let dateString = ISO8601DateFormatter().string(from: date).prefix(10)
        let request = CreateTransactionRequest(
            type: type.rawValue,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            date: String(dateString),
            description: description,
            categoryId: categoryId,
            creditCardId: creditCardId,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            installments: installments,
            startingInstallment: startingInstallment,
            notes: notes,
            paymentMethod: paymentMethod
        )
        return try await client.request("/transactions", method: "POST", body: request)
    }

    /// Create a transaction from a local Transaction model
    /// Note: categoryId and creditCardId should be resolved to server IDs by the caller
    func create(from transaction: Transaction, serverCategoryId: String? = nil, serverCreditCardId: String? = nil) async throws -> TransactionResponse {
        return try await create(
            type: transaction.type,
            amount: transaction.amount,
            date: transaction.date,
            description: transaction.desc,
            categoryId: serverCategoryId,
            creditCardId: serverCreditCardId,
            locationName: transaction.locationName,
            latitude: transaction.latitude,
            longitude: transaction.longitude,
            cityName: transaction.cityName,
            installments: transaction.installments,
            startingInstallment: transaction.startingInstallment,
            notes: transaction.notes,
            paymentMethod: transaction.paymentMethod
        )
    }

    // MARK: - Update Operations

    func update(
        id: String,
        type: String? = nil,
        amount: Double? = nil,
        date: String? = nil,
        description: String? = nil,
        categoryId: String? = nil,
        creditCardId: String? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        cityName: String? = nil,
        installments: Int? = nil,
        startingInstallment: Int? = nil,
        notes: String? = nil,
        paymentMethod: String? = nil
    ) async throws -> TransactionResponse {
        let request = UpdateTransactionRequest(
            type: type,
            amount: amount,
            date: date,
            description: description,
            categoryId: categoryId,
            creditCardId: creditCardId,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            installments: installments,
            startingInstallment: startingInstallment,
            notes: notes,
            paymentMethod: paymentMethod
        )
        return try await client.request("/transactions/\(id)", method: "PATCH", body: request)
    }

    /// Update a transaction from a local Transaction model
    /// Note: categoryId and creditCardId should be resolved to server IDs by the caller
    func update(from transaction: Transaction, serverCategoryId: String? = nil, serverCreditCardId: String? = nil) async throws -> TransactionResponse {
        guard let serverId = transaction.serverId else {
            throw APIError.invalidURL
        }
        let dateString = ISO8601DateFormatter().string(from: transaction.date).prefix(10)
        return try await update(
            id: serverId,
            type: transaction.type.rawValue,
            amount: NSDecimalNumber(decimal: transaction.amount).doubleValue,
            date: String(dateString),
            description: transaction.desc,
            categoryId: serverCategoryId,
            creditCardId: serverCreditCardId,
            locationName: transaction.locationName,
            latitude: transaction.latitude,
            longitude: transaction.longitude,
            cityName: transaction.cityName,
            installments: transaction.installments,
            startingInstallment: transaction.startingInstallment,
            notes: transaction.notes,
            paymentMethod: transaction.paymentMethod
        )
    }

    func updateCategory(transactionId: String, categoryId: String) async throws -> TransactionResponse {
        let request = UpdateTransactionCategoryRequest(categoryId: categoryId)
        return try await client.request(
            "/transactions/\(transactionId)/category",
            method: "PATCH",
            body: request
        )
    }

    // MARK: - Delete Operations

    func delete(transactionId: String) async throws {
        try await client.requestVoid("/transactions/\(transactionId)", method: "DELETE")
    }
}
