# Fat CI vs Thin CI — side by side

This doc accompanies Phần I of the research README. It compares the two
shapes of pipeline using files that live in this repo.

## The two files to compare

| File | Lines | Logic location |
|---|---|---|
| `application/ci-providers/fat-ci-example.yml` | ~85 | Inline YAML |
| `application/ci-providers/github-actions.yml` | ~25 | `scripts/*.sh` |

Both files deploy the same app from the same repo. The difference is where
the build/test/deploy logic *lives*.

## What the Fat CI version does that you can't do

- Reproduce the failure on a laptop. There is no equivalent of
  `./scripts/deploy.sh dev` — every change requires a push to CI.
- Unit-test the deploy logic. It is YAML interleaved with shell snippets
  and step outputs; there is nothing to import.
- Migrate to GitLab/Jenkins/CodeBuild without rewriting from scratch.
  Steps like `aws-actions/configure-aws-credentials@v4` are GitHub-only.
- Code-review the rollout decision tree. The "determine environment"
  step branches on `GITHUB_REF` using shell-in-YAML.

## What the Thin CI version gives up

Almost nothing. The CI file still owns the parts the CI provider is good
at: triggers, OIDC into the registry, runner provisioning, notifications.
The parts a CI provider is *not* good at — branching, state, error
handling — moved into a real language.

## The portability claim, in practice

The four files in `application/ci-providers/` (excluding the fat example)
all reduce to the same three lines:

```
./application/scripts/test.sh
./application/scripts/build.sh
./application/scripts/deploy.sh dev
```

Migrating from one CI provider to another means re-translating the
trigger config — typically 10-20 lines. It does not mean rewriting the
deploy logic.

## When Fat CI is acceptable

Single developer, single environment, you genuinely do not foresee ever
moving providers, and the pipeline is short enough to fit on one screen.
In any other situation, the Fat CI cost compounds.
