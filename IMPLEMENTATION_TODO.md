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

1. **Landing page (`/`)** ✅ Decision made — implement **both B and C**:
   - **Static marketing page (C):** Explains what the app is, shows a link/QR to the Telegram bot.
   - **Telegram deep-link entry (B):** Bot's `/dashboard` command sends a URL with `household_id` that opens the dashboard directly. The landing page handles unknown/missing `household_id` gracefully by redirecting to the marketing view.
   - No household ID entry form (Option A) — too much friction without auth.

2. **`src/types/` directory** 🔴 **MANDATORY** — Create typed interfaces mirroring the Pydantic schemas:
   - `Transaction`, `Household`, `HouseholdSettings`, `SummaryResponse`, `CategorySummaryResponse`, `MerchantSummaryResponse`, `MemberResponse`
   - Remove **all** `any` casts in dashboard and transactions pages.

3. **API client abstraction** 🔴 **MANDATORY** — Create `src/lib/api.ts` with typed fetch helpers for every BFF endpoint. All pages must import from this module — no inline `fetch()` calls allowed anywhere.
   - Additionally: **purge all `fetch()` calls that do not go through `/api`** from the codebase. No direct Supabase calls, no external HTTP calls from the frontend.

4. **Locale switching** 🔴 **MANDATORY** — `next-intl` locale routing is needed. Add a language switcher to the topbar (initially `pt-BR` / `en`). Requires adding a `[locale]` route segment and the `en.json` messages file.

5. **Dashboard: month picker** 🔴 **MANDATORY** — Add a month picker to the dashboard page so the summary cards and category chart update for any selected month (not just the current one).

6. **Proper transaction deletion** 🔴 **MANDATORY** — The delete action on the transactions page needs: optimistic UI update, error rollback, and a success/error toast notification.

7. **Loading skeletons** 🔴 **MANDATORY** — Add `loading.tsx` to both the dashboard and transactions routes so Next.js shows skeleton placeholders during server-side data fetching instead of a blank screen.

8. **Members page** — ~~Deferred.~~ The `/api/households/me/members` endpoint is used only for member filtering on the transactions page. No dedicated members management page is needed at this stage.

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

> 🔴 = Mandatory before Phase 5 can be marked complete.

#### Web — UI & Architecture

| # | Item | Priority | Effort |
|---|---|---|---|
| W1 | Implement landing page: static marketing view + `household_id` deep-link entry (B+C) | 🔴 Mandatory | 🟡 Medium |
| W2 | Create `src/types/` — typed interfaces for all BFF responses; remove all `any` casts | 🔴 Mandatory | 🟢 Small |
| W3 | Create `src/lib/api.ts` typed API client; replace all inline `fetch()` calls; purge any non-`/api` fetches | 🔴 Mandatory | 🟢 Small |
| W4 | Add locale switcher to topbar; add `[locale]` route segment; create `messages/en.json` | 🔴 Mandatory | 🟡 Medium |
| W5 | Add month picker to dashboard page (summary cards + category chart update on change) | 🔴 Mandatory | 🟢 Small |
| W6 | Proper transaction deletion: optimistic update, error rollback, success/error toast | 🔴 Mandatory | 🟢 Small |
| W7 | Add `loading.tsx` to dashboard and transactions routes (skeleton placeholders) | 🔴 Mandatory | 🟢 Small |

#### API — Cleanup (same sprint)

| # | Item | Priority | Effort |
|---|---|---|---|
| A1 | Move summary aggregation to Supabase SQL `GROUP BY` query or RPC | 🔴 Mandatory | 🟡 Medium |
| A2 | Add `MemberResponse` Pydantic schema; fix `list[dict]` on members endpoint | 🔴 Mandatory | 🟢 Small |
| A3 | Move inline `import uuid` to top-level in `households.py` | 🟡 Nice-to-have | 🟢 Trivial |
| A4 | Add `BASE_URL`, `API_URL`, `NEXT_PUBLIC_API_URL` to `.env.example` | 🔴 Mandatory | 🟢 Trivial |
| A5 | Add `test_households.py` for members + categories endpoints | 🔴 Mandatory | 🟡 Medium |

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
