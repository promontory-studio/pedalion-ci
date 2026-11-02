#!/usr/bin/env bash
# Proves the check can fail, and in which directions. A gate that cannot refuse anything reads
# exactly like a gate with nothing to catch, so every assertion below has a body that it turns down
# and a body it lets through, and the two differ in one thing.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0 fail=0

check() { # name expected-exit body [env assignments...]
  local name=$1 expect=$2 body=$3; shift 3
  local got
  printf '%s' "$body" | env "$@" "$here/pr-provenance.sh" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$expect" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $name (exit $got, wanted $expect)"
  fi
}

six='```json
{
  "plan": "planning/thing/a-plan.md",
  "phase": "2",
  "pre_sha": "0123456",
  "verify": "the suite passes",
  "undo": "revert the merge",
  "door": "two-way"
}
```

## What this changes'

none='```json
{ "plan": null, "phase": null, "reason": "a dependency bump" }
```'

check "a full declaration passes"                 0 "$six"
check "the no-phase form with a reason passes"    0 "$none"
check "a body with no fence at all is refused"    1 "## What this changes, and why"
check "a fence that is not \`json\` is refused"   1 '```
{ "plan": null, "phase": null, "reason": "x" }
```'
check "an unparseable fence is refused"           1 '```json
{ "plan": null, "phase": null,
```'
check "a non-object fence is refused"             1 '```json
["planning/thing/a-plan.md", "2"]
```'
check "a missing \`plan\` key is refused"         1 '```json
{ "phase": null, "reason": "a dependency bump" }
```'
check "a missing \`phase\` key is refused"        1 '```json
{ "plan": null, "reason": "a dependency bump" }
```'
check "no phase and no reason is refused"         1 '```json
{ "plan": null, "phase": null }
```'
check "no phase and an empty reason is refused"   1 '```json
{ "plan": null, "phase": null, "reason": "   " }
```'
check "a declared phase with no \`undo\` is refused" 1 "${six/\"undo\": \"revert the merge\",/}"
check "a declared phase with an empty \`verify\` is refused" 1 "${six/the suite passes/}"
check "a declared phase with a null \`plan\` is refused" 1 "${six/\"planning\/thing\/a-plan.md\"/null}"

# The reader's own two tolerances, which this gate inherits rather than tightens.
check "a CRLF body passes"                        0 "$(printf '%s' "$six" | sed 's/$/\r/')"
check "a declaration below prose passes"          0 "Some prose first.

$six"
check "a later \`json\` fence is not read"        1 "## What this changes

\`\`\`json
{ \"an\": \"example\" }
\`\`\`

$none"

# The author exemptions. The first is the declared hole; the second is the caller's own.
check "a bot needs no declaration"                0 "Bumps a thing." PR_AUTHOR_TYPE=Bot PR_AUTHOR='dependabot[bot]'
check "a person does"                             1 "Bumps a thing." PR_AUTHOR_TYPE=User PR_AUTHOR=someone
check "an exempt login needs none"                0 "Bumps a thing." PR_AUTHOR_TYPE=User PR_AUTHOR=someone EXEMPT_AUTHORS=other,someone
check "a login not on that list does"             1 "Bumps a thing." PR_AUTHOR_TYPE=User PR_AUTHOR=someone EXEMPT_AUTHORS=other

echo "pr-provenance: $pass passed, $fail failed"
[ "$fail" = 0 ]
