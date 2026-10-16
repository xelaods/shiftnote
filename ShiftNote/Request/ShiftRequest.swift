import Foundation

// シフコン（shifucon.ppihgroup.com）のシフト申請。
// 画面の form1 に入っている値をそのまま扱い、判定はシフコンの画面のスクリプトと同じ式にしている。

/// 時刻。シフコンは日をまたぐ時間を 26:00 のように 24 時以降で表す
struct ShiftClock: Hashable, Comparable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init?(hour: String, minute: String) {
        guard let h = Int(hour), let m = Int(minute) else { return nil }
        self.init(hour: h, minute: m)
    }

    var totalMinutes: Int { hour * 60 + minute }
    /// 18:30 / 26:00
    var label: String { "\(hour):" + String(format: "%02d", minute) }
    var hourString: String { String(format: "%02d", hour) }
    var minuteString: String { String(format: "%02d", minute) }

    static func < (a: ShiftClock, b: ShiftClock) -> Bool { a.totalMinutes < b.totalMinutes }

    /// シフコンで選べる時刻
    static let startHours = Array(5...28)
    static let endHours = Array(5...37)
    static let minutes = [0, 15, 30, 45]
}

/// 1日分の申請内容（シフコンのフォームの値そのまま）
struct RequestFields: Hashable {
    /// "1" 出勤 / "2" 休み
    var shiftType: String
    var fromHour: String
    var fromMinute: String
    var toHour: String
    var toMinute: String
    /// "0" なし / "1" 連絡欲しい / "2" 調整済み
    var flexibleType: String
    /// "0" 出勤 / "1" 休み / "2" 希望休 / "41" 前半休 / "42" 後半休
    var holidayType: String
    var holidayReason: String

    static let dayOff = RequestFields(shiftType: "2", fromHour: "", fromMinute: "", toHour: "", toMinute: "",
                                      flexibleType: "0", holidayType: "1", holidayReason: "")

    static func work(_ start: ShiftClock, _ end: ShiftClock, flexible: Bool = false) -> RequestFields {
        RequestFields(shiftType: "1", fromHour: start.hourString, fromMinute: start.minuteString,
                      toHour: end.hourString, toMinute: end.minuteString,
                      flexibleType: flexible ? "1" : "0", holidayType: "0", holidayReason: "")
    }

    var isWork: Bool { shiftType == "1" }
    /// "1830"（休みのときは ""）
    var time1: String { fromHour + fromMinute }
    var time2: String { toHour + toMinute }
    var start: ShiftClock? { ShiftClock(hour: fromHour, minute: fromMinute) }
    var end: ShiftClock? { ShiftClock(hour: toHour, minute: toMinute) }
    var wantsContact: Bool { flexibleType != "0" }

    var durationMinutes: Int? {
        guard isWork, let s = start, let e = end, e > s else { return nil }
        return e.totalMinutes - s.totalMinutes
    }

    var offLabel: String { Self.holidayLabel(holidayType) }

    /// 一覧に出す短い表示
    var label: String {
        if isWork, let s = start, let e = end { return "\(s.label)–\(e.label)" }
        return isWork ? "未入力" : offLabel
    }

    static func holidayLabel(_ type: String) -> String {
        switch type {
        case "2": return "希望休"
        case "41": return "前半休"
        case "42": return "後半休"
        case "4": return "有給"
        default: return "休み"
        }
    }

    /// 申請画面で選べる休日区分
    static let holidayTypes = ["1", "2", "41", "42"]
}

/// 申請期間の1日
struct RequestDay: Identifiable, Hashable {
    /// form1 の番号（0〜13）
    let index: Int
    let date: DayKey
    /// 祝日
    let isPublicHoliday: Bool
    /// 申請できる日か（締切後・確定済みは false）
    let editable: Bool
    /// これから送る値
    var fields: RequestFields
    /// 読み込んだときの値（取り消し用）
    let loaded: RequestFields
    /// 店舗に出している値（disp_*）。申請が必要かどうかはこれと比べる
    let original: RequestFields
    let originalUpdateFlag: String
    /// 期間の外の前日の終了・翌日の開始（"2600" など）
    let initialYesterdayTo: String
    let initialTomorrowFrom: String
    /// 店舗のシフト案・基本の時間など（出勤の候補）
    let suggestions: [RequestFields]

    var id: Int { index }
    var isEdited: Bool { fields != loaded }
    var isRedDay: Bool { date.weekday == 1 || isPublicHoliday }
}

/// 締切日・予定時間などの1行
struct RequestInfo: Hashable {
    let label: String
    let value: String
}

/// 2週間分の申請画面
struct RequestPeriod: Hashable {
    var from: DayKey
    var to: DayKey
    var staffName: String
    var storeName: String
    var deadline: String?
    var infos: [RequestInfo]
    var days: [RequestDay]
    var canGoBack: Bool
    var canGoNext: Bool
    var canCopy: Bool
    /// 申請ボタンがある（締切前の期間）
    var isOpen: Bool
    /// 「申請済」など
    var statusText: String?
    /// 「申請」「再申請」
    var applyTitle: String?
    /// シフコン側ですでに申請できる状態になっている（前回のコピー後など）
    var serverCanApply: Bool
    var messages: [String]

    var editedCount: Int { days.filter(\.isEdited).count }
    var canApply: Bool { isOpen && (ShiftRequestLogic.updateFlags(days).contains("1") || serverCanApply) }
    var hasEdits: Bool { editedCount > 0 }
}

enum RequestError: Error, Equatable {
    case message(String)
    var text: String {
        switch self { case .message(let s): return s }
    }
}

/// シフコンの画面のスクリプト（#shift-apply-ok・#staffpage-index-footer-apply）と同じ判定
enum ShiftRequestLogic {
    /// 前日の終了（"2600"）。期間の初日は期間の外の値
    static func yesterdayTo(_ days: [RequestDay], at i: Int) -> String {
        guard days.indices.contains(i) else { return "" }
        if i == 0 { return days[0].initialYesterdayTo }
        let prev = days[i - 1].fields
        return prev.isWork ? prev.time2 : ""
    }

    /// 翌日の開始（"1000"）。期間の最終日は期間の外の値
    static func tomorrowFrom(_ days: [RequestDay], at i: Int) -> String {
        guard days.indices.contains(i) else { return "" }
        if i == days.count - 1 { return days[i].initialTomorrowFrom }
        let next = days[i + 1].fields
        return next.isWork ? next.time1 : ""
    }

    /// 1日の変更を確定する。input の flexibleType は「連絡欲しい」なら "1"、そうでなければ "0"
    static func commit(_ input: RequestFields, for day: RequestDay, yesterdayTo: String, tomorrowFrom: String) -> Result<RequestFields, RequestError> {
        var f = input
        if f.shiftType != "1" && f.shiftType != "2" {
            return .failure(.message("シフト種別を選択してください。"))
        }
        if f.isWork {
            if f.fromHour.isEmpty || f.fromMinute.isEmpty || f.toHour.isEmpty || f.toMinute.isEmpty {
                return .failure(.message("勤務時間を入力してください。"))
            }
            let t1 = Int(f.time1) ?? 0
            let t2 = Int(f.time2) ?? 0
            if t1 >= t2 {
                return .failure(.message("勤務時間が間違っています。"))
            }
            let s = f.start?.totalMinutes ?? 0, e = f.end?.totalMinutes ?? 0
            if e - s > 24 * 60 {
                return .failure(.message("勤務時間は24時間以内で入力してください。"))
            }
            if (Int(yesterdayTo) ?? 0) - 2900 > t1 - 500 {
                return .failure(.message("前日の勤務時間と重複しています。"))
            }
            if !tomorrowFrom.isEmpty, t2 - 2900 > (Int(tomorrowFrom) ?? 0) - 500 {
                return .failure(.message("明日の勤務時間と重複しています。"))
            }
            f.holidayType = "0"
            f.holidayReason = ""
        } else {
            f.fromHour = ""; f.fromMinute = ""; f.toHour = ""; f.toMinute = ""
            f.flexibleType = "0"
            if f.holidayType == "0" || f.holidayType.isEmpty { f.holidayType = "1" }
            if f.holidayType != "2" { f.holidayReason = "" }
            f.holidayReason = String(f.holidayReason.prefix(35))
        }

        // 変更があり、ゆうずうフラグが立っていた場合はステータスを調整前に戻す
        let org = day.original
        if org.shiftType != f.shiftType {
            if f.shiftType == "2" {
                f.flexibleType = "0"
            } else if f.flexibleType == "2" {
                f.flexibleType = "1"
            }
        } else if org.shiftType == "1" && (org.time1 != f.time1 || org.time2 != f.time2) {
            if f.flexibleType == "2" { f.flexibleType = "1" }
        } else if f.flexibleType == "1" && org.flexibleType == "2" {
            f.flexibleType = org.flexibleType
        } else if f.shiftType == "2" {
            f.flexibleType = "0"
        }
        return .success(f)
    }

    /// 送信する update_flg。シフコンと同じく、一度変更が見つかるとそれ以降の日もすべて "1" になる
    static func updateFlags(_ days: [RequestDay]) -> [String] {
        var flag = false
        return days.map { day in
            let org = day.original, cur = day.fields
            var flexible = cur.flexibleType
            if org.shiftType != cur.shiftType { flag = true }
            // 調整済みのまま「連絡欲しい」で申請した場合は変更なしと見なす
            if org.flexibleType == "2" && flexible == "1" { flexible = "2" }
            if org.shiftType == "2" && org.flexibleType != flexible { flag = true }
            if org.shiftType == "2" && (org.holidayType != cur.holidayType || (cur.holidayType == "2" && org.holidayReason != cur.holidayReason)) {
                flag = true
            }
            if org.shiftType == "1" && (org.time1 != cur.time1 || org.time2 != cur.time2 || org.flexibleType != flexible) {
                flag = true
            }
            return flag ? "1" : "0"
        }
    }

    /// 申請前の確認（期間の初日・最終日が期間の外のシフトと重ならないか）
    static func applyCheck(_ days: [RequestDay]) -> String? {
        if let first = days.first, first.fields.isWork, !first.initialYesterdayTo.isEmpty,
           (Int(first.initialYesterdayTo) ?? 0) - 2900 > (Int(first.fields.time1) ?? 0) - 500 {
            return "開始日の勤務時間が前日と重複しています。"
        }
        if let last = days.last, last.fields.isWork, !last.initialTomorrowFrom.isEmpty,
           (Int(last.fields.time2) ?? 0) - 2900 > (Int(last.initialTomorrowFrom) ?? 0) - 500 {
            return "終了日の勤務時間が翌日と重複しています。"
        }
        return nil
    }

    /// 申請後に読み込み直した期間で、送った内容が店舗側の値（disp_*）になっているか
    static func unreflectedDays(sent: [RequestDay], reloaded: RequestPeriod) -> [DayKey] {
        let byDate = Dictionary(reloaded.days.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        return sent.compactMap { day in
            guard day.fields != day.original, let now = byDate[day.date] else { return nil }
            let a = day.fields, b = now.original
            let same = a.shiftType == b.shiftType && a.time1 == b.time1 && a.time2 == b.time2
                && (a.isWork || a.holidayType == b.holidayType)
            return same ? nil : day.date
        }
    }
}
