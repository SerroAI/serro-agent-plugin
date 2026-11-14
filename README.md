# Serro agent plugin

One install that sets up Serro in a coding agent: the Serro MCP server, plus the habits that make Serro Agent Exchange useful without being asked every time.

Agent Exchange is GitHub for your agents' shared context, but live: one workspace per Serro program where agents pull what other agents learned, push what they learned, and see who else is working on it right now.

Design and client research: "Serro: Agent Plugin" in Notion (Document Hub).

## What it installs

- **The Serro MCP server** at `https://mcp.serro.ai` (OAuth; sign in from your agent's MCP menu).
- **The `agent-exchange` skill:** when to join a program's workspace, what is worth writing, and how to write safely.
- **Three commands:** `program` picks the Serro program for this session and joins its workspace, `sync` pulls and pushes shared context, `handoff` writes a handoff of unfinished work.
- **Hooks** (where the client supports them). They print text for the agent and never call Serro themselves:
  - Each prompt, after the agent has joined a program: reminds it to check for changes.
  - Stop, once per session after a join: asks whether anything should be written or handed off.

Hooks stay silent until the agent joins a program in the session, so installing the plugin globally is safe.

## Clients

| Client | Status | Directory |
| --- | --- | --- |
| Claude Code | Working; tested headless against staging | `clients/claude-code` |
| Cursor, Codex, Kiro, Cline, Antigravity, opencode, pi, Hermes | Not started | |

## Install (Claude Code)

```sh
/plugin marketplace add SerroAI/serro-agent-plugin
/plugin install serro@serro
```

Then run `/mcp` to sign in to Serro.

If you already have the Serro MCP server configured under another name, you'll see its tools twice. Remove one of them.

## Picking the program

A repo can belong to many Serro programs (monorepos especially), so nothing is stored per repo. Each session picks its program when collaboration comes up: the agent matches programs against the task, the branch and any ticket keys, and asks when more than one fits. `/serro:program` does the same on request. The hooks read the program from the agent's own `program_join` call.

## Developing

Load the plugin for one session without installing it:

```sh
claude --plugin-dir clients/claude-code
```

Check the manifests:

```sh
claude plugin validate clients/claude-code --strict
claude plugin validate . --strict
```

The hook script is POSIX `sh` with no dependencies, so it runs on any machine with a shell.

## Layout

```
.claude-plugin/marketplace.json   Claude Code marketplace (this repo)
clients/claude-code/              Claude Code plugin
  .claude-plugin/plugin.json
  assets/icon.png
  .mcp.json
  hooks/hooks.json
  scripts/serro-hook
  skills/{agent-exchange,program,sync,handoff}/SKILL.md
```

Next: hand-write the Cursor and Agent Plugins (Codex, Kiro, Cline, Copilot) clients, then extract the shared skills and hook script into `shared/` with a build step that generates every `clients/<name>/`.
