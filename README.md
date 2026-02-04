# GitOps & Safe Rollback on Kubernetes

> **Status: in progress.** See [docs/PLAN.md](docs/PLAN.md) for what is built so far.
> Results and measured timings will be added here only once they come from real runs.

A case study in GitOps delivery and release safety on Kubernetes: Argo CD syncs a
local `kind` cluster from this repository, Argo Rollouts ships a demo app through
canary steps, and a Prometheus-based analysis aborts a bad release automatically.
The repo then compares the ways of rolling back (abort, in-cluster undo, `git revert`)
and records what each one actually does.

**Stack:** Kubernetes · Argo CD · Argo Rollouts · Helm · Prometheus · ingress-nginx

## Prerequisites

Docker (about 6 GB RAM available), kind, kubectl, helm, kustomize, the `argocd` CLI,
the `kubectl-argo-rollouts` plugin, Go, make and yq. Pinned versions are in
[versions.env](versions.env).

```bash
make doctor
```

`make doctor` reports what is missing. It does not install anything.

## Layout

To be filled in as the phases land.

## License

[MIT](LICENSE)
