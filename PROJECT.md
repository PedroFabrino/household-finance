# PROJECT.md — Household Finance: Single Source of Truth

> **This is the living source of truth for the entire `household-finance` project.**
> All agents, contributors, and apps must treat this document as authoritative.
> Update it when significant decisions are made. Never let it drift from reality.
>
> _Last audited: 2026-07-17_

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
household-finance/              ← You are here (meta repo — docs + setup scripts only)
├── PROJECT.md                  ← This file — single source of truth
├── AGENTS.md                   ← Cross-cutting directives for all AI agents
├── clone-all.ps1 / .sh         ← Onboarding: clones all sub-repos
└── README.md

household-finance-api/          ← FastAPI BFF (Python) — separate git repo
├── AGENTS.md
├── app/
│   ├── core/config.py
│   ├── routers/       (webhook, transactions, households)
│   ├── services/      (bot_service, db_service, llm_service, telegram_service)
│   ├── schemas/       (telegram, transaction)
│   └── dependencies.py / main.py
├── supabase/migrations/
├── tests/
└── docs/              (decisions.md, deployment.md, implementation-plan.md)

household-finance-web/          ← Next.js dashboard (TypeScript) — separate git repo
├── AGENTS.md
└── src/
    ├── app/
    │   ├── page.tsx                        (landing — currently Next.js scaffold)
    │   └── dashboard/[household_id]/
    │       ├── page.tsx                    (main dashboard)
    │       └── transactions/page.tsx       (full transaction management)
    ├── components/
    │   ├── features/  (transactions-table, overview-chart)
    │   └── ui/        (shadcn/ui components)
    ├── messages/pt-BR.json
    └── lib/utils.ts
```

> A **mobile app** (React Native or Flutter) is planned and will live at `household-finance-mobile/` when created. Reserve that namespace.

---

## 3. Tech Stack

### `household-finance-api` (Backend / BFF)

| Concern | Technology | Notes |
|---|---|---|
| Web framework | FastAPI + Uvicorn | ASGI, async-first |
| Telegram integration | `httpx.AsyncClient` (raw) | No `python-telegram-bot` — see ADR-002 |
| LLM / OCR | Google Gemini 3.1 Flash Lite | Upgraded from 1.5 Flash — see ADR-003 (update needed) |
| Database | Supabase (Postgres + RLS) | Service-role key on the backend |
| OFX parsing | `ofxparse` | Bulk bank statement import, AI-categorized in batches |
| Config | `pydantic-settings` | All env vars via `Settings` class |
| Testing | `pytest` + `pytest-mock` | No real external API calls in tests |
| Linting | `ruff` | Enforced in CI |
| Dependency management | `pip-compile` | Edit `requirements.in`, never `requirements.txt` |
| CI | GitHub Actions | Lint → test → deploy (`main` only) |
| Container | Docker / Docker Compose | Prod + local override files |
| Deployment | Vercel (`vercel.json` present) | API deployed to Vercel |

### `household-finance-web` (Frontend Dashboard)

| Concern | Technology | Notes |
|---|---|---|
| Framework | Next.js (App Router) | Default to Server Components |
| Language | TypeScript (strict) | No `any` types |
| Styling | Tailwind CSS + shadcn/ui | Dark theme, glassmorphism |
| Component library | shadcn/ui (Radix UI) | Pull via `npx shadcn@latest add` |
| State (server) | Next.js data fetching | Fetch from FastAPI BFF only, `cache: "no-store"` |
| State (client) | `useState` / `useReducer` | Client components only where interactivity required |
| i18n | `next-intl` | Default locale: `pt-BR` (messages in `messages/pt-BR.json`) |
| Charts | Recharts (via shadcn chart) | Category spending chart on dashboard |
| Linting | ESLint | Fix all errors before committing |

### `household-finance-mobile` (Planned)

> Not yet scaffolded. Technology (React Native / Flutter) to be decided in an ADR when started.
> Will consume the same FastAPI BFF REST API. The BFF must remain mobile-friendly.

---

## 4. Data Model

> Canonical schema source: `household-finance-api/supabase/migrations/`
> This section is the human-readable reference. **4 migrations have been applied.**

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
| `type` | TEXT | `expense`, `income`, or `transfer` — added in migration 2 |
| `account_type` | TEXT | `checking` or `credit_card` — added in migration 2 |
| `external_id` | TEXT | OFX deduplication key — added in migration 3 |
| `raw_source` | TEXT | `text`, `image`, `ofx` |
| `raw_input` | TEXT | original message/filename |
| `date` | TIMESTAMPTZ | |
| `created_at` | TIMESTAMPTZ | |

### `categories` _(custom per-household)_
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `household_id` | UUID FK | |
| `name` | TEXT | custom category name |

> Added in migration 4. Default categories are returned in-code; this table holds household-specific additions.

**Key constraint (ADR-008):** A user belongs to **exactly one household** (`users.household_id` is a single FK). No `household_members` join table in MVP.

---

## 5. API Surface

### Telegram Webhook (ingestion)
```
POST /webhook/telegram          ← Receives all Telegram Updates
```

### REST Endpoints (BFF for web/mobile)
```
# Transactions
GET    /api/transactions?household_id=&month=YYYY-MM
POST   /api/transactions?telegram_id=
GET    /api/transactions/{id}?household_id=
PUT    /api/transactions/{id}?household_id=
DELETE /api/transactions/{id}?household_id=

# Summary / Aggregation
GET /api/summary?household_id=&month=YYYY-MM
GET /api/summary/categories?household_id=&month=YYYY-MM
GET /api/summary/merchants?household_id=&month=YYYY-MM&limit=10

# Households
GET  /api/households/me?household_id=
GET  /api/households/me/members?household_id=
GET  /api/households/me/categories?household_id=
POST /api/households/me/categories?household_id=    ← body: {"name": "..."}
```

> Note: read endpoints accept either `telegram_id` or `household_id`. Mutation endpoints require `telegram_id`.

> [!WARNING]
> **REST auth is MVP-only (ADR-009).** Endpoints currently accept `telegram_id` or `household_id` as identity. This is **not cryptographically secure**.
>
> **Do not add any business logic that depends on this auth remaining as-is.** When a real client app ships, swap to Supabase Auth JWT tokens — only the identity-resolution helper changes, not the business logic.

#### Auth Migration Template (for Phase 6)
```python
# CURRENT (MVP):
async def get_current_user(telegram_id: int = Query(...)) -> User:
    return await db.get_user_by_telegram_id(telegram_id)

# FUTURE (JWT):
async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    payload = verify_supabase_jwt(token)
    return await db.get_user_by_id(payload["sub"])
```

### Bot Commands (Telegram)
| Command | Behaviour |
|---|---|
| `/start` | Onboarding flow (create household) or shows status if already onboarded |
| `/join <code>` | Joins an existing household by invite code |
| `/summary` | Current month: total spend + top 3 categories |
| `/categories` | Spend per category for current month |
| `/month YYYY-MM` | Summary for a specific month |
| `/dashboard` | Sends a link to the web dashboard |
| _(text message)_ | Parsed as expense via Gemini |
| _(photo message)_ | Receipt OCR via Gemini Vision |
| _(`.ofx` document)_ | Bulk OFX import with AI categorization |

---

## 6. Conversation State (FSM)

Multi-step Telegram flows use a `pending_state` + `pending_payload` pattern on the `users` table. **Never use in-memory state.**

```
/start → pending_state = 'onboarding_name'
       → pending_state = 'onboarding_currency' (name in pending_payload)
       → household created, pending_state cleared

[expense text/image] → pending_state = 'confirm_transaction' (ParsedTransaction in pending_payload)
                     → [✅ Save] → transaction saved, state cleared
                     → [✏️ Category] → category picker keyboard shown
                     → [❌ Cancel] → state cleared
                     → [fix_category:<cat> callback] → saved with corrected category, state cleared
```

---

## 7. Implementation Roadmap

| Phase | Goal | Status | Notes |
|---|---|---|---|
| Phase 0 | Scaffold, git, CI, docs | ✅ Complete | |
| Phase 1 | FastAPI + Webhook + `/start`/`/join` onboarding + Supabase schema + RLS | ✅ Complete | |
| Phase 2 | Gemini text/image parsing + confirmation flow | ✅ Complete | |
| Phase 3 | Full CRUD + OFX import + category correction | ✅ Complete | OFX uses AI batch-categorization |
| Phase 4 | `/summary`, `/categories`, `/month`, `/dashboard` + BFF aggregation endpoints | ✅ Complete | |
| Phase 5 | Web dashboard (`household-finance-web`) | ✅ Complete | |
| Phase 6 | REST auth migration (Supabase JWT) | ⬜ Planned | |
| Phase 7 | Mobile app (`household-finance-mobile`) | ⬜ Planned | |

> Update the status column here whenever a phase changes. See `IMPLEMENTATION_TODO.md` for the detailed gap analysis.

---

## 8. Known Constraints & Accepted Limitations

These are hard-decided constraints. Do not work around them without creating a new ADR.

| Constraint | Decided In | What it means |
|---|---|---|
| FastAPI + webhooks (not polling) | ADR-001 | No `python-telegram-bot` polling loop |
| Raw `httpx` for Telegram calls | ADR-002 | No `python-telegram-bot` wrapper library |
| Gemini for OCR (cost decision) | ADR-003 | Currently using `gemini-3.1-flash-lite` — ADR-003 needs update |
| Supabase RLS from Phase 1 | ADR-004 | RLS is required, not optional |
| `merchant` is its own column | ADR-005 | Not embedded in `description` |
| GitHub + GitHub Actions for CI | ADR-006 | |
| Currency is per-household | ADR-007 | No global default currency |
| One user ↔ one household (MVP) | ADR-008 | No `household_members` join table yet |
| REST auth deferred (MVP: `telegram_id`/`household_id` param) | ADR-009 | **Not secure** — internal use only |

Full ADR log: [`household-finance-api/docs/decisions.md`](./household-finance-api/docs/decisions.md)

---

## 9. Environment Variables

> Never commit secrets. Use GitHub Actions Secrets for CI and provider dashboards for prod.

| Variable | Used By | Description |
|---|---|---|
| `TELEGRAM_TOKEN` | API | Bot token from BotFather |
| `TELEGRAM_WEBHOOK_SECRET` | API | Self-generated random string for webhook validation |
| `SUPABASE_URL` | API | Supabase project URL |
| `SUPABASE_KEY` | API | Supabase `service_role` key (**not** `anon`) |
| `SUPABASE_DATABASE_PASSWORD` | API | Optional — for direct DB access |
| `GEMINI_API_KEY` | API | Google AI Studio API key |
| `LOG_LEVEL` | API | Logging level (default: `INFO`) |
| `BASE_URL` | API | Public base URL of the web app — used to build `/dashboard` links (default: `http://localhost:3000`) |
| `API_URL` | Web | Server-side URL to the FastAPI BFF (e.g. `https://your-api.vercel.app`) |
| `NEXT_PUBLIC_API_URL` | Web | Client-side fallback URL to the FastAPI BFF |

---

## 10. Deployment

See [`household-finance-api/docs/deployment.md`](./household-finance-api/docs/deployment.md) for the full local-testing and production deployment guide.

**API:** Deployed on Vercel (`vercel.json` present in `household-finance-api/`)
**Database:** Supabase (managed Postgres)
**Web:** Next.js — deployable to Vercel

---

## 11. Adding a New App

When adding a new app to this monorepo:
1. Create a new git repo: `household-finance-<name>` and clone it locally
2. Add its SSH clone URL to `clone-all.ps1` and `clone-all.sh` in the meta repo
3. Add an `AGENTS.md` with app-specific directives (include the cross-repo banner)
4. Update this file: sections 2 (structure), 3 (tech stack), and 7 (roadmap)
5. Update the root `AGENTS.md §0` table to reference the new app
6. Create an ADR in `household-finance-api/docs/decisions.md` for any architecture decisions made
