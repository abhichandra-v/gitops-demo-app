# Case study: release and rollback scenarios

Six scenarios, each run against the local kind cluster with Argo CD syncing
`main` of this repository from GitHub. Every number below comes from a recorded
run; each section links its raw evidence (commands, timestamped polling output,
final state).

**How times are measured.** `scripts/measure.sh` prints one line every ~3-6s
with Argo CD sync/health, the Rollout phase, step, canary weight and ready pods
per image tag. `+Ns` is seconds since the push (or since the manual command).
Polling granularity means each time is accurate to about ±5s.

**Setup for all runs.** Argo CD v3.5.5 with `timeout.reconciliation: 30s`
(ADR 0003), Argo Rollouts v1.10.1, ingress-nginx traffic routing, a load
generator sending 20 requests/s through the ingress, and the success-rate
analysis from ADR 0006 gating the 20% and 50% steps.

## Summary

| Scenario | What was done | Outcome | Measured | Evidence |
|---|---|---|---|---|
| A. Good release | Commit tag bump v1.0.0 → v2.0.0, push | Both analyses passed (every measurement `1`), promoted to 100% | **247s** push → fully promoted | [scenario-a](../evidence/scenario-a/good-release-v1-to-v2.txt) |
| B. Bad release | Commit tag bump v2.0.0 → v3.0.0-bad, push | Analysis failed (0.521, 0.553), rollout **aborted automatically**, traffic back on v2.0.0 | **74s** push → abort | [scenario-b](../evidence/scenario-b/bad-release-v2-to-v3-bad.txt) |
| C1. `rollouts undo` with selfHeal on | `kubectl argo rollouts undo` after B | Undo lasted ~5s; Argo CD re-applied Git (v3.0.0-bad), a **new bad canary** started and was aborted by analysis again | 6s undo → bad canary at 20%; 50s → second abort | [undo](../evidence/scenario-c/undo-with-selfheal.txt) |
| C2. `rollouts abort` with selfHeal on | `retry`, then a manual `abort` mid-canary | Abort held; Argo CD stayed `Synced` and did not fight it | weight back to 0 within 2s | [abort](../evidence/scenario-c/abort-with-selfheal.txt) |
| D. GitOps rollback | `git revert` of the bad bump, push | Synced/Healthy on v2.0.0, no new pods | **67s** push → Healthy | [scenario-d](../evidence/scenario-d/git-revert-bad-release.txt) |
| E. Drift | Patch live Rollout replicas 5 → 2, then image → v1.0.0 | Both reverted by selfHeal | replicas: spec back within 6s, all 5 ready at 14s; image: back within 4s | [replicas](../evidence/scenario-e/drift-replicas.txt), [image](../evidence/scenario-e/drift-image.txt) |
| F. Argo CD down | Scale controller and server to 0, drift replicas 5 → 3, restore controller | App served 100% of sampled requests throughout; drift stayed until the controller returned | recovery **21s** after controller scaled up | [scenario-f](../evidence/scenario-f/argocd-down.txt) |

## A. Good release (v1.0.0 → v2.0.0)

**Goal.** Show a release that changes only an image tag in Git and is promoted
through the canary steps because the analysis passes.

**Commands.** `make demo-good` (= `scripts/demo-good-release.sh v2.0.0`):
commit `chore(release): demo-app v2.0.0 in dev`, `git push origin main`, poll.

**What happened** ([evidence](../evidence/scenario-a/good-release-v1-to-v2.txt)):

| +s | Event |
|---|---|
| 0 | push |
| 68 | Argo CD sees the new revision (`OutOfSync`) |
| 74 | Rollout `Progressing`, new ReplicaSet created |
| 80 | weight 20, first canary pod ready; AnalysisRun starts |
| 157 | analysis 1 `Successful` (4/4 measurements = 1) |
| 163 | weight 50, second AnalysisRun starts |
| 247 | analysis 2 `Successful`, Rollout `Healthy`, 100% on v2.0.0 |

After promotion, 200 of 200 sampled requests returned `v2.0.0`.

**What surprised me.** 68 of the 247 seconds passed before Argo CD noticed the
commit, despite a 30s reconciliation interval. Across all runs the push →
`OutOfSync` delay ranged from 25s (B) to 77s (the Phase 6 good release).
The cause was not measured; candidates are the repo-server's cache of the
resolved revision and the root app reconciling before the child app.

## B. Bad release (v2.0.0 → v3.0.0-bad)

**Goal.** A release that passes health checks but fails ~40% of real requests,
reaching the cluster the same way as a good one: a tag bump in Git.

**Commands.** `make demo-bad`.

**What happened** ([evidence](../evidence/scenario-b/bad-release-v2-to-v3-bad.txt)):

| +s | Event |
|---|---|
| 0 | push |
| 25 | Argo CD sees the new revision |
| 30 | weight 20, one `v3.0.0-bad` pod ready (it passes `/healthz`) |
| 59 | measurement 1: success rate **0.521** → Failed |
| 74 | measurement 2: **0.553** → Failed; AnalysisRun `Failed` ("failed (2) > failureLimit (1)"), `RolloutAborted`, weight 0 |
| 109 | canary pod gone (ReplicaSet scaled down) |

**Afterwards.**

- Argo CD: `sync=Synced health=Degraded`. Synced because the live Rollout
  matches Git, which still names `v3.0.0-bad`. Degraded because the Rollout is
  aborted.
- Rollouts: `✖ Degraded`, stable ReplicaSet still the v2.0.0 one.
- Users: 200 of 200 sampled requests returned `v2.0.0`.
- Exposure: in the 5 minutes covering the run, the canary served about 178 requests
  of which 76 were HTTP 500 (PromQL `increase(...[5m])` on the canary hash),
  out of about 6,551 requests in total. Those 76 errors are the cost of
  finding out.

**What surprised me.** The cluster is healthy for users but stays `Degraded`
with Git still pointing at the bad tag. Nothing converges on its own; a
person has to choose C or D.

## C. Manual rollback inside the cluster, with selfHeal on

**Goal.** Find out whether the in-cluster commands an operator might reach for
first survive Argo CD's self-heal.

### C1. `kubectl argo rollouts undo`

**Commands.** `scripts/demo-manual-undo.sh undo` while Git still says
`v3.0.0-bad` and the Rollout is aborted.

**What happened** ([evidence](../evidence/scenario-c/undo-with-selfheal.txt)):

| +s | Event |
|---|---|
| 0 | `undo`: Rollout template set back to the v2.0.0 revision (revision 11) |
| 1 | Rollout `Healthy` on v2.0.0; Argo CD `OutOfSync` |
| 6 | **selfHeal re-applies Git**: template is v3.0.0-bad again (revision 12), new canary at weight 20 |
| 50 | analysis fails again, second `RolloutAborted` |

**Why.** `undo` works by rewriting `spec.template` of the Rollout. That is
exactly the field Argo CD owns, so the change is drift and selfHeal reverts it
within one reconcile. The net effect of "undo" was a **second exposure of users
to the bad release**, stopped only because the analysis gate was still in
place.

### C2. `kubectl argo rollouts abort`

**Commands.** `kubectl argo rollouts retry rollout demo-app` to get a canary in
progress, then `kubectl argo rollouts abort demo-app` 15s later.

**What happened** ([evidence](../evidence/scenario-c/abort-with-selfheal.txt)):
weight went to 0 within 2s, the Rollout became `Degraded`, and Argo CD stayed
`Synced` the whole time — `abort` changes only Rollout *status*, not the spec
in Git, so there is nothing for selfHeal to revert.

**Takeaway.** With selfHeal on, `abort` is safe and immediate; `undo` is not a
rollback at all. The durable fix is a Git change (D).

## D. GitOps rollback (`git revert`)

**Commands.** `make demo-rollback` (= `scripts/demo-gitops-rollback.sh`):
`git revert` of the release commit, `git push origin main`, poll.

**What happened** ([evidence](../evidence/scenario-d/git-revert-bad-release.txt)):

| +s | Event |
|---|---|
| 0 | push of `revert: demo-app v3.0.0-bad in dev` |
| 62 | Argo CD sees the revision (`OutOfSync / Degraded`) |
| 67 | `Synced / Healthy`, Rollout `Healthy`, aborted flag cleared |

No pods were created: the reverted template hashes to the existing stable
ReplicaSet, so the Rollout simply marks it current. 62 of the 67 seconds were
Argo CD noticing the commit.

## E. Drift

**Commands.** `scripts/demo-drift.sh replicas` and `scripts/demo-drift.sh image`.

**What happened.**

- [Replicas 5 → 2](../evidence/scenario-e/drift-replicas.txt): Argo CD
  `OutOfSync` immediately; spec back to 5 within 6s; all 5 pods ready at 14s.
- [Image → v1.0.0](../evidence/scenario-e/drift-image.txt): spec back to
  v2.0.0 within 4s; ready pods stayed at 5 throughout.

**What surprised me.** Neither self-heal appears in the Application's
`status.history` (the last entry is the previous Git sync). Self-heal syncs of
the same revision leave no history entry, so an audit of "who changed what"
cannot rely on it.

## F. Argo CD unavailable

**Commands.** `make demo-argocd-down` (= `scripts/demo-argocd-down.sh`).

**What happened** ([evidence](../evidence/scenario-f/argocd-down.txt)):

1. `argocd-server` scaled to 0 **while the controller was running**: back to
   1/1 about 42s later. Argo CD manages its own release, so it healed itself.
2. Controller and server both at 0: the demo app kept serving — every 50-request
   sample returned `v2.0.0`.
3. Drift while down (replicas 5 → 3): stayed at 3 for the full 75s. The
   Application still showed `Synced/Healthy`, because nothing was updating its
   status; that status was stale, not true.
4. Controller scaled back to 1: replicas back to 5, `argocd-server` back, all
   `Synced/Healthy` **21s** later.

**Takeaway.** Argo CD being down stops delivery and self-heal, not traffic.
The Application status shown during an outage cannot be trusted.

## Cross-cutting observations

- **Exposure window for a bad release** is set by the analysis
  (`initialDelay` 30s + two 15s measurements), not by Argo CD: about 45s at
  20% weight once the canary pod is up.
- **Push-to-notice latency** (25-77s here) dominates every GitOps action,
  including the rollback in D. Webhooks would remove most of it.
- **The machine went to sleep** during an early attempt at C2; that run was
  discarded and repeated. The C2 evidence is from the repeat.

## Screenshots

Placeholders, to be added from the Argo CD UI and the Rollouts dashboard:

- `docs/evidence/screenshots/argocd-app-of-apps.png` — *placeholder*
- `docs/evidence/screenshots/rollouts-canary-20pct.png` — *placeholder*
- `docs/evidence/screenshots/rollouts-aborted-bad-release.png` — *placeholder*
- `docs/evidence/screenshots/argocd-synced-degraded.png` — *placeholder*
