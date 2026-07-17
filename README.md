# household-finance

> **Meta-repository** for the Household Finance project.
> This repo contains no application code — it holds the cross-cutting documentation and setup scripts that govern all apps.

## Repositories

| App | Repository | Description |
|---|---|---|
| Backend / BFF | [household-finance-api](https://github.com/PedroFabrino/household-finance-api) | FastAPI BFF, Telegram bot, Gemini OCR |
| Web dashboard | [household-finance-web](https://github.com/PedroFabrino/household-finance-web) | Next.js dashboard (App Router, shadcn/ui) |
| Mobile _(planned)_ | `household-finance-mobile` | React Native or Flutter — tech TBD |

## Quick Start

Clone this repo, then run the setup script to clone all sub-repos alongside it:

```powershell
# Windows
git clone git@github.com:PedroFabrino/household-finance.git
cd household-finance
.\clone-all.ps1
```

```bash
# macOS / Linux
git clone git@github.com:PedroFabrino/household-finance.git
cd household-finance
bash clone-all.sh
```

Your working directory will look like:

```
household-finance/          ← you are here (meta repo)
├── PROJECT.md
├── AGENTS.md
├── clone-all.ps1
├── clone-all.sh
├── household-finance-api/  ← cloned by setup script (separate git repo)
└── household-finance-web/  ← cloned by setup script (separate git repo)
```

## Key Documents

| Document | Purpose |
|---|---|
| [`PROJECT.md`](./PROJECT.md) | Single source of truth: system overview, data model, roadmap, ADRs, env vars |
| [`AGENTS.md`](./AGENTS.md) | Cross-cutting AI agent & contributor directives for all apps |

## Adding a New App

1. Create the new repo: `household-finance-<name>`
2. Add its SSH clone URL to `clone-all.ps1` and `clone-all.sh`
3. Follow the checklist in [`PROJECT.md §11`](./PROJECT.md#11-adding-a-new-app)
