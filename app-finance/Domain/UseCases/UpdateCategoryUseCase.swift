import Foundation
import SwiftData

class UpdateCategoryUseCase {
    func execute(
        id: String,
        name: String?,
        colorHex: String?,
        iconName: String?,
        isActive: Bool?,
        context: ModelContext
    ) async throws -> CategoryResponse {
        let response = try await CategoriesAPI.shared.update(
            id: id,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            isActive: isActive
        )

        // Atualizar local
        if let local = try? context.fetch(
            FetchDescriptor<Category>(
                predicate: #Predicate { $0.id == id }
            )
        ).first {
            if let name = name { local.name = name }
            if let colorHex = colorHex { local.colorHex = colorHex }
            if let iconName = iconName { local.iconName = iconName }
            if let isActive = isActive { local.isActive = isActive }
            local.lastSyncAttempt = Date()
            local.syncStatusEnum = .synced
            try context.save()
        }

        return response
    }
}
