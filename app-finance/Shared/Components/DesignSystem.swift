import SwiftUI
import UIKit

// MARK: - App Colors

struct AppColors {
    // Backgrounds - Deep Matte Theme
    static let bgPrimary = Color(hex: "09090B") ?? .black // Zinc 950
    static let bgSecondary = Color(hex: "18181B") ?? .black // Zinc 900
    
    // Surface / Cards
    static let cardBackground = Color(hex: "27272A")?.opacity(0.6) ?? .gray.opacity(0.2) // Zinc 800
    static let cardBorder = Color.white.opacity(0.08)
    
    // Text
    static let textPrimary = Color(hex: "FAFAFA") ?? .white // Zinc 50
    static let textSecondary = Color(hex: "A1A1AA") ?? .gray // Zinc 400
    static let textTertiary = Color(hex: "52525B") ?? .gray // Zinc 600
    
    // Accents - Sophisticated, not neon
    static let accentBlue = Color(hex: "3B82F6") ?? .blue // Blue 500
    static let accentPurple = Color(hex: "8B5CF6") ?? .purple // Violet 500
    static let accentGreen = Color(hex: "10B981") ?? .green // Emerald 500
    static let accentRed = Color(hex: "EF4444") ?? .red // Red 500
    static let accentOrange = Color(hex: "F97316") ?? .orange // Orange 500
    
    // Special
    static let income = Color(hex: "34D399") ?? .green // Emerald 400
    static let expense = Color(hex: "F87171") ?? .red // Red 400
    
    // Gradients
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accentBlue, accentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgPrimary, bgSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Extensions for Hex Colors

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
        guard let cgColor = UIColor(self).cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ) else {
            // Fallback for colors that can't be converted
            let uic = UIColor(self)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uic.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "#%02lX%02lX%02lX", lroundf(Float(r) * 255), lroundf(Float(g) * 255), lroundf(Float(b) * 255))
        }

        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// MARK: - Components

struct DarkBackground: View {
    var body: some View {
        ZStack {
            AppColors.bgPrimary
                .ignoresSafeArea()
            
            // Subtle ambient gradient top-left
            GeometryReader { proxy in
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.1))
                    .frame(width: proxy.size.width * 1.2)
                    .blur(radius: 120)
                    .offset(x: -proxy.size.width * 0.5, y: -proxy.size.height * 0.2)
                
                // Subtle ambient gradient bottom-right
                Circle()
                    .fill(AppColors.accentPurple.opacity(0.05))
                    .frame(width: proxy.size.width)
                    .blur(radius: 100)
                    .offset(x: proxy.size.width * 0.4, y: proxy.size.height * 0.6)
            }
            .ignoresSafeArea()
        }
    }
}

struct DarkCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var corners: CGFloat
    
    init(padding: CGFloat = 20, corners: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.corners = corners
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: corners, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corners, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}

struct DarkSectionHeader: View {
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

struct DarkButton: View {
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
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
            Color.white.opacity(0.05)
        case .danger:
            AppColors.accentRed.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .white
        case .danger: return AppColors.accentRed
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .secondary: return Color.white.opacity(0.1)
        default: return .clear
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return AppColors.accentBlue.opacity(0.3)
        default: return .clear
        }
    }
}

struct DarkTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.textTertiary)
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
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DarkSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.textTertiary)
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
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

#Preview {
    ZStack {
        DarkBackground()
        VStack(spacing: 20) {
            DarkSectionHeader(title: "Overview", actionText: "See All", action: {})
            
            DarkCard {
                Text("This is a sophisticated card")
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            DarkButton(title: "Primary Action", icon: "star.fill", action: {})
            DarkButton(title: "Secondary Action", style: .secondary, action: {})
        }
        .padding()
    }
}
