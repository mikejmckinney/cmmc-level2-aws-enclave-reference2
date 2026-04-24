# 09 — Demo deploy + destroy GitHub Actions workflows

> Wires the deployable demo (prompt `05`) to GitHub Actions via AWS OIDC.
> No long-lived AWS keys in the repo. Includes a scheduled auto-destroy
> to bound demo cost.

## Context

The demo lives at a public URL prospects can click. To keep cost bounded
and avoid stale infra, we deploy on-demand and destroy nightly. AWS access
uses OIDC federation (no `aws_access_key_id` secrets).

## Prerequisites

- `05-terraform-demo-root.md` complete (`make demo-up` works locally).

## Deliverables

- [ ] `.github/workflows/demo-plan.yml`
  - Triggers: `pull_request` paths `terraform/demo/**`, `terraform/modules/**`
  - Steps: checkout → setup-terraform → AWS OIDC assume → `terraform fmt -check`
    → `init` → `plan -out=tfplan` → upload plan as artifact → comment
    summary on PR
  - **Read-only** AWS role; no `apply` permissions

- [ ] `.github/workflows/demo-deploy.yml`
  - Triggers: `workflow_dispatch` only (manual)
  - Inputs: `confirm` (string, must equal `DEPLOY` to proceed)
  - Steps: checkout → setup-terraform → AWS OIDC assume (deploy role)
    → `init` → `apply -auto-approve` → write `terraform output -raw demo_url`
    to job summary and to a GitHub deployment status
  - Concurrency: `group: demo-deploy`, `cancel-in-progress: false`

- [ ] `.github/workflows/demo-destroy.yml`
  - Triggers:
    - `workflow_dispatch` (manual, with same `confirm: DESTROY` gate)
    - `schedule: cron: "0 7 * * *"` (07:00 UTC nightly = ~02:00 ET)
  - Steps: checkout → setup-terraform → AWS OIDC assume (deploy role)
    → `init` → `destroy -auto-approve`
  - Concurrency: shared with `demo-deploy` group

- [ ] `docs/demo-deploy.md` — operator guide:
  - Prereqs (AWS account, region, billing alarm)
  - **OIDC role bootstrap** — Terraform snippet (or CloudFormation) to
    create the GitHub OIDC provider + two roles (`demo-plan-readonly`,
    `demo-deploy`); with trust policy scoped to this repo and (for deploy)
    only the `main` branch + `workflow_dispatch`
  - Required GitHub repo secrets: `AWS_PLAN_ROLE_ARN`, `AWS_DEPLOY_ROLE_ARN`,
    `AWS_REGION` (default `us-east-1`), `AWS_ACCOUNT_ID`
  - Required GitHub variable: `DEMO_STATE_BUCKET` (S3 backend bucket)
  - How to override the schedule (env-protected `disable-destroy` job)
  - Cost guardrails: AWS Budgets alarm at $25/month, manual-tear-down runbook

- [ ] Branch protection note in `docs/demo-deploy.md`: deploy workflow runs
      from `main` only; PR plans use the read-only role

## Acceptance criteria

- Three workflow files validate via `actionlint .github/workflows/demo-*.yml`
- Neither workflow contains the strings `aws_access_key_id`,
  `AWS_SECRET_ACCESS_KEY`, or any `***`-shaped key
- `permissions:` block at workflow top sets `id-token: write` and
  `contents: read` (deploy adds `deployments: write`)
- The deploy and destroy workflows both gate on a typed-confirmation input
- `docs/demo-deploy.md` contains a runnable OIDC role-bootstrap snippet

## Verification

```bash
actionlint .github/workflows/demo-plan.yml \
            .github/workflows/demo-deploy.yml \
            .github/workflows/demo-destroy.yml

# No accidental secrets
! grep -RE "aws_access_key_id|AWS_SECRET_ACCESS_KEY" .github/workflows/

# OIDC opt-in present
grep -l "id-token: write" .github/workflows/demo-deploy.yml
```

## Do NOT

- Do NOT use a `repository_dispatch` event for deploy; require manual
  click + typed confirmation.
- Do NOT grant the plan role any write actions; it should only have
  `*:Describe*`, `*:Get*`, `*:List*`, plus S3 read on the state bucket.
- Do NOT skip the nightly destroy schedule; the demo will rack up cost
  if left running over a holiday.
- Do NOT allow plan/apply against PRs from forks (default OIDC trust scoping
  prevents this; document explicitly).

## Truth-hierarchy updates

- `docs/demo-deploy.md` canonical for the deploy workflow.
- `terraform/demo/README.md` (from prompt `05`) cross-links here.
- `README.md` (prompt `08`) gets the live demo URL once the first deploy
  succeeds.
