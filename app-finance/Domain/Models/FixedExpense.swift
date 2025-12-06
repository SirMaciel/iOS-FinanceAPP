import Foundation
import SwiftData

@Model
final class FixedExpense: Identifiable {
    @Attribute(.unique) var id: String
    var userId: String
    var desc: String
    var amount: Decimal
    var dueDay: Int     // Dia de vencimento (1 a 31)
    var isPaid: Bool    // Status de pagamento (para o ciclo atual)
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        description: String,
        amount: Decimal,
        dueDay: Int,
        isPaid: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.desc = description
        self.amount = amount
        self.dueDay = dueDay
        self.isPaid = isPaid
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension FixedExpense {
    var amountDouble: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}
