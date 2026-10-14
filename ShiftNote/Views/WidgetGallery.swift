import SwiftUI
import WidgetKit

/// ウィジェットの見本（起動引数 -gallery で表示。見た目の確認用）
struct WidgetGallery: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    tile(.systemSmall) { NextShiftWidgetView(engine: model.engine, now: model.now, family: .systemSmall) }
                    tile(.systemSmall) { MonthPayWidgetView(engine: model.engine, now: model.now, family: .systemSmall) }
                }
                tile(.systemMedium) { MonthPayWidgetView(engine: model.engine, now: model.now, family: .systemMedium) }
                tile(.systemMedium) { CalendarWidgetView(engine: model.engine, now: model.now, family: .systemMedium, span: .weekCentered) }
                tile(.systemMedium) { IncomeWidgetView(engine: model.engine, now: model.now, family: .systemMedium) }
                HStack(alignment: .top, spacing: 14) {
                    tile(.systemSmall) { IncomeWidgetView(engine: model.engine, now: model.now, family: .systemSmall) }
                    tile(.systemSmall) { CalendarWidgetView(engine: model.engine, now: model.now, family: .systemSmall, span: .weekCentered) }
                }
                tile(.systemMedium) { CalendarWidgetView(engine: model.engine, now: model.now, family: .systemMedium, span: .twoWeeks) }
                tile(.systemLarge) { CalendarWidgetView(engine: model.engine, now: model.now, family: .systemLarge, span: .month) }
                tile(.systemLarge) { IncomeWidgetView(engine: model.engine, now: model.now, family: .systemLarge) }
                HStack(spacing: 14) {
                    accessory { NextShiftWidgetView(engine: model.engine, now: model.now, family: .accessoryRectangular) }
                    accessory { IncomeWidgetView(engine: model.engine, now: model.now, family: .accessoryRectangular) }
                }
            }
            .padding(16)
        }
        .background(Color(white: 0.45).ignoresSafeArea())
    }

    private func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 354, height: 170)
        default: return CGSize(width: 354, height: 376)
        }
    }

    private func tile<V: View>(_ family: WidgetFamily, @ViewBuilder _ content: () -> V) -> some View {
        let s = size(family)
        return content()
            .padding(16)
            .frame(width: s.width, height: s.height)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func accessory<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content()
            .foregroundStyle(.white)
            .frame(width: 160, height: 72, alignment: .leading)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
