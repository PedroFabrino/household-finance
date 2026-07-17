# AGENTS.md — Monorepo-Wide Coding Agent Directives

> **Scope:** These directives apply to ALL repositories in this monorepo.
> They are cross-cutting rules that override any app-specific AGENTS.md.
> Each app also has its own AGENTS.md with additional, app-specific rules — read both.

---

## 0. Start Here

Before working on any app in this monorepo, read:
1. **[`PROJECT.md`](./PROJECT.md)** — system overview, data model, roadmap, and all accepted constraints.
2. **This file** — universal rules for all agents.
3. **The target app's `AGENTS.md`** — app-specific rules.

| App | AGENTS.md |
|---|---|
| `household-finance-api` | [`household-finance-api/AGENTS.md`](./household-finance-api/AGENTS.md) |
| `household-finance-web` | [`household-finance-web/AGENTS.md`](./household-finance-web/AGENTS.md) |
| `household-finance-mobile` | _Not yet created — see PROJECT.md §11_ |

---

## 1. Monorepo Architecture Rules

- The **FastAPI BFF** (`household-finance-api`) is the **only** service that talks to Supabase.
- Frontends (`web`, `mobile`) **MUST NOT** make direct Supabase calls. All data access goes through the BFF REST API.
- Telegram is an **ingestion channel** — it is not the application core. Bot logic lives in `bot_service.py`, not in routers.
- **Do not blur boundaries between apps.** If a feature requires a schema change, update the API first, then the consumer.

---

## 2. Secrets & Environment Variables

- **NEVER** hardcode credentials, tokens, or API keys anywhere in the codebase.
- **NEVER** commit `.env` files. They are git-ignored; use `.env.example` as a template.
- **NEVER** log or print secret values, even in debug mode.
- All env vars are documented in [`PROJECT.md §9`](./PROJECT.md#9-environment-variables). Add new ones there when introducing them.
- Use GitHub Actions Secrets for CI. Use the cloud provider's dashboard for production.

---

## 3. Git & Branching

- The `main` branch is production-ready at all times.
- Feature work goes on a branch: `feature/<short-description>`.
- Bug fixes: `fix/<short-description>`.
- CI must pass before merging to `main`.
- Commit messages must be descriptive and imperative: `Add OFX import handler`, not `stuff` or `WIP`.
- **NEVER** force-push to `main`.

---

## 4. Architecture Decision Records (ADRs)

- When making a **significant design decision** (library choice, schema change, auth strategy, etc.), log it in [`household-finance-api/docs/decisions.md`](./household-finance-api/docs/decisions.md).
- ADR format:
  ```markdown
  ## ADR-NNN: <Title>
  **Date:** YYYY-MM-DD
  **Status:** Accepted | Superseded by ADR-NNN
  **Context:** Why is this decision needed?
  **Decision:** What was decided?
  **Consequence:** What changes or risks does this introduce?
  ```
- Update [`PROJECT.md §8`](./PROJECT.md#8-known-constraints--accepted-limitations) when a new constraint is added.

---

## 5. Hard Constraints — Do Not Work Around These

These are accepted limitations documented in ADRs. Do not "fix" them without a new ADR.

| Constraint | Rule |
|---|---|
| No `python-telegram-bot` | Use raw `httpx.AsyncClient` for all Telegram Bot API calls (ADR-002) |
| No polling loop | Telegram uses webhooks only (ADR-001) |
| No GPT-4o or other LLMs | `gemini-3.1-flash-lite` only, for cost (ADR-010, supersedes ADR-003) |
| RLS always on | Supabase Row Level Security is required from Phase 1 (ADR-004) |
| One user = one household (MVP) | No `household_members` join table yet (ADR-008) |
| REST auth = MVP `telegram_id` param | **Not secure.** Do NOT build features that depend on this being permanent (ADR-009) |

> **On the REST auth constraint specifically:** The `telegram_id` / `household_id` query params are a known, accepted security gap for the MVP. Do NOT silently "improve" them by adding JWT middleware, session cookies, or any other auth mechanism — that work is scoped to Phase 6 and requires a dedicated ADR.

---

## 6. Cross-Cutting Banned Patterns

These are banned across the entire monorepo:

| Pattern | Why Banned | Alternative |
|---|---|---|
| Direct Supabase calls from frontend/mobile | Violates BFF boundary | Call the FastAPI REST API |
| In-memory conversation state | Lost on restart, unscalable | `pending_state` + `pending_payload` on `users` table |
| Hardcoded currency, category, or locale strings | Brittle | Enum in `schemas/`, i18n in frontend |
| `os.getenv()` in the API codebase | Bypasses validation | `from app.core.config import settings` |
| `any` TypeScript types in the web/mobile app | Loses type safety | Proper interfaces in `src/types/` |
| `print()` / `console.log()` left in production code | Not captured by loggers | `logging.getLogger(__name__)` / `console.error()` |
| Manually editing `requirements.txt` | Gets overwritten | Edit `requirements.in`, run `pip-compile` |
| Committing secrets | Security violation | GitHub Actions Secrets / `.env` (git-ignored) |

---

## 7. Testing Standards

- **API:** `pytest` + `pytest-mock`. No real external API calls in tests. Mock Supabase, Gemini, and Telegram responses.
- **Web:** TypeScript strict mode must pass. ESLint must pass with zero errors.
- **Mobile (future):** To be defined in `household-finance-mobile/AGENTS.md`.
- CI must pass on every push. Broken CI must be fixed before new features are merged.

---

## 8. Roadmap Awareness

Always check [`PROJECT.md §7`](./PROJECT.md#7-implementation-roadmap) before starting work.

- Do not implement Phase N+1 features while Phase N is incomplete.
- Do not add auth logic until Phase 6 is officially started and a new ADR is written.
- Do not scaffold `household-finance-mobile/` until a tech-stack ADR is approved.

---

## 9. Updating This Monorepo's Documentation

| When | What to update |
|---|---|
| New app added | `PROJECT.md §2`, `PROJECT.md §3`, `PROJECT.md §7`, this file `§0` |
| New ADR added | `household-finance-api/docs/decisions.md`, `PROJECT.md §8` |
| Phase completed | `PROJECT.md §7` status column |
| New env var added | `PROJECT.md §9` |
| New constraint discovered | `PROJECT.md §8`, this file `§5` if cross-cutting |
