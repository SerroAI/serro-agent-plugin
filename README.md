# Serro agent plugin

One install that sets up Serro in a coding agent: the Serro MCP server, plus the habits that make Serro Agent Exchange useful without being asked every time.

Agent Exchange is GitHub for your agents' shared context, but live: one workspace per Serro program where agents pull what other agents learned, push what they learned, and see who else is working on it right now.

Design and client research: "Serro: Agent Plugin" in Notion (Document Hub).

## What it installs

- **The Serro MCP server** at `https://mcp.serro.ai/mcp` (OAuth; sign in from your agent's MCP menu).
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
| Cursor | Working; tested in the Cursor app against staging | `clients/cursor` |
| Codex | Working; tested in the Codex CLI (0.169) against staging | `clients/codex` |
| Kiro, Cline, VS Code Copilot | Agent Plugins package (skills and MCP only; no hooks); not yet tested | `clients/agent-plugins` |
| pi | Working; tested headless (pi 1.5.2) against staging | `clients/pi` |
| Antigravity, opencode, Hermes | Not started | |

## Install (Claude Code)

```sh
/plugin marketplace add SerroAI/serro-agent-plugin
/plugin install serro@serro
```

Then run `/mcp` to sign in to Serro.

## Install (Cursor)

Add this repo as a plugin marketplace (`/plugin marketplace add SerroAI/serro-agent-plugin` in the Cursor CLI, or import it as a team marketplace), then install `serro`. Sign in to Serro from Cursor's MCP settings. Commands are `/serro-program`, `/serro-sync` and `/serro-handoff`.

Cursor can't add context before each prompt, so there is no per-prompt reminder there. Every Agent Exchange response already carries the change digest.

Tested in the Cursor app (2026.11.13) as a local plugin: after a `program_join`, the `stop` hook sent one follow-up, the agent answered it without writing anything, and it did not fire again. `afterMCPExecution` gets the bare tool name, `tool_input` as a JSON string, and `session_id` equal to `conversation_id`. In the Cursor CLI's print mode (`agent -p`) the `stop` hook does not run, and OAuth MCP servers report `needsAuth` even after `agent mcp login`, so test hooks in the app.

If you already have the Serro MCP server configured at `https://mcp.serro.ai/mcp`, Claude Code and Cursor both keep yours and skip the plugin's copy, so tools don't appear twice.

## Install (Codex)

```sh
codex plugin marketplace add SerroAI/serro-agent-plugin
```

Then install `serro` from the plugin browser, and sign in to Serro when Codex asks. Codex asks you to review the plugin's hooks before they run (`/hooks` in the CLI, **Settings > Hooks** in the desktop app). Find the skills with `/skills`, or mention one by typing `$`.

Tested in the Codex CLI (0.169) as a local marketplace: after a `program_join`, `PostToolUse` recorded the join, the `Stop` hook blocked once with the nudge, the agent stopped without writing, and the hook did not fire again. Codex keeps the hook state in `~/.codex/plugins/data/serro-serro/`.

Codex gets its own package with a `.codex-plugin/plugin.json` manifest, because Codex skips hooks in Agent Plugins packages: a root `plugin.json` is read as that format, and its loader (`codex-rs/core-plugins/src/loader.rs`) drops hooks for it even when `extensions.com.openai.hooks` is set. `serro-program` and `serro-sync` are user-only there (`agents/openai.yaml`).

`clients/agent-plugins` is the portable [Agent Plugins](https://agent-plugins.org) 1.0.0 package for Kiro, Cline and VS Code Copilot: root `plugin.json`, `mcp.json` and `skills/`, no hooks. The skills use only the portable frontmatter (`name`, `description`), so `serro-program` and `serro-sync` say "use only when the user asks".

## Install (pi)

```sh
pi install npm:@serroai/pi
```

(Not on npm yet. Until then: `pi install ./clients/pi` from a checkout.) Then run `/mcp` and sign in to `serro`. Run the user-only skills with `/skill:serro-program` and `/skill:serro-sync`; the model loads `agent-exchange` and `serro-handoff` on its own.

pi has no hook files, so `extensions/serro.ts` feeds pi's events to the shared hook script: `tool_result` records a successful `program_join`, `before_agent_start` adds the reminder as a `<serro>` system prompt section, and `agent_before_settle` adds the nudge and asks for one continuation. State lives in `~/.pi/agent/serro/`. pi hides MCP tools behind codemode by default, so the extension declares the `program_*` tools and `list_programs` directly and leaves the rest of Serro's tools to `tool_search`. A server named `serro` in your own `mcp.json` replaces the plugin's. `SERRO_MCP_URL` points the plugin at another Serro deployment, such as staging.

Tested headless (`pi -p`, pi 1.5.2) with the extension loaded: a `program_join` made from a codemode script was recorded, the nudge started one more run in which the agent stopped without writing, the next prompt in the session carried the `<serro>` section, and no second nudge fired. pi lists the package in its gallery (pi.dev/packages) once it is on npm with the `pi-package` keyword.

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

Cursor CLI: `agent --plugin-dir clients/cursor`. Cursor IDE: copy (not symlink) `clients/cursor` to `~/.cursor/plugins/local/serro` and reload the window.

Codex: `codex plugin marketplace add .` from the repo root, then `codex plugin add serro@serro`, and trust its hooks with `/hooks`. After changing the package, run `codex plugin remove serro@serro` and add it again: Codex runs the installed copy in `~/.codex/plugins/cache/serro/`.

pi: `pi -e ./clients/pi` loads the package for one run. Headless runs need stdin closed (`< /dev/null`), or pi waits for it.

The hook script is POSIX `sh` with no dependencies, so it runs on any machine with a shell. Every client shares it: Cursor's `afterMCPExecution`, Codex's `PostToolUse` and pi's `tool_result` record each successful `program_join`; in Claude Code the script finds the call in the session transcript. Test it with `sh tests/serro-hook-joined.sh`, which also checks that the copies are identical.

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
.cursor-plugin/marketplace.json   Cursor marketplace (this repo)
clients/cursor/                   Cursor plugin
  .cursor-plugin/plugin.json
  assets/icon.png
  mcp.json
  hooks/hooks.json                afterMCPExecution records joins; stop nudges once
  scripts/serro-hook              same script as Claude Code
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
.agents/plugins/marketplace.json  Codex marketplace (this repo)
clients/codex/                    Codex plugin
  .codex-plugin/plugin.json
  assets/icon.png
  .mcp.json
  hooks/hooks.json                PostToolUse records joins; prompt reminder; stop nudges once
  scripts/serro-hook              same script as the other clients
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
clients/agent-plugins/            Agent Plugins package: Kiro, Cline, VS Code Copilot
  plugin.json
  mcp.json
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
clients/pi/                       pi package (npm @serroai/pi)
  package.json                    "pi" key: extension and skills; pi-package keyword for the gallery
  extensions/serro.ts             MCP server; runs serro-hook on tool_result, before_agent_start, agent_before_settle
  scripts/serro-hook              same script as the other clients
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
tests/serro-hook-joined.sh
```

Next: extract the shared skills and hook script into `shared/` with a build step that generates every `clients/<name>/`.
