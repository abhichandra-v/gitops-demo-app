# 0002 — Repo-local tool directory and isolated Helm state

**Context.** The build machine (Windows 11, Git Bash) had Docker, kubectl and
Helm but not kind, kustomize, the argocd CLI, the Argo Rollouts kubectl plugin,
Go or yq. Its global Helm config also referenced a repository whose cached index
was missing, which made every `helm --repo` call fail.

**Decision.** Scripts source `scripts/lib.sh`, which (a) prepends an optional,
gitignored `.bin/` directory to `PATH`, and (b) points `HELM_REPOSITORY_CONFIG`
and `HELM_REPOSITORY_CACHE` at `.bin/helm/`. The missing tools were downloaded
into `.bin/` from their official release pages at the versions in
`versions.env`, and each download was checked against the published SHA-256.
Nothing was installed system-wide and no global config was changed.

**Consequence.** The scripts work the same whether tools are installed
system-wide or dropped into `.bin/`. `make` itself was not available on the
build machine, so every Makefile target is a one-line wrapper around a script
that can be run directly with `bash`.
