import SwiftUI

struct CardSpendingCarousel: View {
    let cardSpendings: [CreditCardSpending]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Gastos do Cartão")
            
            if cardSpendings.isEmpty {
                Text("Nenhum gasto com cartão neste mês")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cardSpendings) { spending in
                            CardSpendingSummaryCard(spending: spending)
                        }
                    }
                }
            }
        }
    }
}

private struct CardSpendingSummaryCard: View {
    let spending: CreditCardSpending

    private var cardColors: [Color] {
        if let match = AvailableBankCards.cards(forBank: spending.bank).first(where: { $0.tier == spending.cardType }) {
            if let color = Color(hex: match.cardColor) {
                return [color, color.opacity(0.7)]
            }
        }
        return spending.cardType.gradientColors
    }

    var body: some View {
        AppCard(padding: 16, corners: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Mini card icon
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: cardColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 6, height: 4)
                                .offset(x: -8, y: 2)
                        )

                    Spacer()

                    Text("•••• \(spending.lastFourDigits)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(spending.cardName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)

                    Text(CurrencyUtils.format(spending.totalAmount))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .frame(width: 160)
        }
    }
}
