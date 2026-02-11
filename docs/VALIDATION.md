# Validation gates

`.github/workflows/validate.yml` runs on every pull request and on `main`. It
calls the same script you can run locally:

```bash
bash scripts/validate.sh all      # or: render | kubeconform | kube-score | checkov
make check                        # platform charts render at the pinned versions
```

| Gate | What it checks | Fails the build when |
|---|---|---|
| `kustomize build` | Every overlay under `apps/*/overlays/*` renders | An overlay does not build |
| `kubeconform -strict` | Rendered overlays, `argocd/` and `bootstrap/root-app.yaml` against the Kubernetes schemas for the cluster version and CRD schemas (Rollout, AnalysisTemplate, Application, AppProject, PodMonitor) from the datreeio CRDs catalog | A field is unknown, mistyped or missing |
| `kube-score` | Pod spec quality: security context, resources, probes, PDB, anti-affinity | Any CRITICAL finding |
| Checkov (`kubernetes` framework) | Security misconfiguration | Any failed check that is not skipped |
| `scripts/check-platform.sh` | Each platform chart renders with its values at the version in `versions.env`; `argocd/` pins the same versions and repo URL | Versions drift apart or a chart stops rendering |

## Scoring the Rollout as a Deployment

kube-score and Checkov do not know the `Rollout` kind, so they would silently
skip the demo app's pod template, which is the part most worth checking. Before
scoring, `scripts/validate.sh` writes a copy of each rendered overlay in which
the Rollout is rewritten as a `Deployment` with the same pod template
(`rendered/scoring/`). kubeconform validates the real Rollout.

## Documented skips

| Tool | Check | Why it is skipped |
|---|---|---|
| kube-score | `container-image-pull-policy` | Wants `imagePullPolicy: Always`. The images are side-loaded into kind (ADR 0005); `Always` would force a registry pull that cannot succeed. |
| kube-score | `pod-networkpolicy` | NetworkPolicies are outside the scope of this case study. |
| kube-score | `pod-probes` on `loadgen` only | `fortio load` is a client with no port to probe, and the image has no shell for an exec probe. |
| Checkov | `CKV_K8S_43` (image digest) | The image tag is the release lever the whole case study turns on. In production, pin digests. |
| Checkov | `CKV_K8S_15` (pull policy Always) | Same reason as the kube-score skip. |
| Checkov | `CKV2_K8S_6` (NetworkPolicy) | Same reason as the kube-score skip. |
| Checkov | `CKV_K8S_8`, `CKV_K8S_9` on `loadgen` only | No endpoint to probe; set as annotations on the Deployment. |

## What the gates caught

- Before hardening: 18 kube-score CRITICALs and 50 failed Checkov checks
  ([evidence](evidence/phase-7/before-hardening.txt)). After: none
  ([evidence](evidence/phase-7/after-hardening.txt)).
- kube-score flagged identical liveness and readiness probes; liveness is now a
  TCP check and readiness the HTTP `/healthz` check.
- An earlier bug shows why the schema check matters: the load generator's
  `-H=Host: ...` argument was written unquoted, YAML parsed it as a map, and
  the API server rejected the Deployment after it was already on `main`
  (fixed in `fix: quote loadgen host header argument`). `kustomize build`
  accepts that file; `kubeconform -strict` rejects it.

## Not covered

- The workflow has not been observed running on GitHub from this build
  machine; the same script passes locally.
- Helm-rendered platform manifests are rendered but not scored: they are
  third-party charts and their findings are not actionable here.
