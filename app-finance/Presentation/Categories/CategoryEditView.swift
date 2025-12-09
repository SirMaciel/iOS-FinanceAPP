import SwiftUI
import SwiftData

struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category
    let onSave: (String, String) -> Void

    @State private var name: String
    @State private var colorHex: String

    init(category: Category, onSave: @escaping (String, String) -> Void) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category.name)
        _colorHex = State(initialValue: category.colorHex)
    }

    var body: some View {
        ZStack {
            // Background
            AppBackground()

            // Content
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancelar")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Text("Editar Categoria")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button(action: {
                        onSave(name, colorHex)
                        dismiss()
                    }) {
                        Text("Salvar")
                            .fontWeight(.semibold)
                            .foregroundColor(name.isEmpty ? AppColors.textTertiary : AppColors.accentBlue)
                    }
                    .disabled(name.isEmpty)
                }
                .padding()

                // Preview
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: colorHex) ?? .gray)
                            .frame(width: 80, height: 80)
                            .shadow(color: (Color(hex: colorHex) ?? .gray).opacity(0.5), radius: 16, x: 0, y: 8)

                        Image(systemName: category.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }

                    Text(name.isEmpty ? "Nome da categoria" : name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(name.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
                }
                .padding(.vertical, 20)

                // Form
                VStack(spacing: 16) {
                    // Nome
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nome")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)

                        AppTextField(
                            icon: "pencil",
                            placeholder: "Nome da categoria",
                            text: $name
                        )
                    }

                    // Cor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cor")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 44, height: 44)
                                .shadow(color: (Color(hex: colorHex) ?? .gray).opacity(0.4), radius: 8, x: 0, y: 4)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )

                            ColorPicker("", selection: Binding(
                                get: { Color(hex: colorHex) ?? .blue },
                                set: { colorHex = $0.toHex() ?? colorHex }
                            ))
                            .labelsHidden()

                            Spacer()

                            Text(colorHex.uppercased())
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppColors.bgSecondary)
                                .cornerRadius(8)
                        }
                        .padding(16)
                        .background(AppColors.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}
