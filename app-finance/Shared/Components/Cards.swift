import SwiftUI
import SwiftData

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let icon = icon {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundColor(color)
                    }
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// MARK: - Transaction Row Card

struct TransactionRowCard: View {
    let transaction: TransactionItemViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Barra lateral com cor da categoria
            RoundedRectangle(cornerRadius: 4)
                .fill(transaction.categoryColor)
                .frame(width: 4, height: 50)
                .shadow(color: transaction.categoryColor.opacity(0.5), radius: 4, x: 0, y: 0)

            // Conteúdo
            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.description)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(transaction.dateFormatted)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    if let categoryName = transaction.categoryName {
                        Circle()
                            .fill(AppColors.textTertiary)
                            .frame(width: 3, height: 3)

                        Text(categoryName)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if transaction.needsUserReview {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.accentOrange)
                    }

                    if transaction.isPendingSync {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Valor
            Text(transaction.amountFormatted)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(transaction.type == .expense ? AppColors.accentRed : AppColors.accentGreen)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(12)
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
                        .shadow(color: (Color(hex: category.colorHex) ?? .gray).opacity(0.4), radius: 8, x: 0, y: 4)

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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
