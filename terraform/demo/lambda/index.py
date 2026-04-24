def handler(event, context):
    html = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>CMMC L2 Enclave Demo</title>
  <style>
    body { font-family: -apple-system, system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; color: #1d1d1f; }
    .banner { background: #b91c1c; color: white; padding: 1rem; border-radius: 8px; font-weight: 600; }
    code { background: #f4f4f5; padding: 0.1rem 0.4rem; border-radius: 4px; }
    a { color: #2563eb; }
  </style>
</head>
<body>
  <div class="banner">
    DEMO ENVIRONMENT &mdash; NOT A CUI ENCLAVE. Do not upload real CUI.
  </div>
  <h1>CMMC Level 2 / NIST SP 800-171 r2 Reference Architecture</h1>
  <p>
    You are looking at the <strong>commercial-AWS demo half</strong> of a
    reference architecture for hosting Controlled Unclassified Information
    (CUI) in AWS GovCloud. This page proves the Terraform actually deploys.
    The CUI-grade configuration lives in <code>terraform/govcloud/</code>
    and is validate-clean only &mdash; we do not have a GovCloud account
    here to apply it against.
  </p>
  <h2>What this demo deploys (commercial AWS)</h2>
  <ul>
    <li>3-tier VPC with VPC endpoints (no NAT to keep cost low)</li>
    <li>2 KMS CMKs (logs, data) with annual rotation</li>
    <li>IAM password policy + Access Analyzer</li>
    <li>CloudTrail &rarr; KMS-encrypted, Object-Locked S3 + CloudWatch Logs</li>
    <li>This Lambda + Function URL serving you this page</li>
  </ul>
  <h2>Where to look next</h2>
  <ul>
    <li><a href="https://github.com/mikejmckinney/cmmc-level2-aws-enclave-reference">Repository</a></li>
    <li><a href="https://github.com/mikejmckinney/cmmc-level2-aws-enclave-reference/blob/main/diagrams/network.md">Network diagram</a></li>
    <li><a href="https://github.com/mikejmckinney/cmmc-level2-aws-enclave-reference/blob/main/ssp/SSP.md">SSP skeleton</a></li>
    <li><a href="https://github.com/mikejmckinney/cmmc-level2-aws-enclave-reference/blob/main/controls/nist-800-171-mapping.csv">110-control mapping</a></li>
  </ul>
  <hr>
  <p><em>Auto-destroyed nightly. If this URL 404s, the nightly cleanup ran.</em></p>
</body>
</html>"""
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/html; charset=utf-8",
            "Cache-Control": "no-store",
        },
        "body": html,
    }
