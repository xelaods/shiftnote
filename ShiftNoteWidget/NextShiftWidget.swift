import WidgetKit
import SwiftUI

struct NextShiftWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "NextShift", intent: PayWidgetIntent.self, provider: PayProvider()) { entry in
            NextShiftView(entry: entry).widgetBackground()
        }
        .configurationDisplayName("次のシフト")
        .description("次に入っているシフトの時間と給与を表示します。")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct NextShiftView: View {
    let entry: PayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .message(let text):
            MessageView(text: text)
        case .ready(let engine):
            content(engine.next(after: entry.date))
        }
    }

    @ViewBuilder
    private func content(_ next: ShiftItem?) -> some View {
        let now = entry.date
        switch family {
        case .accessoryInline:
            if let next {
                Text("\(Fmt.monthDay(next.start)) \(Fmt.time(next.start))〜\(Fmt.time(next.end))")
            } else {
                Text("シフトの予定なし")
            }
        case .accessoryRectangular:
            if let next {
                VStack(alignment: .leading, spacing: 0) {
                    Text(next.start <= now ? "勤務中" : "\(Fmt.dayWithWeekday(next.start))")
                        .font(.caption.weight(.semibold))
                    Text("\(Fmt.time(next.start))〜\(Fmt.time(next.end))")
                        .font(.headline)
                        .monospacedDigit()
                    Text(Fmt.yen(next.pay.total))
                        .font(.caption)
                        .monospacedDigit()
                }
                .widgetAccentable()
            } else {
                Text("シフトの予定なし").font(.headline)
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                WidgetTitle(text: next.map { $0.start <= now ? "勤務中" : "次のシフト" } ?? "次のシフト")
                if let next {
                    Text("\(Fmt.dayWithWeekday(next.start))・\(Fmt.relativeDay(next.start, now: now))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(Fmt.time(next.start))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                    Text("〜\(Fmt.time(next.end))")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer(minLength: 2)
                    Text("\(Fmt.yen(next.pay.total))・\(Fmt.hours(next.pay.paidMinutes))時間")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Spacer()
                    Text("予定されたシフトはありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
