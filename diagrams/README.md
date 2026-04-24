# Diagrams

Mermaid diagrams describing the network topology and deployment pipeline.
The canonical artifact is [`network.md`](network.md); the demo deploy
pipeline is captured in the same file as a second diagram.

## Rendering

In VS Code: install the Markdown Preview Mermaid Support extension and
open `network.md` in preview.

CLI:

```bash
npx -y @mermaid-js/mermaid-cli -i diagrams/network.md -o /tmp/network.svg
```

## Convention

Any change to network topology, subnet tiering, or admin/user access
patterns in `terraform/modules/vpc/` or either root must update
[`network.md`](network.md) in the same PR. CI enforces this via the
mermaid-lint job in `.github/workflows/compliance-checks.yml` (added in
prompt 10) — that job only catches *syntax* drift, not stale topology;
reviewers must catch the latter.
