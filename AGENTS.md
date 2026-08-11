# Repository delivery policy

## Pull request review gate

For every repository change intended for GitHub, invoke the repository skill at `.codex/skills/pr-review-loop/SKILL.md` and follow its full workflow.

- Create a task branch before committing; never push task commits directly to the default branch.
- Open or update a pull request. Delivery requires every required CI/check to pass and Cubic plus CodeRabbit to return results for the current head SHA.
- Record a disposition and rationale for every distinct AI review item: `accepted`, `already-addressed`, `duplicate`, `rejected`, or `unresolved`.
- Implement accepted feedback, verify it, push fixes, and repeat for at most three automatic remediation rounds.
- Every new commit or push makes prior CI, Cubic, and CodeRabbit results stale; obtain fresh results for the new head SHA.
- Delivery remains blocked while a required check fails or any blocking review item is unresolved.
- Keep the PR open unless the user explicitly authorizes merging.
- If a reviewer has not responded after 30 minutes, verify its installation, permissions, draft status, and trigger mechanism, then report the blocker.
- An unavailable reviewer remains blocking unless the user explicitly waives that reviewer after the missing evidence and risk are recorded. A reviewer waiver does not itself authorize merging.
