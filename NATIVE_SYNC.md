# Native synchronization

## Shifcon calendar sync

When the current Shifcon request screen finishes loading or refreshing, Shift Note reads its loaded form values and reconciles shifts for today through the next four dates in Japan time (five dates total).

- Each of the five dates must be present exactly once, and every work entry must have valid start/end times. An incomplete or invalid read does not change existing calendar events.
- Work events are written to the app-owned **Shift Note** calendar. Only events marked as Shift Note-managed are updated or removed; unrelated calendar events are left alone.
- The read occurs as part of the existing Shifcon request-screen flow. It does not claim to retrieve an employer-confirmed roster or promise a timed background refresh.

## COMPANY payroll

The verified-payslip Keychain store and income-card separation are in place, so shift-based estimates remain separate from confirmed payroll. Automatic COMPANY retrieval is not connected yet: the portal's month detail page offers a password-protected PDF save flow, and the PDF fields and a reliable local extraction mapping have not been verified. Failed or incomplete retrieval must never be saved or displayed as confirmed pay.

## Privacy and refresh limits

Credentials, session cookies, PDF passwords, and payroll records must remain on the device and must not be committed to GitHub. iOS does not guarantee timed background WKWebView execution; the current automatic refresh point is a successful foreground load/refresh of the Shifcon request screen.
