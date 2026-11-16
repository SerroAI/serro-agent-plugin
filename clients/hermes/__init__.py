"""Serro for Hermes: the Agent Exchange skills, plus the habits that make them useful.

The habits are the ones scripts/serro-hook gives the other Serro clients, as Hermes hooks:

  post_tool_call   records a successful program_join
  pre_llm_call     reminds the agent to check for changes
  pre_verify       nudges it once to write or hand off

Hermes has no general stop hook. pre_verify fires only on turns where the agent edited
code, so the nudge comes at the end of the first such turn after a join.

The plugin never calls Serro: the agent does the work over its own MCP connection, the
user's `serro` server entry (a native plugin can't ship one). It stays silent until the
agent has joined a program in this session.
"""

from __future__ import annotations

import json
import re
import threading
from pathlib import Path

JOIN_TOOL = re.compile(r"^mcp__.+__program_join$")
PROGRAM_ID = re.compile(r"[0-9A-Fa-f-]{36}")
# Only a successful join counts: the result must return an "agent_id" key with a UUID
# value. Serro reports failures as {"error": ..., "message": ...}, sometimes without
# isError. The result is text, often JSON inside a JSON string, so quotes may be escaped.
UUID = r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
AGENT_ID = re.compile(r'\\*"agent_id\\*"\s*:\s*\\*"' + UUID + r'\\*"')
ERROR = re.compile(r'\\*"error\\*"\s*:')
IS_ERROR = re.compile(r'\\*"isError\\*"\s*:\s*true')

# The same text as scripts/serro-hook (tests/hermes-plugin.py checks).
REMINDER = (
    "Serro Agent Exchange: you joined program {programs} in this session. "
    "Check program_fs_changes before relying on shared workspace state."
)
NUDGE = (
    "Serro: before stopping, if this session produced something other agents on Serro "
    "program {programs} need (a plan, a decision, a gotcha) or left work unfinished, write "
    "it to the Agent Exchange workspace now (for unfinished work, use the serro:handoff "
    "skill). If not, stop without writing anything."
)

# Sessions kept in the plugin's state, most recent last.
MAX_SESSIONS = 200

_lock = threading.Lock()


def register(ctx):
    skills = Path(__file__).parent / "skills"
    for skill in sorted(skills.iterdir()):
        if (skill / "SKILL.md").is_file():
            ctx.register_skill(skill.name, skill / "SKILL.md")

    # {session_id: {"programs": [program_id, ...], "nudged": bool}}
    def sessions() -> dict:
        return ctx.state.get("sessions", default={}) or {}

    def programs(entry: dict | None) -> str:
        return ", ".join(sorted(set(entry["programs"]))) if entry else ""

    def on_tool_call(tool_name="", args=None, result="", session_id="", status="", **kwargs):
        if not session_id or not JOIN_TOOL.match(tool_name or ""):
            return
        text = result if isinstance(result, str) else json.dumps(result)
        if status == "error" or not AGENT_ID.search(text) or ERROR.search(text) or IS_ERROR.search(text):
            return
        if isinstance(args, str):
            try:
                args = json.loads(args)
            except ValueError:
                return
        program = (args or {}).get("program_id")
        if not isinstance(program, str) or not PROGRAM_ID.fullmatch(program):
            return
        with _lock:
            data = sessions()
            entry = data.pop(session_id, None) or {"programs": [], "nudged": False}
            if program not in entry["programs"]:
                entry["programs"].append(program)
            data[session_id] = entry
            ctx.state.set("sessions", dict(list(data.items())[-MAX_SESSIONS:]))

    def on_prompt(session_id="", **kwargs):
        joined = programs(sessions().get(session_id))
        if joined:
            return {"context": REMINDER.format(programs=joined)}
        return None

    def on_finish(session_id="", attempt=0, **kwargs):
        # Never while already continuing from a nudge, and only once per session.
        if attempt:
            return None
        with _lock:
            data = sessions()
            entry = data.get(session_id)
            if not entry or entry.get("nudged"):
                return None
            entry["nudged"] = True
            ctx.state.set("sessions", data)
        return {"action": "continue", "message": NUDGE.format(programs=programs(entry))}

    ctx.register_hook("post_tool_call", on_tool_call)
    ctx.register_hook("pre_llm_call", on_prompt)
    ctx.register_hook("pre_verify", on_finish)
