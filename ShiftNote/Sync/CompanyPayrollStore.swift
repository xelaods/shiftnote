import Foundation

/// Exact amount from a verified, authenticated COMPANY payslip.
struct CompanyPayrollRecord: Codable, Equatable, Identifiable {
    let sourceID: String
    let paymentYear: Int
    let paymentMonth: Int
    let grossYen: Int
    let netYen: Int?
    let transportYen: Int?
    let confirmedAt: Date

    var id: String { sourceID }
    var isValid: Bool {
        !sourceID.isEmpty && (2020...2100).contains(paymentYear) &&
        (1...12).contains(paymentMonth) && (0...100_000_000).contains(grossYen) &&
        netYen.map { (0...100_000_000).contains($0) } != false &&
        transportYen.map { (0...100_000_000).contains($0) } != false
    }
}

/// Persist verified payslips locally, separately from estimated wages.
enum CompanyPayrollStore {
    private static let key = "company-payroll-confirmed-v1"

    static func load() -> [CompanyPayrollRecord] {
        guard let data = Keychain.data(key),
              let records = try? JSONDecoder().decode([CompanyPayrollRecord].self, from: data) else {
            return []
        }
        return records.filter(\.isValid).sorted {
            ($0.paymentYear, $0.paymentMonth) < ($1.paymentYear, $1.paymentMonth)
        }
    }

    /// To be called by an authenticated source adapter only after verification.
    /// Failed/partial fetches must never replace confirmed values.
    @discardableResult
    static func mergeVerified(_ incoming: [CompanyPayrollRecord]) -> Bool {
        guard !incoming.isEmpty && incoming.allSatisfy(\.isValid) else { return false }
        var records = Dictionary(uniqueKeysWithValues: load().map { ($0.id, $0) })
        for record in incoming { records[record.id] = record }
        guard let data = try? JSONEncoder().encode(Array(records.values)) else { return false }
        Keychain.set(data, for: key)
        return true
    }
}
