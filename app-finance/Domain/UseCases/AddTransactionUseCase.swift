import Foundation
import SwiftData

class AddTransactionUseCase {
    func execute(
        type: TransactionType,
        amount: Decimal,
        date: Date,
        description: String,
        categoryId: String? = nil,
        userId: String,
        context: ModelContext
    ) async throws -> TransactionResponse {
        let response = try await TransactionsAPI.shared.create(
            type: type,
            amount: amount,
            date: date,
            description: description,
            categoryId: categoryId
        )

        // Salvar localmente
        let localTransaction = response.toLocal(context: context, userId: userId)
        context.insert(localTransaction)
        try context.save()

        return response
    }
}
