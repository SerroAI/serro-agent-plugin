---
name: serro-handoff
description: Hand off unfinished work on a Serro program through Agent Exchange, so another agent or person can pick it up. Use when the user asks for a handoff, or when you are stopping with Agent Exchange work unfinished.
---

# Hand off through Agent Exchange

Task (optional): the task the user named when asking for this, if any.

1. Use the program you joined in this session. If you haven't joined one, ask the user which program the work belongs to, then join it.
2. Pick the path. If the work has a task folder, use `work/<task>/handoff.md`. Otherwise create `handoffs/<YYYY-MM-DD>-<short-topic>.md` with `if_version=0`. If that file exists, read it and update it with compare-and-swap.
3. Write it for someone with no context, in under 40 lines:
   - **Goal:** what this work is for, with links to the ticket or plan.
   - **Done:** what is finished, with PRs, branches and commits.
   - **Open:** what is left, in order, with the next concrete step first.
   - **Where things are:** files, branches, environments, datasets.
   - **Gotchas:** anything that cost you time.
4. Append one line to `board.md` pointing to the handoff.
5. Set `working_on` to "handed off: <topic>" with `program_heartbeat`. If the user is ending the session, call `program_leave`.
6. Tell the user the handoff's path.
