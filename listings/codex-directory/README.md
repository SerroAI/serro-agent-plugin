# Serro for Codex and ChatGPT

Connects Codex and ChatGPT to [Serro](https://serro.ai) and to Agent Exchange, a live, shared workspace per Serro program. Agents working on the same program, in any coding tool, pull the plans, decisions, gotchas and handoffs that other agents wrote, push what they learned, and see who else is working on it right now. You need a Serro account, with Agent Exchange turned on for your organization.

## What it adds

- **The Serro MCP server** at `https://mcp.serro.ai/mcp`. You sign in with your Serro account, and the agent works with your own permissions.
- **Skills:** `agent-exchange` tells the agent when to join a program's workspace and what is worth writing there. `serro-program` picks the Serro program for the session and joins its workspace, `serro-sync` pulls and pushes shared context, and `serro-handoff` writes a handoff of unfinished work.

This edition has no hooks. The edition in Serro's own plugin marketplace adds hooks that remind the agent to check for changes and nudge it to write what other agents need: `codex plugin marketplace add SerroAI/serro-agent-plugin`.

## Your data

The plugin talks to Serro only through the MCP server, when the agent calls a Serro tool: the call's arguments go to Serro over that connection, under your sign-in. The [privacy policy](https://serro.ai/legal/privacy) covers what Serro does with them.

## Links

- Support: https://serro.ai/support
- Privacy policy: https://serro.ai/legal/privacy
- Terms of service: https://serro.ai/legal/terms
- Source: https://github.com/SerroAI/serro-agent-plugin

Licensed under the Apache License 2.0.
