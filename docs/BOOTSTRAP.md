# Local bootstrap

Everything runs in a local `kind` cluster. Versions are pinned in
[`versions.env`](../versions.env).

## 1. Check prerequisites

```bash
make doctor
```

Reports missing tools; installs nothing. Docker needs about 6 GB of RAM.

## 2. Create the cluster

```bash
make cluster-up
```

Creates the kind cluster `gitops-rollback` from
[`bootstrap/kind-config.yaml`](../bootstrap/kind-config.yaml): one control-plane
and two workers, with host ports 80 and 443 mapped to the control-plane node on
`127.0.0.1` for ingress. kind switches your current kubectl context to
`kind-gitops-rollback`.

## 3. Install Argo CD

```bash
make bootstrap
```

Runs [`bootstrap/install-argocd.sh`](../bootstrap/install-argocd.sh): a
`helm upgrade --install` of the official `argo-cd` chart at the pinned version
with [`platform/argo-cd/values.yaml`](../platform/argo-cd/values.yaml).

## 4. Open the UI

```bash
make argocd-ui
```

Then open <http://localhost:8443> and log in as `admin`. Print the initial
password to your terminal only. Do not redirect it into a file in this repo:

```bash
kubectl --context kind-gitops-rollback -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Tear down

```bash
make cluster-down
```

## Without make

Each target is a wrapper around one script, so `bash scripts/cluster-up.sh`,
`bash bootstrap/install-argocd.sh` and so on work directly.

## Evidence

A recorded run is in
[`docs/evidence/phase-2/argocd-install.txt`](evidence/phase-2/argocd-install.txt).
