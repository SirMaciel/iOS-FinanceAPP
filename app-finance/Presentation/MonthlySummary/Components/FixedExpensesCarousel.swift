import SwiftUI

struct FixedExpensesCarousel: View {
    let expenses: [FixedExpense]
    let onAddTap: () -> Void
    let onDelete: (FixedExpense) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DarkSectionHeader(title: "Contas Fixas", icon: "calendar.badge.clock")
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Botão Adicionar
                    Button(action: onAddTap) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.accentBlue)
                            
                            Text("Nova Conta")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 100, height: 100) // Square card
                        .background(AppColors.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accentBlue.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                    
                    // Lista de Despesas
                    ForEach(expenses) { expense in
                        FixedExpenseCard(expense: expense)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(expense)
                                } label: {
                                    Label("Remover", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct FixedExpenseCard: View {
    let expense: FixedExpense
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Dia do vencimento
                Text("Dia \(expense.dueDay)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.bgPrimary.opacity(0.5))
                    .cornerRadius(4)
                
                Spacer()
                
                // Status (pago ou não - por enquanto estático ou base na logica futura)
                // Vamos usar um icone de conta
                Image(systemName: "doc.text.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.accentPurple)
            }
            
            Spacer()
            
            Text(expense.desc)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(CurrencyUtils.format(expense.amountDouble))
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(12)
        .frame(width: 120, height: 100) // Square-ish
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}
