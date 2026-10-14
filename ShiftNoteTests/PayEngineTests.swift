import XCTest
@testable import ShiftNote

final class PayEngineTests: XCTestCase {
    private func jst(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        JST.gregorian.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private var rates: PayRates {
        var r = PayRates()
        r.transport = 300
        return r
    }

    // Scriptable版と同じ金額になること
    func testWeekdayEvening() {
        // 2026/10/14（水）17:00〜22:00
        let p = PayCalculator.breakdown(start: jst(2026, 10, 14, 17), end: jst(2026, 10, 14, 22), rates: rates)
        XCTAssertEqual(Fmt.yen(p.total), "¥7,050")
        XCTAssertEqual(p.restMinutes, 0)
        XCTAssertEqual(p.nightMinutes, 0)
    }

    func testNightWithBreak() {
        // 17:00〜23:30（6.5時間・休憩30分・22時以降は深夜）
        let p = PayCalculator.breakdown(start: jst(2026, 10, 14, 17), end: jst(2026, 10, 14, 23, 30), rates: rates)
        XCTAssertEqual(Fmt.yen(p.total), "¥8,867")
        XCTAssertEqual(p.restMinutes, 30)
        XCTAssertEqual(p.paidMinutes, 360)
    }

    func testSaturdayLong() {
        // 2026/10/17（土）10:00〜18:00（8時間・休憩60分）
        let p = PayCalculator.breakdown(start: jst(2026, 10, 17, 10), end: jst(2026, 10, 17, 18), rates: rates)
        XCTAssertEqual(Fmt.yen(p.total), "¥10,100")
    }

    func testCrossMidnightIntoSunday() {
        // 土曜22:00〜日曜2:00：日付が変わったら日曜の時給
        var r = PayRates()
        r.saturday = 1000
        r.sunday = 2000
        r.nightPremium = 0
        let p = PayCalculator.breakdown(start: jst(2026, 10, 17, 22), end: jst(2026, 10, 18, 2), rates: r)
        XCTAssertEqual(p.base, 2 * 1000 + 2 * 2000, accuracy: 0.001)
    }

    func testPayMonth() {
        var s = AppSettings()
        s.closingDay = 15
        s.payOffset = 1
        let shifts = [
            Shift(start: jst(2026, 12, 10, 17), end: jst(2026, 12, 10, 22)), // 12/15締め → 1月払い
            Shift(start: jst(2026, 12, 20, 17), end: jst(2026, 12, 20, 22))  // 1/15締め → 2月払い
        ]
        let e = PayEngine(shifts: shifts, settings: s)
        XCTAssertEqual(e.items[0].payMonth, MonthKey(year: 2027, month: 1))
        XCTAssertEqual(e.items[1].payMonth, MonthKey(year: 2027, month: 2))
    }

    func testMonthKeyNormalizes() {
        XCTAssertEqual(MonthKey(year: 2026, month: 13), MonthKey(year: 2027, month: 1))
        XCTAssertEqual(MonthKey(year: 2026, month: 0), MonthKey(year: 2025, month: 12))
    }

    func testMonthWeeks() {
        // 2026年10月は木曜始まり。日曜始まりで5週
        let weeks = MonthKey(year: 2026, month: 10).weeks(firstWeekday: 1)
        XCTAssertEqual(weeks.count, 5)
        XCTAssertEqual(weeks[0][0], DayKey(year: 2026, month: 9, day: 27))
        XCTAssertEqual(weeks[0][0].weekday, 1)
    }

    func testWalls() {
        let shift = Shift(start: jst(2026, 3, 2, 17), end: jst(2026, 3, 2, 22))
        let e = PayEngine(shifts: [shift], settings: AppSettings())
        let w = e.walls(year: 2026, now: jst(2026, 10, 14, 12))
        XCTAssertEqual(w.statuses.count, IncomeWall.all.count)
        XCTAssertFalse(w.statuses[0].isOver)
    }
}
