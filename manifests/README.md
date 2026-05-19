# manifests/

GitOps manifest repository for the sample app. In a real setup this would
live in its own Git repo so that the application repo and the manifest repo
have independent lifecycles — see Phần IV §4.4. They are kept together here
for demo purposes.

## Layout

```
apps/sample-app/
  base/                  # shared Deployment + Service
  overlays/
    dev/                 # 1 replica, dev env, dev image tag
    staging/             # 2 replicas, staging env
    prod/                # 4 replicas, prod resource limits
argocd/
  projects/              # AppProject (RBAC + destination whitelist)
  applications/          # one Argo CD Application per environment
  image-updater-config.yaml
```

## Promotion flow

1. CI builds and pushes `ghcr.io/example-org/sample-app:<sha>`.
2. CI runs `application/scripts/deploy.sh dev`. The script rewrites the
   `images:` block in `overlays/dev/kustomization.yaml` and commits.
3. Argo CD's `sample-app-dev` Application syncs the change.
4. Promotion to staging or prod is a PR that bumps the corresponding overlay.
   `sample-app-prod` has `syncPolicy.automated` disabled on purpose —
   production goes out by human approval.

## Rollback

`git revert <commit>` in this repo. Argo CD will reconcile within ~30s.
No CI rebuild required. See Phần IV §4.4.

## Why this layout, and not Argo CD writing to the cluster directly

See Phần IV §4.2. If Image Updater writes directly to the cluster
(`write-back-method: argocd`) instead of committing to Git, the cluster
becomes a second source of truth alongside Git, and disaster recovery from
Git silently rolls the cluster backward in time. The `argocd/` config in
this directory pins the safe default.
