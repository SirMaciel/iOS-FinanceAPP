import SwiftUI
import UIKit

// MARK: - App Colors (Light Theme / Minimalist)

struct AppColors {
    // Backgrounds
    static let bgPrimary = Color(hex: "F8F9FA") ?? .white // Zinc 50 (Main background)
    static let bgSecondary = Color(hex: "FFFFFF") ?? .white // Pure White (Cards)
    static let bgTertiary = Color(hex: "E9ECEF") ?? .gray // Zinc 200 (Inputs/Sections)
    
    // Text / Ink
    static let textPrimary = Color(hex: "111827") ?? .black // Gray 900 (Main text)
    static let textSecondary = Color(hex: "6B7280") ?? .gray // Gray 500 (Subtitles)
    static let textTertiary = Color(hex: "9CA3AF") ?? .gray // Gray 400 (Placeholders)
    
    // Accents
    static let accentBlue = Color(hex: "2563EB") ?? .blue // Blue 600
    static let accentPurple = Color(hex: "7C3AED") ?? .purple // Violet 600
    static let accentGreen = Color(hex: "059669") ?? .green // Emerald 600
    static let accentRed = Color(hex: "DC2626") ?? .red // Red 600
    static let accentOrange = Color(hex: "F97316") ?? .orange // Orange 500
    
    // Semantic
    static let income = Color(hex: "10B981") ?? .green // Emerald 500
    static let expense = Color(hex: "EF4444") ?? .red // Red 500
    static let cardBorder = Color.black.opacity(0.05)
    
    // Gradients
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accentBlue, Color(hex: "1D4ED8") ?? .blue], // Blue 600 -> Blue 700
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Extensions

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var a: UInt64 = 255
        var r: UInt64 = 0
        var g: UInt64 = 0
        var b: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        
        switch length {
        case 3: // RGB (12-bit)
            r = (rgb >> 8) * 17
            g = (rgb >> 4 & 0xF) * 17
            b = (rgb & 0xF) * 17
        case 6: // RGB (24-bit)
            r = (rgb >> 16)
            g = (rgb >> 8 & 0xFF)
            b = (rgb & 0xFF)
        case 8: // ARGB (32-bit)
            a = (rgb >> 24)
            r = (rgb >> 16 & 0xFF)
            g = (rgb >> 8 & 0xFF)
            b = (rgb & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        // Simple fallback conversion
        let uic = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r) * 255), lroundf(Float(g) * 255), lroundf(Float(b) * 255))
    }
}

// MARK: - Components

struct AppBackground: View {
    var body: some View {
        AppColors.bgPrimary
            .ignoresSafeArea()
    }
}

struct AppCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var corners: CGFloat
    var shadow: Bool
    
    init(padding: CGFloat = 20, corners: CGFloat = 24, shadow: Bool = true, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.corners = corners
        self.shadow = shadow
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AppColors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: corners, style: .continuous))
            .shadow(color: shadow ? Color.black.opacity(0.06) : .clear, radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: corners, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}

struct SectionHeader: View {
    let title: String
    var actionText: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            if let actionText = actionText, let action = action {
                Button(action: action) {
                    Text(actionText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

struct AppButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void
    
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
                        .tint(style == .primary ? .white : AppColors.textPrimary)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundView)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: shadowColor, radius: style == .primary ? 8 : 0, y: 4)
        }
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            AppColors.primaryGradient
        case .secondary:
            AppColors.bgTertiary // Light gray
        case .danger:
            AppColors.accentRed.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return AppColors.textPrimary
        case .danger: return AppColors.accentRed
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return AppColors.accentBlue.opacity(0.3)
        default: return .clear
        }
    }
}

struct AppTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(AppColors.textTertiary)
                }
        }
        .padding()
        .frame(height: 56)
        .background(AppColors.bgTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AppSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 20)

            if isVisible {
                TextField(placeholder, text: $text)
                    .foregroundColor(AppColors.textPrimary)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(AppColors.textTertiary)
                    }
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(AppColors.textPrimary)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(AppColors.textTertiary)
                    }
            }
            
            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding()
        .frame(height: 56)
        .background(AppColors.bgTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AppSegmentedPicker<T: Hashable>: View {
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
                        .foregroundColor(selection == option.0 ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            selection == option.0 ? AppColors.bgSecondary : Color.clear
                        )
                        .cornerRadius(10)
                        .shadow(color: selection == option.0 ? Color.black.opacity(0.05) : .clear, radius: 2, x: 0, y: 1)
                }
            }
        }
        .padding(4)
        .background(AppColors.bgTertiary)
        .cornerRadius(14)
    }
}

struct AppEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.bgTertiary)
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

// MARK: - Legacy / Helper Aliases for smoother refactor
// (To be removed after full migration, but helpful for intermediate steps if needed)


// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
