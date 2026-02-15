# BeamBox V2 Git Workflow

Use this flow for every feature, fix, and refactor.

## Branch Strategy

- Stable branch for BeamBox work: `codex/logistics-foundation`
- Create a new feature branch for each task:
  - `codex/feature/<short-name>`
  - `codex/fix/<short-name>`
  - `codex/chore/<short-name>`
- Keep branches small and focused to one concern.

## Daily Flow

1. Sync base branch:
   - `git checkout codex/logistics-foundation`
   - `git pull origin codex/logistics-foundation`
2. Create a feature branch:
   - `git checkout -b codex/feature/<short-name>`
3. Make changes in small commits.
4. Run verification before merge:
   - `cd /Users/jesse/pulse/Boppy/v2/ios/BoppyV2App && swift test`
   - `xcodebuild -project /Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/BoppyV2App.xcodeproj -scheme BoppyV2App -destination 'generic/platform=iOS Simulator' build`
   - `cd /Users/jesse/pulse/Boppy/v2/backend/supabase/functions && deno check */index.ts` (only if backend touched)
5. Push branch:
   - `git push -u origin codex/feature/<short-name>`
6. Open PR into `codex/logistics-foundation`.
7. Merge only after:
   - CI/checks pass
   - manual simulator pass for changed screens
   - no unresolved conflicts

## Commit Rules

- Conventional commits:
  - `feat(v2): ...`
  - `fix(v2): ...`
  - `docs(v2): ...`
  - `chore(v2): ...`
- One logical change per commit.
- Do not mix unrelated changes in a single commit.

## Safety Rules

- Never commit directly to `main`.
- Avoid long-lived feature branches.
- Rebase/sync if branch gets stale:
  - `git fetch origin`
  - `git rebase origin/codex/logistics-foundation`
- If urgent hotfix:
  - branch from latest `codex/logistics-foundation`
  - merge back immediately after verification.

## Release Merge Path

1. Feature branch -> `codex/logistics-foundation`
2. Stabilization/testing on `codex/logistics-foundation`
3. `codex/logistics-foundation` -> `main` for release
