"""Serro for Hermes: the Agent Exchange skills, plus the habits that make them useful.

The habits are the ones scripts/serro-hook gives the other Serro clients, as Hermes hooks:

  post_tool_call    records a successful program_join
  pre_llm_call      reminds the agent to check for changes
  pre_verify        nudges it once to write or hand off
  post_compaction   keeps the record when compaction starts a new session id

Hermes has no general stop hook. pre_verify fires only on turns where the agent edited
files, so the nudge comes at the end of the first such turn after a join.

The plugin never calls Serro: the agent does the work over its own MCP connection, the
user's `serro` server entry (a native plugin can't ship one). It stays silent until the
agent has joined a program in this session.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

from plugins.plugin_storage import plugin_data_dir

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


# State, as serro-hook keeps it: joined-<session> lists the programs joined in a session,
# one per line, and nudged-<session> marks the nudge as sent. Separate files per session,
# appended or created atomically, so concurrent Hermes processes can't undo each other.
def state_file(kind: str, session_id: str) -> Path | None:
    session = re.sub(r"[^A-Za-z0-9_-]", "-", session_id or "")
    return plugin_data_dir("serro") / f"{kind}-{session}" if session else None


def programs(session_id: str) -> str:
    joins = state_file("joined", session_id)
    if not joins or not joins.is_file():
        return ""
    return ", ".join(sorted(set(joins.read_text().split())))


def mark_nudged(session_id: str) -> bool:
    """Creates the nudge marker; False if it already existed."""
    try:
        os.close(os.open(state_file("nudged", session_id), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644))
    except FileExistsError:
        return False
    return True


def frontmatter(skill_md: Path) -> dict:
    """The top-level `key: value` lines of a SKILL.md's frontmatter."""
    lines = skill_md.read_text().split("\n")
    if lines[0].strip() != "---":
        return {}
    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        key, sep, value = line.partition(":")
        if sep and key and not key[0].isspace():
            fields[key.strip()] = value.strip().strip("\"'")
    return fields


def register(ctx):
    skills = Path(__file__).parent / "skills"
    for skill in sorted(skills.iterdir()):
        skill_md = skill / "SKILL.md"
        if skill_md.is_file():
            # Hermes doesn't read SKILL.md's frontmatter itself, and the model picks skills
            # by these descriptions.
            meta = frontmatter(skill_md)
            ctx.register_skill(skill.name, skill_md, meta.get("description", ""), meta)

    def on_tool_call(tool_name="", args=None, result="", session_id="", status="", **kwargs):
        joins = state_file("joined", session_id)
        if not joins or not JOIN_TOOL.match(tool_name or ""):
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
        if isinstance(program, str) and PROGRAM_ID.fullmatch(program):
            with open(joins, "a") as f:
                f.write(program + "\n")

    def on_prompt(session_id="", **kwargs):
        joined = programs(session_id)
        return {"context": REMINDER.format(programs=joined)} if joined else None

    def on_finish(session_id="", attempt=0, **kwargs):
        # Never while already continuing from a nudge, and only once per session.
        joined = programs(session_id)
        if attempt or not joined or not mark_nudged(session_id):
            return None
        return {"action": "continue", "message": NUDGE.format(programs=joined)}

    def on_compaction(session_id="", old_session_id="", **kwargs):
        joined, old = state_file("joined", session_id), state_file("joined", old_session_id)
        if not joined or not old or joined == old or not old.is_file():
            return
        with open(joined, "a") as f:
            f.write(old.read_text())
        if state_file("nudged", old_session_id).exists():
            mark_nudged(session_id)

    ctx.register_hook("post_tool_call", on_tool_call)
    ctx.register_hook("pre_llm_call", on_prompt)
    ctx.register_hook("pre_verify", on_finish)
    ctx.register_hook("post_compaction", on_compaction)
