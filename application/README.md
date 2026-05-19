# application/

Sample service that demonstrates the **Thin CI, Thick Scripts** pattern from
Phần I of the research document.

## Layout

```
src/                 # Python service code (Flask)
tests/               # pytest suite
Dockerfile           # produces the artifact deployed by every environment
scripts/             # portable build/test/deploy logic — runs on laptop and CI
  build.sh
  test.sh
  deploy.sh
  lib/common.sh
ci-providers/        # thin per-provider configs that all call into scripts/
  github-actions.yml
  gitlab-ci.yml
  jenkins/Jenkinsfile
  codebuild/buildspec.yml
  fat-ci-example.yml # anti-pattern, kept for direct comparison
```

## Run locally

```bash
./scripts/test.sh                 # unit tests
./scripts/build.sh                # build + tag a Docker image
APP_VERSION=v0.1.0 ./scripts/build.sh
./scripts/deploy.sh dev           # writes the new image tag into manifests/
```

Every command above is the same one CI runs. If CI fails, you can reproduce
the failure locally — no `git commit -m "fix CI"` loop required.

## What "Build Once, Deploy Anywhere" looks like here

`build.sh` produces one image tagged with the git short-SHA and writes the
tag to `.build/image`. `deploy.sh dev|staging|prod` then pins the same tag
into the corresponding overlay under `../manifests/`. Promoting a build from
dev to prod is the exact same image — no rebuild.
