import WidgetKit
import SwiftUI
import Charts

struct IncomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Income", intent: PayWidgetIntent.self, provider: PayProvider()) { entry in
            IncomeWidgetView(entry: entry).widgetBackground()
        }
        .configurationDisplayName("年収と年収の壁")
        .description("今年の年収の見込みと、次の年収の壁までの残りを表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

struct IncomeWidgetView: View {
    let entry: PayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .message(let text):
            MessageView(text: text)
        case .ready(let engine):
            content(engine)
        }
    }

    @ViewBuilder
    private func content(_ engine: PayEngine) -> some View {
        let year = DayKey(entry.date).year
        let s = engine.yearStats(year, now: entry.date)
        let walls = engine.walls(year: year, now: entry.date)
        let next = walls.statuses.first { !$0.isOver }
        switch family {
        case .accessoryInline:
            Text(next.map { "年収\(Fmt.man(s.total))・\(Fmt.man($0.wall.amount))まであと\(Fmt.man($0.remaining))" } ?? "年収\(Fmt.man(s.total))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("\(String(year))年 \(Fmt.man(s.total))円").font(.headline).monospacedDigit()
                if let next {
                    Gauge(value: next.progress) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .widgetAccentable()
                    Text("\(Fmt.man(next.wall.amount))円まで あと\(Fmt.man(next.remaining))円").font(.caption).monospacedDigit()
                } else {
                    Text("178万円を超える見込み").font(.caption)
                }
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 3) {
                WidgetTitle(text: "\(String(year))年の年収")
                Text(Fmt.yen(s.total))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("勤務済み \(Fmt.yen(s.done))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
                WallLine(status: next, compact: true)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        WidgetTitle(text: "\(String(year))年の年収見込み")
                        Text("勤務済み \(Fmt.yen(s.done))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text(Fmt.yen(s.total))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                ForEach(walls.statuses.filter { !$0.isOver }.prefix(2)) { w in
                    WallLine(status: w, compact: false)
                }
                if next == nil { WallLine(status: nil, compact: false) }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetTitle(text: "\(String(year))年の年収見込み")
                    Text(Fmt.yen(s.total))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                YearChart(months: engine.months(of: year, now: entry.date), current: MonthKey(entry.date), year: year)
                    .frame(maxHeight: .infinity)
                Divider()
                Text("年収の壁（給料日の月で集計）\(Fmt.yen(walls.total))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                ForEach(walls.statuses) { w in
                    HStack {
                        Text("\(Fmt.man(w.wall.amount))円")
                            .font(.caption.weight(.semibold))
                            .frame(width: 52, alignment: .leading)
                        Text(w.wall.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(w.isOver ? "超える見込み" : "あと\(Fmt.man(w.remaining))円")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(wallColor(w))
                    }
                    .monospacedDigit()
                }
            }
        }
    }
}

func wallColor(_ s: WallStatus?) -> Color {
    guard let s else { return .red }
    if s.isOver { return .red }
    if s.remaining < 100_000 { return .orange }
    return .accentColor
}

struct WallLine: View {
    let status: WallStatus?
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let s = status {
                HStack(alignment: .firstTextBaseline) {
                    Text(compact ? "\(Fmt.man(s.wall.amount))円まで" : "\(Fmt.man(s.wall.amount))円 \(s.wall.title)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if !compact {
                        Text("あと\(Fmt.man(s.remaining))円")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(wallColor(s))
                    }
                }
                if compact {
                    Text("あと\(Fmt.man(s.remaining))円")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(wallColor(s))
                }
                ProgressView(value: s.progress)
                    .tint(wallColor(s))
            } else {
                Text("178万円（所得税）を超える見込み")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .monospacedDigit()
    }
}

struct YearChart: View {
    let months: [MonthStats]
    let current: MonthKey
    let year: Int

    var body: some View {
        Chart {
            ForEach(Array(months.enumerated()), id: \.offset) { index, s in
                BarMark(x: .value("月", "\(index + 1)"), y: .value("金額", s.done))
                    .foregroundStyle(Color.accentColor)
                BarMark(x: .value("月", "\(index + 1)"), y: .value("金額", s.planned))
                    .foregroundStyle(Color.accentColor.opacity(0.35))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(Fmt.man(v)).font(.system(size: 8)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let m = value.as(String.self) {
                        Text(m)
                            .font(.system(size: 8, weight: Int(m) == current.month && current.year == year ? .bold : .regular))
                    }
                }
            }
        }
    }
}
