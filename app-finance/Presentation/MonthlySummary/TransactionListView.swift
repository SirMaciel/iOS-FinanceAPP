import SwiftUI

struct TransactionListView: View {
    let transactions: [TransactionItemViewModel]
    let selectedCategoryInfo: (name: String, total: String)?
    let onClearFilter: () -> Void
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Transações")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if selectedCategoryInfo != nil {
                    Button(action: onClearFilter) {
                        HStack(spacing: 4) {
                            Text("Limpar filtro")
                                .font(.caption)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.accentBlue)
                    }
                }
            }

            // Filtro ativo
            if let info = selectedCategoryInfo {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(AppColors.accentBlue)

                    Text(info.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Text("—")
                        .foregroundColor(AppColors.textTertiary)

                    Text(info.total)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentRed)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(AppColors.accentBlue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accentBlue.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }

            // Lista de transações
            if transactions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(transactions, id: \.id) { transaction in
                        TransactionRowCard(transaction: transaction)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(transaction.id)
                                } label: {
                                    Label("Apagar", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(transactions.count) * 86)
            }
        }
        .padding(16)
        .background(AppColors.bgSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(20)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.bgTertiary)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )

                Image(systemName: "tray")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("Nenhuma transação")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Text("Adicione sua primeira transação usando o botão abaixo")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
