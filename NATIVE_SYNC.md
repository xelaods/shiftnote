# Native synchronization contract

This branch adds a native EventKit writer and a separate verified COMPANY payslip store.

- ConfirmedShiftCalendarWriter reconciles a complete, verified five-day roster.
- Only Shift Note-owned events are changed; incomplete downloads cannot delete shifts.
- CompanyPayrollStore stores exact payslip records in the device Keychain.
- The income view distinguishes verified COMPANY payslips from estimated shift earnings.

## Source verification

The current Shifcon integration reads the staffpage shift request form. Its fields include request/edit flags and submitted or editable values; the inspected app code does not establish that these values are the employer's confirmed roster. Do not treat them as confirmed shifts.

The COMPANY portal flow was inspected in the authenticated browser:

1. Open **照会 → 給与情報照会 → 給与明細**.
2. The newest available month is linked directly; older items are behind **一覧表示**.
3. A month detail page offers **PDF表示／保存**. It does not expose payroll amounts as readable page text.
4. Continuing to **PDF保存** requires entering and confirming a PDF open password before the file can be saved.

The PDF's field layout and a reliable way to extract its payroll values have not been verified. The portal flow therefore does not yet provide an automatic, validated payroll source. Never show shift-based estimates as confirmed payroll.

## Refresh limits

iOS does not guarantee timed background WKWebView execution. Any authenticated source adapter must refresh on foreground activation, preserve credentials only on device, validate the complete source response before replacing records, and keep verified payroll separate from estimates. Do not commit payroll records, PDF files, passwords, or session cookies to GitHub.
