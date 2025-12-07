import Foundation
import SwiftData
import SwiftUI

// MARK: - Fixed Bill Model

@Model
final class FixedBill: Identifiable {
    @Attribute(.unique) var id: String
    var userId: String
    var name: String
    var amount: Decimal
    var dueDay: Int // Dia do vencimento (1-31)
    var category: FixedBillCategory
    var isActive: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // Custom category fields (used when category == .custom)
    var customCategoryName: String?
    var customCategoryIcon: String?
    var customCategoryColorHex: String?

    // Installment fields (for financing)
    var totalInstallments: Int?
    var paidInstallments: Int?

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        amount: Decimal,
        dueDay: Int,
        category: FixedBillCategory = .other,
        isActive: Bool = true,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        customCategoryName: String? = nil,
        customCategoryIcon: String? = nil,
        customCategoryColorHex: String? = nil,
        totalInstallments: Int? = nil,
        paidInstallments: Int? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.category = category
        self.isActive = isActive
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.customCategoryName = customCategoryName
        self.customCategoryIcon = customCategoryIcon
        self.customCategoryColorHex = customCategoryColorHex
        self.totalInstallments = totalInstallments
        self.paidInstallments = paidInstallments
    }
}

// MARK: - Fixed Bill Category

enum FixedBillCategory: String, Codable, CaseIterable {
    case housing = "Moradia"
    case utilities = "Utilidades"
    case health = "Saúde"
    case education = "Educação"
    case transport = "Transporte"
    case entertainment = "Entretenimento"
    case subscription = "Assinatura"
    case insurance = "Seguro"
    case financing = "Financiamento" // Parcelas de carro, moto, casa
    case loan = "Empréstimo" // Empréstimo pessoal, consignado
    case other = "Outros"
    case custom = "Personalizada"

    /// Predefined categories (excludes custom)
    static var predefinedCases: [FixedBillCategory] {
        allCases.filter { $0 != .custom }
    }

    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .health: return "heart.fill"
        case .education: return "book.fill"
        case .transport: return "car.fill"
        case .entertainment: return "tv.fill"
        case .subscription: return "repeat"
        case .insurance: return "shield.fill"
        case .financing: return "creditcard.fill"
        case .loan: return "banknote.fill"
        case .other: return "ellipsis.circle.fill"
        case .custom: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .housing: return .blue
        case .utilities: return .yellow
        case .health: return .red
        case .education: return .purple
        case .transport: return .orange
        case .entertainment: return .pink
        case .subscription: return .cyan
        case .insurance: return .green
        case .financing: return Color(red: 0.85, green: 0.65, blue: 0.13) // Dourado
        case .loan: return .indigo
        case .other: return .gray
        case .custom: return .teal
        }
    }
}

// MARK: - Extensions

extension FixedBill {
    // MARK: - Display Properties (handles custom categories)

    /// Display name for the category (custom or predefined)
    var displayCategoryName: String {
        if category == .custom, let customName = customCategoryName, !customName.isEmpty {
            return customName
        }
        return category.rawValue
    }

    /// Display icon for the category (custom or predefined)
    var displayCategoryIcon: String {
        if category == .custom, let customIcon = customCategoryIcon, !customIcon.isEmpty {
            return customIcon
        }
        return category.icon
    }

    /// Display color for the category (custom or predefined)
    var displayCategoryColor: Color {
        if category == .custom, let colorHex = customCategoryColorHex {
            return Color(hex: colorHex) ?? category.color
        }
        return category.color
    }

    // MARK: - Amount

    var amountDouble: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }

    var formattedAmount: String {
        CurrencyUtils.format(amountDouble)
    }

    var dueDayFormatted: String {
        "Dia \(dueDay)"
    }

    /// Returns the next due date based on today
    var nextDueDate: Date {
        let calendar = Calendar.current
        let today = Date()
        let currentDay = calendar.component(.day, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)

        // If due day already passed this month, next due is next month
        if currentDay > dueDay {
            var components = DateComponents()
            components.year = currentYear
            components.month = currentMonth + 1
            components.day = min(dueDay, 28) // Handle months with fewer days
            return calendar.date(from: components) ?? today
        } else {
            var components = DateComponents()
            components.year = currentYear
            components.month = currentMonth
            components.day = min(dueDay, 28)
            return calendar.date(from: components) ?? today
        }
    }

    /// Days until next due date
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDate = calendar.startOfDay(for: nextDueDate)
        return calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
    }

    /// Status text based on days until due
    var statusText: String {
        let days = daysUntilDue
        if days == 0 {
            return "Vence hoje"
        } else if days == 1 {
            return "Vence amanhã"
        } else if days < 0 {
            return "Vencida"
        } else if days <= 7 {
            return "Vence em \(days) dias"
        } else {
            return "Dia \(dueDay)"
        }
    }

    var isOverdue: Bool {
        daysUntilDue < 0
    }

    var isDueSoon: Bool {
        daysUntilDue >= 0 && daysUntilDue <= 7
    }

    // MARK: - Installments

    /// Check if this bill has installment tracking
    var hasInstallments: Bool {
        totalInstallments != nil && totalInstallments! > 0
    }

    /// Formatted installments text (e.g., "21/60")
    var installmentsText: String? {
        guard let total = totalInstallments, total > 0 else { return nil }
        let paid = paidInstallments ?? 0
        return "\(paid)/\(total)"
    }

    /// Remaining installments
    var remainingInstallments: Int? {
        guard let total = totalInstallments else { return nil }
        let paid = paidInstallments ?? 0
        return max(0, total - paid)
    }

    /// Progress percentage (0.0 to 1.0)
    var installmentProgress: Double? {
        guard let total = totalInstallments, total > 0 else { return nil }
        let paid = paidInstallments ?? 0
        return Double(paid) / Double(total)
    }
}
