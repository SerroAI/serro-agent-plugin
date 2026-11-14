#!/bin/sh
# Tests that serro-hook records a Cursor program_join only when it succeeded.
# Run from the repo root: sh tests/serro-hook-joined.sh

hook=clients/cursor/scripts/serro-hook
cmp -s "$hook" clients/claude-code/scripts/serro-hook || { echo "FAIL: the two serro-hook copies differ"; exit 1; }

TMPDIR=$(mktemp -d); export TMPDIR
trap 'rm -rf "$TMPDIR"' EXIT
P=2137fc71-a969-460d-a579-72153a9c0350
A=527b90fb-b168-4aaf-ad07-f6c286612870
fails=0

# check <name> <want: recorded|skipped> <hook input JSON>
check() {
	rm -rf "$TMPDIR/serro-agent-plugin"
	printf '%s' "$3" | sh "$hook" joined cursor
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
check "agent_id null" skipped \
	"$start,$args,\"result_json\":\"{\\\"agent_id\\\":null}\"}"
check "no result_json" skipped \
	"$start,$args}"
check "another tool" skipped \
	"{\"conversation_id\":\"c1\",\"tool_name\":\"program_who\",$args,\"result_json\":\"{\\\"agent_id\\\":\\\"$A\\\"}\"}"

[ "$fails" -eq 0 ] || exit 1
