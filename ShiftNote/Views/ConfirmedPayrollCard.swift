import SwiftUI

/// Exact COMPANY payslips are displayed independently of calculated shift estimates.
struct ConfirmedPayrollCard: View {
    @EnvironmentObject var model: AppModel
    let year: Int

    private var records: [CompanyPayrollRecord] {
        model.confirmedPayroll.filter { $0.paymentYear == year }
            .sorted { $0.paymentMonth < $1.paymentMonth }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("COMPANY 確定給与")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(records.isEmpty ? "未連携" : "確定明細")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            if records.isEmpty {
                Text("COMPANYの給与明細はまだ取得できていません。以下の年収・給与はシフトから計算した見込み額です。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let gross = records.reduce(0) { $0 + $1.grossYen }
                Text(Fmt.yen(Double(gross)))
                    .font(Theme.number(36, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("取得済みの明細の支給総額（\(records.count)件）")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                ForEach(records) { record in
                    HStack {
                        Text("\(record.paymentMonth)月支給")
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text(Fmt.yen(Double(record.grossYen)))
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                    }
                    .font(.system(size: 13))
                }
                Text("確定給与は取得済みの明細のみ。下のグラフは引き続き見込み額です。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .card(padding: 20)
    }
}
