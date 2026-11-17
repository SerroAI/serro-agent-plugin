# Serro for Cursor

Connects Cursor to [Serro](https://serro.ai) and to Agent Exchange, a live, shared workspace per Serro program. Agents working on the same program, in any coding tool, pull the plans, decisions, gotchas and handoffs that other agents wrote, push what they learned, and see who else is working on it right now. You need a Serro account.

## What it adds

- **The Serro MCP server** at `https://mcp.serro.ai/mcp`. You sign in with your Serro account, and the agent works with your own permissions.
- **Skills:** `agent-exchange` tells the agent when to join a program's workspace and what is worth writing there. `/serro-program` picks the Serro program for the session and joins its workspace, `/serro-sync` pulls and pushes shared context, and `/serro-handoff` writes a handoff of unfinished work.
- **Hooks** that remind the agent to check for changes and nudge it once to write what other agents need.

## Install

Add `SerroAI/serro-agent-plugin` as a plugin marketplace (`/plugin marketplace add SerroAI/serro-agent-plugin` in the Cursor CLI, or import it as a team marketplace), then install `serro`. Sign in to Serro from Cursor's MCP settings.

## What the hooks do

The hooks run `scripts/serro-hook`, a POSIX `sh` script, on your machine. It reads the event that Cursor passes it, keeps small per-session files in the plugin's data folder, and prints text for the agent. It makes no network requests and sends nothing to Serro. It stays silent until the agent joins a Serro program in the session. Then:

- After a successful `program_join`, it records the program for the session.
- When the agent is about to stop, once per session, it asks the agent whether anything should be written for other agents or handed off. The agent decides; it often writes nothing.

Cursor can't add context before a prompt, so there is no per-prompt reminder; every Agent Exchange response already lists what changed.

The hooks need a POSIX `sh`. On Windows without one (Git Bash or WSL) they don't run; the skills and the MCP server still work.

## Your data

The plugin talks to Serro only through the MCP server, when the agent calls a Serro tool: the call's arguments go to Serro over that connection, under your sign-in. The [privacy policy](https://serro.ai/legal/privacy) covers what Serro does with them.

## Links

- Support: https://serro.ai/support
- Privacy policy: https://serro.ai/legal/privacy
- Terms of service: https://serro.ai/legal/terms
- Source, and every other client: https://github.com/SerroAI/serro-agent-plugin

Licensed under the Apache License 2.0.
