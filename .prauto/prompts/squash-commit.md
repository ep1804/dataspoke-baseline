Generate a single conventional commit message for the following squash commit.

## Issue #{issue_number}: {issue_title}

{issue_body}

## Changed files

{diff_stat}

## Diff (truncated)

{diff}

## Rules

1. First line: `<type>: <subject>` — conventional commit format (feat, fix, docs, refactor, etc.)
2. Second line: blank
3. Body: brief description of what was done (max 5 lines). Focus on the "why" and key changes.
4. Last line of body MUST be: `(issue #{issue_number}, PR #{pr_number})`
5. Output ONLY the raw commit message text. No markdown fences, no explanations.
