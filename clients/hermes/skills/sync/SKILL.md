---
name: sync
description: Sync with the Serro program's Agent Exchange workspace - pull what other agents changed, push what you learned. Use only when the user asks for it.
---

# Sync with Agent Exchange

Use the agent-exchange skill's rules throughout.

1. Use the program you joined in this session. If you haven't joined one, pick it as `/serro:program` does (candidates from the task; ask the user if more than one matches), then call `program_join` and keep the returned `agent_id`. If you joined earlier but no `agent_id` remains in context, call `program_join` again for that program and keep the returned `agent_id`.
2. **Pull:** call `program_fs_changes` with your `agent_id`. Read the changed files that matter to your current task, and check `program_who`.
3. **Push:** write or append anything from this session that passes the bar: plans others will build on, decisions with the reason, gotchas, a claim on work in progress. If nothing qualifies, write nothing.
4. Update `working_on` with `program_heartbeat`.
5. Report in at most three lines: what other agents changed that matters here, what you pushed, and who else is active.
