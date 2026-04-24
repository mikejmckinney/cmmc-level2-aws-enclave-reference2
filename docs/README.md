# Documentation

> Supporting documentation for `cmmc-level2-aws-enclave-reference`. For
> canonical project direction, see [`.context/`](../.context/) (truth
> hierarchy: `.context/**` > `docs/**` > codebase).

## Layout

| Path | Purpose |
|---|---|
| [`FAQ.md`](FAQ.md) | Project FAQ |
| [`decisions/`](decisions/) | ADRs (Architecture Decision Records) |
| [`postmortems/`](postmortems/) | Incident / mistake postmortems |
| [`guides/`](guides/) | How-to guides for agents and contributors |
| [`reference/`](reference/) | Reference material (NIST, CMMC, AWS) |
| [`research/`](research/) | Analyst research artifacts (read-only for other roles) |
| `demo-deploy.md` | Demo deploy workflow operator guide (created in prompt 09) |

## Conventions

- Anything that constrains behavior repo-wide belongs in
  [`.context/rules/`](../.context/rules/), not here.
- Anything that records a decision belongs in
  [`decisions/`](decisions/) using
  [`decisions/adr-template.md`](decisions/adr-template.md).
- Anything that's user-facing marketing or quick-start belongs in the
  root [`README.md`](../README.md), not here.
