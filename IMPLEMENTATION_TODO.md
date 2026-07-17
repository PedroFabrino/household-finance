# IMPLEMENTATION_TODO.md

> Gap analysis produced from a full audit of both repos on 2026-07-17.
> Reflects what was planned vs. what is actually implemented.
> Each item links to the relevant app and phase. Update this file as items are completed.

---

## Summary

| Phase | API Status | Web Status |
|---|---|---|
| 1 — Onboarding + schema | ✅ Done | N/A |
| 2 — Parsing + confirmation | ✅ Done | N/A |
| 3 — CRUD + OFX | ✅ Done | ✅ Done (transactions page) |
| 4 — Summaries + aggregation | ✅ Done | ✅ Done (dashboard) |
| 5 — Web dashboard | N/A | 🔄 In Progress |
| 6 — Auth (JWT) | ⬜ Not started | ⬜ Not started |
| 7 — Mobile | ⬜ Not started | N/A |

---

## API (`household-finance-api`) — Gap Analysis

### ✅ Fully Implemented (beyond original plan)

- All Phase 1–4 deliverables are complete
- Extra endpoints not in original plan, now implemented:
  - `GET /api/households/me/members` — list household members
  - `GET /api/households/me/categories` — list merged default + custom categories
  - `POST /api/households/me/categories` — add a custom category per household
- OFX import enhanced: AI batch-categorization via `parse_ofx_batch()` (batches of 100)
- Nubank-specific OFX deduplication: `external_id = f"{fitid}_{amount}"` to handle reused FITIDs
- `account_type` (`checking`/`credit_card`) and `type` (`expense`/`income`/`transfer`) fields
  on transactions — not in original plan but properly migrated
- `/dashboard` bot command sends a direct link to the web dashboard

### ✅ Resolved Deviations

| Item | Resolution |
|---|---|
| LLM model changed (`gemini-1.5-flash` → `gemini-3.1-flash-lite`) | **ADR-010** written — model deprecated, free-tier upgrade |
| SDK changed (`google-generativeai` → `google-genai`) | **ADR-011** written — old SDK deprecated by Google |
| Auth params accept `household_id` in addition to `telegram_id` | **ADR-009 updated** — intentional; required for web dashboard before auth exists |

### 🔴 Open Tech Debt — Fix as part of Phase 5 dashboard completion

These are API-side cleanup items to be done in the same sprint as the dashboard work.

- **Summary aggregation is in-memory** — `get_summary()` fetches all transactions and aggregates in Python. Move to a Supabase SQL `GROUP BY` query or RPC for correctness at scale.
- **`list[dict]` return type on members endpoint** — `GET /api/households/me/members` returns `list[dict]`, violating the Pydantic schema rule. Add a `MemberResponse` schema to `schemas/transaction.py`.
- **Inline `import uuid` inside route handlers** — `households.py` imports `uuid` inside function bodies. Move to top-level.
- **Missing tests for households endpoints** — `test_webhook.py` etc. exist; `households.py` members and categories endpoints have no test coverage. Add `test_households.py`.
- **`BASE_URL` missing from `.env.example`** — Present in `config.py` but not documented in the example file.

---

## Web (`household-finance-web`) — Gap Analysis

### ✅ Fully Implemented

- **Dashboard page** (`/dashboard/[household_id]`): Summary cards (total balance, expenses, top category, active members), spending-by-category chart, recent transactions list
- **Transactions page** (`/dashboard/[household_id]/transactions`): Full transactions table with filtering (date range, category multi-select, member, source, search), inline category editing, inline delete, pagination
- **i18n**: `next-intl` set up with `pt-BR` as default locale; all strings externalized
- **shadcn/ui** component library installed (16 components)
- **Dark theme** with glassmorphism styling

### ⚠️ Deviations / Issues

| Item | Expected | Actual |
|---|---|---|
| Root landing page (`/`) | Login/entry page | **Still the Next.js default scaffold** — "To get started, edit page.tsx" |
| TypeScript `any` types | Banned | Dashboard `page.tsx` uses `any` in `chartData: any[]`, `transactions.forEach((t: any)`, etc. |
| `src/types/` directory | All types here | No `src/types/` directory exists — types are inline |
| API client helpers | In `src/lib/` | No API client abstraction; each page manually constructs fetch calls |
| `console.log` cleanup | None in production | `console.error` calls left in page components (acceptable), but worth reviewing |

### 🔴 Open Items — Phase 5 Remaining Work

1. **Landing page (`/`)** — The root page is the default Next.js scaffold. Needs a proper entry point.
   - **Option A:** A household ID entry form (user pastes/types their household ID to open dashboard)
   - **Option B:** A Telegram-auth gate (deep-link from bot, `telegram_id` in URL)
   - **Option C:** Static marketing/info page with a link to the bot
   - **Decision needed from Pedro before implementing.**

2. **`src/types/` directory** — Create typed interfaces mirroring the Pydantic schemas:
   - `Transaction`, `Household`, `SummaryResponse`, `CategorySummaryResponse`, `MerchantSummaryResponse`
   - Remove all `any` casts in dashboard and transactions pages

3. **API client abstraction** — Each page duplicates `fetch(${apiUrl}/api/...)`. Should be a `src/lib/api.ts` module with typed helpers.

4. **No `src/i18n/` routing** — `next-intl` messages exist, but there is no locale routing (`[locale]` segment). Confirm whether single-locale (always `pt-BR`) is intentional or if locale switching is needed.

5. **Dashboard: no month selector** — Dashboard always shows current month. Transactions page has date range filtering, but the dashboard summary cards and chart have no month picker.

6. **Transactions page: delete is client-side only** — Delete button calls the API but there is no optimistic UI or success toast.

7. **No loading skeletons on dashboard** — Data fetching is server-side, but there is no `loading.tsx` in the dashboard route, so navigating to it shows a blank screen on slow connections.

8. **Members page** — The `GET /api/households/me/members` endpoint is implemented in the API but there is no web page for it.

---

## Docs (`household-finance-api/docs/`) — Gap Analysis

| Document | Status | Notes |
|---|---|---|
| `decisions.md` | ✅ Updated | ADR-003 superseded by ADR-010; ADR-009 updated; ADR-010 and ADR-011 added |
| `deployment.md` | ✅ Accurate | Covers local + prod setup correctly |
| `implementation-plan.md` | ⚠️ Outdated | Describes Phases 1–4 as planned; does not reflect what was actually built (extra endpoints, column changes, Vercel deploy). Low priority — superseded by this document |

---

## Priority Order (Suggested Next Steps)

### Phase 5 — Complete Web Dashboard (current focus)

| # | Item | App | Effort |
|---|---|---|---|
| 1 | **Decide on landing page strategy** (see §Web item 1 above — options A/B/C) | Web | 🟡 Decision needed |
| 2 | Implement landing page once decision is made | Web | 🟢 Small–Medium |
| 3 | Create `src/types/` with typed interfaces; remove all `any` casts | Web | 🟢 Small |
| 4 | Create `src/lib/api.ts` typed API client (deduplicate fetch logic) | Web | 🟢 Small |
| 5 | Add `loading.tsx` to dashboard + transactions routes | Web | 🟢 Small |
| 6 | Move summary aggregation from Python in-memory to Supabase SQL `GROUP BY` | API | 🟡 Medium |
| 7 | Add `MemberResponse` Pydantic schema; fix `list[dict]` on members endpoint | API | 🟢 Small |
| 8 | Move inline `import uuid` to top-level in `households.py` | API | 🟢 Trivial |
| 9 | Add `BASE_URL` and `API_URL` / `NEXT_PUBLIC_API_URL` to `.env.example` | API | 🟢 Trivial |
| 10 | Add `test_households.py` for members + categories endpoints | API | 🟡 Medium |

### Phase 6 — Auth

| # | Item | App | Effort |
|---|---|---|---|
| 10 | Write ADR for chosen auth strategy (Supabase JWT recommended) | Both | 🟡 Decision + ADR |
| 11 | Implement JWT-based identity resolution in API | API | 🔴 Large |
| 12 | Update web to pass auth token with every BFF request | Web | 🔴 Large |

### Phase 7 — Mobile

| # | Item | App | Effort |
|---|---|---|---|
| 13 | Write tech-stack ADR (React Native vs Flutter) | Meta | 🟡 Decision + ADR |
| 14 | Scaffold `household-finance-mobile/` repo | Mobile | 🔴 Large |
