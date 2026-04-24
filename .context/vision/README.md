# Vision

> Design artifacts for `cmmc-level2-aws-enclave-reference`.

## Where the diagrams live

The canonical network architecture diagram is **not** in this directory.
It lives at [`diagrams/network.md`](../../diagrams/network.md) (created
in [`.github/prompts/02-scaffold-and-architecture.md`](../../.github/prompts/02-scaffold-and-architecture.md))
because it doubles as a user-facing artifact linked from the README and
SSP, not just an internal vision sketch.

This `vision/` directory is the right home for:

- Early architecture explorations that didn't make it into `diagrams/`
- ADR-supporting sketches (per
  [`docs/decisions/`](../../docs/decisions/))
- Future-state diagrams (e.g., a Phase 8 workload-module library)

## Conventions

- Use Mermaid for any diagram that would otherwise be a PNG; PNGs are
  acceptable only when Mermaid can't express the needed shape.
- Cross-link from any diagram in this directory to its triggering ADR or
  prompt file.
- Diagrams that change boundary, subnetting, or access patterns require a
  matching update to `diagrams/network.md` and the SSP §2 / §3.
