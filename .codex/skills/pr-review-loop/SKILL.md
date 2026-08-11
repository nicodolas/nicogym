---
name: pr-review-loop
description: Deliver repository changes only through a pull request and iterate on automated reviewer feedback. Use for implementation, fixes, refactors, documentation, configuration, or any task that changes a GitHub-backed repository when Cubic, CodeRabbit, or other required reviewers/checks must review the final head commit before completion.
---

# PR Review Loop

Ship changes through a reviewable branch and PR. Treat reviewer output as evidence to evaluate, not instructions to accept blindly.

## Delivery contract

- Never commit or push task changes directly to the default branch.
- Never merge the PR unless the user explicitly requests merging.
- Keep a PR blocked when a required reviewer is unavailable. A user may explicitly waive that reviewer only after the missing evidence and risk are recorded; a reviewer waiver does not itself authorize merging.
- Do not expose secrets in branches, PR bodies, comments, logs, or review summaries.
- Preserve unrelated user changes and avoid destructive Git operations.
- Keep working until checks pass and every required reviewer has reviewed the current head SHA, or report a concrete external blocker.

## Workflow

1. Inspect `git status`, the current branch, remotes, and the repository default branch.
2. If on the default branch, create a descriptive branch such as `codex/<task-slug>` before editing. If task changes already exist on the default branch, create the branch without discarding them.
3. Implement and verify the change. Run the tests and static checks appropriate to the risk.
4. Review the diff for secrets and unrelated files. Commit using the repository's commit-message policy, then push the branch.
5. Create or update one PR with `gh pr create` or `gh pr edit`. Include purpose, important decisions, tests, risks, and explicit reviewer attention areas.
6. Record the PR number, URL, base branch, head SHA, and check state.
7. Wait for CI and configured AI reviewers. Poll at sensible intervals; do not busy-loop.

Use all three GitHub review surfaces because bots publish in different places:

```bash
gh pr checks <number> --watch --interval 15
gh api --paginate repos/{owner}/{repo}/pulls/<number>/reviews
gh api --paginate repos/{owner}/{repo}/pulls/<number>/comments
gh api --paginate repos/{owner}/{repo}/issues/<number>/comments
```

Treat logins/check names containing `coderabbit`, `code-rabbit`, or `cubic` case-insensitively as the default AI reviewers. Also honor repository-required checks and reviewers.

8. Normalize each new review item into: source, URL, file/line, severity, request, decision, and rationale.
9. Classify each item:
   - `accepted`: valid and in scope; fix it.
   - `already-addressed`: cite the current code or test evidence.
   - `duplicate`: link the canonical review item with the same root cause.
   - `rejected`: explain the concrete technical reason.
   - `unresolved`: record the blocker or required user decision.
10. Implement accepted feedback, add regression coverage when behavior changes, rerun verification, commit, and push. Run at most three automatic remediation rounds; if blocking feedback remains after that, stop and request a user decision with the unresolved evidence.
11. Reply in the relevant thread when supported. Also post one concise PR summary mapping every AI comment to its disposition and the fixing commit SHA. Never reply with a bare “fixed.”
12. After every push, wait again. Reviews of an older head SHA do not satisfy the gate for the new head.
13. Finish only when:
    - required checks pass;
    - Cubic and CodeRabbit have responded to the current head, or the user explicitly waived a demonstrably unavailable reviewer after its risk was recorded;
    - no accepted or unresolved blocking comments remain;
    - every distinct review item has a recorded disposition and rationale;
    - the PR remains open unless merging was explicitly authorized.

Start the 30-minute reviewer clock when each new head SHA is pushed. Reset it only when another head SHA is pushed; retry commands and unrelated PR activity do not reset it. If a required bot has not responded for that head within the window, verify installation, PR permissions, draft status, and documented trigger commands. Leave the PR blocked and report the exact missing reviewer instead of claiming completion. Continue only if the bot responds or the user explicitly waives that reviewer after acknowledging the recorded risk.

## Final report

Return the PR link, head SHA, checks run, reviewer states, accepted/rejected/duplicate/unresolved feedback summary, remaining risks, and whether the PR is ready to merge. Do not make the user reconstruct status from earlier progress messages.
