<!-- `provenance.yml` asks a body to open by declaring the phase that authorized the work. A plan
     path belongs to whoever is calling this repository and does not travel here, so a contribution
     to this repository states what brought it into existence instead — see USAGE.md step 3. -->

```json
{
  "plan": null,
  "phase": null,
  "reason": "<what brought this into existence: a dependency bump, a failing check, a direct request>"
}
```

## What changed and why

## Checklist

- [ ] Read [CONTRIBUTING.md](../CONTRIBUTING.md), and if this changes a workflow input — its name,
      whether it is required, or its default — said so above and kept the old name working.
- [ ] The declaration above says what authorized this, with the placeholder replaced.
- [ ] `npm test` and `npm run typecheck` pass locally.
- [ ] `./scripts/no-entity-leak.sh` and `./scripts/no-entity-leak.test.sh` pass locally.
- [ ] If this "fixes" one of the deliberate designs in
      [ARCHITECTURE.md](../ARCHITECTURE.md#5-four-things-that-look-like-bugs), argued with the
      reason rather than only changing the code.
- [ ] A changed input is documented in [REFERENCE.md](../REFERENCE.md).
- [ ] Anything a caller would notice has an entry under `[Unreleased]` in
      [CHANGELOG.md](../CHANGELOG.md).
