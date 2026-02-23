import SwiftUI

// MARK: - Day Data Model

struct DayData: Identifiable {
    let id: Int
    let day: String
    let fullDayName: String
    let seconds: Int
    let isToday: Bool
    let dateKey: String
    let sessionCount: Int
    let date: Date?
}

// MARK: - Dotted Line Shape

struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Chart Grid Lines

struct ChartGridLines: View {
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Top solid
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)

            Spacer()

            // 75% dotted
            DottedLine()
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                .frame(height: 0.5)

            Spacer()

            // 50% solid
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)

            Spacer()

            // 25% dotted
            DottedLine()
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                .frame(height: 0.5)

            Spacer()

            // Bottom solid
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
        .frame(height: height)
    }
}

// MARK: - Y-Axis Labels

struct YAxisLabels: View {
    let maxSeconds: Int
    let height: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(StatsChartHelpers.formatYAxisLabel(seconds: maxSeconds))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.25))

            Spacer()

            Text(StatsChartHelpers.formatYAxisLabel(seconds: maxSeconds / 2))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.25))

            Spacer()

            Text("0h")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.25))
        }
        .frame(width: 28, height: height)
    }
}

// MARK: - Chart Helpers

enum StatsChartHelpers {

    static func calculateYAxisMax(maxSeconds: Int) -> Int {
        let maxHours = Double(maxSeconds) / 3600.0

        if maxHours <= 1   { return 3600 * 2 }
        if maxHours <= 2   { return 3600 * 4 }
        if maxHours <= 3   { return 3600 * 6 }
        if maxHours <= 4   { return 3600 * 8 }
        if maxHours <= 5   { return 3600 * 10 }
        if maxHours <= 6   { return 3600 * 12 }
        if maxHours <= 8   { return 3600 * 16 }
        if maxHours <= 10  { return 3600 * 20 }

        let roundedHours = Int(ceil(maxHours / 2.0) * 2)
        return roundedHours * 3600
    }

    static func formatYAxisLabel(seconds: Int) -> String {
        let hours = seconds / 3600
        return "\(hours)h"
    }

    static func barHeight(for seconds: Int, max: Int, chartHeight: CGFloat) -> CGFloat {
        guard max > 0 else { return 4 }
        let minHeight: CGFloat = seconds > 0 ? 6 : 4
        let ratio = CGFloat(seconds) / CGFloat(max)
        return Swift.max(ratio * chartHeight, minHeight)
    }

    static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }

    static func formatDurationInterval(_ seconds: TimeInterval) -> String {
        formatDuration(Int(seconds))
    }
}
