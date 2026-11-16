// Serro for opencode: the Serro MCP server, plus the Agent Exchange habits.
//
// The habits come from the serro-hook script that every Serro client shares.
// This plugin only feeds it opencode's events, as JSON on stdin:
//
//   tool execute.after         records a successful program_join
//   session prompt, context    reminds the agent to check for changes
//   session experimental.idle  nudges it once to write or hand off
//
// The script prints text for the agent and never calls Serro: the agent does
// the work over its own MCP connection. It stays silent until the agent has
// joined a program in this session.

import { spawn } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { Plugin, Skill } from "@opencode/plugin";

const root = fileURLToPath(new URL(".", import.meta.url));
const hook = join(root, "scripts", "serro-hook");
const state = join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "opencode", "serro");

// Hook output, or "" if the script fails or takes too long. Without sh (as
// on Windows) the hooks stay silent and the skills still work.
function runHook(event: "joined" | "prompt" | "stop", input: object): Promise<string> {
	return new Promise((resolve) => {
		let out = "";
		const child = spawn("sh", [hook, event, "opencode"], {
			env: { ...process.env, CLAUDE_PLUGIN_DATA: "", PLUGIN_DATA: state },
			stdio: ["pipe", "pipe", "ignore"],
			timeout: 10_000,
		});
		child.stdout.on("data", (chunk) => (out += chunk));
		child.on("error", () => resolve(""));
		child.on("close", (code) => resolve(code === 0 ? out.trim() : ""));
		child.stdin.on("error", () => {});
		child.stdin.end(JSON.stringify(input));
	});
}

// A skill's SKILL.md: the top-level `key: value` lines of its frontmatter, and its body.
function readSkill(name: string) {
	const path = join(root, "skills", name, "SKILL.md");
	const [, front = "", body = ""] = readFileSync(path, "utf8")
		.replace(/\r\n/g, "\n")
		.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/) ?? [];
	const fields = Object.fromEntries(
		front.split("\n").flatMap((line) => {
			const match = line.match(/^([\w-]+):\s*(.*)$/);
			return match ? [[match[1], match[2].trim()]] : [];
		}),
	);
	return {
		name,
		path,
		description: fields.description ?? "",
		userOnly: fields["disable-model-invocation"] === "true",
		body: body.trim(),
	};
}

export default Plugin.define({
	id: "serro",
	async setup(ctx) {
		// A server named "serro" in the user's own config takes precedence over this
		// one. The url option, or SERRO_MCP_URL, points it at another Serro deployment.
		const url =
			(typeof ctx.options.url === "string" && ctx.options.url) || process.env.SERRO_MCP_URL || "https://mcp.serro.ai/mcp";
		await ctx.mcp.transform((editor) => {
			if (!editor.get("serro")) editor.set("serro", { type: "remote", url });
		});

		const skills = readdirSync(join(root, "skills")).map(readSkill);
		await ctx.skill.transform((editor) => {
			for (const skill of skills) {
				editor.add({
					id: Skill.ID.make(skill.name),
					name: Skill.Name.make(skill.name),
					description: skill.description,
					path: Skill.Info.fields.path.make(skill.path),
					content: skill.body,
				});
				// User-only skills stay out of the model's list; commands below run them.
				if (skill.userOnly) editor.update(skill.name, (entry) => void (entry.autoinvoke = false));
			}
		});

		// opencode's skills aren't slash commands, so the ones a user runs are also
		// commands: /serro-program, /serro-sync and /serro-handoff. Each sends the
		// user's words with the skill attached, as an @skill mention would.
		await ctx.command.transform((editor) => {
			for (const skill of skills.filter((s) => s.name !== "agent-exchange")) {
				editor.add({
					name: skill.name,
					description: skill.description,
					execute: async ({ sessionID, prompt, delivery }) => {
						await ctx.session.prompt({
							...prompt,
							sessionID,
							delivery,
							text: prompt.text.trim() || skill.description,
							skills: [...(prompt.skills ?? []), { id: Skill.ID.make(skill.name) }],
						});
					},
				});
			}
		});

		await ctx.tool.hook("execute.after", async (event) => {
			if (event.status !== "completed" || !/program_join$/.test(event.tool)) return;
			// tool_response goes last: the script reads the result from there to the end.
			await runHook("joined", {
				session_id: event.sessionID,
				tool_name: event.tool,
				tool_input: event.input,
				tool_response: event.result,
			});
		});

		// The reminder is worked out once per user prompt and added to each model
		// call in that turn; context changes apply to the outgoing call only.
		const reminders = new Map<string, string>();
		await ctx.session.hook("prompt", async (event) => {
			const reminder = await runHook("prompt", { session_id: event.sessionID });
			if (reminder) reminders.set(event.sessionID, reminder);
			else reminders.delete(event.sessionID);
		});
		await ctx.session.hook("context", (event) => {
			const reminder = reminders.get(event.sessionID);
			if (reminder) event.system.push({ type: "text", text: reminder });
		});

		// Sessions continuing from a nudge, so their next idle doesn't nudge again.
		const continuing = new Set<string>();
		await ctx.session.hook("experimental.idle", async (event) => {
			const wasContinuing = continuing.delete(event.sessionID);
			// This session's own background work wakes it again when it finishes; work a
			// subagent owns wakes the subagent instead, so it doesn't count here.
			if (event.background.some((work) => work.sessionID === event.sessionID)) return;
			const out = await runHook("stop", { session_id: event.sessionID, stop_hook_active: wasContinuing });
			let reason: unknown;
			try {
				reason = out && JSON.parse(out).reason;
			} catch {
				return;
			}
			if (typeof reason !== "string" || !reason) return;
			continuing.add(event.sessionID);
			// A message admitted here runs in the same execution instead of the session going idle.
			await ctx.session.synthetic({ sessionID: event.sessionID, text: reason });
		});
	},
});
