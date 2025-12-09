import Foundation

// MARK: - Request Models

struct CreateCreditCardRequest: Codable {
    let cardName: String
    let holderName: String
    let lastFourDigits: String
    let brand: String
    let cardType: String
    let bank: String
    let paymentDay: Int
    let closingDay: Int
    let limitAmount: Double
    let isActive: Bool
    let displayOrder: Int
}

struct UpdateCreditCardRequest: Codable {
    let cardName: String?
    let holderName: String?
    let lastFourDigits: String?
    let brand: String?
    let cardType: String?
    let bank: String?
    let paymentDay: Int?
    let closingDay: Int?
    let limitAmount: Double?
    let isActive: Bool?
    let displayOrder: Int?
}

// MARK: - Response Model

struct CreditCardResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let cardName: String
    let holderName: String
    let lastFourDigits: String
    let brand: String
    let cardType: String
    let bank: String
    let paymentDay: Int
    let closingDay: Int
    let limitAmount: Double
    let isActive: Bool
    let displayOrder: Int
    let createdAt: String
    let updatedAt: String
}

// MARK: - API

class CreditCardsAPI {
    static let shared = CreditCardsAPI()
    private let client = APIClient.shared

    private init() {}

    /// Get all credit cards for the current user
    func getAll() async throws -> [CreditCardResponse] {
        return try await client.request("/credit-cards")
    }

    /// Get a single credit card by ID
    func getById(_ id: String) async throws -> CreditCardResponse {
        return try await client.request("/credit-cards/\(id)")
    }

    /// Create a new credit card
    func create(
        cardName: String,
        holderName: String,
        lastFourDigits: String,
        brand: String,
        cardType: String,
        bank: String,
        paymentDay: Int,
        closingDay: Int,
        limitAmount: Double,
        isActive: Bool = true,
        displayOrder: Int = 0
    ) async throws -> CreditCardResponse {
        let request = CreateCreditCardRequest(
            cardName: cardName,
            holderName: holderName,
            lastFourDigits: lastFourDigits,
            brand: brand,
            cardType: cardType,
            bank: bank,
            paymentDay: paymentDay,
            closingDay: closingDay,
            limitAmount: limitAmount,
            isActive: isActive,
            displayOrder: displayOrder
        )
        return try await client.request("/credit-cards", method: "POST", body: request)
    }

    /// Create a credit card from a local CreditCard model
    func create(from card: CreditCard) async throws -> CreditCardResponse {
        return try await create(
            cardName: card.cardName,
            holderName: card.holderName,
            lastFourDigits: card.lastFourDigits,
            brand: card.brand,
            cardType: card.cardType,
            bank: card.bank,
            paymentDay: card.paymentDay,
            closingDay: card.closingDay,
            limitAmount: NSDecimalNumber(decimal: card.limitAmount).doubleValue,
            isActive: card.isActive,
            displayOrder: card.displayOrder
        )
    }

    /// Update a credit card
    func update(
        id: String,
        cardName: String? = nil,
        holderName: String? = nil,
        lastFourDigits: String? = nil,
        brand: String? = nil,
        cardType: String? = nil,
        bank: String? = nil,
        paymentDay: Int? = nil,
        closingDay: Int? = nil,
        limitAmount: Double? = nil,
        isActive: Bool? = nil,
        displayOrder: Int? = nil
    ) async throws -> CreditCardResponse {
        let request = UpdateCreditCardRequest(
            cardName: cardName,
            holderName: holderName,
            lastFourDigits: lastFourDigits,
            brand: brand,
            cardType: cardType,
            bank: bank,
            paymentDay: paymentDay,
            closingDay: closingDay,
            limitAmount: limitAmount,
            isActive: isActive,
            displayOrder: displayOrder
        )
        return try await client.request("/credit-cards/\(id)", method: "PATCH", body: request)
    }

    /// Update a credit card from a local CreditCard model
    func update(from card: CreditCard) async throws -> CreditCardResponse {
        guard let serverId = card.serverId else {
            throw APIError.invalidURL
        }
        return try await update(
            id: serverId,
            cardName: card.cardName,
            holderName: card.holderName,
            lastFourDigits: card.lastFourDigits,
            brand: card.brand,
            cardType: card.cardType,
            bank: card.bank,
            paymentDay: card.paymentDay,
            closingDay: card.closingDay,
            limitAmount: NSDecimalNumber(decimal: card.limitAmount).doubleValue,
            isActive: card.isActive,
            displayOrder: card.displayOrder
        )
    }

    /// Delete a credit card
    func delete(id: String) async throws {
        try await client.requestVoid("/credit-cards/\(id)", method: "DELETE")
    }
}
