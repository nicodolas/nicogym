# Repository delivery policy

## Pull request review gate

For every repository change intended for GitHub, invoke `$pr-review-loop` and follow its full workflow.

- Create a task branch before committing; never push task commits directly to the default branch.
- Open or update a pull request and wait for CI, Cubic, and CodeRabbit to review the current head commit.
- Evaluate and record every AI review item, implement accepted feedback, push fixes, and repeat the review loop.
- Keep the PR open unless the user explicitly authorizes merging.
- If a reviewer integration is absent or unavailable, report that exact blocker; do not silently bypass the gate.
