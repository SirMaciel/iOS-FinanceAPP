import SwiftUI
import Charts
import UIKit

struct PieChartView: View {
    let data: [PieCategoryData]
    let selectedCategoryId: String?
    let onTap: (String) -> Void

    private var selectedCategory: PieCategoryData? {
        guard let id = selectedCategoryId else { return nil }
        return data.first { $0.categoryId == id }
    }

    private var totalExpenses: Double {
        data.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        VStack(spacing: 16) {
            if data.isEmpty {
                emptyState
            } else {
                ZStack {
                    // Gráfico principal
                    Chart(data) { item in
                        SectorMark(
                            angle: .value("Total", item.total),
                            innerRadius: .ratio(0.55),
                            outerRadius: selectedCategoryId == item.categoryId ? .ratio(1.0) : .ratio(0.85),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: item.colorHex) ?? .gray)
                        .opacity(selectedCategoryId == nil || selectedCategoryId == item.categoryId ? 1.0 : 0.3)
                    }
                    .frame(height: 260)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCategoryId)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    // Calcular qual fatia foi clicada
                                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                    let dx = location.x - center.x
                                    let dy = location.y - center.y
                                    let distance = sqrt(dx * dx + dy * dy)

                                    // Verificar se está dentro do donut (entre innerRadius e outerRadius)
                                    let innerRadius: CGFloat = 60
                                    let outerRadius: CGFloat = 130

                                    guard distance >= innerRadius && distance <= outerRadius else {
                                        // Clicou fora ou no centro - deselecionar
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedCategoryId != nil {
                                                onTap(selectedCategoryId!)
                                            }
                                        }
                                        return
                                    }

                                    // Calcular ângulo do clique
                                    var angle = atan2(dy, dx)
                                    angle = angle + .pi / 2 // Ajustar para começar do topo
                                    if angle < 0 { angle += 2 * .pi }
                                    let clickAngle = Angle(radians: angle)

                                    // Encontrar qual categoria foi clicada
                                    for item in data {
                                        let startAngle = angleForCategory(item, before: true)
                                        let endAngle = angleForCategory(item, before: false)

                                        var start = startAngle.radians
                                        var end = endAngle.radians
                                        if start < 0 { start += 2 * .pi }
                                        if end < 0 { end += 2 * .pi }
                                        if end < start { end += 2 * .pi }

                                        var click = clickAngle.radians
                                        if click < start { click += 2 * .pi }

                                        if click >= start && click <= end {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                onTap(item.categoryId)
                                            }
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                            return
                                        }
                                    }
                                }
                        }
                    }

                    // Centro com informações
                    VStack(spacing: 4) {
                        if let selected = selectedCategory {
                            // Mostra categoria selecionada
                            Text(selected.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            Text(CurrencyUtils.format(selected.total))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: selected.colorHex) ?? AppColors.textPrimary)

                            Text(String(format: "%.1f%%", selected.percent))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            // Mostra total
                            Text("Total")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            Text(CurrencyUtils.format(totalExpenses))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    .frame(width: 100)
                }

                // Legenda
                legendView
            }
        }
        .padding()
        .background(AppColors.cardBackground)
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
                    .fill(AppColors.cardBackground)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )

                Image(systemName: "chart.pie")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("Sem gastos neste mês")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Text("Adicione sua primeira transação")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(data) { item in
                HStack(spacing: 10) {
                    // Indicador de cor
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: item.colorHex) ?? .gray)
                        .frame(width: 16, height: 16)

                    Text(item.name)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text(CurrencyUtils.format(item.total))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(String(format: "%.0f%%", item.percent))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    selectedCategoryId == item.categoryId ?
                    (Color(hex: item.colorHex) ?? .gray).opacity(0.15) : Color.clear
                )
                .cornerRadius(8)
                .opacity(selectedCategoryId == nil || selectedCategoryId == item.categoryId ? 1.0 : 0.4)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onTap(item.categoryId)
                    }
                }
            }
        }
    }

    private func angleForCategory(_ category: PieCategoryData, before: Bool) -> Angle {
        let total = data.reduce(0) { $0 + $1.total }
        guard total > 0 else { return .degrees(0) }

        var accumulated: Double = 0
        for item in data {
            if item.id == category.id {
                if before {
                    return .degrees(accumulated / total * 360)
                } else {
                    return .degrees((accumulated + item.total) / total * 360)
                }
            }
            accumulated += item.total
        }
        return .degrees(0)
    }
}
