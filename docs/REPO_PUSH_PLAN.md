# Repo push plan (GitHub private; wait for empty repo URL)

## Decision
- Host: **GitHub private** (Z t313u).
- Cursor cannot create GitHub repositories. **Z creates an empty private repo** and shares its URL; parent forwards that URL before any `git remote add` / `git push`.
- Do **not** use `gh repo create`, GitHub API create, or Origin as a substitute for this push target.

## Local facts
- Branch `main`, initial commit `a28a2f7` only; **no git remote configured**.
- Hygiene commit prepared on top (Mac touchpad MVP + docs/index + sanitization + ignore/xcconfig).
- Raw `build/` diagnostics/screenshots/logs/crash packages remain on disk and stay gitignored.
- `Config/Developer.xcconfig` and `Config/local_devices.env` are gitignored (local Team + device IDs).
- Tracked `project.yml` / regenerated `project.pbxproj` use empty `DEVELOPMENT_TEAM`; local signing still uses the gitignored xcconfig.

## History note (not rewritten)
`a28a2f7` still contains a personal Apple ID email string and DEVELOPMENT_TEAM literals in README / run_watch.sh / project files. **Nothing has been pushed**, so parent may still choose:
1. **Keep history:** push `main` as-is to the new empty private repo (email/team remain in the first commit forever).
2. **Clean root:** orphan/clean history without rewriting a remote (only valid while remote has no `a28a2f7`). Procedure stays manual after URL arrives; no force-push plan against a non-empty remote.

## After URL arrives
1. Confirm repo is empty/private and SSH/HTTPS URL.
2. `git remote add origin <url>` (first remote; do not alter unrelated remotes — there are none today).
3. Normal `git push -u origin main` (or orphan branch if parent chose clean root).
4. No `--force` unless parent explicitly orders a safe empty-repo case in writing.
