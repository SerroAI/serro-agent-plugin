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
| Kiro | Working; tested in the Kiro IDE (1.4.178) against staging. Skills and MCP only: powers can't ship hooks | `clients/agent-plugins/serro` |
| Cline, VS Code Copilot | Same Agent Plugins package (skills and MCP only; no hooks); not yet tested | `clients/agent-plugins/serro` |
| Antigravity | Built; hooks tested in the Antigravity CLI (1.5.9). Sign-in waits on a serro-mcp fix (SerroAI/serro-mcp#169) | `clients/antigravity` |
| opencode, pi, Hermes | Not started | |

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

`clients/agent-plugins/serro` is the portable [Agent Plugins](https://agent-plugins.org) 1.0.0 package for Kiro, Cline and VS Code Copilot: root `plugin.json`, `mcp.json` and `skills/`, no hooks. The skills use only the portable frontmatter (`name`, `description`), so `serro-program` and `serro-sync` say "use only when the user asks".

## Install (Kiro)

In the **Powers** panel, choose **Add Custom Power**, then import `clients/agent-plugins/serro` from GitHub or from a local folder. Sign in to Serro when the MCP server asks. Kiro loads the power when a message mentions one of its `keywords` (`serro`, `agent exchange`), and adds the MCP server as `power-serro-serro`. The skills are also slash commands: `/serro-program`, `/serro-sync` and `/serro-handoff`.

Kiro names an imported power, and its MCP server, after the power's folder, not the manifest's `name`. That is why the package sits in a folder called `serro`.

Tested in the Kiro IDE (1.4.178) by importing a staging copy from a local folder: the remote OAuth MCP server connected, the keyword in "Use Serro Agent Exchange to join program …" loaded the power, the agent joined and left the program, and `/serro-program` picked and joined a program. Kiro reports its MCP client as `kiro` with version `0.0.0`. A power can't ship hooks, so Kiro gets no reminder or stop nudge.

## Install (Antigravity)

```sh
agy plugin install ./clients/antigravity
```

That installs from a checkout; `/plugin` in the CLI can also install from a local folder. Then open `/plugin`, expand **serro** under **Installed**, and sign in. Antigravity names the plugin's MCP server `serro_serro` (`<plugin>_<server>`). The skills keep their names and are slash commands: `/serro-program`, `/serro-sync` and `/serro-handoff`.

The plugin runs the shared hook script from `hooks.json`:
- `PostToolUse` on `program_join` records a successful join. Antigravity sends the call but not its result, so the script reads the result from the session transcript: the step whose `step_index` is the call's `stepIdx`.
- `PreInvocation` adds the reminder as a system message, at the first model call of each turn (`invocationNum` 0).
- `Stop` asks for one continuation with the nudge. It skips continuations (`executionNum` above 0); `continuationActive` stayed false on the Stop that followed a continuation, so the script doesn't rely on it.

State lives in `PLUGIN_DATA` (`~/.gemini/antigravity-cli/plugin_data/serro/`).

Antigravity offers an MCP sign-in only when the server's protected-resource metadata names the exact URL it connects to (RFC 9728 §3.3). Serro's named the origin, so Antigravity showed `Unauthorized` with no sign-in; SerroAI/serro-mcp#169 fixes that. Official listings go through the Antigravity plugin marketplace (`agy plugin install <name>@antigravity-plugins-official`).

Tested in the Antigravity CLI (1.5.9) with a probe plugin that recorded each hook's input: the payload fields above, a `Stop` continuation that ran once, and the transcript format.

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

Antigravity: `agy plugin install ./clients/antigravity` installs a copy, so reinstall after changing the package. `agy plugin validate clients/antigravity --strict` checks it.

Codex: `codex plugin marketplace add .` from the repo root, then `codex plugin add serro@serro`, and trust its hooks with `/hooks`. After changing the package, run `codex plugin remove serro@serro` and add it again: Codex runs the installed copy in `~/.codex/plugins/cache/serro/`.

The hook script is POSIX `sh` with no dependencies, so it runs on any machine with a shell. Every client shares it: Cursor's `afterMCPExecution` and Codex's `PostToolUse` hooks record each successful `program_join`; in Claude Code the script finds the call in the session transcript. Test it with `sh tests/serro-hook-joined.sh`, which also checks that the copies are identical.

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
clients/agent-plugins/serro/      Agent Plugins package: Kiro, Cline, VS Code Copilot (folder name = Kiro power name)
  plugin.json
  mcp.json
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
clients/antigravity/              Antigravity plugin
  plugin.json
  assets/icon.png
  mcp_config.json
  hooks.json                      PostToolUse records joins; PreInvocation reminder; Stop nudges once
  scripts/serro-hook              same script as the other clients
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
tests/serro-hook-joined.sh
```

Next: extract the shared skills and hook script into `shared/` with a build step that generates every `clients/<name>/`.
