# Network architecture

Two diagrams: the **CUI enclave network** (the architecture this repo
realizes) and the **demo deploy pipeline** (how the commercial-AWS demo
gets stood up).

> Same diagram, different deploy. The GovCloud root (`terraform/govcloud/`)
> and the commercial demo root (`terraform/demo/`) instantiate the same
> module shapes; only the partition, region, FIPS endpoint flags, and a
> handful of cost-control variables differ.

## CUI enclave network

```mermaid
flowchart LR
    %% ── External actors ─────────────────────────────────────────
    Admin["Admin laptop<br/>(authorized personnel)"]
    User["End user<br/>(MFA via IAM Identity Center)"]
    AWSAPIs[("AWS service APIs<br/>(FIPS endpoints<br/>in GovCloud)")]

    %% ── CUI authorization boundary ─────────────────────────────
    subgraph BOUNDARY["⚠ CUI Authorization Boundary"]
        direction TB

        subgraph IDENTITY["Identity plane"]
            IAM["IAM Identity Center<br/>+ IAM roles<br/>(MFA enforced)"]
            KMS["KMS CMKs<br/>logs · data · config<br/>(annual rotation)"]
        end

        subgraph LOGGING["Logging / monitoring plane"]
            CT["CloudTrail<br/>multi-region trail<br/>+ log file validation"]
            CTBUCKET[("S3 trail bucket<br/>KMS + Object Lock<br/>7-yr retention")]
            GD["GuardDuty<br/>+ EKS / S3 / RDS<br/>malware protection"]
            CFG["AWS Config<br/>+ NIST 800-171<br/>conformance pack"]
            CWL["CloudWatch Logs<br/>+ metric filters<br/>(root login, IAM, MFA)"]
        end

        subgraph VPC["VPC (multi-AZ)"]
            direction TB

            subgraph PUB["Public subnets (per AZ)"]
                ALB["Application Load Balancer<br/>(TLS 1.2+ only)"]
            end

            subgraph PRIV["Private / app subnets (per AZ)"]
                APP["Workloads<br/>(no public IPs)"]
            end

            subgraph DATA["Data subnets (per AZ)"]
                RDS[("RDS<br/>encrypted at rest<br/>via KMS")]
                S3GW[("S3 gateway endpoint")]
                EFS[("EFS<br/>encrypted at rest")]
            end

            subgraph ENDPOINTS["Interface VPC endpoints (FIPS where supported)"]
                EP_SSM["ssm · ssmmessages · ec2messages"]
                EP_KMS["kms"]
                EP_LOGS["logs · monitoring"]
                EP_STS["sts · ec2"]
            end

            FLOW["VPC Flow Logs<br/>→ CloudWatch (365 d)"]
        end
    end

    %% ── Access patterns ─────────────────────────────────────────
    Admin -- "TLS 1.2+ &<br/>SSM Session Manager<br/>(no inbound SSH)" --> EP_SSM
    User -- "HTTPS (TLS 1.2+)" --> ALB
    ALB --> APP
    APP --> RDS
    APP --> EFS
    APP --> S3GW

    %% ── Service plane wiring ────────────────────────────────────
    APP -.uses.-> EP_KMS
    APP -.logs.-> EP_LOGS
    EP_KMS -.-> KMS
    EP_LOGS -.-> CWL
    EP_SSM -.via AWS backbone.-> AWSAPIs
    EP_STS -.-> AWSAPIs

    %% ── Audit / monitoring ──────────────────────────────────────
    CT -.records all API calls.-> CTBUCKET
    CTBUCKET -.encrypted by.-> KMS
    GD -.observes.-> VPC
    CFG -.records.-> VPC
    FLOW -.-> CWL

    %% ── Identity flow ───────────────────────────────────────────
    IAM -.federates.-> Admin
    IAM -.federates.-> User
    IAM -.assumes roles in.-> APP

    classDef boundary fill:#fff5e6,stroke:#cc6600,stroke-width:3px,stroke-dasharray:5 5;
    classDef public fill:#e8f4ff,stroke:#3a7ab8;
    classDef private fill:#eaf5ea,stroke:#2f7d32;
    classDef data fill:#fde8e8,stroke:#c0392b;
    classDef logging fill:#f5e8ff,stroke:#7b3fa3;
    classDef identity fill:#fff9d6,stroke:#a18800;

    class BOUNDARY boundary
    class PUB public
    class PRIV private
    class DATA data
    class LOGGING,CT,CTBUCKET,GD,CFG,CWL logging
    class IDENTITY,IAM,KMS identity
```

### What crosses the boundary

| Direction | Traffic | Mechanism |
|---|---|---|
| Admin → enclave | Privileged shell access | **AWS SSM Session Manager only** (no bastion, no inbound SSH); admin laptops authenticate via IAM Identity Center with MFA |
| User → enclave | Application traffic | HTTPS (TLS 1.2+) to ALB; user identity federated via IAM Identity Center / Cognito with MFA |
| Enclave → AWS APIs | Service control plane | Interface / Gateway VPC endpoints (FIPS endpoints in GovCloud); no NAT, no internet egress required for AWS service traffic |
| Enclave → external SaaS | (intentionally restricted) | Out-of-scope for this reference; consumer wires explicit egress through a managed proxy if required |

### What this diagram does NOT show

- **Workload modules** — the green "Workloads" box is a placeholder; consumers attach their own ECS / EKS / EC2 / Lambda definitions
- **Org-trail / log archive account** — for multi-account deployments the CloudTrail bucket lives in a separate logging account; this diagram assumes single-account for clarity
- **SIEM forwarding** — CloudWatch Logs subscription filters → external SIEM are a consumer concern
- **DR / cross-region replication** — single-region for diagram clarity; real CUI deployments often add cross-region S3 replication for the trail bucket

## Demo deploy pipeline

```mermaid
flowchart LR
    Dev["Maintainer<br/>(workflow_dispatch)"]
    GHA["GitHub Actions<br/>demo-deploy.yml"]
    OIDC["GitHub OIDC provider<br/>(in AWS account)"]
    Role["IAM role<br/>demo-deploy<br/>(scoped to repo + main branch)"]
    TF["terraform apply<br/>terraform/demo/"]
    AWS[("AWS commercial<br/>us-east-1")]
    URL["Public demo URL<br/>(Lambda Function URL)"]
    Cron["Nightly schedule<br/>demo-destroy.yml"]

    Dev -- "type DEPLOY to confirm" --> GHA
    GHA -- "AssumeRoleWithWebIdentity" --> OIDC
    OIDC -- "issues short-lived creds" --> Role
    GHA -- "uses creds" --> TF
    TF --> AWS
    AWS --> URL

    Cron -. "07:00 UTC" .-> GHA
    Cron -. "terraform destroy" .-> AWS

    classDef external fill:#f5f5f5,stroke:#888;
    classDef ci fill:#e8f0ff,stroke:#3a6fcc;
    classDef aws fill:#fff5e6,stroke:#cc6600;
    class Dev,Cron external
    class GHA,OIDC ci
    class Role,TF,AWS,URL aws
```

The demo deploy pipeline uses **GitHub Actions OIDC** federation — there
are no long-lived AWS access keys in the repo or in CI. Both `deploy` and
`destroy` workflows require a typed-confirmation input (`DEPLOY` /
`DESTROY`); destroy also runs nightly on a schedule to bound cost. Full
operator guide: [`docs/demo-deploy.md`](../docs/demo-deploy.md) (added in
prompt 09).
