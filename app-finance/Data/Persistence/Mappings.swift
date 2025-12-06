import Foundation
import SwiftData

extension TransactionResponse {
    func toLocal(context: ModelContext, userId: String) -> Transaction {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: self.date) ?? Date()

        // Salvar categoria se vier do backend
        if let catDTO = category {
            let catDTOId = catDTO.id
            let allCats = (try? context.fetch(FetchDescriptor<Category>())) ?? []
            let existingCat = allCats.first { $0.id == catDTOId || $0.serverId == catDTOId }

            if existingCat == nil {
                let newCat = Category(
                    id: catDTO.id,
                    serverId: catDTO.id,
                    userId: userId,
                    name: catDTO.name,
                    colorHex: catDTO.colorHex,
                    iconName: catDTO.iconName,
                    syncStatus: .synced
                )
                context.insert(newCat)
            }
        }

        let transaction = Transaction(
            id: id,
            serverId: id,
            userId: userId,
            categoryId: categoryId,
            type: TransactionType(rawValue: type) ?? .expense,
            amount: Decimal(amount),
            date: date,
            description: description,
            aiConfidence: aiConfidence,
            aiJustification: aiJustification,
            needsUserReview: needsUserReview ?? false,
            syncStatus: .synced
        )

        return transaction
    }
}

extension CategoryResponse {
    func toLocal(context: ModelContext) -> Category {
        let category = Category(
            id: id,
            serverId: id,
            userId: userId,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            isActive: isActive,
            syncStatus: .synced
        )
        return category
    }
}
