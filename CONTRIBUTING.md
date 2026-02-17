# Contributing to Lapse

> **This is a school project. We are not accepting outside contributions.**
> If you are not a member of the project team, please do not open pull requests, issues, or comments. They will be closed without review.

---

The guidelines below are for **team members only**.

## Pull Request Naming

PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>: <short description>
```

**Types:**

| Type | Use when... |
|------|------------|
| `feat` | Adding new functionality |
| `fix` | Fixing a bug |
| `refactor` | Restructuring code without changing behavior |
| `docs` | Documentation only |
| `style` | Formatting, whitespace, naming (no logic changes) |
| `test` | Adding or updating tests |
| `chore` | Build config, dependencies, tooling |

**Examples:**
- `feat: add bulk card move to deck detail screen`
- `fix: cascade soft-delete to nested decks and cards`
- `refactor: replace N+1 card counts with COUNT(*) queries`
- `docs: add AI usage log for session 2026-02-14`

Keep titles under 70 characters. Use the PR body for details.

## General Guidelines

- **Read before you edit.** Understand the existing code and patterns before making changes.
- **Keep changes focused.** One PR should address one concern. Don't bundle unrelated fixes.
- **Match existing conventions.** Follow the patterns already in the codebase (see `CLAUDE.md` for architecture details).
- **Test your changes.** Run the app and verify your changes work before opening a PR. If tests exist for the area you changed, make sure they pass.
- **Commit logically.** Use conventional commit messages. Prefer small, frequent commits over large monolithic ones.
- **No dead code.** Don't leave behind commented-out code, debug prints, or TODO stubs.
