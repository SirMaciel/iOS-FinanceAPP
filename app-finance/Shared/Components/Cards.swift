import SwiftUI
import SwiftData

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
            }

            // Title
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // Value
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Transaction Row Card

struct TransactionRowCard: View {
    let transaction: TransactionItemViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(transaction.categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "tag.fill") // Placeholder icon, ideally category.iconName
                    .font(.system(size: 16))
                    .foregroundColor(transaction.categoryColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(transaction.categoryName ?? "Sem categoria")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text(transaction.dateFormatted)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()

            // Amount
            HStack(spacing: 4) {
                Text(transaction.amountFormatted)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.type == .expense ? AppColors.textPrimary : AppColors.income)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.001)) // Tappable area
        .contentShape(Rectangle())
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: Category
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Ícone com cor
                ZStack {
                    Circle()
                        .fill(Color(hex: category.colorHex) ?? .gray)
                        .frame(width: 44, height: 44)
                        .shadow(color: (Color(hex: category.colorHex) ?? .gray).opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: category.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                // Nome e status
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(category.name)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        // Indicador de sync pendente
                        if category.isPendingSync {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Text(category.isActive ? "Ativa" : "Inativa")
                        .font(.caption)
                        .foregroundColor(category.isActive ? AppColors.accentGreen : AppColors.textTertiary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .opacity(category.isActive ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Card

struct SettingsCard: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var iconColor: Color = AppColors.accentBlue
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
