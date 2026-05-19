# Quickstart

This repo accompanies the research article in `README.md`. Each directory
demonstrates one stage of the CI/CD evolution covered in the article.

## What's where

| Directory | Demonstrates | Article section |
|---|---|---|
| `application/` | Thin CI + Thick Scripts, Build Once Deploy Anywhere | Phần I, III |
| `application/ci-providers/` | Same three commands, four CI providers; one fat-CI anti-pattern | Phần I §1.4 |
| `manifests/` | GitOps with Kustomize overlays + Argo CD Applications | Phần IV |
| `manifests/argocd/` | Correct `write-back-method: git` setup, AppProject scope | Phần IV §4.3 |
| `secrets-examples/sealed-secrets/` | Encrypted-in-Git pattern | Phần V §5.2.1 |
| `secrets-examples/vault/` | Centralized Vault with Agent Injector | Phần V §5.2.2 |
| `docs/` | Side-by-side comparisons and runbooks | — |

## Three commands you actually run

```bash
./application/scripts/test.sh                       # pytest
./application/scripts/build.sh                      # docker build, tag, record
APP_VERSION=v0.1.0 ./application/scripts/deploy.sh dev   # pin overlay
```

All three are the same commands every CI provider in
`application/ci-providers/` runs. That is the entire pitch of Phần I.

## Promotion flow at a glance

1. `build.sh` produces `ghcr.io/example-org/sample-app:<sha>`.
2. `deploy.sh dev` rewrites the `newTag:` in
   `manifests/apps/sample-app/overlays/dev/kustomization.yaml` and commits.
3. Argo CD (`manifests/argocd/applications/sample-app-dev.yaml`) syncs.
4. Promotion to staging/prod is a PR that bumps the corresponding overlay.
   `sample-app-prod` is the only Application without auto-sync — production
   goes out by human approval.

## Rollback

```bash
git -C manifests revert <bad-commit>
git -C manifests push
```

Argo CD reconciles within ~30 seconds. No CI rebuild. See Phần IV §4.4.

## Further reading inside this repo

- `docs/fat-vs-thin-ci.md` — direct comparison of the two CI files
- `docs/gitops-setup.md` — end-to-end Argo CD installation walkthrough
- `docs/secret-management.md` — when to pick Sealed Secrets vs Vault
- `application/README.md` — sample app layout
- `manifests/README.md` — manifest repo layout and promotion model
