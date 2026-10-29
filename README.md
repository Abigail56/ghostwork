# GhostWork

**Your workflows. On autopilot.**

GhostWork is a workflow automation platform built around the **Living Workflow**: the
same canvas you design an automation on shows what it is doing while it runs and
what each step did afterwards.

- **Frontend:** Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS 4, DaisyUI,
  TanStack Query, React Hook Form + Zod, React Flow (`@xyflow/react`), Recharts.
- **Backend:** FastAPI, SQLModel/SQLAlchemy, PostgreSQL, Alembic, Celery + Redis,
  Argon2 (pwdlib), JWT, pytest.
- **Infrastructure:** Docker Compose (PostgreSQL, Redis, Mailpit; optional app containers).

---

## What works today

| Area | Status |
| --- | --- |
| Accounts | Register, sign in/out, Argon2 hashing, password change, password reset by email |
| Sessions | 15-min access tokens + rotating refresh sessions (HttpOnly cookie), reuse detection, per-device revocation, CSRF guard |
| Workflows | Create, list (search/filter/sort/paginate), edit, duplicate, activate/pause, delete, ownership enforced server-side |
| Builder | Drag/click to add steps, connect, configure, rename, delete, undo/redo, save (Ctrl S), validation with per-step issues, activation confirm, unsaved-change protection, live test runs |
| Triggers | Manual, schedule (≥ 5 min), webhook (secret URL, regenerable) |
| Steps | HTTP request (SSRF-guarded, retries, timeouts), transform, condition (true/false branches), email via SMTP, Slack incoming webhook |
| Execution | Celery worker, per-step records (status, attempts, output, error, timing), cancellation, re-run, time limits, stale-run reaper, per-user concurrency limit |
| Monitoring | Dashboard metrics from real data, 14-day trend, health summary, execution history with filters, notifications |
| Integrations | SMTP, Slack, HTTP credentials — secrets encrypted with Fernet, never returned |
| Templates | 5 templates, all valid against the implemented step types |
| Settings | Profile, password, sessions, notification and appearance preferences, activity log |

**Not implemented (shown as "Planned" in the UI):** Google Workspace and GitHub
integrations, team workspaces, billing, the Flutter mobile app.

GhostWork has **not** been hardened or load-tested for production use; see
[Production checklist](#production-checklist).

---

## Local development

Prerequisites: Docker, Node.js 22+, Python 3.12+ (the existing venv uses 3.14).

### 1. Infrastructure

```bash
cp .env.example .env                # first time only; set POSTGRES_PASSWORD
docker compose up -d                # PostgreSQL :5434, Redis :6380, Mailpit :1026 / UI :8026
```

### 2. Backend

```bash
cd backend
cp .env.example .env                # first time only; fill JWT_SECRET_KEY, INTEGRATION_ENCRYPTION_KEY,
                                    # and make DATABASE_URL's password match the root .env
python -m venv .venv                # only if .venv doesn't exist
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m alembic upgrade head

# three terminals:
.venv/bin/python -m uvicorn app.main:app --reload --port 8000
.venv/bin/python -m celery -A app.workers.celery_app worker --loglevel=info
.venv/bin/python -m celery -A app.workers.celery_app beat --loglevel=info
```

> **Note:** always run tools as `.venv/bin/python -m <tool>`. The existing venv was
> created when the folder was named `GhostWork`, so its console scripts
> (`.venv/bin/alembic`, `.venv/bin/uvicorn`, …) point at a path that no longer exists.
> `python -m` is unaffected. Recreating the venv also fixes it.

API docs: <http://localhost:8000/docs>

### 3. Frontend

```bash
cd frontend
cp .env.example .env.local          # NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
npm install
npm run dev                         # http://localhost:3000
```

### Everything in containers (optional)

```bash
docker compose --profile full up --build
```

Runs the API (applies migrations on start), worker, beat and the production web build.
Stop any locally running API/web servers first (ports 8000 and 3000).

---

## Testing

```bash
# Backend: 53 tests against a real PostgreSQL test database (ghostwork_test)
docker exec ghostwork-db psql -U ghostwork -d ghostwork -c "CREATE DATABASE ghostwork_test OWNER ghostwork;"  # once
cd backend && .venv/bin/python -m pytest -q

# Frontend: type check, lint, production build
cd frontend && npm run typecheck && npm run lint && npm run build

# End-to-end (Playwright) — needs the API and a Celery worker running
cd frontend && npx playwright install chromium   # once
npm run test:e2e
```

The e2e suite registers fresh accounts, so the development `backend/.env` raises
`REGISTER_RATE_LIMIT_PER_HOUR`. Production keeps the defaults (5/hour, 10 logins/5 min).

---

## Architecture

```
frontend/                         Next.js App Router
  src/app/(marketing)/            Public site: /, /features, /pricing, /docs, /about, /privacy, /terms
  src/app/(auth)/                 /login, /register, /forgot-password, /reset-password
  src/app/(app)/                  Authenticated app (client-gated): dashboard, workflows, builder,
                                  executions, integrations, templates, settings, help
  src/components/ui/              Design-system primitives (Button, Field, Dialog, Drawer, Menu, Tabs, Toast…)
  src/components/workflow/        Living Workflow canvas: node, edge, read-only canvas, auto-fit
  src/components/builder/         Builder: library, config panel, editor
  src/lib/                        Typed API client, auth provider, TanStack Query hooks, types
  e2e/                            Playwright tests

backend/
  app/api/routes/                 HTTP layer only (auth, users, workflows, executions, hooks,
                                  dashboard, integrations, catalog, notifications)
  app/services/                   Business logic: auth, workflow definition & validation,
                                  execution engine, integrations, SSRF guard, templating, mailer
  app/workers/                    Celery app, run/schedule/reaper tasks
  app/models/                     SQLModel tables
  migrations/                     Alembic
  tests/                          pytest
```

FastAPI is the single source of business rules. The Next.js app holds no business
logic beyond client-side form validation that mirrors the API.

### Auth model

- `POST /auth/login` returns a 15-minute JWT access token (kept in memory) and sets an
  HttpOnly `gw_refresh` cookie scoped to `/api/v1/auth`.
- `POST /auth/refresh` rotates the refresh token. Presenting an already-rotated token
  after a 20-second grace window revokes that session (theft detection).
- Access tokens carry the session ID; every request checks the session is still active,
  so revocation is immediate.
- Cookie-authenticated endpoints require the `X-GhostWork-CSRF` header and an allowed
  `Origin`. Mobile clients send `client: "mobile"` and receive the refresh token in the
  body instead of a cookie.

### Workflow definitions

```json
{
  "nodes": [{ "id": "fetch", "type": "action.http_request", "name": "Fetch", "position": {"x": 0, "y": 0}, "config": {} }],
  "edges": [{ "id": "e1", "source": "trigger", "target": "fetch", "source_handle": "out" }]
}
```

Saved definitions must be structurally valid. Activation and runs require full
validation (one trigger, reachable DAG, required config, references that resolve,
integrations owned by the user). Runs execute a snapshot, so editing a workflow never
changes past history.

---

## Security notes

- Passwords: Argon2id; constant-time path for unknown accounts.
- Integration secrets: Fernet-encrypted (`INTEGRATION_ENCRYPTION_KEY`); never returned
  by the API, never written to step outputs or logs.
- Outbound HTTP: http/https only, no credentials in URLs, DNS resolved and checked
  against private/loopback/link-local/reserved ranges, connection pinned to the checked
  IP (with SNI), redirects re-checked, 1 MB / 30 s caps.
- No user code execution: steps are a fixed catalog; templating is dotted lookups only.
- Webhooks: 256 KB limit, 60 requests/minute per URL, auth/cookie headers dropped.
- Errors: unhandled exceptions return a generic 500; details stay in server logs.
- Rate limits (Redis): register, login, refresh, password reset.

### Production checklist

Before exposing GhostWork publicly:

- [ ] `ENVIRONMENT=production` (forces Secure cookies; refuses private-network requests)
- [ ] Strong `JWT_SECRET_KEY` and `INTEGRATION_ENCRYPTION_KEY` from a secret manager; plan key rotation
- [ ] HTTPS everywhere; set `CORS_ORIGINS`, `FRONTEND_URL`, `API_PUBLIC_URL`
- [ ] Real SMTP provider for platform email
- [ ] Managed PostgreSQL backups and Redis persistence
- [ ] Monitoring/alerting for the worker and beat processes
- [ ] Load and security testing

---

## Mobile (Flutter) — phase two

The API was designed so a Flutter app can use it unchanged; see
[`docs/mobile-flutter.md`](docs/mobile-flutter.md) for the plan and API contract.
The Flutter app itself has not been built yet.
