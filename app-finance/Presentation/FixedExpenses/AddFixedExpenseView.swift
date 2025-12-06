import SwiftUI

struct AddFixedExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var description: String = ""
    @State private var amount: String = ""
    @State private var dueDay: Int = 10
    @State private var isLoading = false
    
    private let repository = FixedExpenseRepository.shared
    let onSaved: () -> Void
    
    // Dias do mês (1 a 31)
    private let days = Array(1...31)
    
    var body: some View {
        ZStack {
            DarkBackground(blurColor1: AppColors.blurPurple, blurColor2: AppColors.blurBlue)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Text("Nova Conta Fixa")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Button("Salvar") {
                        saveExpense()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(isValid ? AppColors.accentBlue : AppColors.textTertiary)
                    .disabled(!isValid || isLoading)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Nome
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nome da conta")
                                .font(.caption).foregroundColor(AppColors.textSecondary)
                            
                            DarkTextField(
                                icon: "tag.fill",
                                placeholder: "Ex: Aluguel, Internet",
                                text: $description
                            )
                        }
                        
                        // Valor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Valor aproximado")
                                .font(.caption).foregroundColor(AppColors.textSecondary)
                            
                            HStack {
                                Text("R$").bold().foregroundColor(AppColors.textSecondary)
                                TextField("0,00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.title2).bold()
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder))
                        }
                        
                        // Dia de Vencimento
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dia de vencimento")
                                .font(.caption).foregroundColor(AppColors.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(days, id: \.self) { day in
                                        Button(action: { dueDay = day }) {
                                            Text("\(day)")
                                                .font(.headline)
                                                .frame(width: 44, height: 44)
                                                .background(dueDay == day ? AppColors.accentBlue : AppColors.cardBackground)
                                                .foregroundColor(dueDay == day ? .white : AppColors.textPrimary)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(AppColors.cardBorder, lineWidth: dueDay == day ? 0 : 1))
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
    
    private var isValid: Bool {
        !description.isEmpty && !amount.isEmpty
    }
    
    private func saveExpense() {
        guard let userId = authManager.userId,
              let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { return }
        
        isLoading = true
        _ = repository.createFixedExpense(
            userId: userId,
            description: description,
            amount: amountDecimal,
            dueDay: dueDay
        )
        
        isLoading = false
        onSaved()
        dismiss()
    }
}
