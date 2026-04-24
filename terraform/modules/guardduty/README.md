# guardduty

Account-scoped GuardDuty detector with toggleable feature set.

## What it creates

- `aws_guardduty_detector` (when `var.enable = true`) at `FIFTEEN_MINUTES` publishing frequency.
- One `aws_guardduty_detector_feature` per key in `var.features`.

## Controls satisfied (NIST SP 800-171 r2)

| Control | How |
|---|---|
| 3.14.6 | GuardDuty monitors VPC Flow Logs, DNS, CloudTrail for malicious activity. |
| 3.14.7 | Findings surface unauthorized use; consume into the SIEM / security ticketing flow. |

## Variables

- `enable` (bool, default `true`) — master switch.
- `finding_publishing_frequency` — `FIFTEEN_MINUTES` / `ONE_HOUR` / `SIX_HOURS`.
- `features` (map of bool) — defaults all features ON. Demo root sets `{ S3_DATA_EVENTS=false, EBS_MALWARE_PROTECTION=false, ... }` to control cost.

## Outputs

`detector_id`, `detector_arn`, `enabled_features`, `partition`. Detector outputs are `null` when `enable = false`.

## GovCloud notes

GuardDuty is available in GovCloud-West but supported feature set lags commercial. Validate `var.features` keys against the GovCloud-supported list before applying — the module passes feature names through unchanged.
