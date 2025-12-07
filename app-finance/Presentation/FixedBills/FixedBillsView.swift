import SwiftUI
import Combine

struct FixedBillsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = FixedBillsViewModel()
    @State private var showingAddBill = false
    @State private var editingBill: FixedBill?
    @State private var viewMode: ViewMode = .list

    enum ViewMode {
        case list
        case grouped
    }

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
                        VStack(spacing: 24) {
                            // Summary Card
                            summaryCard

                            // View Mode Picker
                            viewModePicker

                            // Bills List
                            if viewMode == .list {
                                billsList
                                    .transition(.opacity)
                            } else {
                                groupedBillsList
                                    .transition(.opacity)
                            }
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
        .animation(.easeInOut, value: viewMode)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            DarkSectionHeader(title: "Contas Fixas")

            Spacer()
        }
        .padding()
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            viewModeButton(mode: .list, icon: "list.bullet", title: "Lista")
            viewModeButton(mode: .grouped, icon: "rectangle.grid.1x2", title: "Agrupado")
        }
        .padding(4)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private func viewModeButton(mode: ViewMode, icon: String, title: String) -> some View {
        Button(action: {
            withAnimation {
                viewMode = mode
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(viewMode == mode ? .black : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                viewMode == mode ? Color.white : Color.clear
            )
            .cornerRadius(10)
        }
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Mensal Estimado")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)

                    Text(CurrencyUtils.format(viewModel.totalMonthly))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: "calendar")
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
                // Bills count
                HStack(spacing: 8) {
                    Text("\(viewModel.activeBillsCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text("ativas")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Due soon count
                if viewModel.dueSoonCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.accentOrange)

                        Text("\(viewModel.dueSoonCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)

                        Text("vencem logo")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.accentOrange.opacity(0.1))
                    .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                AppColors.cardBackground
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

    // MARK: - Bills List (Flat)

    private var billsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.bills) { bill in
                SwipeableDeleteView(
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.deleteBill(bill)
                        }
                    },
                    onTap: {
                        editingBill = bill
                    }
                ) {
                    FixedBillRow(bill: bill)
                }
                .contextMenu {
                    contextMenuButtons(for: bill)
                }
            }
        }
    }

    // MARK: - Grouped Bills List

    private var groupedBillsList: some View {
        LazyVStack(spacing: 20) {
            ForEach(viewModel.groupedBills, id: \.category) { group in
                VStack(spacing: 12) {
                    // Group Header
                    HStack {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(group.color.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                    
                                Image(systemName: group.icon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(group.color)
                            }
                            
                            Text(group.category.rawValue)
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Spacer()

                        Text(CurrencyUtils.format(group.total))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, 4)

                    // Bills in Group
                    VStack(spacing: 8) {
                        ForEach(group.bills) { bill in
                            SwipeableDeleteView(
                                onDelete: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.deleteBill(bill)
                                    }
                                },
                                onTap: {
                                    editingBill = bill
                                }
                            ) {
                                FixedBillRow(bill: bill, isCompact: true)
                            }
                            .contextMenu {
                                contextMenuButtons(for: bill)
                            }
                        }
                    }
                }
                .padding(16)
                .background(AppColors.cardBackground.opacity(0.5)) // Slightly darker/lighter for groups?
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private func contextMenuButtons(for bill: FixedBill) -> some View {
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

// MARK: - Group Model
struct BillGroup {
    let category: FixedBillCategory
    let bills: [FixedBill]
    let total: Double
    let color: Color
    let icon: String
}

// MARK: - Row View (Redesigned)

struct FixedBillRow: View {
    let bill: FixedBill
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Category Icon
            if !isCompact {
                ZStack {
                    Circle()
                        .fill(bill.displayCategoryColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: bill.displayCategoryIcon)
                        .font(.system(size: 20))
                        .foregroundColor(bill.displayCategoryColor)
                }
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(bill.displayCategoryColor)
                    .frame(width: 4, height: 32)
            }

            // Main Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bill.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(bill.isActive ? AppColors.textPrimary : AppColors.textTertiary)
                        .lineLimit(1)

                    if let installmentsText = bill.installmentsText {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(installmentsText)
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)
                    }

                    if !bill.isActive {
                        Text("Pausada")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                    }
                }

                // Status / Due Date
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(bill.statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(statusColor)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(bill.formattedAmount)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(bill.isActive ? AppColors.textPrimary : AppColors.textTertiary)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary.opacity(0.5))
                }
            }
        }
        .padding(isCompact ? 12 : 16)
        .background(AppColors.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusBorderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
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
        if bill.isActive && (bill.isOverdue || bill.isDueSoon) {
            return statusColor.opacity(0.3)
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

    var groupedBills: [BillGroup] {
        let grouped = Dictionary(grouping: bills.filter { $0.isActive }, by: { $0.category })
        return grouped.map { category, bills in
            let total = bills.reduce(0) { $0 + $1.amountDouble }
            // For custom category visuals, we take the first bill's or default
            let first = bills.first
            let color = first?.displayCategoryColor ?? category.color
            let icon = first?.displayCategoryIcon ?? category.icon
            
            return BillGroup(
                category: category,
                bills: bills.sorted(by: { $0.dueDay < $1.dueDay }),
                total: total,
                color: color,
                icon: icon
            )
        }.sorted(by: { $0.total > $1.total }) // Sort groups by highest spending
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

// MARK: - Swipeable Delete View

struct SwipeableDeleteView<Content: View>: View {
    let onDelete: () -> Void
    let onTap: () -> Void
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @GestureState private var isDragging = false

    private let deleteThreshold: CGFloat = -80
    private let fullSwipeThreshold: CGFloat = -200

    init(onDelete: @escaping () -> Void, onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()

                if offset < 0 {
                    HStack(spacing: 0) {
                        // Delete button area
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                offset = 0
                            }
                            onDelete()
                        }) {
                            ZStack {
                                Rectangle()
                                    .fill(AppColors.expense)

                                VStack(spacing: 4) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 20, weight: .semibold))

                                    if offset < fullSwipeThreshold {
                                        Text("Solte")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                    } else {
                                        Text("Excluir")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                }
                                .foregroundColor(.white)
                            }
                            .frame(width: max(0, -offset))
                        }
                    }
                }
            }
            .cornerRadius(16)

            // Main content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($isDragging) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            // Only allow left swipe
                            if value.translation.width < 0 {
                                offset = value.translation.width
                                isSwiping = true
                            } else if offset < 0 {
                                // Allow dragging back to close
                                offset = min(0, value.translation.width + deleteThreshold)
                            }
                        }
                        .onEnded { value in
                            isSwiping = false

                            if offset < fullSwipeThreshold {
                                // Full swipe - delete
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    offset = -500 // Enough to slide off screen
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete()
                                }
                            } else if offset < deleteThreshold {
                                // Partial swipe - show delete button
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = deleteThreshold
                                }
                            } else {
                                // Reset
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            if offset < 0 {
                                // If swiped, reset on tap
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                            } else {
                                // Open settings
                                onTap()
                            }
                        }
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSwiping)
        }
        .clipped()
    }
}

#Preview {
    FixedBillsView()
}
