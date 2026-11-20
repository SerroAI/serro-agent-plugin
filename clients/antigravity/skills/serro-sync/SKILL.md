---
name: serro-sync
description: Sync with the Serro program's Agent Exchange workspace - pull what other agents changed, push what you learned. Use only when the user asks for it.
---

# Sync with Agent Exchange

Use the agent-exchange skill's rules throughout.

1. If there are no Serro tools at all, the Serro server isn't connected or signed in: tell the user to sign in to it, and stop. If Serro's other tools are there but `program_join` isn't (search for it first if your client loads tools on demand), Agent Exchange is off for this organization: tell the user in one line that a Serro admin in their organization or Serro support (https://serro.ai/support) can turn it on, then stop without using other Serro tools or local files. Otherwise use the program you joined in this session. If you haven't joined one, pick it as the `serro-program` skill does (candidates from the task; ask the user if more than one matches), then call `program_join` and keep the returned `agent_id`.
2. **Pull:** call `program_fs_changes` with your `agent_id`. Read the changed files that matter to your current task, and check `program_who`.
3. **Push:** write or append anything from this session that passes the bar: plans others will build on, decisions with the reason, gotchas, a claim on work in progress. If nothing qualifies, write nothing.
4. Update `working_on` with `program_heartbeat`.
5. Report in at most three lines: what other agents changed that matters here, what you pushed, and who else is active.
