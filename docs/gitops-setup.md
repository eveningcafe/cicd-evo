# GitOps setup walkthrough

End-to-end setup matching the manifests in `manifests/argocd/`. Assumes a
Kubernetes cluster with admin access and a running Argo CD installation.

## 1. Install Argo CD (if not already installed)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## 2. Create the AppProject

The `AppProject` constrains *what* this team's Applications are allowed to
deploy and *where*. RBAC lives here, not on individual Applications.

```bash
kubectl apply -f manifests/argocd/projects/sample-app-project.yaml
```

## 3. Create the three Applications

```bash
kubectl apply -f manifests/argocd/applications/sample-app-dev.yaml
kubectl apply -f manifests/argocd/applications/sample-app-staging.yaml
kubectl apply -f manifests/argocd/applications/sample-app-prod.yaml
```

Note the difference between the three: `dev` and `staging` have
`syncPolicy.automated`, `prod` does not. Production goes out by PR review,
per Phần II §2.1.

## 4. Install Argo CD Image Updater (optional)

The hand-off in this repo uses CI to commit the new image tag into
`overlays/<env>/kustomization.yaml`. If you prefer the CD side to do that
itself, install Image Updater:

```bash
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
kubectl apply -f manifests/argocd/image-updater-config.yaml
```

The Application annotation `argocd-image-updater.argoproj.io/write-back-method: git`
is mandatory. **Do not** change it to `argocd`. See Phần IV §4.2.

## 5. Promotion flow

```
[code]
   │
   ▼
push to main
   │
   ▼
CI builds image, tags <sha>, pushes to registry
   │
   ▼
CI runs deploy.sh dev          ── commit ──▶ overlays/dev/kustomization.yaml
                                                        │
                                                        ▼
                                                   Argo CD sync (auto)
                                                        │
                                                        ▼
                                                   dev cluster updated

manual PR bumps overlays/staging/kustomization.yaml ──▶ Argo CD sync (auto)
manual PR bumps overlays/prod/kustomization.yaml    ──▶ Argo CD sync (manual)
```

## 6. Rollback

```bash
git -C manifests revert <bad-deploy-commit>
git -C manifests push
```

Argo CD reconciles within ~30 seconds. Nothing else to do.

## Source of truth, restated

The only place that decides what runs in any cluster is the corresponding
overlay's `kustomization.yaml`. Argo CD UI is observation, not control.
The CI script writes Git. Image Updater writes Git. Humans write Git.
Anything that bypasses Git is by definition drift, and Argo CD's self-heal
will undo it on the next sync — that is the feature, not a bug.
