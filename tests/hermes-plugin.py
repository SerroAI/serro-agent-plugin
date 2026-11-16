#!/usr/bin/env python3
"""Tests the Hermes plugin's hooks with a fake plugin context, and that its reminder
and nudge say the same as scripts/serro-hook.
Run from the repo root: python3 tests/hermes-plugin.py"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile

# No __pycache__ in the plugin: the Hermes catalog refuses committed bytecode.
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("serro_hermes", "clients/hermes/__init__.py")
plugin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plugin)

P = "2137fc71-a969-460d-a579-72153a9c0350"
A = "527b90fb-b168-4aaf-ad07-f6c286612870"
JOIN = "mcp__serro__program_join"
ARGS = {"program_id": P, "role": "t", "working_on": "fix agent_id handling"}
fails = 0


class State:
    def __init__(self):
        self.data = {}

    def get(self, key, default=None):
        return json.loads(json.dumps(self.data.get(key, default)))

    def set(self, key, value):
        self.data[key] = json.loads(json.dumps(value))


class Ctx:
    def __init__(self):
        self.state = State()
        self.skills = []
        self.hooks = {}

    def register_skill(self, name, path, *args, **kwargs):
        assert path.is_file(), path
        self.skills.append(name)

    def register_hook(self, event, callback, **kwargs):
        self.hooks[event] = callback


def fresh():
    ctx = Ctx()
    plugin.register(ctx)
    return ctx


def check(name, got, want):
    global fails
    if got == want:
        print(f"ok    {name}")
    else:
        print(f"FAIL  {name}: got {got!r}, want {want!r}")
        fails += 1


def joined(name, want, result, tool=JOIN, args=ARGS, **kwargs):
    ctx = fresh()
    kwargs.setdefault("session_id", "s1")
    ctx.hooks["post_tool_call"](tool_name=tool, args=args, result=result, **kwargs)
    check(name, "recorded" if ctx.state.data.get("sessions") else "skipped", want)


check("skills", fresh().skills, ["agent-exchange", "handoff", "program", "sync"])

text = json.dumps({"agent_id": A, "protocol": "..."})
joined("success as text", "recorded", text)
joined("success as JSON inside JSON", "recorded", json.dumps({"result": text}))
joined("args as a JSON string", "recorded", text, args=json.dumps(ARGS))
joined("another server", "recorded", text, tool="mcp__serro_staging__program_join")
joined("Serro error JSON", "skipped", json.dumps({"error": "invalid_argument", "message": "bad agent_id: x"}))
joined("isError", "skipped", json.dumps({"content": [{"type": "text", "text": text}], "isError": True}))
joined("status error", "skipped", text, status="error")
joined("agent_id not a UUID", "skipped", json.dumps({"agent_id": "deadbeef-not-a-uuid"}))
joined("agent_id null", "skipped", json.dumps({"agent_id": None}))
joined("another tool", "skipped", text, tool="mcp__serro__program_who")
joined("no program_id", "skipped", text, args={"role": "t"})
joined("no session", "skipped", text, session_id="")

# After a join: a reminder on each prompt, one nudge, then silence.
ctx = fresh()
ctx.hooks["post_tool_call"](tool_name=JOIN, args=ARGS, result=text, session_id="s1")
prompt, finish = ctx.hooks["pre_llm_call"], ctx.hooks["pre_verify"]
reminder = (prompt(session_id="s1") or {}).get("context", "")
check("other sessions stay silent", prompt(session_id="s2"), None)
check("no nudge while continuing", finish(session_id="s1", attempt=1), None)
nudge = (finish(session_id="s1", attempt=0) or {}).get("message", "")
check("second finish is silent", finish(session_id="s1", attempt=0), None)
check("reminder after the nudge", prompt(session_id="s1"), {"context": reminder})

# The same text as serro-hook in Claude Code, which also names the skill serro:handoff.
with tempfile.TemporaryDirectory() as state:
    with open(os.path.join(state, "joined-s1"), "w") as f:
        f.write(P + "\n")
    env = {**os.environ, "CLAUDE_PLUGIN_DATA": state}

    def hook(event):
        return subprocess.run(
            ["sh", "clients/claude-code/scripts/serro-hook", event, "claude"],
            input='{"session_id":"s1"}', capture_output=True, text=True, env=env, check=True,
        ).stdout.strip()

    check("reminder matches serro-hook", reminder, hook("prompt"))
    check("nudge matches serro-hook", nudge, json.loads(hook("stop"))["reason"])

sys.exit(1 if fails else 0)
