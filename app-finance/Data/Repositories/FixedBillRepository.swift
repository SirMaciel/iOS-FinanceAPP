import Foundation
import SwiftData

@MainActor
class FixedBillRepository {
    static let shared = FixedBillRepository()

    private var context: ModelContext {
        SwiftDataStack.shared.context
    }

    private init() {}

    // MARK: - CRUD Operations

    /// Get all fixed bills for a user
    func getFixedBills(userId: String, activeOnly: Bool = false) -> [FixedBill] {
        let descriptor = FetchDescriptor<FixedBill>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.dueDay, order: .forward)]
        )

        guard let bills = try? context.fetch(descriptor) else {
            return []
        }

        if activeOnly {
            return bills.filter { $0.isActive }
        }
        return bills
    }

    /// Get a single fixed bill by ID
    func getFixedBill(id: String) -> FixedBill? {
        let descriptor = FetchDescriptor<FixedBill>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    /// Create a new fixed bill
    func createFixedBill(
        userId: String,
        name: String,
        amount: Decimal,
        dueDay: Int,
        category: FixedBillCategory,
        notes: String? = nil,
        customCategoryName: String? = nil,
        customCategoryIcon: String? = nil,
        customCategoryColorHex: String? = nil,
        totalInstallments: Int? = nil,
        paidInstallments: Int? = nil
    ) -> FixedBill {
        let bill = FixedBill(
            userId: userId,
            name: name,
            amount: amount,
            dueDay: dueDay,
            category: category,
            notes: notes,
            customCategoryName: customCategoryName,
            customCategoryIcon: customCategoryIcon,
            customCategoryColorHex: customCategoryColorHex,
            totalInstallments: totalInstallments,
            paidInstallments: paidInstallments
        )

        context.insert(bill)
        try? context.save()

        return bill
    }

    /// Update an existing fixed bill
    func updateFixedBill(
        _ bill: FixedBill,
        name: String,
        amount: Decimal,
        dueDay: Int,
        category: FixedBillCategory,
        notes: String?,
        isActive: Bool,
        customCategoryName: String? = nil,
        customCategoryIcon: String? = nil,
        customCategoryColorHex: String? = nil,
        totalInstallments: Int? = nil,
        paidInstallments: Int? = nil
    ) {
        bill.name = name
        bill.amount = amount
        bill.dueDay = dueDay
        bill.category = category
        bill.notes = notes
        bill.isActive = isActive
        bill.customCategoryName = customCategoryName
        bill.customCategoryIcon = customCategoryIcon
        bill.customCategoryColorHex = customCategoryColorHex
        bill.totalInstallments = totalInstallments
        bill.paidInstallments = paidInstallments
        bill.updatedAt = Date()

        try? context.save()
    }

    /// Toggle active status
    func toggleActive(_ bill: FixedBill) {
        bill.isActive.toggle()
        bill.updatedAt = Date()
        try? context.save()
    }

    /// Delete a fixed bill
    func deleteFixedBill(_ bill: FixedBill) {
        context.delete(bill)
        try? context.save()
    }

    // MARK: - Computed Totals

    /// Get total monthly amount for active bills
    func getTotalMonthlyAmount(userId: String) -> Double {
        let bills = getFixedBills(userId: userId, activeOnly: true)
        return bills.reduce(0) { $0 + $1.amountDouble }
    }

    /// Get bills due soon (within 7 days)
    func getBillsDueSoon(userId: String) -> [FixedBill] {
        let bills = getFixedBills(userId: userId, activeOnly: true)
        return bills.filter { $0.isDueSoon }
    }

    /// Get overdue bills
    func getOverdueBills(userId: String) -> [FixedBill] {
        let bills = getFixedBills(userId: userId, activeOnly: true)
        return bills.filter { $0.isOverdue }
    }

    /// Get bills by category
    func getBillsByCategory(userId: String) -> [FixedBillCategory: [FixedBill]] {
        let bills = getFixedBills(userId: userId, activeOnly: true)
        return Dictionary(grouping: bills) { $0.category }
    }
}
