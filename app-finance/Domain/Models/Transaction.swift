import Foundation
import SwiftData

// MARK: - Sync Status

enum SyncStatus: String, Codable {
    case pending      // Criado/modificado localmente, aguardando sync
    case synced       // Sincronizado com servidor
    case pendingDelete // Marcado para deletar no servidor
}

// MARK: - Transaction Model

@Model
final class Transaction: Identifiable {
    @Attribute(.unique) var id: String
    var serverId: String?  // ID do servidor (pode ser diferente do local)
    var userId: String
    var categoryId: String?
    var type: TransactionType
    var amount: Decimal
    var date: Date
    var desc: String
    var aiConfidence: Double?
    var aiJustification: String?
    var needsUserReview: Bool
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String  // SyncStatus.rawValue
    var lastSyncAttempt: Date?
    var syncError: String?

    init(
        id: String = UUID().uuidString,
        serverId: String? = nil,
        userId: String,
        categoryId: String? = nil,
        type: TransactionType,
        amount: Decimal,
        date: Date,
        description: String,
        aiConfidence: Double? = nil,
        aiJustification: String? = nil,
        needsUserReview: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        lastSyncAttempt: Date? = nil,
        syncError: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.userId = userId
        self.categoryId = categoryId
        self.type = type
        self.amount = amount
        self.date = date
        self.desc = description
        self.aiConfidence = aiConfidence
        self.aiJustification = aiJustification
        self.needsUserReview = needsUserReview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus.rawValue
        self.lastSyncAttempt = lastSyncAttempt
        self.syncError = syncError
    }

    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    var isPendingSync: Bool {
        syncStatusEnum == .pending || syncStatusEnum == .pendingDelete
    }

    func markAsSynced(serverId: String) {
        self.serverId = serverId
        self.syncStatusEnum = .synced
        self.syncError = nil
        self.lastSyncAttempt = Date()
    }

    func markAsModified() {
        self.updatedAt = Date()
        if syncStatusEnum == .synced {
            self.syncStatusEnum = .pending
        }
    }

    func markForDeletion() {
        self.syncStatusEnum = .pendingDelete
    }
}

enum TransactionType: String, Codable {
    case expense
    case income
}

extension Transaction {
    var amountDouble: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}
