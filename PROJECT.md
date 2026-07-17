# PROJECT.md — Household Finance: Single Source of Truth

> **This is the living source of truth for the entire `household-finance` monorepo.**
> All agents, contributors, and apps must treat this document as authoritative.
> Update it when significant decisions are made. Never let it drift from reality.

---

## 1. System Overview

Household Finance is a personal-finance tracking system for families. The primary ingestion channel is **Telegram** (chat-based expense logging). A web dashboard provides reporting and management. A mobile app is on the roadmap.

```
┌─────────────────────────────────────────────────────────────────┐
│                       household-finance                         │
│                                                                 │
│  Telegram Bot ──► household-finance-api (FastAPI BFF)           │
│                            │                                    │
│  household-finance-web ────┤──► Supabase (DB + Auth + Storage)  │
│  (Next.js Dashboard)       │                                    │
│                            │                                    │
│  [Future] Mobile App ──────┘                                    │
└─────────────────────────────────────────────────────────────────┘
```

**Key architectural principle:** Telegram is an **ingestion channel**, not the application core. The FastAPI app is the BFF for all clients — web, mobile, and Telegram alike.

---

## 2. Repository Structure

```
household-finance/              ← You are here (monorepo root)
├── PROJECT.md                  ← This file — single source of truth
├── AGENTS.md                   ← Cross-cutting directives for all AI agents
├── household-finance-api/      ← FastAPI BFF (Python)
│   ├── AGENTS.md               ← App-specific agent directives
│   └── docs/                   ← ADRs, deployment guide, implementation plan
└── household-finance-web/      ← Next.js dashboard (TypeScript)
    └── AGENTS.md               ← App-specific agent directives
```

> A **mobile app** (React Native or Flutter) is planned and will live at `household-finance-mobile/` when created. Reserve that namespace.

---

## 3. Tech Stack

### `household-finance-api` (Backend / BFF)

| Concern | Technology | Notes |
|---|---|---|
| Web framework | FastAPI + Uvicorn | ASGI, async-first |
| Telegram integration | `httpx.AsyncClient` (raw) | No `python-telegram-bot` — see ADR-002 |
| LLM / OCR | Google Gemini 1.5 Flash | Text + vision receipt parsing |
| Database | Supabase (Postgres + RLS) | Service-role key on the backend |
| OFX parsing | `ofxparse` | Bulk bank statement import |
| Config | `pydantic-settings` | All env vars via `Settings` class |
| Testing | `pytest` + `pytest-mock` | No real external API calls in tests |
| Linting | `ruff` | Enforced in CI |
| Dependency management | `pip-compile` | Edit `requirements.in`, never `requirements.txt` |
| CI | GitHub Actions | Lint → test → deploy (`main` only) |
| Container | Docker / Docker Compose | Prod + local override files |

### `household-finance-web` (Frontend Dashboard)

| Concern | Technology | Notes |
|---|---|---|
| Framework | Next.js (App Router) | Default to Server Components |
| Language | TypeScript (strict) | No `any` types |
| Styling | Tailwind CSS + shadcn/ui | No custom global CSS unless needed |
| Component library | shadcn/ui (Radix UI) | Pull via `npx shadcn@latest add` |
| State (server) | Next.js data fetching / React Query | Fetch from FastAPI BFF only |
| State (client) | `useState` / `useReducer` / Zustand | Zustand for global complexity |
| i18n | `next-intl` | Default locale: `pt-BR` |
| Linting | ESLint | Fix all errors before committing |

### `household-finance-mobile` (Planned)

> Not yet scaffolded. Technology (React Native / Flutter) to be decided in an ADR when started.
> Will consume the same FastAPI BFF REST API. The BFF must remain mobile-friendly.

---

## 4. Data Model

> Canonical schema source: `household-finance-api/sql/001_init.sql`
> This section is the human-readable reference.

### `households`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | `gen_random_uuid()` |
| `name` | TEXT | e.g. "Murphy Family" |
| `invite_code` | TEXT UNIQUE | 8-char random string |
| `settings` | JSONB | `{"currency": "BRL"}` |
| `created_at` | TIMESTAMPTZ | |

### `users`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `telegram_id` | BIGINT UNIQUE | |
| `username` | TEXT | nullable |
| `household_id` | UUID FK → households | nullable until onboarded |
| `role` | TEXT | `admin` or `member` |
| `pending_state` | TEXT | nullable — multi-step flow FSM |
| `pending_payload` | JSONB | transient state data |
| `settings` | JSONB | reserved for future use |
| `created_at` / `updated_at` | TIMESTAMPTZ | |

### `transactions`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | UUID FK | |
| `household_id` | UUID FK | |
| `amount` | DECIMAL(10,2) | |
| `merchant` | TEXT | nullable; separate column — see ADR-005 |
| `description` | TEXT | |
| `category` | TEXT | see `Category` enum |
| `raw_source` | TEXT | `text`, `image`, `ofx` |
| `raw_input` | TEXT | original message/filename |
| `date` | TIMESTAMPTZ | |
| `created_at` | TIMESTAMPTZ | |

**Key constraint (ADR-008):** A user belongs to **exactly one household** (`users.household_id` is a single FK). No `household_members` join table in MVP. If multi-household is required, migrate then.

---

## 5. API Surface

### Telegram Webhook (ingestion)
```
POST /webhook/telegram          ← Receives all Telegram Updates
```

### REST Endpoints (BFF for web/mobile)
```
# Transactions
GET    /api/transactions?telegram_id=&month=YYYY-MM
POST   /api/transactions?telegram_id=
GET    /api/transactions/{id}?telegram_id=
PUT    /api/transactions/{id}?telegram_id=
DELETE /api/transactions/{id}?telegram_id=

# Summary / Aggregation
GET /api/summary?telegram_id=&month=YYYY-MM
GET /api/summary/categories?telegram_id=&month=YYYY-MM
GET /api/summary/merchants?telegram_id=&limit=10

# Households
GET /api/households/me?telegram_id=
```

> **WARNING — REST auth is MVP-only (ADR-009).** Endpoints currently accept `telegram_id` as a query parameter for identity. This is **not cryptographically secure**. It is acceptable only while the API is behind a non-public domain and has no external clients.
>
> **Do not add any business logic that depends on this auth remaining as-is.** When a real client app ships, swap to Supabase Auth JWT tokens — only the identity-resolution helper changes, not the business logic.

#### Auth Migration Template (for future implementation)
```python
# CURRENT (MVP):
async def get_current_user(telegram_id: int = Query(...)) -> User:
    return await db.get_user_by_telegram_id(telegram_id)

# FUTURE (JWT):
async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    payload = verify_supabase_jwt(token)
    return await db.get_user_by_id(payload["sub"])
```

---

## 6. Conversation State (FSM)

Multi-step Telegram flows use a `pending_state` + `pending_payload` pattern on the `users` table. **Never use in-memory state.**

```
/start → pending_state = 'onboarding_name'
       → pending_state = 'onboarding_currency' (name in pending_payload)
       → household created, pending_state cleared

[expense text/image] → pending_state = 'confirm_transaction' (ParsedTransaction in pending_payload)
                     → [✅ Save] → transaction saved, state cleared
                     → [❌ Cancel] → state cleared
```

---

## 7. Implementation Roadmap

| Phase | Goal | Status |
|---|---|---|
| Phase 0 | Scaffold, git, CI, docs | ✅ Complete |
| Phase 1 | FastAPI + Webhook + `/start` onboarding + Supabase schema + RLS | 🔄 In Progress |
| Phase 2 | Gemini text/image parsing + confirmation flow | ⬜ Planned |
| Phase 3 | Full CRUD + OFX import + category correction | ⬜ Planned |
| Phase 4 | `/summary`, `/categories` + BFF aggregation endpoints | ⬜ Planned |
| Phase 5 | Web dashboard (`household-finance-web`) | ⬜ Planned |
| Phase 6 | REST auth migration (Supabase JWT) | ⬜ Planned |
| Phase 7 | Mobile app (`household-finance-mobile`) | ⬜ Planned |

> Update the status column here whenever a phase is started or completed.

---

## 8. Known Constraints & Accepted Limitations

These are hard-decided constraints. Do not work around them without creating a new ADR.

| Constraint | Decided In | What it means |
|---|---|---|
| FastAPI + webhooks (not polling) | ADR-001 | No `python-telegram-bot` polling loop |
| Raw `httpx` for Telegram calls | ADR-002 | No `python-telegram-bot` wrapper library |
| Gemini 1.5 Flash for OCR | ADR-003 | Not GPT-4o Vision — cost decision |
| Supabase RLS from Phase 1 | ADR-004 | RLS is required, not optional |
| `merchant` is its own column | ADR-005 | Not embedded in `description` |
| GitHub + GitHub Actions for CI | ADR-006 | |
| Currency is per-household | ADR-007 | No global default currency |
| One user ↔ one household (MVP) | ADR-008 | No `household_members` join table yet |
| REST auth deferred (MVP: `telegram_id` param) | ADR-009 | **Not secure** — internal use only |

Full ADR log: [`household-finance-api/docs/decisions.md`](./household-finance-api/docs/decisions.md)

---

## 9. Environment Variables

> Never commit secrets. Use GitHub Actions Secrets for CI and provider dashboards for prod.

| Variable | Used By | Source |
|---|---|---|
| `TELEGRAM_TOKEN` | API | BotFather |
| `TELEGRAM_WEBHOOK_SECRET` | API | Self-generated random string |
| `SUPABASE_URL` | API | Supabase project dashboard |
| `SUPABASE_KEY` | API | Supabase `service_role` key (**not** `anon`) |
| `GEMINI_API_KEY` | API | Google AI Studio |

---

## 10. Deployment

See [`household-finance-api/docs/deployment.md`](./household-finance-api/docs/deployment.md) for the full local-testing and production deployment guide.

**Recommended free-tier hosts:** Render, Fly.io, Koyeb
**Database:** Supabase (managed Postgres)

---

## 11. Adding a New App

When adding a new app to this monorepo:
1. Create the app directory: `household-finance-<name>/`
2. Add an `AGENTS.md` with app-specific directives
3. Update this file: sections 2 (structure), 3 (tech stack), and 7 (roadmap)
4. Update the root `AGENTS.md` to reference the new app's directives
5. Create an ADR in `household-finance-api/docs/decisions.md` for any architecture decisions made
