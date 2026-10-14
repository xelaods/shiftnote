import WidgetKit
import SwiftUI

struct MonthPayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthPay", provider: PayProvider()) { entry in
            MonthPayView(entry: entry).widgetBackground()
        }
        .configurationDisplayName("今月の給与")
        .description("今月の予想給与と勤務時間を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct MonthPayView: View {
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
        let month = MonthKey(entry.date)
        let s = engine.stats(for: month, now: entry.date)
        switch family {
        case .accessoryInline:
            Text("\(month.month)月 \(Fmt.yen(s.total))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text("\(month.month)月の給与").font(.caption.weight(.semibold))
                Text(Fmt.yen(s.total)).font(.headline).monospacedDigit().widgetAccentable()
                Text("\(Fmt.hours(s.paidMinutes))時間・\(s.days)日").font(.caption).monospacedDigit()
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetTitle(text: "\(month.month)月の給与")
                    Text("控除前の見込み").font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(Fmt.yen(s.total))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    ProgressView(value: s.progress)
                    Text("勤務済み \(Fmt.yen(s.done))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 8) {
                    StatColumn(title: "勤務時間", value: "\(Fmt.hours(s.paidMinutes))時間")
                    StatColumn(title: "勤務日数", value: "\(s.days)日")
                    StatColumn(title: "実質時給", value: s.effectiveHourly.map(Fmt.yen) ?? "—")
                }
                .frame(width: 92, alignment: .leading)
            }
        default:
            VStack(alignment: .leading, spacing: 3) {
                WidgetTitle(text: "\(month.month)月の給与")
                Text("控除前の見込み").font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(Fmt.yen(s.total))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                ProgressView(value: s.progress)
                Spacer(minLength: 0)
                Text("\(Fmt.hours(s.paidMinutes))時間・\(s.days)日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
