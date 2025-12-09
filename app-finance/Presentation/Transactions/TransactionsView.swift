import SwiftUI

struct TransactionsView: View {
    @Environment(\.dismiss) private var dismiss

    let transactions: [TransactionItemViewModel]
    let currentMonth: MonthRef
    let onDelete: (String) -> Void
    var onEdit: ((String, String, Decimal, Date, TransactionType, String?, String?, String?) -> Void)? = nil

    @State private var selectedTransaction: TransactionItemViewModel?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                if transactions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Summary Card
                            summaryCard

                            // Transactions List
                            transactionsList
                        }
                        .padding()
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.bgSecondary)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("Transações")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text(currentMonth.displayString)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Placeholder for balance
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Nenhuma transação")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("Suas transações deste mês\naparecerão aqui")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let incomeTotal = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenseTotal = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

        return VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total de Transações")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)

                    Text("\(transactions.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }

            // Divider aesthetic
            Rectangle()
                .fill(LinearGradient(
                    colors: [AppColors.cardBorder, AppColors.cardBorder.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)

            HStack(spacing: 24) {
                // Income
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(AppColors.income)

                    Text(CurrencyUtils.format(incomeTotal))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.income)
                }

                Spacer()

                // Expense
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundColor(AppColors.expense)

                    Text(CurrencyUtils.format(expenseTotal))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.expense)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                AppColors.bgSecondary
                // Subtle shine
                LinearGradient(
                    colors: [Color.white.opacity(0.02), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(transactions) { transaction in
                Button {
                    selectedTransaction = transaction
                } label: {
                    TransactionRowCard(transaction: transaction)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete(transaction.id)
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onDelete: {
                    onDelete(transaction.id)
                    selectedTransaction = nil
                },
                onEdit: onEdit != nil ? { desc, amount, date, type, categoryId, notes, paymentMethod in
                    onEdit?(transaction.id, desc, amount, date, type, categoryId, notes, paymentMethod)
                    selectedTransaction = nil
                } : nil
            )
        }
    }
}

#Preview {
    TransactionsView(
        transactions: [],
        currentMonth: .current,
        onDelete: { _ in }
    )
}
