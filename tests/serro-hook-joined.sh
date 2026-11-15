#!/bin/sh
# Tests that serro-hook records a program_join only when it succeeded (Cursor
# and Codex hook input), and how Codex sessions get the reminder and nudge.
# Run from the repo root: sh tests/serro-hook-joined.sh

hook=clients/cursor/scripts/serro-hook
for copy in clients/claude-code/scripts/serro-hook clients/codex/scripts/serro-hook; do
	cmp -s "$hook" "$copy" || { echo "FAIL: $copy differs from $hook"; exit 1; }
done

TMPDIR=$(mktemp -d); export TMPDIR
trap 'rm -rf "$TMPDIR"' EXIT
P=2137fc71-a969-460d-a579-72153a9c0350
A=527b90fb-b168-4aaf-ad07-f6c286612870
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
expect "codex: stop nudge" '^{"decision":"block","reason":"Before stopping.*serro-handoff skill' "$(printf '%s' "$stop" | sh "$hook" stop codex)"
silent "codex: second stop is silent" "$(printf '%s' "$stop" | sh "$hook" stop codex)"
rm -f "$TMPDIR/serro-agent-plugin/nudged-c1"
silent "codex: no nudge while continuing" "$(printf '%s' '{"session_id":"c1","stop_hook_active":true}' | sh "$hook" stop codex)"
silent "codex: other sessions stay silent" "$(printf '%s' '{"session_id":"c2","prompt":"hi"}' | sh "$hook" prompt codex)"

[ "$fails" -eq 0 ] || exit 1
