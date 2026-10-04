# Partner application review overdue

`PartnerApplicationReviewOverdue` reads the actual oldest `IN_REVIEW` submission
timestamp in each Restaurant/Delivery database. It fires after the age exceeds 24 hours
for 15 minutes. The metric refreshes every 30 seconds and carries only the application
type; it contains no applicant or document information.

Sign in to the admin portal with its separate admin session and open **Partner approvals**.
Select the application type from the alert and filter **In review**. Review the oldest
application's details, provider results and private documents. Document downloads are
short-lived and each admin view is audited. Approve only if all required checks pass;
otherwise reject with a clear reason explaining what the applicant should correct.
Use the displayed version so a concurrent review produces409 and refreshes current state.

If details or checks are unavailable, restore the affected service/provider and retry.
Inspect service health and the typed application-event dead-letter position using IDs
only. Do not approve through SQL, change a stored provider result, manufacture a passed
check, log a presigned URL/document number, or bypass the admin decision. Replaying a
submitted event preserves its revision and retries the durable callback intent.

After a decision commits, verify it leaves the queue and the oldest-age metric falls
after its next refresh. Check published transition/notification outbox state. Suspension
blocks new restaurant orders or rider duty while preserving a rider's current delivery.
