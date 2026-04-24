please write a series of prompt files or issues using the issue templates in the attached repo that i will give to an ai agent like copilot or claude code to create the following project: 



Name: cmmc-level2-aws-enclave-reference



A reference architecture for a minimal CUI enclave in AWS GovCloud, with a partial Terraform implementation. Include:



Mermaid network diagram showing boundary, VPC, subnet, and access patterns

Terraform modules for the core components (VPC, IAM baseline, KMS, CloudTrail, GuardDuty, Config) with clear gaps where client-specific work is needed

A spreadsheet (CSV in the repo) mapping all 110 NIST 800-171 controls to specific AWS services and Terraform resources, with columns for "addressed by this repo," "requires client config," "organizational control"

An example SSP skeleton (markdown) with 5-10 of the 110 control implementation statements fully written out, and the rest as TODO stubs

README that cites the November 10, 2026 Phase 2 deadline Greypike and explains why waiting is expensive


In addition to the above, I would like to be able to deploy a live demo to showcase to clients.  the demo most likely wont be on aws gov cloud due to restricted access so im thinking we could make another set of resources that would deploy to aws non-gov for the sake of having a live demo.  what are your thoughts and what changes would need to be make to make it work