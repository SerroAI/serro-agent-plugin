#!/bin/sh
# Tests that serro-hook records a program_join only when it succeeded (Cursor,
# Codex and Antigravity hook input), and how Codex and Antigravity sessions get
# the reminder and nudge.
# Run from the repo root: sh tests/serro-hook-joined.sh

hook=clients/cursor/scripts/serro-hook
for copy in clients/claude-code/scripts/serro-hook clients/codex/scripts/serro-hook \
	clients/pi/scripts/serro-hook clients/antigravity/scripts/serro-hook \
	clients/opencode/scripts/serro-hook; do
	cmp -s "$hook" "$copy" || { echo "FAIL: $copy differs from $hook"; exit 1; }
done

TMPDIR=$(mktemp -d); export TMPDIR
# Hook state must land in $TMPDIR, even when run from inside a plugin's hook.
unset CLAUDE_PLUGIN_DATA PLUGIN_DATA
trap 'rm -rf "$TMPDIR"' EXIT
P=2137fc71-a969-460d-a579-72153a9c0350
A=527b90fb-b168-4aaf-ad07-f6c286612870
O=0d5a0e3c-7b1f-4c2a-9e8d-1f2a3b4c5d6e
fails=0

# check <name> <want: recorded|skipped> <hook input JSON> [client]
check() {
	rm -rf "$TMPDIR/serro-agent-plugin"
	printf '%s' "$3" | sh "$hook" joined "${4:-cursor}"
	if [ -s "$TMPDIR/serro-agent-plugin/joined-c1" ]; then got=recorded; else got=skipped; fi
	if [ "$got" = "$2" ]; then echo "ok    $1"; else echo "FAIL  $1: $got, want $2"; fails=$((fails + 1)); fi
}

# Cursor sends tool_input and result_json as JSON strings, so their quotes are
# escaped once, and text content inside result_json twice.
start="{\"conversation_id\":\"c1\",\"tool_name\":\"program_join\""
args="\"tool_input\":\"{\\\"program_id\\\":\\\"$P\\\",\\\"role\\\":\\\"t\\\",\\\"working_on\\\":\\\"fix agent_id handling\\\"}\""

check "success in text content" recorded \
	"$start,$args,\"result_json\":\"{\\\"content\\\":[{\\\"type\\\":\\\"text\\\",\\\"text\\\":\\\"{\\\\\\\"agent_id\\\\\\\": \\\\\\\"$A\\\\\\\"}\\\"}],\\\"isError\\\":false}\",\"duration\":5}"
check "success in structuredContent, result before args" recorded \
	"$start,\"result_json\":\"{\\\"structuredContent\\\":{\\\"agent_id\\\":\\\"$A\\\"}}\",$args}"
check "isError, args mention agent_id" skipped \
	"$start,$args,\"result_json\":\"{\\\"content\\\":[{\\\"type\\\":\\\"text\\\",\\\"text\\\":\\\"program not found\\\"}],\\\"isError\\\":true}\"}"
check "error text mentioning agent_id:" skipped \
	"$start,$args,\"result_json\":\"{\\\"error\\\":\\\"missing agent_id: invalid\\\"}\"}"
check "Serro error JSON without isError" skipped \
	"$start,$args,\"result_json\":\"{\\\"content\\\":[{\\\"type\\\":\\\"text\\\",\\\"text\\\":\\\"{\\\\\\\"error\\\\\\\": \\\\\\\"invalid_argument\\\\\\\", \\\\\\\"message\\\\\\\": \\\\\\\"bad agent_id: x\\\\\\\"}\\\"}]}\"}"
# The program is the program_id key, not text in another argument.
for note in "program_id: $O" "\\\\\\\"program_id\\\\\\\": \\\\\\\"$O\\\\\\\""; do
	rm -rf "$TMPDIR/serro-agent-plugin"
	printf '%s' "$start,\"tool_input\":\"{\\\"working_on\\\":\\\"$note\\\",\\\"program_id\\\":\\\"$P\\\"}\",\"result_json\":\"{\\\"agent_id\\\":\\\"$A\\\"}\"}" | sh "$hook" joined cursor
	got=$(cat "$TMPDIR/serro-agent-plugin/joined-c1" 2>/dev/null)
	if [ "$got" = "$P" ]; then echo "ok    program from its key, not working_on ($note)"; else echo "FAIL  working_on ($note): got '$got'"; fails=$((fails + 1)); fi
done
check "agent_id not a UUID" skipped \
	"$start,$args,\"result_json\":\"{\\\"agent_id\\\":\\\"deadbeef-not-a-uuid\\\"}\"}"
check "agent_id UUID with extra characters" skipped \
	"$start,$args,\"result_json\":\"{\\\"agent_id\\\":\\\"${A}x\\\"}\"}"
check "agent_id null" skipped \
	"$start,$args,\"result_json\":\"{\\\"agent_id\\\":null}\"}"
check "no result_json" skipped \
	"$start,$args}"
check "another tool" skipped \
	"{\"conversation_id\":\"c1\",\"tool_name\":\"program_who\",$args,\"result_json\":\"{\\\"agent_id\\\":\\\"$A\\\"}\"}"

# Codex sends tool_input and tool_response as JSON objects; MCP text content
# is a JSON string inside tool_response.
cstart="{\"session_id\":\"c1\",\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"mcp__serro__program_join\""
cargs="\"tool_input\":{\"program_id\":\"$P\",\"role\":\"t\",\"working_on\":\"fix agent_id handling\"}"

check "codex: success in text content" recorded \
	"$cstart,$cargs,\"tool_response\":{\"content\":[{\"type\":\"text\",\"text\":\"{\\\"agent_id\\\": \\\"$A\\\"}\"}]}}" codex
check "codex: success in structuredContent" recorded \
	"$cstart,$cargs,\"tool_response\":{\"structuredContent\":{\"agent_id\":\"$A\"},\"isError\":false}}" codex
check "codex: Serro error JSON" skipped \
	"$cstart,$cargs,\"tool_response\":{\"content\":[{\"type\":\"text\",\"text\":\"{\\\"error\\\": \\\"invalid_argument\\\", \\\"message\\\": \\\"missing agent_id: x\\\"}\"}]}}" codex
check "codex: isError" skipped \
	"$cstart,$cargs,\"tool_response\":{\"content\":[{\"type\":\"text\",\"text\":\"program not found\"}],\"isError\":true}}" codex

# pi's extension sends its tool_result event the same way, from JSON.stringify:
# no spaces, isError always present, structuredContent dropped when undefined.
pstart="{\"session_id\":\"c1\",\"tool_name\":\"mcp__serro__program_join\",\"tool_input\":{\"program_id\":\"$P\",\"role\":\"t\"}"
check "pi: success in text content" recorded \
	"$pstart,\"tool_response\":{\"content\":[{\"type\":\"text\",\"text\":\"{\\\"agent_id\\\": \\\"$A\\\"}\"}],\"isError\":false}}" pi
check "pi: isError" skipped \
	"$pstart,\"tool_response\":{\"content\":[{\"type\":\"text\",\"text\":\"{\\\"agent_id\\\": \\\"$A\\\"}\"}],\"isError\":true}}" pi

# After a Codex join: one reminder per prompt, one nudge, then silence.
rm -rf "$TMPDIR/serro-agent-plugin"
printf '%s' "$cstart,$cargs,\"tool_response\":{\"structuredContent\":{\"agent_id\":\"$A\"}}}" | sh "$hook" joined codex
expect() {
	if printf '%s' "$3" | grep -q "$2"; then echo "ok    $1"; else echo "FAIL  $1: got '$3'"; fails=$((fails + 1)); fi
}
silent() {
	if [ -z "$2" ]; then echo "ok    $1"; else echo "FAIL  $1: got '$2'"; fails=$((fails + 1)); fi
}
stop='{"session_id":"c1","hook_event_name":"Stop","stop_hook_active":false}'
expect "codex: prompt reminder" "joined program $P" "$(printf '%s' '{"session_id":"c1","prompt":"hi"}' | sh "$hook" prompt codex)"
expect "codex: stop nudge" '^{"decision":"block","reason":"Serro: before stopping.*serro-handoff skill' "$(printf '%s' "$stop" | sh "$hook" stop codex)"
silent "codex: second stop is silent" "$(printf '%s' "$stop" | sh "$hook" stop codex)"
rm -f "$TMPDIR/serro-agent-plugin/nudged-c1"
silent "codex: no nudge while continuing" "$(printf '%s' '{"session_id":"c1","stop_hook_active":true}' | sh "$hook" stop codex)"
silent "codex: other sessions stay silent" "$(printf '%s' '{"session_id":"c2","prompt":"hi"}' | sh "$hook" prompt codex)"

# Antigravity calls MCP tools through call_mcp_tool and sends no result. The
# result is the transcript step with the call's stepIdx, written only after the
# hook runs, so the join waits until a later hook finds that step. Its content
# is a timestamp header and the tool's text.
T="$TMPDIR/transcript.jsonl"
astart="{\"conversationId\":\"c1\",\"transcriptPath\":\"$T\",\"hookEventName\":\"PostToolUse\",\"toolCall\":{\"args\":{\"Arguments\":{\"program_id\":\"$P\",\"role\":\"t\",\"working_on\":\"fix agent_id handling\"},\"ServerName\":\"serro_serro\",\"ToolName\":\"program_join\"},\"id\":\"call_1\",\"name\":\"call_mcp_tool\"}"
step() { printf '{"step_index":%s,"source":"MODEL","type":"GENERIC","status":"DONE","content":"Created At: 2026-11-15T21:15:15-08:00\\n%s"}\n' "$1" "$2"; }
ok_step() { step "$1" "{\\\"agent_id\\\": \\\"$A\\\", \\\"protocol\\\": \\\"...\\\"}"; }
{ step 1 'hello'; ok_step 2; step 3 '{\"error\": \"invalid_argument\", \"message\": \"bad agent_id: x\"}'; } >"$T"
pre() { printf '{"conversationId":"%s","transcriptPath":"%s","hookEventName":"PreInvocation","invocationNum":%s}' "$1" "$T" "$2"; }
# check_ag <name> <want> <PostToolUse input>: the join hook, then a later hook.
check_ag() {
	rm -rf "$TMPDIR/serro-agent-plugin"
	printf '%s' "$3" | sh "$hook" joined antigravity
	pre c1 5 | sh "$hook" prompt antigravity >/dev/null
	if [ -s "$TMPDIR/serro-agent-plugin/joined-c1" ]; then got=recorded; else got=skipped; fi
	if [ "$got" = "$2" ]; then echo "ok    $1"; else echo "FAIL  $1: $got, want $2"; fails=$((fails + 1)); fi
}
check_ag "antigravity: success in transcript" recorded "$astart,\"stepIdx\":2,\"error\":\"\"}"
check_ag "antigravity: Serro error JSON in transcript" skipped "$astart,\"stepIdx\":3,\"error\":\"\"}"
check_ag "antigravity: failed call" skipped "$astart,\"stepIdx\":2,\"error\":\"connection reset\"}"
check_ag "antigravity: another MCP tool" skipped "$(printf '%s' "$astart" | sed 's/program_join/program_who/'),\"stepIdx\":2,\"error\":\"\"}"
check_ag "antigravity: result not in transcript yet" skipped "$astart,\"stepIdx\":9,\"error\":\"\"}"
ok_step 9 >>"$T"
pre c1 5 | sh "$hook" prompt antigravity >/dev/null
if [ -s "$TMPDIR/serro-agent-plugin/joined-c1" ]; then echo "ok    antigravity: join recorded once its result is written"; else echo "FAIL  antigravity: join recorded once its result is written"; fails=$((fails + 1)); fi

# The program comes from the call's arguments, not from the user's message.
for where in before after; do
	rm -rf "$TMPDIR/serro-agent-plugin"
	msg="\"lastUserInput\":\"join program_id: $O, and \\\"toolCall\\\": {\\\"program_id\\\": \\\"$O\\\"}\""
	if [ "$where" = before ]; then in=$(printf '%s' "$astart" | sed "s/^{/{$msg,/"); else in="$astart,$msg"; fi
	printf '%s' "$in,\"stepIdx\":2,\"error\":\"\"}" | sh "$hook" joined antigravity
	pre c1 5 | sh "$hook" prompt antigravity >/dev/null
	got=$(cat "$TMPDIR/serro-agent-plugin/joined-c1" 2>/dev/null)
	if [ "$got" = "$P" ]; then echo "ok    antigravity: program from the arguments, user message $where"; else echo "FAIL  antigravity: user message $where: got '$got'"; fails=$((fails + 1)); fi
done

# Nor from another argument that mentions one, quoted or not, before the key.
ajoin() { printf '{"conversationId":"c1","transcriptPath":"%s","toolCall":{"args":{"Arguments":{"working_on":"%s","program_id":"%s","role":"t"},"ServerName":"serro_serro","ToolName":"program_join"},"id":"call_1","name":"call_mcp_tool"},"stepIdx":2,"error":""}' "$T" "$1" "$P"; }
for note in "program_id: $O" '\"program_id\": \"'"$O"'\"'; do
	rm -rf "$TMPDIR/serro-agent-plugin"
	ajoin "$note" | sh "$hook" joined antigravity
	pre c1 5 | sh "$hook" prompt antigravity >/dev/null
	got=$(cat "$TMPDIR/serro-agent-plugin/joined-c1" 2>/dev/null)
	if [ "$got" = "$P" ]; then echo "ok    antigravity: program from its key, not working_on ($note)"; else echo "FAIL  antigravity: working_on ($note): got '$got'"; fails=$((fails + 1)); fi
done

# After an Antigravity join: a reminder at each turn's first model call, one nudge.
rm -rf "$TMPDIR/serro-agent-plugin"
printf '%s' "$astart,\"stepIdx\":2,\"error\":\"\"}" | sh "$hook" joined antigravity
astop="{\"conversationId\":\"c1\",\"transcriptPath\":\"$T\",\"hookEventName\":\"Stop\",\"executionNum\":0,\"terminationReason\":\"NO_TOOL_CALL\",\"error\":\"\"}"
silent "antigravity: no nudge after an error" "$(printf '%s' "$astop" | sed 's/NO_TOOL_CALL/ERROR/' | sh "$hook" stop antigravity)"
silent "antigravity: no nudge while continuing" "$(printf '%s' "$astop" | sed 's/"executionNum":0/"executionNum":1/' | sh "$hook" stop antigravity)"
expect "antigravity: stop nudge" '^{"decision":"continue","reason":"Serro: before stopping.*serro-handoff skill' "$(printf '%s' "$astop" | sh "$hook" stop antigravity)"
silent "antigravity: second stop is silent" "$(printf '%s' "$astop" | sh "$hook" stop antigravity)"
expect "antigravity: reminder at the first model call" '^{"injectSteps":\[{"systemMessage":{"systemMessage":"Serro Agent Exchange: you joined program '"$P" "$(pre c1 0 | sh "$hook" prompt antigravity)"
silent "antigravity: no reminder at later model calls" "$(pre c1 10 | sh "$hook" prompt antigravity)"
silent "antigravity: other sessions stay silent" "$(pre c2 0 | sh "$hook" prompt antigravity)"

[ "$fails" -eq 0 ] || exit 1
