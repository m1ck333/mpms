# MPMS — monorepo workflow

Manufacturing Process Monitoring System. One repo: `be/` (.NET) + `fe/` (pnpm
workspace: dashboard + tablet). Per-repo coding conventions live in
`be/CLAUDE.md` and `fe/CLAUDE.md` — **this file is the branch + deploy workflow,
and it is authoritative.**

## Branches (only two — this is a solo project)

| Branch | Environment | Deploy |
|---|---|---|
| `staging` | **alblue** — test env | `./deploy.sh staging` |
| `main` | **algreen** — pilot = Mile's production | `./deploy.sh pilot` |

No feature branches. No `master` (that was the old separate BE repo — this
monorepo uses `main`).

## The loop — local → staging → production, every time

1. **Local.** Develop and test on your machine until satisfied.
2. **Staging.** Commit + push to `staging`, then `./deploy.sh staging`. Verify
   on alblue.
3. **Production.** Merge `staging → main`, push, then `./deploy.sh pilot`.
   (Merge FIRST — the pilot deploy ships `main`'s tip, so merging after would
   ship stale code.)

**No bypassing.** Even an urgent pilot bug goes local → staging → prod. The
only discipline: always promote by merging `staging → main` — never commit new
work straight to `main`, so the two branches never diverge or conflict.

## Deploy permission — ALWAYS ASK FIRST

**Never run `./deploy.sh` (staging or pilot) on your own initiative. Always ask
Milos and wait for an explicit go-ahead before any deploy.** This applies to
both environments, every time — no standing pre-authorization. Committing,
pushing, and merging are fine; the `deploy.sh` step specifically requires
asking first.

## Superseded docs

`fe/HANDOFF.md`, `fe/CLAUDE.md`, and `be/docs/CLAUDE_ONBOARDING.md` predate the
monorepo (created 2026-07-17) and still describe the old multi-repo world:
separate `algreen-tracker-*` / `alblue-tracker-*` repos, and promoting by
**rsync-mirroring files** between two FE repos ("mirror waves", "never `cp`
between repos", branding divergence). **That mirror workflow is dead** —
promotion is now a git merge `staging → main`. Read those files for coding
conventions and gotchas only, not for branch/deploy workflow.

## Ops

- Deploy config (hosts, paths, Sentry env) is per-environment inside
  `deploy.sh`, not in per-branch files, so `staging → main` merges never
  conflict. `.env` (gitignored) supplies the deploy host + SSH key.
- Sentry: org `sky-hard`, project `mes-api` (BE + both FE apps report here,
  split by `environment` tag: `alblue-staging`, `algreen-pilot`).
