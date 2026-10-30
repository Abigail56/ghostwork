# Legal review brief

For the lawyer reviewing GhostWork's Terms of Service and Privacy page before public launch.
**Nothing here is legal advice, and neither document has been reviewed by a lawyer yet.** They
were drafted by the developer with an AI assistant, based on what the software actually does.

## Documents

- Terms of Service: `frontend/src/lib/terms.json` (version 2026-10-30), shown at `/terms` and during sign-up.
- Privacy page: `frontend/src/app/(marketing)/privacy/page.tsx`, and its copy in the mobile app.

## Facts to fill in first (the owner must supply these)

The drafts can't be finished without them:

1. Legal name and address of the operator, and a real contact address. Section 16 currently says
   only "the administrator of your GhostWork service".
2. Country of establishment, which decides the governing law and courts. Section 16 currently says
   "the place where the operator ... is established", with no named jurisdiction.
3. Countries where GhostWork will be offered, especially the EU/UK, US states and Nigeria.
4. Whether users will be consumers, businesses or both.
5. Hosting location and subprocessors (host, email provider), which aren't chosen yet.
6. How long backups are kept. The product deletes run data after 90 days; backups aren't set up yet.

## Questions for review

**Terms**
1. Is the sign-up acceptance (unticked checkbox, with the version and time recorded) enough to form a binding agreement?
2. Are the "as is" disclaimer (section 12) and the liability cap of the greater of 12 months' fees or USD 50 (section 13) enforceable in the target markets, including against consumers?
3. Section 14 asks users to take responsibility for claims caused by their use. Is that appropriate for consumers?
4. Does the minimum age of 16, or the local age of digital consent, satisfy the target markets?
5. Section 15 covers changes to the Terms. Is the notice adequate, and should users have to accept again? The app can record acceptance per version.
6. Do section 11 (suspension and deletion) and section 9 (early access, possible future fees) need more detail?
7. Is section 16's unnamed governing law workable, and is a dispute-resolution clause wanted?

**Privacy**
8. Which lawful bases apply, and does the page meet GDPR/UK GDPR and NDPA (Nigeria) disclosure requirements?
9. Is a data processing agreement needed? Users can route other people's personal data through workflows, which may make the operator a processor.
10. Are cross-border transfer disclosures needed for the integrations and push services below?

## What the software does with data

- **Account:** name, email, Argon2 password hash, session records (IP and device), preferences, Terms version accepted.
- **Workflows and runs:** user-defined content and step results, deleted after 90 days. Account deletion removes all of it.
- **Credentials for connected services:** encrypted at rest and never shown back. These are SMTP passwords, Slack webhooks, API tokens, GitHub personal access tokens and Google service account keys.
- **Data sent to third parties, only on the user's instruction:** any HTTP destination they configure, their SMTP server, Slack, GitHub, Google Sheets.
- **Push (off until turned on per device):** a device address is stored. Notification titles and text pass through the browser or phone maker's push service (Google, Mozilla, Apple, Microsoft), and through Firebase on mobile. A title can include the workflow's name and the failure's error text.
- **Cookies:** one essential HttpOnly session cookie. No analytics or advertising.
- **Not present:** payments, team workspaces, OAuth sign-in. Section 9 still says features marked "Planned" aren't available.

## After review

Change `frontend/src/lib/terms.json`, run `scripts/sync-shared.sh`, update `version` and
`TERMS_VERSION` in `backend/app/core/config.py`, and update the Privacy page in both apps.
