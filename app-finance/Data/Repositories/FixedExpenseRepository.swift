import Foundation
import SwiftData
import Combine

@MainActor
final class FixedExpenseRepository: ObservableObject {
    static let shared = FixedExpenseRepository()

    private let context: ModelContext

    private init() {
        self.context = SwiftDataStack.shared.context
    }

    // MARK: - Read Operations

    func getFixedExpenses(userId: String) -> [FixedExpense] {
        let descriptor = FetchDescriptor<FixedExpense>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.dueDay), SortDescriptor(\.desc)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [FixedExpenseRepo] Erro ao buscar contas fixas: \(error)")
            return []
        }
    }

    // MARK: - Write Operations

    func createFixedExpense(
        userId: String,
        description: String,
        amount: Decimal,
        dueDay: Int
    ) -> FixedExpense {
        let expense = FixedExpense(
            userId: userId,
            description: description,
            amount: amount,
            dueDay: dueDay
        )

        context.insert(expense)

        do {
            try context.save()
            print("📅 [FixedExpenseRepo] Conta fixa criada: \(description)")
        } catch {
            print("❌ [FixedExpenseRepo] Erro ao salvar conta fixa: \(error)")
        }

        return expense
    }

    func deleteFixedExpense(_ expense: FixedExpense) {
        context.delete(expense)

        do {
            try context.save()
            print("📅 [FixedExpenseRepo] Conta fixa removida")
        } catch {
            print("❌ [FixedExpenseRepo] Erro ao remover conta fixa: \(error)")
        }
    }
    
    // Simples toggle de pagamento
    func togglePaidStatus(_ expense: FixedExpense) {
        expense.isPaid.toggle()
        expense.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
             print("❌ [FixedExpenseRepo] Erro ao atualizar status: \(error)")
        }
    }
}
