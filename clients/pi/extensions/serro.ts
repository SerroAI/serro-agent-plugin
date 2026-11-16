// Serro for pi: the Serro MCP server, plus the Agent Exchange habits.
//
// The habits come from the serro-hook script that every Serro client shares.
// This extension only feeds it pi's events, as JSON on stdin:
//
//   tool_result           records a successful program_join
//   before_agent_start    reminds the agent to check for changes
//   agent_before_settle   nudges it once to write or hand off
//
// The script prints text for the agent and never calls Serro: the agent does
// the work over its own MCP connection. It stays silent until the agent has
// joined a program in this session.

import { spawn } from "node:child_process";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { type ExtensionAPI, getAgentDir } from "@earendil-works/pi-coding-agent";

const hook = fileURLToPath(new URL("../scripts/serro-hook", import.meta.url));

// Hook output, or "" if the script fails or takes too long. Without sh (as
// on Windows) the hooks stay silent and the skills still work.
function runHook(event: "joined" | "prompt" | "stop", input: object): Promise<string> {
	return new Promise((resolve) => {
		let out = "";
		const child = spawn("sh", [hook, event, "pi"], {
			env: { ...process.env, CLAUDE_PLUGIN_DATA: "", PLUGIN_DATA: join(getAgentDir(), "serro") },
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

export default function serro(pi: ExtensionAPI) {
	// A server named "serro" in the user's own mcp.json takes precedence over
	// this one. SERRO_MCP_URL points the plugin at another Serro deployment.
	pi.registerMcpServer("serro", {
		url: process.env.SERRO_MCP_URL || "https://mcp.serro.ai/mcp",
		description:
			"Serro: programs, their sources and reports, and Agent Exchange, a shared workspace per program for agents' plans, decisions and handoffs",
		// pi hides MCP tools behind codemode by default. Agent Exchange tools are
		// declared directly; the rest load through tool_search.
		exposure: "deferred",
		toolExposure: { "program_*": "direct", list_programs: "direct" },
	});

	// A continuation this extension requested, so the next settle doesn't nudge again.
	let continuing = false;
	pi.on("session_start", async () => {
		continuing = false;
	});

	pi.on("tool_result", async (event, ctx) => {
		if (!/^mcp__.+__program_join$/.test(event.toolName)) return;
		// tool_response goes last: the script reads the result from there to the end.
		await runHook("joined", {
			session_id: ctx.sessionManager.getSessionId(),
			tool_name: event.toolName,
			tool_input: event.input,
			tool_response: { content: event.content, structuredContent: event.structuredContent, isError: event.isError },
		});
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (event.messageType !== "user") return;
		const reminder = await runHook("prompt", { session_id: ctx.sessionManager.getSessionId() });
		if (reminder) event.systemPromptOptions.sections.serro = reminder;
	});

	pi.on("agent_before_settle", async (event, ctx) => {
		const wasContinuing = continuing;
		continuing = false;
		// event.context.canContinue is usually false here, because the assistant
		// spoke last. The nudge entry added below is what makes continuing valid.
		if (event.outcome !== "completed") return;
		const out = await runHook("stop", {
			session_id: ctx.sessionManager.getSessionId(),
			stop_hook_active: wasContinuing,
		});
		let reason: unknown;
		try {
			reason = out && JSON.parse(out).reason;
		} catch {
			return;
		}
		if (typeof reason !== "string" || !reason) return;
		continuing = true;
		return {
			entries: [...event.entries, { type: "custom_message", customType: "serro", content: reason, display: true }],
			continue: true,
		};
	});
}
