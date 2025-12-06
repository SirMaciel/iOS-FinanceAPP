import SwiftUI

struct CardSpendingCarousel: View {
    let cardSpendings: [CreditCardSpending]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DarkSectionHeader(title: "Gastos do Cartão", icon: "creditcard.fill")
            
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
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct CardSpendingSummaryCard: View {
    let spending: CreditCardSpending
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.accentPurple)
                    .frame(width: 24, height: 24)
                    .background(AppColors.accentPurple.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                Text("•••• \(spending.lastFourDigits)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Text(spending.cardName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            
            Text(CurrencyUtils.format(spending.totalAmount))
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(12)
        .frame(width: 150)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}
