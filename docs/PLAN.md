# Build plan

Checklist for building this repo. Items are ticked in the same commit as the work.
Checkpoints marked 🛑 need the repo owner (push, GitHub settings, cluster runs).

## Phase 0 — `chore/bootstrap`

- [x] `.gitignore`, `.editorconfig`, MIT `LICENSE`
- [x] README skeleton and this plan
- [x] `versions.env` and Makefile skeleton with `doctor`

## Phase 1 — `feat/demo-app`

- [x] Go service: `/` (version JSON), `/healthz`, `/metrics` (`http_requests_total{code}`, request duration)
- [x] Fault mode `FAULT_MODE=error-40pct` (about 40% of requests return HTTP 500)
- [x] Tests for fault injection and metrics
- [x] Multi-stage, small, non-root Dockerfile
- [x] `.github/workflows/app-image.yml`: matrix build of `v1.0.0`, `v2.0.0`, `v3.0.0-bad`, pushed to GHCR
- [x] Acceptance: tests pass; each image runs locally; `v3.0.0-bad` returns ~40% 500s over 200 requests (count saved to evidence); `/metrics` exposes the status-code counter

> 🛑 **Checkpoint A:** owner pushes, enables Actions, confirms the three images exist and sets the GHCR package to public.
> Fallback: `kind load docker-image`, documented in an ADR.

## Phase 2 — `feat/cluster-bootstrap`

- [x] `bootstrap/kind-config.yaml` and `make cluster-up`
- [x] `bootstrap/install-argocd.sh` (Helm, pinned chart; prints how to get the admin password without writing it to the repo)
- [x] Port-forward helper for the UI and `make bootstrap`
- [x] Local bootstrap documented
- [x] Acceptance: Argo CD healthy; UI reachable; evidence saved (`kubectl get pods -A`, `argocd version`)

## Phase 3 — `feat/app-of-apps-platform` → tag `v0.1.0`

- [x] Root `Application` in `bootstrap/root-app.yaml` pointing at `argocd/`
- [x] `AppProject` restricting source repos and destination namespaces
- [x] Argo CD manages itself
- [x] Argo Rollouts via Argo CD (Helm source, pinned, sync-wave)
- [x] ingress-nginx via Argo CD
- [x] kube-prometheus-stack via Argo CD (Alertmanager and Grafana off)
- [x] ADR for app-of-apps
- [x] Acceptance: one `make bootstrap` converges to Synced/Healthy from Git only; self-heal of a deleted platform resource captured as evidence

## Phase 4 — `feat/rollout-canary`

- [x] `Rollout` with canary steps (`setWeight 20 → pause 30s → setWeight 50 → pause 30s → setWeight 100`)
- [x] Stable and canary Services
- [x] `dev` and `prod` overlays pinning image tag and replicas
- [x] Argo CD `Application` for the demo app
- [x] Acceptance: healthy v1; tag bump to v2.0.0 via commit progresses to 100%; watch output saved with timestamps

## Phase 5 — `feat/traffic-routing`

- [x] Ingress for the demo app
- [x] NGINX traffic routing on the Rollout
- [x] In-cluster load generator
- [x] Acceptance: measured traffic split at the 20% step recorded

## Phase 6 — `feat/analysis-automated-rollback` → tag `v0.5.0`

- [x] Prometheus success-rate `AnalysisTemplate` (≥ 0.95, no-data does not pass)
- [x] `PodMonitor` carrying the `rollouts-pod-template-hash` label
- [x] Canary steps gated on analysis
- [x] Analysis tuning decisions recorded
- [x] Acceptance: good release passes and promotes; `v3.0.0-bad` fails analysis and aborts automatically; both runs captured

## Phase 7 — `ci/manifest-validation`

- [x] `validate.yml`: `kustomize build` for every overlay + `kubeconform -strict` with CRD schemas
- [x] `kube-score` and Checkov with documented skips
- [x] Demo app pod spec hardened (non-root, read-only root fs, dropped caps, limits, probes)
- [ ] Validation gates documented

## Phase 8 — `docs/scenarios`

- [ ] `scripts/measure.sh`
- [ ] A. Good release v1 → v2
- [ ] B. Bad release v2 → `v3.0.0-bad`, automatic abort
- [ ] C. Manual rollback inside the cluster with `selfHeal` on
- [ ] D. GitOps rollback with `git revert`
- [ ] E. Drift and self-heal
- [ ] F. Argo CD unavailable
- [ ] `docs/case-study/SCENARIOS.md` written from recorded evidence

> 🛑 **Checkpoint B:** owner runs the push steps for the scenarios with the cluster up and adds UI screenshots.

## Phase 9 — `docs/final-polish` → tag `v1.0.0`

- [ ] `docs/ARCHITECTURE.md` with Mermaid diagrams
- [ ] `docs/RELEASE-PROCEDURE.md`
- [ ] `docs/RECOVERY-RUNBOOK.md`
- [ ] `README.md` with scenario results table
- [ ] Final pass: every number maps to an evidence file; `make doctor` clean; validate workflow green; gitleaks on full history; `git status` clean

## Definition of done

- [ ] One `make cluster-up bootstrap` brings up Argo CD, the platform and the demo app purely from Git
- [ ] Good release promotes through canary steps with analysis passing
- [ ] Bad release is aborted automatically by Prometheus analysis; evidence captured
- [ ] Manual undo vs `git revert` behaviour observed, recorded and explained
- [ ] Validation workflow green (kustomize, kubeconform, kube-score, Checkov)
- [ ] Architecture, release procedure and recovery runbook written from observed results
- [ ] History is feature-branch merges with Conventional Commits and no secrets
- [ ] Tags `v0.1.0`, `v0.5.0`, `v1.0.0` exist locally
