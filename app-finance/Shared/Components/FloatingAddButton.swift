import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Adicionar")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(28)
            .shadow(color: Color.blue.opacity(0.4), radius: 16, x: 0, y: 8)
            .shadow(color: Color.purple.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    ZStack {
        AppBackground()

        FloatingAddButton {
            print("Tapped")
        }
    }
}
