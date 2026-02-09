# 0003 — Argo CD reconciliation every 30s, lean install

**Context.** Argo CD polls Git every 120s by default, with up to 60s of jitter.
The scenarios measure "time from push to effect", and a 0-3 minute polling
delay would dominate every measurement. No webhook can reach a local kind
cluster from GitHub.

**Decision.** `timeout.reconciliation: 30s` and `timeout.reconciliation.jitter:
0s` in `argocd-cm` (see `platform/argo-cd/values.yaml`). Dex, notifications and
the ApplicationSet controller are switched off because nothing here uses them.
`server.insecure: true` because the UI is only reached through a local
port-forward.

**Consequence.** A pushed commit is noticed within about 30s. All measured
"push to ..." timings in this repo include up to 30s of polling delay and are
not comparable with a default install. 30s polling against github.com is fine
for one repository but is not a setting to copy into a large installation; use
webhooks there.
