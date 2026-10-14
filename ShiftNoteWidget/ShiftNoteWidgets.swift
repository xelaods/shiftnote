import WidgetKit
import SwiftUI

@main
struct ShiftNoteWidgets: WidgetBundle {
    var body: some Widget {
        NextShiftWidget()
        MonthPayWidget()
        IncomeWidget()
        ShiftCalendarWidget()
    }
}

// MARK: - 共通

struct PayEntry: TimelineEntry {
    let date: Date
    let state: LoadState
}

/// 次に表示が変わる時刻（シフトの開始・終了、日付の変わり目、最長30分）
func nextRefresh(after now: Date, state: LoadState) -> Date {
    var candidates = [now.addingTimeInterval(30 * 60), DayKey(now).adding(days: 1).date]
    if case .ready(let engine) = state, let next = engine.next(after: now) {
        candidates.append(next.start > now ? next.start : next.end)
    }
    return candidates.filter { $0 > now }.min() ?? now.addingTimeInterval(1800)
}

struct PayProvider: TimelineProvider {
    func placeholder(in context: Context) -> PayEntry {
        PayEntry(date: Date(), state: .ready(Sample.engine()))
    }

    func getSnapshot(in context: Context, completion: @escaping (PayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let now = Date()
        let state = DataLoader.load(now: now)
        if case .message = state {
            completion(PayEntry(date: now, state: .ready(Sample.engine(now: now))))
        } else {
            completion(PayEntry(date: now, state: state))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PayEntry>) -> Void) {
        let now = Date()
        let state = DataLoader.load(now: now)
        completion(Timeline(entries: [PayEntry(date: now, state: state)], policy: .after(nextRefresh(after: now, state: state))))
    }
}

extension View {
    func widgetBackground() -> some View {
        containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}

struct MessageView: View {
    let text: String
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Shift Note：設定が必要です")
        case .accessoryRectangular, .accessoryCircular:
            VStack(alignment: .leading) {
                Text("Shift Note").font(.headline)
                Text("アプリで設定してください").font(.caption)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Shift Note")
                    .font(.headline)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct WidgetTitle: View {
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
    }
}

struct StatColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
