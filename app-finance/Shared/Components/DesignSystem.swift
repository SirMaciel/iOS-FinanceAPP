import SwiftUI

// MARK: - App Colors

struct AppColors {
    // Background
    static let bgPrimary = Color(red: 0.08, green: 0.09, blue: 0.14)
    static let bgSecondary = Color(red: 0.12, green: 0.13, blue: 0.20)

    // Card
    static let cardBackground = Color.black.opacity(0.2)
    static let cardBorder = Color.white.opacity(0.05)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.5)
    static let textTertiary = Color.white.opacity(0.3)

    // Accent
    static let accentBlue = Color.blue
    static let accentGreen = Color.green
    static let accentRed = Color.red
    static let accentOrange = Color.orange
    static let accentPurple = Color.purple

    // Blur Circles
    static let blurBlue = Color.blue.opacity(0.3)
    static let blurPurple = Color.purple.opacity(0.3)
    static let blurGreen = Color.green.opacity(0.2)

    // Gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgPrimary, bgSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Dark Background

struct DarkBackground: View {
    var showBlurCircles: Bool = true
    var blurColor1: Color = AppColors.blurBlue
    var blurColor2: Color = AppColors.blurPurple

    var body: some View {
        ZStack {
            AppColors.backgroundGradient
                .ignoresSafeArea()

            if showBlurCircles {
                GeometryReader { geo in
                    Circle()
                        .fill(blurColor1)
                        .frame(width: 400, height: 400)
                        .blur(radius: 100)
                        .offset(x: -100, y: -200)

                    Circle()
                        .fill(blurColor2)
                        .frame(width: 350, height: 350)
                        .blur(radius: 100)
                        .offset(x: geo.size.width - 150, y: geo.size.height - 200)
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Dark Card

struct DarkCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
    }
}

// MARK: - Dark Section Header

struct DarkSectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

// MARK: - Dark Text Field

struct DarkTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 24)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColors.textTertiary))
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// MARK: - Dark Button

struct DarkButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case danger
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .black : .white)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1 : 0)
            )
            .shadow(color: shadowColor, radius: 20, y: 10)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .black
        case .secondary:
            return .white
        case .danger:
            return .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return AppColors.cardBackground
        case .danger:
            return Color.red.opacity(0.8)
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary:
            return AppColors.cardBorder
        default:
            return .clear
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary:
            return .white.opacity(0.2)
        case .danger:
            return .red.opacity(0.3)
        default:
            return .clear
        }
    }
}

// MARK: - Dark Segmented Picker

struct DarkSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option.0
                    }
                }) {
                    Text(option.1)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selection == option.0 ? .black : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            selection == option.0 ? Color.white : Color.clear
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Empty State View

struct DarkEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Loading Overlay

struct DarkLoadingOverlay: View {
    var message: String = "Carregando..."

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(32)
            .background(AppColors.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DarkBackground()

        ScrollView {
            VStack(spacing: 20) {
                DarkSectionHeader(title: "Exemplo de Seção", icon: "star.fill")

                DarkCard {
                    Text("Conteúdo do card")
                        .foregroundColor(.white)
                }

                DarkTextField(icon: "envelope", placeholder: "Email", text: .constant(""))

                DarkButton(title: "Botão Primário", icon: "arrow.right") {}

                DarkButton(title: "Botão Secundário", style: .secondary) {}

                DarkButton(title: "Sair", icon: "rectangle.portrait.and.arrow.right", style: .danger) {}

                DarkEmptyState(
                    icon: "tray",
                    title: "Nenhum item",
                    subtitle: "Adicione seu primeiro item para começar"
                )
            }
            .padding()
        }
    }
}
