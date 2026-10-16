import Foundation

/// シフコンの画面で動かすスクリプト
enum ShifconScripts {
    /// 画面の内容を JSON 文字列で返す
    static let scrape = #"""
    (function(){
      function v(id){ var e = document.getElementById(id); return e ? String(e.value) : null; }
      function n(name){ var e = document.querySelector('#form1 input[name="' + name + '"]'); return e ? String(e.value) : null; }
      function clean(s){ return (s || '').replace(/ /g, ' ').trim(); }
      var r = {
        ok: false,
        hasPassword: !!document.querySelector('input[type=password]'),
        url: location.href,
        title: document.title,
        text: clean(document.body ? document.body.innerText : '').slice(0, 400)
      };
      var f = document.getElementById('form1');
      if (!f || !f.querySelector('input[name="select_date0"]')) { return JSON.stringify(r); }
      r.ok = true;
      r.from = n('target_date_from');
      r.to = n('target_date_to');
      var names = document.querySelectorAll('.header_name li');
      r.staff = names[0] ? clean(names[0].innerText) : '';
      r.store = names[1] ? clean(names[1].innerText) : '';
      r.infos = [].slice.call(document.querySelectorAll('.staffpage-discription')).map(function(e){
        return clean(e.innerText).split(/[\n\t]+/).map(clean).filter(function(s){ return s.length > 0; });
      });
      var days = [];
      for (var i = 0; i < 42; i++) {
        if (!f.querySelector('input[name="select_date' + i + '"]')) { continue; }
        var btn = document.getElementById('staffpage-index-shift' + i);
        days.push({
          i: i,
          date: n('select_date' + i), edit: n('edit_flg' + i),
          disabled: btn ? !!btn.disabled : true, cls: btn ? btn.className : '',
          st: n('shift_type' + i), fh: n('from_hour' + i), fm: n('from_minutes' + i),
          th: n('to_hour' + i), tm: n('to_minutes' + i), fx: n('flexible_type' + i),
          ht: n('holiday_type' + i), hr: n('holiday_reason' + i), hol: n('holiday' + i),
          dst: v('disp_shift_type' + i), dfh: v('disp_from_hour' + i), dfm: v('disp_from_minutes' + i),
          dth: v('disp_to_hour' + i), dtm: v('disp_to_minutes' + i), dfx: v('disp_flexible_type' + i),
          dht: v('disp_holiday_type' + i), dhr: v('disp_holiday_reason' + i), dup: v('disp_update_flg' + i),
          yt: v('yesterday_working_time_to' + i), tf: v('tomorrow_working_time_from' + i),
          cfh: v('create_from_hour' + i), cfm: v('create_from_minutes' + i), cth: v('create_to_hour' + i), ctm: v('create_to_minutes' + i),
          mfh: v('master_from_hour' + i), mfm: v('master_from_minutes' + i), mth: v('master_to_hour' + i), mtm: v('master_to_minutes' + i)
        });
      }
      r.days = days;
      var back = document.getElementById('date-back'), next = document.getElementById('date-next');
      r.back = !!back && !back.disabled;
      r.next = !!next && !next.disabled;
      var copy = document.getElementById('date-copy');
      r.copy = !!copy && !copy.disabled;
      var status = document.getElementById('staffpage-index-footer-status');
      r.status = status ? clean(status.innerText) : null;
      var apply = document.getElementById('staffpage-index-footer-apply');
      r.footer = !!apply;
      r.applyTitle = apply ? clean(apply.innerText) : null;
      r.canApply = apply ? String(apply.getAttribute('data-can_apply')) : null;
      var msgs = [];
      document.querySelectorAll('.error-message, #copy_error, .attention, .ui-popup-active .ui-content').forEach(function(e){
        if (e.id === 'shift-apply-error' || (e.closest && e.closest('#shift-apply'))) { return; }
        if (e.offsetParent === null) { return; }
        var t = clean(e.innerText);
        if (t && msgs.indexOf(t) < 0) { msgs.push(t); }
      });
      r.messages = msgs;
      return JSON.stringify(r);
    })();
    """#

    /// 前後の期間・前回のコピー（シフコンのボタンと同じ送信）
    static func submit(mode: String) -> String {
        "eccube.setModeAndSubmit(\"\(mode)\", \"target_date\", \"\"); 'ok';"
    }

    /// 申請：各日の値を form1 に入れて regist で送信
    static func apply(_ days: [RequestDay], flags: [String]) -> String {
        let rows: [[String: String]] = zip(days, flags).map { day, flag in
            let f = day.fields
            return [
                "i": String(day.index),
                "shift_type": f.shiftType,
                "from_hour": f.fromHour, "from_minutes": f.fromMinute,
                "to_hour": f.toHour, "to_minutes": f.toMinute,
                "flexible_type": f.flexibleType,
                "holiday_type": f.holidayType,
                "holiday_reason": f.holidayReason,
                "update_flg": flag,
            ]
        }
        let json = (try? JSONSerialization.data(withJSONObject: rows)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
        (function(rows){
          var f = document.getElementById('form1');
          if (!f || typeof eccube === 'undefined') { return 'noform'; }
          rows.forEach(function(r){
            Object.keys(r).forEach(function(k){
              if (k === 'i') { return; }
              var e = f.querySelector('input[name="' + k + r.i + '"]');
              if (e) { e.value = r[k]; }
            });
          });
          eccube.setModeAndSubmit("regist", "", "");
          return 'ok';
        })(\(json));
        """
    }

    /// ログイン画面の入力を拾ってアプリに渡す（自動ログイン用）
    static let captureLogin = #"""
    (function(){
      if (window.__shiftnoteCapture) { return; }
      window.__shiftnoteCapture = true;
      function snap(){
        var pw = document.querySelector('input[type=password]');
        if (!pw || !pw.value) { return; }
        var o = {};
        document.querySelectorAll('input, select').forEach(function(e){
          var t = (e.type || '').toLowerCase();
          if (!e.name || t === 'hidden' || t === 'submit' || t === 'button' || t === 'file') { return; }
          if (t === 'checkbox' || t === 'radio') { if (e.checked) { o[e.name] = e.value; } return; }
          o[e.name] = e.value;
        });
        try { window.webkit.messageHandlers.shifconLogin.postMessage(JSON.stringify(o)); } catch (err) {}
      }
      ['input', 'change', 'submit', 'click', 'touchend'].forEach(function(ev){ document.addEventListener(ev, snap, true); });
    })();
    """#

    /// 保存したログイン情報を入れてログインボタンを押す
    static func autoLogin(_ values: [String: String]) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: values)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return #"""
        (function(c){
          var pw = null;
          Object.keys(c).forEach(function(k){
            var els = document.getElementsByName(k);
            if (!els.length) { return; }
            var e = els[0], t = (e.type || '').toLowerCase();
            if (t === 'checkbox' || t === 'radio') {
              for (var i = 0; i < els.length; i++) { if (els[i].value === c[k]) { els[i].checked = true; } }
            } else {
              e.value = c[k];
            }
            e.dispatchEvent(new Event('input', { bubbles: true }));
            e.dispatchEvent(new Event('change', { bubbles: true }));
            if (t === 'password') { pw = e; }
          });
          if (!pw) { return 'nofield'; }
          var f = pw.form;
          var btn = f ? f.querySelector('button[type=submit], input[type=submit], input[type=image]') : null;
          if (!btn) {
            var cands = document.querySelectorAll('button, a, input[type=button], .ui-btn');
            for (var i = 0; i < cands.length; i++) {
              var s = (cands[i].innerText || cands[i].value || '').replace(/\s/g, '');
              if ((s.indexOf('ログイン') >= 0 || s.toLowerCase().indexOf('login') >= 0) && s.indexOf('ログアウト') < 0) { btn = cands[i]; break; }
            }
          }
          if (btn) { btn.click(); return 'clicked'; }
          if (f) { f.submit(); return 'submitted'; }
          return 'nosubmit';
        })(\#(json));
        """#
    }
}

/// scrape の結果
struct ScrapedPage: Decodable {
    struct Day: Decodable {
        let i: Int
        let date, edit, cls: String?
        let disabled: Bool?
        let st, fh, fm, th, tm, fx, ht, hr, hol: String?
        let dst, dfh, dfm, dth, dtm, dfx, dht, dhr, dup: String?
        let yt, tf: String?
        let cfh, cfm, cth, ctm: String?
        let mfh, mfm, mth, mtm: String?
    }

    let ok: Bool
    let hasPassword: Bool?
    let url: String?
    let title: String?
    let text: String?
    let from, to: String?
    let staff, store: String?
    let infos: [[String]]?
    let days: [Day]?
    let back, next, copy, footer: Bool?
    let status, applyTitle, canApply: String?
    let messages: [String]?

    static func dayKey(_ s: String?) -> DayKey? {
        guard let s, s.count == 8, let n = Int(s) else { return nil }
        return DayKey(year: n / 10000, month: n / 100 % 100, day: n % 100)
    }

    /// 申請期間として読めたら RequestPeriod にする
    func period() -> RequestPeriod? {
        guard ok, let days, !days.isEmpty else { return nil }
        var deadline: String?
        var infos: [RequestInfo] = []
        for lines in self.infos ?? [] where !lines.isEmpty {
            if let first = lines.first, first.hasPrefix("締切") {
                deadline = first.components(separatedBy: CharacterSet(charactersIn: "：:")).dropFirst().joined(separator: ":")
                continue
            }
            if lines.count >= 2 {
                infos.append(RequestInfo(label: lines.dropLast().joined(), value: lines.last ?? ""))
            } else if let only = lines.first {
                // 「受付終了」など
                if deadline == nil { deadline = only } else { infos.append(RequestInfo(label: only, value: "")) }
            }
        }

        let parsed: [RequestDay] = days.compactMap { (d: Day) -> RequestDay? in
            guard let date = Self.dayKey(d.date) else { return nil }
            func s(_ x: String?) -> String { x ?? "" }
            var st = s(d.st)
            if st.isEmpty { st = "2" }
            var fx = s(d.fx)
            if fx.isEmpty { fx = "0" }
            let loaded = RequestFields(shiftType: st, fromHour: s(d.fh), fromMinute: s(d.fm), toHour: s(d.th), toMinute: s(d.tm),
                                       flexibleType: fx, holidayType: s(d.ht), holidayReason: s(d.hr))
            let original = RequestFields(shiftType: s(d.dst), fromHour: s(d.dfh), fromMinute: s(d.dfm), toHour: s(d.dth), toMinute: s(d.dtm),
                                         flexibleType: s(d.dfx), holidayType: s(d.dht), holidayReason: s(d.dhr))
            var suggestions: [RequestFields] = []
            for (fh, fm, th, tm) in [(d.cfh, d.cfm, d.cth, d.ctm), (d.mfh, d.mfm, d.mth, d.mtm)] {
                if let a = ShiftClock(hour: s(fh), minute: s(fm)), let b = ShiftClock(hour: s(th), minute: s(tm)), b > a {
                    let f = RequestFields.work(a, b)
                    if !suggestions.contains(f) { suggestions.append(f) }
                }
            }
            return RequestDay(index: d.i, date: date, isPublicHoliday: d.hol == "1",
                              editable: d.edit == "1" && d.disabled != true,
                              fields: loaded, loaded: loaded, original: original,
                              originalUpdateFlag: s(d.dup),
                              initialYesterdayTo: s(d.yt), initialTomorrowFrom: s(d.tf),
                              suggestions: suggestions)
        }
        guard let first = parsed.first, let last = parsed.last else { return nil }
        return RequestPeriod(from: Self.dayKey(from) ?? first.date, to: Self.dayKey(to) ?? last.date,
                             staffName: staff ?? "", storeName: store ?? "",
                             deadline: deadline, infos: infos, days: parsed,
                             canGoBack: back ?? false, canGoNext: next ?? false, canCopy: copy ?? false,
                             isOpen: footer ?? false, statusText: status, applyTitle: applyTitle,
                             serverCanApply: canApply == "1", messages: messages ?? [])
    }
}
