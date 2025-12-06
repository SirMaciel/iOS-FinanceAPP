import Foundation
import SwiftData
import Combine

// MARK: - Transaction Repository (Local-First)

@MainActor
final class TransactionRepository: ObservableObject {
    static let shared = TransactionRepository()

    @Published private(set) var isLoading = false

    private let context: ModelContext
    private let syncManager = SyncManager.shared

    private init() {
        self.context = SwiftDataStack.shared.context
    }

    // MARK: - Read Operations (Local First)

    /// Busca transações do mês - SEMPRE do local primeiro
    func getTransactions(month: String, userId: String) -> [Transaction] {
        // Parse month string (yyyy-MM)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        guard let startDate = formatter.date(from: month) else {
            return []
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        guard let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            return []
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.date >= startDate &&
                $0.date < endDate &&
                $0.syncStatus != "pendingDelete"
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [Repo] Erro ao buscar transações: \(error)")
            return []
        }
    }

    /// Busca transações e tenta sincronizar em background
    func getTransactionsWithSync(month: String, userId: String) async -> [Transaction] {
        // 1. Retornar dados locais imediatamente
        let localData = getTransactions(month: month, userId: userId)

        // 2. Sincronizar em background se conectado
        if NetworkMonitor.shared.isConnected {
            Task {
                await syncManager.syncAll()
            }
        }

        return localData
    }

    // MARK: - Write Operations (Local First)

    /// Criar transação - salva local primeiro, sync depois
    func createTransaction(
        userId: String,
        type: TransactionType,
        amount: Decimal,
        date: Date,
        description: String,
        categoryId: String? = nil
    ) -> Transaction {
        let transaction = Transaction(
            userId: userId,
            categoryId: categoryId,
            type: type,
            amount: amount,
            date: date,
            description: description,
            syncStatus: .pending
        )

        context.insert(transaction)

        do {
            try context.save()
            print("💾 [Repo] Transação salva localmente: \(description)")

            // Tentar sync em background
            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao salvar transação: \(error)")
        }

        return transaction
    }

    /// Atualizar categoria da transação
    func updateCategory(transaction: Transaction, categoryId: String) {
        transaction.categoryId = categoryId
        transaction.markAsModified()

        do {
            try context.save()
            print("💾 [Repo] Categoria atualizada localmente")

            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao atualizar categoria: \(error)")
        }
    }

    /// Deletar transação (soft delete para sync)
    func deleteTransaction(_ transaction: Transaction) {
        if transaction.serverId != nil {
            // Marcar para deletar no servidor
            transaction.markForDeletion()
        } else {
            // Se nunca foi sincronizado, deletar direto
            context.delete(transaction)
        }

        do {
            try context.save()
            print("💾 [Repo] Transação marcada para deleção")

            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao deletar transação: \(error)")
        }
    }

    // MARK: - Batch Operations

    /// Buscar todas transações pendentes de sync
    func getPendingTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Contar transações pendentes
    func getPendingCount() -> Int {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )

        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
