# 0004 — App-of-apps with two projects and Helm-sourced platform apps

**Context.** The cluster must be rebuildable from Git with one command, and
"what is installed" must be a reviewable diff. Argo CD itself is part of what
is installed.

**Decision.**

- One root `Application` (`bootstrap/root-app.yaml`) points at `argocd/`. It is
  the only thing applied by hand (through `make bootstrap`). Everything in
  `argocd/` is created, changed and pruned by commits.
- Platform components are `Application`s with a Helm chart source pinned to an
  exact chart version, plus a second source (`ref: values`) that reads the
  values file from this repo under `platform/<chart>/values.yaml`. Chart
  version and values therefore change through the same pull request.
- Argo CD manages its own Helm release (`argocd/argocd.yaml`) with the same
  values file the bootstrap script uses, so there is one definition of the
  Argo CD config.
- Ordering uses `sync-wave`: projects (-2), Argo CD (-1), Argo Rollouts (0),
  ingress-nginx (1), kube-prometheus-stack (2), workloads (3). Because Argo CD
  no longer assesses `Application` health by default, the health check for
  `argoproj.io/Application` is restored in `argocd-cm`; without it the waves
  would not wait for each other.
- Two `AppProject`s: `platform` (may create cluster-scoped resources, limited
  to four source repos and four namespaces) and `apps` (this repo only, the
  demo namespaces only, no cluster-scoped resources except `Namespace`).
- Every app syncs with `automated: {prune: true, selfHeal: true}`.

**Consequence.** A change to the platform is a commit; an out-of-band change is
reverted by self-heal. The cost is a circular dependency at bootstrap (Argo CD
must exist before it can manage itself), which is why a small Helm install
script remains. `ServerSideApply=true` is set on the platform apps because the
Prometheus Operator CRDs exceed the size limit of the client-side
last-applied annotation.

`scripts/check-platform.sh` keeps `versions.env` and the manifests honest: it
fails if a chart version in `argocd/` differs from `versions.env` or a chart no
longer renders with its values.
