# config

AWS Config recorder + delivery channel + (optional) NIST 800-171 conformance pack.

## What it creates

- KMS-encrypted S3 delivery bucket (versioned, public-access blocked, deny-non-TLS).
- IAM role for the Config service with the managed `AWS_ConfigRole` attached (partition-aware ARN).
- `aws_config_configuration_recorder` recording all supported resources (global resources toggled by `include_global_resource_types`).
- `aws_config_delivery_channel` with `Six_Hours` snapshot frequency by default.
- `aws_config_configuration_recorder_status` that enables the recorder.
- *Optional* `aws_config_conformance_pack` named `Operational-Best-Practices-for-NIST-800-171` when `var.conformance_pack_template_body` is supplied.

## Conformance pack template

The `Operational-Best-Practices-for-NIST-800-171.yaml` template is **not vendored** in this repo — download it from AWS's [aws-config-rules conformance-pack-templates](https://github.com/awslabs/aws-config-rules/tree/master/aws-config-conformance-packs) repository (Apache-2.0 licensed) and pass the file contents:

```hcl
module "config" {
  source                         = "../modules/config"
  kms_key_arn                    = module.kms.key_arns["audit"]
  conformance_pack_template_body = file("${path.root}/conformance/nist-800-171.yaml")
}
```

## Controls satisfied (NIST SP 800-171 r2)

| Control | How |
|---|---|
| 3.4.1 | Config records configuration baselines for every supported resource. |
| 3.4.2 | Conformance pack rules detect drift from the NIST 800-171 baseline. |
| 3.14.1 | Config rules continuously monitor for unauthorized changes. |

## Multi-region note

Set `include_global_resource_types = true` on **exactly one region per account** to avoid duplicate IAM events.

## Outputs

`recorder_name`, `delivery_channel_name`, `delivery_bucket_name`, `delivery_bucket_arn`, `config_role_arn`, `conformance_pack_arn` (null when no template supplied), `partition`.
