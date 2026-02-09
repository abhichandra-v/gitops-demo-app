# 0005 — Images are loaded into kind; GHCR publishing stays in CI

**Context.** The plan is for GitHub Actions to push the three release images to
`ghcr.io/abhichandra-v/gitops-demo-app` and for the cluster to pull them
anonymously. That needs the package to be made public in the GitHub UI by the
repo owner. At build time an anonymous pull token for the package was refused,
so the cluster could not pull.

**Decision.** Use the documented fallback: build the images locally
(`make images`) and load them into the kind nodes (`make load-images`). The
image references in Git are unchanged (`ghcr.io/abhichandra-v/gitops-demo-app:<tag>`),
and the Rollout keeps the default `imagePullPolicy` (`IfNotPresent` for a
non-`latest` tag), so a node uses the loaded image and never contacts the
registry. `.github/workflows/app-image.yml` still builds and pushes the same
three tags from the same Dockerfile and build args.

**Consequence.** Nothing in the manifests changes when the package becomes
public; `make load-images` just becomes unnecessary. Differences from the
registry path: (1) the images on the nodes are local builds, not the CI-built
digests; (2) pod start is faster because there is no pull, so measured rollout
times are slightly optimistic compared with a cold pull; (3) a rebuilt cluster
needs `make load-images` before the demo app can start.
