# 0006 — Canary analysis tuning

**Context.** The analysis has to fail a release that returns about 40% HTTP
500s, pass a healthy one, and never pass because there was nothing to measure.
The load generator sends 20 requests/s through the ingress, so a 20% canary
gets roughly 4 requests/s.

**Decision.** `apps/demo-app/base/analysis-template.yaml`:

| Setting | Value | Why |
|---|---|---|
| Query | non-5xx rate / total rate over `[1m]`, filtered by `rollouts_pod_template_hash` | Looks at canary pods only. The hash comes from `podTemplateHashValue: Latest`; the `PodMonitor` copies the pod label onto the series. |
| `successCondition` | `len(result) > 0 && !isNaN(result[0]) && result[0] >= 0.95` | Empty result (no series) and NaN (no requests) fail instead of passing. |
| `initialDelay` | 30s | The canary needs to receive traffic and be scraped (every 5s) before a 1m rate means anything. |
| `interval` / `count` | 15s / 4 | A passing step takes about 75s (30s + 3 x 15s). |
| `failureLimit` | 1 | One bad sample is tolerated; the second aborts. |
| `consecutiveErrorLimit` | 2 | A query that cannot run ends the analysis as Error, which also aborts. |

The same template gates both the 20% and the 50% step.

**Observed** (see `docs/evidence/phase-6/`):

- Good release: both AnalysisRuns `Successful`, every measurement `1`.
  Fully promoted 302s after the push.
- Bad release (`v3.0.0-bad`): measurements `0.708` then `0.658`, AnalysisRun
  `Failed` ("failed (2) > failureLimit (1)"), rollout aborted with weight back
  to 0. The abort showed up 84s after the push; the two failed measurements
  were taken 30s and 45s after the analysis started.
- After the abort Argo CD reports `Synced / Degraded`: the cluster matches Git
  (which still names the bad tag), but the Rollout is Degraded and all traffic
  is on the previous version.

**Consequence.** With these values a bad release is exposed to at most 20% of
traffic for about a minute. Lowering `initialDelay` would shorten that but
risks judging a canary on a few seconds of data. The analysis depends on
Prometheus and on steady traffic: with the load generator off, a release
cannot promote (NaN fails) — which is the intended direction of failure.
