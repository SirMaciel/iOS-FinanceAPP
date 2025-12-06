import SwiftUI

struct CardSpendingCarousel: View {
    let cardSpendings: [CreditCardSpending]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DarkSectionHeader(title: "Gastos do Cartão")
            
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
    
    var body: some View {
        DarkCard(padding: 16, corners: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                    
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
