# Release procedure

A release changes one line in Git: the image tag in an overlay. Everything
after the merge is automatic.

## Roles

| Who | Does what |
|---|---|
| **Author** | Opens the PR that bumps the tag; watches the canary after merge |
| **Reviewer** | Approves the PR once `validate` is green |
| **Argo CD** | Applies the merged change to the cluster (polls `main` every 30s) |
| **Argo Rollouts** | Moves traffic 20% → 50% → 100%, runs the analysis, aborts on failure |

## Steps

1. **Image exists.** `app-image.yml` has built and pushed the tag to
   `ghcr.io/abhichandra-v/gitops-demo-app` (tags listed in `app/releases.env`).
2. **Open a PR** that changes `newTag` in
   `apps/demo-app/overlays/dev/kustomization.yaml`:

   ```bash
   git switch -c release/demo-app-v2.0.0
   yq e -i '.images[0].newTag = "v2.0.0"' apps/demo-app/overlays/dev/kustomization.yaml
   git commit -am "chore(release): demo-app v2.0.0 in dev"
   git push -u origin release/demo-app-v2.0.0
   ```

   In this case study the release commits were made directly on `main` with
   `scripts/release.sh` to keep the recorded timings clean. The commit content
   is identical.
3. **Validation.** `validate.yml` must pass: kustomize build, kubeconform
   `-strict`, kube-score, Checkov, chart rendering ([VALIDATION.md](VALIDATION.md)).
4. **Merge** to `main`. This is the release.
5. **Observe the canary.**

   ```bash
   kubectl argo rollouts get rollout demo-app -n demo-dev --watch
   bash scripts/measure.sh            # one timestamped line per poll
   ```

   Expected timeline for a good release (Scenario A): Argo CD notices the
   commit within about 25–77s, weight 20 shortly after, first analysis passes
   about 75s later, weight 50, second analysis, fully promoted. Recorded: 247s
   from push to 100% ([evidence](evidence/scenario-a/good-release-v1-to-v2.txt)).
6. **Done** when Argo CD shows `Synced / Healthy` and the Rollout is `Healthy`
   with the new image as stable.

## What "promote" and "abort" mean

| Action | Who triggers it | Effect | Changes Git? |
|---|---|---|---|
| Step advances | Rollouts, when the AnalysisRun is `Successful` | Next `setWeight` | No |
| `kubectl argo rollouts promote` | A person | Skips the current step or pause | No |
| Automatic abort | Rollouts, when the AnalysisRun is `Failed` or `Error` | Weight to 0, canary scaled down, Rollout `Degraded` | No — Git still names the bad tag |
| `kubectl argo rollouts abort` | A person | Same as automatic abort; Argo CD does not undo it (Scenario C2) | No |

After any abort, the release is not finished until Git is brought back in line
with what is serving: see the [recovery runbook](RECOVERY-RUNBOOK.md).

## If the analysis aborts your release

1. Do **not** run `kubectl argo rollouts undo` — with selfHeal on it
   re-deploys the bad version (Scenario C1).
2. `git revert` the release commit and merge it (Scenario D, 67s to Healthy).
3. Look at the failed AnalysisRun for the measured values:

   ```bash
   kubectl get analysisrun -n demo-dev
   kubectl describe analysisrun <name> -n demo-dev
   ```
