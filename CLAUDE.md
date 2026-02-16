# Global Guidelines

## Naming Conventions
- Use clear, descriptive names that reveal intent — avoid abbreviations and single-letter variables outside small loop scopes
- Files and folders: use kebab-case (e.g., `user-profile.ts`, `api-handlers/`) or match the dominant convention of the project's language/framework
- Match the existing project's naming style before introducing a new one
- Boolean variables/functions: prefix with `is`, `has`, `should`, `can`

## Folder Structure
- Group by feature or domain, not by file type, when the project grows beyond a handful of files
- Keep nesting shallow — max 3-4 levels deep; prefer flat structures
- Separate source code, tests, configuration, and documentation into distinct top-level directories
- Place shared utilities in a clearly named directory (e.g., `lib/`, `shared/`, `utils/`)

## Documentation
- Every project must have a root `README.md` covering: purpose, setup instructions, usage, and contribution guidelines
- Document "why", not "what" — code shows what it does; comments explain non-obvious reasoning
- Keep a `CHANGELOG.md` for projects with releases or versioned APIs
- Add inline comments only for complex logic, workarounds, or non-obvious business rules

## Version Control (Git)
- Write commit messages in imperative mood: "Add feature", "Fix bug", "Remove unused code"
- Keep commits atomic — one logical change per commit
- Use feature branches; never commit directly to `main` or `master`
- Write meaningful PR descriptions explaining what changed and why
- Do not commit secrets, credentials, or environment-specific config — use `.gitignore` and `.env` files

## Git Safety
- Before the first commit in any project, verify a .gitignore exists and covers secrets (.env*, *.key, *.pem, credentials*)
- Run `gitleaks detect` before pushing to verify no secrets are staged
- Never commit files matching: .env, .env.*, *.pem, *.key, *.p12, *.pfx, credentials.json, service-account*.json, *secret*, token.json
- If pre-commit hooks are not installed in a project, run `pre-commit install` to set them up
- When creating new projects, initialize with a comprehensive .gitignore appropriate for the language/framework
- Never force-push to any branch; never push directly to main or master
- When in doubt about whether a file contains sensitive data, ask before committing

## Code Quality
- Follow the principle of least surprise — write code that does what a reader would expect
- Prefer explicit over implicit; prefer simple over clever
- Handle errors explicitly — do not silently swallow exceptions
- Remove dead code rather than commenting it out; Git preserves history

## Collaboration
- Before making large architectural changes, outline the plan and confirm with the user
- When modifying existing code, preserve the project's established patterns and style
- Run existing linters, formatters, and test suites before proposing changes
- When adding dependencies, prefer well-maintained libraries with active communities
