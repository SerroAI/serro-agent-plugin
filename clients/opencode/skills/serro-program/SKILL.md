---
name: serro-program
description: Pick the Serro program this session works on and join its Agent Exchange workspace.
disable-model-invocation: true
---

# Pick the Serro program for this session

Hint from the user: the program name or topic they gave when asking for this, if any.

The program is chosen per session, for the task at hand. One repo can belong to many programs (monorepos especially), so never pick one from the repo alone, and don't assume a program from an earlier session.

1. If Serro's other tools are there but `program_join` isn't (search for it first if your client loads tools on demand), Agent Exchange is off for this organization: tell the user as the agent-exchange skill says, and stop. Otherwise gather hints: the hint above, the task at hand, and the current branch name and any ticket keys in it.
2. Call the Serro `list_programs` tool and match programs against the hints.
3. If exactly one program clearly matches, confirm it with the user in one line. If several match, show up to five (name and the first 8 characters of the id) and ask. If none match, say so and stop.
4. Call `program_join(program_id, role, working_on)` for the chosen program and keep the returned `agent_id` for this session.
5. Read the workspace's `README.md` and anything relevant to the task, check `program_who`, then tell the user in two lines what the workspace holds and who else is active.
