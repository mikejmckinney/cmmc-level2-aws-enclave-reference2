# Demo deploy / destroy operator guide

This is the runbook for the public commercial-AWS demo at
[`terraform/demo/`](../terraform/demo/). The CUI-grade GovCloud root
([`terraform/govcloud/`](../terraform/govcloud/)) is **not** wired to
GitHub Actions and is never deployed from CI in this repo.

## Prerequisites

1. A dedicated commercial AWS account (use a sandbox; do not co-locate with prod).
2. AWS Region selected (`us-east-1` recommended for cost).
3. **AWS Budgets alarm** at $25/month in the demo account (cap exposure if the nightly destroy ever fails).
4. An S3 bucket for remote Terraform state in that account; record its name.
5. A GitHub repository environment named `demo` with an environment protection rule (require reviewers if your org policy requires it).

## OIDC role bootstrap

Run this **once** in the demo AWS account. It creates the GitHub OIDC
provider and two roles: a read-only role for PR plans and a deploy role
for `apply`/`destroy`. Adjust `<ORG>/<REPO>` to match your fork.

```hcl
# bootstrap.tf — apply with admin credentials, then commit nothing.
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.40" }
  }
}

provider "aws" { region = "us-east-1" }

locals {
  repo = "<ORG>/<REPO>"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---- Read-only role for PR plans (any branch / PR) ----
data "aws_iam_policy_document" "plan_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan_readonly" {
  name               = "cmmc-demo-plan-readonly"
  assume_role_policy = data.aws_iam_policy_document.plan_assume.json
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ---- Deploy role: scoped to main branch + workflow_dispatch only ----
data "aws_iam_policy_document" "deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.repo}:ref:refs/heads/main",
        "repo:${local.repo}:environment:demo",
      ]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "cmmc-demo-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_assume.json
}

# Demo is small — admin in a dedicated sandbox is the simplest scoping.
# If your account is not exclusively for this demo, replace with a
# least-privilege policy covering only the resources the demo creates.
resource "aws_iam_role_policy_attachment" "deploy_admin" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "plan_role_arn"   { value = aws_iam_role.plan_readonly.arn }
output "deploy_role_arn" { value = aws_iam_role.deploy.arn }
```

`AdministratorAccess` is acceptable here **only** because the demo account
is dedicated and ephemeral. For a shared account, write a least-privilege
policy.

## Required GitHub configuration

In the repository settings:

| Type | Name | Value |
|---|---|---|
| Secret | `AWS_PLAN_ROLE_ARN` | ARN of `cmmc-demo-plan-readonly` |
| Secret | `AWS_DEPLOY_ROLE_ARN` | ARN of `cmmc-demo-deploy` |
| Secret | `AWS_REGION` | e.g. `us-east-1` |
| Secret | `AWS_ACCOUNT_ID` | demo account ID |
| Variable | `DEMO_STATE_BUCKET` | name of the S3 state bucket |
| Environment | `demo` | (with optional protection rules) |

## Workflows

| Workflow | Trigger | Role | Notes |
|---|---|---|---|
| [`demo-plan.yml`](../.github/workflows/demo-plan.yml) | PR touching `terraform/demo/**` or `terraform/modules/**` | `cmmc-demo-plan-readonly` | Posts plan summary as a PR comment. Read-only. Forks: `pull_request_target` is **not** used; OIDC trust on `pull_request` already prevents fork PRs from assuming the role. |
| [`demo-deploy.yml`](../.github/workflows/demo-deploy.yml) | `workflow_dispatch` only, requires typed `DEPLOY` confirmation | `cmmc-demo-deploy` | `if: github.ref == 'refs/heads/main'` — runs only from `main`. |
| [`demo-destroy.yml`](../.github/workflows/demo-destroy.yml) | `workflow_dispatch` (typed `DESTROY`) **and** nightly cron `0 7 * * *` | `cmmc-demo-deploy` | Concurrency-grouped with deploy so they cannot interleave. |

## Disabling the nightly destroy

If you need the demo to persist over a holiday or roadshow:

1. Edit `.github/workflows/demo-destroy.yml` and comment out the `schedule:` block in a branch.
2. Open a PR titled `chore: pause demo nightly destroy through <date>`.
3. Merge to `main`. Set a calendar reminder to revert.

The cost cap from the AWS Budgets alarm still applies; if it fires, run the workflow manually with `confirm=DESTROY`.

## Manual teardown runbook

If a workflow is stuck or state is corrupt:

1. From a workstation with admin in the demo account:
   ```bash
   cd terraform/demo
   aws sso login   # or otherwise assume admin
   terraform init -backend-config="bucket=<state bucket>" \
                  -backend-config="key=cmmc-level2-aws-enclave-reference/demo/terraform.tfstate" \
                  -backend-config="region=<region>"
   terraform destroy -auto-approve
   ```
2. If `destroy` fails, inspect the named resources in the AWS console and remove manually:
   - Lambda function `cmmc-demo-page` and Function URL
   - CloudTrail `cmmc-demo-trail` and S3 bucket `cmmc-demo-cloudtrail-<account>` (Object Lock retention may require the AWS API not console)
   - Config delivery bucket (if you enabled Config in the demo)
   - VPC, subnets, IGW, VPC endpoints
   - KMS keys (will go to 7-day deletion window — that's fine)
3. Confirm spend in AWS Cost Explorer over the next 24h.
