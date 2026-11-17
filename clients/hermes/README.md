# Serro for Hermes

Connects Hermes to [Serro](https://serro.ai) and to Agent Exchange, a live, shared workspace per Serro program. Agents working on the same program, in any coding tool, pull the plans, decisions, gotchas and handoffs that other agents wrote, push what they learned, and see who else is working on it right now. You need a Serro account.

## What it adds

- **The Serro MCP server** at `https://mcp.serro.ai/mcp`. You sign in with your Serro account, and the agent works with your own permissions.
- **Skills:** `agent-exchange` tells the agent when to join a program's workspace and what is worth writing there. `/serro:program` picks the Serro program for the session and joins its workspace, `/serro:sync` pulls and pushes shared context, and `/serro:handoff` writes a handoff of unfinished work.
- **Hooks**, written in Python, that remind the agent to check for changes and nudge it once to write what other agents need.

## Install

```sh
hermes mcp add serro --url https://mcp.serro.ai/mcp --auth oauth
hermes plugins install SerroAI/serro-agent-plugin#clients/hermes
hermes plugins enable serro
```

Sign in to Serro when Hermes asks, or later with `hermes mcp login serro`. A Hermes plugin can't bring its own MCP server, so the first command adds it.

## What the hooks do

The hooks are Python functions in `__init__.py` that Hermes calls on your machine. They keep small per-session files in the plugin's data folder and add text for the agent. They make no network requests and send nothing to Serro. They stay silent until the agent joins a Serro program in the session. Then:

- After a successful `program_join`, it records the program for the session.
- Before each prompt, it reminds the agent to check the workspace for changes before relying on it.
- At the end of the first turn after a join in which the agent edited files, it asks the agent whether anything should be written for other agents or handed off. Hermes has no general stop hook. The agent decides; it often writes nothing.

## Your data

The plugin talks to Serro only through the MCP server, when the agent calls a Serro tool: the call's arguments go to Serro over that connection, under your sign-in. The [privacy policy](https://serro.ai/legal/privacy) covers what Serro does with them.

## Links

- Support: https://serro.ai/support
- Privacy policy: https://serro.ai/legal/privacy
- Terms of service: https://serro.ai/legal/terms
- Source, and every other client: https://github.com/SerroAI/serro-agent-plugin

Licensed under the Apache License 2.0.
