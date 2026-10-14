import SwiftUI
import UIKit

/// 色と文字のルール。
/// タイムカードのような紙（paper）とインク（ink）を基本に、
/// シフトの時間帯（朝・昼・夕・夜）で色を変える。アクセントは Shift Note のティール。
enum Theme {
    static let paper = dynamic(light: 0xF3F2EE, dark: 0x0E0F11)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x1A1B1E)
    static let ink = dynamic(light: 0x16181B, dark: 0xF3F2EE)
    static let muted = dynamic(light: 0x6C7077, dark: 0x989CA3)
    static let faint = dynamic(light: 0xA4A7AC, dark: 0x5C5F65)
    static let line = dynamic(light: 0xE3E2DD, dark: 0x2A2C30)
    static let fill = dynamic(light: 0xEBEAE5, dark: 0x232528)

    static let accent = dynamic(light: 0x0B9A8A, dark: 0x45D2BF)
    static let positive = dynamic(light: 0x1E9157, dark: 0x3DBB78)
    static let warning = dynamic(light: 0xD98A0B, dark: 0xF2B53C)
    static let negative = dynamic(light: 0xD7263D, dark: 0xF0485A)
    static let sunday = dynamic(light: 0xD7263D, dark: 0xF0606E)
    static let saturday = dynamic(light: 0x2F64D6, dark: 0x6C95F2)

    /// 数字：細長い太字（タイムカードの刻印のような字面）
    static func number(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    /// 小見出し
    static let label = Font.system(size: 12, weight: .bold).width(.condensed)

    static func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: return sunday
        case 7: return saturday
        default: return ink
        }
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// シフトの時間帯。開始時刻で決める
enum ShiftBand: CaseIterable {
    case morning, day, evening, night

    init(start: Date) {
        let hour = Int(((start.timeIntervalSince1970 + JST.offset).truncatingRemainder(dividingBy: 86400)) / 3600)
        switch hour {
        case 5..<11: self = .morning
        case 11..<16: self = .day
        case 16..<21: self = .evening
        default: self = .night
        }
    }

    var color: Color {
        switch self {
        case .morning: return Theme.dynamic(light: 0xE09A12, dark: 0xF4BC45)
        case .day: return Theme.dynamic(light: 0xE0602C, dark: 0xF5804F)
        case .evening: return Theme.accent
        case .night: return Theme.dynamic(light: 0x4C50D0, dark: 0x8A8EF7)
        }
    }

    var label: String {
        switch self {
        case .morning: return "朝"
        case .day: return "昼"
        case .evening: return "夕"
        case .night: return "夜"
        }
    }
}

extension ShiftItem {
    var band: ShiftBand { ShiftBand(start: start) }
    /// 交通費を除いた、いままでに稼いだ額（勤務中の表示用）
    func earned(at now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let ratio = min(1, max(0, now.timeIntervalSince(start) / total))
        return (pay.total - pay.transport) * ratio
    }
    func progress(at now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }
}

// MARK: - 共通の部品（アプリとウィジェットで使う）

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.label)
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
    }
}

/// 勤務済み（濃い）とこれから（薄い）の2段のバー
struct SplitBar: View {
    let done: Double
    let total: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let p = total > 0 ? min(1, done / total) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.fill)
                if total > 0 { Capsule().fill(color.opacity(0.3)) }
                Capsule().fill(color)
                    .frame(width: total > 0 && done > 0 ? max(height, w * p) : 0)
            }
        }
        .frame(height: height)
    }
}

/// 年収の壁のメーター（0〜200万円、壁の位置に目盛り）
struct WallMeter: View {
    let value: Double
    var height: CGFloat = 8
    var showsLabels = true
    private let scale = 2_000_000.0
    private let ticks: [Double] = [1_100_000, 1_300_000, 1_500_000, 1_780_000]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .topLeading) {
                if showsLabels {
                    ForEach(ticks, id: \.self) { t in
                        Text("\(Int(t / 10000))")
                            .font(.system(size: 9, weight: .semibold).width(.condensed))
                            .foregroundStyle(Theme.muted)
                            .fixedSize()
                            .position(x: w * t / scale, y: 5)
                    }
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accent.opacity(0.75), Theme.accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: value > 0 ? max(height, min(1, value / scale) * w) : 0)
                    ForEach(ticks, id: \.self) { t in
                        Rectangle()
                            .fill(value >= t ? Theme.paper.opacity(0.9) : Theme.ink.opacity(0.35))
                            .frame(width: 1.5, height: height + 6)
                            .offset(x: w * t / scale - 0.75)
                    }
                }
                .frame(height: height)
                .offset(y: showsLabels ? 13 : 0)
            }
        }
        .frame(height: showsLabels ? height + 16 : height)
    }
}

/// 金額の大きな表示（数字が変わるときにめくれる）
struct Amount: View {
    let value: Double
    var size: CGFloat = 44
    var color: Color = Theme.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("¥")
                .font(Theme.number(size * 0.55, weight: .bold))
                .foregroundStyle(color.opacity(0.6))
            Text(Fmt.yen(value).dropFirst())
                .font(Theme.number(size, weight: .black))
                .foregroundStyle(color)
                .contentTransition(.numericText(value: value))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

/// 小さな数字のまとまり（「勤務時間 86.5時間」など）
struct StatTile: View {
    let title: String
    let value: String
    var unit: String = ""
    var tint: Color = Theme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Theme.number(22, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

