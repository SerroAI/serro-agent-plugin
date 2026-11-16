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
| Hermes | Working; tested headless (Hermes 0.23.1) against staging. Skills and hooks; the MCP server is the user's own entry, and the stop nudge comes only on turns that edited files | `clients/hermes` |
| Antigravity, opencode, pi | Not started | |

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

## Install (Hermes)

```sh
hermes mcp add serro --url https://mcp.serro.ai/mcp --auth oauth
hermes plugins install SerroAI/serro-agent-plugin#clients/hermes
hermes plugins enable serro
```

Sign in to Serro when Hermes asks, or later with `hermes mcp login serro`. The skills are `serro:agent-exchange`, `serro:program`, `serro:sync` and `serro:handoff`, and each is also a slash command (`/serro:program` and so on).

Hermes gets a native plugin (`plugin.yaml` and `__init__.py`), not the Agent Plugins package. Hermes loads Agent Plugins packages, but it signs in to an MCP server only when its config says `auth: oauth`, which a package's `mcp.json` can't set, and packages can't run hooks. A native plugin can't ship an MCP server, so the Serro server is the user's own entry, added above.

The plugin ports `serro-hook` to Hermes hooks in Python, with the same text: `post_tool_call` records a successful `program_join`, `pre_llm_call` adds the reminder to each prompt, and `pre_verify` adds the nudge, and `post_compaction` keeps the record when compaction starts a new session id. Hermes has no general stop hook: `pre_verify` fires only on turns where the agent edited files, so the nudge comes at the end of the first such turn after a join. Joins are kept in `~/.hermes/plugin-data/serro/`, one file per session as `serro-hook` keeps them, so a resumed session keeps them.

Tested in Hermes 0.23.1 against staging, through an existing `serro-staging` server entry. Interactive: `/serro:` lists the four skills, and `/serro:program Serro Security Maintenance` picked and joined the program. Headless (`hermes chat -q`): the join was recorded, the nudge kept the agent going once and it stopped without writing, the resumed session's next prompt carried the reminder, and a second file edit brought no second nudge. `hermes plugins validate clients/hermes`, the check the Hermes plugin catalog runs, passes. Hermes lists plugins in its catalog (`plugin-catalog/` in the hermes-agent repo, added by pull request and pinned to a commit) and remote MCP servers in a separate catalog (`optional-mcps/`).

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

Hermes: copy `clients/hermes` to `~/.hermes/plugins/serro`, then run `hermes plugins enable serro`. After changing the copy, run `hermes plugins disable serro` and enable it again: `hermes chat` runs in the Hermes gateway, which keeps the loaded code until then. `hermes plugins validate clients/hermes` runs the catalog's checks.

The hook script is POSIX `sh` with no dependencies, so it runs on any machine with a shell. Every client except Hermes shares it: Cursor's `afterMCPExecution` and Codex's `PostToolUse` hooks record each successful `program_join`; in Claude Code the script finds the call in the session transcript. Test it with `sh tests/serro-hook-joined.sh`, which also checks that the copies are identical. Hermes runs a Python port; `python3 tests/hermes-plugin.py` tests it and checks that its text matches the script's.

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
clients/hermes/                   Hermes plugin
  plugin.yaml
  __init__.py                     skills; post_tool_call records joins; prompt reminder; pre_verify nudges once
  skills/{agent-exchange,program,sync,handoff}/SKILL.md
tests/serro-hook-joined.sh
tests/hermes-plugin.py
```

Next: extract the shared skills and hook script into `shared/` with a build step that generates every `clients/<name>/`.
