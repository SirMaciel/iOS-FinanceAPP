import SwiftUI
import Charts

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
                    .chartBackground { _ in
                        // Área clicável
                        GeometryReader { geo in
                            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            let radius: CGFloat = 110

                            ForEach(data) { item in
                                let startAngle = angleForCategory(item, before: true)
                                let endAngle = angleForCategory(item, before: false)

                                PieSliceTapArea(
                                    center: center,
                                    innerRadius: 60,
                                    outerRadius: radius + 30,
                                    startAngle: startAngle,
                                    endAngle: endAngle
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        onTap(item.categoryId)
                                    }
                                }
                            }
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCategoryId)

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

                            Text("\(Int(selected.percent * 100))%")
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

                    Text("\(Int(item.percent * 100))%")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 32, alignment: .trailing)
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

struct PieSliceTapArea: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    var body: some View {
        Path { path in
            let start = startAngle.radians - .pi / 2
            let end = endAngle.radians - .pi / 2

            path.addArc(
                center: center,
                radius: outerRadius,
                startAngle: Angle(radians: start),
                endAngle: Angle(radians: end),
                clockwise: false
            )

            path.addLine(to: CGPoint(
                x: center.x + innerRadius * cos(end),
                y: center.y + innerRadius * sin(end)
            ))

            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: Angle(radians: end),
                endAngle: Angle(radians: start),
                clockwise: true
            )

            path.closeSubpath()
        }
        .fill(Color.clear)
    }
}
