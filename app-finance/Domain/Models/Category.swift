import Foundation
import SwiftUI
import SwiftData

@Model
final class Category: Identifiable {
    @Attribute(.unique) var id: String
    var serverId: String?  // ID do servidor
    var userId: String
    var name: String
    var colorHex: String
    var iconName: String
    var isActive: Bool
    var displayOrder: Int  // Ordem de exibição para drag & drop
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String  // SyncStatus.rawValue
    var lastSyncAttempt: Date?
    var syncError: String?

    init(
        id: String = UUID().uuidString,
        serverId: String? = nil,
        userId: String,
        name: String,
        colorHex: String,
        iconName: String = "tag",
        isActive: Bool = true,
        displayOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        lastSyncAttempt: Date? = nil,
        syncError: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.userId = userId
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.isActive = isActive
        self.displayOrder = displayOrder
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

extension Category {
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
