# GhostWork mobile (Flutter) — plan

Status: **not started**. The web app and API are functional and tested; this document
records the agreed scope and the API contract the app will use. The Flutter SDK is not
installed on the current development machine.

## Scope (initial release)

Optimized for monitoring and quick actions, not authoring:

| Screen | API |
| --- | --- |
| Sign in / register | `POST /api/v1/auth/login`, `POST /api/v1/auth/register` with `"client": "mobile"` |
| Dashboard summary | `GET /api/v1/dashboard/summary` |
| Workflows | `GET /api/v1/workflows?q=&status=&sort=&page=` |
| Workflow status | `GET /api/v1/workflows/{id}`, `POST /api/v1/workflows/{id}/status` |
| Run now | `POST /api/v1/workflows/{id}/run` |
| Executions | `GET /api/v1/executions?status=&workflow_id=&page=` |
| Execution detail | `GET /api/v1/executions/{id}` (poll every 1–2 s while `queued`/`running`) |
| Cancel / re-run | `POST /api/v1/executions/{id}/cancel`, `/rerun` |
| Notifications | `GET /api/v1/notifications`, `POST /api/v1/notifications/{id}/read` |
| Profile & settings | `GET /api/v1/auth/me`, `PATCH /api/v1/users/me`, `GET/DELETE /api/v1/auth/sessions` |

The visual builder stays web-only.

## Authentication on mobile

- Send `"client": "mobile"` on login/register: the response includes `refresh_token`
  in the body and **no cookie** is set.
- Store the refresh token with `flutter_secure_storage` (Keychain / Android Keystore).
  Keep the access token in memory only.
- Refresh with `POST /api/v1/auth/refresh` and body `{"refresh_token": "..."}`. Every
  refresh returns a **new** refresh token; persist it immediately. Reusing an old token
  after the 20 s grace window revokes the session.
- HTTP 409 from refresh means a concurrent refresh happened; retry once.
- Sign out with `POST /api/v1/auth/logout` and body `{"refresh_token": "..."}`.
- No CSRF header is needed for body-token requests.

## Suggested architecture

- `go_router` for navigation, `riverpod` for state, `dio` with an auth interceptor
  (attach bearer, single-flight refresh on 401), `freezed`/`json_serializable` models
  mirroring `frontend/src/lib/types.ts`.
- Reuse the design tokens from `frontend/src/app/globals.css` (colors, status colors)
  and the logo from `frontend/public/ghostwork-mark.svg`.
- Tests: model parsing, the auth interceptor (rotation, 409 retry, logout on 401),
  and widget tests for execution status rendering.

## Push notifications

Not planned for the first release. They need an FCM/APNs setup and a device-token
endpoint on the API, neither of which exists yet. The app will poll
`/notifications` while in the foreground.
