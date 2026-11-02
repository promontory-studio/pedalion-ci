#!/usr/bin/env bash
# A pull request body must open by declaring the phase that authorized the work -- a fenced `json`
# block, which `doctrine/git.md` in the shared protocol states and which a work-state ledger reads to
# join a landed phase to the commit that landed it.
#
# Nothing checked it. The ledger reports an absent declaration as *undetermined* rather than refusing
# it, so a body written without one costs nothing when it is written and costs a wrong answer later:
# the fallback key is the head branch, and the cleanup rule deletes the branch at the merge. A phase
# that shipped then reads as a phase nobody started. This refuses the pull request instead, which is
# the only moment the body is still somebody's to fix.
#
# Usage: pr-provenance.sh [body-file]          (default: the body on stdin)
#
#   PR_AUTHOR        login that opened the pull request       (default: empty)
#   PR_AUTHOR_TYPE   the forge's own `user.type` for it       (`Bot` is exempt -- see below)
#   EXEMPT_AUTHORS   comma-separated logins exempt whatever their type
#
# **The bot exemption is a declared hole, not an oversight.** A dependency bot composes its own body
# and cannot be taught a form, so requiring one of it would refuse every bump -- and a gate that
# refuses every bump is switched off within a day. What the exemption costs is that an automated pull
# request joins to no phase, which is the right answer for it: no phase authorized it. The `null`
# form below is what a *person* writes in that same case, and the difference is that a person can.
set -uo pipefail

if [ -n "${1:-}" ]; then body=$(cat -- "$1"); else body=$(cat); fi

author=${PR_AUTHOR:-} author_type=${PR_AUTHOR_TYPE:-} exempt=${EXEMPT_AUTHORS:-}

if [ "$author_type" = "Bot" ]; then
  echo "pr-provenance: ${author:-this author} is a bot, and a declaration is a person's to write. Nothing to check."
  exit 0
fi
if [ -n "$author" ] && printf '%s' "$exempt" | tr ',' '\n' | grep -qxF "$author"; then
  echo "pr-provenance: $author is exempt by the caller's own declaration. Nothing to check."
  exit 0
fi

# Only the FIRST fenced `json` block is read, and the carriage returns go first: the forge stores
# what the author sent, and a body typed into the web form arrives CRLF, so the fence line reads
# "```json\r" and matches nothing. Both of those are the reader's tolerances rather than this gate's
# -- a gate stricter than the reader it protects refuses bodies that reader would have understood,
# which is why the position of the block is not checked either, only that it is the first one.
verdict=$(printf '%s' "$body" | jq -Rsr '
  def decl:
    ((. // "") | gsub("\r"; "") | split("\n")) as $l
    | ($l | index("```json")) as $i
    | if $i == null then null
      else ($l[$i+1:] | index("```")) as $j
        | if $j == null then null
          else (try ($l[$i+1:$i+1+$j] | join("\n") | fromjson) catch null)
          end
      end;
  def filled($d; $k): ($d | has($k)) and (($d[$k] | type) == "string") and ($d[$k] | test("\\S"));
  decl as $d
  | if $d == null then
      "FAIL\tthe body does not open with a fenced `json` block that parses"
    elif ($d | type) != "object" then
      "FAIL\tthe first fenced `json` block is a \($d | type), not an object"
    elif ($d | has("plan") | not) then
      "FAIL\tthe declaration has no `plan` key -- `null` where no plan authorized this"
    elif ($d | has("phase") | not) then
      "FAIL\tthe declaration has no `phase` key -- `null` where no phase authorized this"
    elif ($d.phase == null) or (($d.phase | tostring) | test("\\S") | not) then
      if filled($d; "reason") then
        "OK\tno phase authorized this, and it says what brought it into existence: \($d.reason)"
      else
        "FAIL\t`\"phase\": null` carries a non-empty `reason` -- what brought this pull request into existence"
      end
    else
      ( ["plan", "pre_sha", "verify", "undo", "door"] | map(select(filled($d; .) | not)) ) as $gaps
      | if ($gaps | length) > 0 then
          "FAIL\tphase \($d.phase | tostring) is declared, but \($gaps | join(", ")) missing or empty -- all six fields are fixed when the phase is approved"
        else
          "OK\tphase \($d.phase | tostring) of \($d.plan)"
        end
    end')

printf '%s\n' "${verdict#*$'\t'}" | sed "s/^/pr-provenance: /"
case $verdict in
  OK*) exit 0 ;;
esac

cat <<'HELP'

The body opens with the phase that authorized the work, and quotes that phase's executive summary
beneath it. Six fields, every one of them fixed when the phase was approved:

    ```json
    {
      "plan":    "planning/<repo>/<path>.md",
      "phase":   "<the phase's label>",
      "pre_sha": "<the commit this phase rewinds to>",
      "verify":  "<the phase's Verify row, verbatim>",
      "undo":    "<the phase's Undo row, verbatim>",
      "door":    "<the phase's Door row, verbatim>"
    }
    ```

A pull request that no phase authorized declares that, and says what brought it into existence
instead -- a dependency bump, a failing check, asked for directly:

    ```json
    { "plan": null, "phase": null, "reason": "<why this exists>" }
    ```

Nothing about how the work is *doing* goes in the block: whether it has landed, whether its checks
pass, how old it is. A body is written once and never revised, so a status copied into one reads as
current for as long as the pull request exists.
HELP
exit 1
