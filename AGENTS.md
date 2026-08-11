# Repository delivery policy

## Pull request review gate

For every repository change intended for GitHub, invoke the repository skill at `.codex/skills/pr-review-loop/SKILL.md` and follow its full workflow.

- Create a task branch before committing; never push task commits directly to the default branch.
- Open or update a pull request. Delivery requires every required CI/check to pass and Cubic to review the current head SHA.
- Record a disposition and rationale for every distinct AI review item: `accepted`, `already-addressed`, `duplicate`, `rejected`, `skipped-rate-limited`, or `unresolved`.
- Collect CodeRabbit and other AI reviews when available. If an optional AI reviewer explicitly reports rate limiting, record the evidence as `skipped-rate-limited` and do not let it block delivery.
- Implement accepted feedback, verify it, push fixes, and repeat for at most three automatic remediation rounds.
- Every new commit or push makes prior CI and Cubic results stale; obtain fresh results for the new head SHA. Available optional-AI feedback must also target the current head.
- Delivery remains blocked while a required check fails or any blocking review item is unresolved.
- Keep the PR open unless the user explicitly authorizes merging.
- Start a 30-minute reviewer clock for each newly pushed head SHA. Only a new head SHA resets it; bot retriggers do not. On timeout, verify installation, permissions, draft status, and trigger mechanism, then report the blocker.
- Cubic and explicitly required reviewers remain blocking when unavailable. Optional AI reviewers are skippable only with explicit rate-limit evidence.
