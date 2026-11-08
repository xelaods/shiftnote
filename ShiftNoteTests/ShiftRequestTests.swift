import XCTest
@testable import ShiftNote

/// シフト申請の判定が、シフコンの画面のスクリプトと同じになること
final class ShiftRequestTests: XCTestCase {
    private func work(_ h1: Int, _ h2: Int, flexible: String = "0") -> RequestFields {
        var f = RequestFields.work(ShiftClock(hour: h1, minute: 0), ShiftClock(hour: h2, minute: 0))
        f.flexibleType = flexible
        return f
    }

    private func day(_ i: Int, _ f: RequestFields, yesterday: String = "", tomorrow: String = "") -> RequestDay {
        RequestDay(index: i, date: DayKey(year: 2026, month: 11, day: 8 + i), isPublicHoliday: false, editable: true,
                   fields: f, loaded: f, original: f, originalUpdateFlag: "0",
                   initialYesterdayTo: yesterday, initialTomorrowFrom: tomorrow, suggestions: [])
    }

    func testUpdateFlagsTurnOnFromFirstChange() {
        var days = (0..<5).map { day($0, work(18, 23)) }
        XCTAssertEqual(ShiftRequestLogic.updateFlags(days), ["0", "0", "0", "0", "0"])
        days[2].fields = work(20, 23)
        XCTAssertEqual(ShiftRequestLogic.updateFlags(days), ["0", "0", "1", "1", "1"])
        days[2].fields = .dayOff
        XCTAssertEqual(ShiftRequestLogic.updateFlags(days), ["0", "0", "1", "1", "1"])
    }

    func testDesiredDayOffReasonCountsAsChange() {
        var days = [day(0, .dayOff), day(1, .dayOff)]
        days[1].fields.holidayType = "2"
        days[1].fields.holidayReason = "試験"
        XCTAssertEqual(ShiftRequestLogic.updateFlags(days), ["0", "1"])
    }

    func testCommitRejectsReversedTimes() {
        let d = day(0, work(18, 23))
        let r = ShiftRequestLogic.commit(work(23, 18), for: d, yesterdayTo: "", tomorrowFrom: "")
        XCTAssertEqual(r, .failure(.message("勤務時間が間違っています。")))
    }

    func testCommitChecksNeighbours() {
        let d = day(0, work(18, 23))
        // 前日が 30:00（翌6時）まで → 5:00 開始は重なる
        XCTAssertEqual(ShiftRequestLogic.commit(work(5, 10), for: d, yesterdayTo: "3000", tomorrowFrom: ""),
                       .failure(.message("前日の勤務時間と重複しています。")))
        // 前日が 26:00 まで → 10:00 開始は大丈夫
        XCTAssertNoThrow(try ShiftRequestLogic.commit(work(10, 23), for: d, yesterdayTo: "2600", tomorrowFrom: "").get())
        // 30:00 まで働くと、翌日 5:00 開始と重なる
        XCTAssertEqual(ShiftRequestLogic.commit(work(20, 30), for: d, yesterdayTo: "", tomorrowFrom: "0500"),
                       .failure(.message("明日の勤務時間と重複しています。")))
    }

    func testCommitDayOffClearsTimes() throws {
        let d = day(0, work(18, 23, flexible: "1"))
        var input = RequestFields.dayOff
        input.holidayType = "41"
        input.holidayReason = "消える"
        let f = try ShiftRequestLogic.commit(input, for: d, yesterdayTo: "", tomorrowFrom: "").get()
        XCTAssertEqual(f.time1, "")
        XCTAssertEqual(f.flexibleType, "0")
        XCTAssertEqual(f.holidayType, "41")
        XCTAssertEqual(f.holidayReason, "")
    }

    func testAdjustedFlexibleIsKeptWhenUnchanged() throws {
        let d = day(0, work(18, 23, flexible: "2"))
        // 時間を変えずに「連絡欲しい」のまま → 調整済み（2）のまま
        let same = try ShiftRequestLogic.commit(work(18, 23, flexible: "1"), for: d, yesterdayTo: "", tomorrowFrom: "").get()
        XCTAssertEqual(same.flexibleType, "2")
        // 時間を変えたら調整前（1）に戻る
        let changed = try ShiftRequestLogic.commit(work(19, 23, flexible: "1"), for: d, yesterdayTo: "", tomorrowFrom: "").get()
        XCTAssertEqual(changed.flexibleType, "1")
    }

    func testNeighbourTimesFollowEdits() {
        var days = [day(0, work(10, 26), yesterday: "2300"), day(1, .dayOff), day(2, work(20, 23), tomorrow: "1000")]
        XCTAssertEqual(ShiftRequestLogic.yesterdayTo(days, at: 0), "2300")
        XCTAssertEqual(ShiftRequestLogic.yesterdayTo(days, at: 1), "2600")
        XCTAssertEqual(ShiftRequestLogic.tomorrowFrom(days, at: 1), "2000")
        XCTAssertEqual(ShiftRequestLogic.tomorrowFrom(days, at: 2), "1000")
        days[1].fields = work(18, 23)
        XCTAssertEqual(ShiftRequestLogic.yesterdayTo(days, at: 2), "2300")
    }

    func testUnreflectedDays() {
        var sent = [day(0, work(18, 23)), day(1, work(18, 23))]
        sent[1].fields = work(20, 26)
        var reloaded = RequestPeriod.demo()
        reloaded.days = [day(0, work(18, 23)), day(1, work(18, 23))]
        XCTAssertEqual(ShiftRequestLogic.unreflectedDays(sent: sent, reloaded: reloaded), [DayKey(year: 2026, month: 11, day: 9)])
        reloaded.days = [day(0, work(18, 23)), day(1, work(20, 26))]
        XCTAssertEqual(ShiftRequestLogic.unreflectedDays(sent: sent, reloaded: reloaded), [])
    }

    private func calendarDay(_ index: Int, _ date: DayKey, _ fields: RequestFields,
                              original: RequestFields? = nil) -> RequestDay {
        RequestDay(index: index, date: date, isPublicHoliday: false, editable: true,
                   fields: fields, loaded: fields, original: original ?? fields, originalUpdateFlag: "0",
                   initialYesterdayTo: "", initialTomorrowFrom: "", suggestions: [])
    }

    private func calendarPeriod(_ days: [RequestDay]) -> RequestPeriod {
        RequestPeriod(from: days.first!.date, to: days.last!.date, staffName: "", storeName: "",
                      deadline: nil, infos: [], days: days, canGoBack: false, canGoNext: false,
                      canCopy: false, isOpen: true, statusText: nil, applyTitle: nil,
                      serverCanApply: false, messages: [])
    }

    func testCalendarSnapshotUsesLoadedFiveDatesIncludingOvernightShift() throws {
        let today = DayKey(year: 2026, month: 11, day: 8)
        let days = (0..<5).map { offset -> RequestDay in
            let date = today.adding(days: offset)
            if offset == 2 { return calendarDay(offset, date, .dayOff) }
            if offset == 4 {
                return calendarDay(offset, date, work(26, 32), original: work(18, 26))
            }
            return calendarDay(offset, date, work(10, 23))
        }

        let shifts = try XCTUnwrap(ShifconCalendarSnapshot.make(
            from: calendarPeriod(days), now: today.date.addingTimeInterval(12 * 60 * 60)
        ))
        XCTAssertEqual(shifts.count, 4)
        XCTAssertEqual(shifts[0].sourceID, "date-20261108")
        XCTAssertEqual(shifts[0].start, today.date.addingTimeInterval(10 * 60 * 60))
        XCTAssertEqual(shifts[0].end, today.date.addingTimeInterval(23 * 60 * 60))
        XCTAssertEqual(shifts[3].sourceID, "date-20261112")
        XCTAssertEqual(shifts[3].start, today.adding(days: 5).date.addingTimeInterval(2 * 60 * 60))
        XCTAssertEqual(shifts[3].end, today.adding(days: 5).date.addingTimeInterval(8 * 60 * 60))
    }

    func testCalendarSnapshotRejectsIncompleteOrInvalidData() {
        let today = DayKey(year: 2026, month: 11, day: 8)
        let fourDays = (0..<4).map { i in calendarDay(i, today.adding(days: i), work(10, 23)) }
        XCTAssertNil(ShifconCalendarSnapshot.make(from: calendarPeriod(fourDays), now: today.date))

        var days = (0..<5).map { i in calendarDay(i, today.adding(days: i), work(10, 23)) }
        var invalid = RequestFields(shiftType: "1", fromHour: "", fromMinute: "",
                                    toHour: "23", toMinute: "00", flexibleType: "0",
                                    holidayType: "0", holidayReason: "")
        days[1] = calendarDay(1, today.adding(days: 1), invalid)
        XCTAssertNil(ShifconCalendarSnapshot.make(from: calendarPeriod(days), now: today.date))

        invalid = .dayOff
        days[1] = calendarDay(1, today.adding(days: 1), invalid)
        days.append(calendarDay(5, today.adding(days: 1), .dayOff))
        XCTAssertNil(ShifconCalendarSnapshot.make(from: calendarPeriod(days), now: today.date))
    }

    func testCompleteAllOffSnapshotIsEmptyAndValid() throws {
        let today = DayKey(year: 2026, month: 11, day: 8)
        let days = (0..<5).map { i in calendarDay(i, today.adding(days: i), .dayOff) }
        XCTAssertEqual(try XCTUnwrap(ShifconCalendarSnapshot.make(
            from: calendarPeriod(days), now: today.date
        )).count, 0)
    }

    func testScrapedPageBecomesPeriod() throws {
        let json = """
        {"ok":true,"from":"20261108","to":"20261121","staff":"塩中 陽翔","store":"葛西店",
         "infos":[["締切日：10/26(月)"],["11月予定","235:00"],["個人設定時間","0:00～76:00"]],
         "days":[
          {"i":0,"date":"20261108","edit":"1","disabled":false,"st":"1","fh":"10","fm":"00","th":"23","tm":"00","fx":"0","ht":"0","hr":"","hol":"0",
           "dst":"1","dfh":"10","dfm":"00","dth":"23","dtm":"00","dfx":"0","dht":"0","dhr":"","dup":"0","yt":"2600","tf":"",
           "cfh":"10","cfm":"00","cth":"23","ctm":"00","mfh":"10","mfm":"00","mth":"23","mtm":"00"},
          {"i":1,"date":"20261109","edit":"1","disabled":false,"st":"2","fh":"","fm":"","th":"","tm":"","fx":"0","ht":"1","hr":"","hol":"0",
           "dst":"2","dfh":"","dfm":"","dth":"","dtm":"","dfx":"0","dht":"1","dhr":"","dup":"0","yt":"2300","tf":"2000",
           "cfh":"","cfm":"","cth":"","ctm":"","mfh":"","mfm":"","mth":"","mtm":""}
         ],
         "back":true,"next":true,"copy":true,"status":"申請済","footer":true,"applyTitle":"再申請","canApply":"0","messages":[]}
        """
        let page = try JSONDecoder().decode(ScrapedPage.self, from: Data(json.utf8))
        let p = try XCTUnwrap(page.period())
        XCTAssertEqual(p.from, DayKey(year: 2026, month: 11, day: 8))
        XCTAssertEqual(p.deadline, "10/26(月)")
        XCTAssertEqual(p.infos, [RequestInfo(label: "11月予定", value: "235:00"), RequestInfo(label: "個人設定時間", value: "0:00～76:00")])
        XCTAssertEqual(p.days.count, 2)
        XCTAssertEqual(p.days[0].fields.label, "10:00–23:00")
        XCTAssertEqual(p.days[1].fields.offLabel, "休み")
        XCTAssertEqual(p.days[0].suggestions.count, 1)
        XCTAssertTrue(p.isOpen)
        XCTAssertFalse(p.canApply)
    }
}
