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
| pi | Working; tested in pi (1.5.2), interactive and headless, against staging | `clients/pi` |
| Hermes | Working; tested headless (Hermes 0.23.1) against staging. Skills and hooks; the MCP server is the user's own entry, and the stop nudge comes only on turns that edited files | `clients/hermes` |
| Antigravity | Working; tested in the Antigravity CLI (1.5.9) against staging and prod. Sign-in needed SerroAI/serro-mcp#169 | `clients/antigravity` |
| opencode | Working; tested in opencode (2.3.0), interactive and headless, against staging | `clients/opencode` |

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

## Install (pi)

```sh
pi install npm:@serroai/pi
```

(Not on npm yet. Until then: `pi install ./clients/pi` from a checkout.) Then run `/mcp` and sign in to `serro`. Run the user-only skills with `/skill:serro-program` and `/skill:serro-sync`; the model loads `agent-exchange` and `serro-handoff` on its own.

pi has no hook files, so `extensions/serro.ts` feeds pi's events to the shared hook script: `tool_result` records a successful `program_join`, `before_agent_start` adds the reminder as a `<serro>` system prompt section, and `agent_before_settle` adds the nudge and asks for one continuation. State lives in `~/.pi/agent/serro/`. pi hides MCP tools behind codemode by default, so the extension declares the `program_*` tools and `list_programs` directly and leaves the rest of Serro's tools to `tool_search`. A server named `serro` in your own `mcp.json` replaces the plugin's. `SERRO_MCP_URL` points the plugin at another Serro deployment, such as staging.

Tested in pi 1.5.2 against staging. Interactive (`pi -e ./clients/pi`): after signing in to `serro` from `/mcp`, `/skill:serro-program` called `list_programs` and `program_join` directly through the plugin's server, the nudge showed once as a `[serro]` message and the agent stopped without writing, the next prompt carried the `<serro>` section, and no second nudge fired. pi keeps MCP sign-ins per server name and URL, so a sign-in for another entry with the same URL doesn't carry over. Headless (`pi -p`): a `program_join` made from a codemode script on another server was recorded too. pi lists the package in its gallery (pi.dev/packages) once it is on npm with the `pi-package` keyword.

## Install (Hermes)

```sh
hermes mcp add serro --url https://mcp.serro.ai/mcp --auth oauth
hermes plugins install SerroAI/serro-agent-plugin#clients/hermes
hermes plugins enable serro
```

Sign in to Serro when Hermes asks, or later with `hermes mcp login serro`. The skills are `serro:agent-exchange`, `serro:program`, `serro:sync` and `serro:handoff`, and each is also a slash command (`/serro:program` and so on).

Hermes gets a native plugin (`plugin.yaml` and `__init__.py`), not the Agent Plugins package. Hermes loads Agent Plugins packages, but it signs in to an MCP server only when its config says `auth: oauth`, which a package's `mcp.json` can't set, and packages can't run hooks. A native plugin can't ship an MCP server, so the Serro server is the user's own entry, added above.

The plugin ports `serro-hook` to Hermes hooks in Python, with the same text: `post_tool_call` records a successful `program_join`, `pre_llm_call` adds the reminder to each prompt, `pre_verify` adds the nudge, and `post_compaction` keeps the record when compaction starts a new session id. Hermes has no general stop hook: `pre_verify` fires only on turns where the agent edited files, so the nudge comes at the end of the first such turn after a join. Joins are kept in `~/.hermes/plugin-data/serro/`, one file per session as `serro-hook` keeps them, so a resumed session keeps them.

Tested in Hermes 0.23.1 against staging, through an existing `serro-staging` server entry. Interactive: `/serro:` lists the four skills, and `/serro:program Serro Security Maintenance` picked and joined the program. Headless (`hermes chat -q`): the join was recorded, the nudge kept the agent going once and it stopped without writing, the resumed session's next prompt carried the reminder, and a second file edit brought no second nudge. `hermes plugins validate clients/hermes`, the check the Hermes plugin catalog runs, passes. Hermes lists plugins in its catalog (`plugin-catalog/` in the hermes-agent repo, added by pull request and pinned to a commit) and remote MCP servers in a separate catalog (`optional-mcps/`).

## Install (Antigravity)

```sh
agy plugin install ./clients/antigravity
```

That installs from a checkout; `/plugin` in the CLI can also install from a local folder. Then open `/plugin`, expand **serro** under **Installed**, and choose **Sign in**. Antigravity names the plugin's MCP server `serro_serro` (`<plugin>_<server>`). The slash commands are `/serro:serro-program`, `/serro:serro-sync` and `/serro:serro-handoff`; the model sees the skills by their own names.

The plugin runs the shared hook script from `hooks.json`:
- `PostToolUse` records a successful join. The model calls MCP tools through Antigravity's `call_mcp_tool`, so the hook matches that and checks `toolCall.args.ToolName`. Antigravity sends no result, and writes it to the session transcript only after the hook returns. So the join waits in `pending-<session>` with the call's `stepIdx`, and the next `Stop` or `PreInvocation` hook checks the transcript step with that `step_index` and records it if it succeeded.
- `PreInvocation` adds the reminder as a system message, at the first model call of each turn (`invocationNum` 0).
- `Stop` asks for one continuation with the nudge. It skips continuations (`executionNum` above 0); `continuationActive` stayed false on the Stop that followed a continuation, so the script doesn't rely on it.

State lives in `PLUGIN_DATA` (`~/.gemini/antigravity-cli/plugin_data/serro/`).

Antigravity offers an MCP sign-in only when the server's protected-resource metadata names the exact URL it connects to (RFC 9728 §3.3). Serro's named the origin, so Antigravity showed `Unauthorized` with no sign-in. SerroAI/serro-mcp#169 fixed that, on prod since 2026-11-16. Official listings go through the Antigravity plugin marketplace (`agy plugin install <name>@antigravity-plugins-official`).

Tested in the Antigravity CLI (1.5.9) against staging, with a copy of the package pointed at staging. Interactive: signing in from `/plugin` worked, and `/serro:serro-program Serro Security Maintenance` picked and joined the program. Headless (`agy -p`): the join was recorded at the turn's `Stop`, the nudge ran one continuation, the next turn's first model call carried the reminder, and no second nudge fired. In print mode Antigravity can't ask for MCP permission, so the test passed `--settings '{"permissions":{"allow":["mcp(serro_serro/*)","mcp(serro_serro)"]}}'`, which applies to that run only.

## Install (opencode)

```sh
opencode plugin add @serroai/opencode
```

(Not on npm yet. Until then, list the package directory in `opencode.json`: `"plugins": ["file:///path/to/clients/opencode"]`.) Then sign in with `opencode mcp auth serro`, or from `/mcps` in the TUI. The commands are `/serro-program`, `/serro-sync` and `/serro-handoff`; opencode's skills aren't slash commands, so each command sends what you typed with its skill attached, as an `@skill` mention does. The model loads `agent-exchange` and `serro-handoff` on its own; `serro-program` and `serro-sync` are user-only (`autoinvoke` off).

This is an opencode 2 server plugin (`@opencode/plugin`); opencode 1 plugins don't load in 2, and this one doesn't load in 1. `index.ts` adds the MCP server and skills through opencode's transforms and feeds opencode's events to the shared hook script:
- `tool` `execute.after` records a successful `program_join`. opencode's code mode runs MCP calls inside its `execute` tool (`tools.serro.program_join(...)`), and those calls still reach tool hooks.
- `session` `prompt` works out the reminder once per user prompt, and `context` adds it as a system part to each model call in that turn.
- `session` `experimental.idle` runs the nudge when the session would go idle, and admits it with `session.synthetic`, so the agent answers it in the same run. The hook is in the 2.3.0 plugin types but not yet in opencode's docs.

State lives in `~/.local/share/opencode/serro/`. A server named `serro` in your own config replaces the plugin's. To point the plugin at another Serro deployment, give it a `url` option. A local package needs the `file://` form there:

```json
{ "plugins": [{ "package": "file:///path/to/clients/opencode", "options": { "url": "https://mcp-staging.serro.ai/mcp" } }] }
```

`SERRO_MCP_URL` also works, but only in the environment of opencode's background service (`opencode serve --service`), which runs plugins for the TUI and the CLI alike. Setting it on an `opencode` command doesn't reach the plugin.

Tested in opencode 2.3.0 (Claude Sonnet 5.5 on Amazon Bedrock) against staging. Interactive: `/serro-program Serro Security Maintenance` showed as the user's words with the `serro-program` skill attached, the agent joined, and the idle nudge brought one reply that it had nothing to write. Headless (`opencode run`, which sends slash commands as plain text): the join was recorded, the idle nudge ran one more step in which the agent stopped without writing, the next prompt in the session carried the reminder, and no second nudge fired. opencode reports its MCP client as `opencode` with its real version. opencode has no plugin marketplace: plugins are npm packages, installed with `opencode plugin add`.

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

opencode: list `file:///path/to/clients/opencode` under `plugins` in a project's `opencode.json`; the background service reads it from there. `opencode plugin list` in that directory shows whether it loaded.

Antigravity: `agy plugin install ./clients/antigravity` installs a copy, so reinstall after changing the package. `agy plugin validate clients/antigravity --strict` checks it.

Codex: `codex plugin marketplace add .` from the repo root, then `codex plugin add serro@serro`, and trust its hooks with `/hooks`. After changing the package, run `codex plugin remove serro@serro` and add it again: Codex runs the installed copy in `~/.codex/plugins/cache/serro/`.

pi: `pi -e ./clients/pi` loads the package for one run. Headless runs need stdin closed (`< /dev/null`), or pi waits for it.

Hermes: copy `clients/hermes` to `~/.hermes/plugins/serro`, then run `hermes plugins enable serro`. After changing the copy, run `hermes plugins disable serro` and enable it again: `hermes chat` runs in the Hermes gateway, which keeps the loaded code until then. `hermes plugins validate clients/hermes` runs the catalog's checks.

The hook script is POSIX `sh` with no dependencies, so it runs on any machine with a shell. Every client except Hermes shares it: Cursor's `afterMCPExecution`, Codex's `PostToolUse`, pi's `tool_result`, Antigravity's `PostToolUse` and opencode's `execute.after` record each successful `program_join`; in Claude Code the script finds the call in the session transcript. Test it with `sh tests/serro-hook-joined.sh`, which also checks that the copies are identical. Hermes runs a Python port; `python3 tests/hermes-plugin.py` tests it and checks that its text matches the script's.

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
clients/pi/                       pi package (npm @serroai/pi)
  package.json                    "pi" key: extension and skills; pi-package keyword for the gallery
  extensions/serro.ts             MCP server; runs serro-hook on tool_result, before_agent_start, agent_before_settle
  scripts/serro-hook              same script as the other clients
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
clients/hermes/                   Hermes plugin
  plugin.yaml
  __init__.py                     skills; post_tool_call records joins; prompt reminder; pre_verify nudges once; post_compaction keeps joins
  skills/{agent-exchange,program,sync,handoff}/SKILL.md
clients/antigravity/              Antigravity plugin
  plugin.json
  assets/icon.png
  mcp_config.json
  hooks.json                      PostToolUse records joins; PreInvocation reminder; Stop nudges once
  scripts/serro-hook              same script as the other clients
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
clients/opencode/                 opencode 2 plugin (npm @serroai/opencode)
  package.json
  index.ts                        MCP server, skills, commands; runs serro-hook on tool and session hooks
  scripts/serro-hook              same script as the other clients
  skills/{agent-exchange,serro-program,serro-sync,serro-handoff}/SKILL.md
tests/serro-hook-joined.sh
tests/hermes-plugin.py
```

Next: extract the shared skills and hook script into `shared/` with a build step that generates every `clients/<name>/`.
