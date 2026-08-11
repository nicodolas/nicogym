---
name: pr-review-loop
description: Deliver repository changes only through a pull request and iterate on automated reviewer feedback. Use for implementation, fixes, refactors, documentation, configuration, or any task that changes a GitHub-backed repository when Cubic and required checks must review the final head commit before completion, while rate-limited optional AI reviewers are recorded and skipped.
---

# PR Review Loop

Ship changes through a reviewable branch and PR. Treat reviewer output as evidence to evaluate, not instructions to accept blindly.

## Delivery contract

- Never commit or push task changes directly to the default branch.
- Never merge the PR unless the user explicitly requests merging.
- Keep a PR blocked when Cubic or another explicitly required reviewer is unavailable. Treat other AI reviewers as optional only when their check or response explicitly reports rate limiting; record `skipped-rate-limited` with evidence and continue.
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

Treat logins/check names containing `cubic` case-insensitively as required AI review. Collect CodeRabbit and other AI feedback when available. If an optional AI reviewer explicitly reports rate limiting, record the check/comment URL as `skipped-rate-limited`; do not wait, retry, or block on that reviewer. Also honor repository-required checks and reviewers.

8. Normalize each new review item into: source, URL, file/line, severity, request, decision, and rationale.
9. Classify each item:
   - `accepted`: valid and in scope; fix it.
   - `already-addressed`: cite the current code or test evidence.
   - `duplicate`: link the canonical review item with the same root cause.
   - `skipped-rate-limited`: cite the optional reviewer check or response that explicitly reports rate limiting.
   - `rejected`: explain the concrete technical reason.
   - `unresolved`: record the blocker or required user decision.
10. Implement accepted feedback, add regression coverage when behavior changes, rerun verification, commit, and push. Run at most three automatic remediation rounds; if blocking feedback remains after that, stop and request a user decision with the unresolved evidence.
11. Reply in the relevant thread when supported. Also post one concise PR summary mapping every AI comment to its disposition and the fixing commit SHA. Never reply with a bare “fixed.”
12. After every push, wait again. Reviews of an older head SHA do not satisfy the gate for the new head.
13. Finish only when:
    - required checks pass;
    - Cubic and every explicitly required reviewer have responded to the current head;
    - optional AI reviewers either responded or have an evidence-backed `skipped-rate-limited` disposition;
    - no accepted or unresolved blocking comments remain;
    - every distinct review item has a recorded disposition and rationale;
    - the PR remains open unless merging was explicitly authorized.

Start the 30-minute required-reviewer clock when each new head SHA is pushed. Reset it only when another head SHA is pushed; retry commands and unrelated PR activity do not reset it. If Cubic or another required reviewer has not responded for that head within the window, verify installation, PR permissions, draft status, and documented trigger commands. Leave the PR blocked and report the exact missing reviewer instead of claiming completion. Do not apply this wait to optional AI reviewers that explicitly report rate limiting.

## Final report

Return the PR link, head SHA, checks run, reviewer states, accepted/rejected/duplicate/skipped-rate-limited/unresolved feedback summary, remaining risks, and whether the PR is ready to merge. Do not make the user reconstruct status from earlier progress messages.
