# Native synchronization contract

This branch adds a native EventKit writer and a separate verified COMPANY payslip store.

- ConfirmedShiftCalendarWriter reconciles a complete, verified five-day roster.
- Only Shift Note-owned events are changed; incomplete downloads cannot delete shifts.
- CompanyPayrollStore stores exact payslip records in the device Keychain.
- The income view distinguishes confirmed payroll from estimated earnings.

## Unverified inputs

The existing Shifcon HTML parser reads shift requests, not a verified confirmed roster.
The separate neoshift repository explicitly disables its roster reader and returns
an empty result. Do not import requested shifts as confirmed shifts.

The checked repositories contain no verified COMPANY payslip endpoint or field
mapping. Until a legitimate authenticated source is established, there is no
automatic payroll retrieval. Never label the existing estimates as confirmed.

When source adapters exist, invoke them on foreground launch/activation; iOS does
not guarantee timed background WebKit execution. Protect all credentials locally
and never commit payroll records or session cookies to GitHub.
