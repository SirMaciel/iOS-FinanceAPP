import SwiftUI
import Combine

struct FixedBillsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = FixedBillsViewModel()
    @State private var showingAddBill = false
    @State private var editingBill: FixedBill?

    var body: some View {
        ZStack {
            DarkBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                if viewModel.bills.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Summary Card
                            summaryCard

                            // Bills List
                            billsList
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }

            // Floating Add Button
            VStack {
                Spacer()
                FloatingAddButton {
                    showingAddBill = true
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if let userId = authManager.userId {
                viewModel.loadBills(userId: userId)
            }
        }
        .sheet(isPresented: $showingAddBill) {
            AddFixedBillView(onSave: {
                if let userId = authManager.userId {
                    viewModel.loadBills(userId: userId)
                }
            })
        }
        .sheet(item: $editingBill) { bill in
            AddFixedBillView(editingBill: bill, onSave: {
                if let userId = authManager.userId {
                    viewModel.loadBills(userId: userId)
                }
            })
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            DarkSectionHeader(title: "Contas Fixas")

            Spacer()

            Button(action: { showingAddBill = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .cornerRadius(8)
            }
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

                Image(systemName: "calendar.badge.clock")
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
                Text("Nenhuma conta fixa")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("Adicione suas contas fixas para\nacompanhar seus gastos mensais")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            DarkButton(title: "Adicionar Conta", icon: "plus") {
                showingAddBill = true
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Mensal")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    Text(CurrencyUtils.format(viewModel.totalMonthly))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(AppColors.expense.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "calendar")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.expense)
                }
            }

            Divider()
                .background(AppColors.cardBorder)

            HStack(spacing: 24) {
                // Bills count
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.activeBillsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Contas ativas")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Due soon count
                if viewModel.dueSoonCount > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("\(viewModel.dueSoonCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(AppColors.accentOrange)

                        Text("Vencem em breve")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Bills List

    private var billsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            DarkSectionHeader(title: "Suas Contas")

            LazyVStack(spacing: 12) {
                ForEach(viewModel.bills) { bill in
                    FixedBillRow(bill: bill) {
                        editingBill = bill
                    }
                    .contextMenu {
                        Button {
                            editingBill = bill
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }

                        Button {
                            viewModel.toggleActive(bill)
                        } label: {
                            Label(
                                bill.isActive ? "Desativar" : "Ativar",
                                systemImage: bill.isActive ? "pause.circle" : "play.circle"
                            )
                        }

                        Button(role: .destructive) {
                            viewModel.deleteBill(bill)
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Fixed Bill Row

struct FixedBillRow: View {
    let bill: FixedBill
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(bill.displayCategoryColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: bill.displayCategoryIcon)
                        .font(.system(size: 18))
                        .foregroundColor(bill.displayCategoryColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(bill.name)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(bill.isActive ? AppColors.textPrimary : AppColors.textTertiary)

                        if !bill.isActive {
                            Text("Inativa")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.cardBorder)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 8) {
                        // Due day
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(bill.statusText)
                                .font(.caption)
                        }
                        .foregroundColor(statusColor)

                        // Category
                        Text(bill.displayCategoryName)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)

                        // Installments (if applicable)
                        if let installmentsText = bill.installmentsText {
                            HStack(spacing: 4) {
                                Image(systemName: "number.circle.fill")
                                    .font(.caption2)
                                Text(installmentsText)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(bill.displayCategoryColor)
                        }
                    }
                }

                Spacer()

                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text(bill.formattedAmount)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(bill.isActive ? AppColors.expense : AppColors.textTertiary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(statusBorderColor, lineWidth: bill.isDueSoon ? 2 : 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        if !bill.isActive {
            return AppColors.textTertiary
        } else if bill.isOverdue {
            return AppColors.expense
        } else if bill.isDueSoon {
            return AppColors.accentOrange
        }
        return AppColors.textSecondary
    }

    private var statusBorderColor: Color {
        if !bill.isActive {
            return AppColors.cardBorder
        } else if bill.isOverdue {
            return AppColors.expense.opacity(0.5)
        } else if bill.isDueSoon {
            return AppColors.accentOrange.opacity(0.5)
        }
        return AppColors.cardBorder
    }
}

// MARK: - ViewModel

@MainActor
class FixedBillsViewModel: ObservableObject {
    @Published var bills: [FixedBill] = []

    private let repository = FixedBillRepository.shared
    private var userId: String = ""

    var totalMonthly: Double {
        bills.filter { $0.isActive }.reduce(0) { $0 + $1.amountDouble }
    }

    var activeBillsCount: Int {
        bills.filter { $0.isActive }.count
    }

    var dueSoonCount: Int {
        bills.filter { $0.isActive && $0.isDueSoon }.count
    }

    func loadBills(userId: String) {
        self.userId = userId
        bills = repository.getFixedBills(userId: userId)
    }

    func toggleActive(_ bill: FixedBill) {
        repository.toggleActive(bill)
        loadBills(userId: userId)
    }

    func deleteBill(_ bill: FixedBill) {
        repository.deleteFixedBill(bill)
        loadBills(userId: userId)
    }
}

#Preview {
    FixedBillsView()
}
