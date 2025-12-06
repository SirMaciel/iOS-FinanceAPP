import Foundation
import SwiftData

// MARK: - Credit Card Repository

@MainActor
final class CreditCardRepository {
    static let shared = CreditCardRepository()

    private let context: ModelContext

    private init() {
        self.context = SwiftDataStack.shared.context
    }

    // MARK: - Read Operations

    func getCreditCards(userId: String) -> [CreditCard] {
        let descriptor = FetchDescriptor<CreditCard>(
            predicate: #Predicate {
                $0.userId == userId && $0.isActive == true
            },
            sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.cardName)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [CreditCardRepo] Erro ao buscar cartões: \(error)")
            return []
        }
    }

    func getCreditCard(id: String) -> CreditCard? {
        let descriptor = FetchDescriptor<CreditCard>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - Write Operations

    func createCreditCard(
        userId: String,
        cardName: String,
        holderName: String,
        lastFourDigits: String,
        brand: CardBrand,
        cardType: CardType,
        bank: Bank,
        paymentDay: Int,
        closingDay: Int,
        limitAmount: Decimal
    ) -> CreditCard {
        // Determinar próxima ordem
        let existingCards = getCreditCards(userId: userId)
        let maxOrder = existingCards.map { $0.displayOrder }.max() ?? -1

        let card = CreditCard(
            userId: userId,
            cardName: cardName,
            holderName: holderName,
            lastFourDigits: lastFourDigits,
            brand: brand,
            cardType: cardType,
            bank: bank,
            paymentDay: paymentDay,
            closingDay: closingDay,
            limitAmount: limitAmount,
            displayOrder: maxOrder + 1
        )

        context.insert(card)

        do {
            try context.save()
            print("💳 [CreditCardRepo] Cartão criado: \(cardName)")
        } catch {
            print("❌ [CreditCardRepo] Erro ao criar cartão: \(error)")
        }

        return card
    }

    func updateCreditCard(
        _ card: CreditCard,
        cardName: String? = nil,
        holderName: String? = nil,
        lastFourDigits: String? = nil,
        brand: CardBrand? = nil,
        cardType: CardType? = nil,
        bank: Bank? = nil,
        paymentDay: Int? = nil,
        closingDay: Int? = nil,
        limitAmount: Decimal? = nil
    ) {
        if let cardName = cardName { card.cardName = cardName }
        if let holderName = holderName { card.holderName = holderName }
        if let lastFourDigits = lastFourDigits { card.lastFourDigits = lastFourDigits }
        if let brand = brand { card.brandEnum = brand }
        if let cardType = cardType { card.cardTypeEnum = cardType }
        if let bank = bank { card.bankEnum = bank }
        if let paymentDay = paymentDay { card.paymentDay = paymentDay }
        if let closingDay = closingDay { card.closingDay = closingDay }
        if let limitAmount = limitAmount { card.limitAmount = limitAmount }

        card.updatedAt = Date()

        do {
            try context.save()
            print("💳 [CreditCardRepo] Cartão atualizado: \(card.cardName)")
        } catch {
            print("❌ [CreditCardRepo] Erro ao atualizar cartão: \(error)")
        }
    }

    func deleteCreditCard(_ card: CreditCard) {
        card.isActive = false
        card.updatedAt = Date()

        do {
            try context.save()
            print("💳 [CreditCardRepo] Cartão removido: \(card.cardName)")
        } catch {
            print("❌ [CreditCardRepo] Erro ao remover cartão: \(error)")
        }
    }

    func reorderCreditCards(_ cards: [CreditCard]) {
        for (index, card) in cards.enumerated() {
            card.displayOrder = index
        }

        do {
            try context.save()
            print("💳 [CreditCardRepo] Cartões reordenados")
        } catch {
            print("❌ [CreditCardRepo] Erro ao reordenar cartões: \(error)")
        }
    }
}
